// The WebAssembly type family, shared between the Wax and binary forms.
//
// Ported from the `Make_types` functor in wax/src/lib-wasm/ast.mli. OCaml
// parameterises it over three things -- the index representation and two array
// wrappers -- and instantiates it once per language form. MoonBit has no
// functors, so the parameterisation becomes a type parameter.
//
// THE SEAM. Only `Idx` is generic here. The reference itself draws exactly this
// line: it has two mappers, `Map_types_spine` covering the idx-carrying types
// (heaptype, reftype, valtype, storagetype, fieldtype) and `Map_types`
// extending to functype/comptype/subtype/rectype, whose array wrappers differ
// per instance and must be supplied by the caller. So the spine lives here,
// generic over Idx, and the four wrapper-carrying types are declared in each
// instance's own package.
//
// Wax instantiates at `Idx = Ident` -- a NAME with a span, because Wax refers to
// types by name. The binary form the code generator will need instantiates at
// `Idx = Int`. Keeping the parameter is what makes that later instance an
// addition rather than a rewrite; see AGENTS.md.

///|
/// A heap type: what a reference can point at.
///
/// The `No*` cases are the bottom types of each hierarchy (`nofunc` is a
/// subtype of every function type and has no values), and `None_` is the bottom
/// of the internal hierarchy. `Type` names a concrete defined type; `Exact`
/// names one and forbids subtypes, which is the `custom-descriptors` proposal's
/// `&!t`.
pub(all) enum HeapType[Idx] {
  Func
  NoFunc
  Exn
  NoExn
  Cont
  NoCont
  Extern
  NoExtern
  Any
  Eq
  I31
  Struct
  Array
  /// Spelled `none`. Named with a trailing underscore in the reference because
  /// `None` collides with the option constructor; kept here for the same reason.
  None_
  Type(Idx)
  Exact(Idx)
} derive(Eq, Debug)

///|
/// The keyword naming a heap type, or None for the two that carry an index.
///
/// The index-carrying cases have no keyword because each printer spells the
/// index its own way -- by name in Wax, by number in the binary form.
pub fn[Idx] HeapType::keyword(self : HeapType[Idx]) -> String? {
  match self {
    Func => Some("func")
    NoFunc => Some("nofunc")
    Exn => Some("exn")
    NoExn => Some("noexn")
    Cont => Some("cont")
    NoCont => Some("nocont")
    Extern => Some("extern")
    NoExtern => Some("noextern")
    Any => Some("any")
    Eq => Some("eq")
    I31 => Some("i31")
    Struct => Some("struct")
    Array => Some("array")
    None_ => Some("none")
    Type(_) => None
    Exact(_) => None
  }
}

///|
/// A reference type: a heap type plus whether null is allowed.
pub(all) struct RefType[Idx] {
  nullable : Bool
  typ : HeapType[Idx]
} derive(Eq, Debug)

///|
/// A value type -- what a local, parameter or stack slot holds.
pub(all) enum ValType[Idx] {
  I32
  I64
  F32
  F64
  V128
  Ref(RefType[Idx])
} derive(Eq, Debug)

///|
/// A packed storage type. These exist only in struct fields and arrays: there
/// is no i8 or i16 on the operand stack, so they are not value types.
pub(all) enum PackedType {
  I8
  I16
} derive(Eq, Debug)

///|
/// What a struct field or array element stores.
pub(all) enum StorageType[Idx] {
  Value(ValType[Idx])
  Packed(PackedType)
} derive(Eq, Debug)

///|
/// A type paired with its mutability. Used for both globals and struct fields,
/// which is why it is generic in the thing being made mutable.
pub(all) struct MutType[T] {
  mut_ : Bool
  typ : T
} derive(Eq, Debug)

///|
/// A struct field or array element type.
pub type FieldType[Idx] = MutType[StorageType[Idx]]

///|
/// A global's type.
pub type GlobalType[Idx] = MutType[ValType[Idx]]

///|
/// The size bounds of a memory or table.
///
/// `page_size_log2` is the base-2 logarithm of a custom page size (the
/// `custom-page-sizes` proposal); None means the default 65536. It is stored as
/// the logarithm rather than the size because that is what the binary format
/// encodes, so round-tripping cannot lose a non-power-of-two spelling.
///
/// `mi`/`ma` are u64 to cover 64-bit memories. MoonBit's UInt64 is used
/// directly where the reference has its own Uint64 module.
pub(all) struct Limits {
  mi : UInt64
  ma : UInt64?
  address_type : AddressType
  page_size_log2 : Int?
  shared : Bool
} derive(Eq, Debug)

///|
/// Whether a memory or table is indexed by i32 or i64 (`memory64`).
pub(all) enum AddressType {
  I32
  I64
} derive(Eq, Debug)

///|
/// A 128-bit vector literal, kept as its shape plus the raw component strings.
///
/// The components stay unparsed for the same reason numeric literals do: the
/// printer has to reproduce what was written, and a v128 can be spelled in six
/// different shapes.
pub(all) struct V128 {
  shape : V128Shape
  components : Array[String]
} derive(Eq, Debug)

///|
pub(all) enum V128Shape {
  I8x16
  I16x8
  I32x4
  I64x2
  F32x4
  F64x2
} derive(Eq, Debug)

///|
pub fn V128Shape::to_str(self : V128Shape) -> String {
  match self {
    I8x16 => "i8x16"
    I16x8 => "i16x8"
    I32x4 => "i32x4"
    I64x2 => "i64x2"
    F32x4 => "f32x4"
    F64x2 => "f64x2"
  }
}

///|
/// Signedness, where WebAssembly needs an operation to state it.
pub(all) enum Signage {
  Signed
  Unsigned
} derive(Eq, Debug)

///|
/// Comparison operators available inside a conditional-compilation condition.
pub(all) enum CmpOp {
  Eq
  Ne
  Lt
  Gt
  Le
  Ge
} derive(Eq, Debug)

///|
/// A conditional-compilation condition, from `#[if(...)]`.
///
/// Evaluated against the `-D` variables, not against program values: it decides
/// which source survives, so it belongs to the type layer rather than the
/// instruction layer.
pub(all) enum Cond {
  /// A variable, written `$name`.
  Var(@basic.Annotated[String, @basic.Location])
  Str(@basic.Annotated[String, @basic.Location])
  Version(Int, Int, Int)
  And(Array[Cond])
  Or(Array[Cond])
  Not(Cond)
  Cmp(CmpOp, Cond, Cond)
} derive(Eq, Debug)
