# Agent guide

This is a [MoonBit](https://docs.moonbitlang.com) project: a port of the **Wax**
front end (lexer, AST, parser, formatter) from OCaml to MoonBit.

Wax is a Rust-like surface syntax for WebAssembly. The reference implementation
is [ocsigen/wax](https://github.com/ocsigen/wax).

## The two reference checkouts

Both are gitignored siblings of this module, cloned for reference only. **Never
edit them.**

- `wax/` — the OCaml implementation being ported. The front-end slice lives in
  `src/lib-wax/` (`lexer.ml`, `parser.mly`, `ast.mli`, `output.ml`) and
  `src/lib-utils/` (`trivia.ml`, `printer.ml`, `diagnostic.ml`, `message.ml`).
  Everything under `typing.ml`, `validation.ml`, `to_wasm.ml`, `from_wasm.ml` is
  out of scope for now.
- `parser/` — [moonbitlang/parser](https://github.com/moonbitlang/parser), the
  MoonBit language's own parser written in MoonBit. This is the **structural**
  template: package layering, `moon.pkg` conventions, moonyacc codegen wiring,
  snapshot-test style. Note its `AGENTS.md` warning applies there too — read
  `.mbty` grammar sources, not the huge generated `.mbt` files.

## Non-negotiable: the reference is the specification

This port is only worth having if it is *provably* equivalent to the reference.
Correctness is not decided by reading the OCaml and agreeing that the MoonBit
looks similar — it is decided by `cmd/waxdiff`, which runs both implementations
over a ~1000-file corpus and compares:

1. **Reprint parity** — `wax f.wax -f wax` vs `wax-mb fmt f.wax`, byte for byte.
2. **Wasm equivalence** — our printed output, fed back through the reference
   back end, must produce a byte-identical `.wasm`.
3. **Error parity** — same diagnostics at the same spans with the same exit code.

If you change front-end behaviour, run the harness. Do not "fix" a golden file
to make a test pass; a golden diff means either you changed behaviour or
upstream did, and both need explaining.

## The two pins

`tools/reference.json` holds both, and they must agree:

| pin | what it fixes | restore with |
|---|---|---|
| `sha256` / `upstream_commit` | the **binary** the harness tests against | `tools/fetch-reference.sh` |
| `ported_from_commit` | the **sources** being ported, in `wax/` | `tools/fetch-reference-source.sh` |

Skew between them is silent and destructive, which is why they live in one file
and are restored by scripts rather than by hand. This already bit us once: the
obvious choice of oracle, the npm package `@wax-wasm/wax`, turned out to be
0.1.0 — 328 commits behind the checkout, with `parser.mly`, `output.ml` and
`lexer.ml` substantially rewritten in between, and the whole `parser_messages`
generator not yet existing. It would have silently disagreed with the sources.

`fetch-reference.sh` verifies the binary's sha256 and **fails loudly if
upstream's `edge` release moved**, since `edge` is rebuilt on every push to main.

## The suite is hermetic; keep it that way

`test/corpus/` and `test/golden/` are **committed**. That is what lets
`waxdiff.py run` execute with neither the `wax/` checkout nor the reference
binary present — CI needs only this repository.

`wax/` is read-only reference material, used for exactly two things: as the
source the port is written from, and as the input to `waxdiff collect`. The
latter runs rarely, only when deliberately moving the pin. **Never make it a
build or CI input** — the moment that happens the hermetic property is gone.

Regenerating the corpus and goldens is a deliberate act, and the resulting diff
is the point: it shows exactly what upstream's behaviour change was.

## The second layout engine

`printer_pp` lays the same documents out with
[marianoguerra/pretty-fast-pretty-printer](https://mooncakes.io/docs/marianoguerra/pretty-fast-pretty-printer@0.2.1)
instead of the engine ported from `printer.ml`. Only the layout is swapped: both
are driven by the same `@printer.Printer`, whose token stream is
engine-independent, so `just ppdiff` compares them on the same document over the
same corpus. All 1903 modules come out byte-identical, and `ppdiff` exits
non-zero if that stops being true. `printer_pp/README.md` says what it took, and
which parts of the reconciliation the corpus does not exercise.

It is not in the shipped path: `@output.render`, the CLI and all three oracles
go through `printer`, and nothing about equivalence to the reference is decided
here. A divergence is not automatically a bug in the formatter -- it is more
likely one in `printer_pp`'s lowering -- but it always wants explaining.

## Conventions (follow `parser/`)

- Config is the **new DSL**, not JSON: `moon.mod`, `moon.pkg`. Deps go in an
  `import { ... }` block, with a separate `import { ... } for "test"` block for
  test-only deps (and `for "wbtest"` for white-box tests).
- `///|` before every top-level item.
- `_test.mbt` = black-box, `_wbtest.mbt` = white-box.
- `pkg.generated.mbti` is committed for every package; CI enforces that it is
  current. A diff there is a public-API change.
- Generated sources opt out of the formatter: `formatter(ignore: [...])`.
- Snapshot tests use `fn @test.Test::run(t : Self)` + `t.snapshot(...)`, updated
  with `moon test -u`.

## Checks CI enforces

```sh
moon check --deny-warn
moon info --target all && git diff --exit-code   # .mbti files current
moon fmt && git diff --exit-code                 # formatted
moon test --target all
```

## Porting notes that are easy to get wrong

- **Columns.** The reference emits **0-based** columns in `--error-format json`
  and **1-based** columns in its human and short renderers, from the same
  position record. `Position::column0` and `Position::column1` exist so the call
  site has to say which it means.
- **`dummy_pos.cnum` is `-1`, not `0`.** The reference's no-source error path
  tests for exactly that sentinel; `0` is a legitimate offset.
- **Numeric literals stay raw strings** (`Int(String)`, `Float(String)`) through
  the whole front end. Parsing them early would break round-tripping and would
  break the type checker's flexible-literal inference later.
- **The AST is generic over its annotation type** (`Info`) and the wasm type
  family is generic over `Idx`. Neither is used at more than one instantiation
  today. Both are kept because the type checker will be ported later, and
  collapsing them now would make that a rewrite rather than an extension.
