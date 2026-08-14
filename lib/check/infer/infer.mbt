// The inferred-type lattice.
//
// Ported from wax/src/lib-wax/infer.ml. Two things make it more than a copy of
// the value types:
//
//   * The FLEXIBLE literal types. `1` is not an i32 until something says so --
//     an annotation, an operator, a result type -- and until then it is a
//     `Number` that could still become any of the four numeric types. This is
//     what makes keeping numeric literals as raw strings pay off (a Phase 2
//     commitment made specifically for it): the literal has no width yet, so
//     there is nothing to have chosen wrongly.
//   * The three "no concrete type" cases, which are NOT interchangeable.
//     `Unknown` is genuinely polymorphic and still worth an error when a
//     compile needs the type; `Error` has already been reported and must stay
//     silent; `UnknownRef` is known to be a reference and nothing else.
//
// The lattice's join and its interaction with explicit annotations live in the
// checker, not here: this is the substrate.

///|
/// A fully resolved value type, in both the forms the checker needs.
pub(all) struct InferredValType {
  /// The Wax-side type, naming its referenced types.
  typ : @wasm_types.ValType[@ast.Ident]
  /// The wasm-side type, indexing them. The `wasm_types` package is generic
  /// over the index precisely so both instances exist without duplicating the
  /// spine -- the other Phase 2 commitment this file cashes in.
  internal : @wasm_types.ValType[@type_store.Id]
  /// For a synthesized reference type with no source name -- a string's byte
  /// array, an inline function-type cast target -- the composite type it refers
  /// to. `typ` keeps the synthetic name so name-based lookups still resolve,
  /// but a diagnostic renders this inline (`[mut i8]`) rather than printing a
  /// name that means nothing to the reader.
  anon_comptype : @ast.CompType?
} derive(Eq)

///|
/// What inference knows about a value.
pub(all) enum InferredType {
  /// Genuinely polymorphic: a value taken off the stack of unreachable or
  /// branch-terminated code. NOTHING has been reported for it, so an
  /// instruction that needs its operand's concrete type reports when it meets
  /// one.
  Unknown
  /// The recovery type of a value whose own typing already failed. An error has
  /// been reported, so this propagates silently -- treated like `Unknown` but
  /// raising nothing further.
  Error
  /// A non-null reference of unknown heap type: the Wax counterpart of wasm's
  /// `(ref bot)`. Behaves like `Unknown` everywhere except that subtyping knows
  /// it is a reference -- below every reference type, below no numeric one.
  UnknownRef
  /// A bare `null`, whose heap type is not yet fixed. Context narrows it; with
  /// none it takes the bottom of the relevant hierarchy.
  Null
  // The flexible numeric-literal types below form a small lattice. Each is a
  // literal with no fixed type that a context narrows to one concrete numeric
  // type, and that DEFAULTS to a chosen width when nothing constrains it.
  /// Any numeric literal: i32, i64, f32 or f64, defaulting to i32. The bottom
  /// of the flexible lattice.
  Number
  /// A packed narrow read -- a `load8`, or an `i8` struct/array field -- which
  /// yields an i32 tracked as 8 bits wide, so a following widening cast fuses
  /// into the read. Defaults to i32.
  Int8
  /// The same, 16 bits.
  Int16
  /// Committed to the integer family, by a bitwise or shift operator: i32 or
  /// i64, defaulting to i32. Inference can no longer make it a float -- only an
  /// explicit `as`, which emits a conversion.
  Int
  /// A literal too large for i32: i64, f32 or f64, defaulting to i64. Despite
  /// the name it is float-capable, so it belongs to the `number` family rather
  /// than to `int` -- it is `Number` with i32 excluded by magnitude. It exists
  /// so a decompiled out-of-range constant keeps its width instead of
  /// overflowing.
  LargeInt
  /// A float literal: f32 or f64, defaulting to f64.
  Float
  /// Resolved.
  Valtype(InferredValType)
  /// The transient state of a block result being inferred. A value checked
  /// against it is RECORDED rather than unified, and joined once the body is
  /// typed. The cell never escapes inference, so everything else treats it like
  /// `Unknown`.
  Collecting(Collecting)
}

///|
/// A block result under inference.
pub(all) struct Collecting {
  /// Each value reaching the block's exit, with where it was produced (when
  /// known) so a join failure can point at the offending exits.
  ///
  /// A plain array, where the reference needs `mutable`: appending to an OCaml
  /// list means replacing it.
  collected : Array[(@basic.Location?, Cell[InferredType])]
  /// Snapshots of the natural types of values delivered by `br_if` and the
  /// other pass-through branches. Such a value stays on the stack and is typed
  /// as the block result, so -- unlike an ordinary exit, which need only be a
  /// subtype -- its type must be EXACTLY the result.
  exacts : Array[(@basic.Location?, Cell[InferredType])]
  /// The single result type the block already carries while being inferred: a
  /// wasm-to-Wax annotation under test, or `None` when omitted.
  declared : Cell[InferredType]?
  /// Set when `declared` is relied on in a way the join cannot re-derive, which
  /// forces the annotation to be kept.
  mut needed : Bool
  /// Where each REACHABLE exit that delivered nothing was, anchored at the
  /// closing token it is reported on.
  ///
  /// Recorded rather than reported as it is met, because whether it is an error
  /// depends on the exits still to come: an `if` types one arm before the
  /// other, so an empty THEN arm is only wrong once the ELSE arm delivers a
  /// value, and nothing would revisit it. The inference reports these once the
  /// whole body is typed.
  empty_exits : Array[@basic.Location]
}

///|
/// Is this "no concrete type known"?
///
/// `Unknown`, `Error` and `UnknownRef` differ in what they license -- see the
/// constructors -- but the many places that only need to ask whether a type is
/// known share this.
pub fn is_unknown_or_error(cell : Cell[InferredType]) -> Bool {
  cell.get() is (Unknown | Error | UnknownRef)
}

///|
/// Wrap a resolved value type in a fresh cell.
pub fn valtype_cell(v : InferredValType) -> Cell[InferredType] {
  Cell::make(Valtype(v))
}

///|
/// A resolved numeric type, in both forms.
///
/// A concrete base type is never re-resolved during inference -- only a
/// floating cell is unified into one -- so these are invariant and shared.
pub let i32_valtype : InferredValType = {
  typ: I32,
  internal: I32,
  anon_comptype: None,
}

///|
pub let i64_valtype : InferredValType = {
  typ: I64,
  internal: I64,
  anon_comptype: None,
}

///|
pub let f32_valtype : InferredValType = {
  typ: F32,
  internal: F32,
  anon_comptype: None,
}

///|
pub let f64_valtype : InferredValType = {
  typ: F64,
  internal: F64,
  anon_comptype: None,
}

///|
/// Shared cells for the base types.
///
/// Safe to share for the same reason the valtypes are: their value never
/// changes, so no unification can be observed through one.
pub let i32_cell : Cell[InferredType] = valtype_cell(i32_valtype)

///|
pub let i64_cell : Cell[InferredType] = valtype_cell(i64_valtype)

///|
pub let f32_cell : Cell[InferredType] = valtype_cell(f32_valtype)

///|
pub let f64_cell : Cell[InferredType] = valtype_cell(f64_valtype)
