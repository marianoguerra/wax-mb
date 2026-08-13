#!/usr/bin/env python3
"""Report public items in `lib/` that nothing outside their package uses.

A `.mbti` file is the semver contract: once a name is in one, removing it is a
breaking change. Most of the names in these are not promises -- they are `pub`
because `pub` was what got typed, and the first release is the last cheap chance
to say so.

This REPORTS, it does not gate. Two reasons it cannot gate:

  * It is a text search, not a compiler. A name reached through a trait, a
    derived implementation or a method call on an inferred receiver is used and
    is not found here.
  * A library may legitimately export something nothing in this repository
    calls. That is the whole point of `ast/build`, and of half of `wasm/bin`.

So the number is a prompt to look, and the way to drive it down is deliberately,
one package at a time -- not by making CI red.

Usage:
    tools/api_audit.py               # summary, one line per package
    tools/api_audit.py --detail      # every unused name
    tools/api_audit.py --pkg check   # one package, in detail
"""

from __future__ import annotations

import argparse
import re
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / "lib"
# Every module in the workspace. `cli` and `dev` reach `lib` only through its
# public surface, so what they use is by construction what has to stay public.
SOURCE_ROOTS = [ROOT / "lib", ROOT / "cli", ROOT / "test", ROOT / "tools", ROOT / "printer_pp"]

IMPORT_LINE = re.compile(r'"([A-Za-z0-9_/\-]+)"\s*(?:@([A-Za-z0-9_]+))?')

# `pub fn name(`, `pub fn Type::name(`, `pub let name :`, `pub fn[T] name(`
MBTI_FN = re.compile(r"^pub(?:\((?:all|open|readonly)\))? fn(?:\[[^\]]*\])? ([A-Za-z0-9_]+)(?:::([A-Za-z0-9_]+))?\(")
MBTI_LET = re.compile(r"^pub(?:\((?:all|open|readonly)\))? (?:let|const) ([A-Za-z0-9_]+)")
MBTI_TYPE = re.compile(
    r"^pub(?:\((?:all|open|readonly)\))? (?:struct|enum|type|trait|suberror|typealias) ([A-Za-z0-9_]+)"
)


def packages() -> list[Path]:
    """Every package directory in `lib/`, innermost path first."""
    return sorted(p.parent for p in LIB.rglob("moon.pkg"))


def pkg_import_path(d: Path) -> str:
    rel = d.relative_to(LIB).as_posix()
    return "marianoguerra/wax" if rel == "." else f"marianoguerra/wax/{rel}"


def public_names(d: Path) -> set[str]:
    """The names a `.mbti` promises.

    Methods count under their own name rather than `Type::name`: a call site
    writes `x.name(...)`, and the type it is written on is not in the text.
    """
    mbti = d / "pkg.generated.mbti"
    if not mbti.exists():
        return set()
    out: set[str] = set()
    for line in mbti.read_text().splitlines():
        m = MBTI_FN.match(line)
        if m:
            out.add(m.group(2) or m.group(1))
            continue
        for pat in (MBTI_LET, MBTI_TYPE):
            m = pat.match(line)
            if m:
                out.add(m.group(1))
                break
    return out


def aliases_for(pkg: str, importer: Path) -> set[str]:
    """What `importer` calls `pkg`, if it imports it at all."""
    cfg = importer / "moon.pkg"
    if not cfg.exists():
        return set()
    found = set()
    for path, alias in IMPORT_LINE.findall(cfg.read_text()):
        if path == pkg:
            found.add(alias or path.rsplit("/", 1)[-1])
    return found


def sources(d: Path) -> list[Path]:
    return [f for f in d.glob("*.mbt")]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--detail", action="store_true", help="list every unused name")
    ap.add_argument("--pkg", help="only this package, e.g. check or wasm/bin")
    args = ap.parse_args()

    all_pkgs = packages()
    # Every package in the workspace that could import a lib package.
    importers = [p.parent for r in SOURCE_ROOTS for p in r.rglob("moon.pkg")]

    rows = []
    for d in all_pkgs:
        name = pkg_import_path(d)
        short = d.relative_to(LIB).as_posix()
        if args.pkg and short != args.pkg:
            continue
        names = public_names(d)
        if not names:
            continue
        used: set[str] = set()
        for imp in importers:
            if imp == d:
                continue
            aliases = aliases_for(name, imp)
            if not aliases:
                continue
            text = "\n".join(f.read_text() for f in sources(imp))
            for a in aliases:
                for hit in re.findall(rf"@{a}\.([A-Za-z0-9_]+)", text):
                    used.add(hit)
            # A method is called on the value, not on the package.
            for hit in re.findall(r"\.([A-Za-z0-9_]+)\(", text):
                used.add(hit)
        unused = sorted(names - used)
        rows.append((short, len(names), len(unused), unused))

    rows.sort(key=lambda r: -r[2])
    total_pub = sum(r[1] for r in rows)
    total_unused = sum(r[2] for r in rows)
    print(f"{'package':28} {'pub':>5} {'unused':>7}")
    for short, n, u, unused in rows:
        if u == 0 and not args.pkg:
            continue
        print(f"{short:28} {n:5} {u:7}")
        if args.detail or args.pkg:
            for x in unused:
                print(f"    {x}")
    print(f"{'':28} {total_pub:5} {total_unused:7}   total")
    return 0


if __name__ == "__main__":
    sys.exit(main())
