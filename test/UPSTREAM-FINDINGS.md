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
