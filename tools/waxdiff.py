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
    if not REFERENCE.exists():
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
            rel = res["file"]
            stem = rel.removesuffix(".wax")
            # The reprint text is Oracle 1's expected output, so store it as a
            # real file: a golden diff should be reviewable line by line, not a
            # hash that only says "something changed".
            if res["reprint"] is not None:
                p = GOLDEN / f"{stem}.reprint"
                p.parent.mkdir(parents=True, exist_ok=True)
                p.write_text(res["reprint"], encoding="utf-8")
            if res["diagnostics"]:
                p = GOLDEN / f"{stem}.diag.jsonl"
                p.parent.mkdir(parents=True, exist_ok=True)
                p.write_text(res["diagnostics"], encoding="utf-8")
            index[rel] = {
                "bucket": res["bucket"],
                "reprint_code": res["reprint_code"],
                "diag_code": res["diag_code"],
                "wasm_sha256": res["wasm_sha256"],
            }

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
    for i, (w, g) in enumerate(zip(want, got)):
        for f in policy["gated"]:
            if w.get(f) != g.get(f):
                out.failed += 1
                out.failures.append(
                    Failure(rel, "errors", f"diagnostic {i} field {f}: got {g.get(f)!r}, want {w.get(f)!r}")
                )
                return
        for f in policy["reported"]:
            if w.get(f) != g.get(f):
                out.drift.append(f"{rel} #{i} {f}\n  ref: {w.get(f)!r}\n  ours: {g.get(f)!r}")
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

    c = sub.add_parser("golden", help="record reference outputs into test/golden/")
    c.add_argument("-j", "--jobs", type=int, default=default_jobs())
    c.set_defaults(fn=cmd_golden)

    c = sub.add_parser("run", help="compare an implementation against the goldens")
    c.add_argument(
        "--impl",
        default="tools/wax-ref",
        help="the implementation under test, invoked with the reference's own "
        "command line. Defaults to the reference itself, which self-tests the "
        "harness: every oracle must pass trivially.",
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
        help="validate the harness itself with --impl tools/wax-ref. Skips the "
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
