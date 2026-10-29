# Changelog

All notable changes to `marianoguerra/wax`, `marianoguerra/wax-cli`,
`marianoguerra/was` and `marianoguerra/wap`.

`wax` and `wax-cli` are versioned together and released from one repository, so
a release note here covers both unless it says otherwise. `was` and `wap` are
separate packages on their own version lines: each depends on a published `wax`
rather than on this tree, and neither release implies a wax one.

## [0.4.2] — 2026-10-29

Covers `wax` and `wax-cli`. One checker fix; no API changes.

### Fixed

- **A float-only operator on two integers passed the checker.** `a > b`,
  `a <= b` or `a / b` on two i32s (or two i64s) -- the unsuffixed comparisons
  and division are the float ones -- was accepted, and the module then failed
  to lower with "operator at this type not lowered yet" and no diagnostic.
  The reverse, `&`, `/s` or `<s` on two floats, slipped through the same way.
  Both are now reported at the operator, as the reference does: "This operator
  cannot be applied to operands of types 'i32' and 'i32'." Use `>s`, `/s` and
  the other suffixed forms on integers.

## [wap 0.4.2] — 2026-10-29

### Changed

- Depends on `marianoguerra/wax@0.4.2`, for its fix. No API or behaviour
  change of its own.

## [was 0.2.2] — 2026-10-29

### Changed

- Depends on `marianoguerra/wax@0.4.2`, for the same reason and with the same
  scope as `wap 0.4.2`.

## [0.4.1] — 2026-10-28

Covers `wax` and `wax-cli`. Bug fixes, and syntax errors worded like the
reference's in many more places. The one API addition is a method.

### Added

- `ErrorState::reduced_stack` in `syntax/parser`: the stack the reference
  reports a syntax error from, after the reductions it makes at the error.

### Fixed

- **The checker aborted on a function whose result type does not resolve.**
  A result naming an unbound type (`-> &nosuch`), or a value-type alias
  behind `&` (`type s = extern; fn g(x: &extern) -> &s { return x; }`), is
  reported at the type, and the body is still checked; returning anything
  then panicked with "an unknown type cannot be an expected type". It is now
  accepted against the already-reported type, as an already-reported value
  is. The reference has the same assertion (its command line stops at the
  first error and never reaches it; its language server does).
- **Syntax errors fell back to the bare "Expecting ..." list where the
  reference says what it assumed complete.** The reference's parser makes
  the reductions its grammar declares `%on_error_reduce` before it reports,
  and names the state they lead to; ours failed earlier, in a state its
  message table had no entry for. Those reductions are now replayed, for the
  message and for the label on the construct it names, so `x y;`,
  `return_call g();`, `#[likely] if ...`, `[1, 2, 3 }`, an unclosed `{` and
  an `if` condition followed by a stray token read as the reference's do.
  Across the corpus, messages that differ from the reference's go from 52 to
  20.
- A malformed string or comment is reported as a zero-width point where no
  lexer rule applied -- the backslash of a bad escape, the control character,
  the end of input -- like the reference, rather than spanning from the
  opening quote or `/*`, onto the next line when the character was a newline.

## [wap 0.4.1] — 2026-10-28

### Changed

- Depends on `marianoguerra/wax@0.4.1`, for its fixes. No API or behaviour
  change of its own.

## [was 0.2.1] — 2026-10-28

### Changed

- Depends on `marianoguerra/wax@0.4.1`, for the same reason and with the same
  scope as `wap 0.4.1`.

## [0.4.0] — 2026-10-23

Covers `wax` and `wax-cli`. Tracks the reference implementation from `209f43a`
to `004d19e`. A minor release because the API grew in ways an exhaustive
`match` or a record literal notices (see Changed).

### Added

- **Value-type aliases**: `type word = i64;` names a value type, which is then
  usable wherever a value type is expected. Defined differently in the
  branches of an `#[if]`, an alias stands for a different type in each
  configuration. A definition that is cyclic or names no type is reported once,
  at the definition; an alias used where a heap type is expected (`&word`, a
  supertype) is reported at the use; an alias nothing reachable uses is
  reported as `unused-field`. Compiling to the binary format expands each alias
  into the type it stands for.
- **Type ascription** `(e : t)`: a static assertion that `e`'s type is a subtype
  of `t`, with result type `t`. It compiles to nothing; an ascription that does
  not hold is a compile-time error, and an ascribed bare hole takes its type
  from the ascription rather than consuming a pending value.
- **`--try-table`** rewrites the legacy exception-handling instructions (`try`
  with `catch`/`catch_all`) into the standard `try_table` and a ladder of
  blocks, for engines and tools that only accept the current proposal. On a
  Wax-to-Wax conversion each `try_legacy` becomes a structured `try`. Library:
  `Checked::to_bytes`/`to_wat`/`to_module` take `try_table`, and
  `Checked::rewrite_legacy_try` is the Wax-level rewrite.
- **`label_names`** on `compile_string`, `Checked::to_bytes` and
  `@wasm_bin.encode`: `false` leaves the label names out of the `name` section,
  which Binaryen's `wasm-opt` does not know and warns about.
- **`dead-code`** also reports a `#[if]` branch no configuration can select.
- A condition variable may be a keyword: `#[if(loop)]`.
- **`wax-cli`**: `-v`/`--validate` checks a conversion with the lints on (unused
  locals among them) and checks a same-format conversion that otherwise only
  re-prints; with no input file the input is read from stdin, reported as `-`;
  and with no `-f`, the output format is taken from the `-o` file's extension.
- `Diagnostic` `Context::replay`, `TypeContext::unalias` and the alias table on
  the checker's `TypeContext`.
- `Session::check(suggest=true)` makes the suggestions; `@message.lazy_type`
  renders a type when the message is shown; `check_subtypes` takes
  `expected_at`.

### Changed

- A type may no longer be named after a packed storage type or a conversion
  target (`i8`, `i16`, `i32_s`, …), as it already could not be named after a
  value type.
- A syntax error that expects one of two things no longer puts a comma before
  "or": "expecting ';' or '}'". The parser messages are regenerated from the
  pinned reference's.
- custom-descriptors: a type and its descriptor must agree on finality.
- `Checked::to_bytes`/`to_wat`/`to_module`, `lower_module`, `encode` and
  `compile_string` gained optional arguments; existing calls are unaffected.
  `ValType` gained `Alias`, `CastType` gained `Ascribed` and `ModuleField`
  gained `TypeAlias`, so an exhaustive `match` on any of them needs an arm.
- The lowered module carries more of the source for the text form, so code
  that builds these records needs the new fields: `@wasm_bin.FunctionCode`
  gained `local_locs`, `clause_locs`, `name_loc` and `param_locs`; `TextView`
  gained `field_spans`, `export_locs` and `type_name_locs`; `CondGroup` gained
  the condition as a `tree`. `AliasSite` gained `SiteLocal` and `SiteBlock`,
  and `Instruction` the text-only wrappers `AliasedResult` and `Unfolded`,
  which the encoder unwraps. In the checker, `InferredValType` gained
  `type_alias`, and `TypeContext::written` keeps every declaration of a name
  (`TypeContext::written_form` reads the right one).

### Fixed

- **A struct field took second place to a built-in method of the same name.**
  `h.copy(1, 2, 3, 4)` on a struct with a `copy` field is a call through the
  field, at any argument count; the checker and the lowering now both decide by
  the receiver's type, which a field access receiver is resolved through too.
- **A packed aggregate read bound without a signedness was accepted.**
  `let x = arr[i]` on an `i8`/`i16` array, or `_ = r.f` on such a field, has no
  lowering, and is now reported.
- **The holes of a binary operator took their values in reverse.** `x; y;
  _ + _ as i32` paired the first hole with `y`. A statement's pending values
  are now popped together and each hole takes the slot its position in
  emission order gives it, as the reference does, whatever order the operands
  are typed in.
- A legacy `try` taking block parameters in expression position is reported,
  as a block, loop or `if` there is.
- "Expected function type" is reported at the call's callee, not at the type
  reference its declared type points at.
- A source-shape lint (a discarded effect-free value) in a branch of a
  conditional is reported, as it is in every configuration; and code after a
  conditional that diverges in some configurations only is no longer reported
  dead in all of them.
- An element segment of non-null `(ref func)` uses the compact function-index
  encoding, and a nullable `funcref` one no longer does.
- The binary and text output now match the reference's on every module of the
  differential corpus (oracle 2: 18 failures to 0). The orders that were left
  different because they come from the reference's hash tables -- the
  functions its synthesized `elem declare` lists, and the synthesized types
  (`<func:f>`, `<fn:...>`, `<string>`) it adds to the type section -- are
  reproduced by simulating OCaml's `Hashtbl` over its string hash. The other
  differences fixed along the way: a type only a tag's signature uses comes
  after the block types the code interns; an inline signature reuses only a
  standalone final function type, not one in a rec group; a local inferred
  from a value of a synthesized type declares it by name; an inline function
  type cast is named by its signature, `<fn:i;->i;>`, so identical casts share
  one; `(t[i] as &?fn(..))()` is a `call_indirect` with an inline signature; a
  legacy `try` and its handlers are one label; and a synthesized function type
  keeps its parameter names in the text output.
- The text output keeps value-type aliases: `(@type $n v)` where one is
  defined, and `(@type $n)` where a signature, a struct or array field or a
  global was written with one.
- A conversion to wasm or WAT stops at the first error, as the reference does;
  `check` still reports them all.
- Converting a module with an unresolved conditional to wasm reports it as a
  located diagnostic with a hint, and a field access whose position differs
  between configurations, a cast to a conditional alias, or a literal that takes
  a conditional alias's type is rejected when converting, as it has no single
  WebAssembly form.
- **A module with unresolved conditionals is written as WAT as the reference
  writes it** -- 160 of 160 such corpus modules, up from 129. A function body
  holding `#[if]` groups is typed once per configuration it needs and each
  branch is taken from the typing that selected it, so a parameter declared
  with a conditional alias, or a trailing literal, has its branch's type; a name
  two branches declare -- a type, a tag, an imported function's signature --
  means the declaration its own branch can see; a type of one shape declared
  in several branches is reused only where it is visible; and a value inferred
  from one of a conditional alias's type (a `let`, a block result, a `?:`, a
  global) is declared with the alias.
- **Comments in the text output** stay where the reference puts them: after a
  local's name, a struct field, a function's name, a parameter, an explicit
  export name or a type's name; in an `if`'s `then`/`else`; inside an empty
  body in a conditional; and before the initializer of a `let` with several
  names, whose stores are numbered after the initializer's own locals.
- The text output names the labels of an `if` whose condition holds a block in
  the order the binary numbers them, breaks a long `(@if ...)` condition across
  lines, and writes the blocks and branches `--try-table` inserts unfolded
  (`block ... end`, `br 1`), as the reference does for what it adds.
- A diagnostic about a statement's holes is reported where the reference makes
  it, among the diagnostics of the operands around the hole; an unbound label
  on `br_if`/`br_on_null` is reported; an attribute guard (`#[export, if(c)]`)
  explores the configurations like an `#[if]`, and an attribute it guards is
  checked in every configuration; and the values reaching a checked block's
  exit are joined, so ones with no common supertype are reported.
- In `{ descriptor(d) | ... }` the field values run before the descriptor, so a
  local the descriptor reads may be initialized by a field and not the other
  way round -- as for a call's callee and its arguments.
- `-x` of a literal is folded into one constant only when the negation is
  representable; `-18446744073709551615` as an `i64` is `0 - x`.
- **The `suggestion` group is implemented**: `wax check` offers a redundant type
  annotation (a `let`, each binding of a tuple `let`, a global, a block's or an
  `if`'s result type, a construction's type name), a `x = x op e` that has the
  compound form, and a field written `x: x`, each with a machine-applicable
  edit, shown where `-W` enables them. A `let` annotation is redundant when what
  the initializer would re-infer to on its own already equals it -- or, for a
  binding nothing assigns, is a subtype of it.
- **`redundant-operation` on arithmetic**: `x + 0`, `x * 1`, `x & x`, `x * 0`,
  `x ^ x`, `x - x` and their kin are reported for integers (never for floats),
  as is `-e` of a non-literal zero.
- A type in a diagnostic is rendered when the diagnostic is shown, so a literal
  still being inferred when it was reported reads as the type it settled to
  ('i32' rather than 'number').
- A hole in a global initializer that recovery dropped is still reported, at
  the initializer; an unbound array type name is reported once; a `br_table`
  listing one label several times checks and reports it once, pointing at the
  label; and a caret under a wide character is as wide as the character.
- **`wax-cli`**: an option given a value it does not accept is reported as the
  reference reports it, the usage line then `wax: option '...': ...`.
- **`-D NAME[=VALUE]`** resolves conditional compilation before checking: an
  `#[if]` the defines decide is replaced by its surviving branch (whose
  comments go with it), one they partly decide is kept with its condition
  simplified, and attribute guards are resolved the same way. A bare name or
  `true`/`false` sets a boolean, `A.B.C` a version, anything else a string.
  Library: `parse_define`, `specialize_defines` and `type Define` on the root
  and `compile` packages, and `@trivia.Context::drop_in_ranges`.
- `become` on a stack-switching method (`become c.resume()`) is rejected, as it
  already was on `k::new`.
- All 103 in-scope cram tests pass, none excused.

### Performance

- Recording a reference is constant time: a module where many functions use
  the same type or helper no longer pays a scan per reference.

## [wap 0.4.0] — 2026-10-23

### Changed

- Depends on `marianoguerra/wax@0.4.0`. No behaviour change of its own; a minor
  release because its API names `wax` types, whose definitions grew.

## [was 0.2.0] — 2026-10-23

### Added

- Prints the `wax` 0.4.0 forms a `was` tree can now hold: value-type aliases,
  `type n = v;` and their uses, and the parenthesized ascription `(e : t)`.

### Changed

- Depends on `marianoguerra/wax@0.4.0`, whose API grew; a minor release for the
  same reason.

## [0.3.1] — 2026-10-19

Covers `wax` and `wax-cli`. A toolchain update and nothing else: no language,
API or behaviour change.

### Changed

- Builds clean under moonc v0.10.16 (moon 0.1.20261016). The regenerated
  `.mbti` files record that toolchain's spelling of the same API; warning 79
  stays off for the reason `lib/moon.mod` gives.
- `wax-cli` depends on `moonbitlang/x@0.5.5`.

## [wap 0.3.2] — 2026-10-19

### Changed

- Depends on `marianoguerra/wax@0.3.1`, `marianoguerra/shrubbery@0.1.2` and
  `marianoguerra/error-report@0.1.1`, so a `wap` build compiles on moonc
  v0.10.16. No API or behaviour change of its own.

## [was 0.1.3] — 2026-10-19

### Changed

- Depends on `marianoguerra/wax@0.3.1`, `marianoguerra/shrubbery@0.1.2` and
  `marianoguerra/error-report@0.1.1`, for the same reason and with the same
  scope as `wap 0.3.2`.

## [0.3.0] — 2026-10-14

Covers `wax` and `wax-cli`. Five fixes in the front end and the checker, a
toolchain update, and the minor slot rather than the patch one because four
names left the public API on the way.

### Fixed

- **A `br_table` of 16000 labels cost a gigabyte.** `case_labels` is
  right-recursive — the `else` is the base case — so the parser action copied
  the whole tail on every reduction: quadratic in the label count. The spec
  suite's `br_table.0` has a table that size, and reprinting it allocated 130M
  idents, 1075 MB, where the reference does the same file in 20. It is 24.9 MB
  and 0.11s now. Only the semantic actions changed, so the generated automaton
  is byte-identical and every recorded parser state still means what it meant.

- **A statement's holes were counted one at a time.** `_ - _` on an empty stack
  said it expected one value where it expects two, and with a value on the
  stack the caret landed on whichever hole noticed rather than on the
  statement's first. A statement's holes are now one run: counted together
  before it is typed, reported once, anchored where the reference anchors it.

- **A negated hole swallowed its own leftover.** The poisoned-result rule
  belongs to a binary operator, and had been copied onto the unary one — so
  `- _` produced an `Error` value, which poisons the stack on push, which hid
  the "This value remains on the stack" that follows the underflow. A unary
  operator answers a failed operand with a real recovery type, and the value it
  leaves is a real value.

- **The two hole reports were ordered by phase, not by position.** `10 - _`
  reports the ordering fault first and `1; _ + (2 * _)` reports the underflow
  first; the underflow now rides on the same emission-order walk as the
  ordering check, so both come out where they belong.

- **A leftover with no locatable value pointed one column too far.** The caret
  sits on the scope's closing bracket, not on the empty span after it.

### Removed

Three items left `marianoguerra/wax`'s public API with the hole-run rewrite.
Nothing in the language changed; a consumer that named one of them stops
compiling, which is what the minor slot is for.

- `@check.report_missing_hole` — replaced by `@check.report_hole_underflow`,
  which takes the statement's underflow rather than a placeholder cell.
- `@check.Operands.missing_holes` — the placeholder registry. The report is
  routed by position now, so nothing read it.
- `@infer.same_cell` — the identity test that registry existed for.
- `@wasm_types.V128`, the v128 literal record, is now `@wasm_types.V128Literal`.
  moonc 0.10.15 reserves `V128` as a type name, so no published wax compiles on
  it. The `ValType::V128` case keeps its name.

### Changed

- Builds clean under moonc 0.10.15: `Ref(x)` and `Json(value)` replace the
  deprecated `@ref.new` and `.to_json()`, and `moon fmt` now spells `Int` as
  `Int32`.
- The parser is generated with `moonbitlang/yacc@0.7.25`, whose `--table`
  engine writes `priv suberror E { E(T) }` itself, so the `sed` rewrite 0.2.2
  added is gone.

## [wap 0.3.1] — 2026-10-14

### Changed

- Depends on `marianoguerra/wax@0.3.0`. No API or behaviour change of its own;
  released so that a `wap` build resolves the wax whose checker reports a
  stack underflow correctly, and that compiles on moonc 0.10.15.

## [was 0.1.2] — 2026-10-14

### Changed

- Depends on `marianoguerra/wax@0.3.0`, for the same reason and with the same
  scope as `wap 0.3.1`.

## [wap 0.3.0] — 2026-09-09

### Added

- **`Node::TailCall(Node, Array[Node])`** — a proper tail call an AST-first
  front end can ask for by name. The lowering treats it as a terminator and
  emits `return_call`, so a function that recurses per element runs in constant
  stack. There is no surface syntax for it: wap's own parser never produces one,
  and a module that does not build its AST directly cannot tell the difference.

  This is why the minor rather than the patch slot. `Node` is `pub(all)`, so a
  consumer matching it exhaustively stops compiling on the new variant even
  though nothing it already wrote changed meaning.

### Changed

- Depends on `marianoguerra/wax@0.2.2` and `marianoguerra/shrubbery@0.1.1`.

## [was 0.1.1] — 2026-09-09

### Changed

- Depends on `marianoguerra/wax@0.2.2` and `marianoguerra/shrubbery@0.1.1`. No
  API or behaviour change; released so that a `was` build resolves a `wax` that
  compiles on moonc 0.10.12.

## [0.2.2] — 2026-09-09

Covers `wax` and `wax-cli`. A toolchain release: no API change, no behaviour
change, and every oracle reports what it reported at 0.2.1.

### Fixed

- **0.2.1 does not compile on moonc 0.10.12.** That compiler stopped parsing
  `priv suberror E T`, and MoonYacc's `--table` engine emits it — so the
  `syntax/parser/parser.mbt` that ships inside the package declared 93 constant
  constructors and then rejected all 1667 uses of one. The declarations are now
  generated in the brace form the direct-style engine already used for the same
  grammar. Anyone on the current toolchain needs this release to build `wax` at
  all.

### Changed

- `wax-cli` depends on `moonbitlang/x@0.5.1`; the parser is generated with
  `moonbitlang/yacc@0.7.19` through `moonx`, which replaces `moon runwasm`
  after 2026-09-14.
- Two warning suppressions are gone from the parser package rather than carried:
  the rewrite above retires `-27`, and 0.7.19 emitting `guard!` retires `-87`.
  Both had applied to the hand-written files too, and `-87` was hiding a real
  non-exhaustive `guard` in `recover.mbt` — now `guard!`, where the panic is the
  intent.

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

- **No function can be given a named function type** — neither a definition nor
  an import. Both `func_field` and `import_group` build an inline signature and
  leave the AST's `typ` slot `None`, and Wax then mints a fresh singleton type
  for the function, which will not coerce to a named one declared inside a
  `rec` group. So a function cannot be stored in a struct field whose type is a
  named function type in its own recursion group — any vtable or callback
  table. Wax spells the fix `fn c_get: tg_get(...)`; wap has no syntax for it.
  An embedder can set `typ` on the lowered field itself, which Wax then checks
  against the inline signature rather than silently accepting.
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
