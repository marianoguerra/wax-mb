// The value-method registry, and what a member access records.
//
// Ported from wax/src/lib-wax/members.ml -- the parts with a consumer in this
// port. What is here is what the CHECKER uses: the descriptor it records at
// each `recv.member` access, the classification that decides whether a receiver
// has value methods at all, and the type a SIMD intrinsic's operand stands for.
//
// What is NOT here is the other half of that file: the completion candidate
// LISTS (`fn(i32) -> i32` renderings of every method a memory, table, array,
// struct or v128 receiver offers). They exist for `recv.<here>` completion in
// an editor, which this port does not have -- the reference's own `.mli` is
// explicit that the typer's method dispatch is match-based and NOT enumerable
// from these tables, so nothing in the checker consults them. They are
// transcription with no consumer and no test, and they cost more than they are
// worth until there is an editor to serve. See task 9 of implementation-plan.md.
//
// The two curated registries below are the exception: they are small, they name
// the methods the typer must accept, and upstream keeps them honest with a test
// that type-checks each one. That test is the reason to have them ported before
// the typer rather than after -- they are the checklist it is written against.

///|
/// What a value method's result type is, relative to its receiver.
pub(all) enum MethodResult {
  /// The receiver's own type.
  Same
  /// The equal-width opposite numeric family -- i32 <-> f32, i64 <-> f64 --
  /// as `from_bits` and `to_bits` reinterpret.
  Reinterpret
} derive(Eq, Debug)

///|
/// One value method: `x.clz()`, `x.rotl(y)`.
pub(all) struct ValueMethod {
  name : String
  /// Takes a second operand, of the receiver's type.
  binary : Bool
  result : MethodResult
} derive(Eq, Debug)

///|
fn meth(
  name : String,
  binary? : Bool = false,
  result? : MethodResult = Same,
) -> ValueMethod {
  { name, binary, result }
}

///|
/// The value methods an integer receiver offers.
pub let integer_methods : Array[ValueMethod] = [
  meth("clz"),
  meth("ctz"),
  meth("popcnt"),
  meth("extend8_s"),
  meth("extend16_s"),
  meth("from_bits", result=Reinterpret),
  meth("rotl", binary=true),
  meth("rotr", binary=true),
]

///|
/// The value methods a float receiver offers.
pub let float_methods : Array[ValueMethod] = [
  meth("abs"),
  meth("ceil"),
  meth("floor"),
  meth("trunc"),
  meth("nearest"),
  meth("sqrt"),
  meth("to_bits", result=Reinterpret),
  meth("min", binary=true),
  meth("max", binary=true),
  meth("copysign", binary=true),
]

///|
/// What a member access's receiver is, as the checker records it.
///
/// A lightweight descriptor rather than the candidate list itself: for a v128
/// or a memory receiver that list is large, and it is only ever wanted for the
/// one access under a cursor.
pub(all) enum MemberReceiver {
  /// A value receiver: its integer, float or v128 methods.
  RNumeric(@infer.InferredType)
  /// A struct, by its fields.
  RStruct(StructFields)
  /// An array, by its element type: `length`, `fill`, `copy`, `init`.
  RArray(FieldType)
  /// A memory, by its address type.
  RMemory(@wasm_types.AddressType)
  /// A table, by its address and element types.
  RTable(@wasm_types.AddressType, @wasm_types.RefType[@ast.Ident])
}

///|
/// A struct or array field's type, as the AST spells it.
type FieldType = @wasm_types.MutType[@wasm_types.StorageType[@ast.Ident]]

///|
/// A struct's fields, named and typed, as a type definition declares them.
type StructFields = Array[
  @basic.Annotated[(@ast.Ident, FieldType), @basic.Location],
]

///|
/// The value type a SIMD intrinsic's operand or result stands for.
pub fn simd_valtype(t : SimdTy) -> @infer.InferredValType {
  match t {
    TV128 =>
      (
        { typ: V128, internal: V128, anon_comptype: None } :
        @infer.InferredValType)
    TI32 => @infer.i32_valtype
    TI64 => @infer.i64_valtype
    TF32 => @infer.f32_valtype
    TF64 => @infer.f64_valtype
  }
}

///|
/// The types a SIMD intrinsic's operands and results take.
///
/// The reference reads this from `Wax_wasm.Simd`, the 856-line registry of
/// every vector op, which is NOT ported: it is an unlisted prerequisite of the
/// type checker (task 12), which dispatches `v.add_i32x4(w)` through it. This
/// enum is the part `simd_valtype` needs, so the checker-facing half of this
/// file does not wait on the other 856 lines.
pub(all) enum SimdTy {
  TV128
  TI32
  TI64
  TF32
  TF64
} derive(Eq, Debug)

///|
/// Does a value receiver of this type have value methods?
///
/// The cheap classification the recorder uses to decide whether to record at
/// all, without building a candidate list. A packed `i8`/`i16` has none -- it
/// must be cast first -- and neither has a non-numeric type.
pub fn numeric_receiver_kind(t : @infer.InferredType) -> MemberReceiver? {
  match t {
    Valtype({ typ: I32 | I64 | F32 | F64 | V128, .. })
    | Int
    | Number
    | LargeInt
    | Float => Some(RNumeric(t))
    _ => None
  }
}
