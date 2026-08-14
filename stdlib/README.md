# Wax standard library sources

This directory contains dependency-free Wax sources for projects that use Wax
as a compilation target. Wax currently has no source import system, package
manager, generics, or source-level privacy, so the library is distributed as
prefixed `.wax` files that are concatenated before application code.

Vendor a complete immutable-data profile with:

```sh
tools/vendor-stdlib.sh path/to/vendor/wax data
```

Concatenate the files in this order:

1. `hashing.wax`
2. `persistent_hash_map.wax`
3. `persistent_hash_set.wax`
4. `persistent_vector.wax`
5. `utf8.wax`
6. `immutable_value.wax`
7. `record.wax`

The `text`, `collections`, and `all` profiles copy the corresponding subsets.
The older `tools/vendor-collections.sh` remains available for collection-only
consumers.

## Immutable UTF-8 strings

`text/utf8.wax` defines an owned `utf8_string`. Construction validates UTF-8
and copies the input. Copying is necessary because WebAssembly GC does not
offer a way to fill an immutable array dynamically. The backing byte array is
mutable but private by API convention: do not access `storage_internal`
directly after concatenating the source.

Core operations are:

```wax
utf8_try_from_bytes(bytes) -> (i32, &?utf8_string)
utf8_from_bytes(bytes) -> &utf8_string
utf8_empty() -> &utf8_string
utf8_copy_bytes(string) -> &wax_hash_bytes
utf8_byte_length/utf8_codepoint_length(...)
utf8_get_byte/utf8_at_byte(...)
utf8_equal/utf8_compare/utf8_hash(...)
utf8_concat(left, right) -> &utf8_string
utf8_try_slice_bytes/utf8_slice_bytes(...)
utf8_each_codepoint(string, context, visit)
```

Slices use byte offsets but accept only complete code-point boundaries.
`utf8_hash_key` and `utf8_equal_key` are directly compatible with the
persistent hash map. Hashes are cached MurmurHash3 values and are not
cryptographic.

## Immutable values

`data/immutable_value.wax` defines an open `jv_value` hierarchy with distinct
null, bool, UTF-8 string, i32, i64, f32, f64, vector, string-keyed map, opaque
`any`, set, insertion-ordered map, and insertion-ordered set variants.
Constructors are named `jv_null`, `jv_bool`,
`jv_string`, `jv_i32`, `jv_i64`, `jv_f32`, `jv_f64`, and `jv_any`; collection
values begin with `jv_vector_empty`, `jv_map_empty`, `jv_set_empty`,
`jv_ordered_map_empty`, and `jv_ordered_set_empty`.

Each scalar has a safe `jv_get_*` accessor and a trapping `jv_require_*`
accessor. Typed collection APIs wrap the persistent vector, map, and set so
their elements remain `&jv_value`. Transient builders use the `jvt_*` prefix
and trap if reused after `*_persistent`.

`jv_equal` and `jv_hash` are structural. Numeric variants remain distinct;
f32/f64 compare exact bit patterns, including NaNs and signed zero. Map and set
hashing is order-independent. Ordered maps and sets compare and hash in
insertion order, and are distinct from their unordered counterparts. Opaque
`any` values compare by GC reference
identity when they are in the equality hierarchy. WebAssembly exposes no
identity hash, so every `any` receives the same kind-specific hash; correctness
is preserved, but a set containing many opaque values will have collisions.

Values built through the public API are immutable and acyclic. An opaque
`any` payload may refer to mutable application state; the value retains the
reference but cannot make the referenced object immutable.

### Ordered collections

`jv_ordered_map_*` mirrors the string-keyed `jv_map_*` API and
`jv_ordered_set_*` mirrors `jv_set_*`, including set algebra and consuming
`jvt_ordered_*` builders. Iteration follows insertion order. Associating an
existing map key changes its value without moving it, and adding an existing
set member is a no-op. Removing and later reinserting a key or member appends
it at the end.

The implementation follows Immutable.js's ordered-collection organization: a
HAMT indexes entries held in a persistent vector. Removal leaves a tombstone;
trailing tombstones are removed immediately and sparse vectors are compacted
without changing encounter order. Ordered operations have the same amortized
`O(log32 N)` lookup/update shape as the underlying collections, with additional
memory for the order index.

## Runtime-defined records

`data/record.wax` adds `jv_record_value`, a named immutable record whose fields
are declared at runtime. A `jv_record_schema` maps UTF-8 names to a runtime
`jv_type`, a valid default, and an optional validator callback. A finalized
`jv_record_type` acts as a factory; instances store only the factory reference
and a persistent map containing every field.

Runtime types cover the scalar value kinds, unconstrained `jv_type_any`, exact
opaque-any values, homogeneous vectors/maps/sets, homogeneous ordered
maps/sets, exact record-definition references, unions, and optional values.
Numeric kinds are never coerced. Collection validation recursively checks their
contents and distinguishes ordered variants from unordered ones. Type
descriptors and record definitions are immutable DAGs in v1, so directly or
mutually recursive record definitions are not supported.

```wax
let schema = jv_record_schema_add(
    jv_record_schema_add(
        jv_record_schema_empty(),
        utf8_from_bytes("x"),
        jv_type_i32(),
        jv_i32(0),
    ),
    utf8_from_bytes("label"),
    jv_type_optional(jv_type_string()),
    jv_null(),
);
let point_type = jv_record_type_create(utf8_from_bytes("Point"), schema);
let point = jv_record_set(
    jv_record_default(point_type),
    utf8_from_bytes("x"),
    jv_i32(7),
);
```

`jv_record_try_set`, strict/lenient construction, merge, reset, clear,
iteration, and `jvt_record` transient batching preserve the definition and
validate changes. Stable `jv_record_*` status constants distinguish unknown or
duplicate fields, type mismatches, field-validator failures, and whole-record
validator failures. The corresponding trapping functions are conveniences for
inputs the caller already knows are valid. A transient freeze is consuming even
when its whole-record validator rejects the result.

Record equality requires definition identity as well as equal values. Names are
descriptive and are not registered globally. Since WebAssembly has no identity
hash, same-name definitions with equal maps can have the same hash while still
being unequal. Validator callbacks take an explicit context and must be pure
and deterministic.

## Verification

`just stdlib-test` generates reproducible state-machine traces with MoonBit
QuickCheck, compiles the combined sources through Wax's public API, and runs
them in Node's WebAssembly GC runtime. MoonBit maps and explicit encounter-order
arrays model persistent updates. A fatal WHATWG `TextDecoder` independently
checks generated UTF-8 byte sequences. Deterministic tests cover malformed
encodings, numeric bit identity, nested values, record schemas and validators,
ordered collection replacement/removal/reinsertion and algebra, structural
sharing, compaction, and transient lifecycle traps. Committed fixtures exercise
the behavior documented by Immutable.js v5 for records, ordered maps, and
ordered sets; typed validation is checked against an independent generated
state-machine model because Immutable.js records are not runtime typed.

`just stdlib-bench` reports median and minimum times for UTF-8 validation/hash,
persistent/transient value construction, and record updates. Timings are
informational rather than pass/fail thresholds.

The validator implements the well-formed byte ranges in
[Unicode Standard Table 3-7](https://www.unicode.org/versions/latest/ch03.pdf).
The general set follows the established map-with-sentinel organization of
[Clojure's PersistentHashSet](https://github.com/clojure/clojure/blob/master/src/jvm/clojure/lang/PersistentHashSet.java),
adapted to the existing Wax HAMT. These references are design oracles only and
are never fetched by builds or tests.

Record factory/default/reset behavior follows the public
[Immutable.js v5 Record contract](https://immutable-js.com/docs/v5/Record/).
Wax exposes strict and lenient constructors separately instead of silently
ignoring unknown fields in every constructor.

Ordered map and set encounter-order behavior follows the public
[Immutable.js v5 OrderedMap](https://immutable-js.com/docs/v5/OrderedMap/) and
[OrderedSet](https://immutable-js.com/docs/v5/OrderedSet/) contracts. The
implementation also follows Immutable.js's hash-index plus persistent-list
layout and its sparse-list compaction threshold; the reference is a design
oracle and is never fetched by builds or tests.
