# The Wax standard library, in wap

Ports of every module in [`stdlib/`](../stdlib), one wap module per `.wax`
file. They are the showcase and the regression suite at once: `just wap-stdlib`
compiles them from disk through a filesystem loader, `moon test` compiles the
same sources embedded in `wap/stdlib_test.mbt`, and `just wap-stdlib-test` runs
the two examples in Node and checks what they return.

| `.wax` | wap module | imported as |
|---|---|---|
| `collections/hashing.wax` | `collections/hashing.wap` | `hashing` |
| `collections/persistent_hash_map.wax` | `collections/persistent_hash_map.wap` | `persistent_hash_map` |
| `collections/persistent_hash_set.wax` | `collections/persistent_hash_set.wap` | `persistent_hash_set` |
| `collections/persistent_vector.wax` | `collections/persistent_vector.wap` | `persistent_vector` |
| `collections/example.wax` | `collections/example.wap` | — |
| `text/utf8.wax` | `text/utf8.wap` | `utf8` |
| `data/immutable_value.wax` | `data/immutable_value.wap` | `jv` |
| `data/record.wax` | `data/record.wap` | `record` |
| `data/example.wax` | `data/example.wap` | — |

## What the module system replaces

`stdlib/README.md` opens by telling you which files to concatenate, in which
order, and why every name carries a `phm_`/`pv_`/`jv_` prefix: *Wax modules do
not have source namespaces*. That is the whole difference here. A file names its
module, every declaration in it is emitted as `module__name`, and a module names
what it needs.

`data/immutable_value.wap` calls itself `jv` rather than `immutable_value`,
because wap takes a module's declared name as the alias rather than the last
segment of the path it was found at. So `jv_i32` reads `jv.i32` and still emits
`jv__i32`.

Exported wasm names are left alone where the originals had them, because those
are an ABI rather than an identifier: `pv_empty` is still `pv_empty`.

## What changed, and why

Everything below is a difference from the `.wax` original that a reader should
not have to reverse-engineer.

**A type says what the operator used to.** Wax spells signedness on the
operator, so the originals write `>>u`, `<s`, `<=u`. A hash here is `u32`, so
`>>` is the logical shift and `<` the unsigned comparison, and there is nothing
left to spell. `||` is bitwise or on integers and logical or on `bool`, decided
the same way, because shrubbery's `|` introduces alternatives and there is no
second spelling to give them.

**A predicate returns `bool`.** Wax has no `bool`, so the originals return `i32`
and compare it against `0` at every call site; `(i32, &?eq)` lookups become
`(bool, eq?)`.

**`utf8`'s validator lost its labelled block.** Wax has labelled blocks and the
original uses one as a `switch` (`'unit: do { ... br 'unit; }`). wap has
labelled `break` and `continue` but no labelled block, so each of those arms is
an arm of a multi-arm `if` — the same order, the same Table 3-7 bounds.

**Three functions moved.** `record_to_map`, `record_equal` and `record_hash` are
in `data/immutable_value.wap`, not in `data/record.wap` where the `.wax` file
has them. Concatenated into one namespace, `jv_equal` calling `jv_record_equal`
and `jv_record_equal` calling `jv_equal` is fine; as two modules it is a cycle,
which wap refuses. All three are one-liners over types declared on that side.

**The whole-record validator takes an `eq`.** `jv_record_validator` is
`fn(&?eq, &jv_record_value)`; here it is `fn(eq?, eq)` and the implementation
casts. `record_type` holds the validator and `record_value` holds the
definition, so a validator written over `record_value` is inside that cycle,
and Wax will not coerce a function's name to a function type declared inside a
recursion group. The `.wax` file has the same problem and answers it by typing
the field `&func` and downcasting at the call site; wap has no `func`, so the
generality moves into the parameter instead. (The downcast is not an
alternative: it compiles and traps at run time with `illegal cast`, because the
two function types are in different recursion groups and so are not the same
wasm type. `wap/repro_test.mbt` keeps that pinned.)

**`hashing.bytes_new` is new.** An array literal names its type and wap has no
spelling for a qualified one — `hashing.bytes[0 ** n]` reads `hashing` as the
array type — so the constructor lives beside the type, which is where it
belongs anyway.

## Checking it

```sh
just wap-stdlib                              # compile every module
just wap-stdlib collections.hashing --wat    # one, and look at the output
just wap-stdlib-test                         # run the examples in Node
just wap-stdlib-test --against-reference     # ... and against the .wax originals
just wap-stdlib-embed                        # re-embed into wap/stdlib_test.mbt
```

The examples return `8` and `19`. Those are not chosen numbers: they are what
the concatenated `.wax` sources return when compiled with the pinned reference
`wax` binary and run the same way, which is what `--against-reference` checks.
