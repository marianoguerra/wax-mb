// Instruction mnemonics.
//
// A first slice: the instructions the corpus's simplest modules are made of.
// Anything not here reports rather than guessing a name -- the same discipline
// the lowering uses, so a gap is a gap and not a plausible wrong answer.

///|
pub suberror WatError {
  /// An instruction with no spelling here yet, named so the gap is legible.
  NotPrinted(String)
}

///|
pub impl Show for WatError with fn output(self, logger) {
  let NotPrinted(what) = self
  logger.write_string(what + " has no text form yet")
}

///|
/// The mnemonic and immediates of one instruction, without its operands.
pub fn mnemonic(
  i : @wasm_bin.Instruction,
  names : @wasm_bin.Names,
  locals : Map[Int, Bytes],
) -> String raise WatError {
  match i {
    Unreachable => "unreachable"
    Nop => "nop"
    Drop => "drop"
    Return => "return"
    Select => "select"
    I32Const(v) => "i32.const " + v.to_string()
    I64Const(v) => "i64.const " + v.to_string()
    // A local is named where the function named it, which is per FUNCTION --
    // unlike every other index space, whose names are the module's.
    LocalGet(k) => "local.get " + name_or(locals, k)
    LocalSet(k) => "local.set " + name_or(locals, k)
    LocalTee(k) => "local.tee " + name_or(locals, k)
    GlobalGet(k) => "global.get " + name_or(names.globals, k)
    GlobalSet(k) => "global.set " + name_or(names.globals, k)
    Call(k) => "call " + name_or(names.functions, k)
    ReturnCall(k) => "return_call " + name_or(names.functions, k)
    RefIsNull => "ref.is_null"
    RefAsNonNull => "ref.as_non_null"
    RefFunc(k) => "ref.func " + name_or(names.functions, k)
    I32Eqz => "i32.eqz"
    I64Eqz => "i64.eqz"
    I32Add => "i32.add"
    I32Sub => "i32.sub"
    I32Mul => "i32.mul"
    I32And => "i32.and"
    I32Or => "i32.or"
    I32Xor => "i32.xor"
    I64Add => "i64.add"
    I64Sub => "i64.sub"
    I64Mul => "i64.mul"
    F32Add => "f32.add"
    F32Sub => "f32.sub"
    F32Mul => "f32.mul"
    F32Div => "f32.div"
    F64Add => "f64.add"
    F64Sub => "f64.sub"
    F64Mul => "f64.mul"
    F64Div => "f64.div"
    _ => raise NotPrinted("this instruction")
  }
}
