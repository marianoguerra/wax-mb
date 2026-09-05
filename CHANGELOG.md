# Changelog

All notable changes to `marianoguerra/wax`, `marianoguerra/wax-cli`,
`marianoguerra/was` and `marianoguerra/wap`.

`wax` and `wax-cli` are versioned together and released from one repository, so
a release note here covers both unless it says otherwise. `was` and `wap` are
separate packages on their own version lines: each depends on a published `wax`
rather than on this tree, and neither release implies a wax one.

## [was 0.1.0] — 2026-09-05

The first release of `marianoguerra/was`: Wax in
[shrubbery](https://docs.racket-lang.org/shrubbery/) notation. A second reader
for the same language, producing the same AST — not a language above Wax, and
not a subset of it.

### Added

- **The reader** (`marianoguerra/was/read`): types with `open`, supertypes,
  `descriptor`/`describes` and the `..` splice; `rec` groups; functions,
  globals, tags, memories, tables, element and data segments, import groups,
  module features and `cfg` conditionals; and for instructions `let`,
  assignment and its compound forms, `:=`, every binary and unary operator,
  `as`/`is`/`on`, casts including `as i32_u` and `as ?descriptor(d)`, struct and
  array literals in all four array forms, field and element access and
  assignment, calls, labelled arguments, `if`, `do`, `loop`, `while` with a
  step, `match`, `dispatch`, `try`/`catch` and `try on [...]`, the whole `br`
  family, `return`, `become`, `throw`, `throw_ref` and `suspend`.
- **Spans mapped rather than synthesised**, so a Wax type error found after the
  read lands on the `.was` line that caused it.
- **`stdlib-was/`**, translations compiled beside their originals.

### Notation

Five characters were already spoken for, and every difference from Wax follows
from one of them: `:` opens a block, so annotations take `::` and bodies take
indentation; `'…'` is a bracket pair, so labels take `~` and character literals
take `char"A"`; `#` is reserved, so attributes become prefix modifiers; a bare
`|` introduces alternatives, so bitwise or takes `||` and the array forms move
their type outside the brackets; and no operator may contain a letter, so
`<s`/`<u` become `<~`/`<$`. A bare operator stays the one Wax leaves
unannotated, so all three of its forms survive and the notation changes no
meanings.

### Tested by byte equality

Ten corpus programs and the whole of `stdlib/collections/hashing.wax` are
compiled in both notations and their wasm compared byte for byte — which fails
on a wrong signedness, a wrong field order, a wrong label, or an instruction in
the wrong place.

### Known gaps

- No printer: was reads, and does not render a Wax AST back as shrubbery.
- `?:` is gone; `if c | a | b` is the expression form.
- A one-element array literal is told from an index by whether the name is a
  declared type, so a local shadowing a type name reads as the type.

## [wap 0.1.0] — 2026-09-05

The first release of `marianoguerra/wap`: **W**eb**A**ssembly's **P**ascal, an
Oberon-level language on [shrubbery](https://docs.racket-lang.org/shrubbery/)
notation that compiles through the Wax AST. It reads notation with
`marianoguerra/shrubbery` and reports with `marianoguerra/error-report`.

### Added

- **A public, constructible AST** (`marianoguerra/wap/ast`), which does not
  import `marianoguerra/wax`. A project that generates wap — a schema compiler,
  a DSL back end — builds values and hands them to `marianoguerra/wap/lower`;
  emitting source text is not a supported way to use this compiler, it is the
  thing the AST exists to avoid. Spans are error-report spans, so a generator
  that has them gets Wax type errors pointing at its own syntax, and one that
  does not gets fresh synthetic locations rather than colliding bindings.
- **The language**: modules with name mangling, `const`, record types with
  single inheritance, array/function/enumeration types, subranges, sets over
  enumerations, `impl` blocks with static and type-switch dispatch, nullable
  references, tuples as multi-value results and destructuring bindings,
  `let`/`var`, `if` in three shapes, `while` with an optional step, `for` over
  ranges and arrays, `loop`, labelled `break`/`continue`, `match` over types and
  over values, `as`/`is`/`!`, host imports, and `import was` signatures.
- **Signedness in the type.** `i32` and `u32` are both wasm i32 and differ only
  in the instruction an operator selects, so wap has one spelling per operator
  where Wax has `<`/`<s`/`<u`. The same rule decides `&&` and `||`: logical and
  short-circuiting on `bool`, bitwise on integers.
- **`stdlib-wap/`**, ports of two standard library modules, compiled by `wap`'s
  own tests — the showcase and the regression suite are the same files.

### Known gaps

- `import a.b` is recorded but not resolved: compilation is one file at a time.
- A value `match` lowers to a comparison chain, never to `dispatch`.
- `let` immutability, subrange bounds and untyped set literals are not enforced.

## [0.2.1] — 2026-09-03

Tracks the reference implementation from `e57f93b` to `209f43a`. Both changes
are behaviour changes inside feature-gated Wasm proposals, so they reach only
code that opted into one; no public API moved.

### Changed

- **custom-descriptors**: descriptor presence must now match along the declared
  subtype chain. A subtype may no longer add a `descriptor` clause its
  supertype lacks — the proposal's "complete square" rule (upstream
  WebAssembly/custom-descriptors#111), which makes the check symmetric with the
  `describes` one it sits beside. Programs relying on the old asymmetry are now
  rejected with `This type is not a valid subtype of '...'`.
- **compact-import-section**: the shared-type text form is strictly name-only,
  so `(item $id "name")` is gone. A group whose items bind identifiers is
  printed per-item, each spelling the shared type out. This costs nothing in
  the binary: the encoder still picks the shared-type (`0x7E`) encoding
  whenever the item types agree, with the identifiers riding the name section.

### Fixed

- The differential harness collected documentation blocks from `docs/src/*.md`
  plus `skills/wax/reference.md`, which the reference assembles from every doc
  page — so the top-level pages were collected twice and the
  `docs/src/correspondence/` pages only through the skill. Upstream split
  `reference.md` into per-topic files and the single-file lookup silently
  stopped matching. `collect_docs` now reads `docs/src` recursively, which is
  what that lookup stood in for: same 215 distinct modules, without the 172
  duplicate files, and no longer breakable by a re-split.

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
