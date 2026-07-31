# Implementation plan

Remaining work on the MoonBit port of the [Wax](https://github.com/ocsigen/wax)
toolchain. Phases 0–4 are done; what follows is everything still open, in the
order it makes sense to do it.

## Todo

**Near-term — close the gaps in what already exists**

- [x] 1. Point CI at the port, not at the reference
- [x] 2. Run the cram suite in CI
- [x] 3. Readable token names for the `Expecting …` list

**Phase 5 — harden the front end**

- [ ] 4. Reproduce the `Assuming that … is complete` subject phrase
- [ ] 5. Reproduce the related labels (`this statement`, `This '{' opens …`)
- [ ] 6. Diff-fuzzing
- [ ] 7. Error recovery and `--all-errors` *(research)*

**Phase 6 — the type checker**

- [ ] 8. `ast_utils` — the surface-form desugarings
- [ ] 9. `members` — the method and intrinsic table
- [ ] 10. `infer` — inference cells and the numeric-literal lattice
- [ ] 11. `typing_env` — symbol tables
- [ ] 12. `typing` — the checker
- [ ] 13. `typing_lint` / `typing_suggest` — the warnings and quick fixes
- [ ] 14. Flip the oracle policy to `full`

**Phase 7 — the back end and the conversions**

- [ ] 15. `to_wasm` + `text_to_binary` — emit wasm, and switch Oracle 2 to `--native`
- [ ] 16. `validation` — the wasm validator
- [ ] 17. `from_wasm` — the decompiler, which unlocks most of the cram suite

---

## Where things stand

| | |
|---|---|
| MoonBit source | ~34.5k lines across 16 packages (`basic` `tokens` `lexer` `trivia` `wasm_types` `ast` `grammar` `unicode` `colors` `message` `warning` `printer` `output` `diagnostic` `io` `cmd/wax-mb`) |
| Oracle 1 — reprint parity | 1903 / 1903 byte-exact, idempotence gated alongside |
| Oracle 2 — same wasm | 1592 / 1592 identical binaries |
| Oracle 3 — same errors | 2112 / 2112 on severity, file, spans, offsets, exit code |
| Unit tests | 135 |
| Message drift | 231 entries: 182 message text, 23 related labels, 26 span (the 7 finding-9 exemptions) |
| Upstream findings | 9, in `test/UPSTREAM-FINDINGS.md` |
| Cram tests in scope | 2 of 328; the other 326 are listed with reasons in `test/cram-scope.md` |

The three oracles are the gate for everything below. Any task that changes
behaviour has to leave them green, and `tools/waxdiff.py run --impl tools/wax-mb`
is the one command that says so.

---

## 1. Point CI at the port, not at the reference — done

**Done.** The `check` job now builds the native executable and runs
`tools/waxdiff.py run --oracle 1 --oracle 3 --impl tools/wax-mb`, so CI
exercises the port. It stays hermetic: no reference binary, no `wax/` checkout.

The harness self-test moved to its own job, `harness-self-test`, which fetches
the pinned reference and runs `waxdiff.py run --self-test` over all three
oracles (~90 s — this is also the only place oracle 2 runs in CI). It is
`continue-on-error: true` for the same reason `drift` is: its one external
dependency is the floating `edge` asset, so an upstream rebuild would otherwise
redden every PR for a reason unrelated to the change.

Two harness bugs surfaced while wiring it up, both fixed in `waxdiff.py`:

- `--self-test` failed on 7 files. The finding-9 span exemptions carry a
  staleness check ("listed but the spans now agree — did upstream fix it?"),
  and with `--impl` pointed at the reference the spans *always* agree. The
  exemptions describe the port, so the check is now suppressed under
  `--self-test` (`policy["self_test"]`).
- `--self-test` only *documented* that it used the reference; it inherited
  whatever `--impl` said. It now sets `impl` itself, so
  `--self-test --impl tools/wax-mb` cannot quietly mean something else.

Also: `need_reference()` checked the committed *wrapper*, which always exists,
rather than the gitignored binary it execs — so a missing reference produced
~8400 separate exit-127 failures instead of one clear message. It now checks
the asset named in `reference.json`.

**Summary.** `.github/workflows/check.yml` runs
`tools/waxdiff.py run --oracle 1 --oracle 3` with no `--impl`. That flag
defaults to `tools/wax-ref`, so CI is currently running the *reference against
its own goldens* — a harness self-test that passes no matter what the port
does. The port itself is not exercised by CI at all.

**Approach.** Add a `moon build --target native` step, then pass
`--impl tools/wax-mb`. Keep a separate self-test step (`--self-test`, which
already exists) so the harness is still validated, but make the two distinct
and clearly labelled. Oracle 2 stays out of CI: it alone needs the reference
binary to compile our output, and the hermetic property — CI needs neither the
reference nor the `wax/` checkout — is worth more than the extra coverage.

**Resources.** `.github/workflows/check.yml`; the `--impl` and `--self-test`
flags in `tools/waxdiff.py`; `tools/wax-mb` (the wrapper that locates the built
executable).

---

## 2. Run the cram suite in CI — done

**Done.** A `cram tests` step runs `tools/run-cram.sh` after the native build,
in the same hermetic `check` job. `classify-cram` is not run in CI, as planned.

`moon-cram` ships inside the `moonbit-linux-x86_64` tarball the install step
already fetches, so no extra install is needed — but the script hard-coded
`$HOME/.moon/bin/moon-cram`, and now resolves it from `PATH` first, failing
with a message rather than a bare "no such file".

Two false-green checks while wiring it up: the runner does catch a mismatch
(verified by corrupting an expectation — 1 passed, 1 failed, exit 1), and an
empty `test/cram/` used to report "0 passed, 0 failed" and exit 0. That now
fails: the suite is committed, so zero tests means a broken checkout or glob.

**Summary.** `tools/run-cram.sh` passes locally and is not wired into CI. It is
only two tests today, but it is the only thing covering the CLI's own
behaviour — exit codes, which stream output goes to, flag handling — and it
grows for free as capabilities land.

**Approach.** Add a step running `tools/run-cram.sh` after the native build.
Do **not** re-run `waxdiff.py classify-cram` in CI: classification invokes the
reference binary against a materialized copy of every test, which is slow and
needs the `wax/` checkout. `test/cram/` and `test/cram-scope.md` are committed
artifacts; regenerating them is a deliberate local act, like regenerating
goldens.

**Resources.** `tools/run-cram.sh`; `test/cram-scope.md`;
`waxdiff.py classify-cram`; `~/.moon/bin/moon-cram` (note it does *not* copy
fixtures into its sandbox the way dune's cram runner does — hence the wrapper).

---

## 3. Readable token names for the `Expecting …` list — done

**Done.** The `[names]` table turned out to be already ported (the value-carrying
tokens read "an identifier", not `'ident'`, in `tokens/expect_string.mbt` — it
was built from the same config in Phase 1). What was missing was everything
*around* the names, and that is what landed:

- **`tokens/expect_class.mbt`** — the two `[class …]` sections of
  `parser_messages.config`. `TokenKind::expect_class` returns the label; the
  collapse itself is `expecting_message`'s, since it fires only when **≥2**
  members are legal (a lone legal `+` rendered "an operator" would claim the
  other 26 are legal too).
- **`grammar/driver.mbt:expecting_message`** — collapse, dedupe, sort, and the
  Oxford-comma join (`a`, `a, or b`, `a, b, or c` — with the comma, as the
  reference's `format_human_list` writes it).
- **`grammar/driver_wbtest.mbt`** — 8 tests. Whitebox because the sharpest case
  (a class that must *not* collapse) needs a state no input reliably produces.

Two things deliberately left out, both blocked on the same missing information:
the `≤5` cap (without nonterminal names our lists routinely exceed 5 — what the
reference renders "an expression" reaches us as its 31-token FIRST set — so
capping would degrade nearly every message to a bare "Syntax error"), and the
`Assuming …` subject, which is task 4.

**The sort was the bug worth having found.** MoonBit's `Compare` for `String` is
**shortlex** — length first — so `sort()` put `'{'` ahead of `'do'`. OCaml's
`String.compare` is plain lexicographic, and matching it needs
`lexical_compare`. Anything in this port that sorts strings for parity with the
reference has the same trap.

**Effect.** `Expecting ';', '?', '(', '}', '[', '.', '!', '+', '-', '*', '/',
'/s', … 'as', 'is', 'on'.` (38 entries, declaration order) became
`Expecting '!', '(', '.', ';', '?', '[', 'as', 'is', 'on', '}', a comparison
operator, or an operator.` (12, sorted). Across the corpus the mean list is
14.8 → 13.8 entries: the collapse fires only where operators can follow (~10 of
the 180 messages, cutting those by two thirds), while the commonest message —
the 14-way module-field set, 144 of the 180 — has no class members and only
gains the ordering and the join.

**Drift is unchanged at 231, as expected**, and the plan's gate ("watch the
message count fall") turns out to be the wrong gate for this task: 153 of the
160 captured messages need the `Assuming …` clause before their text can match
at all. This work is the list-rendering half that task 4 then embeds.

**A caveat for task 4, found here.** MoonYacc's acceptable set is not always
Menhir's. On `#[if(VERSION 1)]` the reference says
`Expecting '(', ')', ',', or a comparison operator.` and we say
`Expecting '(', ')', '=', or a comparison operator.` — and *ours is the accurate
one*: after `ident` in a `condition`, `=` is a `condition_relop` and `,` is only
legal inside `ident "(" … ")"`. The reference's list is a merged state's union
(the "unblended contexts" case its own stele README describes). So even a
perfect port of the subject phrase will not reach 100 % message parity, and the
residue is not all ours.

**Summary.** Of the reference's syntax messages, 7 are a bare
`Expecting X, Y, or Z.` and the port already produces that shape. What differs
is the *rendering of each token* and the ordering. The reference names tokens
with a curated table; the port prints `TokenKind::to_expect_string()`.

**Approach.** Port the `[names]` section of
`wax/src/lib-wax/parser_messages.config` into the `tokens` package as a lookup
used by `to_expect_string`. The table exists precisely because auto-derived
names read as internal jargon — `IDENT` renders as `an identifier`, not
`'ident'`. Then match the list's ordering, deduplication, and the Oxford-comma
`X, Y, or Z` join. This is the cheapest slice of the drift and should land
before task 4, since task 4's messages embed the same list.

Gate it by watching the `message` count in `test/report/message-drift.md` fall,
not by eyeballing: `waxdiff.py run --oracle 3 --max-report 1000`.

**Resources.** `wax/src/lib-wax/parser_messages.config` (134 lines, with the
rationale in its header comments); `tokens/tokens.mbt`;
`grammar/driver.mbt:expecting_message`; `wax/vendor/stele/README.md` §Naming.

---

## 4. Reproduce the `Assuming that … is complete` subject phrase

**Summary.** This is the bulk of the drift: **153 of 160** captured reference
messages use the template `Assuming that the SUBJECT is/are complete,
expecting …`. The port emits only the `expecting` half, so almost every syntax
message differs by its opening clause.

The subject is not derivable from the expected-token set. It names the
*grammar symbol under construction* at the error state, which comes from the
LR automaton's item sets — the same information Menhir's `--list-errors`
exposes and which `stele` consumes.

**The obstacle.** MoonYacc's error value is
`UnexpectedToken(Token, (Pos, Pos), Array[TokenKind])` — the offending token,
its span, and the acceptable set. No state number, no item set, no stack. And
`moonyacc --help` offers no automaton dump: the flags are
`--print-as-mly-without-actions`, `--table`, `--mode`, and little else.

**Approach.** Three options, in increasing cost:

1. **Contribute upstream.** Ask MoonYacc to expose the error *state number* (or
   the item set) on `UnexpectedToken`. This is a small, generally useful change
   — every grammar wanting good messages needs it — and it turns the rest of
   this task into a table lookup. Try this first.
2. **Reconstruct the automaton.** Run `menhir --list-errors` against the
   reference's own `parser.mly` to enumerate error states and their sentences,
   then map each to a MoonYacc error by *replaying the sentence*: feed it to
   our parser and record which `(token, expected-set)` pair comes back. That
   gives a lookup keyed on data MoonYacc does hand back. Fragile if two states
   share an expected set — measure the collision rate before committing.
3. **Port stele.** ~3.8k lines of OCaml operating on Menhir's automaton. Only
   worth it if MoonYacc grows an automaton dump, in which case tasks 4 and 5
   collapse into one.

Whatever the route, `parser_messages.expected` is a committed golden of every
generated message, so correctness is checkable offline without running anything.

**Resources.** `wax/vendor/stele/` (README, TUTORIAL, `parse_messages.ml`);
`wax/src/lib-wax/parser_messages.expected` and `.verdicts` and `.census.expected`;
`wax/src/lib-wax/parser.automaton` (a committed automaton dump — the reference
data for option 2); Pottier, *Reachability and Error Diagnosis in LR(1)
Parsers* (CC 2016); `test/UPSTREAM-FINDINGS.md` for the MoonYacc gaps already
recorded.

---

## 5. Reproduce the related labels

**Summary.** 23 drift entries are `related`: the secondary spans a diagnostic
carries, rendered under the snippet as `^^^^ this statement` or
`^ This '{' opens the enclosing construct.` The port emits none — every
`Report` it builds has `related: []`.

The renderer is done: `diagnostic/` already draws multi-line spines, secondary
colours and labels, and there is a test pinning that output byte-for-byte
against the reference. What is missing is the *source* of the labels.

**Approach.** Same dependency as task 4 — the labels are derived from the
parser stack at the error state (the construct being built, and the token that
opened it). Do this immediately after task 4, reusing whatever mechanism that
task establishes. If option 1 lands, the stack is the natural thing to expose
alongside the state.

Note the labels are a *reported*, non-blocking field in
`test/oracle-policy.json`, so this improves diagnostics without unblocking
anything else.

**Resources.** `diagnostic/snippet.mbt` and `diagnostic/with_source.mbt` (the
renderer, already correct); `diagnostic/render_test.mbt` (the pinned multi-line
spine test); `grammar/driver.mbt` (where `related: []` is currently hard-coded);
`test/report/message-drift.md` for the 23 concrete cases.

---

## 6. Diff-fuzzing

**Summary.** The corpus is fixed: 2112 files, all hand-written, generated from
the spec suite, or extracted from docs. It exercises what someone thought to
write down. Fuzzing explores what nobody did.

**Approach.** Mutate corpus inputs and run all three oracles on each mutant.
The mutations that matter are the ones that stay *parseable* often enough to
reach the printer — byte-level noise mostly produces syntax errors, which only
exercises Oracle 3. Wax's own `fuzz/` scripts already solve this: token-level
mutation (swap, delete, duplicate) plus grammar-directed generation.

Wire it as a nightly CI job rather than a gate, and have a mutant that fails
any oracle get minimized and committed to `test/corpus/` — so a fuzz find turns
into a permanent regression test rather than a transient report.

**Resources.** `wax/fuzz/` — `mutate-wax.sh` and `wax-fault-mutate.js` are the
Wax-side mutators; `null-mutate.sh`, `exec-mutate.sh` and the `*-gen.awk`
generators are the rest of the kit, and `wax/fuzz/README.md` explains how they
compose. Also `wax/src/bin/fuzz_gen.ml`, `fuzz_mutate.ml`, `fuzz_recover.ml`;
`tools/waxdiff.py run --filter`. Note `wax/fuzz/` also produced the fixture
behind upstream finding 1 (the 2.1 GB DoS), so run mutants under the memory cap
described in `tools/waxdiff.py` (`WAXDIFF_MEM_CAP`).

---

## 7. Error recovery and `--all-errors` *(research)*

**Summary.** The single largest structural gap. MoonYacc has no error recovery
(`doc/MANUAL.md`: *"MoonYacc does not support error recovery at the moment."*),
so the port reports exactly one syntax error and stops. That matches the
reference's **default** `check`/`convert` path, which is why Phases 1–4 were
unaffected — but it blocks `--all-errors`, blocks the 3 cram tests excluded for
it, and blocks any future LSP.

**Approach.** Recovery has to live *outside* the generated parser: on
`UnexpectedToken`, classify the token array with the reference's own sync
categories (`Open | Close | Boundary | Leader | Terminal | Skip`), splice a
repair, and re-invoke the parser from the top. This is cruder than Menhir's
stack-unwinding recovery — it will not reproduce
`wax/test/recovery/test_recover.expected` — and re-parsing from scratch per
error is quadratic on a file with many errors.

The better answer is to contribute recovery to MoonYacc, which also serves
task 4. Treat this as research: prototype the resync loop first to learn what
recovery quality is reachable, then decide between shipping it and pushing
upstream.

**Resources.** `wax/src/lib-wax/recover.ml` (63 lines — the sync
classification, small and readable); `wax/test/recovery/test_recover.expected`;
`wax/src/bin/fuzz_recover.ml`; MoonYacc's `doc/MANUAL.md`;
`test/cram-scope.md` for the tests this unblocks.

---

## 8. `ast_utils` — the surface-form desugarings

**Summary.** `lower_match`, `lower_while`, `lower_dispatch`: the transforms
turning the surface constructors into the core forms the checker and the code
generator understand. The AST already carries those constructors faithfully —
that was a deliberate Phase 2 commitment — so this is additive.

**Approach.** Port `ast_utils.ml` directly. It is the natural first step of
Phase 6: it is self-contained, it has no dependency on the type checker, and
getting it right is checkable in isolation with AST snapshot tests. Doing it
first also validates that the surface constructors really are faithful before
13k lines of checker are built on that assumption.

**Resources.** `wax/src/lib-wax/ast_utils.ml` (915 lines) and `.mli`;
`ast/` (the constructors it consumes); `ast/json.mbt` for snapshots;
`test/__snapshot__/`.

---

## 9. `members` — the method and intrinsic table

**Summary.** The table behind `x.extend8_s()`, `i64::add128`, `m.load32(…)` —
which receiver types have which methods, and what each lowers to. Needed
before the checker can resolve a method call.

**Approach.** Port `members.ml` directly. It is mostly data, so the work is
transcription plus a test asserting the table's size and a sample of entries
against the reference. Worth doing before `typing` since the checker indexes
into it constantly.

**Resources.** `wax/src/lib-wax/members.ml` (450 lines) and `.mli`;
`wax/skills/wax/reference.md` (the user-facing list of the same methods, useful
as a cross-check).

---

## 10. `infer` — inference cells and the numeric-literal lattice

**Summary.** The unification substrate: mutable inference cells, and the
lattice that lets `1` be an `i32` or an `i64` until context decides. This is
what makes keeping numeric literals as raw strings pay off — a Phase 2
commitment made specifically for it.

**Approach.** Port `infer.ml`. It is small (207 lines) but subtle, and it is
the piece most worth unit-testing exhaustively before anything depends on it:
the lattice's join and its interaction with explicit annotations are where
type-checker bugs hide.

**Resources.** `wax/src/lib-wax/infer.ml` (207 lines) and `.mli`;
`ast/instr.mbt` (`Int(String)` / `Float(String)` — the raw literals).

---

## 11. `typing_env` — symbol tables

**Summary.** Scopes and bindings: locals, labels, globals, functions, types,
tags. Straightforward, and a prerequisite for the checker.

**Approach.** Port `typing_env.ml`. Watch the recovery-mode interaction: the
`diagnostic` package already carries `set_recovery` / `in_recovery`, whose
whole purpose is to let the checker suppress "not bound" cascades when name
resolution is unreliable. That plumbing is in place and unused; this is where
it starts mattering.

**Resources.** `wax/src/lib-wax/typing_env.ml` (461 lines) and `.mli`;
`diagnostic/context.mbt` (`recovery`).

---

## 12. `typing` — the checker

**Summary.** 13,286 lines, roughly **3× the entire front end**. Treat it as its
own project with its own phase plan, not as one task.

**Approach.** Decompose along the checker's own structure (declarations,
instructions, control flow, reference types, the GC proposal, stack switching)
and gate each slice by moving corpus files from "must stay silent" to "must
reproduce the reference's diagnostics". The harness supports this
incrementally: `test/oracle-policy.json` is data, and the `type-bad` bucket is
exactly the set that flips.

Do not flip the whole bucket at once. Add an intermediate scope between
`front-end` and `full` that flips subsets, so progress is measurable and
regressions are attributable.

**Resources.** `wax/src/lib-wax/typing.ml` (13,286 lines) and `.mli`;
`test/oracle-policy.json` (the `scopes` map); the 311 `type-bad` corpus files
in `test/golden/index.json`; `wax/docs/src/` for the language semantics.

---

## 13. `typing_lint` / `typing_suggest` — the warnings and quick fixes

**Summary.** The 23 named warnings and the three machine-applicable
suggestions. The `warning` package — names, groups, `-W` policy, default
levels — is already ported in full and tested; the `diagnostic` package already
renders warnings, suggestions, hints and edits. What is missing is only the
analysis that decides *when* to report.

**Approach.** Port `typing_lint.ml` and `typing_suggest.ml` after the checker.
Each lint is independently gateable: turn one on, watch the corpus, move on.
Note this unblocks 28 cram tests excluded for "exercises a lint" plus the one
using `WAX_WARN`.

One lint is already half-done: `confusing_precedence` in `output/prec.mbt` was
ported during Phase 3 because the *printer* consults the same table to decide
parenthesisation. The lint side reuses it.

**Resources.** `wax/src/lib-wax/typing_lint.ml` (1012 lines),
`typing_suggest.ml` (265 lines); `warning/` (already complete);
`output/prec.mbt:confusing_precedence`; `test/cram-scope.md` for the tests this
unblocks.

---

## 14. Flip the oracle policy to `full`

**Summary.** The Phase 6 finish line. `test/oracle-policy.json` already
contains a `full` scope: `type-bad` becomes a positive error-parity test and
`compiles-clean` gains one. Switching `scope` is the whole change — the corpus,
the buckets and the goldens all stay as they are.

**Approach.** Flip it, run the harness, and burn down what fails. This was the
point of making the bucket→expectation mapping configuration rather than code
back in Phase 0, and it should be a genuinely small commit.

**Resources.** `test/oracle-policy.json`; `tools/waxdiff.py`'s `--scope` flag.

---

## 15. `to_wasm` + `text_to_binary` — emit wasm

**Summary.** The code generator. Oracle 2 currently proves our *printed Wax*
round-trips to identical wasm by routing it through the reference back end. A
native back end lets it compare our own emitted binary directly — a strictly
stronger claim, since the reference back end currently launders any AST detail
the printer happens to reproduce faithfully.

**Approach.** Port `to_wasm.ml` then `text_to_binary.ml`. The `wasm_types`
package is already generic over `Idx` precisely so a binary/index instance
exists without touching the Wax AST — a Phase 2 commitment made for this.

Note a gap to close first: `check_oracle2` in `tools/waxdiff.py` **hard-codes
the via-reference route**. The original design called for a
`--via-reference` / `--native` mode flag from day one so this transition would
be a flag change; that flag was never built. Add it before porting the back
end, so the switch is a one-line change and both routes stay runnable — keeping
via-reference available is worth it, since a disagreement between the two
routes localizes a bug to the code generator rather than the printer. The
golden `wasm_sha256` values in `test/golden/index.json` are already the right
comparison target for both.

**Resources.** `wax/src/lib-conversion/to_wasm.ml` (3002 lines);
`wax/src/lib-wasm/text_to_binary.ml` (1247 lines); `wasm_types/` (the
`Idx`-generic spine); `tools/waxdiff.py:check_oracle2`; `wasm-tools print` for
readable diffs of mismatched binaries.

---

## 16. `validation` — the wasm validator

**Summary.** 6694 lines. Independent of the Wax type checker: it validates
*wasm*, and is what `-v` / `--validate` invoke. Unblocks the 20 cram tests
excluded for `--validate`.

**Approach.** Port after the code generator, since its natural test is
"validate what we just emitted". Its diagnostics use the `wat` palette rather
than the `wax` one — `colors.wat_theme` is already ported for exactly this, and
`diagnostic.run` takes the palette as a required parameter so the choice cannot
be defaulted by accident.

**Resources.** `wax/src/lib-wasm/validation.ml` (6694 lines);
`colors/colors.mbt:wat_theme`; `test/cram-scope.md`.

---

## 17. `from_wasm` — the decompiler

**Summary.** 5124 lines, plus ~1800 in the `recover_*` and `sink_let` passes
that reconstruct Wax's structured forms (`match`, `try`/`catch`, loops,
`dispatch`) from flat wasm. This is what turns `wat`/`wasm` input into Wax.

**Why it is last but valuable.** It is the single biggest unlock for the test
suite: **229 of the 326 excluded cram tests** are excluded for wat/wasm
conversion. Nothing else moves that number.

**Approach.** Port `from_wasm.ml` and a binary reader first, then the
`recover_*` passes one at a time — each reconstructs one surface form and each
is independently testable by decompiling and re-checking against the reference.
The three from-wasm renaming warnings (`naming-conflict`,
`reserved-word-rename`, `generated-name`) are already defined in `warning/` and
default to hidden; this is what makes them reachable.

**Resources.** `wax/src/lib-conversion/from_wasm.ml` (5124 lines),
`recover_match.ml` (401), `recover_trycatch.ml` (303), `recover_loops.ml` (281),
`recover_dispatch.ml` (141), `sink_let.ml` (655), `namespace.ml`, `naming.ml`;
`wax/src/lib-wasm/binary_to_text.ml`; `test/cram-scope.md`.

---

## Notes that outlive any one task

- **The reference is pinned, and both the binary and the source commit.**
  `tools/reference.json` records the sha256 and the commit it was built from.
  A nightly CI job checks it against upstream `edge`; it reports, it does not
  gate. Regenerating goldens is a deliberate local act.
- **`wax/` and `parser/` are reference checkouts, never build inputs.** They are
  gitignored. The moment CI needs them, the hermetic property is gone.
- **Divergences are recorded, not absorbed.** `test/UPSTREAM-FINDINGS.md` holds
  9 findings. Two of them (7 and 8) are exemptions in the idempotence gate and
  one (9) in the span gate — and each is written so the harness *fails* if
  upstream fixes it, rather than drifting silently.
- **Run memory-hungry commands under a cap.** Upstream finding 1 is a fixture
  that makes the reference allocate 2.1 GB. `tools/waxdiff.py` wraps every
  reference invocation in `systemd-run --user --scope -p MemoryMax=…`
  (`WAXDIFF_MEM_CAP`, default 1G), so a runaway kills the command and not the
  session.
