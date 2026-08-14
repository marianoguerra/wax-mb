# Changelog

All notable changes to `marianoguerra/wax` and `marianoguerra/wax-cli`.

The two modules are versioned together and released from one repository, so a
release note here covers both unless it says otherwise.

## [0.2.0] — 2026-08-14

### Added

- Insertion-ordered `jv_ordered_map` and `jv_ordered_set` variants in the
  vendorable Wax data library, with order-sensitive equality and hashing,
  persistent and transient updates, ordered set algebra, recursive runtime
  type descriptors, and Immutable.js-compatible conformance fixtures.
- Runtime-defined immutable `jv_record` values in the vendorable Wax standard
  library. Record factories carry a UTF-8 name, typed schema, defaults, field
  validators and an optional whole-record validator; persistent and transient
  updates preserve structural sharing while rejecting unknown or invalid
  fields.
- Recursive runtime `jv_type` descriptors for scalar values, vectors,
  string-keyed maps, sets, exact record definitions, unions, nullable values,
  unconstrained values and opaque `any` payloads.
- MoonBit state-machine tests, Immutable.js-compatible conformance fixtures,
  transient lifecycle checks and record-specific benchmarks.

## [0.1.0] — 2026-08-14

The first release. Nothing was published before it, so the entries below are
relative to this repository's own history rather than to a version anyone could
have depended on.

### Added

- `marianoguerra/wax/compile` — the embedder's entry point. `Session` and
  `Checked` carry the type store, the feature set and the diagnostic context
  that `check_module` and `lower_module` need, so an AST-first consumer runs
  the same pipeline the CLI does without re-deriving the wiring.
- `marianoguerra/wax/ast/build` — smart constructors for module fields, each
  taking an optional `at~` location so a generator can point diagnostics back
  at its own syntax.
- `marianoguerra/wax/ast/build`'s `Spans` — distinct, ordered locations for a
  generator that has no source text of its own to map into `at~`.
- `marianoguerra/wax` (the root package) — a batteries-included facade over
  parse, format and compile, for consumers that do want the front end.
- `@compile.CompileError`, named where `Checked::to_bytes`, `Checked::to_wat`,
  `compile_string` and `compile_string_to_wat` used to raise the open `Error`
  type. Three packages sit on that path and each raises its own error — the
  lowering, the binary encoder, the text printer — so a caller could only print
  what it caught. `Lower`, `Encode` and `Wat` say which three, and there is no
  fourth. `Show` still renders each with its own span, so nothing a caller
  prints changes.

### Changed

- The repository is now a `moon.work` workspace of three modules: the library
  `marianoguerra/wax`, the command-line tool `marianoguerra/wax-cli`, and the
  unpublished development harness at the root. The library has **no external
  dependencies**, which is what lets it be embedded without pulling in
  filesystem and process access.
- Packages are grouped by layer: `syntax/*`, `check/*`, `wasm/*`, `emit/*`,
  `fmt` and `internal/*`. Import aliases are unchanged, so the sources read
  exactly as before.
- `internal/spell`, `internal/number` and `internal/cond_explore` are now
  genuinely module-private: MoonBit refuses an `internal/` import from outside
  the module that declares it.
- Two bindings in one function may no longer share a location. A local's slot
  is keyed by the offset its name was written at — which is what lets a
  shadowing `let` take a new slot while the name it shadows is still readable
  in its own initializer — so a tree built entirely at `dummy_loc` collapsed a
  whole function's locals onto one slot and emitted a module that was wrong
  rather than one that failed. The same keying drives the unused-local and
  unused-label lints, so shared spans were switching those off as well. The
  emitter now refuses the second binding, addressing whoever generated the
  tree. Nothing parsed can reach it: two identifiers in one file are two byte
  offsets.

### Removed

- The unused `moonbitlang/async` dependency.
- About 850 lines of `pkg.generated.mbti`: names that were `pub` because `pub`
  was what got typed. A name in a committed `.mbti` is a semver promise, and
  the first release is the last cheap chance to say which ones are not. The
  public surface of `lib/` went from 1117 names to 685, `check` alone from 349
  to 103; `tools/api_audit.py` is what reports the remainder. Nothing outside
  a package's own tests referenced any of them. What the removal then exposed
  was deleted rather than hidden: `Checker::statements`, `uses_string_literal`,
  `hierarchy_conversion`, `parse_f64`, `parse_int32`, `char_literal`,
  `string_literal`, `TypedAnnotation`, and `Indices`' five `imported_*` counts,
  all written and never read.
