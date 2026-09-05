# wap

**W**eb**A**ssembly's **P**ascal: an Oberon-level language on
[shrubbery](https://docs.racket-lang.org/shrubbery/) notation, compiled through
the [Wax](https://github.com/marianoguerra/wax-mb) AST.

```
module sieve

type flags = [bool]

export "count_primes" fn count(n :: u32) -> u32:
  if n < 2:
    return 0
  var marked = flags[false ** (n + 1)]
  var total = 0
  for i in 2 .. n:
    if marked[i]:
      continue
    total += 1
    var j = i * i
    while j <= n:
      marked[j] = true
      j += i
  total
```

## Two rules

**Every construct becomes Wax AST.** There is no runtime, no hidden allocation
and no instruction a wap form emits that its Wax expansion does not show. A
`for` is a binding and a `while`; a tuple is wasm multi-value; a set is a mask.

**What wap can't say, Wax says.** wap has no linear memory, no exceptions, no
continuations, no SIMD, no atomics, no `br_table` and no custom descriptors.
Write those in Wax, declare their signatures with `import was`, and call them.
This is Oberon's `SYSTEM` module, and it is why wap stays small.

## The sign lives in the type

Wax spells signedness on the operator -- `<s`, `<u`, `/s`, `%u`, `>>u`. wap does
not, because Modula-2 already solved it: `i32` and `u32` are both wasm i32 and
differ only in the instruction an operator on them selects.

```
fn a(x :: i32, y :: i32) -> i32: x / y     // i32.div_s
fn b(x :: u32, y :: u32) -> u32: x / y     // i32.div_u
```

The same rule decides `<`, `<=`, `>`, `>=`, `%` and `>>`, and it decides `&&`
and `||`: logical and short-circuiting on `bool`, bitwise on integers.
Shrubbery's `|` introduces alternatives, so there is no separate bitwise
spelling to give them.

Conversions are the exception, and keep Wax's spelling:

```
fn c(x :: i64) -> f64: x as f64_s          // f64.convert_i64_s
fn d(x :: f64) -> i32: x as i32_s          // i32.trunc_sat_f64_s
```

A conversion is not an operator on two values of a known type -- it is one
instruction chosen by how the SOURCE bits are to be read, and the target type
alone does not say. `f64.convert_i64_s` and `f64.convert_i64_u` answer
different numbers for the same input, so the suffix stays. It reads the source
in both directions: `as f64_s` converts an integer, `as i32_s` truncates a
float. wap builds the non-trapping form, so an out-of-range truncation
saturates rather than trapping.

## Modules

Every declaration is private to its module unless it is written `pub`, and a
name from another module is always written out:

```
module app

import geometry
import collections.hashing

export "run" fn run() -> i32:
  let p = geometry.make(3, 4)      // `geometry.make` must be `pub`
  geometry.dot(p, p)
```

The alias is the module's own declared name, not the last segment of the path
it was found at: `import collections.hashing` brings in whatever the source at
that path declares itself to be. A dot is a field access on a local and a
qualifier on a module, told apart the only way it can be -- a local wins.

`stdlib/collections/persistent_vector.wax` opens with

> All names use `pv_`/`pvt_` prefixes because Wax has no source namespaces.

wap's module system is that convention done by the compiler. A file names its
module, and every declaration in it is emitted as `module__name`. Exported wasm
names are untouched, because they are an ABI rather than an identifier.

## Using it

```sh
moon add marianoguerra/wap
```

Two ways in, the same as Wax itself.

**With the front end**, hand it source:

```moonbit
@wap.compile_string(src)          // -> Result[Bytes, Diagnostics]
@wap.compile_string_to_wat(src)   // the same lowering, printed
@wap.to_wax(src)                  // stop at the Wax AST
```

**With several modules**, hand it a loader:

```moonbit
let loader = @resolve.MapLoader::new(entries=[("collections.hashing", src)])
@wap.compile_program("app", entry_src, loader)
```

`Loader` is a trait with one method, `load(path) -> String?`, and nothing in
the resolver knows that files exist. A build tool implements it over a
filesystem, an editor over its open buffers, a bundler over what it has already
read:

```moonbit
struct Files {
  root : String
}

impl @resolve.Loader for Files with load(self, path) {
  read_file(self.root + "/" + path.replace_all(old=".", new="/") + ".wap")
}
```

The resolver walks imports depth-first, reports a cycle with the whole ring
rather than just the edge that happened to close it, and returns the modules in
dependency order. Every module gets its own entry in the source registry, so a
Wax type error found three modules deep still names the right file and line.

**Without it**, build the AST. This is the point of `marianoguerra/wap/ast`
being public: a project that generates wap -- a schema compiler, a DSL back end
-- constructs values and never produces source text, so there is no quoting, no
escaping and no reparsing.

```moonbit
let m : @wap_ast.Module = {
  name: "gen",
  decls: [
    Fn({
      name: "mul",
      receiver: None,
      params: [
        { name: "x", typ: I32, span: @wap_ast.nowhere },
        { name: "y", typ: I32, span: @wap_ast.nowhere },
      ],
      results: [I32],
      body: Some([{ it: Bin(Mul, x, y), span: @wap_ast.nowhere }]),
      export_name: Some("mul"),
      import_name: None,
      is_start: false,
      span: @wap_ast.nowhere,
    }),
  ],
}
let fields = @lower.lower_module(m).fields()   // Wax AST, ready to check
```

Spans are `marianoguerra/error-report` spans, and a node built without one
(`@wap_ast.nowhere`) gets a fresh synthetic location during lowering, so two
generated bindings never collide. A generator that *does* have spans should pass
them: Wax's type errors then point at its syntax, and the whole diagnostic
renderer starts working for it.

## Packages

| package | what |
|---|---|
| `marianoguerra/wap` | the facade: source to Wax AST, wasm or wat |
| `marianoguerra/wap/ast` | the AST. Depends on `error-report` and nothing else |
| `marianoguerra/wap/parse` | shrubbery notation to wap AST |
| `marianoguerra/wap/lower` | wap AST to Wax AST |
| `marianoguerra/wap/resolve` | `Loader`, and the import walk over it |

`ast` deliberately does not import `marianoguerra/wax`: a generator that builds
wap values should not have to compile a type checker to do it.

## What is implemented

Modules with `pub` visibility, qualified cross-module references, and
resolution through a `Loader` that need not be a filesystem; `const`; record types with single inheritance;
array, function and enumeration types; subranges; sets over enumerations;
`impl` blocks with static and type-switch dispatch; nullable references;
tuples as multi-value results and destructuring bindings; `let`/`var`;
`if` in all three shapes; `while` with an optional step; `for` over ranges and
over arrays; `loop`; labelled `break` and `continue`; `match` over types and
over values; `as`, `is`, `!`; host imports; `import was` signatures.

Method calls wap does not recognise are passed through to Wax's own intrinsic
dispatch, so `x.rotl(15)`, `f.to_bits()` and `m.load8(p)` work without wap
carrying a table of them.

## What is not

- **A value `match` lowers to a comparison chain**, never to `dispatch`.
  Correct for every label set, but not the jump table a dense one deserves.
- **`let` is not enforced.** It parses and is recorded, and assigning to one is
  not yet an error.
- **Subrange bounds inform nothing.** `1 .. 31` is an i32 to the checker, and no
  construction site is guarded.
- **Bare `{a, b}` needs an expected type** to be read as a set rather than a
  record literal.

## Development

`wap/` is a member of the `wax-mb` workspace. From the repository root:

```sh
moon check --deny-warn
moon test
moon info --target all    # regenerate .mbti
moon fmt
```

`stdlib-wap/` holds ports of the whole Wax standard library, and the tests in
this module compile them: they are the showcase and the regression suite at
once. `just wap-stdlib` compiles the same sources from disk through a
filesystem `Loader`, and `just wap-stdlib-test` runs the examples in Node and
checks that they return what the `.wax` originals return. See
[`stdlib-wap/README.md`](../stdlib-wap/README.md) for what the ports changed and
why.
