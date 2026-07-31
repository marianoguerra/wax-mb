#!/usr/bin/env python3
"""waxdiff -- the differential test harness for the MoonBit Wax front end.

This port is only worth having if it is provably equivalent to the reference
implementation, so this harness is the project's real correctness gate. It runs
both implementations over a corpus and compares three things:

  Oracle 1  reprint parity   `f.wax -f wax` through both implementations, byte
                             for byte. A same-format conversion in the reference
                             only re-prints and is NOT validated, so this
                             exercises exactly this project's scope -- lexer,
                             parser, AST, trivia, printer -- with no type
                             checker involved.

  Oracle 2  wasm equivalence our printed output, fed back through the REFERENCE
                             back end, must produce a byte-identical .wasm. This
                             proves the AST preserved everything semantically
                             relevant without our needing a code generator.

  Oracle 3  error parity     same diagnostics at the same spans with the same
                             exit code. Spans/offsets/severity are gated;
                             message wording is reported but non-blocking.

The implementation under test is invoked with the SAME command line as the
reference (`<impl> file.wax -f wax`, `<impl> check --error-format json file.wax`)
rather than some harness-specific interface. Two things fall out of that: the
harness can be self-tested by pointing --impl at the reference itself, and the
reference's own cram tests port over without rewriting their command lines.

Subcommands:
  collect    build test/corpus/ from the wax/ checkout (needs wasm-tools)
  classify   bucket the corpus using the reference alone
  golden     record the reference's expected outputs into test/golden/
  run        compare an implementation against the goldens, writing details to
             test/report/{failures,message-drift}.md
  fuzz       mutate corpus files and grade the mutants with the same oracles
  adopt      move a fuzz find into the corpus, where it becomes a permanent test

NOTE ON IMPLEMENTATION LANGUAGE: the plan called for this to be a MoonBit
executable (cmd/waxdiff). It is Python instead. The harness is pure external
process orchestration and byte comparison -- there is nothing here that benefits
from being written in the language under test, and Phase 0's whole point is to
have a *trustworthy* oracle in place before any parser exists. When the parser
lands and we want in-process comparison (parse in MoonBit, no subprocess per
file), that is the moment to move the hot loop into MoonBit.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import hashlib
import json
import os
import random
import re
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WAX_CHECKOUT = ROOT / "wax"
CORPUS = ROOT / "test" / "corpus"
GOLDEN = ROOT / "test" / "golden"
REPORT = ROOT / "test" / "report"
REFERENCE = ROOT / "tools" / "wax-ref"

# Buckets, decided by the reference's own behaviour. See `classify`.
SYNTAX_BAD = "syntax-bad"
COMPILES_CLEAN = "compiles-clean"
TYPE_BAD = "type-bad"


# --------------------------------------------------------------------------
# running the reference
# --------------------------------------------------------------------------


@dataclass
class Run:
    code: int
    out: bytes
    err: bytes


# Cap every child process's memory.
#
# This is not defensive programming for its own sake: the corpus deliberately
# includes adversarial inputs, because that is where a reimplementation diverges.
# wax/test/cram-tests/array-new-fixed-large-count.t/poly.wat is upstream's own
# regression test for a validator DoS (`array.new_fixed $vec 4294967295`), and
# while `wax check` handles it in 13 MB, `wax -i wat -f wax` on the same file
# allocates past 2 GB. Without a per-process cap, one such input takes down the
# whole collection run -- and, uncapped, the machine's OOM killer takes down
# whatever shell is running it.
MEM_CAP = os.environ.get("WAXDIFF_MEM_CAP", "1G")
_HAS_SYSTEMD_RUN = shutil.which("systemd-run") is not None


def _capped(argv: list[str]) -> list[str]:
    if not _HAS_SYSTEMD_RUN:
        return argv
    return [
        "systemd-run", "--user", "--scope", "-q",
        "-p", f"MemoryMax={MEM_CAP}",
        "-p", "MemorySwapMax=0",
        *argv,
    ]


def run(
    argv: list[str], cwd: Path | None = None, timeout: int = 60, cap: bool = True
) -> Run:
    try:
        p = subprocess.run(
            _capped(argv) if cap else argv,
            cwd=cwd,
            capture_output=True,
            timeout=timeout,
            check=False,
        )
        return Run(p.returncode, p.stdout, p.stderr)
    except subprocess.TimeoutExpired:
        return Run(-1, b"", b"waxdiff: timed out\n")


def wax(*args: str, timeout: int = 60) -> Run:
    return run([str(REFERENCE), *args], timeout=timeout)


def need_reference() -> None:
    # The wrapper is committed; the binary it execs is not (13 MB, gitignored).
    # Checking the binary is what matters -- otherwise the precondition holds
    # and every one of the ~8400 invocations fails separately with exit 127.
    asset = json.loads((ROOT / "tools" / "reference.json").read_text())["asset"]
    if not REFERENCE.exists() or not (ROOT / "tools" / asset).exists():
        sys.exit("waxdiff: reference missing; run tools/fetch-reference.sh")


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def default_jobs() -> int:
    """Worker count for the parallel passes.

    Bounded by *memory*, not cores. Each worker can have a reference process
    holding up to MEM_CAP, so `cores` workers on an 8-core box means a worst
    case of 8 GB -- more than is free on a 12 GB machine that is also running an
    editor. Typical invocations use ~13 MB, but the corpus contains inputs that
    provoke the pathological case on purpose (see MEM_CAP), and the whole point
    of the cap is to survive those rather than gamble on them being rare.
    """
    return min(4, os.cpu_count() or 4)


# --------------------------------------------------------------------------
# collect
# --------------------------------------------------------------------------


def _write_corpus_file(rel: str, text: str, manifest: dict, origin: str) -> None:
    # A collision means two different inputs are competing for one corpus slot,
    # so one of them is about to vanish. That is a naming bug in the collector,
    # not something to paper over -- it silently shrank the spec corpus by 158
    # files before the .wast directory was added to the key.
    if rel in manifest:
        raise AssertionError(
            f"corpus name collision: {rel!r} claimed by both "
            f"{manifest[rel]['origin']!r} and {origin!r}"
        )
    dest = CORPUS / rel
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(text, encoding="utf-8")
    manifest[rel] = {"origin": origin}


def collect_cram(manifest: dict) -> int:
    """The hand-written .wax fixtures from the reference's own cram tests.

    These are the highest-value inputs in the corpus: each one was written by
    the reference's authors to pin down a specific behaviour, so they cluster
    exactly on the edge cases a reimplementation gets wrong.
    """
    n = 0
    src = WAX_CHECKOUT / "test" / "cram-tests"
    for path in sorted(src.rglob("*.wax")):
        test = path.parent.name.removesuffix(".t")
        rel = f"cram/{test}__{path.name}"
        _write_corpus_file(
            rel,
            path.read_text(encoding="utf-8"),
            manifest,
            str(path.relative_to(WAX_CHECKOUT)),
        )
        n += 1
    return n


FENCE = re.compile(r"^```(wax(?:,[a-z]+)?)\s*$")


def collect_docs(manifest: dict) -> int:
    """Wax code blocks from the language documentation and the agent skill.

    Blocks fenced ```wax,check are validated by the reference's own doc build,
    so they are known-good complete modules. Plain ```wax blocks are often
    fragments that do not parse standalone -- they are collected anyway, because
    "both implementations must reject this identically" is just as much a test
    as "both must accept this identically".
    """
    n = 0
    sources = sorted((WAX_CHECKOUT / "docs" / "src").glob("*.md"))
    skill = WAX_CHECKOUT / "skills" / "wax" / "reference.md"
    if skill.exists():
        sources.append(skill)
    for md in sources:
        lines = md.read_text(encoding="utf-8").splitlines()
        i, block = 0, 0
        while i < len(lines):
            m = FENCE.match(lines[i])
            if not m:
                i += 1
                continue
            i += 1
            body: list[str] = []
            while i < len(lines) and lines[i].rstrip() != "```":
                body.append(lines[i])
                i += 1
            i += 1
            if not body:
                continue
            checked = "check" in m.group(1)
            rel = f"docs/{md.stem}__{block:03d}{'_checked' if checked else ''}.wax"
            _write_corpus_file(
                rel,
                "\n".join(body) + "\n",
                manifest,
                f"{md.relative_to(WAX_CHECKOUT)} block {block}",
            )
            block += 1
            n += 1
    return n


def collect_wat(manifest: dict) -> int:
    """Wax produced by converting the reference's .wat fixtures.

    Free coverage of constructs the hand-written .wax fixtures happen not to
    reach. Inputs the reference cannot convert are skipped -- many are
    deliberately-malformed WAT, which tests the WAT parser, not ours.
    """
    n = 0
    for path in sorted((WAX_CHECKOUT / "test").rglob("*.wat")):
        r = wax("-i", "wat", "-f", "wax", str(path))
        if r.code != 0 or not r.out.strip():
            continue
        rel = "wat/" + str(path.relative_to(WAX_CHECKOUT / "test")).replace(
            "/", "__"
        ).removesuffix(".wat") + ".wax"
        _write_corpus_file(
            rel,
            r.out.decode("utf-8"),
            manifest,
            f"{path.relative_to(WAX_CHECKOUT)} (wat->wax)",
        )
        n += 1
    return n


def collect_spec(
    manifest: dict, limit: int | None = None, per_wast: int = 5
) -> int:
    """Wax decompiled from the official WebAssembly spec test suite.

    .wast files are scripts, not modules, so they are first split into
    individual .wasm modules with wasm-tools, then decompiled. This is the only
    corpus source with systematic coverage of every instruction in the
    instruction set, which is what makes it worth the extra tooling step.

    Only the first `per_wast` modules of each file are kept. Taking all of them
    yields ~4400 files that are heavily redundant -- the SIMD suites in
    particular are hundreds of modules differing by a constant -- which costs
    repository size and three reference invocations each at golden time, while
    adding almost no coverage. Capping per file preserves breadth (every .wast
    is still represented) and drops the repetition. The cap is deliberately part
    of the collector rather than a post-hoc prune, so the corpus stays
    reproducible from this script alone.
    """
    if not shutil.which("wasm-tools"):
        print("waxdiff: wasm-tools not found, skipping the spec corpus", file=sys.stderr)
        return 0
    n = 0
    tmp = REPORT / "wast-split"
    shutil.rmtree(tmp, ignore_errors=True)
    tmp.mkdir(parents=True, exist_ok=True)
    wasts = sorted(
        list((WAX_CHECKOUT / "test" / "wasm-test-suite").rglob("*.wast"))
        + list((WAX_CHECKOUT / "test" / "wasm-tools-suite").rglob("*.wast"))
    )
    if limit:
        wasts = wasts[:limit]
    for wast in wasts:
        d = tmp / wast.stem
        d.mkdir(parents=True, exist_ok=True)
        r = run(
            [
                "wasm-tools", "json-from-wast", "--wasm-dir", str(d),
                "-o", str(d / "out.json"), str(wast),
            ]
        )
        if r.code != 0:
            continue
        kept = 0
        for mod in sorted(d.glob("*.wasm")):
            if kept >= per_wast:
                break
            d2 = wax(str(mod), "-f", "wax")
            if d2.code != 0 or not d2.out.strip():
                continue
            kept += 1
            # Qualify with the .wast's directory, not just its stem: the spec
            # and wasm-tools suites both contain e.g. simd_lane.wast, and
            # keying on the stem alone silently overwrote 158 files.
            tag = str(wast.relative_to(WAX_CHECKOUT / "test")).removesuffix(
                ".wast"
            ).replace("/", "__")
            rel = f"spec/{tag}__{mod.stem}.wax"
            _write_corpus_file(
                rel,
                d2.out.decode("utf-8"),
                manifest,
                f"{wast.relative_to(WAX_CHECKOUT)} -> {mod.name} (wasm->wax)",
            )
            n += 1
    shutil.rmtree(tmp, ignore_errors=True)
    return n


def cmd_collect(args) -> int:
    need_reference()
    if not WAX_CHECKOUT.exists():
        sys.exit(f"waxdiff: reference checkout missing at {WAX_CHECKOUT}")
    CORPUS.mkdir(parents=True, exist_ok=True)
    REPORT.mkdir(parents=True, exist_ok=True)

    # Collection is incremental and per-source. The spec pass in particular runs
    # thousands of subprocesses and can be interrupted; wiping everything up
    # front would mean an interrupted run destroys the sources that already
    # succeeded. Each source rebuilds only its own subtree.
    sources = args.only or ["cram", "docs", "wat", "spec"]
    manifest_path = CORPUS / "manifest.json"
    prior = (
        json.loads(manifest_path.read_text())["files"]
        if manifest_path.exists()
        else {}
    )
    manifest: dict = {k: v for k, v in prior.items() if k.split("/")[0] not in sources}

    collectors = {
        "cram": lambda m: collect_cram(m),
        "docs": lambda m: collect_docs(m),
        "wat": lambda m: collect_wat(m),
        "spec": lambda m: collect_spec(m, args.spec_limit, args.spec_per_wast),
    }
    counts = {}
    for name in sources:
        shutil.rmtree(CORPUS / name, ignore_errors=True)
        counts[name] = collectors[name](manifest)
    for name in ("cram", "docs", "wat", "spec"):
        if name not in counts and (CORPUS / name).exists():
            counts[name] = len(list((CORPUS / name).glob("*.wax")))

    # The manifest is the corpus's provenance record, and an incremental run can
    # only carry forward entries a PREVIOUS run wrote. If an earlier collect was
    # interrupted before it saved the manifest, those files exist on disk with
    # no recorded origin -- which is how 699 collected files ended up with 0
    # manifest entries. Detect the gap rather than committing a corpus whose
    # provenance is quietly incomplete.
    on_disk = {str(p.relative_to(CORPUS)) for p in CORPUS.rglob("*.wax")}
    missing = on_disk - manifest.keys()
    if missing:
        sys.exit(
            f"waxdiff: {len(missing)} corpus file(s) have no manifest entry, e.g. "
            f"{sorted(missing)[:3]}.\nRe-run a full `collect` (no --only) to "
            f"rebuild provenance for every source."
        )

    (CORPUS / "manifest.json").write_text(
        json.dumps(
            {
                "_comment": "Provenance for every corpus file. Regenerate with "
                "tools/waxdiff.py collect. Files are committed so the "
                "differential suite runs without the wax/ checkout.",
                "counts": counts,
                "files": dict(sorted(manifest.items())),
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    total = sum(counts.values())
    for k, v in counts.items():
        print(f"  {k:6} {v:5}")
    print(f"  {'total':6} {total:5}")
    return 0


# --------------------------------------------------------------------------
# classify + golden
# --------------------------------------------------------------------------


def corpus_files() -> list[Path]:
    return sorted(p for p in CORPUS.rglob("*.wax"))


def classify_one(path: Path) -> dict:
    """Bucket one file using only the reference.

    The order matters. `-f wax` re-prints WITHOUT validating, so its exit status
    isolates "did it parse?" from "did it type-check?" -- which is precisely the
    line between what this port implements and what it does not. Only if it
    parses do we ask the second question.
    """
    rel = str(path.relative_to(CORPUS))
    reprint = wax(str(path), "-f", "wax")
    if reprint.code != 0:
        diag = wax("check", "--error-format", "json", str(path))
        return {
            "file": rel,
            "bucket": SYNTAX_BAD,
            "reprint_code": reprint.code,
            "diag_code": diag.code,
            "reprint": None,
            "diagnostics": diag.err.decode("utf-8", "replace"),
            "wasm_sha256": None,
        }
    compiled = wax(str(path), "-f", "wasm", "-o", "-")
    if compiled.code == 0:
        bucket, wasm_sha = COMPILES_CLEAN, sha256(compiled.out)
    else:
        bucket, wasm_sha = TYPE_BAD, None
    diag = wax("check", "--error-format", "json", str(path))
    return {
        "file": rel,
        "bucket": bucket,
        "reprint_code": 0,
        "diag_code": diag.code,
        "reprint": reprint.out.decode("utf-8", "replace"),
        "diagnostics": diag.err.decode("utf-8", "replace"),
        "wasm_sha256": wasm_sha,
    }


def write_golden(res: dict) -> dict:
    """Record one file's reference behaviour under GOLDEN; return its index entry.

    Shared with `fuzz`, which points GOLDEN at a scratch directory and grades a
    mutant with the very same oracles rather than a second implementation of
    what agreement means.
    """
    stem = res["file"].removesuffix(".wax")
    # The reprint text is Oracle 1's expected output, so store it as a real
    # file: a golden diff should be reviewable line by line, not a hash that
    # only says "something changed".
    if res["reprint"] is not None:
        p = GOLDEN / f"{stem}.reprint"
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(res["reprint"], encoding="utf-8")
    if res["diagnostics"]:
        p = GOLDEN / f"{stem}.diag.jsonl"
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(res["diagnostics"], encoding="utf-8")
    return {
        "bucket": res["bucket"],
        "reprint_code": res["reprint_code"],
        "diag_code": res["diag_code"],
        "wasm_sha256": res["wasm_sha256"],
    }


def cmd_golden(args) -> int:
    need_reference()
    files = corpus_files()
    if not files:
        sys.exit("waxdiff: corpus is empty; run `waxdiff.py collect` first")
    shutil.rmtree(GOLDEN, ignore_errors=True)
    GOLDEN.mkdir(parents=True, exist_ok=True)

    index: dict = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as ex:
        for res in ex.map(classify_one, files):
            index[res["file"]] = write_golden(res)

    counts: dict[str, int] = {}
    for v in index.values():
        counts[v["bucket"]] = counts.get(v["bucket"], 0) + 1
    (GOLDEN / "index.json").write_text(
        json.dumps(
            {
                "_comment": "The reference's expected behaviour for every corpus "
                "file. Committed, so `waxdiff.py run` needs neither the "
                "reference binary nor the wax/ checkout. A diff here is either "
                "your behaviour change or upstream's -- never edit it to make a "
                "test pass.",
                "reference": json.loads(
                    (ROOT / "tools" / "reference.json").read_text()
                )["sha256"],
                "counts": counts,
                "files": dict(sorted(index.items())),
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    for k in (SYNTAX_BAD, COMPILES_CLEAN, TYPE_BAD):
        print(f"  {k:15} {counts.get(k, 0):5}")
    print(f"  {'total':15} {len(index):5}")
    return 0


def cmd_classify(args) -> int:
    """Bucket counts without writing goldens -- a quick look at the corpus."""
    need_reference()
    files = corpus_files()
    counts: dict[str, int] = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as ex:
        for res in ex.map(classify_one, files):
            counts[res["bucket"]] = counts.get(res["bucket"], 0) + 1
    for k in (SYNTAX_BAD, COMPILES_CLEAN, TYPE_BAD):
        print(f"  {k:15} {counts.get(k, 0):5}")
    print(f"  {'total':15} {len(files):5}")
    return 0


# --------------------------------------------------------------------------
# run -- compare an implementation against the goldens
# --------------------------------------------------------------------------

POLICY_PATH = ROOT / "test" / "oracle-policy.json"


def load_policy(scope_override: str | None = None) -> dict:
    """Per-bucket expectations, loaded from test/oracle-policy.json.

    Kept as data because the expectations flip as the port grows: a type-bad
    file must draw no complaint from us today and must reproduce the reference's
    diagnostics exactly once the type checker lands. See the file's own comments.
    """
    p = json.loads(POLICY_PATH.read_text())
    scope = scope_override or p["scope"]
    if scope not in p["scopes"]:
        sys.exit(f"waxdiff: unknown policy scope {scope!r}")
    return {
        "scope": scope,
        "buckets": p["scopes"][scope],
        "gated": p["gated_fields"],
        "reported": p["reported_fields"],
    }


@dataclass
class Failure:
    file: str
    oracle: str
    detail: str


@dataclass
class Outcome:
    passed: int = 0
    failed: int = 0
    skipped: int = 0
    failures: list[Failure] = field(default_factory=list)
    drift: list[str] = field(default_factory=list)


def load_index() -> dict:
    p = GOLDEN / "index.json"
    if not p.exists():
        sys.exit("waxdiff: no goldens; run `waxdiff.py golden` first")
    return json.loads(p.read_text())["files"]


def parse_jsonl(text: str) -> list[dict]:
    return [json.loads(l) for l in text.splitlines() if l.strip()]


def impl_run(impl: list[str], *args: str) -> Run:
    return run([*impl, *args])


def check_oracle1(
    impl: list[str], rel: str, path: Path, meta: dict, out: Outcome, policy: dict
) -> None:
    """Reprint parity: our formatter's output must equal the reference's."""
    if policy["buckets"][meta["bucket"]]["oracle1"] == "skip":
        out.skipped += 1
        return
    want_path = GOLDEN / (rel.removesuffix(".wax") + ".reprint")
    if not want_path.exists():
        out.skipped += 1
        return
    got = impl_run(impl, str(path), "-f", "wax")
    want = want_path.read_bytes()
    if got.code != 0:
        out.failed += 1
        out.failures.append(
            Failure(rel, "reprint", f"exited {got.code}: {got.err.decode('utf-8', 'replace')[:400]}")
        )
        return
    if got.out != want:
        out.failed += 1
        out.failures.append(Failure(rel, "reprint", _text_diff(want, got.out)))
        return
    if not _check_idempotent(impl, rel, got.out, out):
        return
    out.passed += 1


# Files whose reprint the REFERENCE itself does not reproduce when fed back to
# it. Reprint parity is the gate, so matching the reference means inheriting
# its instability here; see test/UPSTREAM-FINDINGS.md findings 7 and 8. Listed
# rather than silently tolerated so the set cannot grow unnoticed.
NON_IDEMPOTENT_UPSTREAM = {
    "cram/custom-page-sizes__huge-pow2.wax",
    "docs/language__127_checked.wax",
    "docs/reference__129_checked.wax",
}


def _check_idempotent(impl: list[str], rel: str, once: bytes, out: Outcome) -> bool:
    """Formatting an already-formatted file must change nothing.

    A cheap check that catches printer bugs reprint parity cannot: a layout
    decision that depends on the input's incidental line breaks matches the
    reference on the corpus and still drifts on its own output.
    """
    with tempfile.NamedTemporaryFile(suffix=".wax", delete=False) as f:
        f.write(once)
        tmp = f.name
    try:
        twice = impl_run(impl, tmp, "-f", "wax")
    finally:
        os.unlink(tmp)
    stable = twice.code == 0 and twice.out == once
    expected_unstable = rel in NON_IDEMPOTENT_UPSTREAM
    if stable and expected_unstable:
        out.failed += 1
        out.failures.append(
            Failure(
                rel,
                "idempotence",
                "listed in NON_IDEMPOTENT_UPSTREAM but now stable; if upstream "
                "fixed this, drop the entry and the finding",
            )
        )
        return False
    if not stable and not expected_unstable:
        out.failed += 1
        out.failures.append(
            Failure(rel, "idempotence", _text_diff(once, twice.out))
        )
        return False
    return True


def check_oracle2(
    impl: list[str], rel: str, path: Path, meta: dict, out: Outcome, policy: dict
) -> None:
    """Wasm equivalence, routed through the reference back end.

    We have no code generator, so we cannot emit wasm directly. Instead we print
    the file with our formatter and hand THAT to the reference's back end: if our
    AST lost or garbled anything semantically relevant, the resulting binary
    differs from the one the reference produced from the original source.
    """
    want_sha = meta.get("wasm_sha256")
    if policy["buckets"][meta["bucket"]]["oracle2"] == "skip" or not want_sha:
        out.skipped += 1
        return
    printed = impl_run(impl, str(path), "-f", "wax")
    if printed.code != 0:
        out.failed += 1
        out.failures.append(Failure(rel, "wasm", f"reprint exited {printed.code}"))
        return
    tmp = REPORT / "tmp"
    tmp.mkdir(parents=True, exist_ok=True)
    mid = tmp / (rel.replace("/", "__"))
    mid.write_bytes(printed.out)
    built = wax(str(mid), "-f", "wasm", "-o", "-")
    if built.code != 0:
        out.failed += 1
        out.failures.append(
            Failure(rel, "wasm",
                    "our output does not compile: "
                    + built.err.decode("utf-8", "replace")[:400])
        )
        return
    got_sha = sha256(built.out)
    if got_sha != want_sha:
        out.failed += 1
        out.failures.append(
            Failure(rel, "wasm", f"binary differs (want {want_sha[:12]}, got {got_sha[:12]})")
        )
        return
    out.passed += 1


# The span fields, the only ones an exemption below can excuse.
SPAN_FIELDS = {"startLine", "startColumn", "endLine", "endColumn",
               "startOffset", "endOffset"}

# Files whose spans this port deliberately does not reproduce, each with the
# reason. Listed one by one so a divergence stays visible, stays bounded, and is
# noticed the day it stops happening -- the check below FAILS on a listed file
# whose spans agree, so a fix upstream (or here) surfaces as a red test rather
# than as a stale exemption nobody reads.
#
# This started as one list of seven under finding 9. Diff-fuzzing
# (`waxdiff.py fuzz`) turned up a mutant whose real cause was ours, not
# upstream's -- we lexed the whole file before parsing, so a stray character
# late in a file hid a syntax error early in it -- and fixing that, plus the
# same first-in-the-file rule for a semantic error an action records, made three
# of the seven agree exactly. The lesson is in the accounting: an exemption list
# that lumps unlike causes together stops being a record of a divergence and
# becomes a place bugs hide.
SPAN_EXEMPT = {
    # Finding 9: the offending token is a STRING, so the reference points at
    # its closing quote rather than at the string. We report the true span.
    "docs/language__092.wax": "finding 9 (string span)",
    "docs/language__094.wax": "finding 9 (string span)",
    "docs/reference__094.wax": "finding 9 (string span)",
    "docs/reference__096.wax": "finding 9 (string span)",
    # Finding 12, both directions: the two automata reduce at different
    # moments, so an action's check fires in one and not the other. Here the
    # reference runs the action and we do not; below, we run it and the
    # reference does not. Both are fuzz finds, adopted.
    "fuzz/hint-attr-then-syntax-error.wax": "finding 12 (action timing)",
    "fuzz/missing-params-then-syntax-error.wax": "finding 12 (action timing)",
}


def check_oracle3(
    impl: list[str], rel: str, path: Path, meta: dict, out: Outcome, policy: dict
) -> None:
    """Error parity: same diagnostics, same spans, same exit code."""
    mode = policy["buckets"][meta["bucket"]]["oracle3"]
    if mode == "skip":
        out.skipped += 1
        return

    want_path = GOLDEN / (rel.removesuffix(".wax") + ".diag.jsonl")
    want = parse_jsonl(want_path.read_text()) if want_path.exists() else []
    got_run = impl_run(impl, "check", "--error-format", "json", str(path))
    got = parse_jsonl(got_run.err.decode("utf-8", "replace"))

    if mode == "no-errors":
        # The file parses, so nothing in this port's scope can complain about
        # it. Only ERRORS are checked: the reference also emits lint warnings
        # here (unused-local, unused-field) and we implement no lints, so
        # warnings are ignored on both sides rather than compared.
        errors = [d for d in got if d.get("severity") == "error"]
        if errors:
            out.failed += 1
            out.failures.append(
                Failure(rel, "errors",
                        f"reported {len(errors)} error(s) on a {meta['bucket']} file, "
                        f"which parses cleanly; first: {errors[0].get('message')!r}")
            )
        else:
            out.passed += 1
        return

    if got_run.code != meta["diag_code"]:
        out.failed += 1
        out.failures.append(
            Failure(rel, "errors", f"exit {got_run.code}, want {meta['diag_code']}")
        )
        return
    if len(got) != len(want):
        out.failed += 1
        out.failures.append(
            Failure(rel, "errors", f"{len(got)} diagnostic(s), want {len(want)}")
        )
        return
    span_exempt = rel in SPAN_EXEMPT
    saw_span_divergence = False
    for i, (w, g) in enumerate(zip(want, got)):
        for f in policy["gated"]:
            if w.get(f) != g.get(f):
                # A listed divergence: see SPAN_EXEMPT for the reason this
                # file carries. Only span fields can be excused, and only for a
                # file that is on the list.
                if span_exempt and f in SPAN_FIELDS:
                    saw_span_divergence = True
                    out.drift.append(
                        f"{rel} #{i} {f} ({SPAN_EXEMPT[rel]})\n"
                        f"  ref: {w.get(f)!r}\n  ours: {g.get(f)!r}"
                    )
                    continue
                out.failed += 1
                out.failures.append(
                    Failure(rel, "errors", f"diagnostic {i} field {f}: got {g.get(f)!r}, want {w.get(f)!r}")
                )
                return
        for f in policy["reported"]:
            if w.get(f) != g.get(f):
                out.drift.append(f"{rel} #{i} {f}\n  ref: {w.get(f)!r}\n  ours: {g.get(f)!r}")
    if span_exempt and not saw_span_divergence and not policy.get("self_test"):
        out.failed += 1
        out.failures.append(
            Failure(rel, "errors",
                    f"listed in SPAN_EXEMPT as {SPAN_EXEMPT[rel]} but the spans "
                    "now agree; drop the entry and the finding it names")
        )
        return
    out.passed += 1


def _text_diff(want: bytes, got: bytes, context: int = 3) -> str:
    import difflib

    w = want.decode("utf-8", "replace").splitlines()
    g = got.decode("utf-8", "replace").splitlines()
    d = list(difflib.unified_diff(w, g, "reference", "ours", n=context, lineterm=""))
    return "\n".join(d[:60]) if d else "(differs only in trailing bytes)"


def cmd_run(args) -> int:
    index = load_index()
    impl = args.impl.split()
    policy = load_policy(args.scope)
    oracles = args.oracle or [1, 2, 3]

    if args.self_test:
        # Validating the harness by pointing --impl at the reference itself.
        # The mode *is* that substitution, so it picks the implementation
        # rather than trusting the default: `--self-test --impl tools/wax-mb`
        # would otherwise silently mean something else entirely.
        impl = [str(REFERENCE)]
        need_reference()
        #
        # Oracles 1 and 2 are scope-neutral -- they ask "does this produce the
        # same bytes?" -- so the reference must pass them perfectly, and any
        # failure is a harness bug.
        #
        # Oracle 3 is NOT scope-neutral. Its `no-errors` expectation asserts
        # that the implementation has no type checker, which is true of this
        # port and false of the reference: on a type-bad file the reference
        # correctly reports the type error the expectation forbids. So the
        # reference is only a valid stand-in on the buckets compared with
        # `match`, and the rest are skipped rather than counted as failures.
        #
        # The finding-9 span exemptions are likewise a property of the PORT, not
        # of the harness: the reference cannot diverge from its own goldens, so
        # the staleness check guarding them would fire on every listed file.
        policy["self_test"] = True
        for bucket, modes in policy["buckets"].items():
            if isinstance(modes, dict) and modes.get("oracle3") == "no-errors":
                modes["oracle3"] = "skip"
    if 2 in oracles:
        need_reference()
    REPORT.mkdir(parents=True, exist_ok=True)

    results = {o: Outcome() for o in oracles}
    files = sorted(index.items())
    if args.filter:
        files = [(r, m) for r, m in files if args.filter in r]

    def one(item):
        rel, meta = item
        path = CORPUS / rel
        if not path.exists():
            return None
        local = {o: Outcome() for o in oracles}
        if 1 in oracles:
            check_oracle1(impl, rel, path, meta, local[1], policy)
        if 2 in oracles:
            check_oracle2(impl, rel, path, meta, local[2], policy)
        if 3 in oracles:
            check_oracle3(impl, rel, path, meta, local[3], policy)
        return local

    # Parallel because this is the command run constantly during development:
    # serially it is ~8400 subprocesses over the full corpus.
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as ex:
        for local in ex.map(one, files):
            if local is None:
                continue
            for o in oracles:
                results[o].passed += local[o].passed
                results[o].failed += local[o].failed
                results[o].skipped += local[o].skipped
                results[o].failures.extend(local[o].failures)
                results[o].drift.extend(local[o].drift)

    names = {1: "reprint parity", 2: "wasm equivalence", 3: "error parity"}
    failed_total = 0
    lines = []
    for o in oracles:
        r = results[o]
        failed_total += r.failed
        lines.append(
            f"  oracle {o}  {names[o]:18} pass {r.passed:5}  fail {r.failed:5}  skip {r.skipped:5}"
        )
    print("\n".join(lines))

    detail = REPORT / "failures.md"
    with detail.open("w", encoding="utf-8") as fh:
        fh.write("# waxdiff failures\n\n")
        for o in oracles:
            for f in results[o].failures[: args.max_report]:
                fh.write(f"## {f.file} — {f.oracle}\n\n```\n{f.detail}\n```\n\n")
    drift = [d for o in oracles for d in results[o].drift]
    (REPORT / "message-drift.md").write_text(
        "# Diagnostic message drift (non-blocking)\n\n"
        "Spans and severity are gated; wording is not, yet. Each entry is a\n"
        "message this port words differently from the reference.\n\n"
        + "\n\n".join(drift[: args.max_report])
        + "\n",
        encoding="utf-8",
    )
    if drift:
        print(f"  message drift: {len(drift)} (see test/report/message-drift.md)")
    if failed_total:
        print(f"\n  {failed_total} failure(s); see test/report/failures.md")
        return 1
    return 0



# --------------------------------------------------------------------------
# fuzz -- the same oracles, on inputs nobody wrote
# --------------------------------------------------------------------------

# The corpus is 2112 files, every one of them hand-written, generated from the
# spec suite, or lifted from the docs. It covers what somebody thought to write
# down. This mutates those files and grades the result with the SAME three
# oracles, which needs no goldens: the reference is run on the mutant to say
# what the answer should be.
#
# Mutation is at TOKEN level, not byte level. Byte noise mostly produces
# something the lexer rejects, which only ever exercises oracle 3; moving,
# dropping and duplicating whole tokens keeps a mutant parseable often enough to
# reach the printer and the back end, which is where the interesting
# disagreements are.

FUZZ_FINDS = REPORT / "fuzz"

# Wax's lexical shapes, longest match first. This is deliberately NOT the
# port's own lexer: a mutator that shares a lexer with the implementation under
# test can only produce inputs that lexer already understands, which is the
# opposite of the point. It only has to be good enough to cut the source at
# plausible boundaries.
_TOKEN_RE = re.compile(
    r"""
      //[^\n]*                       # line comment
    | /\*(?:[^*]|\*(?!/))*\*/         # block comment
    | "(?:[^"\\]|\\.)*"             # string literal
    | '(?:[^'\\]|\\.)*'             # char literal, or a label's quote
    | [A-Za-z_][A-Za-z0-9_.]*        # identifier / keyword
    | 0[xXbBoO][0-9a-fA-F_]+         # radix literal
    | [0-9][0-9_]*(?:\.[0-9_]*)?      # number
    | >>=|<<=|>=s|>=u|<=s|<=u|>>s|>>u  # three-character operators
    | ->|=>|::|==|!=|<=|>=|<<|\+\+
    | \+=|-=|\*=|/=|%=|&=|\|=|\^=|:=
    | /s|/u|%s|%u|<s|<u|>s|>u
    | \S                             # anything else, one character
    """,
    re.VERBOSE,
)


def tokenize(src: str) -> list[str]:
    return _TOKEN_RE.findall(src)


def mutate(tokens: list[str], rng: random.Random) -> list[str]:
    """One token-level edit. Swap, delete, duplicate, or borrow.

    "Borrow" replaces a token with another drawn from the same file, which is
    what produces type-correct-looking nonsense -- an `i32` where a `&func`
    belongs -- rather than the syntax errors the other three tend toward.
    """
    if len(tokens) < 2:
        return tokens
    out = list(tokens)
    i = rng.randrange(len(out))
    kind = rng.choice(("swap", "delete", "duplicate", "borrow"))
    if kind == "swap":
        j = min(i + 1, len(out) - 1)
        out[i], out[j] = out[j], out[i]
    elif kind == "delete":
        del out[i]
    elif kind == "duplicate":
        out.insert(i, out[i])
    else:
        out[i] = out[rng.randrange(len(out))]
    return out


def render_tokens(tokens: list[str]) -> str:
    """Tokens back to source.

    Every token is separated by one space and every statement-ish token by a
    newline: layout is not what is under test here (the printer normalises it
    anyway), and a single line of 4000 tokens makes a find unreadable.
    """
    out = []
    for t in tokens:
        out.append(t)
        if t in (";", "{", "}") or t.startswith("//"):
            out.append("\n")
        else:
            out.append(" ")
    return "".join(out).strip() + "\n"


def _is_finding9(src: str, want: list[dict], got: list[dict]) -> bool:
    """Do these diagnostics differ only in the way finding 9 describes?

    On the corpus, finding 9 is handled by naming the four files it affects. A
    mutant has no name to put on a list, and the divergence is common enough in
    generated input to bury everything else -- so here it is recognised by its
    SHAPE: same diagnostics, differing only in span, with the reference's span
    being the last character of ours and ours starting at a quote.
    """
    if len(want) != len(got) or not want:
        return False
    for w, g in zip(want, got):
        for k in set(w) | set(g):
            if w.get(k) != g.get(k) and k not in SPAN_FIELDS:
                return False
        start, end = g.get("startOffset"), g.get("endOffset")
        if start is None or end is None or not 0 <= start < len(src):
            return False
        if src[start] != '"':
            return False
        if w.get("endOffset") != end or w.get("startOffset") != end - 1:
            return False
    return True


def grade(impl: list[str], src: str, policy: dict, oracles: list[int]) -> list[Failure]:
    """Run one mutant through the oracles. Empty means the two agreed."""
    global CORPUS, GOLDEN
    saved = (CORPUS, GOLDEN)
    scratch = Path(tempfile.mkdtemp(prefix="waxdiff-fuzz-"))
    exempted = False
    try:
        CORPUS, GOLDEN = scratch / "corpus", scratch / "golden"
        CORPUS.mkdir(parents=True)
        GOLDEN.mkdir(parents=True)
        path = CORPUS / "mutant.wax"
        path.write_text(src, encoding="utf-8")
        meta = write_golden(classify_one(path))
        want_path = GOLDEN / "mutant.diag.jsonl"
        if want_path.exists():
            want = parse_jsonl(want_path.read_text())
            got = parse_jsonl(
                impl_run(impl, "check", "--error-format", "json", str(path))
                .err.decode("utf-8", "replace")
            )
            if _is_finding9(src, want, got):
                SPAN_EXEMPT["mutant.wax"] = "finding 9 (string span)"
                exempted = True
        out = Outcome()
        if 1 in oracles:
            check_oracle1(impl, "mutant.wax", path, meta, out, policy)
        if 2 in oracles:
            check_oracle2(impl, "mutant.wax", path, meta, out, policy)
        if 3 in oracles:
            check_oracle3(impl, "mutant.wax", path, meta, out, policy)
        return out.failures
    finally:
        if exempted:
            SPAN_EXEMPT.pop("mutant.wax", None)
        CORPUS, GOLDEN = saved
        shutil.rmtree(scratch, ignore_errors=True)


def minimize(
    impl: list[str], tokens: list[str], policy: dict, oracles: list[int],
    budget: int = 400,
) -> list[str]:
    """Shrink a failing mutant by dropping tokens while it still fails.

    A find is only worth committing to the corpus if someone can read it, and a
    seed file runs to thousands of tokens. Delta debugging by CHUNKS -- halves,
    then quarters, down to single tokens -- gets most of the way in a few dozen
    attempts where one-token-at-a-time would need one attempt per token, each
    attempt being several processes.

    `budget` caps the attempts. A partly minimized find is still worth having;
    an hour spent shrinking one is not.
    """
    kept = list(tokens)
    spent = 0
    width = max(1, len(kept) // 2)
    while width >= 1 and spent < budget:
        i = 0
        shrunk = False
        while i < len(kept) and spent < budget:
            candidate = kept[:i] + kept[i + width :]
            spent += 1
            if candidate and grade(impl, render_tokens(candidate), policy, oracles):
                kept = candidate
                shrunk = True
            else:
                i += width
        if not shrunk:
            width //= 2
    return kept


def cmd_adopt(args) -> int:
    """Move a fuzz find into the corpus, where it becomes a permanent test.

    A find in test/report/ is transient -- the directory is gitignored and the
    next run overwrites it. Adopting one copies it under test/corpus/fuzz/ and
    records its provenance, so it is graded by every future `run` exactly like
    the hand-written files. `collect` leaves the fuzz/ subtree alone (it only
    rebuilds the sources it knows), so an adopted file survives a re-collection.
    """
    src = Path(args.file)
    if not src.exists():
        sys.exit(f"waxdiff: no such file: {src}")
    name = args.name or src.stem
    rel = f"fuzz/{name}.wax"
    dest = CORPUS / rel
    if dest.exists() and not args.force:
        sys.exit(f"waxdiff: {rel} already in the corpus (use --force to replace)")
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(src.read_text(encoding="utf-8"), encoding="utf-8")

    manifest_path = CORPUS / "manifest.json"
    manifest = json.loads(manifest_path.read_text())
    manifest["files"][rel] = {"origin": args.origin or f"fuzz find, from {src.name}"}
    manifest["files"] = dict(sorted(manifest["files"].items()))
    manifest["counts"]["fuzz"] = sum(
        1 for k in manifest["files"] if k.startswith("fuzz/")
    )
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"  adopted {rel}")
    print("  now run `waxdiff.py golden` to record what the reference does with it")
    return 0


def cmd_fuzz(args) -> int:
    need_reference()
    impl = args.impl.split()
    policy = load_policy(args.scope)
    oracles = args.oracle or [1, 2, 3]
    seed = args.seed if args.seed is not None else random.randrange(1 << 30)
    rng = random.Random(seed)
    print(f"  seed {seed} (reproduce with --seed {seed})")

    seeds = sorted(load_index().items())
    if args.filter:
        seeds = [(r, m) for r, m in seeds if args.filter in r]
    if not seeds:
        sys.exit("waxdiff: no seed files")

    FUZZ_FINDS.mkdir(parents=True, exist_ok=True)
    found = 0
    for n in range(args.count):
        rel, _meta = seeds[rng.randrange(len(seeds))]
        tokens = tokenize((CORPUS / rel).read_text(encoding="utf-8"))
        if len(tokens) < 2:
            continue
        for _ in range(rng.randint(1, args.edits)):
            tokens = mutate(tokens, rng)
        failures = grade(impl, render_tokens(tokens), policy, oracles)
        if not failures:
            continue
        found += 1
        # Minimize before reporting: an unminimized find is a wall of tokens,
        # and the point of a find is to become a corpus file someone can read.
        small = minimize(impl, tokens, policy, oracles)
        dest = FUZZ_FINDS / f"find-{seed}-{n}.wax"
        dest.write_text(render_tokens(small), encoding="utf-8")
        print(f"\n  FIND {dest.relative_to(ROOT)}  (from {rel})")
        for f in failures:
            print(f"    {f.oracle}: {f.detail.splitlines()[0][:120]}")

    print(f"\n  {args.count} mutants, {found} finding(s)")
    if found:
        print(f"  Minimized inputs in {FUZZ_FINDS.relative_to(ROOT)}. A real find")
        print("  belongs in test/corpus/ with a regenerated golden, so it stays a")
        print("  test after the bug is fixed.")
    return 1 if found else 0

# --------------------------------------------------------------------------
# classify-cram -- select the cram tests this port can run
# --------------------------------------------------------------------------

CRAM_SRC = ROOT / "wax" / "test" / "cram-tests"
CRAM_DST = ROOT / "test" / "cram"

# Flags wax-mb implements. A test using anything else is out of scope: running
# it would either fail on an unknown flag or, worse, pass while silently
# ignoring one.
CRAM_OK_FLAGS = {
    "-f", "--output-format", "--format",
    "-i", "--input-format",
    "-o", "--output",
    "--error-format",
    "--color",
    "-W", "--warn",
    "-c", "--check",
}

# Formats the port handles. `-f wat`, `-f wasm` and `-i wasm` all need the back
# end or the decompiler, neither of which exists yet.
CRAM_OK_FORMATS = {"wax"}


def _cram_commands(text: str) -> list[str]:
    """The shell commands a cram file runs.

    A command starts at a `  $ ` line and CONTINUES through the `  > ` lines
    under it -- which is how a cram test writes a fixture with a heredoc.
    Dropping the continuations would leave `cat > m.wax <<WAX` with no body.
    """
    out: list[str] = []
    for raw in text.splitlines():
        st = raw.strip()
        if st.startswith("$ "):
            out.append(st[2:])
        elif st.startswith("> ") and out:
            out[-1] += "\n" + st[2:]
        elif st == ">" and out:
            out[-1] += "\n"
    return out


# Interpreters that can invoke `wax` from inside a heredoc, where no static
# inspection can see the flags it is given.
CRAM_OPAQUE = {"python3", "python", "node", "perl", "ruby", "sh", "bash"}


def _cram_reason(cmd: str) -> str | None:
    """Why `cmd` is out of scope, or None when it is in scope.

    Only `wax` invocations are judged. A cram test may also run `cat`, `diff`
    or `printf` to set up or inspect a fixture, and cram runs those through a
    real shell, so they work here unchanged.
    """
    head = cmd.split("\n")[0]
    for seg in re.split(r"\|\||&&|[|;]", head):
        words = seg.split()
        while words and "=" in words[0] and not words[0].startswith("-"):
            words.pop(0)
        if words and words[0] in CRAM_OPAQUE:
            return f"drives wax from a {words[0]} script, so its invocations cannot be inspected"
        r = _cram_wax_reason(seg)
        if r:
            return r
    return None


# The subcommands wax-mb implements. `lsp`, `fmt-diff`, ... are not among them.
CRAM_OK_COMMANDS = {"convert", "format", "check"}


def _cram_wax_reason(seg: str) -> str | None:
    """Why this `wax` invocation is out of scope, or None when it is in scope.

    One pass, and it has to know which flags take a value: reading `-i wat` as
    a positional would report `wat` as an unimplemented SUBCOMMAND, which is
    both wrong and confusing in the scope report.
    """
    words = seg.split()
    # Strip leading `VAR=value` assignments, so `WAX_WARN=... wax check` is
    # recognised as a wax invocation -- and as a lint one.
    env = []
    while words and "=" in words[0] and not words[0].startswith("-"):
        env.append(words.pop(0))
    if not words or words[0] != "wax":
        return None
    if any(e.startswith("WAX_WARN=") for e in env):
        return "sets WAX_WARN, so it exercises a lint, which needs the type checker"

    valued = {"-f", "--output-format", "--format", "-i", "--input-format",
              "-o", "--output", "--error-format", "--color", "-W", "--warn",
              "-D", "--define", "-X", "--feature", "--debug"}
    formats = {"-f", "--output-format", "--format", "-i", "--input-format"}
    positionals: list[str] = []
    i = 1
    while i < len(words):
        w = words[i]
        if not w.startswith("-") or w == "-":
            positionals.append(w)
            i += 1
            continue
        name, eq, inline = w.partition("=")
        if name in ("-W", "--warn"):
            return "exercises a lint, which needs the type checker"
        if name not in CRAM_OK_FLAGS:
            return f"uses {name!r}, which wax-mb does not implement"
        if name in valued:
            val = inline if eq else (words[i + 1] if i + 1 < len(words) else "")
            if name in formats and val not in CRAM_OK_FORMATS:
                return f"converts to/from {val!r}; only wax is implemented"
            i += 1 if eq else 2
        else:
            i += 1

    # The first positional names a subcommand only when it is not a path.
    if positionals:
        head = positionals[0]
        if "." not in head and "/" not in head:
            if head not in CRAM_OK_COMMANDS:
                return f"runs the {head!r} subcommand, which wax-mb does not implement"
            positionals = positionals[1:]
    for w in positionals:
        if "." in w and not w.endswith(".wax"):
            # With no -i, the format is inferred from the extension, so a .wat
            # or .wasm argument needs the decompiler or the binary reader.
            return f"reads {w.rsplit('.', 1)[1]!r} input; only wax is implemented"
    return None


def _cram_needs_typer(d: Path, text: str) -> str | None:
    """Whether the test depends on the type checker.

    Decided by the REFERENCE rather than by reading the expectations, and on a
    MATERIALIZED copy of the test: most fixtures are written by a heredoc in
    the test itself, so they do not exist until the setup commands have run.

    The rule is precise. For each `wax` command, run the reference on the same
    inputs twice: once as a plain reprint (`-f wax`, which does not validate)
    and once as the command asks. A file that reprints cleanly but is rejected
    anyway failed in the type checker, and this port would exit 0 where the
    test expects 128.
    """
    if "Warning:" in text or "Suggestion:" in text:
        return "expects a warning or suggestion, which needs the type checker"
    with tempfile.TemporaryDirectory() as tmp:
        sandbox = Path(tmp) / d.name
        shutil.copytree(d, sandbox)
        for cmd in _cram_commands(text):
            if not any(seg.split()[:1] == ["wax"] for seg in
                       re.split(r"\|\||&&|[|;]", cmd) if seg.split()):
                # A setup command (a heredoc, a mkdir): run it, so the fixtures
                # it writes exist for the commands that follow.
                subprocess.run(cmd, shell=True, cwd=sandbox,
                               capture_output=True, timeout=60)
                continue
            args = cmd.split()
            inputs = [w for w in args[1:]
                      if not w.startswith("-") and w.endswith(".wax")]
            real = subprocess.run([str(REFERENCE), *args[1:]], cwd=sandbox,
                                  capture_output=True, timeout=60)
            if real.returncode == 0:
                continue
            for f in inputs:
                parsed = subprocess.run([str(REFERENCE), f, "-f", "wax"],
                                        cwd=sandbox, capture_output=True,
                                        timeout=60)
                if parsed.returncode == 0:
                    return f"`{f}` parses but is rejected later, so the test needs the type checker"
    return None


def cmd_classify_cram(args) -> int:
    """Copy the in-scope cram tests into test/cram/, and list the rest.

    Selection is mechanical -- every `$` command is checked against the flags
    wax-mb implements -- and the excluded set is WRITTEN OUT rather than
    silently dropped, so "we run 40 of 329" cannot quietly become "we run 12".
    """
    if not CRAM_SRC.is_dir():
        sys.exit(f"waxdiff: no cram tests at {CRAM_SRC}")
    included, excluded = [], []
    for d in sorted(CRAM_SRC.iterdir()):
        run = d / "run.t"
        if not run.is_file():
            continue
        text = run.read_text()
        reasons = [r for r in (_cram_reason(c) for c in _cram_commands(text)) if r]
        if "../" in text:
            # Reaches outside its own directory -- typically into the wax
            # checkout's docs -- so it cannot run from a copied-out sandbox.
            reasons.append("reads paths outside its own directory")
        if not reasons:
            r = _cram_needs_typer(d, text)
            if r:
                reasons = [r]
        if reasons:
            excluded.append((d.name, sorted(set(reasons))[0]))
        else:
            included.append(d.name)

    if not args.dry_run:
        if CRAM_DST.exists():
            shutil.rmtree(CRAM_DST)
        CRAM_DST.mkdir(parents=True)
        for name in included:
            shutil.copytree(CRAM_SRC / name, CRAM_DST / name)

    report = ROOT / "test" / "cram-scope.md"
    lines = [
        "# Cram tests: what this port runs",
        "",
        "Generated by `waxdiff.py classify-cram`. A test is in scope when every",
        "`wax` command it runs uses only flags and formats wax-mb implements;",
        "anything else is listed below with the reason, so the excluded set stays",
        "visible instead of shrinking unnoticed.",
        "",
        f"In scope: **{len(included)}** of {len(included) + len(excluded)}.",
        "",
        "That is a small fraction, and the reasons below say why: the",
        "reference's cram suite is overwhelmingly about the two things this",
        "port does not implement -- conversion to and from wat/wasm, and the",
        "type checker with its lints. The differential oracles are what cover",
        "the front end, over 2112 corpus files; these tests add the CLI's own",
        "behaviour (exit codes, which stream output goes to, flag handling).",
        "",
        "## Excluded",
        "",
        "| test | why |",
        "|---|---|",
    ]
    for name, why in sorted(excluded):
        lines.append(f"| `{name}` | {why} |")
    lines.append("")
    if not args.dry_run:
        report.write_text("\n".join(lines))
    print(f"  in scope  {len(included)}")
    print(f"  excluded  {len(excluded)}  (see test/cram-scope.md)")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(prog="waxdiff", description=__doc__)
    sub = ap.add_subparsers(dest="cmd", required=True)

    c = sub.add_parser("collect", help="build test/corpus/ from the wax/ checkout")
    c.add_argument(
        "--only",
        action="append",
        choices=["cram", "docs", "wat", "spec"],
        help="rebuild only these sources (repeatable); others are left alone",
    )
    c.add_argument("--spec-limit", type=int, default=None, help="cap .wast files")
    c.add_argument(
        "--spec-per-wast",
        type=int,
        default=5,
        help="modules kept per .wast file (default 5; see collect_spec)",
    )
    c.set_defaults(fn=cmd_collect)

    c = sub.add_parser("classify", help="show bucket counts for the corpus")
    c.add_argument("-j", "--jobs", type=int, default=default_jobs())
    c.set_defaults(fn=cmd_classify)

    c = sub.add_parser(
        "fuzz", help="mutate corpus files and grade the mutants with the oracles"
    )
    c.add_argument(
        "--impl", default="tools/wax-mb", help="the implementation under test"
    )
    c.add_argument("--count", type=int, default=100, help="mutants to try (default 100)")
    c.add_argument(
        "--edits",
        type=int,
        default=3,
        help="at most this many token edits per mutant (default 3)",
    )
    c.add_argument(
        "--seed",
        type=int,
        default=None,
        help="PRNG seed; printed on every run so a find can be reproduced",
    )
    c.add_argument("--filter", help="only seed from files whose path contains this")
    c.add_argument("--oracle", type=int, action="append", choices=[1, 2, 3])
    c.add_argument("--scope", choices=["front-end", "full"], default=None)
    c.set_defaults(fn=cmd_fuzz)

    c = sub.add_parser(
        "adopt", help="move a fuzz find into test/corpus/ as a permanent test"
    )
    c.add_argument("file", help="the find, e.g. test/report/fuzz/find-7-2.wax")
    c.add_argument("--name", help="corpus name (default: the file's stem)")
    c.add_argument("--origin", help="provenance line for the manifest")
    c.add_argument("--force", action="store_true", help="replace an existing entry")
    c.set_defaults(fn=cmd_adopt)

    c = sub.add_parser(
        "classify-cram",
        help="copy the in-scope cram tests into test/cram/ and list the rest",
    )
    c.add_argument("--dry-run", action="store_true", help="report without writing")
    c.set_defaults(fn=cmd_classify_cram)

    c = sub.add_parser("golden", help="record reference outputs into test/golden/")
    c.add_argument("-j", "--jobs", type=int, default=default_jobs())
    c.set_defaults(fn=cmd_golden)

    c = sub.add_parser("run", help="compare an implementation against the goldens")
    c.add_argument(
        "--impl",
        default="tools/wax-ref",
        help="the implementation under test, invoked with the reference's own "
        "command line; pass tools/wax-mb for the port. The default compares the "
        "reference against its own goldens, which passes trivially whatever the "
        "port does -- prefer --self-test when that is what you actually want.",
    )
    c.add_argument(
        "--oracle",
        type=int,
        action="append",
        choices=[1, 2, 3],
        help="run only these oracles (repeatable). Oracle 2 needs the reference "
        "binary; 1 and 3 compare against committed goldens only.",
    )
    c.add_argument("--filter", help="only files whose path contains this substring")
    c.add_argument(
        "--scope",
        choices=["front-end", "full"],
        default=None,
        help="override the policy scope in test/oracle-policy.json. 'full' is "
        "for phase 6+, once the type checker is ported.",
    )
    c.add_argument("-j", "--jobs", type=int, default=default_jobs())
    c.add_argument(
        "--self-test",
        action="store_true",
        help="validate the harness itself: forces --impl to tools/wax-ref, so "
        "the reference is compared against its own goldens. Skips the "
        "oracle-3 buckets where the reference is knowingly not a valid stand-in "
        "for a front-end-only port; everything else must pass perfectly.",
    )
    c.add_argument(
        "--max-report",
        type=int,
        default=50,
        help="cap entries written to test/report/ (default 50)",
    )
    c.set_defaults(fn=cmd_run)

    args = ap.parse_args()
    return args.fn(args)


if __name__ == "__main__":
    sys.exit(main())
