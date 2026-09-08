import {ok, err, map, ScriptFault} from './runtime.mjs';

const operation = (params, result) => Object.freeze({params: Object.freeze(params), result});
const bytes = {vector: 'i64'};
export const standardSchemas = Object.freeze({
  'std.clock.Wall.v1': {operations: {now_ms: operation([], 'i64')}},
  'std.clock.Monotonic.v1': {operations: {now_ns: operation([], 'i64')}},
  'std.random.v1': {operations: {bytes: operation(['i64'], bytes)}},
  'std.fetch.v1': {operations: {request: operation([{record: {url: 'string', method: 'string', headers: 'value', body: {optional: bytes}}}], {result: 'value'})}},
  'std.objects.Read.v1': {operations: {get: operation(['string'], {result: bytes}), head: operation(['string'], {result: 'value'}), list: operation(['string', {optional: 'string'}, 'i64'], {result: 'value'})}},
  'std.objects.Write.v1': {operations: {put: operation(['string', bytes], {result: 'nil'}), delete: operation(['string'], {result: 'nil'})}},
});

export function protocol(id, operations, schema = standardSchemas[id]) {
  if (!schema) throw new ScriptFault(`schema required for ${id}`);
  for (const [name, signature] of Object.entries(schema.operations)) {
    if (typeof operations[name] !== 'function' || !Array.isArray(signature.params)) throw new ScriptFault(`invalid protocol operation ${name}`);
  }
  return Object.freeze({protocol: id, schema, operations: Object.freeze({...operations})});
}

// Providers are arguments, never implicit ambient clock/random implementations.
export const wallClock = now => protocol('std.clock.Wall.v1', {now_ms: async () => BigInt(await now())});
export const monotonicClock = now => protocol('std.clock.Monotonic.v1', {now_ns: async () => BigInt(await now())});
export function randomBytes(provider, {maxBytes = 65536} = {}) {
  return protocol('std.random.v1', {bytes: async (count, {signal}) => {
    if (count < 0n || count > BigInt(maxBytes)) throw new ScriptFault('random byte limit exceeded');
    const data = await provider(Number(count), {signal});
    if (!(data instanceof Uint8Array) || data.length !== Number(count)) throw new ScriptFault('invalid random provider result');
    return Object.freeze(Array.from(data, BigInt));
  }});
}

export function fields(value) {
  if (value?.tag === 'map') {
    return Object.fromEntries(value.entries.map(([k, v]) => [k?.tag === 'keyword' ? k.name : k, v]));
  }
  if (value?.tag === 'record') return value.fields;
  return value;
}

function toBytes(value, maxBytes) {
  if (!Array.isArray(value) || value.length > maxBytes || value.some(b => typeof b !== 'bigint' || b < 0n || b > 255n)) throw new ScriptFault('invalid or oversized bytes');
  return Uint8Array.from(value, Number);
}

// The application supplies fetch itself and an allow predicate. Redirects are
// followed manually so authority is rechecked at every hop, including origins.
export function fetchProtocol(fetchFn, {allow, maxBytes = 1_000_000, maxRedirects = 5} = {}) {
  if (typeof allow !== 'function') throw new TypeError('fetch requires an allow(url, method) policy');
  return protocol('std.fetch.v1', {request: async (request, {signal}) => {
    try {
      const req = fields(request);
      let url = new URL(req.url);
      let method = req.method.toUpperCase();
      let body = req.body === null ? undefined : toBytes(req.body, maxBytes);
      const headers = fields(req.headers);
      if (!headers || typeof headers !== 'object' || Object.values(headers).some(v => typeof v !== 'string')) throw new ScriptFault('headers must contain strings');
      for (let redirects = 0; ; redirects++) {
        if (!['https:', 'http:'].includes(url.protocol) || url.username || url.password || !allow(url, method)) return err('fetch denied');
        const response = await fetchFn(url.href, {method, body, headers, redirect: 'manual', credentials: 'omit', signal});
        if (response.type === 'opaqueredirect') return err('redirect is not inspectable');
        if ([301, 302, 303, 307, 308].includes(response.status)) {
          const location = response.headers.get('location');
          if (!location || redirects >= maxRedirects) { await response.body?.cancel(); return err('redirect limit exceeded'); }
          const next = new URL(location, url);
          await response.body?.cancel();
          // Explicit headers must not carry credentials across an origin change.
          if (next.origin !== url.origin && Object.keys(headers).length) return err('cross-origin redirect with headers denied');
          url = next;
          if (response.status === 303 || ([301, 302].includes(response.status) && method === 'POST')) { method = 'GET'; body = undefined; }
          continue;
        }
        const reader = response.body?.getReader();
        const chunks = [];
        let length = 0;
        if (reader) {
          try {
            for (;;) {
              const {done, value} = await reader.read();
              if (done) break;
              length += value.length;
              if (length > maxBytes) { await reader.cancel(); return err('response limit exceeded'); }
              chunks.push(value);
            }
          } finally { reader.releaseLock(); }
        }
        const result = [];
        for (const chunk of chunks) for (const b of chunk) result.push(BigInt(b));
        return ok({status: BigInt(response.status), headers: map([...response.headers].map(([k, v]) => [k, v])), body: Object.freeze(result)});
      }
    } catch (error) {
      if (signal.aborted) throw new ScriptFault('fetch cancelled');
      return err('fetch failed');
    }
  }});
}

// In-memory object store. No OS paths, CLI, symlink, or current-directory model.
// The host may expose read and write grants independently and narrow by prefix.
export function objectStore(initial = [], {prefix = '', maxBytes = 1_000_000, maxObjects = 1000} = {}) {
  const objects = new Map();
  for (const [key, value] of initial) {
    if (typeof key !== 'string' || !(value instanceof Uint8Array) || value.length > maxBytes || objects.size >= maxObjects) throw new TypeError('invalid initial object');
    objects.set(key, value.slice());
  }
  const allowed = key => typeof key === 'string' && key.startsWith(prefix) && key.length <= 4096;
  const read = protocol('std.objects.Read.v1', {
    get: key => {
      if (!allowed(key)) return err('object denied');
      const value = objects.get(key);
      return value ? ok(Object.freeze(Array.from(value, BigInt))) : err('not found');
    },
    head: key => {
      if (!allowed(key)) return err('object denied');
      return objects.has(key) ? ok({size: BigInt(objects.get(key).length)}) : err('not found');
    },
    list: (start, cursor, limit) => {
      if (!allowed(start) || limit < 1n || limit > 1000n) return err('listing denied');
      const keys = [...objects.keys()].filter(k => k.startsWith(start) && (cursor === null || k > cursor)).sort();
      const page = keys.slice(0, Number(limit));
      return ok({keys: page, cursor: keys.length > page.length ? page.at(-1) : null});
    },
  });
  const write = protocol('std.objects.Write.v1', {
    put: (key, bytes) => {
      if (!allowed(key) || (!objects.has(key) && objects.size >= maxObjects)) return err('object denied');
      try { objects.set(key, toBytes(bytes, maxBytes)); return ok(null); } catch { return err('object size exceeded'); }
    },
    delete: key => { if (!allowed(key)) return err('object denied'); objects.delete(key); return ok(null); },
  });
  return Object.freeze({read, write});
}
