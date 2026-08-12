// Tests for the SIMD registry.
//
// The registry's whole job is that several tables agree, so what is worth
// testing is the agreements: that a name the completion list offers is a name
// the lookup recognises, and that the natural alignments follow the bytes each
// access actually touches rather than the 16 a vector suggests.

///|
test "shapes" {
  inspect(@simd.Shape::I8x16.lane_count(), content="16")
  inspect(@simd.Shape::I16x8.lane_count(), content="8")
  inspect(@simd.Shape::I32x4.lane_count(), content="4")
  inspect(@simd.Shape::F64x2.lane_count(), content="2")
  // Every shape round-trips through its spelling.
  for s in @simd.all_shapes {
    inspect(@simd.Shape::of_str(s.to_str()) == Some(s), content="true")
  }
  inspect(@simd.Shape::of_str("i8x8") is None, content="true")
  // The narrow integer lanes are handled as i32, because wasm has no narrower
  // scalar type to hand them to.
  inspect(@simd.Shape::I8x16.lane_scalar() == TI32, content="true")
  inspect(@simd.Shape::I16x8.lane_scalar() == TI32, content="true")
  inspect(@simd.Shape::I64x2.lane_scalar() == TI64, content="true")
  inspect(@simd.Shape::F32x4.lane_scalar() == TF32, content="true")
  inspect(@simd.Shape::F64x2.lane_scalar() == TF64, content="true")
  inspect(@simd.Shape::F32x4.is_float(), content="true")
  inspect(@simd.Shape::I32x4.is_float(), content="false")
}

///|
/// Constants and bitselect are free functions rather than methods, because
/// neither has a receiver to be a method on.
test "the free intrinsics" {
  inspect(@simd.const_name(I32x4), content="v128_i32x4")
  inspect(
    @simd.const_shape_of_name("v128_i32x4") == Some(I32x4),
    content="true",
  )
  inspect(@simd.const_shape_of_name("v128_bitselect") is None, content="true")
  inspect(@simd.const_shape_of_name("add_i32x4") is None, content="true")
  inspect(@simd.is_free_intrinsic("v128_bitselect"), content="true")
  inspect(@simd.is_free_intrinsic("v128_f64x2"), content="true")
  inspect(@simd.is_free_intrinsic("add_i32x4"), content="false")
  // A constant takes one literal per lane.
  inspect(@simd.const_arity(I8x16), content="16")
  inspect(@simd.const_arity(F64x2), content="2")
  // Every offered member name is a name the recogniser accepts.
  for m in @simd.free_member_names {
    inspect(@simd.is_free_intrinsic(@simd.free_full(m)), content="true")
  }
}

///|
/// The completion list and the lookup are built from the same lists, and this
/// is what says so.
test "every offered memory method is recognised" {
  inspect(@simd.mem_method_names.length(), content="22")
  for n in @simd.mem_method_names {
    inspect(@simd.is_mem_method(n), content="true")
  }
  inspect(@simd.is_mem_method("loadv256"), content="false")
  inspect(@simd.is_mem_method("load8x8"), content="false")
}

///|
/// A vector load's natural alignment is the bytes it actually reads, which for
/// the widening and zero-filling loads is not 16.
test "natural alignment follows the bytes touched" {
  fn align(n : String) -> Int {
    match @simd.mem_method(n) {
      None => -1
      Some(m) => m.nat_align
    }
  }

  inspect(align("loadv128"), content="16")
  inspect(align("storev128"), content="16")
  // These read eight bytes and widen them to sixteen.
  inspect(align("load8x8_s"), content="8")
  inspect(align("load32x2_u"), content="8")
  // These read one lane and zero the rest.
  inspect(align("load32_zero"), content="4")
  inspect(align("load64_zero"), content="8")
  // A lane access reads exactly its lane.
  inspect(align("load8_lane"), content="1")
  inspect(align("load16_splat"), content="2")
  inspect(align("store32_lane"), content="4")
  inspect(align("load64_lane"), content="8")
}

///|
/// The lane operations take the vector to modify as an operand as well as the
/// address, and only they carry a trailing lane immediate.
test "memory method signatures" {
  fn shape_of(n : String) -> String {
    match @simd.mem_method(n) {
      None => "none"
      Some(m) => {
        let ops = m.operands
          .map(t => {
            match t {
              TV128 => "v128"
              TI32 => "i32"
              TI64 => "i64"
              TF32 => "f32"
              TF64 => "f64"
            }
          })
          .join(" ")
        let res = match m.result {
          None => "()"
          Some(_) => "v128"
        }
        "(\{ops}) -> \{res}\{if m.lane { " +lane" } else { "" }}"
      }
    }
  }

  inspect(shape_of("loadv128"), content="(i32) -> v128")
  inspect(shape_of("load32_splat"), content="(i32) -> v128")
  inspect(shape_of("storev128"), content="(i32 v128) -> ()")
  inspect(shape_of("load8_lane"), content="(i32 v128) -> v128 +lane")
  inspect(shape_of("store8_lane"), content="(i32 v128) -> () +lane")
}

///|
/// The registry builds the instruction the encoder will write, so this is where
/// a name and an opcode are tied together.
test "memory methods build the right instruction" {
  fn built(n : String, lane : Int) -> String {
    match @simd.mem_method(n) {
      None => "none"
      Some(m) => (m.build)(0, 4, 8L, lane) |> @debug.to_string
    }
  }

  inspect(built("loadv128", 0), content="V128Load(0, 4, 8)")
  inspect(built("load8x8_s", 0), content="V128Load8x8S(0, 4, 8)")
  inspect(built("storev128", 0), content="V128Store(0, 4, 8)")
  inspect(built("load16_splat", 0), content="V128Load16Splat(0, 4, 8)")
  inspect(built("load32_lane", 3), content="V128Load32Lane(0, 4, 8, 3)")
  inspect(built("store64_lane", 1), content="V128Store64Lane(0, 4, 8, 1)")
}
