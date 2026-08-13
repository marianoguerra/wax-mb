// The SIMD intrinsic registry: what a vector op is called, and what it takes.
//
// Ported from wax/src/lib-wasm/simd.ml, the single source of truth shared by
// the lowering, the decompiler and the type checker. Four consumers that must
// agree about ~250 operations, which is why the module derives its tables from
// one naming scheme rather than listing them.
//
// THE SURFACE CONVENTION. A vector op is written as a method intrinsic with the
// lane shape baked into the name -- `a.add_i32x4(b)`, `v.splat_i32x4()`,
// `v.extract_lane_s_i8x16(0)`. The Wax name is the WAT mnemonic `A.B` rewritten
// as `B_A`, so `i32x4.add` becomes `add_i32x4` and `v128.and` becomes
// `and_v128`. Constants and bitselect are free functions; loads and stores are
// methods on a memory object.

///|
/// A lane shape: how the 128 bits are divided, and into what.
pub(all) enum Shape {
  I8x16
  I16x8
  I32x4
  I64x2
  F32x4
  F64x2
} derive(Eq, Hash, Debug)

///|
pub fn Shape::to_str(self : Shape) -> String {
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
pub fn Shape::of_str(s : String) -> Shape? {
  match s {
    "i8x16" => Some(I8x16)
    "i16x8" => Some(I16x8)
    "i32x4" => Some(I32x4)
    "i64x2" => Some(I64x2)
    "f32x4" => Some(F32x4)
    "f64x2" => Some(F64x2)
    _ => None
  }
}

///|
/// How many lanes the shape has. Also the number of literals a constant of that
/// shape takes, and the exclusive bound on a lane index.
pub fn Shape::lane_count(self : Shape) -> Int {
  match self {
    I8x16 => 16
    I16x8 => 8
    I32x4 | F32x4 => 4
    I64x2 | F64x2 => 2
  }
}

///|
/// The operand and result types a vector intrinsic deals in.
///
/// Kept apart from both the Wax and the wasm value-type representations, so
/// each consumer maps it to its own rather than this module picking one.
pub(all) enum Ty {
  TV128
  TI32
  TI64
  TF32
  TF64
} derive(Eq, Hash, Debug)

///|
/// The scalar type of one lane: what `splat` takes, what `extract` gives back,
/// and what `replace` puts in.
///
/// The narrow integer shapes work in i32, because wasm has no narrower scalar.
pub fn Shape::lane_scalar(self : Shape) -> Ty {
  match self {
    I8x16 | I16x8 | I32x4 => TI32
    I64x2 => TI64
    F32x4 => TF32
    F64x2 => TF64
  }
}

///|
/// Is this shape's lane a float?
pub fn Shape::is_float(self : Shape) -> Bool {
  self is (F32x4 | F64x2)
}

///|
pub let int_shapes : Array[Shape] = [I8x16, I16x8, I32x4, I64x2]

///|
pub let float_shapes : Array[Shape] = [F32x4, F64x2]

///|
pub let all_shapes : Array[Shape] = [I8x16, I16x8, I32x4, I64x2, F32x4, F64x2]

// ============================================================
// The free functions
// ============================================================

///|
/// The namespace the free vector intrinsics live in.
pub let free_namespace : String = "v128"

///|
/// The full name of a free intrinsic, from its member part.
pub fn free_full(part : String) -> String {
  free_namespace + "_" + part
}

///|
/// The member part of a full free-intrinsic name, if it is one.
pub fn free_member(full : String) -> String? {
  let prefix = free_namespace + "_"
  if full.has_prefix(prefix) {
    Some(full[prefix.length():].to_owned())
  } else {
    None
  }
}

///|
pub let bitselect_name : String = "v128_bitselect"

///|
/// A constant is named for its shape: `v128_i32x4(1, 2, 3, 4)`.
pub fn const_name(s : Shape) -> String {
  free_full(s.to_str())
}

///|
/// The shape a `v128_<shape>` constant name denotes, if the name is one.
pub fn const_shape_of_name(name : String) -> Shape? {
  match free_member(name) {
    None => None
    Some(m) => Shape::of_str(m)
  }
}

///|
/// How many lane literals a constant of this shape takes.
pub fn const_arity(s : Shape) -> Int {
  s.lane_count()
}

///|
/// Is this the name of a free intrinsic -- a constant, or bitselect?
pub fn is_free_intrinsic(name : String) -> Bool {
  name == bitselect_name || const_shape_of_name(name) is Some(_)
}

///|
/// Every free intrinsic's member name, for completion after `v128_`.
pub let free_member_names : Array[String] = {
  let out = all_shapes.map(s => s.to_str())
  out.push("bitselect")
  out
}
