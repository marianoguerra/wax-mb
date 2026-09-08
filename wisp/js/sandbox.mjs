import {ScriptFault, validate, resource, resourceImplementation} from './runtime.mjs';

// Both compilation and execution happen in a dedicated worker. Host protocol
// implementations remain in the app and are reached only through this broker.
export async function createSandbox(request, implementations = {}, limits = {}) {
  if (!Number.isSafeInteger(limits.timeoutMs ?? 5000) || (limits.timeoutMs ?? 5000) < 1) throw new RangeError('invalid timeout');
  const node = typeof process !== 'undefined' && process.versions?.node;
  const WorkerClass = node ? (await import('node:worker_threads')).Worker : Worker;
  const worker = new WorkerClass(new URL('./worker.mjs', import.meta.url), {type: 'module'});
  const timeout = limits.timeoutMs ?? 5000;
  let waiter;
  let closed = false;
  let busy = false;
  let abort = new AbortController();
  let calls = 0;
  let transferred = 0;
  let resourceSerial = 0;
  const resources = new Map();
  const revoked = new Set();
  const stop = (reason = 'sandbox closed') => {
    if (closed) return;
    closed = true; abort.abort(); worker.terminate();
    if (waiter) { clearTimeout(waiter.timer); waiter.reject(new ScriptFault(reason)); waiter = null; }
  };
  const wait = message => new Promise((resolve, reject) => {
    waiter = {resolve, reject, timer: setTimeout(() => stop('sandbox deadline exceeded'), timeout)};
    try { worker.postMessage(message); } catch (error) { stop(error.message); }
  });
  const receive = async message => {
    if (closed) return;
    if (message.type === 'invoke') {
      try {
        const issued = message.resourceId === null ? null : resources.get(message.resourceId);
        if (message.resourceId !== null && (!issued || issued.name !== message.name)) throw new ScriptFault('resource not granted');
        const impl = issued ? resourceImplementation(issued.token) : implementations[message.name];
        const sig = impl?.schema.operations[message.method];
        if (!busy || revoked.has(message.name) || !sig || !Object.hasOwn(impl.operations, message.method) || ++calls > (limits.hostCalls ?? 100)) throw new ScriptFault('protocol operation denied');
        if (message.args.length !== sig.params.length) throw new ScriptFault('protocol arity mismatch');
        const args = message.args.map((value, i) => {
          if (!sig.params[i]?.resource) return value;
          const ref = value?.resourceRef;
          if (!ref || revoked.has(ref.name)) throw new ScriptFault('invalid resource argument');
          if (ref.id === null) {
            const root = implementations[ref.name];
            if (!root) throw new ScriptFault('resource not granted');
            return resource(root);
          }
          const issued = resources.get(ref.id);
          if (!issued || issued.name !== ref.name) throw new ScriptFault('resource not granted');
          return issued.token;
        });
        args.forEach((v, i) => validate(v, sig.params[i]));
        const value = await impl.operations[message.method](...args, {signal: abort.signal});
        validate(value, sig.result);
        if (!closed && sig.result?.resource) {
          const id = ++resourceSerial;
          resources.set(id, {name: message.name, token: value});
          const impl = resourceImplementation(value);
          worker.postMessage({type: 'reply', id: message.id, resource: {name: message.name, id, protocol: impl.protocol, schema: impl.schema}});
        } else if (!closed) {
          const visit = (item, depth = 0) => {
            if (++transferred > (limits.transferNodes ?? 100000) || depth > (limits.maxDepth ?? 128)) throw new ScriptFault('protocol transfer limit exceeded');
            if (typeof item === 'string') transferred += item.length;
            else if (item && typeof item === 'object') for (const child of Object.values(item)) visit(child, depth + 1);
            if (transferred > (limits.transferNodes ?? 100000)) throw new ScriptFault('protocol transfer limit exceeded');
          };
          visit(value);
          worker.postMessage({type: 'reply', id: message.id, value});
        }
      } catch (error) {
        if (!closed) worker.postMessage({type: 'reply', id: message.id, error: error.message});
      }
      return;
    }
    if (!waiter) return;
    const current = waiter; waiter = null; clearTimeout(current.timer);
    if (message.type === 'error') current.reject(Object.assign(new ScriptFault(message.error.message), message.error));
    else current.resolve(message);
  };
  if (node) {
    worker.on('message', receive);
    worker.on('error', error => stop(error.message));
    worker.on('exit', () => stop('sandbox worker exited'));
  } else {
    worker.addEventListener('message', e => receive(e.data));
    worker.addEventListener('error', e => stop(e.message));
  }
  let manifest;
  try {
    const grants = Object.fromEntries(Object.entries(implementations).map(([name, impl]) => [name, {protocol: impl.protocol, schema: impl.schema}]));
    manifest = (await wait({type: 'init', request: {...request, compilerURL: String(request.compilerURL)}, grants, limits})).manifest;
  } catch (error) { stop(); throw error; }
  return Object.freeze({
    manifest,
    close() { stop(); },
    cancel() { stop('sandbox cancelled'); },
    revoke(name) { revoked.add(name); worker.postMessage({type: 'revoke', name}); },
    async run(entry, input = null, bindings = {}) {
      if (closed || busy) throw new ScriptFault(closed ? 'sandbox closed' : 'sandbox already running');
      busy = true; calls = 0; transferred = 0; resources.clear(); abort = new AbortController();
      try {
        return freeze((await wait({type: 'run', entry, input, bindings})).value);
      } finally { busy = false; abort.abort(); }
    },
  });
}

function freeze(value) {
  if (value && typeof value === 'object') { for (const child of Object.values(value)) freeze(child); Object.freeze(value); }
  return value;
}
