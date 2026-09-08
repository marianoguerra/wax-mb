const encoder = new TextEncoder();
const decoder = new TextDecoder('utf-8', {fatal: true});
export const keyword = name => Object.freeze({tag: 'keyword', name});
export const list = values => Object.freeze({tag: 'list', values: Object.freeze([...values])});
export const map = entries => Object.freeze({tag: 'map', entries: Object.freeze(entries.map(pair => Object.freeze([...pair])))});
export const set = values => Object.freeze({tag: 'set', values: Object.freeze([...values])});
export const record = (name, fields) => Object.freeze({tag: 'record', name, fields: Object.freeze({...fields})});
export const ok = value => record('core.Ok', {value});
export const err = error => record('core.Err', {error});
const resources = new WeakMap();
// Host-only resource minting. The empty token exposes neither implementation nor
// an integer handle; only a protocol result with a resource schema admits it.
export function resource(implementation) {
  if (!implementation?.protocol || !implementation.schema || !implementation.operations) throw new TypeError('invalid resource implementation');
  const token = Object.freeze({});
  resources.set(token, implementation);
  return token;
}
export function resourceImplementation(token) { return resources.get(token); }

export class ScriptFault extends Error {
  constructor(message, code = 0, offset = 0) {
    super(message); this.name = 'ScriptFault'; this.code = code; this.offset = offset;
  }
}

const errors = ['', 'fuel exhausted', 'allocation or size limit exceeded', 'call depth exceeded', 'type mismatch', 'value is not callable', 'wrong arity', 'capabilities and functions are not data keys', 'index out of bounds', 'numeric overflow or conversion error', 'division by zero', 'no matching pattern'];
const defaults = Object.freeze({fuel: 1_000_000n, allocation: 16_000_000n, maxSize: 100_000, maxDepth: 128, hostCalls: 100, transferNodes: 100_000, timeoutMs: 5000});

function limitsOf(options) {
  const limits = {...defaults, ...options};
  for (const key of ['fuel', 'allocation']) {
    limits[key] = BigInt(limits[key]);
    if (limits[key] < 1n || limits[key] > 9223372036854775807n) throw new RangeError(`invalid ${key}`);
  }
  for (const key of ['maxSize', 'maxDepth', 'hostCalls', 'transferNodes', 'timeoutMs']) {
    if (!Number.isSafeInteger(limits[key]) || limits[key] < 1 || limits[key] > 0x7fffffff) throw new RangeError(`invalid ${key}`);
  }
  return limits;
}

// Low-level instance API. Use sandbox.mjs for worker supervision of hostile code.
// Only artifacts from the trusted compiler/runtime are accepted by this contract.
export async function instantiate(artifact, implementations = {}, options = {}) {
  if (typeof WebAssembly.Suspending !== 'function' || typeof WebAssembly.promising !== 'function') {
    throw new ScriptFault('this embedding requires Wasm GC, tail calls, and JSPI');
  }
  if (artifact.manifest.abi !== 1) throw new ScriptFault('unsupported Wisp ABI');
  const limits = limitsOf(options);
  const grants = new Map();
  for (const [name, id] of Object.entries(artifact.manifest.requirements)) {
    const impl = implementations[name];
    if (!impl || impl.protocol !== id || !impl.operations || !impl.schema) throw new ScriptFault(`missing or incompatible protocol ${name}: ${id}`);
    if (artifact.manifest.protocolSchemas?.[id] && canonical(impl.schema) !== canonical(artifact.manifest.protocolSchemas[id])) throw new ScriptFault(`protocol schema version mismatch: ${id}`);
    for (const op of artifact.manifest.protocols?.[id] ?? []) {
      if (typeof impl.operations[op] !== 'function' || !impl.schema.operations[op]) throw new ScriptFault(`missing operation ${id}.${op}`);
    }
    grants.set(name, impl);
  }
  let ex;
  let active = null;
  let retired = false;
  const tokens = new Map();
  const revoked = new Set();
  const module = await WebAssembly.compile(artifact.wasm);
  for (const imp of WebAssembly.Module.imports(module)) {
    if (imp.kind !== 'function' || imp.module !== 'wisp' || imp.name !== 'invoke') throw new ScriptFault('unexpected Wasm import');
  }
  const instance = await WebAssembly.instantiate(module, {wisp: {invoke: new WebAssembly.Suspending(async (ctx, cap, methodBytes, args) => {
    const run = active;
    if (!run || run.ctx !== ctx || run.cancelled) throw new ScriptFault('inactive invocation');
    const grant = tokens.get(cap);
    if (!grant || revoked.has(grant.name)) throw new ScriptFault('invalid or revoked capability');
    if (++run.calls > limits.hostCalls) throw new ScriptFault('host call limit exceeded');
    const method = readBytes(methodBytes);
    const signature = grant.impl.schema.operations[method];
    const operation = grant.impl.operations[method];
    if (!Object.hasOwn(grant.impl.operations, method) || typeof operation !== 'function' || !signature) throw new ScriptFault('operation not granted');
    if (ex.value_count(args) !== signature.params.length) throw new ScriptFault('protocol arity mismatch');
    const data = signature.params.map((type, i) => {
      const value = ex.value_get(args, i);
      if (type?.resource) {
        const other = tokens.get(value);
        if (!other || other.impl.protocol !== type.resource || revoked.has(other.name)) throw new ScriptFault('resource argument not granted');
        return other.resource ?? resource(other.impl);
      }
      return decode(value, run);
    });
    data.forEach((v, i) => validate(v, signature.params[i]));
    const result = await operation(...data, {signal: run.abort.signal});
    if (run.cancelled || active !== run || revoked.has(grant.name)) throw new ScriptFault('invocation cancelled or capability revoked');
    validate(result, signature.result);
    if (signature.result?.resource) {
      const implementation = resources.get(result);
      const token = ex.capability(ctx, run.calls);
      tokens.set(token, {name: grant.name, impl: implementation, resource: result});
      return token;
    }
    return encode(result, run);
  })}});
  ex = instance.exports;

  function charge(run, n = 1) {
    run.transferred += n;
    if (run.transferred > limits.transferNodes) throw new ScriptFault('transfer limit exceeded');
  }
  function readBytes(bytes) {
    const n = ex.byte_count(bytes);
    if (n > limits.maxSize) throw new ScriptFault('string size limit exceeded');
    const out = new Uint8Array(n);
    for (let i = 0; i < n; i++) out[i] = ex.byte_get(bytes, i);
    return decoder.decode(out);
  }
  function writeBytes(text, run) {
    if (typeof text !== 'string' || text.length > limits.maxSize || !text.isWellFormed()) throw new ScriptFault('invalid or oversized string');
    const bytes = encoder.encode(text);
    charge(run, bytes.length);
    const out = ex.bytes(run.ctx, bytes.length);
    bytes.forEach((b, i) => ex.byte_set(out, i, b));
    return out;
  }
  function writeArray(items, run, depth) {
    if (items.length > limits.maxSize) throw new ScriptFault('collection size limit exceeded');
    const out = ex.values(run.ctx, items.length);
    items.forEach((v, i) => ex.value_set(out, i, encode(v, run, depth + 1)));
    return out;
  }
  function encode(value, run, depth = 0) {
    charge(run);
    if (depth > limits.maxDepth) throw new ScriptFault('input nesting limit exceeded');
    if (value === null) return null;
    if (typeof value === 'bigint') {
      if (value < -9223372036854775808n || value > 9223372036854775807n) throw new ScriptFault('integer out of range');
      return ex.integer(run.ctx, value);
    }
    if (typeof value === 'number') return ex.float(run.ctx, value);
    if (typeof value === 'boolean') return ex.boolean(run.ctx, value);
    if (typeof value === 'string') return ex.text(run.ctx, writeBytes(value, run), false);
    if (Array.isArray(value)) return ex.sequence(run.ctx, 6, writeArray(value, run, depth));
    if (!value || typeof value !== 'object') throw new ScriptFault('not an immutable data value');
    if (value.tag === 'keyword') return ex.text(run.ctx, writeBytes(value.name, run), true);
    if (value.tag === 'list' || value.tag === 'set') return ex.sequence(run.ctx, value.tag === 'list' ? 7 : 12, writeArray(value.values, run, depth));
    if (value.tag === 'map') return ex.sequence(run.ctx, 8, writeArray(value.entries.flat(), run, depth));
    if (value.tag === 'record') {
      const descriptor = artifact.manifest.records[value.name];
      if (!descriptor || descriptor.fields.length !== Object.keys(value.fields).length || descriptor.fields.some(k => !Object.hasOwn(value.fields, k))) throw new ScriptFault('unknown or malformed nominal record');
      return ex[descriptor.constructor](run.ctx, writeArray(descriptor.fields.map(k => value.fields[k]), run, depth));
    }
    if (Object.getPrototypeOf(value) === Object.prototype || Object.getPrototypeOf(value) === null) {
      const items = Object.entries(value).flatMap(([k, v]) => [keyword(k), v]);
      return ex.sequence(run.ctx, 8, writeArray(items, run, depth));
    }
    throw new ScriptFault('unsupported host value');
  }
  function readArray(array, run, depth = 0) {
    const length = ex.value_count(array);
    if (length > limits.maxSize) throw new ScriptFault('output size limit exceeded');
    return Array.from({length}, (_, i) => decode(ex.value_get(array, i), run, depth + 1));
  }
  function decode(value, run, depth = 0) {
    charge(run);
    if (depth > limits.maxDepth) throw new ScriptFault('output nesting limit exceeded');
    const kind = ex.kind(value);
    if (kind === 0) return null;
    if (kind === 1) return ex.integer_value(run.ctx, value);
    if (kind === 2) return ex.float_value(run.ctx, value);
    if (kind === 3) return Boolean(ex.boolean_value(value));
    if (kind === 4 || kind === 5) {
      const text = readBytes(ex.text_bytes(value));
      charge(run, text.length);
      return kind === 4 ? text : keyword(text);
    }
    if ([6, 7, 8, 12].includes(kind)) {
      const values = readArray(ex.sequence_values(run.ctx, value), run, depth);
      if (kind === 6) return Object.freeze(values);
      if (kind === 7) return list(values);
      if (kind === 12) return set(values);
      return map(Array.from({length: values.length / 2}, (_, i) => values.slice(i * 2, i * 2 + 2)));
    }
    if (kind === 13) {
      const keys = readArray(ex.record_keys(value), run, depth);
      const values = readArray(ex.record_values(value), run, depth);
      return Object.freeze({tag: 'record', name: readBytes(ex.record_name(value)), fields: Object.freeze(Object.fromEntries(keys.map((k, i) => [k.name, values[i]])))});
    }
    throw new ScriptFault('functions and capabilities cannot cross the data boundary');
  }
  function cancel() {
    if (active) { retired = true; active.cancelled = true; active.abort.abort(); active.rejectCancel(new ScriptFault('invocation cancelled')); }
  }
  return Object.freeze({
    revoke(name) { revoked.add(name); },
    cancel,
    async run(entry, input = null, bindings = {}) {
      if (retired) throw new ScriptFault('cancelled instance cannot be reused');
      if (active) throw new ScriptFault('instance already running');
      const params = artifact.manifest.entries[entry];
      if (!Array.isArray(params)) throw new ScriptFault('unknown entry');
      const ctx = ex.context(limits.fuel, limits.allocation, limits.maxSize, limits.maxDepth);
      const run = {ctx, calls: 0, transferred: 0, cancelled: false, abort: new AbortController()};
      const cancelled = new Promise((_, reject) => { run.rejectCancel = reject; });
      active = run;
      const timer = setTimeout(cancel, limits.timeoutMs);
      try {
        const args = ex.values(ctx, params.length);
        let dataParams = 0;
        params.forEach((name, i) => {
          if (Object.hasOwn(artifact.manifest.requirements, name)) {
            const grantName = bindings[name] ?? name;
            const impl = grants.get(grantName);
            if (!impl || impl.protocol !== artifact.manifest.requirements[name] || revoked.has(grantName)) throw new ScriptFault(`missing grant ${name}`);
            const token = ex.capability(ctx, i);
            tokens.set(token, {name: grantName, impl});
            ex.value_set(args, i, token);
          } else {
            if (++dataParams > 1) throw new ScriptFault('entry accepts at most one data parameter');
            ex.value_set(args, i, encode(input, run));
          }
        });
        const result = await Promise.race([WebAssembly.promising(ex[`run_${entry}`])(ctx, args), cancelled]);
        if (run.cancelled) throw new ScriptFault('invocation cancelled');
        return decode(result, run);
      } catch (error) {
        const code = ex.error(ctx);
        if (code) {
          const fault = new ScriptFault(errors[code] ?? 'runtime failure', code, ex.offset(ctx));
          fault.source = artifact.manifest.sources[ex.source(ctx)]?.module;
          throw fault;
        }
        throw error;
      } finally {
        clearTimeout(timer); run.cancelled = true; run.abort.abort(); tokens.clear(); active = null;
      }
    }
  });
}

export function validate(value, schema, depth = 0) {
  if (depth > 128) throw new ScriptFault('schema nesting limit exceeded');
  if (schema === 'value') return;
  if (schema?.resource && resources.get(value)?.protocol === schema.resource) return;
  const ok = schema === 'i64' ? typeof value === 'bigint' && value >= -9223372036854775808n && value <= 9223372036854775807n
    : schema === 'f64' ? typeof value === 'number'
    : schema === 'bool' ? typeof value === 'boolean'
    : schema === 'string' ? typeof value === 'string'
    : schema === 'nil' ? value === null : false;
  if (ok) return;
  if (schema?.vector && Array.isArray(value)) { value.forEach(v => validate(v, schema.vector, depth + 1)); return; }
  if (schema?.optional) { if (value !== null) validate(value, schema.optional, depth + 1); return; }
  if (schema?.result && value?.tag === 'record') {
    if (value.name === 'core.Ok') { validate(value.fields.value, schema.result, depth + 1); return; }
    if (value.name === 'core.Err') { validate(value.fields.error, 'value', depth + 1); return; }
  }
  if (schema?.record && value && typeof value === 'object') {
    const fields = value.tag === 'map' ? Object.fromEntries(value.entries.map(([k, v]) => [k?.tag === 'keyword' ? k.name : k, v])) : value.tag === 'record' ? value.fields : value;
    if (Object.keys(fields).length !== Object.keys(schema.record).length) throw new ScriptFault('protocol record shape mismatch');
    for (const [name, type] of Object.entries(schema.record)) {
      if (!Object.hasOwn(fields, name)) throw new ScriptFault(`missing protocol field ${name}`);
      validate(fields[name], type, depth + 1);
    }
    return;
  }
  throw new ScriptFault(`protocol schema mismatch: ${JSON.stringify(schema)}`);
}

function canonical(value) {
  if (Array.isArray(value)) return '[' + value.map(canonical).join(',') + ']';
  if (value && typeof value === 'object') return '{' + Object.keys(value).sort().map(k => JSON.stringify(k) + ':' + canonical(value[k])).join(',') + '}';
  return JSON.stringify(value);
}
