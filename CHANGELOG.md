# Changelog

All notable changes to `marianoguerra/wax`, `marianoguerra/wax-cli`,
`marianoguerra/was` and `marianoguerra/wap`.

`wax` and `wax-cli` are versioned together and released from one repository, so
a release note here covers both unless it says otherwise. `was` and `wap` are
separate packages on their own version lines: each depends on a published `wax`
rather than on this tree, and neither release implies a wax one.

## [wap 0.2.1] — 2026-09-05

### Fixed

- **An integer cannot be converted to a float.** `x as f64_s` was rejected:
  `signed_cast` knew the four integer names and nothing else, so a float target
  fell through to a cast carrying no signedness, which Wax refuses — correctly,
  since `f64.convert_i64_s` and `f64.convert_i64_u` are different instructions.
  `f32_s`, `f32_u`, `f64_s` and `f64_u` now lower like their integer siblings.
  The other direction already worked, because a truncation is named by the
  integer it produces.

  Nothing in `wap/` or `stdlib-wap/` crosses between an integer and a float —
  `data/immutable_value` keeps the four numeric arms apart and never converts —
  which is why a whole standard library went by without reaching it. Found by a
  port of `tgc/rt` from [tutuca](https://github.com/marianoguerra/tutuca), whose
  language has one number: every arithmetic operation answers an `f64`, so the
  crossing is on the first line rather than never.

### Known gaps

Two more, both from the same port, both expressible in Wax and not in wap:

- An imported function cannot be bound to a **named** function type.
  `import_group` builds an inline signature, so `#[import] fn get_field:
  tg_get(...)` — which is how a link checks a rec group's own type rather than
  a structurally identical singleton — has no wap spelling.
- No mutable module-level globals: `Decl` has `Const` and no `Var`. Porting
  anything that uses a global as an out-parameter means rethinking it as a
  tuple return rather than translating it.

## [wap 0.2.0] — 2026-09-05

The whole Wax standard library, ported. Nine modules, and each port was a
question put to the compiler rather than an exercise in retyping — three of
them came back as gaps in wap rather than as mistakes in the port, which is
what most of this release is.

### Changed

- **An import's alias is the name the module declares, not the last segment of
  its path.** `import data.immutable_value` brings in a module that calls
  itself `jv`, and everything after it says `jv.i32`. The code carried a
  comment saying exactly this directly above the line that took the path's last
  segment, and the README said it too; both are now true. **This rebinds names
  in existing programs** whose declared module name and file name differ.
- **Nominal types are grouped by strongly connected component**, by Tarjan, and
  emitted in dependency order — not all into one `rec` group. Wax will not
  coerce a function's name to a function type declared inside a recursion
  group, so a single group made `phm_each(m, state, entry_fn)` an error in any
  module with more than one type, while working in a module with one; that is
  Wax's rule and it stands, but types which do not refer to each other have no
  business sharing a group and provoking it. A record holding a callback that
  takes the record keeps the old behaviour. Both halves have a test.
- **A function type that names no other declared type is emitted on its own**,
  ahead of the group, where a record inside the group can still refer to it.

### Added

- **A record literal can name a qualified type**: `jv.record_field{...}`, which
  is what a module that builds another's values has to write. A type annotation
  already accepted the qualified name, and nothing else gives braces a meaning
  after a field access, so the constructor is no longer the one place the name
  cannot be written.
- **`stdlib-wap/` is complete**: the persistent vector, hash map and hash set
  and their transient halves, `text/utf8`, `collections/hashing`,
  `data/immutable_value`, `data/record`, and the two examples. The embedded
  copies in `wap/stdlib_test.mbt` are generated from those sources rather than
  pasted, and CI regenerates and diffs them — they exist because `moon test`
  also runs on wasm, where a test cannot read a file, so this module carries
  its own evidence. [`stdlib-wap/README.md`](../stdlib-wap/README.md) records
  what each port changed and why.
- **The examples are run, not merely compiled.** Both are built to wasm and
  executed under Node, and return what their `.wax` originals return.

### Known gaps

- An array literal names its type and there is no spelling for a qualified one:
  `hashing.bytes[0 ** n]` reads `hashing` as the array type.
- No labelled block. `break` and `continue` take a label, but Wax's
  `'unit: do { ... br 'unit; }` has to become a multi-arm `if`.
- Unchanged from 0.1.0: a value `match` lowers to a comparison chain rather
  than to `dispatch`, and `let` immutability, subrange bounds and untyped set
  literals are not enforced.

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

*Superseded before release by the entries below; kept as one release note.*

### Added: a module system that resolves

- **`marianoguerra/wap/resolve`**, whose point is the `Loader` trait: one
  method, `load(path) -> String?`, and nothing in the resolver knows that files
  exist. A build tool implements it over a filesystem, an editor over its open
  buffers, a test over `MapLoader`. Imports are walked depth-first, a cycle is
  reported with the whole ring rather than the edge that closed it, and the
  modules come back in dependency order.
- **`pub`**, and cross-module references written out: `geometry.make(3, 4)`. A
  declaration is private to its module unless marked, the importing module must
  have imported the one it names, and both are enforced with a report that says
  which rule was broken.
- **Qualified names throughout the lowering.** Every table is keyed
  `module.name`, and each module carries its own line map, so a Wax type error
  found three modules deep names the right file and line.

### Added: was as an output format

- `marianoguerra/was/print` renders a Wax AST as shrubbery, which is what makes
  `wap -f was` and `wax -f was` real rather than aspirational.

## [wap 0.1.0 — original entry]

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
