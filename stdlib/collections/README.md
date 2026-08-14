# Persistent collections for Wax

This directory is a source-distributed collection library for Wax programs. It
contains a persistent hash map implemented as a 32-way HAMT and a persistent
vector implemented as a 32-way trie with a tail. Both support persistent
path-copying operations and single-owner transient batches.

Wax currently has neither source imports nor a package manager, so these are
deliberately standalone `.wax` files with collision-resistant prefixes. Copy
the files you need into your project and concatenate them before the consuming
source, or use:

```sh
tools/vendor-collections.sh path/to/vendor/wax all
```

The sources have no runtime or build dependency on this repository. The helper
copies files only; it does not edit a manifest or make the source checkout a
build input.

## Value representation

Wax does not currently support generic type parameters. `any` is a concrete
WebAssembly GC heap type, not a language-level dynamic value that can contain
numbers and arbitrary references. The collection API therefore stores
`&?eq`: a nullable reference in WebAssembly's `eq` hierarchy.

- Struct and array references in the `eq` hierarchy can be stored directly.
- `null` is a valid value. Lookup returns `(found, value)`, so a missing entry is
  distinguishable from an entry whose value is null.
- Small integers can be boxed as i31 references: `n as &i31`, and read with
  `value! as i32_s` or `i32_u`.
- Full-width numbers, function references, external references, and references
  outside the `eq` hierarchy need an application-defined box struct.

The map accepts `phm_hash` and `phm_equal` callbacks when it is created. This
keeps key policy with the caller and permits application key structs without a
universal cast. A null key is supported separately and never passed to either
callback.

## Hash map API

Persistent operations return a map and leave the input usable:

```wax
phm_empty(hash, equal) -> &phm_map
phm_count(map) -> i32
phm_get(map, key) -> (i32, &?eq)
phm_contains(map, key) -> i32
phm_assoc(map, key, value) -> &phm_map
phm_dissoc(map, key) -> &phm_map
phm_each(map, context, visit)
```

The HAMT uses five hash bits per level. Sparse levels are bitmap-indexed nodes,
levels promote to 32-child array nodes at 17 branches and pack back when they
shrink, and equal full hashes use collision nodes.

Transient operations mutate nodes owned by one edit token:

```wax
phm_as_transient(map) -> &phmt_map
phmt_count/get/contains(...)
phmt_assoc(transient, key, value)
phmt_dissoc(transient, key)
phmt_persistent(transient) -> &phm_map
```

Calling any transient operation after `phmt_persistent` traps. Do not share a
live transient between concurrent owners.

## Vector API

```wax
pv_empty() -> &pv_vector
pv_count(vector) -> i32
pv_get(vector, index) -> (i32, &?eq)
pv_at(vector, index) -> &?eq
pv_push(vector, value) -> &pv_vector
pv_assoc(vector, index, value) -> &pv_vector
pv_peek(vector) -> (i32, &?eq)
pv_pop(vector) -> &pv_vector
pv_each(vector, context, visit)
```

The last 32 elements live in a tail array. Earlier elements live in a 32-way
trie; updates copy only the path from the root and reuse unaffected branches.
`pv_assoc` accepts `index == count` as a push. `pv_at`, out-of-range assoc, and
pop on an empty vector trap; `pv_get` returns `found = 0` instead.

The transient equivalents are `pv_as_transient`, `pvt_count/get/at`,
`pvt_push`, `pvt_assoc`, `pvt_pop`, and `pvt_persistent`. A transient has a
32-slot mutable tail and edit-owned trie paths, then freezes to an exact-sized
persistent tail.

## Verification

`just collections-test` composes the two library files with a test adapter,
uses MoonBit QuickCheck generators to create reproducible state-machine traces,
compiles that generated Wax module through the public Wax compiler API, and
runs it with Node's WebAssembly GC engine. MoonBit's standard `HashMap` and
`Array` are the independent models for map and vector behavior.

The same run checks deterministic boundaries (16/17-way HAMT promotion,
packing, collision buckets, 31/32/33 and 1024/1056/1057 vector boundaries), old
versions after updates, unaffected-branch identity, null keys and values,
transient edit ownership, and required lifecycle traps.

`just collections-bench` reports median and minimum wall times for persistent
and transient workloads. Timings are deliberately not pass/fail thresholds;
identity-based structural-sharing checks are the stable complexity gate, while
the report is useful for tracking performance on a fixed machine.

The algorithms follow the established persistent-vector and HAMT design used
by Clojure's `PersistentVector.java` and `PersistentHashMap.java`. This is an
independent Wax implementation; reference Java source is not copied, vendored,
or used by builds and CI. The files are licensed under this repository's
Apache-2.0 license.
