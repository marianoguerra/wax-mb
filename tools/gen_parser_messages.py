#!/usr/bin/env python3
"""Generate lib/syntax/parser/parser_messages.mbt from the reference's message golden.

The reference's syntax messages are produced offline by `stele` from Menhir's
automaton -- item sets, spurious reductions, the lot -- and shipped as a
per-state table. None of that input exists here: MoonYacc offers no automaton
dump, so the messages cannot be DERIVED. What it does offer, once the parser is
built with --table, is a state number (see grammar/state.mbt).

So the table is REKEYED rather than rederived. `parser_messages.expected` is a
committed golden of every message the reference generates, each paired with the
token sentence that reaches it. Writing that sentence out as source and parsing
it here says which of OUR states the reference's state corresponds to, and the
message can then be looked up by our state number at run time.

One state is not always enough. Menhir's subject comes from reductions it
performs at the error, which depend on the parser's STACK -- so where it
distinguishes "the argument list is complete" from "the index expression is
complete", MoonYacc has one state (55, "after an expression") that 14 of the
reference's messages claim. The key is therefore a stack SUFFIX, taken only as
deep as it needs to be: one frame resolves 435 of the 550 sentences, two
resolve 533, and the table records the shallowest suffix that is unanimous.

What makes it sound rather than a guess is that every entry is checked: the
sentence must fail on its LAST token (otherwise the source we wrote is not the
sentence the reference meant), and a key two different reference messages claim
is dropped rather than guessed at. Both counts are printed.

It writes a second file first, `error_reduce.mbt`: which of OUR nonterminals
are the ones the reference declares `%on_error_reduce`. Menhir makes those
reductions before it reports an error, so the stack it names is the one they
lead to; `ErrorState::reduced_stack` replays them, and keys a second table on
where they end. The ids come from the tables of a COMMENTED moonyacc build
(each action names its source line, so its rule), and a parameterised list is
matched to its element by the automaton itself: its instance over X is the one
a goto on X leads into. The tree is then rebuilt, since errstate needs the set.

Needs the `wax/` checkout. Like regenerating goldens, this is a deliberate
local act; the OUTPUT is committed.

    moon build --target native && tools/gen_parser_messages.py && moon fmt

The `moon fmt` matters: the arms are long enough that the formatter rewraps
them, and CI checks that a formatted tree is a committed tree.
"""
import re
import subprocess
import sys
import tempfile
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EXPECTED = ROOT / "wax/src/lib-wax/parser_messages.expected"
GRAMMAR = ROOT / "lib/syntax/parser/parser.mbty"
OUT = ROOT / "lib/syntax/parser/parser_messages.mbt"
REDUCE_OUT = ROOT / "lib/syntax/parser/error_reduce.mbt"
MLY = ROOT / "wax/src/lib-wax/parser.mly"
MOONYACC = ["moonx", "moonbitlang/yacc@0.7.25"]
ERRSTATE = ROOT / "_build/native/debug/build/marianoguerra/wax-dev/tools/errstate/errstate.exe"

# The terminals with no alias in the grammar: what a user actually types.
# EOF is written as nothing at all -- our lexer appends it.
VALUE_LEXEME = {
    "IDENT": "x",
    "INT": "1",
    "FLOAT": "1.0",
    "STRING": '"s"',
    "CHAR": "'c'",
    "EOF": "",
    "INF": "inf",
    "NAN": "nan",
}


def aliases() -> dict[str, str]:
    """Token name -> its source spelling, from the %token declarations."""
    out = {}
    for line in GRAMMAR.read_text().splitlines():
        m = re.match(r'%token(?:<[^>]*>)?\s+(.*)$', line.strip())
        if not m:
            continue
        m2 = re.match(r'(\w+)\s+"(.*)"$', m.group(1))
        if m2:
            out[m2.group(1)] = m2.group(2)
    return out


ALIAS = aliases()


def lexeme(t: str) -> str:
    if t in ALIAS:
        return ALIAS[t]
    if t in VALUE_LEXEME:
        return VALUE_LEXEME[t]
    # An unaliased keyword is spelled as its own lowercase name.
    return t.lower()


def render(sentence: list[str]) -> str:
    """Write a token sentence out as source, one token per lexeme."""
    parts = []
    for t in sentence:
        lx = lexeme(t)
        if not lx:
            continue
        # `'` then an identifier is a LABEL and must not be separated, or the
        # lexer tries to read a character literal across the space.
        if parts and parts[-1] == "'":
            parts[-1] = "'" + lx
        else:
            parts.append(lx)
    return " ".join(parts)


def entries():
    """(entry point, sentence, message, markers) per block of the golden."""
    blocks = EXPECTED.read_text().split("\n\n")
    out = []
    for i in range(0, len(blocks) - 1, 2):
        head, body = blocks[i].strip(), blocks[i + 1].strip()
        if ":" not in head:
            continue
        entry, sentence = head.split(":", 1)
        lines = body.splitlines()
        out.append(
            {
                "entry": entry.strip(),
                "sentence": sentence.split(),
                "message": lines[0] if lines else "",
                "markers": lines[1:],
            }
        )
    return out


def states_of(sources: list[str]) -> list[tuple | None]:
    """(state, stack, index, count, signature, reduced) per source, via tools/errstate.

    errstate prints more columns than this needs (the per-cell spans and the
    resolved label positions, for diagnosing by hand); the rest are ignored.
    """
    if not ERRSTATE.exists():
        sys.exit("gen_parser_messages: run 'moon build --target native' first")
    with tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False) as fh:
        fh.write("\n".join(sources) + "\n")
        path = fh.name
    out = subprocess.run([str(ERRSTATE), path], capture_output=True, check=True)
    rows = out.stdout.decode().splitlines()
    if len(rows) != len(sources):
        sys.exit(f"gen_parser_messages: {len(rows)} rows for {len(sources)} sources")
    parsed = []
    for r in rows:
        if r == "-":
            parsed.append(None)
            continue
        cols = r.split("\t")
        state, stack, idx, count, signature = cols[:5]
        reduced = None if cols[8] == "-" else [int(s) for s in cols[8].split()]
        parsed.append(
            (
                int(state),
                [int(s) for s in stack.split()],
                int(idx),
                int(count),
                signature,
                reduced,
            )
        )
    return parsed


def mbt_string(s: str) -> str:
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def labels_of(markers: list[str]) -> tuple[str, str]:
    """The `<^N>subject` and `<N>opener` marker lines, as their label texts.

    Both are 1-based indices into MENHIR's stack, which is not ours -- the two
    automata reduce at different moments, so the depth does not carry over.
    Only the label text does; where it points is worked out here at run time
    (`subject_span` and `enclosing_opener` in grammar/state.mbt).
    """
    subject = opener = ""
    for line in markers:
        m = re.match(r"<(\^?)(\d+)>(.*)$", line)
        if not m:
            continue
        if m.group(1) == "^":
            subject = m.group(3).strip()
        else:
            opener = m.group(3).strip()
    return subject, opener


def key_of(stack: list[int], depth: int) -> str:
    return " ".join(str(s) for s in stack[-depth:])


def build(items: list[tuple[list[int], str]], depth: int, out: dict) -> int:
    """Fill `out` with key -> (signature, message), deepening where contested.

    Returns the number of entries dropped as unresolvable -- a key claimed by
    two messages whose stacks are identical as far down as they go.
    """
    dropped = 0
    groups = defaultdict(list)
    for stack, value in items:
        groups[key_of(stack, depth)].append((stack, value))
    for key, group in groups.items():
        values = {v for _, v in group}
        if len(values) == 1:
            out[key] = values.pop()
            continue
        # Contested. Deepening only helps if some stack HAS another frame.
        if not any(len(stack) > depth for stack, _ in group):
            dropped += len(group)
            continue
        out[key] = None  # "look one frame deeper"
        dropped += build(group, depth + 1, out)
    return dropped


def parser_tables(src: str, name: str) -> list[int]:
    m = re.search(r"let %s : FixedArray\[\w+\] = \[(.*?)\]" % name, src, re.S)
    return [
        int(x.strip().replace("yy_action_", ""))
        for x in m.group(1).replace("\n", " ").split(",")
        if x.strip()
    ]


# How the reference spells a parameterised rule, against how our grammar does.
GENERIC = {
    "separated_nonempty_list_trailing": "non_empty_sep_trailing",
    "list": "list_of",
    "semi_list": "semi_list",
}


def on_error_reduce_ids() -> dict[int, str]:
    """Our nonterminal id -> the reference's `%on_error_reduce` symbol it is."""
    with tempfile.TemporaryDirectory() as d:
        out = Path(d) / "parser.mbt"
        subprocess.run(
            [*MOONYACC, "--external-tokens", "--table", str(GRAMMAR), "-o", str(out)],
            check=True,
            capture_output=True,
        )
        src = out.read_text()
    lhs = parser_tables(src, "yy_prod_lhs_table")
    act = parser_tables(src, "yy_prod_act_table")
    length = parser_tables(src, "yy_prod_len_table")
    table = parser_tables(src, "yy_state_table")
    m = re.search(r"fn yy_state\(.*?\[state \* (\d+) \+ symbol\]", src, re.S)
    cols = int(m.group(1))
    m = re.search(r"2\.\.=(\d+) => Shift.*?(\d+)\.\.=(\d+) =>", src, re.S)
    last_shift, first_reduce, last_reduce = int(m.group(1)), int(m.group(2)), int(m.group(3))

    def decide(s, sym):
        e = table[s * cols + sym]
        if 2 <= e <= last_shift:
            return ("shift", e - 2)
        if e >= first_reduce:
            p = e - first_reduce if e <= last_reduce else e - (last_reduce + 1)
            return ("reduce", p)
        return None

    rules = GRAMMAR.read_text().splitlines()

    def rule_at(line: int) -> str:
        for i in range(line - 1, -1, -1):
            r = re.match(r"^([a-z_][a-z0-9_]*)\b", rules[i])
            if r:
                return r.group(1)
        sys.exit(f"gen_parser_messages: no rule above parser.mbty:{line}")

    # moonyacc's own library rules (option, list) carry another file's lines;
    # they are never on the reference's list, so they get no name.
    line_of = {
        int(a): int(l)
        # An action spanning several source lines is quoted line by line.
        for f, l, a in re.findall(
            r"// file:///(\S+)\n// (\d+)\|[^\n]*\n(?:// \d+\|[^\n]*\n)*"
            r"fn yy_action_(\d+)\(",
            src,
        )
        if f.endswith("parser.mbty")
    }
    ids_of = defaultdict(set)
    for p in range(len(lhs)):
        if act[p] in line_of:
            ids_of[rule_at(line_of[act[p]])].add(lhs[p])
    terminals = int(
        re.search(
            r"let terminal_symbol_count = (\d+)",
            (ROOT / "lib/syntax/parser/state.mbt").read_text(),
        ).group(1)
    )
    states = len(table) // cols

    out = {}
    for d in re.search(r"%on_error_reduce (.*)", MLY.read_text()).group(1).split():
        g = re.match(r'(\w+)\((?:"[^"]*",)?(\w+)\)$', d)
        if not g:
            found = set(ids_of.get(d, ()))
        else:
            if len(ids_of[g.group(2)]) != 1:
                sys.exit(f"gen_parser_messages: no single rule {g.group(2)}: {sorted(ids_of[g.group(2)])}")
            (x,) = ids_of[g.group(2)]
            found = set()
            for L in ids_of[GENERIC[g.group(1)]]:
                for s in range(states):
                    t = decide(s, x)
                    if not t or t[0] != "shift":
                        continue
                    t = t[1]
                    reduces_x = any(
                        (r := decide(t, a)) and r[0] == "reduce"
                        and lhs[r[1]] == L and length[r[1]] == 1
                        for a in range(1, terminals + 1)
                    )
                    goto = decide(t, L)
                    if reduces_x or (goto and goto[0] == "shift"):
                        found.add(L)
                        break
        # One of ours per declared symbol, or the mapping is not to be trusted.
        if len(found) != 1:
            sys.exit(f"gen_parser_messages: {d} maps to {sorted(found)} of ours")
        out[found.pop()] = d
    return out


def write_error_reduce(ids: dict[int, str]) -> None:
    arms = "\n".join(f"    {i} => true // {d}" for i, d in sorted(ids.items()))
    REDUCE_OUT.write_text(
        f'''// The reference's `%on_error_reduce` set, as OUR nonterminal ids.
//
// GENERATED by tools/gen_parser_messages.py from wax/src/lib-wax/parser.mly
// and parser.mbty -- do not edit. The ids are the generated parser's, so this
// is stale the moment the grammar changes: regenerate with the messages.

///|
/// Whether Menhir reduces to `symbol` when an error is detected. See
/// `error_reduction`.
fn on_error_reduce(symbol : Int) -> Bool {{
  match symbol {{
{arms}
    _ => false
  }}
}}
''',
        encoding="utf-8",
    )


def main():
    ids = on_error_reduce_ids()
    write_error_reduce(ids)
    print(f"on_error_reduce:    {len(ids)} symbols")
    subprocess.run(["moon", "build", "--target", "native"], cwd=ROOT, check=True,
                   capture_output=True)

    # `dummy_ctx` is the reference's fake start symbol, declared to keep its
    # unused-token report quiet. No real parse enters there.
    es = [e for e in entries() if e["entry"] != "dummy_ctx"]
    sources = [render(e["sentence"]) for e in es]
    results = states_of(sources)

    parsed_fine = misplaced = 0
    items = []
    reduced_items = []
    for e, r in zip(es, results):
        if r is None:
            parsed_fine += 1
            continue
        _state, stack, idx, _count, signature, reduced = r
        # The sentence's last token is the offending one by construction, so
        # anything else means the source we wrote is not that sentence.
        if idx != len([t for t in e["sentence"] if lexeme(t) != ""]) - 1:
            misplaced += 1
            continue
        subject, opener = labels_of(e["markers"])
        items.append((stack, (signature, e["message"], subject, opener)))
        if reduced is not None:
            reduced_items.append(
                (reduced, (signature, e["message"], subject, opener))
            )

    table: dict[str, str | None] = {}
    dropped = build(items, 1, table)
    resolved = {k: v for k, v in table.items() if v is not None}
    # The same messages keyed by the stack each sentence REDUCES to, consulted
    # only when the failing stack misses. Menhir names the state it reaches
    # after the reductions the offending token cannot stop; MoonYacc fails
    # before making them, so `x y` and `'c' y` fail in different states here
    # but reduce to the same one -- the one Menhir reports from.
    # Only the END of the chain: keying every step was tried and is worse --
    # Menhir stops short in some contexts (a `br_if` operand) and not in
    # others (a statement), and a one-step key then borrows the wrong one.
    reduced_table: dict[str, str | None] = {}
    reduced_dropped = build(reduced_items, 1, reduced_table)
    reduced_resolved = {k: v for k, v in reduced_table.items() if v is not None}
    max_depth = (
        max(len(k.split()) for k in [*table, *reduced_table])
        if table
        else 0
    )
    shallow = sum(1 for k in resolved if len(k.split()) == 1)

    print(f"entries:            {len(es)}")
    print(f"  we parse them:    {parsed_fine}")
    print(f"  wrong token:      {misplaced}")
    print(f"  dropped:          {dropped} (a key two messages claim, no deeper frame)")
    print(f"  keys:             {len(resolved)} ({shallow} on one frame)")
    print(f"  reduced keys:     {len(reduced_resolved)} ({reduced_dropped} dropped)")
    print(f"  deepest key:      {max_depth} frames")

    def arms_of(t):
        arms = []
        for key in sorted(t, key=lambda k: (len(k.split()), k)):
            v = t[key]
            arms.append(
                f'    {mbt_string(key)} => Some('
                + (
                    "Deeper"
                    if v is None
                    else "Msg({signature: %s, text: %s, subject: %s, opener: %s})"
                    % tuple(mbt_string(x) for x in v)
                )
                + ")"
            )
        return "\n".join(arms)

    body = arms_of(table)
    reduced_body = arms_of(reduced_table)
    OUT.write_text(
        f'''// The reference's syntax messages, keyed by OUR parser stack.
//
// GENERATED by tools/gen_parser_messages.py from
// wax/src/lib-wax/parser_messages.expected -- do not edit. Regenerating needs
// the wax/ checkout and is a deliberate local act, like regenerating goldens.
//
// The reference derives these from Menhir's automaton with `stele`: the
// "Assuming that the X is complete" subject names the grammar symbol the parser
// was in the middle of, which no MoonYacc error value carries and no
// expected-token set determines ("an expression", "a then-branch" and "an index
// expression" share theirs exactly). What CAN be recovered here is the state
// stack (grammar/state.mbt), so the reference's own table is rekeyed onto it:
// each of its error sentences is written out as source, parsed, and the stack
// it fails on becomes the key.
//
// The key is the SHALLOWEST stack suffix that names one message. Most are one
// frame; Menhir distinguishes by the reductions it performs at the error, which
// depend on the stack, so where it has several messages our state 55 ("after an
// expression") needs a second frame to tell them apart. `Deeper` says to
// extend the key by one more frame.
//
// {len(resolved)} keys from the golden's {len(es)} sentences, {dropped} dropped
// as unresolvable. A miss retries with the stack the failure REDUCES to, in a
// second table built the same way ({len(reduced_resolved)} keys, {reduced_dropped} dropped): Menhir
// reports from the state after those reductions, MoonYacc fails before them.
// A miss in both falls back to the locally rendered `Expecting ...` list,
// which is always correct if less specific.

///|
/// One recorded message.
priv struct Message {{
  /// The acceptable-token signature it was recorded with. A stack suffix can
  /// recur in a context whose continuations differ; this is what tells the two
  /// apart.
  signature : String
  text : String
  /// The label on the construct the hedge names ("this statement"), or "" when
  /// the reference emits none. Where it points is `ErrorState::subject_span`.
  subject : String
  /// The label on the enclosing construct's opening delimiter, or "". Where it
  /// points is `enclosing_opener`.
  opener : String
}}

///|
priv enum Entry {{
  Msg(Message)
  Deeper
}}

///|
/// The reference's message for a failing stack, bottom first, or None.
fn reference_message(stack : ArrayView[Int], signature : String) -> Message? {{
  lookup(stack, signature, entry_of)
}}

///|
/// The reference's message for the stack a failure reduces to, or None.
fn reduced_message(stack : ArrayView[Int], signature : String) -> Message? {{
  lookup(stack, signature, entry_of_reduced)
}}

///|
/// Walks from the top frame down, deepening only where the table says the
/// shallower key stands for more than one message.
fn lookup(
  stack : ArrayView[Int],
  signature : String,
  entry_of : (String) -> Entry?,
) -> Message? {{
  let key = StringBuilder()
  for depth = 1; depth <= stack.length() && depth <= {max_depth}; depth = depth + 1 {{
    // The key reads bottom-up within the suffix, as the generator writes it.
    key.reset()
    let from = stack.length() - depth
    for i in from..<stack.length() {{
      if i > from {{
        key.write_char(' ')
      }}
      key.write_string(stack[i].to_string())
    }}
    match entry_of(key.to_string()) {{
      None => return None
      // The signature is proof the recorded context is this one. Failing
      // that, the message may still be borrowed if it names only tokens this
      // state accepts -- see `message_fits`.
      Some(Msg(m)) =>
        return if m.signature == signature || message_fits(m.text, signature) {{
          Some(m)
        }} else {{
          None
        }}
      Some(Deeper) => continue
    }}
  }}
  None
}}

///|
fn entry_of(key : String) -> Entry? {{
  match key {{
{body}
    _ => None
  }}
}}

///|
fn entry_of_reduced(key : String) -> Entry? {{
  match key {{
{reduced_body}
    _ => None
  }}
}}
''',
        encoding="utf-8",
    )
    print(f"\nwrote {OUT.relative_to(ROOT)}")


main()
