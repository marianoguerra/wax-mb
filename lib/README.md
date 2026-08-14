# marianoguerra/wax

The **Wax** language in MoonBit: a parser, a formatter, a type checker, and
emitters for both the binary and the text form of WebAssembly.

[Wax](https://github.com/ocsigen/wax) is a Rust-like surface syntax for
WebAssembly. It reads as a programming language:

```rust
#[export]
fn add(x: i32, y: i32) -> i32 {
    x + y;
}
```

and compiles to the same bytecode as the equivalent stack-machine WAT.

This is a port of the reference implementation, written against it as a
*specification* rather than as an inspiration: a differential harness runs both
over a ~2000-module corpus and gates on reprint parity, wasm equivalence and
diagnostic parity. See the
[repository](https://github.com/marianoguerra/wax-mb) for what that suite covers
and where the port has not reached parity yet.

**No dependencies.** This module imports nothing outside `moonbitlang/core`.
The command-line tool, which needs filesystem access, is a separate module:
`marianoguerra/wax-cli`.

Every example below is a test in [`facade_test.mbt`](facade_test.mbt) and
[`ast/build/build_test.mbt`](ast/build/build_test.mbt), so `moon test` is what
says this page is still true.

## Source in, wasm out

```moonbit
let src =
  #|#[export]
  #|fn add(x: i32, y: i32) -> i32 { x + y; }
  #|
let bytes = match @wax.compile_string(src) {
  Ok(b) => b
  Err(diagnostics) => ...   // nothing compiled; these say why
}
```

`Err` carries the diagnostics that stopped it and nothing else: a compile that
reports an error produces no bytes at all, rather than bytes derived from a
module known to be wrong.

`compile_string_to_wat` takes the same route as far as the lowered module and
prints it instead of encoding it, so the two forms cannot describe different
modules:

```moonbit
let text = @wax.compile_string_to_wat("fn one() -> i32 { 1; }")
// (func $one (result i32) (i32.const 1))
```

## Source in, source out

The formatter is a front-end operation: it does not type-check, because a module
that does not type-check still has a canonical layout. `Err` therefore only ever
holds syntax errors.

```moonbit
@wax.format_string("fn f()->i32{1;}")
// Ok("fn f() -> i32 {\n    1;\n}")
```

## AST in, wasm out

This is the path a code generator wants, and the reason the module is laid out
the way it is. Import `marianoguerra/wax/compile` rather than
`marianoguerra/wax`, and **the lexer, the token table and the generated LR
parser are never compiled** — about 8k lines, most of it a table nobody wrote by
hand.

`marianoguerra/wax/ast/build` has smart constructors for the module fields;
anything it does not cover is a plain `@ast` value written out by hand, and the
two mix freely.

```moonbit
let i32_ : @wasm_types.ValType[@ast.Ident] = I32
let m : @ast.LocModule = [
  @build.func(
    "add",
    params=[(Some("x"), i32_), (Some("y"), i32_)],
    results=[i32_],
    body=[
      @ast.no_loc_instr(
        BinOpI(
          @basic.no_loc(Add),
          @ast.no_loc_instr(Get(@build.ident("x"))),
          @ast.no_loc_instr(Get(@build.ident("y"))),
        ),
      ),
    ],
    attributes=[@build.exported()],
  ),
]

let session = @compile.Session::new()
let checked = session.check(m)
if @compile.rejected(session.reports()) {
  // report and stop
} else {
  let bytes = checked.to_bytes()   // or checked.to_wat()
}
```

`check` returns a `Checked` even for a module it rejected, because whether a run
is rejected is not its decision: a named warning is hidden, shown or promoted to
an error by a `@warning.Policy` the caller owns. Ask `reports(policy?)` for the
diagnostics under that policy, `rejected` whether they stop you, and only then
lower.

**Give your builders locations.** Every constructor in `ast/build` takes
`at~ : @basic.Location`, defaulting to `@basic.dummy_loc`. Mapping your own
source spans into it costs one argument and buys the entire diagnostic renderer
— the snippet, the caret, the related labels, the quick fixes — pointing at
*your* syntax rather than at nothing.

**A binding's location has to be distinct.** A local's wasm slot is keyed by the
offset its name was written at — that is what lets a shadowing `let` take a new
slot while the old name is still readable in its own initializer. So the names
in two `let`s, or in two `match` arms, of one function must not share a span.
Nothing parsed can violate that; a generated tree can, by building every
identifier at `dummy_loc`. Doing so is refused rather than emitted
(`@wasm.AmbiguousBinding`), since the module it would produce is wrong rather
than invalid. A generator with no source text of its own mints spans instead:

```moonbit
let s = @build.Spans::new()          // or Spans::new(fname="my.dsl")
let body = [
  s.instr(Let([(Some(s.ident("a")), Some(i32_))], Some(s.instr(Int("1"))))),
  s.instr(Get(s.ident("a"))),
]
```

Each span is a line of its own, so a diagnostic names the node (`File
"<generated>", line 7`) even with no text behind it.

## The packages

| package | |
|---|---|
| `wax` | the facade above: parse, format, compile, one call each |
| `wax/compile` | `Session` and `Checked`: the AST-first pipeline, no front end |
| `wax/ast`, `wax/ast/build` | the syntax tree, and constructors for it |
| `wax/syntax/{lexer,tokens,parser,trivia}` | the front end |
| `wax/fmt` | the formatter |
| `wax/check`, `wax/check/{env,store,infer,members}` | the type checker |
| `wax/emit/wasm` | Wax → the wasm module model |
| `wax/wasm/{types,bin,wat,simd,atomics}` | the wasm model, its encoder and its printer — no Wax anywhere in them |
| `wax/{basic,diagnostic,message,printer,colors,warning,feature,cond,unicode}` | spans, diagnostics and layout |

`wax/internal/*` is private to this module: MoonBit refuses the import from
outside it.

## Stability

Version 0.1. Treated as stable, and changed only with a version bump: the `wax`
facade, `wax/compile`, `wax/ast` and `wax/ast/build`, `wax/wasm/*`, `wax/basic`,
`wax/diagnostic`, `wax/message`, `wax/warning`, `wax/feature`, and the entry
points `@grammar.parse_string` / `parse_recover`, `@output.render`,
`@typing.check_module` and `@to_wasm.lower_module`.

Everything else is 0.x-mutable.

Before the first release the surface was cut from 1117 public names to 684 —
`wax/check` alone from 349 to 103 — on one rule: a name nothing outside its own
package referenced was not a promise, whatever it was doing in a `.mbti`.
What is left in the checker is mostly reached by its own tests.
`tools/api_audit.py` in the repository reports the remainder, and that surface
is being narrowed rather than widened.

## Licence

Apache-2.0, matching the reference implementation this is ported from. See
[`NOTICE`](NOTICE) for the vendored `wasm_core` encoder.
