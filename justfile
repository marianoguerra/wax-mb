# wax-mb — the tasks this project is developed, tested and shipped with.
#
# `just` with no arguments lists everything, grouped. Each recipe is the real
# command, so this file doubles as the index of what can be done here and as the
# place those commands are kept honest.
#
# Two properties of this project decide how the recipes below are split up:
#
#   * The differential suite is HERMETIC. `test/corpus/` and `test/golden/` are
#     committed, so everything in the `diff` group runs with neither the
#     reference binary nor the `wax/` checkout present. Recipes that DO need
#     them are grouped separately and each says so.
#   * Regenerating a committed artifact -- the goldens, the corpus, the message
#     table, the cram scope -- is a deliberate act whose diff is the review
#     artifact. Those are in `regen`, and none of them runs in CI.
#
# Note on the listing: `just --list` shows the LAST comment line above a recipe,
# so that line is always the one-line summary and any explanation sits above it.

impl := "tools/wax-mb"
waxdiff := "tools/waxdiff.py"
native := "_build/native/debug/build"

# List every task, grouped.
default:
    @just --list --unsorted

# ---------------------------------------------------------------------------
# Everyday development
# ---------------------------------------------------------------------------

# Type-check everything, warnings fatal (what CI gates on).
[group('dev')]
check:
    moon check --deny-warn

# Native is the backend the CLI and the harness use, and the fastest to build;
# `test-all` is the four-backend run CI does.
#
# Run the unit tests (native).
[group('dev')]
test:
    moon test --target native

# Run the unit tests on every backend: wasm, wasm-gc, js, native.
[group('dev')]
test-all:
    moon test --target all

# Run one package's tests, e.g. `just test-pkg grammar`.
[group('dev')]
test-pkg pkg:
    moon test -p waxmb/wax/{{pkg}} --target native

# Accept new snapshot output (`inspect` / `t.snapshot` blocks).
[group('dev')]
test-update:
    moon test --target native -u

# Format every source file (generated files opt out in their `moon.pkg`).
[group('dev')]
fmt:
    moon fmt

# A diff in a `.mbti` is a public-API change and wants reviewing as one.
#
# Regenerate the committed `pkg.generated.mbti` files.
[group('dev')]
interfaces:
    moon info --target all

# Everything that drives the CLI needs this: the harness and the cram runner
# call the built binary rather than `moon run`, which would re-check the build
# graph once per file over a 2100-file corpus.
#
# Build the native executable.
[group('dev')]
build:
    moon build --target native

# Run the built CLI, e.g. `just run check foo.wax`.
[group('dev')]
run *args: build
    {{impl}} {{args}}

# Drop build outputs.
[group('dev')]
clean:
    moon clean

# Refresh the package registry index (CI does this before building).
[group('dev')]
update:
    moon update

# ---------------------------------------------------------------------------
# The gates
# ---------------------------------------------------------------------------

# Check, format, unit tests, both hermetic oracles, cram -- run before committing.
[group('gates')]
quick: check fmt test diff cram

# Mirrors .github/workflows/check.yml, including the two `git diff --exit-code`
# steps -- which is how a stale `.mbti` or an unformatted file is caught.
#
# Everything CI enforces, in CI's order.
[group('gates')]
ci:
    moon check --deny-warn
    moon info --target all
    git diff --exit-code
    moon fmt
    git diff --exit-code
    moon test --target all
    moon build --target native
    {{waxdiff}} run --oracle 1 --oracle 3 --impl {{impl}}
    tools/run-cram.sh

# ---------------------------------------------------------------------------
# The differential suite -- the project's real correctness gate
# ---------------------------------------------------------------------------

# Oracle 1 is reprint parity (byte for byte, idempotence gated alongside);
# oracle 3 is error parity (severity, file, spans, offsets, exit code). Both
# compare against committed goldens, so this needs no reference binary.
#
# The differential suite: oracles 1 and 3, port under test.
[group('diff')]
diff: build
    {{waxdiff}} run --oracle 1 --oracle 3 --impl {{impl}}

# Oracle 2 -- our printed output, recompiled by the REFERENCE back end, must
# give a byte-identical .wasm -- is the one that needs the reference binary,
# which is why CI leaves it out.
#
# All three oracles. (needs the reference)
[group('diff')]
diff-all: build
    {{waxdiff}} run --impl {{impl}}

# The same golden hashes, reached the other way: OUR `-f wasm` bytes rather than
# the reference's recompilation of our reprint. A stronger claim, and hermetic --
# the 1592 wasm_sha256 values are committed -- so once the back end lands this
# belongs in `diff` and in CI. Until then it reports the back end as missing,
# which is the honest answer. Misses are graded on a ladder (validate, then
# stripped-WAT equality, then sha256) into test/report/wasm-drift.md.
#
# Oracle 2 against our own back end. (needs wasm-tools for the ladder detail)
[group('diff')]
diff-native: build
    {{waxdiff}} run --oracle 2 --oracle2-route native --impl {{impl}}

# Oracle 4: `-f wat` against the reference's.
#
# The one oracle with no golden behind it -- the reference answers at compare
# time -- so it needs the binary and stays out of `diff` and CI. It is also out
# of the DEFAULT oracle set, and reports rather than gates: the text printer
# reaches most of the corpus and not all of it, and a gate that fails on every
# run says nothing on the run where something actually breaks. The burn-down
# goes to test/report/wat-drift.md. When the count reaches parity it belongs in
# the default set, and then it gates.
[group('diff')]
diff-wat: build
    {{waxdiff}} run --oracle 4 --impl {{impl}}

# The inner loop when something is failing:
#
#     just diff-only cram/match
#
# Run the oracles over only the files whose path contains PATTERN.
[group('diff')]
diff-only pattern: build
    {{waxdiff}} run --oracle 1 --oracle 3 --impl {{impl}} --filter {{pattern}}

# Message wording is REPORTED, not gated; spans and severity are gated by
# `diff`. This rewrites the report with every entry rather than the first 50,
# which is how that number is watched.
#
# Rebuild test/report/message-drift.md in full.
[group('diff')]
drift: build
    {{waxdiff}} run --oracle 3 --impl {{impl}} --max-report 5000
    @echo "  see test/report/message-drift.md"

# Points the harness at the reference, so every oracle must pass trivially and
# any failure is a waxdiff bug rather than a port bug.
#
# Validate the harness itself. (needs the reference)
[group('diff')]
self-test:
    {{waxdiff}} run --self-test

# `printer_pp` lays the SAME token stream out with
# marianoguerra/pretty-fast-pretty-printer instead of the ported engine, so
# every difference this reports is a layout difference and nothing else. The two
# agree on every module in the corpus, so this exits non-zero if any of them
# stops agreeing. Add `--show N` for examples, `--dump` to see the tokens.
#
# Compare the alternative layout engine against the ported one.
[group('diff')]
ppdiff *args: build
    {{native}}/tools/ppdiff/ppdiff.exe test/corpus {{args}}

# The only coverage of the CLI's behaviour rather than the library's: exit
# codes, which stream output lands on, flag handling.
#
# Run the reference's own cram tests against wax-mb.
[group('diff')]
cram: build
    tools/run-cram.sh

# Run the cram tests, printing each failure's log.
[group('diff')]
cram-verbose: build
    tools/run-cram.sh -v

# ---------------------------------------------------------------------------
# Fuzzing -- the oracles on inputs nobody wrote
# ---------------------------------------------------------------------------

# Mutates corpus files at token level and grades each mutant with the same three
# oracles, asking the reference what the answer should be. The seed is printed;
# pass it back to reproduce a find:
#
#     just fuzz            # 200 mutants, random seed
#     just fuzz 1000       # more of them
#     just fuzz 200 7      # replay seed 7
#
# A non-zero exit means it FOUND something, not that it broke. Each minimized
# input lands in test/report/fuzz/; `just adopt` turns one into a test.
#
# Fuzz the oracles with mutated corpus files. (needs the reference)
[group('fuzz')]
fuzz count="200" seed="": build
    {{waxdiff}} fuzz --count {{count}} {{ if seed != "" { "--seed " + seed } else { "" } }}

# Follow it with `just goldens` to record what the reference does with the file.
#
#     just adopt test/report/fuzz/find-7-2.wax
#
# Move a fuzz find into test/corpus/fuzz/ as a permanent test.
[group('fuzz')]
adopt file *args:
    {{waxdiff}} adopt {{file}} {{args}}

# ---------------------------------------------------------------------------
# The porting inner loop
# ---------------------------------------------------------------------------

# Far faster than oracle 1 over the corpus, and it points at one construct
# rather than a pile of files:
#
#     just reprint 'fn f() -> i32 { 1 + 2; }'
#
# Diff this port's reprint of one snippet against the reference's. (needs the reference)
[group('port')]
reprint src:
    tools/reprint_diff.sh {{quote(src)}}

# Prints the error state, the stack, the offending token and the
# acceptable-token signature. That tuple is what the message table is keyed on,
# so it is where a wrong or missing syntax message is diagnosed.
#
# Show what the parser's automaton does with a file.
[group('port')]
errstate file: build
    {{native}}/tools/errstate/errstate.exe --whole {{file}}

# The corpus proves the parser BEHAVES like the reference; this is the
# structural check that the grammar is a faithful translation rather than
# something that happens to accept the same inputs.
#
# Compare this grammar against the reference's, rule by rule. (needs the checkout)
[group('port')]
grammar-fidelity:
    tools/grammar_fidelity.py

# MoonYacc prints conflicts only while GENERATING, so a cached parser.mbt means
# a clean `moon check` says nothing about them (test/UPSTREAM-FINDINGS.md
# finding 4). Deleting the generated file first is the only way to see them.
#
# Regenerate the parser from the grammar and report its conflicts.
[group('port')]
grammar-conflicts:
    rm -f grammar/parser.mbt grammar/parser.mbt.map.json
    moon build --target native

# ---------------------------------------------------------------------------
# The pinned reference -- restoring it, and regenerating what it produces
# ---------------------------------------------------------------------------

# Fails loudly if upstream's floating `edge` release has been rebuilt, which is
# exactly what the pin exists to catch. Needs `gh`.
#
# Restore the pinned reference BINARY (13 MB, gitignored).
[group('reference')]
reference:
    tools/fetch-reference.sh

# Read-only reference material: the OCaml being ported, and the corpus source.
# Never a build or CI input -- that would end the hermetic property.
#
# Restore the pinned reference SOURCES into wax/.
[group('reference')]
reference-source:
    tools/fetch-reference-source.sh

# The corpus is committed, so this runs only when deliberately moving the pin.
#
# Rebuild test/corpus/ from the wax/ checkout. (needs the reference and checkout)
[group('regen')]
corpus:
    {{waxdiff}} collect

# The resulting diff IS the review artifact: it shows what upstream's behaviour
# change was. Never edit a golden to make a test pass.
#
# Rebuild test/golden/, the reference's expected behaviour. (needs the reference)
[group('regen')]
goldens:
    {{waxdiff}} golden

# Show bucket counts for the corpus, writing nothing. (needs the reference)
[group('regen')]
classify:
    {{waxdiff}} classify

# Run it after landing a capability some test was excluded for.
#
# Re-select which cram tests this port can run. (needs the reference and checkout)
[group('regen')]
cram-scope:
    {{waxdiff}} classify-cram

# The reference's syntax messages, rekeyed onto this parser's states by
# replaying its error sentences. The `moon fmt` is not optional: the generated
# arms are long enough that the formatter rewraps them, and CI checks that a
# formatted tree is a committed tree.
#
# Rebuild grammar/parser_messages.mbt. (needs the checkout)
[group('regen')]
parser-messages: build
    tools/gen_parser_messages.py
    moon fmt

# ---------------------------------------------------------------------------
# Packaging and documentation
# ---------------------------------------------------------------------------

# test/ and tools/ are excluded in moon.mod, so the corpus and the harness stay
# out of the package.
#
# List the files `moon publish` would ship.
[group('ship')]
package:
    moon package --list

# Publish to mooncakes.io, after the full CI gate. Not reversible.
[group('ship')]
publish: ci
    moon publish

# Serve the API documentation at http://127.0.0.1:3000.
[group('ship')]
doc:
    moon doc --serve

# Run the tests with coverage instrumentation and report.
[group('ship')]
coverage:
    moon coverage analyze
