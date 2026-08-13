# Changelog

All notable changes to `marianoguerra/wax` and `marianoguerra/wax-cli`.

The two modules are versioned together and released from one repository, so a
release note here covers both unless it says otherwise.

## [Unreleased]

### Added

- `marianoguerra/wax/compile` — the embedder's entry point. `Session` and
  `Checked` carry the type store, the feature set and the diagnostic context
  that `check_module` and `lower_module` need, so an AST-first consumer runs
  the same pipeline the CLI does without re-deriving the wiring.
- `marianoguerra/wax/ast/build` — smart constructors for module fields, each
  taking an optional `at~` location so a generator can point diagnostics back
  at its own syntax.
- `marianoguerra/wax` (the root package) — a batteries-included facade over
  parse, format and compile, for consumers that do want the front end.

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

### Removed

- The unused `moonbitlang/async` dependency.
