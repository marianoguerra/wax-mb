# Vendored from `Milky2018/wasm_core`

This package started as [`Milky2018/wasm_core`][wasm_core] 0.5.0, taken from
[`Milky2018/wasmoon`][wasmoon] at commit `e720f3d`. Both projects are
Apache-2.0. The pin lives in `tools/reference.json`'s sibling
`tools/vendor.json`, and `tools/fetch-vendor.sh` verifies it and reports
upstream drift.

## Why a fork rather than a dependency

The reason to use it at all is the opcode table: ~700 lines mapping the
instruction model to bytes, which is ~700 lines not hand-ported from
`wasm_output.ml`. That part transfers close to verbatim.

Everything around it had to change in ways a published dependency cannot be
asked to. Two reasons, and only the first is about upstream:

1. **The type spine.** `wasm_types` is generic over `Idx` precisely so that the
   Wax form (`Idx = Ident`, types named) and the binary form (`Idx = Int`,
   types numbered) are two instances of one family rather than two copies. Any
   external model is a third copy, and lowering into it would mean converting at
   a seam that exists only because of the dependency.
2. **Silent wrongness.** Upstream's encoder never fails. Where it does not know
   what to do it writes *something*, and the something is always plausible: a
   valid module that loads, validates and does the wrong thing. Against a
   byte-identity oracle that is the worst available failure mode, because the
   diff says "these bytes differ" and not "this is unhandled".

## What changed

### The spine

- `ValueType`, a flat enum of 31 constructors (`RefStruct`, `RefNullFuncTyped`,
  …), is replaced by `@wasm_types.ValType[Int]`, i.e. `Ref(RefType)` over
  `{nullable, HeapType}`. Upstream's enum cannot spell `(ref null $t)` for a
  `$t` that is not a func, struct or array; has no `exact` and no
  `cont`/`nocont`; and, because nullability is part of the constructor name, it
  forced `ref.test` and `ref.test null` apart into two instructions differing
  only in a flag. All three go away.
- `Limits` likewise comes from the spine. Upstream split it into `{min, max}`
  plus `is_memory64` and `page_size_log2` on `MemoryType` and `is_table64` on
  `TableType`, and had no `shared` at all — so a shared memory was not merely
  misencoded, it was unrepresentable.
- Names are `Bytes`, not `String`. That is what the format specifies and what
  the Wax AST already carries, so the hand-rolled UTF-8 re-encoder went too.
- `encode` returns `Bytes` rather than `Array[Int]` (one `Int` per byte).

### The silent fallbacks, and what removing them found

Deleting the catch-alls turned four of these into compiler errors, which is how
they were counted.

| upstream | what it did | now |
|---|---|---|
| `_ => w.write_byte(0x00)` in the opcode table | emitted `unreachable` for anything unmatched | gone, and with it the 256 instructions it hid — all of SIMD beyond loads and stores, `i64.mul_wide_s`/`_u`, and the atomics. Their opcodes came from `wasm-encoder`'s table. The match is now total over `Instruction`, which the compiler checks. |
| `MultiValue \| InlineType => w.write_byte(0x40)` | wrote the *empty* block type, discarding the results | `raise UnresolvedBlockType` |
| `_ => w.write_u32(0)` in the element section | wrote function index **0** for any initialiser that was not a bare `ref.func` | the compact encoding is chosen only when every initialiser is one; otherwise expressions are written |
| `fn encode_memarg(_memidx, …)` | ignored the memory index outright | bit 6 of the alignment plus the index, per multi-memory |

### Encodings that were wrong

- **Rec groups were dropped.** `type_rec_groups` existed on the model and was
  never read: the type section wrote a count of *types* and each type flat, so
  any group of mutually recursive types came out as unrelated definitions.
  Replaced by `rec_groups : Array[RecGroup]`, which partitions the flat type
  array. `explicit` is carried because a singleton `rec` is a different type
  from the same definition written bare — recursive type identity is by group —
  so the prefix cannot be inferred from the length.
- **Reference types mixed the long and short forms.** A nullable reference to an
  abstract heap type has a one-byte abbreviation; upstream's flat enum forced
  the choice per constructor and came out inconsistent (`funcref` short,
  `anyref` long). Both spellings are valid and they differ in bytes, which is
  exactly what a byte-identity oracle cannot tolerate. Now one rule, matching
  `wasm-encoder`.
- **`ref.null`, `ref.test`, `ref.cast`, `br_on_cast` took value types.** The
  format's operand there is a *heap* type, so each was prefixed with a spurious
  `0x63`/`0x64`.
- **Data segments used a negative memory index** as the passive marker and
  decided the encoding from `offset.is_empty()`. Replaced by an explicit
  `DataMode`.

### Dropped

The runtime `Value` type, structural hashing and equality, the `Show` instances
(debug reprs, not WAT), the validator-facing `*_type_at` helpers, and the
`subtyping`, `equivalence`, `bit_conversion` and `numeric_limits` modules.
None of them is on the path from a module to bytes.

### Added

- **The custom sections.** Upstream emits none. `name` (all twelve
  subsections), `target_features`, and the four `metadata.code.*` sections are
  here.
- **The hint sink.** A `metadata.code.*` entry is keyed by its instruction's
  byte offset within the function body, which is knowable exactly once — while
  that opcode is being written. So the writer carries an optional sink, present
  only while a body is being encoded, and `Hinted` is a wrapper constructor
  that emits no opcode of its own. This is what `wasm_output.ml` does with
  `Encoder.hint_sink`, for the same reason.
- **Stack switching.** Seven instructions (`cont.new`, `cont.bind`, `suspend`,
  `resume`, `resume_throw`, `resume_throw_ref`, `switch`) plus the resume table.
  Upstream's model could not express any of them, though the Wax AST has had
  them since Phase 2.
- **`atomic.fence`**, which cannot be spelled as an `Atomic` with a degenerate
  memarg: the format wants a single `0x00` where the memarg would go.

## What is still missing

`sourceMappingURL`, and the source map it points at. Both are only emitted
under `--source-map`, which the goldens do not use, so this is the one gap that
byte identity over the corpus will not notice.

## Upstreaming

The fallback removal, the structured `RefType` and the rec-group fix are all
plausibly useful to `wasm_core` and are not Wax-specific. Contributing them back
would shrink this fork to the custom sections, which genuinely are ours.

[wasm_core]: https://mooncakes.io/docs/Milky2018/wasm_core@0.5.0
[wasmoon]: https://github.com/Milky2018/wasmoon
