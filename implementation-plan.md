# Implementation plan

Remaining work on the MoonBit port of the [Wax](https://github.com/ocsigen/wax)
toolchain. Phases 0–4 are done; what follows is everything still open, in the
order it makes sense to do it.

> **Paths below are pre-workspace.** This file is a log as much as a plan, and
> the notes in it were written when every package sat at the repository root.
> They still name `grammar/`, `typing/`, `output/`, `tokens/` and so on. Those
> are now `lib/syntax/parser/`, `lib/check/`, `lib/fmt/`, `lib/syntax/tokens/`;
> see the table in `AGENTS.md`. The names were left alone deliberately —
> rewriting them would make the record of what was decided when less accurate,
> not more.

## Todo

**Near-term — close the gaps in what already exists**

- [x] 1. Point CI at the port, not at the reference
- [x] 2. Run the cram suite in CI
- [x] 3. Readable token names for the `Expecting …` list

**Phase 5 — harden the front end**

- [x] 4. Reproduce the `Assuming that … is complete` subject phrase
- [x] 5. Reproduce the related labels (`this statement`, `This '{' opens …`)
- [x] 6. Diff-fuzzing
- [x] 7. Error recovery and `--all-errors`

**Phase 6 — the type checker**

- [x] 8. `ast_utils` — the surface-form desugarings
- [x] 8b. The unlisted prerequisites *(new; see below)* — done, bar the
  back-end half of `misc.ml`, which belongs with task 15
- [x] 9. `members` — the method and intrinsic table *(the checker-facing half)*
- [x] 10. `infer` — inference cells and the numeric-literal lattice *(done before 9; see there)*
- [x] 11. `typing_env` — symbol tables *(now `lib/check/env`)*
- [x] 12. `typing` — the checker *(now `lib/check`)*
- [ ] 13. `typing_lint` / `typing_suggest` — 16 of the 23 warnings are emitted;
  `CompoundAssignment`, `FieldPunning`, `GeneratedName`, `NamingConflict`,
  `RedundantAnnotation`, `ReservedWordRename` and `TruncatedCoverage` are not
- [x] 14. Flip the oracle policy to `full`

**Phase 7 — the back end and the conversions**

- [x] 15a. `to_wasm` — emit wasm *(now `lib/emit/wasm`)*
- [ ] 15b. `text_to_binary` — the CLI still refuses any input format but `wax`
- [ ] 16. `validation` — the wasm validator
- [ ] 17. `from_wasm` — the decompiler, which unlocks most of the cram suite

---

## Where things stand

Measured 2026-08-14, at the first release.

| | |
|---|---|
| MoonBit source | 64.5k lines across 36 packages — 63.7k in `lib/`'s 34, of which 6.6k is the generated LR table, and 835 in `cli/`'s 2 — plus 14.8k of tests |
| Public API | 685 names in `lib/`; `tools/api_audit.py` reports which are unreferenced |
| Oracle 1 — reprint parity | 1907 pass, 0 fail, 212 skip; idempotence gated alongside |
| Oracle 2 — same wasm, via the reference | 1576 pass, 20 fail, 523 skip (`just diff-all`) |
| Oracle 2 — same wasm, our own back end | 1577 pass, 19 fail, 523 skip (`just diff-native`) — one better than the route through the reference |
| Oracle 3 — same errors | 2119 pass, 0 fail, on severity, file, spans, offsets, exit code |
| Oracle 4 — same WAT | reported, not gated; see `test/report/wat-drift.md` |
| Unit tests | 502, on all four backends |
| Message drift | 67 entries, in `test/report/message-drift.md` |
| Upstream findings | 12, in `test/UPSTREAM-FINDINGS.md` |
| Cram tests | 72 of 331 in scope: 62 pass, 10 known-failing in `tools/run-cram.sh` |
| Corpus | 2119 files: 2117 collected, 2 adopted fuzz finds |

Oracles 1 and 3 are the gate for everything below, and both are **green**. The
last two oracle-3 residuals closed together:
`cram/block-exit-mismatch__br-no-fall-through.wax`, which needed a checked
block to route a self-resolving trailing instruction through a collecting cell
(and, with it, the reference's `annotate_omitted_block` for stack-switching
operands, which is what keeps such an operand on the annotated path); and
`cram/match__err_scrut.wax`, where the reference emits its "Expected reference."
twice, the second time with no location at all — the spanless one comes from the
poison node a `br_on_cast` on a non-reference operand is abandoned for. Any task
that changes behaviour has to leave the count no worse, and
`tools/waxdiff.py run --oracle 1 --oracle 3 --impl tools/wax-mb` is the one
command that says so.

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

## 4. Reproduce the `Assuming that … is complete` subject phrase — done

**Done.** Message drift fell from **182 to 29**, and the total from 231 to 78.
The route was the plan's option 2, but sourced from committed goldens rather
than from a menhir run, and keyed on the state rather than on the token set.

**What made it possible.** MoonYacc's `--table` engine represents a state as an
`Int` (the default direct-style engine makes it an anonymous closure), and
leaves `yy_state`/`yy_input` package-visible. Switching the build rule to
`--table` is behaviour-neutral — all three oracles unchanged, corpus run
unchanged at ~1m7s — and makes the state observable. `grammar/state.mbt` then
replays the token stream through the same tables with the actions left out and
recovers the state *and the stack*; `test/corpus_parse/error_state_test.mbt`
checks the replay stops on the token the real parse rejected, over all 191
syntax-error corpus files.

**The table.** `tools/gen_parser_messages.py` writes each of the 550 sentences
in `parser_messages.expected` out as source, parses it, and records
stack → message. `grammar/parser_messages.mbt` is the result: 462 keys, nothing
dropped. Regenerating needs the `wax/` checkout and is a deliberate local act,
like regenerating goldens.

**One state was not enough.** Menhir's subject comes from reductions performed
*at* the error, which depend on the stack — so our state 55 ("after an
expression") is claimed by 14 different reference messages. The key is
therefore a stack SUFFIX, taken only as deep as it needs to be: one frame
resolves 435 of the 550 sentences, two resolve 533, seven resolve all of them.

**Borrowing a message needs evidence.** A stack suffix recurs in contexts whose
continuations differ, and the first version of this happily told the user, at
the top level of a module, that a `'}'` would do. Two checks now gate every
lookup: the acceptable-token *signature* recorded with the message must match
(proof the context is the same), or failing that, every token the message
NAMES must be legal here (`message_fits`) — the weaker evidence, which admits a
message whose recorded context differed only in a token it never mentions. That
combination is worth 3 drift entries over the signature alone, and it is the
difference between a message that is merely unhelpful and one that is false.

**What still drifts (29).** Two kinds. Most are states our replay reaches that
the reference's own sentences never produced — `Assuming that the statement is
complete, expecting ';', or '}'.` is generated from a sentence that lands in our
state 55, while real code with a missing `;` lands in state 53. The rest are
where the reference's message quotes a token we do not accept, so `message_fits`
declines it; the `#[if(VERSION 1)]` case in task 3 is the example, and there
ours is the accurate one.

**Options 1 and 3 are still worth doing.** This is a rekeyed table, not a
derivation: it can only say what the reference's sentence set covered. Exposing
the error state on `UnexpectedToken` (finding 11) would not change that, but an
automaton dump would — it is what tasks 4 and 5 would need to collapse into one
generator, and what the remaining 29 would need.

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

## 5. Reproduce the related labels — done

**Done.** The labels are built and correct wherever the message table covers the
state; `type t = { a: i32 b: i32 };` now renders byte-identically to the
reference, snippet, spine and both labels included:

```
Error: Assuming that the structure type is complete, expecting '}'.
 ──➤  t.wax:1:19
1 │ type t = { a: i32 b: i32 };
  ·                   ^
  ·            ^^^^^^ this structure type
  ·          ^ This '{' opens the enclosing construct.
```

**The labels' text** comes from the same table as the message: the `<^N>`/`<N>`
marker lines the golden carries beside each message, recorded by
`tools/gen_parser_messages.py` as `subject` and `opener`.

**Where they point is computed, not recorded.** Both markers are 1-based indices
into *Menhir's* stack, which is not ours — the two automata reduce at different
moments, so the depth does not carry over. Each is resolved on its own terms:

- `subject_span` (`grammar/state.mbt`) emulates what Menhir does with
  `%on_error_reduce`: it reduces while the reduction is unambiguous — a state
  whose only reduce action over every terminal lookahead is one production —
  and the construct is what the last one covers. An empty construct yields a
  zero-width span and no label, which is the reference's rule too.
- `enclosing_opener` scans the shifted tokens for the innermost unclosed
  `(`/`[`/`{`. The reference reaches the same token through a stack cell; a
  bracket scan needs no correspondence between two automatons' layouts.

**Measured against the reference before wiring it up**: on the 23 corpus files
that carry a label, the subject span matches on all 15 where it resolves and is
absent on 8 (never wrong), and the opener matches on all 10. Related drift 23 →
20.

**The residue is task 4's, not this one's.** 20 of the 23 stay because their
*message* is not in the table — no message, no labels. One is the file where the
reference reports a semantic error (`An '#[else]' must directly follow …`) and
we report a syntax error, so its label has nothing to correspond to.

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

## 6. Diff-fuzzing — done

**Done.** `waxdiff.py fuzz` mutates corpus files at TOKEN level (swap, delete,
duplicate, and "borrow" — replace a token with another from the same file) and
grades each mutant with the **same three oracles**, by running the reference on
it to say what the answer should be. Reusing `check_oracle{1,2,3}` verbatim (by
pointing `CORPUS`/`GOLDEN` at a scratch directory) was the point: a second
implementation of what agreement means would be a bug farm.

Byte-level noise was deliberately not used — it mostly produces something the
lexer rejects, which only ever exercises oracle 3. The tokenizer is a regex, not
the port's own lexer: a mutator sharing a lexer with the implementation under
test can only produce inputs that lexer already understands.

A find is minimized (delta debugging by chunks — halves, then quarters, down to
single tokens, under a budget) and written to `test/report/fuzz/`.
`waxdiff.py adopt` moves one into `test/corpus/fuzz/`, where `golden` records
the reference's answer and every future run grades it. The nightly `fuzz` CI job
runs 400 mutants; it is not a gate, because a search that blocks a pull request
blocks it for reasons the author did not introduce.

**It found three things in the first 400 mutants.**

1. **We lexed the whole file before parsing.** The reference's parser pulls
   tokens one at a time, so a syntax error early in a file is reported before
   its lexer ever reaches a stray character later on. Ours reported the stray
   character. Fixed: on a lexical error, the tokens that did lex are parsed and
   an error strictly before the lexical one wins.
2. **A semantic error an action records lost to a later syntax error.** Same
   rule, same fix — MoonYacc's actions cannot raise (finding 3), so the parse
   runs on past the recorded error.
3. **The exemption list was hiding two of these.** `SPAN_DIVERGENCE_UPSTREAM`
   listed seven files "where the offending token is a STRING" (finding 9).
   Three of them were nothing of the sort: two were the lexing-order bug and one
   was the semantic-ordering bug — both ours. Fixing them made all three agree
   exactly, and the list is now `SPAN_EXEMPT`, a file → reason map.

**And one genuine divergence, recorded as finding 12** with both its directions
and a corpus file each. Menhir performs a *default reduction* in a state with a
single action — it reduces without consulting the lookahead — so an action's
check fires before the syntax error is discovered. MoonYacc consults the
lookahead first. Neither preference rule can fix it: an error that is never
produced cannot be preferred.

Net: oracle 3 went from 2112 to 2114 files with zero failures, drift 75 → 64,
and the span exemptions from 7 files under one wrong cause to 6 under two right
ones.

**A fuzzer has to recognise every recorded divergence by SHAPE**, because a
mutant has no name to put on an exemption list. Two filters exist for that, and
the second was added later, when `just fuzz` reported a find that turned out to
be finding 8:

- **Finding 9** (the reference points a syntax error at a string's closing
  quote): same diagnostics, differing only in span, the reference's span being
  the last character of ours and ours starting at a quote. Only the GATED fields
  have to agree — the message may differ for an unrelated reason (a
  message-table miss), and requiring it to match buried the real finds.
- **Finding 8** (a comment ending a block escapes it on reformat): the reference
  is asked directly whether it is unstable on the same input, and whether it
  drifts to the same bytes. A mutant where only WE drift stays a find. The check
  runs only once an idempotence failure has been reported, so the ordinary
  mutant pays nothing for it.

With both, a 250-mutant campaign reports one find, and that one is a fresh
instance of finding 12's class rather than noise.

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

## 7. Error recovery and `--all-errors` — done

**Done, and shipped rather than left as research.** The plan assumed recovery
would have to re-parse the whole file per error ("cruder than Menhir's
stack-unwinding recovery … quadratic"). It does not: task 4's switch to
MoonYacc's `--table` engine left `yy_state`, `yy_input` and the ACTION table
package-visible, so `grammar/recover.mbt` drives the same automaton from its own
loop — with the actions, so the tree is real — and repairs the stream in place.
One pass, no restarts.

Three repairs, in the reference's order (`recover.ml` + `parse_recover`):

1. **Insert a `;`** when that unblocks the parse. The validation matters: `;` is
   shiftable right after `{` (an empty statement is legal), so acceptability
   alone would report a missing separator in front of any junk following a
   brace. The test is whether the OFFENDING token becomes acceptable once the
   `;` is in — `shift_sim` answers it by performing the reductions on a copy of
   the stack.
2. **Auto-close** when the offending token is a closer, a `;` or end of input
   and a construct in front of it is still open. Skipping would unwind past that
   construct and discard it; closing it keeps the function the user is still
   typing, and the inserted closers become the quick fix (`Help: insert '}'`).
3. **Skip to a resynchronization point** and unwind the stack to it. The sync
   classification is `recover.ml` ported directly, nesting-aware: a `;` or `}`
   belonging to a group opened inside the skipped span does not resync the
   construct the error is in.

**Measured against the reference on its own fixtures** (`check-all-errors.t`):
`multi.wax`, `missing-semi.wax` and `stack-cascade.wax` are byte-identical
output; `unclosed-brace.wax` has the same span and the same `insert '}'` fix and
differs only in wording (a message-table miss, task 4's residue); `clean.wax`
and `mixed.wax` agree on everything except the reference's type-checker output.
`wax-limit-overflow.t` now runs and passes — cram is 3 of 328.

**What makes the hand-copied driver safe** is not care, it is a test: on all
1903 files the reference parses, `parse_recover` must report nothing and build a
tree identical to `parse_string`'s. A copy that drifts fails there, not in a
user's file.

**Still missing** is lexical recovery — our scan stops at a bad character where
the reference resumes past it, so a file with two stray characters reports one.
That needs a resuming entry point in the lexer, not anything from the parser.

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

## 8. `ast_utils` — the surface-form desugarings — done

**Done.** `ast/utils.mbt`, and it did what the plan hoped: the surface
constructors are faithful enough that all four lowerings fall out of them
directly, with no AST change.

- **`map_desc`** — the one exhaustive rebuild of `InstrDesc`. The reference
  writes that giant match twice (`map_desc` and `sub_instrs`); here `sub_instrs`
  and `iter_instr` derive from the rebuild by pushing as they go, which costs
  one shallow desc allocation per node visited (linear, and the tree is walked
  once) and leaves ONE place to update when a constructor is added.
- **`map_info`** — `Instr[A]` to `Instr[B]`, which is how the checker will
  re-annotate the parser's tree.
- **`lower_while` / `lower_dispatch` / `lower_match` / `lower_trycatch`** plus
  `synthetic_loop_label`, each the exact inverse of a `recover_*` pass.
- **`import_name`**, returning BYTES where the reference returns a string: a
  wasm import name is a byte string, and this port keeps a string literal as the
  bytes the lexer decoded rather than re-encoding at every use.

**Not ported: `smart_map` / `smart_opt`.** They return the input list
physically when nothing changed, so an untouched subtree allocates nothing. That
is an allocation optimisation resting on OCaml's `==`, and it belongs with the
rewrite pass that needs it — the checker's `simplify` — not ahead of it.

**Tested on parsed input, not hand-built trees** (`test/corpus_parse/
lowering_test.mbt`): each test parses real Wax, finds the construct with
`iter_instr`, lowers it, and compares a compact structural sketch. So a change
to how the parser shapes a `while` breaks these too, which is the point of
putting them there. The sketch is used rather than the AST JSON because the JSON
renderer spells out only the constructors the parse snapshots need — every
branch instruction a lowering emits prints as `"..."`.

Writing the `match` expectation surfaced the one asymmetry worth knowing: a
`null` arm's block is VOID, so its result is not bound, while a cast arm's block
yields the narrowed value the following `let` consumes.

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

## 9. `members` — the method and intrinsic table — done (the half that has a consumer)

**Done, after task 10** — `members` is written against `Infer`'s types, so the
plan's order had that dependency backwards.

**The premise needed correcting.** The plan says this is "needed before the
checker can resolve a method call". It is not: the reference's own `.mli` says
the method dispatch "is match-based and not enumerable", and `members.ml` is the
**editor's** completion registry — what `recv.<here>` offers, with rendered
signatures. Of the 9 places `typing.ml` touches it, seven only RECORD a
receiver descriptor for that completion; the two that do real work are
`simd_valtype` and `cont_method_candidates`.

So the new `members` package carries the half with a consumer: `MethodResult`,
`ValueMethod`, `integer_methods`, `float_methods`, `MemberReceiver`,
`numeric_receiver_kind` and `simd_valtype`. The two curated registries earn
their place ahead of the typer for a different reason than the plan gave — they
are the checklist the typer's method dispatch is written against, and upstream
keeps them honest with a test that type-checks every entry.

**Not ported: the candidate builders** — the `fn(i32) -> i32` renderings for a
memory, table, array, struct, v128 or continuation receiver. They serve
`recv.<here>` completion in an editor this port does not have, nothing in the
checker consults them, and there is no test that could tell a faithful
transcription from a plausible one. They are cheap to add the day an editor
wants them.

**An unlisted prerequisite, found here.** `simd_v128_methods` reads its
signatures from `Wax_wasm.Simd` — `wax/src/lib-wasm/simd.ml`, **856 lines**, the
registry of every vector op. It is not ported and appears in no task, and the
type checker needs it too: `v.add_i32x4(w)` dispatches through it. Task 12 has
to account for it.

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

## 10. `infer` — inference cells and the numeric-literal lattice — done

**Done, and taken before task 9** — `members` is written against `Infer`'s
types, so the plan's order had the dependency backwards. See task 9 for what
else that reordering turned up.

The new `infer` package is three files:

- **`cell.mbt`** — the union-find. `merge` unions two cells and gives the class
  one value, so narrowing either handle afterwards narrows both. The
  self-merge case is guarded explicitly, as upstream does: linking a root to
  itself would build a cycle `representative` could never leave.
- **`infer.mbt`** — the lattice. The flexible literals (`Number`, `Int`,
  `LargeInt`, `Float`, `Int8`, `Int16`) are what make keeping numeric literals
  as raw strings pay off: a literal has no width yet, so there is nothing to
  have chosen wrongly. `InferredValType` carries the type in BOTH forms —
  Wax-side naming its types, wasm-side indexing them — which is the second
  Phase 2 commitment cashed in, since `wasm_types` is generic over the index.
- **`render.mbt`** — the diagnostic rendering. The flexible families print BY
  FAMILY (`number`, `int`, `large number`, `float`), never as their default
  width, and a block result under inference prints as the annotation being
  tested rather than as `any`.

**8 tests**, which is the exhaustive unit-testing the plan asked for: the
union-find under chained merges and self-merge, every lattice case's rendering,
and the three-way "nothing known" distinction (`Unknown` still earns an error,
`Error` is already reported, `UnknownRef` is known to be a reference).

**One deliberate difference.** `TypeIdx` is a struct rather than the
reference's `Wax_wasm.Id.t`; `collected`/`exacts` are plain arrays where the
reference needs `mutable`, since appending to an OCaml list means replacing it.

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

## 8b. The unlisted prerequisites of Phase 6 *(new)*

Measured while starting task 11. `typing_env.ml` and `typing.ml` reach into
nine modules that **no task lists and this port does not have**, and
`typing_env`'s `module_context` cannot even be *typed* without the first three:

| module | lines | uses in the typer | what it is | |
|---|---|---|---|---|
| `lib-wasm/types.ml` | 372 | 71 | the interned type store: rec-group normalisation, canonical indices, subtyping info | **done**, `type_store/` |
| `lib-wasm/simd.ml` | 856 | 11 | every vector op, with its operand and result types; how `v.add_i32x4(w)` dispatches | **done**, `simd/` |
| `lib-wasm/cond_solver.ml` | 240 **+ 1545** | 4 | the conditional-compilation assumption every declaration carries | **done**, `cond/` |
| `lib-wasm/atomics.ml` | 179 | 5 | the atomic memory operations | **done**, `atomics/` |
| `lib-wasm/cond_explore.ml` | 133 | 1 | enumerating the branches of a conditional module | **done**, `cond_explore/` |
| `lib-utils/spell_check.ml` | 126 | 8 | "did you mean" | **done**, `spell/` |
| `lib-wasm/misc.ml` | 100 **+ 140** | 13 | assorted wasm-side helpers | **half done**, `number/` |
| `lib-utils/feature.ml` | 86 | 29 | the proposal gating | **done**, `feature/` |

**Eight are done, and one is half done.**

- **`spell/`** — OCaml's own Damerau-Levenshtein, banded around the diagonal so
  a candidate that is obviously too far is abandoned rather than measured, with
  the limit tightening as better candidates are found. Distances are over CODE
  POINTS, so `é` is one edit from `e` and an emoji is one character. 7 tests.
- **`feature/`** — the proposal gating. The state that matters and is easy to
  lose: a feature can be off by DEFAULT or off because someone wrote
  `-X name=off`, and a module declaring the second is a conflict to report where
  the first is just an opt-in. 8 tests.
- **`type_store/`** — the blocker. Two more instantiations of the `Idx`-generic
  `wasm_types` spine (`Idx = Id`, a canonical store index; `Idx = RefIndex`,
  which can also name a member of the group being registered), so this is an
  addition to the type family rather than a fourth copy of it. The reference
  needs a functor applied three times plus a mapping functor, because OCaml's
  `Make_types` also parameterises the array wrappers; both forms here use plain
  arrays, so the wrapper types are generic in `Idx` and written once. 9 tests.
- **`cond/`** — **not a port.** The row above understates `cond_solver.ml`
  badly: it is 240 lines *on top of* `vendor/theo`, a 1545-line BDD engine with
  generic theory combination. That generality is not needed. Wax's condition
  language admits three kinds of variable and every atom constrains one variable
  against a constant, so satisfiability decomposes per variable and DPLL over
  the atoms decides it completely. ~800 lines instead of ~1800, complete and
  sound, with the translation and its diagnostics following `cond_solver.ml`
  exactly because oracle 3 compares them. 10 tests.

- **`atomics/`** — 66 operations across four tables that must agree: mnemonic,
  sub-opcode, alignment, signature. The reference generates all four from one
  layout rather than writing them out, and that structure is what is ported.
  Note the Wax surface is not one-to-one with the binary one: a method name
  carries the ACCESS width only, so `i32.atomic.load` and `i64.atomic.load32_u`
  share a family. 6 tests.
- **`cond_explore/`** — the driver that makes a conditional module checkable:
  explore every reachable configuration, report each distinct diagnostic once,
  qualified by the union of the assumptions reaching it. It is what wanted a
  structural dedup key on `cond.T`. 5 tests.
- **`number/`** — `misc.ml`'s typer-facing half (`is_int8/16/32/64`,
  `is_float32/64`) turned out to sit on `lib-utils/number_parsing.ml`, 140 lines
  the table also does not list. Hex float parsing, NaN payloads, and an exact
  double-rounding tie-break. The other half of `misc.ml` — encoding a data
  segment's literals to bytes — has no consumer until the lowering exists and
  needs the AST, so it goes with task 15. 9 tests.

- **`simd/`** — 233 operations, derived rather than listed: a Wax name is the
  WAT mnemonic `A.B` rewritten `B_A`, and the signature follows the family. The
  generator refuses to emit anything it cannot classify, and the compiler checks
  every constructor name — it rejected one, where our enum spells
  `RelaxedQ15mulrS` but `Q15MulrSatS`. 10 tests.

**Task 8b is done.** Nothing blocks `typing_env` any more.

## 11. `typing_env` — symbol tables — done

**Done**, as `lib/check/env`. What follows is the plan as it was written; the
recovery-mode interaction it flags is the part that mattered.

**Was blocked on 8b** — `module_context` holds a `Wax_wasm.Types.t`, a
`Cond_solver.t` and a `Feature.set`; two of the three are not ported yet.

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

## 12. `typing` — the checker — done

**Done**, as `lib/check` (36 files). It was decomposed roughly as planned, but
NOT gated by an intermediate oracle scope: the `type-bad` bucket was flipped in
one move once the checker reached it, and the residual is two files rather than
a partial scope. See task 14.

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

## 13. `typing_lint` / `typing_suggest` — the warnings and quick fixes — partly done

**16 of the 23 warnings are emitted** by `lib/check`. The seven that are not:
`CompoundAssignment`, `FieldPunning`, `GeneratedName`, `NamingConflict`,
`RedundantAnnotation`, `ReservedWordRename`, `TruncatedCoverage`. Four entries
in `tools/run-cram.sh`'s `KNOWN_FAILING` are the cram-side view of that gap
(`new-lints-wax`, the two `redundant-*-float`, `suggestions`). The reuse this
section predicted did happen: `lint_source.mbt` calls
`@output.confusing_precedence`, the same function the printer parenthesises by.

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

## 14. Flip the oracle policy to `full` — done

**Done.** `test/oracle-policy.json` reads `"scope": "full"`. It was a one-key
change, as designed. Two files fail under it and are listed in
`test/report/failures.md`; the intermediate scope below was never needed.

**Summary.** The Phase 6 finish line. `test/oracle-policy.json` already
contains a `full` scope: `type-bad` becomes a positive error-parity test and
`compiles-clean` gains one. Switching `scope` is the whole change — the corpus,
the buckets and the goldens all stay as they are.

**Approach.** Flip it, run the harness, and burn down what fails. This was the
point of making the bucket→expectation mapping configuration rather than code
back in Phase 0, and it should be a genuinely small commit.

**Resources.** `test/oracle-policy.json`; `tools/waxdiff.py`'s `--scope` flag.

---

## 15. `to_wasm` + `text_to_binary` — emit wasm — half done

**`to_wasm` is done**, as `lib/emit/wasm`, and the `--oracle2-route native`
flag this section asks for was built: `just diff-native` runs it, `just diff`
still runs the via-reference route. **`text_to_binary` is not**: the CLI
refuses any input format but `wax`, so there is no wat-to-wasm path.

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
  12 findings. Two of them (7 and 8) are exemptions in the idempotence gate and
  two (9 and 12) in the span gate — and each is written so the harness *fails* if
  upstream fixes it, rather than drifting silently.
- **Run memory-hungry commands under a cap.** Upstream finding 1 is a fixture
  that makes the reference allocate 2.1 GB. `tools/waxdiff.py` wraps every
  reference invocation in `systemd-run --user --scope -p MemoryMax=…`
  (`WAXDIFF_MEM_CAP`, default 1G), so a runaway kills the command and not the
  session.
