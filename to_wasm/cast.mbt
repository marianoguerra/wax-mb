// Lowering a cast.
//
// Ported from the `Cast` case of wax/src/lib-conversion/to_wasm.ml.
//
// `e as t` is one syntax over three unrelated jobs, and which one it is depends
// entirely on the pair of types involved:
//
//   * between two numeric types it is a CONVERSION, and the instruction is a
//     table entry over (from, to) -- widen, narrow, or change family;
//   * between two reference types it is a `ref.cast`, which checks at run time
//     and traps;
//   * from a numeric type to the same numeric type it is nothing at all, which
//     is worth emitting nothing for rather than an identity instruction.
//
// The float-to-integer direction has two forms the syntax spells differently:
// `as i32_s` saturates and `as i32_s_strict` traps. They are different
// instructions, and picking the wrong one is a module that silently computes
// something else at the edges.

///|
/// The instruction a numeric conversion becomes, or `None` when the pair has no
/// conversion at all.
///
/// An identity pair yields `Some([])`: the cast is real in the source -- it
/// pins a width the checker used -- and nothing at all in the output.
pub fn numeric_cast(
  from : @wasm_types.ValType[Int],
  to : @wasm_types.ValType[Int],
) -> Array[@wasm_bin.Instruction]? {
  if from == to {
    return Some([])
  }
  match (from, to) {
    (I64, I32) => Some([I32WrapI64])
    // A widening integer cast is SIGNED: wax `as i64` on an i32 means the
    // value, and the unsigned form is written `as i64_u`, which reaches here as
    // a `Signed` cast rather than this one.
    (I32, I64) => Some([I64ExtendI32S])
    (F64, F32) => Some([F32DemoteF64])
    (F32, F64) => Some([F64PromoteF32])
    (I32, F32) => Some([F32ConvertI32S])
    (I32, F64) => Some([F64ConvertI32S])
    (I64, F32) => Some([F32ConvertI64S])
    (I64, F64) => Some([F64ConvertI64S])
    // Float to integer without a written signedness has no instruction: the
    // source has to say `as i32_s` or `as i32_u`, and the checker has said so.
    (F32, I32) | (F32, I64) | (F64, I32) | (F64, I64) => None
    _ => None
  }
}

///|
/// The instruction a `Signed` cast becomes: a float-to-integer conversion, or a
/// widening of an integer with the signedness written out.
///
/// `strict` is the trapping form; without it the saturating one. They differ
/// only at the edges, which is exactly where a wrong choice is hardest to
/// notice.
pub fn signed_cast(
  from : @wasm_types.ValType[Int],
  to : @ast.NumType,
  signage : @wasm_types.Signage,
  strict : Bool,
) -> Array[@wasm_bin.Instruction]? {
  match (from, to, signage, strict) {
    (F32, I32, Signed, true) => Some([I32TruncF32S])
    (F32, I32, Unsigned, true) => Some([I32TruncF32U])
    (F64, I32, Signed, true) => Some([I32TruncF64S])
    (F64, I32, Unsigned, true) => Some([I32TruncF64U])
    (F32, I64, Signed, true) => Some([I64TruncF32S])
    (F32, I64, Unsigned, true) => Some([I64TruncF32U])
    (F64, I64, Signed, true) => Some([I64TruncF64S])
    (F64, I64, Unsigned, true) => Some([I64TruncF64U])
    (F32, I32, Signed, false) => Some([I32TruncSatF32S])
    (F32, I32, Unsigned, false) => Some([I32TruncSatF32U])
    (F64, I32, Signed, false) => Some([I32TruncSatF64S])
    (F64, I32, Unsigned, false) => Some([I32TruncSatF64U])
    (F32, I64, Signed, false) => Some([I64TruncSatF32S])
    (F32, I64, Unsigned, false) => Some([I64TruncSatF32U])
    (F64, I64, Signed, false) => Some([I64TruncSatF64S])
    (F64, I64, Unsigned, false) => Some([I64TruncSatF64U])
    // An integer widened with its signedness written out.
    (I32, I64, Signed, _) => Some([I64ExtendI32S])
    (I32, I64, Unsigned, _) => Some([I64ExtendI32U])
    // An integer converted to a float with its signedness written out.
    (I32, F32, Signed, _) => Some([F32ConvertI32S])
    (I32, F32, Unsigned, _) => Some([F32ConvertI32U])
    (I32, F64, Signed, _) => Some([F64ConvertI32S])
    (I32, F64, Unsigned, _) => Some([F64ConvertI32U])
    (I64, F32, Signed, _) => Some([F32ConvertI64S])
    (I64, F32, Unsigned, _) => Some([F32ConvertI64U])
    (I64, F64, Signed, _) => Some([F64ConvertI64S])
    (I64, F64, Unsigned, _) => Some([F64ConvertI64U])
    // A narrowing needs no sign: the bits are simply dropped.
    (I64, I32, _, _) => Some([I32WrapI64])
    _ => None
  }
}
