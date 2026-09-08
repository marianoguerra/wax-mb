import {instantiate, resource, resourceImplementation} from './runtime.mjs';
import {createCompiler} from './compiler.mjs';

const node = typeof process !== 'undefined' && process.versions?.node;
const port = node ? (await import('node:worker_threads')).parentPort : globalThis;
const send = message => port.postMessage(message);
const listen = callback => node ? port.on('message', callback) : port.addEventListener('message', e => callback(e.data));
let instance;
let serial = 0;
const pending = new Map();
function proxy(grant, name, resourceId = null) {
  const operations = {};
  for (const [method, signature] of Object.entries(grant.schema.operations)) {
    operations[method] = (...args) => {
      args.pop();
      const data = args.map((value, i) => {
        if (signature.params[i]?.resource) {
          const impl = resourceImplementation(value);
          return {resourceRef: {name: impl.brokerName, id: impl.brokerId}};
        }
        return value;
      });
      const id = ++serial;
      return new Promise((resolve, reject) => {
        pending.set(id, {resolve, reject});
        send({type: 'invoke', id, name, resourceId, method, args: data});
      });
    };
  }
  return {...grant, operations, brokerName: name, brokerId: resourceId};
}
listen(async message => {
  try {
    if (message.type === 'init') {
      const {request, limits, grants} = message;
      const bridge = await import(request.compilerURL);
      const artifact = createCompiler(bridge)(request.source, request.modules, request.schemas);
      const implementations = {};
      for (const [name, grant] of Object.entries(grants)) {
        implementations[name] = proxy(grant, name);
      }
      instance = await instantiate(artifact, implementations, limits);
      send({type: 'ready', manifest: artifact.manifest});
    } else if (message.type === 'run') {
      const value = await instance.run(message.entry, message.input, message.bindings);
      send({type: 'result', value});
    } else if (message.type === 'reply') {
      const promise = pending.get(message.id);
      if (promise) {
        pending.delete(message.id);
        if (message.error) promise.reject(new Error(message.error));
        else if (message.resource) promise.resolve(resource(proxy(message.resource, message.resource.name, message.resource.id)));
        else promise.resolve(message.value);
      }
    } else if (message.type === 'revoke') {
      instance.revoke(message.name);
    }
  } catch (error) {
    send({type: 'error', error: {message: error.message, code: error.code, offset: error.offset, source: error.source}});
  }
});
