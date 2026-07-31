# wax-mb

A MoonBit implementation of the **Wax** front end: lexer, AST, parser, and
formatter.

[Wax](https://github.com/ocsigen/wax) is a Rust-like surface syntax for
WebAssembly — this reads as a programming language:

```rust
fn add(x: i32, y: i32) -> i32 {
    x + y;
}
```

and compiles to the same bytecode as the equivalent stack-machine WAT.

## Status

Early. See [`AGENTS.md`](AGENTS.md) for the working conventions and
[the plan](https://github.com/) for the phase breakdown.

| Phase | | |
|---|---|---|
| 0 | scaffolding + differential harness | in progress |
| 1 | `basic`, `tokens`, `lexer` | |
| 2 | AST + moonyacc grammar | |
| 3 | printer + formatter | |
| 4 | CLI + diagnostic rendering | |
| 5 | hardening | |

The type checker (`typing.ml`, 13k lines in the reference) is **not** in scope
yet, but every structural decision here is made so that adding it later is an
extension rather than a rewrite.

## Equivalence, not resemblance

The point of this port is to be *provably* equivalent to the reference
implementation, so the test strategy is the primary design constraint.
`cmd/waxdiff` runs both implementations over a ~1000-file corpus and gates on
three oracles:

1. **Reprint parity** — `wax f.wax -f wax` and `wax-mb fmt f.wax` must agree
   byte for byte. This exercises exactly this project's scope, with no type
   checker involved, because a same-format conversion in the reference only
   re-prints and is not validated.
2. **Wasm equivalence** — our printed output, fed back through the *reference*
   back end, must produce a byte-identical `.wasm`. This tests that the AST
   preserved everything semantically relevant, without needing a code generator
   of our own.
3. **Error parity** — the same diagnostics at the same spans with the same exit
   code. Spans and offsets are gated; message wording is tracked separately and
   tightened over time.

## Build

```sh
moon check --deny-warn
moon test
tools/waxdiff.py run          # differential suite (runs against committed goldens)
```

The differential suite is **hermetic**: `test/corpus/` and `test/golden/` are
committed, so it needs neither the reference binary nor the reference sources.

Regenerating them does need both, and is a deliberate act — you do it when
moving to a newer upstream commit, and the resulting diff is the review artifact
showing what upstream's behaviour change actually was:

```sh
tools/fetch-reference.sh         # the pinned reference binary (needs `gh`)
tools/fetch-reference-source.sh  # the pinned reference sources, into wax/
tools/waxdiff.py collect         # rebuild test/corpus/
tools/waxdiff.py golden          # rebuild test/golden/
```

Both pins live in `tools/reference.json` and must agree; see `AGENTS.md`.

## Licence

Apache-2.0, matching the reference implementation this is ported from.
