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

///|
/// The registry holds every vector operation that is not a constant or a memory
/// access, and the count is worth pinning: 233 is what the classification
/// covered, and a change to it means an operation was added or lost.
test "the registry is complete" {
  inspect(@simd.size(), content="233")
  // A name from each family resolves.
  for
    n in [
      "add_i32x4", "abs_f64x2", "shl_i8x16", "bitmask_i16x8", "any_true_v128", "all_true_i64x2",
      "splat_f32x4", "extract_lane_s_i8x16", "replace_lane_i32x4", "shuffle_i8x16",
      "v128_bitselect", "and_v128", "relaxed_madd_f64x2", "extmul_low_i8x16_s_i16x8",
      "q15mulr_sat_s_i16x8",
    ] {
    inspect(@simd.classify(n) is Some(_), content="true")
  }
  // A name that is not one does not.
  inspect(@simd.classify("add_i32x8") is None, content="true")
  inspect(@simd.classify("i32x4.add") is None, content="true")
  inspect(@simd.classify("loadv128") is None, content="true")
}

///|
/// The signature follows the family, so these are the families.
test "signatures follow the family" {
  fn shape_of(n : String) -> String {
    match @simd.classify(n) {
      None => "none"
      Some(i) => {
        fn ty(t : @simd.Ty) -> String {
          match t {
            TV128 => "v128"
            TI32 => "i32"
            TI64 => "i64"
            TF32 => "f32"
            TF64 => "f64"
          }
        }

        let res = match i.result {
          None => "()"
          Some(t) => ty(t)
        }
        let imm = match i.imm {
          NoImm => ""
          Lane(s) => " lane<\{s.to_str()}>"
          Shuffle => " shuffle"
        }
        "(\{i.operands.map(ty).join(" ")}) -> \{res}\{imm}"
      }
    }
  }

  inspect(shape_of("add_i32x4"), content="(v128 v128) -> v128")
  inspect(shape_of("abs_f64x2"), content="(v128) -> v128")
  inspect(shape_of("relaxed_madd_f32x4"), content="(v128 v128 v128) -> v128")
  // A shift takes a scalar count, not a vector.
  inspect(shape_of("shl_i8x16"), content="(v128 i32) -> v128")
  // Tests and bitmasks leave the vector domain.
  inspect(shape_of("any_true_v128"), content="(v128) -> i32")
  inspect(shape_of("all_true_i64x2"), content="(v128) -> i32")
  inspect(shape_of("bitmask_i32x4"), content="(v128) -> i32")
  // Splat and extract deal in the lane's own scalar type, and the narrow
  // integer shapes have none narrower than i32.
  inspect(shape_of("splat_i8x16"), content="(i32) -> v128")
  inspect(shape_of("splat_i64x2"), content="(i64) -> v128")
  inspect(shape_of("splat_f64x2"), content="(f64) -> v128")
  inspect(shape_of("extract_lane_s_i8x16"), content="(v128) -> i32 lane<i8x16>")
  inspect(shape_of("extract_lane_f64x2"), content="(v128) -> f64 lane<f64x2>")
  inspect(
    shape_of("replace_lane_i64x2"),
    content="(v128 i64) -> v128 lane<i64x2>",
  )
  inspect(shape_of("shuffle_i8x16"), content="(v128 v128) -> v128 shuffle")
}

///|
/// Only bitselect and the constants are free functions; everything else takes a
/// receiver.
test "free functions and methods" {
  inspect(@simd.classify("v128_bitselect").unwrap().free, content="true")
  inspect(@simd.classify("add_i32x4").unwrap().free, content="false")
  // Every method whose receiver is a vector -- which is nearly all of them,
  // since splat takes a scalar receiver instead.
  let on_v128 = @simd.method_names(TV128)
  let on_i32 = @simd.method_names(TI32)
  inspect(on_v128.contains("add_i32x4"), content="true")
  inspect(on_v128.contains("v128_bitselect"), content="false")
  // splat_i8x16 is a method on an i32, because that is what it splats.
  inspect(on_i32.contains("splat_i8x16"), content="true")
  inspect(on_v128.contains("splat_i8x16"), content="false")
  // Sorted, so completion output is stable.
  let sorted = on_v128.copy()
  sorted.sort()
  inspect(on_v128 == sorted, content="true")
}

///|
/// The registry builds the instruction the encoder writes, so a Wax name and an
/// opcode are tied together here.
test "the registry builds the right instruction" {
  fn built(n : String, lanes : Array[Int]) -> String {
    match @simd.classify(n) {
      None => "none"
      Some(i) => (i.build)(lanes) |> @debug.to_string
    }
  }

  inspect(built("add_i32x4", []), content="I32x4Add")
  inspect(built("and_v128", []), content="V128And")
  inspect(built("andnot_v128", []), content="V128AndNot")
  inspect(built("extract_lane_u_i8x16", [3]), content="I8x16ExtractLaneU(3)")
  inspect(built("replace_lane_f64x2", [1]), content="F64x2ReplaceLane(1)")
  inspect(
    built("shuffle_i8x16", [
      0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
    ]),
    content="I8x16Shuffle(<FixedArray: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]>)",
  )
  // The two q15mulr operations are spelled differently, and only one of them
  // splits the word -- which the compiler caught when the derivation assumed
  // otherwise.
  inspect(built("q15mulr_sat_s_i16x8", []), content="I16x8Q15MulrSatS")
  inspect(built("relaxed_q15mulr_s_i16x8", []), content="I16x8RelaxedQ15mulrS")
}
