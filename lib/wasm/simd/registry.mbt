// The vector operation registry: every arithmetic intrinsic, by name.
//
// THE NAMES ARE DERIVED, NOT LISTED. A Wax intrinsic name is the WAT mnemonic
// `A.B` rewritten as `B_A` -- `i32x4.add` is `add_i32x4`, `v128.and` is
// `and_v128` -- which is what the reference's per-family naming functions
// amount to, applied to its enumeration of valid operations. Deriving the table
// the same way is what stops the two directions disagreeing.
//
// The signature comes from the operation's family, and the families partition
// the whole set: 127 binary, 54 unary, 12 shifts, 10 ternary, and the handful
// that take an immediate. That partition is checked rather than assumed -- the
// generator that produced this refuses to emit anything it cannot classify, and
// the constructor names below are checked by the compiler, so a derivation that
// went wrong does not build.

///|
/// What constant immediates an intrinsic takes after its operands.
pub(all) enum Imm {
  NoImm
  /// One lane index, bounded by the shape's lane count.
  Lane(Shape)
  /// Exactly sixteen indices, each below 32.
  Shuffle
} derive(Eq, Debug)

///|
/// What a vector intrinsic takes, gives back, and builds.
pub struct Intrinsic {
  /// Receiver first, for a method.
  operands : Array[Ty]
  result : Ty?
  imm : Imm
  /// A free function `f(args)` rather than a method `recv.f(args)`.
  free : Bool
  /// The lane immediates, in source order, to the instruction.
  build : (Array[Int]) -> @wasm_bin.Instruction
}

///|
let table : Map[String, Intrinsic] = build_table()

///|
fn build_table() -> Map[String, Intrinsic] {
  let m : Map[String, Intrinsic] = Map([])
  fn add(
    name : String,
    operands : Array[Ty],
    result : Ty?,
    imm : Imm,
    free : Bool,
    build : (Array[Int]) -> @wasm_bin.Instruction,
  ) -> Unit {
    m[name] = { operands, result, imm, free, build, }
  }

  add("abs_f32x4", [TV128], Some(TV128), NoImm, false, _ => F32x4Abs)
  add("add_f32x4", [TV128, TV128], Some(TV128), NoImm, false, _ => F32x4Add)
  add("ceil_f32x4", [TV128], Some(TV128), NoImm, false, _ => F32x4Ceil)
  add("convert_i32x4_s_f32x4", [TV128], Some(TV128), NoImm, false, _ => {
    F32x4ConvertI32x4S
  })
  add("convert_i32x4_u_f32x4", [TV128], Some(TV128), NoImm, false, _ => {
    F32x4ConvertI32x4U
  })
  add("demote_f64x2_zero_f32x4", [TV128], Some(TV128), NoImm, false, _ => {
    F32x4DemoteF64x2Zero
  })
  add("div_f32x4", [TV128, TV128], Some(TV128), NoImm, false, _ => F32x4Div)
  add("eq_f32x4", [TV128, TV128], Some(TV128), NoImm, false, _ => F32x4Eq)
  add("extract_lane_f32x4", [TV128], Some(TF32), Lane(F32x4), false, l => {
    F32x4ExtractLane(l[0])
  })
  add("floor_f32x4", [TV128], Some(TV128), NoImm, false, _ => F32x4Floor)
  add("ge_f32x4", [TV128, TV128], Some(TV128), NoImm, false, _ => F32x4Ge)
  add("gt_f32x4", [TV128, TV128], Some(TV128), NoImm, false, _ => F32x4Gt)
  add("le_f32x4", [TV128, TV128], Some(TV128), NoImm, false, _ => F32x4Le)
  add("lt_f32x4", [TV128, TV128], Some(TV128), NoImm, false, _ => F32x4Lt)
  add("max_f32x4", [TV128, TV128], Some(TV128), NoImm, false, _ => F32x4Max)
  add("min_f32x4", [TV128, TV128], Some(TV128), NoImm, false, _ => F32x4Min)
  add("mul_f32x4", [TV128, TV128], Some(TV128), NoImm, false, _ => F32x4Mul)
  add("ne_f32x4", [TV128, TV128], Some(TV128), NoImm, false, _ => F32x4Ne)
  add("nearest_f32x4", [TV128], Some(TV128), NoImm, false, _ => F32x4Nearest)
  add("neg_f32x4", [TV128], Some(TV128), NoImm, false, _ => F32x4Neg)
  add("pmax_f32x4", [TV128, TV128], Some(TV128), NoImm, false, _ => F32x4Pmax)
  add("pmin_f32x4", [TV128, TV128], Some(TV128), NoImm, false, _ => F32x4Pmin)
  add("relaxed_madd_f32x4", [TV128, TV128, TV128], Some(TV128), NoImm, false, _ => {
    F32x4RelaxedMadd
  })
  add("relaxed_max_f32x4", [TV128, TV128], Some(TV128), NoImm, false, _ => {
    F32x4RelaxedMax
  })
  add("relaxed_min_f32x4", [TV128, TV128], Some(TV128), NoImm, false, _ => {
    F32x4RelaxedMin
  })
  add("relaxed_nmadd_f32x4", [TV128, TV128, TV128], Some(TV128), NoImm, false, _ => {
    F32x4RelaxedNmadd
  })
  add("replace_lane_f32x4", [TV128, TF32], Some(TV128), Lane(F32x4), false, l => {
    F32x4ReplaceLane(l[0])
  })
  add("splat_f32x4", [TF32], Some(TV128), NoImm, false, _ => F32x4Splat)
  add("sqrt_f32x4", [TV128], Some(TV128), NoImm, false, _ => F32x4Sqrt)
  add("sub_f32x4", [TV128, TV128], Some(TV128), NoImm, false, _ => F32x4Sub)
  add("trunc_f32x4", [TV128], Some(TV128), NoImm, false, _ => F32x4Trunc)
  add("abs_f64x2", [TV128], Some(TV128), NoImm, false, _ => F64x2Abs)
  add("add_f64x2", [TV128, TV128], Some(TV128), NoImm, false, _ => F64x2Add)
  add("ceil_f64x2", [TV128], Some(TV128), NoImm, false, _ => F64x2Ceil)
  add("convert_low_i32x4_s_f64x2", [TV128], Some(TV128), NoImm, false, _ => {
    F64x2ConvertLowI32x4S
  })
  add("convert_low_i32x4_u_f64x2", [TV128], Some(TV128), NoImm, false, _ => {
    F64x2ConvertLowI32x4U
  })
  add("div_f64x2", [TV128, TV128], Some(TV128), NoImm, false, _ => F64x2Div)
  add("eq_f64x2", [TV128, TV128], Some(TV128), NoImm, false, _ => F64x2Eq)
  add("extract_lane_f64x2", [TV128], Some(TF64), Lane(F64x2), false, l => {
    F64x2ExtractLane(l[0])
  })
  add("floor_f64x2", [TV128], Some(TV128), NoImm, false, _ => F64x2Floor)
  add("ge_f64x2", [TV128, TV128], Some(TV128), NoImm, false, _ => F64x2Ge)
  add("gt_f64x2", [TV128, TV128], Some(TV128), NoImm, false, _ => F64x2Gt)
  add("le_f64x2", [TV128, TV128], Some(TV128), NoImm, false, _ => F64x2Le)
  add("lt_f64x2", [TV128, TV128], Some(TV128), NoImm, false, _ => F64x2Lt)
  add("max_f64x2", [TV128, TV128], Some(TV128), NoImm, false, _ => F64x2Max)
  add("min_f64x2", [TV128, TV128], Some(TV128), NoImm, false, _ => F64x2Min)
  add("mul_f64x2", [TV128, TV128], Some(TV128), NoImm, false, _ => F64x2Mul)
  add("ne_f64x2", [TV128, TV128], Some(TV128), NoImm, false, _ => F64x2Ne)
  add("nearest_f64x2", [TV128], Some(TV128), NoImm, false, _ => F64x2Nearest)
  add("neg_f64x2", [TV128], Some(TV128), NoImm, false, _ => F64x2Neg)
  add("pmax_f64x2", [TV128, TV128], Some(TV128), NoImm, false, _ => F64x2Pmax)
  add("pmin_f64x2", [TV128, TV128], Some(TV128), NoImm, false, _ => F64x2Pmin)
  add("promote_low_f32x4_f64x2", [TV128], Some(TV128), NoImm, false, _ => {
    F64x2PromoteLowF32x4
  })
  add("relaxed_madd_f64x2", [TV128, TV128, TV128], Some(TV128), NoImm, false, _ => {
    F64x2RelaxedMadd
  })
  add("relaxed_max_f64x2", [TV128, TV128], Some(TV128), NoImm, false, _ => {
    F64x2RelaxedMax
  })
  add("relaxed_min_f64x2", [TV128, TV128], Some(TV128), NoImm, false, _ => {
    F64x2RelaxedMin
  })
  add("relaxed_nmadd_f64x2", [TV128, TV128, TV128], Some(TV128), NoImm, false, _ => {
    F64x2RelaxedNmadd
  })
  add("replace_lane_f64x2", [TV128, TF64], Some(TV128), Lane(F64x2), false, l => {
    F64x2ReplaceLane(l[0])
  })
  add("splat_f64x2", [TF64], Some(TV128), NoImm, false, _ => F64x2Splat)
  add("sqrt_f64x2", [TV128], Some(TV128), NoImm, false, _ => F64x2Sqrt)
  add("sub_f64x2", [TV128, TV128], Some(TV128), NoImm, false, _ => F64x2Sub)
  add("trunc_f64x2", [TV128], Some(TV128), NoImm, false, _ => F64x2Trunc)
  add("abs_i16x8", [TV128], Some(TV128), NoImm, false, _ => I16x8Abs)
  add("add_i16x8", [TV128, TV128], Some(TV128), NoImm, false, _ => I16x8Add)
  add("add_sat_s_i16x8", [TV128, TV128], Some(TV128), NoImm, false, _ => {
    I16x8AddSatS
  })
  add("add_sat_u_i16x8", [TV128, TV128], Some(TV128), NoImm, false, _ => {
    I16x8AddSatU
  })
  add("all_true_i16x8", [TV128], Some(TI32), NoImm, false, _ => I16x8AllTrue)
  add("avgr_u_i16x8", [TV128, TV128], Some(TV128), NoImm, false, _ => I16x8AvgrU)
  add("bitmask_i16x8", [TV128], Some(TI32), NoImm, false, _ => I16x8Bitmask)
  add("eq_i16x8", [TV128, TV128], Some(TV128), NoImm, false, _ => I16x8Eq)
  add("extadd_pairwise_i8x16_s_i16x8", [TV128], Some(TV128), NoImm, false, _ => {
    I16x8ExtAddPairwiseI8x16S
  })
  add("extadd_pairwise_i8x16_u_i16x8", [TV128], Some(TV128), NoImm, false, _ => {
    I16x8ExtAddPairwiseI8x16U
  })
  add("extend_high_i8x16_s_i16x8", [TV128], Some(TV128), NoImm, false, _ => {
    I16x8ExtendHighI8x16S
  })
  add("extend_high_i8x16_u_i16x8", [TV128], Some(TV128), NoImm, false, _ => {
    I16x8ExtendHighI8x16U
  })
  add("extend_low_i8x16_s_i16x8", [TV128], Some(TV128), NoImm, false, _ => {
    I16x8ExtendLowI8x16S
  })
  add("extend_low_i8x16_u_i16x8", [TV128], Some(TV128), NoImm, false, _ => {
    I16x8ExtendLowI8x16U
  })
  add("extmul_high_i8x16_s_i16x8", [TV128, TV128], Some(TV128), NoImm, false, _ => {
    I16x8ExtMulHighI8x16S
  })
  add("extmul_high_i8x16_u_i16x8", [TV128, TV128], Some(TV128), NoImm, false, _ => {
    I16x8ExtMulHighI8x16U
  })
  add("extmul_low_i8x16_s_i16x8", [TV128, TV128], Some(TV128), NoImm, false, _ => {
    I16x8ExtMulLowI8x16S
  })
  add("extmul_low_i8x16_u_i16x8", [TV128, TV128], Some(TV128), NoImm, false, _ => {
    I16x8ExtMulLowI8x16U
  })
  add("extract_lane_s_i16x8", [TV128], Some(TI32), Lane(I16x8), false, l => {
    I16x8ExtractLaneS(l[0])
  })
  add("extract_lane_u_i16x8", [TV128], Some(TI32), Lane(I16x8), false, l => {
    I16x8ExtractLaneU(l[0])
  })
  add("ge_s_i16x8", [TV128, TV128], Some(TV128), NoImm, false, _ => I16x8GeS)
  add("ge_u_i16x8", [TV128, TV128], Some(TV128), NoImm, false, _ => I16x8GeU)
  add("gt_s_i16x8", [TV128, TV128], Some(TV128), NoImm, false, _ => I16x8GtS)
  add("gt_u_i16x8", [TV128, TV128], Some(TV128), NoImm, false, _ => I16x8GtU)
  add("le_s_i16x8", [TV128, TV128], Some(TV128), NoImm, false, _ => I16x8LeS)
  add("le_u_i16x8", [TV128, TV128], Some(TV128), NoImm, false, _ => I16x8LeU)
  add("lt_s_i16x8", [TV128, TV128], Some(TV128), NoImm, false, _ => I16x8LtS)
  add("lt_u_i16x8", [TV128, TV128], Some(TV128), NoImm, false, _ => I16x8LtU)
  add("max_s_i16x8", [TV128, TV128], Some(TV128), NoImm, false, _ => I16x8MaxS)
  add("max_u_i16x8", [TV128, TV128], Some(TV128), NoImm, false, _ => I16x8MaxU)
  add("min_s_i16x8", [TV128, TV128], Some(TV128), NoImm, false, _ => I16x8MinS)
  add("min_u_i16x8", [TV128, TV128], Some(TV128), NoImm, false, _ => I16x8MinU)
  add("mul_i16x8", [TV128, TV128], Some(TV128), NoImm, false, _ => I16x8Mul)
  add("narrow_i32x4_s_i16x8", [TV128, TV128], Some(TV128), NoImm, false, _ => {
    I16x8NarrowI32x4S
  })
  add("narrow_i32x4_u_i16x8", [TV128, TV128], Some(TV128), NoImm, false, _ => {
    I16x8NarrowI32x4U
  })
  add("ne_i16x8", [TV128, TV128], Some(TV128), NoImm, false, _ => I16x8Ne)
  add("neg_i16x8", [TV128], Some(TV128), NoImm, false, _ => I16x8Neg)
  add("q15mulr_sat_s_i16x8", [TV128, TV128], Some(TV128), NoImm, false, _ => {
    I16x8Q15MulrSatS
  })
  add(
    "relaxed_dot_i8x16_i7x16_s_i16x8",
    [TV128, TV128],
    Some(TV128),
    NoImm,
    false,
    _ => I16x8RelaxedDotI8x16I7x16S,
  )
  add(
    "relaxed_laneselect_i16x8",
    [TV128, TV128, TV128],
    Some(TV128),
    NoImm,
    false,
    _ => I16x8RelaxedLaneselect,
  )
  add("relaxed_q15mulr_s_i16x8", [TV128, TV128], Some(TV128), NoImm, false, _ => {
    I16x8RelaxedQ15mulrS
  })
  add("replace_lane_i16x8", [TV128, TI32], Some(TV128), Lane(I16x8), false, l => {
    I16x8ReplaceLane(l[0])
  })
  add("shl_i16x8", [TV128, TI32], Some(TV128), NoImm, false, _ => I16x8Shl)
  add("shr_s_i16x8", [TV128, TI32], Some(TV128), NoImm, false, _ => I16x8ShrS)
  add("shr_u_i16x8", [TV128, TI32], Some(TV128), NoImm, false, _ => I16x8ShrU)
  add("splat_i16x8", [TI32], Some(TV128), NoImm, false, _ => I16x8Splat)
  add("sub_i16x8", [TV128, TV128], Some(TV128), NoImm, false, _ => I16x8Sub)
  add("sub_sat_s_i16x8", [TV128, TV128], Some(TV128), NoImm, false, _ => {
    I16x8SubSatS
  })
  add("sub_sat_u_i16x8", [TV128, TV128], Some(TV128), NoImm, false, _ => {
    I16x8SubSatU
  })
  add("abs_i32x4", [TV128], Some(TV128), NoImm, false, _ => I32x4Abs)
  add("add_i32x4", [TV128, TV128], Some(TV128), NoImm, false, _ => I32x4Add)
  add("all_true_i32x4", [TV128], Some(TI32), NoImm, false, _ => I32x4AllTrue)
  add("bitmask_i32x4", [TV128], Some(TI32), NoImm, false, _ => I32x4Bitmask)
  add("dot_i16x8_s_i32x4", [TV128, TV128], Some(TV128), NoImm, false, _ => {
    I32x4DotI16x8S
  })
  add("eq_i32x4", [TV128, TV128], Some(TV128), NoImm, false, _ => I32x4Eq)
  add("extadd_pairwise_i16x8_s_i32x4", [TV128], Some(TV128), NoImm, false, _ => {
    I32x4ExtAddPairwiseI16x8S
  })
  add("extadd_pairwise_i16x8_u_i32x4", [TV128], Some(TV128), NoImm, false, _ => {
    I32x4ExtAddPairwiseI16x8U
  })
  add("extend_high_i16x8_s_i32x4", [TV128], Some(TV128), NoImm, false, _ => {
    I32x4ExtendHighI16x8S
  })
  add("extend_high_i16x8_u_i32x4", [TV128], Some(TV128), NoImm, false, _ => {
    I32x4ExtendHighI16x8U
  })
  add("extend_low_i16x8_s_i32x4", [TV128], Some(TV128), NoImm, false, _ => {
    I32x4ExtendLowI16x8S
  })
  add("extend_low_i16x8_u_i32x4", [TV128], Some(TV128), NoImm, false, _ => {
    I32x4ExtendLowI16x8U
  })
  add("extmul_high_i16x8_s_i32x4", [TV128, TV128], Some(TV128), NoImm, false, _ => {
    I32x4ExtMulHighI16x8S
  })
  add("extmul_high_i16x8_u_i32x4", [TV128, TV128], Some(TV128), NoImm, false, _ => {
    I32x4ExtMulHighI16x8U
  })
  add("extmul_low_i16x8_s_i32x4", [TV128, TV128], Some(TV128), NoImm, false, _ => {
    I32x4ExtMulLowI16x8S
  })
  add("extmul_low_i16x8_u_i32x4", [TV128, TV128], Some(TV128), NoImm, false, _ => {
    I32x4ExtMulLowI16x8U
  })
  add("extract_lane_i32x4", [TV128], Some(TI32), Lane(I32x4), false, l => {
    I32x4ExtractLane(l[0])
  })
  add("ge_s_i32x4", [TV128, TV128], Some(TV128), NoImm, false, _ => I32x4GeS)
  add("ge_u_i32x4", [TV128, TV128], Some(TV128), NoImm, false, _ => I32x4GeU)
  add("gt_s_i32x4", [TV128, TV128], Some(TV128), NoImm, false, _ => I32x4GtS)
  add("gt_u_i32x4", [TV128, TV128], Some(TV128), NoImm, false, _ => I32x4GtU)
  add("le_s_i32x4", [TV128, TV128], Some(TV128), NoImm, false, _ => I32x4LeS)
  add("le_u_i32x4", [TV128, TV128], Some(TV128), NoImm, false, _ => I32x4LeU)
  add("lt_s_i32x4", [TV128, TV128], Some(TV128), NoImm, false, _ => I32x4LtS)
  add("lt_u_i32x4", [TV128, TV128], Some(TV128), NoImm, false, _ => I32x4LtU)
  add("max_s_i32x4", [TV128, TV128], Some(TV128), NoImm, false, _ => I32x4MaxS)
  add("max_u_i32x4", [TV128, TV128], Some(TV128), NoImm, false, _ => I32x4MaxU)
  add("min_s_i32x4", [TV128, TV128], Some(TV128), NoImm, false, _ => I32x4MinS)
  add("min_u_i32x4", [TV128, TV128], Some(TV128), NoImm, false, _ => I32x4MinU)
  add("mul_i32x4", [TV128, TV128], Some(TV128), NoImm, false, _ => I32x4Mul)
  add("ne_i32x4", [TV128, TV128], Some(TV128), NoImm, false, _ => I32x4Ne)
  add("neg_i32x4", [TV128], Some(TV128), NoImm, false, _ => I32x4Neg)
  add(
    "relaxed_dot_i8x16_i7x16_add_s_i32x4",
    [TV128, TV128, TV128],
    Some(TV128),
    NoImm,
    false,
    _ => I32x4RelaxedDotI8x16I7x16AddS,
  )
  add(
    "relaxed_laneselect_i32x4",
    [TV128, TV128, TV128],
    Some(TV128),
    NoImm,
    false,
    _ => I32x4RelaxedLaneselect,
  )
  add("relaxed_trunc_f32x4_s_i32x4", [TV128], Some(TV128), NoImm, false, _ => {
    I32x4RelaxedTruncF32x4S
  })
  add("relaxed_trunc_f32x4_u_i32x4", [TV128], Some(TV128), NoImm, false, _ => {
    I32x4RelaxedTruncF32x4U
  })
  add("relaxed_trunc_f64x2_s_zero_i32x4", [TV128], Some(TV128), NoImm, false, _ => {
    I32x4RelaxedTruncF64x2SZero
  })
  add("relaxed_trunc_f64x2_u_zero_i32x4", [TV128], Some(TV128), NoImm, false, _ => {
    I32x4RelaxedTruncF64x2UZero
  })
  add("replace_lane_i32x4", [TV128, TI32], Some(TV128), Lane(I32x4), false, l => {
    I32x4ReplaceLane(l[0])
  })
  add("shl_i32x4", [TV128, TI32], Some(TV128), NoImm, false, _ => I32x4Shl)
  add("shr_s_i32x4", [TV128, TI32], Some(TV128), NoImm, false, _ => I32x4ShrS)
  add("shr_u_i32x4", [TV128, TI32], Some(TV128), NoImm, false, _ => I32x4ShrU)
  add("splat_i32x4", [TI32], Some(TV128), NoImm, false, _ => I32x4Splat)
  add("sub_i32x4", [TV128, TV128], Some(TV128), NoImm, false, _ => I32x4Sub)
  add("trunc_sat_f32x4_s_i32x4", [TV128], Some(TV128), NoImm, false, _ => {
    I32x4TruncSatF32x4S
  })
  add("trunc_sat_f32x4_u_i32x4", [TV128], Some(TV128), NoImm, false, _ => {
    I32x4TruncSatF32x4U
  })
  add("trunc_sat_f64x2_s_i32x4", [TV128], Some(TV128), NoImm, false, _ => {
    I32x4TruncSatF64x2SZero
  })
  add("trunc_sat_f64x2_u_i32x4", [TV128], Some(TV128), NoImm, false, _ => {
    I32x4TruncSatF64x2UZero
  })
  add("abs_i64x2", [TV128], Some(TV128), NoImm, false, _ => I64x2Abs)
  add("add_i64x2", [TV128, TV128], Some(TV128), NoImm, false, _ => I64x2Add)
  add("all_true_i64x2", [TV128], Some(TI32), NoImm, false, _ => I64x2AllTrue)
  add("bitmask_i64x2", [TV128], Some(TI32), NoImm, false, _ => I64x2Bitmask)
  add("eq_i64x2", [TV128, TV128], Some(TV128), NoImm, false, _ => I64x2Eq)
  add("extend_high_i32x4_s_i64x2", [TV128], Some(TV128), NoImm, false, _ => {
    I64x2ExtendHighI32x4S
  })
  add("extend_high_i32x4_u_i64x2", [TV128], Some(TV128), NoImm, false, _ => {
    I64x2ExtendHighI32x4U
  })
  add("extend_low_i32x4_s_i64x2", [TV128], Some(TV128), NoImm, false, _ => {
    I64x2ExtendLowI32x4S
  })
  add("extend_low_i32x4_u_i64x2", [TV128], Some(TV128), NoImm, false, _ => {
    I64x2ExtendLowI32x4U
  })
  add("extmul_high_i32x4_s_i64x2", [TV128, TV128], Some(TV128), NoImm, false, _ => {
    I64x2ExtMulHighI32x4S
  })
  add("extmul_high_i32x4_u_i64x2", [TV128, TV128], Some(TV128), NoImm, false, _ => {
    I64x2ExtMulHighI32x4U
  })
  add("extmul_low_i32x4_s_i64x2", [TV128, TV128], Some(TV128), NoImm, false, _ => {
    I64x2ExtMulLowI32x4S
  })
  add("extmul_low_i32x4_u_i64x2", [TV128, TV128], Some(TV128), NoImm, false, _ => {
    I64x2ExtMulLowI32x4U
  })
  add("extract_lane_i64x2", [TV128], Some(TI64), Lane(I64x2), false, l => {
    I64x2ExtractLane(l[0])
  })
  add("ge_s_i64x2", [TV128, TV128], Some(TV128), NoImm, false, _ => I64x2GeS)
  add("gt_s_i64x2", [TV128, TV128], Some(TV128), NoImm, false, _ => I64x2GtS)
  add("le_s_i64x2", [TV128, TV128], Some(TV128), NoImm, false, _ => I64x2LeS)
  add("lt_s_i64x2", [TV128, TV128], Some(TV128), NoImm, false, _ => I64x2LtS)
  add("mul_i64x2", [TV128, TV128], Some(TV128), NoImm, false, _ => I64x2Mul)
  add("ne_i64x2", [TV128, TV128], Some(TV128), NoImm, false, _ => I64x2Ne)
  add("neg_i64x2", [TV128], Some(TV128), NoImm, false, _ => I64x2Neg)
  add(
    "relaxed_laneselect_i64x2",
    [TV128, TV128, TV128],
    Some(TV128),
    NoImm,
    false,
    _ => I64x2RelaxedLaneselect,
  )
  add("replace_lane_i64x2", [TV128, TI64], Some(TV128), Lane(I64x2), false, l => {
    I64x2ReplaceLane(l[0])
  })
  add("shl_i64x2", [TV128, TI32], Some(TV128), NoImm, false, _ => I64x2Shl)
  add("shr_s_i64x2", [TV128, TI32], Some(TV128), NoImm, false, _ => I64x2ShrS)
  add("shr_u_i64x2", [TV128, TI32], Some(TV128), NoImm, false, _ => I64x2ShrU)
  add("splat_i64x2", [TI64], Some(TV128), NoImm, false, _ => I64x2Splat)
  add("sub_i64x2", [TV128, TV128], Some(TV128), NoImm, false, _ => I64x2Sub)
  add("abs_i8x16", [TV128], Some(TV128), NoImm, false, _ => I8x16Abs)
  add("add_i8x16", [TV128, TV128], Some(TV128), NoImm, false, _ => I8x16Add)
  add("add_sat_s_i8x16", [TV128, TV128], Some(TV128), NoImm, false, _ => {
    I8x16AddSatS
  })
  add("add_sat_u_i8x16", [TV128, TV128], Some(TV128), NoImm, false, _ => {
    I8x16AddSatU
  })
  add("all_true_i8x16", [TV128], Some(TI32), NoImm, false, _ => I8x16AllTrue)
  add("avgr_u_i8x16", [TV128, TV128], Some(TV128), NoImm, false, _ => I8x16AvgrU)
  add("bitmask_i8x16", [TV128], Some(TI32), NoImm, false, _ => I8x16Bitmask)
  add("eq_i8x16", [TV128, TV128], Some(TV128), NoImm, false, _ => I8x16Eq)
  add("extract_lane_s_i8x16", [TV128], Some(TI32), Lane(I8x16), false, l => {
    I8x16ExtractLaneS(l[0])
  })
  add("extract_lane_u_i8x16", [TV128], Some(TI32), Lane(I8x16), false, l => {
    I8x16ExtractLaneU(l[0])
  })
  add("ge_s_i8x16", [TV128, TV128], Some(TV128), NoImm, false, _ => I8x16GeS)
  add("ge_u_i8x16", [TV128, TV128], Some(TV128), NoImm, false, _ => I8x16GeU)
  add("gt_s_i8x16", [TV128, TV128], Some(TV128), NoImm, false, _ => I8x16GtS)
  add("gt_u_i8x16", [TV128, TV128], Some(TV128), NoImm, false, _ => I8x16GtU)
  add("le_s_i8x16", [TV128, TV128], Some(TV128), NoImm, false, _ => I8x16LeS)
  add("le_u_i8x16", [TV128, TV128], Some(TV128), NoImm, false, _ => I8x16LeU)
  add("lt_s_i8x16", [TV128, TV128], Some(TV128), NoImm, false, _ => I8x16LtS)
  add("lt_u_i8x16", [TV128, TV128], Some(TV128), NoImm, false, _ => I8x16LtU)
  add("max_s_i8x16", [TV128, TV128], Some(TV128), NoImm, false, _ => I8x16MaxS)
  add("max_u_i8x16", [TV128, TV128], Some(TV128), NoImm, false, _ => I8x16MaxU)
  add("min_s_i8x16", [TV128, TV128], Some(TV128), NoImm, false, _ => I8x16MinS)
  add("min_u_i8x16", [TV128, TV128], Some(TV128), NoImm, false, _ => I8x16MinU)
  add("narrow_i16x8_s_i8x16", [TV128, TV128], Some(TV128), NoImm, false, _ => {
    I8x16NarrowI16x8S
  })
  add("narrow_i16x8_u_i8x16", [TV128, TV128], Some(TV128), NoImm, false, _ => {
    I8x16NarrowI16x8U
  })
  add("ne_i8x16", [TV128, TV128], Some(TV128), NoImm, false, _ => I8x16Ne)
  add("neg_i8x16", [TV128], Some(TV128), NoImm, false, _ => I8x16Neg)
  add("popcnt_i8x16", [TV128], Some(TV128), NoImm, false, _ => I8x16Popcnt)
  add(
    "relaxed_laneselect_i8x16",
    [TV128, TV128, TV128],
    Some(TV128),
    NoImm,
    false,
    _ => I8x16RelaxedLaneselect,
  )
  add("relaxed_swizzle_i8x16", [TV128, TV128], Some(TV128), NoImm, false, _ => {
    I8x16RelaxedSwizzle
  })
  add("replace_lane_i8x16", [TV128, TI32], Some(TV128), Lane(I8x16), false, l => {
    I8x16ReplaceLane(l[0])
  })
  add("shl_i8x16", [TV128, TI32], Some(TV128), NoImm, false, _ => I8x16Shl)
  add("shr_s_i8x16", [TV128, TI32], Some(TV128), NoImm, false, _ => I8x16ShrS)
  add("shr_u_i8x16", [TV128, TI32], Some(TV128), NoImm, false, _ => I8x16ShrU)
  add("shuffle_i8x16", [TV128, TV128], Some(TV128), Shuffle, false, l => {
    I8x16Shuffle(FixedArray::from_array(l))
  })
  add("splat_i8x16", [TI32], Some(TV128), NoImm, false, _ => I8x16Splat)
  add("sub_i8x16", [TV128, TV128], Some(TV128), NoImm, false, _ => I8x16Sub)
  add("sub_sat_s_i8x16", [TV128, TV128], Some(TV128), NoImm, false, _ => {
    I8x16SubSatS
  })
  add("sub_sat_u_i8x16", [TV128, TV128], Some(TV128), NoImm, false, _ => {
    I8x16SubSatU
  })
  add("swizzle_i8x16", [TV128, TV128], Some(TV128), NoImm, false, _ => {
    I8x16Swizzle
  })
  add("and_v128", [TV128, TV128], Some(TV128), NoImm, false, _ => V128And)
  add("andnot_v128", [TV128, TV128], Some(TV128), NoImm, false, _ => V128AndNot)
  add("any_true_v128", [TV128], Some(TI32), NoImm, false, _ => V128AnyTrue)
  add(bitselect_name, [TV128, TV128, TV128], Some(TV128), NoImm, true, _ => {
    V128Bitselect
  })
  add("not_v128", [TV128], Some(TV128), NoImm, false, _ => V128Not)
  add("or_v128", [TV128, TV128], Some(TV128), NoImm, false, _ => V128Or)
  add("xor_v128", [TV128, TV128], Some(TV128), NoImm, false, _ => V128Xor)
  m
}

///|
/// The intrinsic of this name, if there is one.
pub fn classify(name : String) -> Intrinsic? {
  table.get(name)
}

///|
/// Every method intrinsic whose receiver has this type, sorted.
///
/// The receiver is the first operand, which is what makes "the methods on a
/// v128" answerable at all -- a free function has no receiver and is excluded.
pub fn method_names(recv : Ty) -> Array[String] {
  let out : Array[String] = []
  for name, i in table {
    if !i.free && i.operands.length() > 0 && i.operands[0] == recv {
      out.push(name)
    }
  }
  out.sort()
  out
}

///|
/// How many operations the registry holds.
pub fn size() -> Int {
  table.length()
}
