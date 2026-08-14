# wax-mb

A MoonBit implementation of **Wax**: parser, formatter, type checker, and
emitters for both the binary and the text form of WebAssembly.

[Wax](https://github.com/ocsigen/wax) is a Rust-like surface syntax for
WebAssembly — this reads as a programming language:

```rust
#[export]
fn add(x: i32, y: i32) -> i32 {
    x + y;
}
```

and compiles to the same bytecode as the equivalent stack-machine WAT.

## Three modules

This repository is a `moon.work` workspace. Two of its modules are published;
the third is the harness that keeps them honest.

| | | |
|---|---|---|
| [`lib/`](lib/README.md) | `marianoguerra/wax` | the language. **No dependencies** outside `moonbitlang/core`. |
| [`cli/`](cli/README.md) | `marianoguerra/wax-cli` | the `wax-mb` binary: convert, format, check. |
| `.` (the root) | `marianoguerra/wax-dev` | not published: the differential suite, the corpus, the porting tools, the alternative layout engine. |

The split is not cosmetic. A module's dependencies are fetched by everyone who
depends on it, whether or not they import the packages that use them — so the
only way for the library to cost an embedder nothing is for the CLI's filesystem
access and the harness's test tooling to live in different modules.

`marianoguerra/wax-dev` reaches the other two only through their *public* API,
which is what keeps that API honest: anything it needs is, by construction, a
name that has to stay public.

## Two ways in

**With the front end.** Import `marianoguerra/wax` and hand it source:

```moonbit
@wax.compile_string(src)         // -> Result[Bytes, Array[Diagnostic]]
@wax.compile_string_to_wat(src)  // the same lowering, printed
@wax.format_string(src)          // reformat, no type checking
```

**Without it.** A code generator that builds `@ast` values itself imports
`marianoguerra/wax/compile` and `marianoguerra/wax/ast/build` instead, and never
compiles the lexer, the token table or the generated LR parser — about 8k lines.
`just embed-smoke` is that claim, tested: it builds such a consumer outside the
workspace and fails if the parser turns up in its build tree. A generator that
has no source spans of its own to thread should mint them with
`@build.Spans` — locals are keyed by where their name was written, so a whole
function's identifiers cannot share one location.

See [`lib/README.md`](lib/README.md) for both paths in full.

## Equivalence, not resemblance

The point of this port is to be *provably* equivalent to the reference
implementation, so the test strategy is the primary design constraint.
`tools/waxdiff.py` runs both implementations over a ~2000-module corpus and
gates on:

1. **Reprint parity** — `wax f.wax -f wax` and `wax-mb f.wax` must agree byte
   for byte. This needs no type checker: a same-format conversion in the
   reference only re-prints, and is not validated.
2. **Wasm equivalence** — the bytes must match, whether reached through the
   reference's back end recompiling our reprint or through our own.
3. **Error parity** — the same diagnostics at the same spans with the same exit
   code. Spans and severity are gated; message wording is tracked in
   `test/report/message-drift.md` and tightened over time.
4. **WAT parity** — `-f wat` against the reference's, reported rather than
   gated while the text printer is still reaching the whole corpus.

Plus the reference's own **cram tests**, run against `wax-mb` unedited: the only
coverage of the CLI's behaviour rather than the library's.

## Build

Every task lives in the [`justfile`](justfile), which doubles as the index of
what can be done here — `just` on its own lists them, grouped:

```sh
just check        # moon check --deny-warn, across all three modules
just test         # unit tests
just diff         # the differential suite, against the committed goldens
just quick        # all of the above plus the cram tests: the pre-commit gate
just ci           # everything CI enforces, in CI's order
just embed-smoke  # an AST-first consumer does not compile the front end
just api-audit    # public names nothing outside their package uses
```

The differential suite is **hermetic**: `test/corpus/` and `test/golden/` are
committed, so it needs neither the reference binary nor the reference sources.

Regenerating them does need both, and is a deliberate act — you do it when
moving to a newer upstream commit, and the resulting diff is the review artifact
showing what upstream's behaviour change actually was:

```sh
just reference         # the pinned reference binary (needs `gh`)
just reference-source  # the pinned reference sources, into wax/
just corpus            # rebuild test/corpus/
just goldens           # rebuild test/golden/
```

Both pins live in `tools/reference.json` and must agree; see
[`AGENTS.md`](AGENTS.md).

## Publishing

```sh
just publish-dry   # the full CI gate, then both dry runs
just publish       # lib first: wax-cli's manifest pins a version of it
```

## Licence

Apache-2.0, matching the reference implementation this is ported from. See
[`NOTICE`](NOTICE) for the vendored `wasm_core` encoder.
