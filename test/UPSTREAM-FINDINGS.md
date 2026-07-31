# Findings about the reference implementation

Things noticed about [ocsigen/wax](https://github.com/ocsigen/wax) while porting
it. These are not bugs in this port; they are recorded here because they affect
how the differential harness has to behave, and because they are worth reporting
upstream.

Reference pinned at `edge` / commit `9002a71`, reporting `0.1.1~dev`.

---

## 1. `array.new_fixed` DoS is fixed in `check` but not in the wax output path

**Input:** `wax/test/cram-tests/array-new-fixed-large-count.t/poly.wat` — which
is upstream's *own* regression test for this class of bug.

```wat
(module
  (type $vec (array f32))
  (func (result (ref $vec))
    unreachable
    array.new_fixed $vec 4294967295))
```

Measured with `/usr/bin/time -f '%e s %M KB'` under a 2 GB cgroup cap:

| command | time | peak RSS | result |
|---|---|---|---|
| `wax check poly.wat` | 0.12 s | 13 MB | ok |
| `wax -i wat -f wat poly.wat` | 0.11 s | 12 MB | ok |
| `wax -i wat -f wax poly.wat` | 3.65 s | **2.1 GB** | killed at the cap |

`run.t` in that directory explains the fix precisely:

> Typing it by popping the element type that many times is O(count) and lets an
> adversarial module (count = 2^32-1) tie up the validator. On a polymorphic
> stack (here, after `unreachable`) every pop past the base trivially succeeds,
> so once the stack is polymorphic the remaining pops are stopped early.

That early-stop is in the validator, which is why `check` is fast. The
**WAT → Wax conversion** path does not have it: it still materialises the
element list, and memory grows without bound. The cram test only exercises
`wax check`, so the gap is invisible to upstream's suite.

Uncapped, this is enough to invoke the machine's OOM killer.

**Consequence for this port:** `tools/waxdiff.py` caps *every* reference
invocation with `systemd-run --user --scope -p MemoryMax=… -p MemorySwapMax=0`.
The corpus deliberately contains adversarial inputs — that is where a
reimplementation diverges — so the harness has to survive them by construction
rather than by curating them out.

**Note for phase 6+:** the analogous MoonBit code must stop early too. Any
`array.new_fixed` handling that is O(count) rather than O(operands actually
present) reproduces this bug.

---

# Findings about MoonYacc

Reference: `moonbitlang/yacc@0.7.18`, invoked via `moon runwasm`.

## 2. `%nonassoc` panics instead of installing an error action

`%nonassoc` is standard yacc: when a conflict arises at that precedence level,
the generator installs an **error** action, making the construct a syntax error.
MoonYacc instead panics — `RuntimeError: unreachable`, with no diagnostic and no
indication of which rule is at fault.

Minimal reproduction (20 lines, no dependencies):

```
%position<Int>
%token<Int> NUM
%token EQEQ "=="
%token PLUS "+"
%token EOF

%left "+"
%nonassoc "=="

%start parse
%%
parse -> Int : expr EOF { $1 } ;
expr -> Int
  : NUM { $1 }
  | expr "+" expr { $1 + $3 }
  | expr "==" expr { if $1 == $3 { 1 } else { 0 } }
  ;
```

Changing `%nonassoc "=="` to `%left "=="` makes it build, which isolates the
trigger to `%nonassoc`.

**Why it matters here.** The Wax grammar declares all 14 comparison operators
`%nonassoc`, which is exactly what makes `1 < 2 < 3` a syntax error while
`1 < (2 < 3)` and `(1 < 2) < 3` are accepted — verified against the pinned
reference binary. The panic makes a faithful translation impossible as written.

**Workaround** (`grammar/parser.mbty`, `grammar/context.mbt`): declare the level
`%left` and enforce non-associativity in the semantic action, rejecting a
comparison whose left operand is an unparenthesized comparison. The reference
reports this at the *second* operator, and `%left` associativity puts exactly
that token on the outer node, so the span matches. Distinguishing the chained
form from the parenthesized one needs information the AST does not carry — the
parenthesized production returns its inner instruction unchanged — so
parenthesized spans are recorded in a side table rather than adding a paren node
the reference does not have.

## 3. Semantic actions cannot raise

Generated actions have the type

```
type YYAction = (Position, ArrayView[(YYObj, Position, Position)]) -> YYObj
```

with no error in the signature, so an action cannot propagate one. The reference
raises freely from inside its actions (`Identifier '%s' is not a value type`,
`A parameter list is required`, …).

**Workaround**: record the first error in a package-level ref and return a
placeholder value; the driver reports it and discards the tree. This matches the
reference's observable behaviour, since it also stops at the first error — but
it means every failing action needs a dummy value of the right type, which is
noise the reference does not have.

## 4. Conflicts are reported only on a fresh generation

MoonYacc prints `Shift-reduce conflict resolved without precedence` (and the
other cases in `lr1/resolve_conflicts.mbt`) while generating. A cached
`parser.mbt` means `moon check` reports nothing, so a grammar change can appear
clean when it is not. **Delete the generated file before trusting a clean run.**

It reports neither the count nor the location of a conflict, so narrowing one
down means bisecting the grammar by hand.

## 5. `%inline` mis-maps semantic-value indices

MoonYacc's inliner assigns the wrong argument slots when an inlined rule can
expand to nothing. The failure is at RUN TIME, not generation time: the emitted
action either reads one past the end of its argument view

```
at @moonbitlang/core/builtin.index_out_of_bounds[...]
at @waxmb/wax/grammar.yy_action_326
```

or guards for the wrong payload type and throws — here, an action for
`block_label "{" statement_list "}"` guarded `_args[0].0 is YYObj_Ident_` when
`block_label` yields `Ident?`.

Both were triggered by a production containing two `%inline` symbols that could
each vanish (`block_label`, itself `ioption(labelled)`, plus a trailing
`ioption(else_branch)`).

**Workaround**: `%inline` is not used anywhere in this grammar, though the
reference uses it on 21 rules. Inlining never changes the language a grammar
accepts — only how many distinct LR states it has — so the cost is
error-message granularity, which is not gated here, and nothing else.

## 6. A note on list recursion (not a bug, but a trap)

The stdlib's `list` is right-recursive. Defining an array-returning equivalent
*left*-recursively — the obvious choice, since it avoids repeated array copying
— silently changes the automaton: the parser must reduce the empty list before
shifting the first token.

At the start of a Wax module field that means committing to
`list_of(attribute) definition` while the lookahead is still `#`, which also
begins `#[if(...)]`. That is a shift-reduce conflict; resolved by shift, it made
**1013 of 1903** corpus files fail with `Expecting 'if', 'else'`. It also
accounted for all 6 of the shift-reduce conflicts the generator was reporting.

Match the reference's recursion direction unless there is a specific reason not
to.

## 7. `pagesize` is printed through a signed shift

`wax/src/lib-wax/output.ml:1860` computes the page size as
`Int64.to_string (Int64.shift_left 1L p)` from the stored base-2 logarithm.
For `p = 63` that overflows into the sign bit, so

```wax
memory m: i32 [1] pagesize 9223372036854775808;
```

reprints as

```wax
memory m: i32 [1] pagesize -9223372036854775808;
```

which is not accepted as input — the reference's own reprint does not round
trip. `test/corpus/cram/custom-page-sizes__huge-pow2.wax` is the fixture.

The port reproduces it, since Oracle 1 gates on byte-exact agreement with the
reference and this is what the reference emits. Should upstream switch to an
unsigned rendering, this port has to follow in the same commit.

## 8. A comment ending a block escapes it on reformat

A comment that is the last thing inside a block attaches to the block's last
CHILD, not to the block. When that child is a function whose body is otherwise
empty, the reprint hoists the comment out:

```wax
#[if(debug)]
{
    const debug_enabled: i32 = 1;
    fn debug_log(msg: i32) {
        // ...
    }
}
```

reprints as

```wax
#[if(debug)]
{
    const debug_enabled: i32 = 1;
    fn debug_log(msg: i32) {}
    // ...
}
```

so the comment now sits beside the function rather than inside it, and a second
pass leaves it there. The reference is not idempotent on these two fixtures
(`docs/language__127_checked.wax`, `docs/reference__129_checked.wax`).

Since Oracle 1 gates on byte-exact reprint parity, matching the reference means
inheriting the instability. Both files are listed in `NON_IDEMPOTENT_UPSTREAM`
in `tools/waxdiff.py`, which fails if one of them ever becomes stable — so the
day upstream fixes this, the harness says so rather than quietly diverging.

## 9. A syntax error at a string literal points at its closing quote

When the token the parser cannot shift is a STRING, the reference reports the
error at the string's closing quote rather than at the string:

```
$ cat t.wax
"hello";
$ wax check --error-format json t.wax
... "startOffset":6,"endOffset":7 ...     # the `"` at offset 6
```

`"hello"` spans offsets 0-7, and the reference's own token carries that span:
`with_loc` (`wax/src/lib-wax/lexer.ml:147`) records
`lexing_bytes_position_start` before scanning and
`lexing_bytes_position_curr` after. But a string is scanned by a RECURSIVE
sedlex rule, so by the time the parser fails, the lexbuf's own
start position has advanced to the last sub-lexeme matched -- the closing
quote -- and Menhir's error reporting reads the lexbuf rather than the token.

The artifact is specific to tokens scanned by a recursive rule. It is
reproducible on demand:

| input | true token span | reference reports |
|---|---|---|
| `"hello";` | 0-7 | 6-7 |
| `"a\tb";` | 0-6 | 5-6 |
| `/*c*/ "xy";` | 6-10 | 9-10 |
| `'a';` (char: one rule, no recursion) | 0-3 | 0-3 |
| `foobar;` | 0-6 | 0-6 |

This port reports the string's true span. It is the one place where it
deliberately does NOT reproduce the reference's spans, because the divergence
exists only in the diagnostic and copying it would mean pointing users at the
wrong character. The seven affected corpus files are listed in
`SPAN_DIVERGENCE_UPSTREAM` in `tools/waxdiff.py`, which fails if one of them
ever starts agreeing -- so an upstream fix surfaces as a failing test rather
than as silent drift.
