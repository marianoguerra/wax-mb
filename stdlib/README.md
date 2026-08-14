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
`any`, and set variants. Constructors are named `jv_null`, `jv_bool`,
`jv_string`, `jv_i32`, `jv_i64`, `jv_f32`, `jv_f64`, and `jv_any`; collection
values begin with `jv_vector_empty`, `jv_map_empty`, and `jv_set_empty`.

Each scalar has a safe `jv_get_*` accessor and a trapping `jv_require_*`
accessor. Typed collection APIs wrap the persistent vector, map, and set so
their elements remain `&jv_value`. Transient builders use the `jvt_*` prefix
and trap if reused after `*_persistent`.

`jv_equal` and `jv_hash` are structural. Numeric variants remain distinct;
f32/f64 compare exact bit patterns, including NaNs and signed zero. Map and set
hashing is order-independent. Opaque `any` values compare by GC reference
identity when they are in the equality hierarchy. WebAssembly exposes no
identity hash, so every `any` receives the same kind-specific hash; correctness
is preserved, but a set containing many opaque values will have collisions.

Values built through the public API are immutable and acyclic. An opaque
`any` payload may refer to mutable application state; the value retains the
reference but cannot make the referenced object immutable.

## Verification

`just stdlib-test` generates reproducible state-machine traces with MoonBit
QuickCheck, compiles the combined sources through Wax's public API, and runs
them in Node's WebAssembly GC runtime. MoonBit maps/arrays/sets model persistent
updates. A fatal WHATWG `TextDecoder` independently checks generated UTF-8 byte
sequences. Deterministic tests cover malformed encodings, numeric bit identity,
nested values, insertion-order independence, structural sharing, and transient
lifecycle traps.

`just stdlib-bench` reports median and minimum times for UTF-8 validation/hash
and persistent/transient value construction. Timings are informational rather
than pass/fail thresholds.

The validator implements the well-formed byte ranges in
[Unicode Standard Table 3-7](https://www.unicode.org/versions/latest/ch03.pdf).
The general set follows the established map-with-sentinel organization of
[Clojure's PersistentHashSet](https://github.com/clojure/clojure/blob/master/src/jvm/clojure/lang/PersistentHashSet.java),
adapted to the existing Wax HAMT. These references are design oracles only and
are never fetched by builds or tests.
