# Wisp

An immutable, dynamically checked functional language in Shrubbery notation,
compiled through **wap AST → Wax AST → Wasm**. `wisp` is the working name. This
experimental module is not included in publishing recipes.

```text
module example
require clock :: std.clock.Wall.v1

record Reading:
  values
  timestamp :: i64

export fn run(input, clock):
  Reading(map(fn(x): x * 2, input), clock.now_ms())
```

## Lexical scope and modules

A module contains declarations only: `module`, `import`, `require`, `fn`,
`record`, and `variant`. There are **no module values, globals, constants,
initialization expressions, or module objects**. `export fn` exposes a function
to importing modules and, in the entry module, to the host. Named functions
resolve statically; taking one as a value creates a function reference in the
current scope. Runtime values come from parameters, expressions, and lexical
captures. Local names shadow imported qualifiers and builtins.

Imports resolve exclusively through a supplied map of source strings. Missing
sources, cycles, and duplicate module names are errors. Imports execute nothing.
Functions support lexical closures, mutual recursion, and proper direct and
indirect tail calls. Generated Wasm has no globals or start function: invocation
bookkeeping is an explicit context parameter. `require` declares an expected
protocol; it creates no ambient value. Helpers must receive or capture grants.

## Values and expressions

Evaluation is eager and left-to-right. Only `nil` and `false` are falsey. `and`
and `or` short-circuit and return operand values. All script bindings and data
are immutable; updates return new values.

```text
fn sum(xs): reduce(fn(a, b): a + b, 0, xs)

fn classify(value):
  match value
  | Ok(x): x
  | Err(message): {~error => message}
  | [a, b]: a + b
  | _: nil

variant Choice:
  Yes:
    value
  No
```

- Integers are checked signed i64; overflow and division by zero are errors.
  Floats are f64. `float(integer)` and `integer(float)` are explicit; integer
  conversion rejects nonfinite, fractional, and out-of-range inputs; conversion
  to float rejects integers that cannot be represented exactly.
- Strings are validated UTF-8. `count` and `get` use Unicode scalar values.
- Keywords use `~name` and are callable as map/record lookups.
- `[a, b]` is a vector; `{~key => value}` is a map. `list(...)` and `set(...)`
  construct lists and sets. Lists/vectors compare by contents.
- Maps support arbitrary immutable data keys and preserve insertion order.
  Replacement retains position; deletion/reinsertion moves a key last. Sets
  preserve insertion order too. Map/set equality ignores order.
- Records and variant cases allocate concrete nominal GC structs. Fields are
  dynamic unless annotated `i64`, `f64`, `bool`, or a declared reference type,
  optionally nullable with `?`. Updates preserve the type and recheck fields.
  Recursive types are allowed; construction creates immutable acyclic values.
- Equality and `hash` agree structurally. Integer/float categories are distinct;
  NaNs compare/hash equally, as do floating signed zeros. Functions/capabilities
  have identity equality and are forbidden as data keys, including nested keys.

Builtins: `list`, `set`, `count`, `get`, `assoc`, `conj`, `not`, `map`, `filter`,
`reduce`, `first`, `rest`, `contains`, `into`, `float`, `integer`, `dissoc`, `hash`.
`map` and `filter` return vectors; maps iterate as entry vectors. `let [a, b] =
value` destructures through indexed lookup. Patterns support literals,
wildcards/binders, sequences, and positional constructors. `Ok`/`Err` are
built-in nominal records. Unmatched patterns and runtime type errors are fatal.

Vectors reuse the repository's persistent trie. Maps/sets reuse its HAMT with
a persistent vector for insertion order; deletion leaves tombstones that are
compacted on subsequent insertion. Hash/equality callbacks carry an explicit
invocation context. Private runtime construction may mutate owned storage, but
scripts cannot access backing arrays or builders. Lists currently copy their
element arrays on updates. Metering conservatively charges for worst-case HAMT
collision copying, even when an operation takes the common logarithmic path.

## In-memory embedding

Build the compiler with `moon build --target js wisp/bridge`. Apps choose how to
serve or bundle the resulting ES module; no generated compiler is committed.

```js
import * as bridge from './_build/js/debug/build/marianoguerra/wisp/bridge/bridge.js';
import {createCompiler} from './wisp/js/compiler.mjs';
import {instantiate} from './wisp/js/runtime.mjs';
import {wallClock} from './wisp/js/protocols.mjs';

const compile = createCompiler(bridge);
const artifact = compile(source, modules, customProtocolSchemas);
const instance = await instantiate(artifact, {
  clock: wallClock(() => 1234n),
});
const result = await instance.run('run', [1n, 2n]);
```

JavaScript BigInts become i64; Numbers become f64; arrays become vectors; plain
objects become keyword-keyed maps. Helpers `keyword`, `list`, `map`, `set`,
`record`, `ok`, and `err` represent other immutable data. Results are frozen
data, never raw GC references. Functions/capabilities cannot cross the ordinary
data boundary. Each entry takes at most one data parameter plus declared grants.

Artifacts contain Wasm, WAT, entry signatures, protocol requirements/schemas,
record constructors, sources, and ABI/feature versions. MoonBit callers use
`@wisp.compile(source, modules?, protocols?)`; its protocol table records
operation names, while the JavaScript adapter validates data schemas.

**Use worker supervision for hostile scripts**, including compilation:

```js
import {createSandbox} from './wisp/js/sandbox.mjs';
const sandbox = await createSandbox({
  source, modules, schemas: customProtocolSchemas,
  compilerURL: new URL('./_build/js/debug/build/marianoguerra/wisp/bridge/bridge.js', import.meta.url),
}, implementations, {timeoutMs: 5000});
try {
  const result = await sandbox.run('run', input);
} finally {
  sandbox.close();
}
```

Node worker threads and browser module workers are supported. Providers stay
in the app; a broker validates operations and marshals requests. Only one run
is active per instance. `revoke(name)` invalidates a grant and its derived
resources. Cancellation aborts host work where supported. A cancelled low-level
instance is retired; cancelling a sandbox terminates the worker.

## Host protocols and suspension

Protocols are versioned host-defined schemas, with explicit operations and
argument/result validation. None is granted automatically.

```js
const schema = {
  operations: {lookup: {params: ['string'], result: {result: 'value'}}},
};
const implementation = protocol('app.Lookup.v1', {
  lookup: key => ok({key, value: 42n}),
}, schema);
```

Schemas accept `value`, `i64`, `f64`, `bool`, `string`, `nil`, `{vector: T}`,
`{optional: T}`, `{record: {field: T}}`, and `{result: T}`. Direct
`{resource: 'protocol.v1'}` arguments/results carry opaque capabilities. Hosts
mint them with `resource(implementation)`; scripts can call/delegate them but
cannot manufacture them from data. Nested resource schemas are not supported.

| Standard protocol | Operations |
|---|---|
| `std.clock.Wall.v1` | `now_ms()` |
| `std.clock.Monotonic.v1` | `now_ns()` |
| `std.random.v1` | `bytes(count)` |
| `std.fetch.v1` | `request({url, method, headers, body})` |
| `std.objects.Read.v1` | `get(key)`, `head(key)`, `list(prefix, cursor, limit)` |
| `std.objects.Write.v1` | `put(key, bytes)`, `delete(key)` |

Bytes are vectors of i64 values in 0–255. Object stores use opaque keys and
prefix-scoped authority, with no OS filesystem model. Clock/random providers
are injected. Fetch requires an injected implementation and allow predicate,
checks every redirect, omits browser credentials, and bounds streamed bodies.
Uninspectable redirects fail closed. Ordinary fetch/object failures return
`Ok`/`Err`; provider exceptions and contract violations abort execution.

Sequential calls may suspend through JSPI's native stack switching; scripts
have no promises, `async`, or `await`. The target uses Wasm 3.0 GC and tail calls
plus the separate JSPI API. Missing JSPI is a compatibility error. Experimental
continuation instructions and compiler-generated state machines are unnecessary.

## Limits and trust

Finite defaults: 1,000,000 fuel units, 16,000,000 allocation units, 100,000
collection elements, depth 128, 100 host calls, 100,000 transfer nodes, and a
5-second deadline. Source limits: 1,000,000 code units per module, 2,000,000
total, and 128 supplied modules. All execution limits are host-configurable.

Counters belong to each invocation and survive suspension. Allocation is charged
before execution; collection operations use conservative upper bounds. Allocation
units bound cumulative requested storage, **not exact live GC heap bytes**.
Exhaustion is fatal. Completed effects are not rolled back. Providers must bound
their own work and honor cancellation; a synchronous host provider cannot be
preempted by the low-level adapter.

The contract covers hostile source compiled by the trusted compiler/runtime,
with a trusted adapter and engine. Arbitrary third-party Wasm is outside it.
Workers isolate scheduling, but do not guarantee protection against whole-
process memory exhaustion. This is an initial implementation with adversarial
regressions, not an independently audited security boundary. Macros, laziness,
mutable references, concurrency, runtime schemas, and native engines are outside
v1.

## Development

```sh
python3 tools/gen-wisp-runtime.py  # after runtime/vector changes
bash tools/wisp-test.sh           # Wasm/JSPI/worker tests, Node 24+
moon test wisp --target all
moon check --deny-warn
moon info --target all
moon fmt
```

Do not edit `runtime_generated.mbt`. It embeds trusted runtime source for
filesystem-free compilation. The generator copies only the persistent halves of
the vector and HAMT libraries, removes exports, and inlines numeric constants
to avoid globals. `--check` verifies freshness.

For browser smoke tests, serve the repository on localhost:8765 and visit
`wisp/js/browser-test.html`. `tools/wisp-browser-test.mjs` drives Chromium with
`--remote-debugging-port=9223` against that page using real wall-clock time.
