// The Wax instance of the wasm type family, plus the small types the AST needs.
//
// `wasm_types` holds the Idx-generic spine. The four types below carry the
// annotated-array wrappers, which differ per language form, so the reference
// leaves them to each instance and so do we. In Wax they are arrays of NAMED,
// SPANNED entries, because Wax refers to types by name and a diagnostic must be
// able to point at the individual parameter or field.

///|
/// An identifier with its span.
///
/// This is the `Idx` the Wax AST instantiates the type family at. The reference
/// spells it `(string, location) annotated`; a named struct is the same shape
/// with readable field names.
pub(all) struct Ident {
  name : String
  loc : Location
} derive(Eq, Debug)

///|
/// A function signature.
///
/// Parameters may be anonymous (`fn(i32)`) or named (`fn(x: i32)`), hence the
/// optional name; results never are.
pub(all) struct FuncType {
  params : Array[Annotated[(Ident?, ValType[Ident]), Location]]
  results : Array[ValType[Ident]]
} derive(Eq, Debug)

///|
/// What a defined type actually is.
pub(all) enum CompType {
  Func(FuncType)
  Struct(Array[Annotated[(Ident, FieldType[Ident]), Location]])
  Array(FieldType[Ident])
  /// A continuation type, from the stack-switching proposal.
  Cont(Ident)
} derive(Eq, Debug)

///|
/// One member of a recursion group.
///
/// `descriptor`/`describes` are the custom-descriptors proposal's pairing; both
/// are present because the relation is navigable in each direction.
pub(all) struct SubType {
  typ : CompType
  supertype : Ident?
  /// Whether the type forbids further subtypes.
  final_ : Bool
  descriptor : Ident?
  describes : Ident?
} derive(Eq, Debug)

///|
/// A recursion group: types that may refer to each other.
///
/// A single `type t = ...` is a one-member group, so there is no separate
/// non-recursive form.
pub type RecType = Array[Annotated[(Ident, SubType), Location]]

///|
/// The field name marking a `..` splice at the head of a struct definition,
/// which inherits the supertype's fields.
///
/// `..` is not a valid identifier, so it can never collide with a real field.
/// The typer replaces it with the supertype's fields and the printer renders it
/// back as `..`; its field TYPE is a placeholder and is never inspected.
pub let splice_field_name : String = ".."

///|
pub fn is_splice_field(
  f : Annotated[(Ident, FieldType[Ident]), Location],
) -> Bool {
  f.desc.0.name == splice_field_name
}

///|
/// Build the `..` splice sentinel at the given span.
pub fn splice_field(
  loc : Location,
) -> Annotated[(Ident, FieldType[Ident]), Location] {
  {
    desc: ({ name: splice_field_name, loc }, { mut_: false, typ: Value(I32) }),
    info: loc,
  }
}

///|
/// Unary operators.
pub(all) enum UnOp {
  Neg
  Pos
  Not
} derive(Eq, Debug)

///|
/// Binary operators.
///
/// Signedness is part of the operator rather than inferred, because
/// WebAssembly has genuinely different instructions for signed and unsigned
/// division, remainder, shift and comparison. It is optional on the operators
/// where floats also apply (`/`, `<`, `>`, `<=`, `>=`): `None` means the
/// spelling did not commit, and the typer resolves it from the operand type.
pub(all) enum BinOp {
  Add
  Sub
  Mul
  Div(Signage?)
  Rem(Signage)
  And
  Or
  Xor
  Shl
  Shr(Signage)
  Eq
  Ne
  Lt(Signage?)
  Gt(Signage?)
  Le(Signage?)
  Ge(Signage?)
} derive(Eq, Debug)

///|
/// A block label.
pub type Label = Ident

///|
/// What an `as` cast targets.
pub(all) enum CastType {
  Value(ValType[Ident])
  /// `&fn(...)`, a function reference.
  Func(nullable~ : Bool, sign~ : FuncType)
  /// A numeric conversion that states signedness, e.g. `i32_s`. `strict` marks
  /// the trapping form, which rejects out-of-range values instead of saturating.
  Signed(typ~ : NumType, signage~ : Signage, strict~ : Bool)
} derive(Eq, Debug)

///|
/// The four numeric types, where a construct admits only those.
pub(all) enum NumType {
  I32
  I64
  F32
  F64
} derive(Eq, Debug)

///|
pub fn NumType::to_str(self : NumType) -> String {
  match self {
    I32 => "i32"
    I64 => "i64"
    F32 => "f32"
    F64 => "f64"
  }
}

///|
/// Render a signed numeric cast type, e.g. `i32_s` or `i64_u_strict`.
pub fn format_signed_type(
  typ : NumType,
  signage : Signage,
  strict : Bool,
) -> String {
  let s = match signage {
    Signed => "s"
    Unsigned => "u"
  }
  let suffix = if strict { "_strict" } else { "" }
  "\{typ.to_str()}_\{s}\{suffix}"
}

///|
/// A `try_table` catch clause.
///
/// The `Ref` variants deliver the exception reference itself alongside the
/// payload, so a handler can rethrow.
pub(all) enum Catch {
  Catch(Ident, Label)
  CatchRef(Ident, Label)
  CatchAll(Label)
  CatchAllRef(Label)
} derive(Eq, Debug)

///|
/// A stack-switching handler clause, `e on [tag -> 'label]`.
pub(all) enum OnClause {
  OnLabel(Ident, Label)
  OnSwitch(Ident)
} derive(Eq, Debug)

///|
/// A `match` arm pattern: an optionally-bound reference-type test, or a null
/// test.
pub(all) enum MatchPattern {
  MatchCast(Ident?, RefType[Ident])
  MatchNull
} derive(Eq, Debug)

///|
/// Advisory `metadata.code.*` metadata attached to an instruction.
///
/// Written in Wax as an attribute prefixing the instruction (`#[likely]`,
/// `#[freq = 16]`, `#[targets(f: 0.73)]`). These never affect behaviour: an
/// engine may ignore them, and dropping one changes performance, never
/// semantics.
///
/// A hint carries the span of the attribute it was written as, so a diagnostic
/// about a malformed hint blames the hint rather than the instruction it
/// decorates.
pub(all) struct Hint[T] {
  value : T
  loc : Location
} derive(Eq, Debug)

///|
pub(all) struct Hints {
  /// `Some(true)` = branch likely taken.
  branch : Hint[Bool]?
  /// The raw wire byte of an `instr_freq` hint: an offset base-2 logarithm of
  /// expected executions, so 32 means once. Kept raw so a value a hand-written
  /// binary put outside the proposal's range still round-trips.
  freq : Hint[Int]?
  /// Likely targets of an indirect call, with each one's frequency as a
  /// percentage.
  targets : Hint[Array[(Ident, Int)]]?
} derive(Eq, Debug)

///|
/// An instruction with no hints, which is what everything carries unless an
/// attribute says otherwise.
pub let no_hints : Hints = { branch: None, freq: None, targets: None }

///|
pub fn Hints::is_empty(self : Hints) -> Bool {
  self.branch is None && self.freq is None && self.targets is None
}
