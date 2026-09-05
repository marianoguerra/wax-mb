# Agent guide

This is a [MoonBit](https://docs.moonbitlang.com) project: a port of **Wax** --
lexer, AST, parser, formatter, type checker and the wasm/wat emitters -- from
OCaml to MoonBit.

Wax is a Rust-like surface syntax for WebAssembly. The reference implementation
is [ocsigen/wax](https://github.com/ocsigen/wax).

## Three modules in one workspace

`moon.work` lists them. Every `moon` command below runs at the repository root
and covers all three.

| directory | module | published |
|---|---|---|
| `lib/` | `marianoguerra/wax` | yes -- **and it has no dependencies**; keep it that way |
| `cli/` | `marianoguerra/wax-cli` | yes; `moonbitlang/x` lives here |
| `was/` | `marianoguerra/was` | yes; depends on `wax`, `shrubbery` and `error-report` |
| `wap/` | `marianoguerra/wap` | yes; depends on `wax`, `shrubbery` and `error-report` |
| `.` (root) | `marianoguerra/wax-dev` | no: `test/`, `tools/`, `printer_pp/` |

The root is a module rather than a bare workspace so that `test/corpus/`,
`test/golden/` and `tools/` keep the paths the Python harness, the justfile and
this document already use.

Two rules follow from the split, and both are load-bearing:

- **Nothing goes in `lib/moon.mod`'s dependencies.** A module's dependencies are
  fetched by every consumer regardless of which packages they import, so one
  convenience dependency there is paid for by every project that wanted only the
  type checker. If something in `lib/` needs a dependency, that is a design
  question, not a manifest edit.
- **`wax-dev` reaches the other two through their public API only.** That is
  what keeps the API honest -- whatever the harness needs is, by construction, a
  name that has to stay public. Do not "fix" a harness import by widening
  `lib/`'s surface without deciding that the name is a promise.

`was/` and `wap/` are front ends and never back ends: it reaches Wax through
`marianoguerra/wax/ast`, `.../ast/build` and `.../compile`, and never through
the Wax parser. A wap program does not become Wax source text on its way to
wasm. `wap/ast` additionally does not import `marianoguerra/wax` at all, so a
generator that builds wap values does not compile a type checker to do it --
the same rule, and for the same reason, as `lib/`'s two ways in.

`lib/internal/*` is enforced by the compiler: `marianoguerra/wax/internal/x` is
importable only from inside `marianoguerra/wax`, so neither `cli` nor `dev` can
reach it.

## Package layout in `lib/`

Grouped by layer, and the alias each is imported under is NOT always its
directory name -- the aliases predate the grouping and the sources read the same
as they did:

| directory | alias |
|---|---|
| `syntax/{tokens,lexer,trivia}` | as named |
| `syntax/parser` | `@grammar` |
| `fmt` | `@output` |
| `check` | `@typing` |
| `check/{env,store,infer,members}` | `@typing_env`, `@type_store`, as named |
| `emit/wasm` | `@to_wasm` |
| `wasm/{types,bin,wat}` | `@wasm_types`, `@wasm_bin`, `@to_wat` |
| `wasm/{simd,atomics}` | as named |
| `internal/{spell,number,cond_explore}` | as named |

A black-box test package sees its own package under the DIRECTORY name, so the
six packages whose alias differs re-import themselves under the alias in their
`for "test"` block. That is why `lib/check/moon.pkg` imports
`"marianoguerra/wax/check" @typing`.

## The reference checkout

`wax/` is gitignored, at the repository root, cloned for reference only.
**Never edit it**, and never let it become a build or CI input.

It is the OCaml implementation being ported. The front-end slice lives in
`src/lib-wax/` (`lexer.ml`, `parser.mly`, `ast.mli`, `output.ml`) and
`src/lib-utils/` (`trivia.ml`, `printer.ml`, `diagnostic.ml`, `message.ml`);
the checker and the emitters in `typing.ml`, `validation.ml`, `to_wasm.ml` and
`wasm_output.ml`. Only `from_wasm.ml` is still out of scope.

There used to be a second checkout,
[moonbitlang/parser](https://github.com/moonbitlang/parser) (the MoonBit
language's own parser, written in MoonBit), kept as the **structural** template
for package layering, `moon.pkg` conventions, moonyacc codegen wiring and
snapshot-test style. It has done its job: those conventions are now this
repository's own, written down below. It was 207 MB for a reading reference,
and an unanchored `parser/` in `.gitignore` for it silently swallowed
`lib/syntax/parser/` out of the published package. Clone it again if a new
structural question comes up:

```sh
git clone https://github.com/moonbitlang/parser   # was pinned at 7f1efb3b
```

## Non-negotiable: the reference is the specification

This port is only worth having if it is *provably* equivalent to the reference.
Correctness is not decided by reading the OCaml and agreeing that the MoonBit
looks similar — it is decided by `tools/waxdiff.py`, which runs both
implementations over a ~2000-module corpus and compares:

1. **Reprint parity** — `wax f.wax -f wax` vs `wax-mb f.wax`, byte for byte.
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
same corpus. All 1907 modules come out byte-identical, and `ppdiff` exits
non-zero if that stops being true. `printer_pp/README.md` says what it took, and
which parts of the reconciliation the corpus does not exercise.

It is not in the shipped path: `@output.render`, the CLI and all three oracles
go through `printer`, and nothing about equivalence to the reference is decided
here. A divergence is not automatically a bug in the formatter -- it is more
likely one in `printer_pp`'s lowering -- but it always wants explaining.

## Conventions

- Config is the **new DSL**, not JSON: `moon.work`, `moon.mod`, `moon.pkg`.
  Deps go in an `import { ... }` block, with a separate
  `import { ... } for "test"` block for test-only deps (and `for "wbtest"` for
  white-box tests). `moon fmt` reformats these files too, and strips comments
  from `moon.work` — put the explanation in this document instead.
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
tools/api_audit.py                               # reported, never gated
```

Before publishing, also:

```sh
just embed-smoke     # an AST-first consumer must not compile the front end
just publish-dry     # the full gate, then both `moon publish --dry-run`s
```

**Never run `moon publish` at the repository root.** With no `-C` it publishes
`marianoguerra/wax-dev` — the corpus, the porting tools, the alternative layout
engine — and `moon.mod` has no `private` field to forbid it. It fails today only
because `marianoguerra/wax` is not on the registry yet, which is an accident of
timing rather than a guard. Go through `just`, or `-C` a module by hand.

`tools/publish-dry.sh` is what `publish-dry` calls, because two things about
`moon publish --dry-run` need handling: it **exits 255 on a dry run the server
accepted** (it reports `202 Accepted, Dry run completed successfully` and then
`Error: moon publish failed`), and the `cli` rehearsal cannot resolve
`marianoguerra/wax` until `lib` is published — the extracted zip reads the
registry, not this tree. The script believes the acceptance line, tolerates the
second case only while `wax` is genuinely absent from
`~/.moon/registry/index/user/marianoguerra/`, and refuses to address the root
module at all.

## Porting notes that are easy to get wrong

- **Columns.** The reference emits **0-based** columns in `--error-format json`
  and **1-based** columns in its human and short renderers, from the same
  position record. `Position::column0` and `Position::column1` exist so the call
  site has to say which it means.
- **`dummy_pos.cnum` is `-1`, not `0`.** The reference's no-source error path
  tests for exactly that sentinel; `0` is a legitimate offset.
- **A binding's offset is its identity.** Local slots (`Lowering::binding_slots`)
  and the unused-local and unused-label lints (`read_locals`, `used_labels`) are
  keyed by `name.loc.start.cnum`, so that a shadowing binding is a different key
  from the one it shadows. Two bindings in one function may therefore never share
  a span — impossible from the parser, easy from a generated tree built at
  `dummy_loc`, and refused with `AmbiguousBinding` rather than emitted.
  `@build.Spans` is what a generator with no source text uses instead.
- **Numeric literals stay raw strings** (`Int(String)`, `Float(String)`) through
  the whole front end. Parsing them early would break round-tripping and would
  break the type checker's flexible-literal inference later.
- **The AST is generic over its annotation type** (`Info`) and the wasm type
  family is generic over `Idx`. Neither is used at more than one instantiation
  today. Both are kept because the type checker will be ported later, and
  collapsing them now would make that a rewrite rather than an extension.
