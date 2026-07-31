#!/usr/bin/env python3
"""Compare this port's grammar against the reference's, rule by rule.

The corpus test proves the parser BEHAVES like the reference on ~2100 files.
This is the complementary structural check: that the grammar is a faithful
translation rather than something that merely happens to accept the same inputs.
It is also the only handle on conflict-resolution fidelity, since MoonYacc
reports conflicts without saying where they are: if the productions and
precedence declarations match a grammar Menhir accepts cleanly, and both
generators use Pager LR(1), the same declarations should resolve the same way.

Usage:
    tools/grammar_fidelity.py            # needs the wax/ checkout and moon

Actions are stripped by BRACE MATCHING, not by line shape. That matters: an
OCaml action containing a `match` has arms beginning with `|`, which a
line-based reader counts as extra grammar alternatives -- it reported 8
productions for raw_statement_list where there are 6.
"""

from __future__ import annotations

import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
REF_MLY = ROOT / "wax" / "src" / "lib-wax" / "parser.mly"
OUR_MBTY = ROOT / "grammar" / "parser.mbty"

# Rules this port renamed. The stdlib equivalents differ in name only.
RENAMES = {
    "list": "list_of",
    "separated_nonempty_list_trailing": "non_empty_sep_trailing",
    "separated_list_trailing": "sep_trailing",
}

# Rules that exist only here, each replacing an ANONYMOUS inline production the
# reference writes inside an ioption/option -- e.g. `ioption(":" t = type_name
# { t })`. MoonYacc requires those to be named, so they become real rules.
OUR_HELPERS = {
    "describes_clause", "descriptor_clause", "else_branch", "function_type_as",
    "fundecl_type", "if_block_type", "labelled", "let_init", "limit_max",
    "loption_data_init", "result_arrow", "semi_then_statements",
    "supertype_clause", "table_init", "tag_type", "type_annot",
    # Replaces the stdlib `list`, which returns @list.List while the AST holds
    # arrays. Right-recursive, matching the stdlib -- see the note in
    # parser.mbty about what left recursion did here.
    "list_of",
}

# Rules whose production COUNT legitimately differs, with the reason.
EXPECTED_COUNT_DIFFS = {
    # The reference wraps these in the stdlib's loption/separated_nonempty_list;
    # this port spells the wrapper out, since the stdlib versions return
    # @list.List while the AST holds arrays.
    "separated_list_trailing": "loption(...) spelled out as two productions",
    "data_init": "separated_nonempty_list('++', ...) spelled out",
}


def strip_ocaml_comments(text: str) -> str:
    """Remove (* ... *), which nest."""
    out, depth, i = [], 0, 0
    while i < len(text):
        if text.startswith("(*", i):
            depth += 1
            i += 2
        elif text.startswith("*)", i) and depth:
            depth -= 1
            i += 2
        else:
            if not depth:
                out.append(text[i])
            i += 1
    return "".join(out)


ACTION_MARK = " @ACT@ "


def strip_actions(text: str) -> str:
    """Replace {...} action blocks with a marker, honouring nesting.

    A MARKER rather than nothing, because an empty production is written
    `| { [] }` and would otherwise become indistinguishable from the whitespace
    Menhir leaves before its first alternative -- which is how an earlier
    version of this script silently lost the empty production of every list
    rule.
    """
    out, depth, i = [], 0, 0
    while i < len(text):
        c = text[i]
        if c == "{":
            if depth == 0:
                out.append(ACTION_MARK)
            depth += 1
        elif c == "}":
            if depth:
                depth -= 1
        elif not depth:
            out.append(c)
        i += 1
    return "".join(out)


def parse_grammar(text: str, ocaml: bool) -> dict[str, list[tuple[str, ...]]]:
    text = text[text.index("\n%%") + 3 :]
    if ocaml:
        text = strip_ocaml_comments(text)
    else:
        text = re.sub(r"//[^\n]*", "", text)
    text = strip_actions(text)

    # A rule starts at column 0. Menhir does not require a `;` terminator and
    # the reference does not use one, so rules are delimited by the next
    # column-0 header rather than by punctuation.
    HEADER = re.compile(
        r"^(?:%inline\s+)?([a-z_][A-Za-z_0-9]*)\s*(?:\[[^\]]*\])?\s*"
        r"(?:\([^)]*\))?\s*(?:->[^:\n]*)?:",
        re.M,
    )
    rules: dict[str, list[tuple[str, ...]]] = {}
    matches = list(HEADER.finditer(text))
    for idx, m in enumerate(matches):
        name = m.group(1)
        stop = matches[idx + 1].start() if idx + 1 < len(matches) else len(text)
        body = text[m.end() : stop]
        alts = body.split("|")
        # Menhir conventionally writes a leading `|` before its FIRST
        # alternative, where MoonYacc uses `:`. That leaves an empty leading
        # piece -- but only when it is genuinely whitespace: `| { [] }` is a
        # real empty production, and its action marker is what tells the two
        # apart.
        if alts and not alts[0].strip():
            alts = alts[1:]
        prods = []
        for alt in alts:
            alt = alt.replace(";", " ").replace(ACTION_MARK.strip(), " ")
            alt = re.sub(r"%prec\s+\w+", "", alt)
            # Menhir binders: `x = sym`
            alt = re.sub(r"\b[a-zA-Z_][a-zA-Z_0-9]*\s*=\s*", "", alt)
            prods.append(tuple(alt.split()))
        rules[name] = prods
    return rules


def main() -> int:
    if not REF_MLY.exists():
        sys.exit(f"reference grammar missing: {REF_MLY}\nrun tools/fetch-reference-source.sh")

    dump = subprocess.run(
        ["moon", "runwasm", "moonbitlang/yacc@0.7.18", "--",
         "--print-as-mly-without-actions", "parser.mbty"],
        cwd=ROOT / "grammar", capture_output=True, text=True,
    )
    if not dump.stdout.strip():
        sys.exit("could not dump our grammar:\n" + dump.stderr)

    ours = parse_grammar(dump.stdout, ocaml=False)
    ref = parse_grammar(REF_MLY.read_text(), ocaml=True)

    ref_mapped = {RENAMES.get(k, k): v for k, v in ref.items() if k != "dummy_ctx"}

    missing = sorted(set(ref_mapped) - set(ours))
    extra = sorted(set(ours) - set(ref_mapped) - OUR_HELPERS)

    print(f"reference rules: {len(ref_mapped)}")
    print(f"our rules:       {len(ours)} ({len(OUR_HELPERS)} named helpers for "
          f"the reference's anonymous inline productions)")

    problems = 0
    if missing:
        problems += len(missing)
        print(f"\nMISSING from this port ({len(missing)}):")
        for r in missing:
            print(f"  {r}")
    if extra:
        problems += len(extra)
        print(f"\nUNEXPLAINED extra rules ({len(extra)}):")
        for r in extra:
            print(f"  {r}")

    count_diffs = []
    for rk, prods in ref.items():
        ok = RENAMES.get(rk, rk)
        if ok not in ours or rk == "dummy_ctx":
            continue
        if len(prods) != len(ours[ok]):
            count_diffs.append((rk, len(prods), len(ours[ok])))

    unexplained = [d for d in count_diffs if d[0] not in EXPECTED_COUNT_DIFFS]
    if count_diffs:
        print(f"\nproduction-count differences ({len(count_diffs)}):")
        for r, a, b in count_diffs:
            why = EXPECTED_COUNT_DIFFS.get(r, "UNEXPLAINED")
            print(f"  {r}: reference {a}, ours {b}  -- {why}")
    problems += len(unexplained)

    if problems:
        print(f"\n{problems} unexplained difference(s)")
        return 1
    print("\nno unexplained differences")
    return 0


if __name__ == "__main__":
    sys.exit(main())
