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
