import {test} from 'node:test';
import assert from 'node:assert/strict';
import * as bridge from '../../_build/js/debug/build/marianoguerra/wisp/bridge/bridge.js';
import {createCompiler} from './compiler.mjs';
import {instantiate, keyword, ok, resource} from './runtime.mjs';
import {createSandbox} from './sandbox.mjs';
import {standardSchemas, objectStore, fetchProtocol, wallClock, protocol} from './protocols.mjs';

const compile = createCompiler(bridge);
async function run(source, input = null, limits = {}) {
  return (await instantiate(compile(source), {}, limits)).run('run', input);
}

test('numeric values, collection transformations, lexical capture', async () => {
  assert.equal(await run('export fn run(): 40 + 2'), 42n);
  assert.deepEqual(await run('export fn run():\n  let n = 3\n  map(fn(x): x + n, [1, 2])'), [4n, 5n]);
  assert.equal(await run('export fn run(): reduce(fn(a, b): a + b, 0, [1, 2, 3])'), 6n);
  assert.equal(await run('export fn run(): get({[1, 2] => 7}, [1, 2])'), 7n);
  assert.equal(await run('export fn run(): [1, 2] == list(1, 2)'), true);
  assert.equal(await run('export fn run(): 0 or 2'), 0n);
  assert.equal(await run('export fn run(): false and (1 / 0)'), false);
});

test('proper direct and closure tail recursion', async () => {
  const src = 'fn loop(n, total):\n  if n == 0 | total | loop(n - 1, total + 1)\nexport fn run(): loop(10000, 0)';
  assert.equal(await run(src, null, {allocation: 100_000_000n, fuel: 10_000_000n}), 10000n);
  const indirect = 'fn loop(f, n):\n  if n == 0 | 0 | f(f, n - 1)\nexport fn run(): loop(loop, 10000)';
  assert.equal(await run(indirect, null, {allocation: 100_000_000n, fuel: 10_000_000n}), 0n);
});

test('immutable nominal records', async () => {
  const value = await run('record Point:\n  x :: i64\n  y\nexport fn run(): Point(1, 2)');
  assert.equal(value.name, 'main.Point');
  assert.deepEqual(value.fields, {x: 1n, y: 2n});
  assert.equal(await run('record Point:\n  x\nexport fn run(): Point(4).x'), 4n);
});

test('JSPI protocols are explicit, checked, and preserve captured GC values', async () => {
  const protocol = 'app.Clock.v1';
  const schema = {operations: {now: {params: [], result: 'i64'}}};
  const source = 'require clock :: app.Clock.v1\nexport fn run(input, clock):\n  let values = [input, 2]\n  let n = clock.now()\n  conj(values, n)';
  const artifact = compile(source, {}, {[protocol]: schema});
  await assert.rejects(instantiate(artifact), /missing.*protocol/);
  const instance = await instantiate(artifact, {clock: {protocol, schema, operations: {now: async () => {await new Promise(r => setTimeout(r, 5)); return 42n;}}}});
  assert.deepEqual(await instance.run('run', 1n), [1n, 2n, 42n]);
  assert.deepEqual(await instance.run('run', 3n), [3n, 2n, 42n]);
  instance.revoke('clock');
  await assert.rejects(instance.run('run'), /missing grant/);
});

test('fatal budgets, arithmetic errors, and declaration-only modules', async () => {
  await assert.rejects(run('fn loop(): loop()\nexport fn run(): loop()', null, {fuel: 100n}), /fuel exhausted/);
  await assert.rejects(run('export fn run(): 9223372036854775807 + 1'), /overflow/);
  await assert.rejects(run('export fn run(): 1 / 0'), /division by zero/);
  assert.throws(() => compile('let x = 1\nexport fn run(): x'), /declarations only/);
  assert.throws(() => compile('export fn run(): missing'), /unbound/);
  assert.equal(await run('export fn run(input): input', keyword('hi')).then(k => k.name), 'hi');
});

test('patterns, records, structural hashing and Unicode', async () => {
  assert.equal(await run('export fn run():\n  match Ok(4)\n  | Ok(x): x\n  | _: 0'), 4n);
  assert.equal(await run('variant Choice:\n  Yes:\n    value\n  No\nexport fn run():\n  match Choice.Yes(7)\n  | Choice.Yes(x): x\n  | Choice.No(): 0'), 7n);
  assert.equal(await run('export fn run():\n  match [1, 2]\n  | [a, b]: a + b\n  | _: 0'), 3n);
  assert.equal(await run('record P:\n  x :: i64\nexport fn run(): assoc(P(1), ~x, 5).x'), 5n);
  assert.equal(await run('export fn run(): hash([1, 2]) == hash(list(1, 2))'), true);
  assert.equal(await run('export fn run(): hash({~a => 1, ~b => 2}) == hash({~b => 2, ~a => 1})'), true);
  assert.equal(await run('export fn run(): get("a😀é", 1)'), '😀');
  assert.equal(await run('export fn run(): count("a😀é")'), 3n);
  assert.equal(await run('export fn run(): -9223372036854775808'), -9223372036854775808n);
});

test('in-memory modules have no initialization and local names win', async () => {
  const artifact = compile('module app\nimport helper\nexport fn run(): helper.value()', {helper: 'module helper\nexport fn value(): 42'});
  assert.equal(await (await instantiate(artifact)).run('run'), 42n);
  assert.throws(() => compile('module app\nimport helper\nexport fn run(): helper.secret()', {helper: 'module helper\nfn secret(): 42'}), /unbound/);
});

test('worker-supervised compiler, JSPI and standard clock protocol', async () => {
  const sandbox = await createSandbox({source: 'require clock :: std.clock.Wall.v1\nexport fn run(clock): clock.now_ms()', schemas: standardSchemas, compilerURL: new URL('../../_build/js/debug/build/marianoguerra/wisp/bridge/bridge.js', import.meta.url)}, {clock: wallClock(() => 42n)}, {timeoutMs: 10000});
  try { assert.equal(await sandbox.run('run'), 42n); } finally { sandbox.close(); }
});

test('bounded object stores and redirected fetch grants', async () => {
  const store = objectStore([['safe/a', Uint8Array.of(1, 2)]], {prefix: 'safe/'});
  assert.deepEqual(store.read.operations.get('safe/a'), ok([1n, 2n]));
  assert.equal(store.read.operations.get('private/a').name, 'core.Err');
  assert.equal(store.write.operations.put('private/a', []).name, 'core.Err');
  let requests = 0;
  const fetch = fetchProtocol(async () => { requests++; return new Response(null, {status: 302, headers: {location: 'https://denied.invalid/'}}); }, {allow: url => url.hostname === 'allowed.invalid'});
  const response = await fetch.operations.request({url: 'https://allowed.invalid/', method: 'GET', headers: {}, body: null}, {signal: new AbortController().signal});
  assert.equal(response.name, 'core.Err');
  assert.equal(requests, 1);
});

test('resource-returning protocols work in-process and through the worker broker', async () => {
  const handleSchema = {operations: {value: {params: [], result: 'i64'}}};
  const factorySchema = {operations: {open: {params: [], result: {resource: 'app.Handle.v1'}}}};
  const factory = protocol('app.Factory.v1', {open: () => resource(protocol('app.Handle.v1', {value: () => 7n}, handleSchema))}, factorySchema);
  const source = 'require factory :: app.Factory.v1\nexport fn run(factory):\n  let handle = factory.open()\n  handle.value()';
  const schemas = {'app.Factory.v1': factorySchema, 'app.Handle.v1': handleSchema};
  assert.equal(await (await instantiate(compile(source, {}, schemas), {factory})).run('run'), 7n);
  const sandbox = await createSandbox({source, schemas, compilerURL: new URL('../../_build/js/debug/build/marianoguerra/wisp/bridge/bridge.js', import.meta.url)}, {factory}, {timeoutMs: 10000});
  try { assert.equal(await sandbox.run('run'), 7n); } finally { sandbox.close(); }
});

test('suspension cancellation, revocation, and worker deadlines', async () => {
  const schema = {operations: {wait: {params: [], result: 'i64'}}};
  let resolve;
  const wait = protocol('app.Wait.v1', {wait: () => new Promise(r => {resolve = r;})}, schema);
  const source = 'require wait :: app.Wait.v1\nexport fn run(wait): wait.wait()';
  const instance = await instantiate(compile(source, {}, {'app.Wait.v1': schema}), {wait});
  const pending = instance.run('run');
  await new Promise(r => setTimeout(r, 5));
  instance.cancel();
  await assert.rejects(pending, /cancelled/);
  resolve(1n);
  await assert.rejects(instance.run('run'), /cannot be reused/);
  const sandbox = await createSandbox({source: 'fn forever(): forever()\nexport fn run(): forever()', compilerURL: new URL('../../_build/js/debug/build/marianoguerra/wisp/bridge/bridge.js', import.meta.url)}, {}, {fuel: 9223372036854775807n, allocation: 9223372036854775807n, timeoutMs: 1000});
  try { await assert.rejects(sandbox.run('run'), /deadline exceeded/); } finally { sandbox.close(); }
});

test('persistent collection versions, HAMT collisions, order and normalization', async () => {
  const source = `export fn run(input):
  let original = into({}, input)
  let changed = assoc(original, 1, 99)
  let removed = dissoc(changed, 1)
  let restored = assoc(removed, 1, 55)
  [count(original), get(original, 1), get(changed, 1), get(removed, 1), get(restored, 1), first(restored)]`;
  // These i64 keys have the same xor-of-halves hash, exercising collision nodes.
  const keys = Array.from({length: 40}, (_, i) => (BigInt(i) << 32n) | BigInt(i));
  const input = [[1n, 1n], ...keys.map((k, i) => [k, BigInt(i)])];
  const result = await run(source, input, {allocation: 100_000_000n, fuel: 10_000_000n});
  assert.deepEqual(result.slice(0, 5), [41n, 1n, 99n, null, 55n]);
  assert.deepEqual(result[5], [0n, 0n]);
  assert.deepEqual(await run('export fn run():\n  let a = [1, 2]\n  let b = assoc(a, 0, 9)\n  [a, b]'), [[1n, 2n], [9n, 2n]]);
  assert.equal(await run('export fn run(): set(1, 1, 2) == set(2, 1)'), true);
  assert.deepEqual(await run('export fn run(): map(fn(x): x, "ab")'), ['a', 'b']);
});

test('authority stays lexical and malformed boundaries fail closed', async () => {
  assert.throws(() => compile('require clock :: std.clock.Wall.v1\nexport fn run(): clock.now_ms()'), /unbound/);
  assert.throws(() => compile('export fn run(): rt.cap(1)'), /unbound/);
  await assert.rejects(run('export fn run(input): input.now_ms()', {tag: 'capability', id: 1n}), /callable/);
  await assert.rejects(run('export fn run():\n  let f = fn(x): x\n  {f => 1}'), /data keys/);
  await assert.rejects(run('export fn run(): float(9007199254740993)'), /conversion/);
  await assert.rejects(run('fn nest(n):\n  if n == 0 | 0 | 1 + nest(n - 1)\nexport fn run(): nest(1000)', null, {maxDepth: 20}), /depth/);
  await assert.rejects(run('export fn run(): [1, 2, 3]', null, {allocation: 100n}), /allocation/);
  const schema = {operations: {now: {params: [], result: 'i64'}}};
  const source = 'require clock :: app.Clock.v1\nexport fn run(clock): clock.now()';
  const artifact = compile(source, {}, {'app.Clock.v1': schema});
  const bad = protocol('app.Clock.v1', {now: () => 'wrong'}, schema);
  await assert.rejects((await instantiate(artifact, {clock: bad})).run('run'), /schema mismatch/);
});

test('worker clone failures retire the instance cleanly', async () => {
  const request = {source: 'export fn run(input): input', compilerURL: new URL('../../_build/js/debug/build/marianoguerra/wisp/bridge/bridge.js', import.meta.url)};
  await assert.rejects(createSandbox({...request, invalid: () => {}}), /clone/i);
  const sandbox = await createSandbox(request, {}, {timeoutMs: 10000});
  try {
    await assert.rejects(sandbox.run('run', () => {}), /clone/i);
    await assert.rejects(sandbox.run('run', 1n), /closed/);
  } finally { sandbox.close(); }
});
