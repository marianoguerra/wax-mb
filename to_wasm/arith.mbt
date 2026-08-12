// Choosing an arithmetic opcode from the type the checker inferred.
//
// Ported from the binop/unop tables of wax/src/lib-conversion/to_wasm.ml.
//
// This is the narrow interface the whole port turns on. `a + b` is one token in
// the source and four instructions here -- `i32.add`, `i64.add`, `f32.add`,
// `f64.add` -- and nothing in the syntax says which. The annotation the checker
// left on the node does, and it is the only thing that does.

///|
/// The instruction a binary operator becomes at this value type.
///
/// `None` when the operator has no form at that type: comparing two `v128`s with
/// `<` has no opcode, and neither does a signed shift of a float. The caller
/// raises rather than guessing, since a plausible substitute would be a module
/// that validates and computes something else.
pub fn binop_instruction(
  op : @ast.BinOp,
  ty : @wasm_types.ValType[Int],
) -> @wasm_bin.Instruction? {
  match ty {
    I32 => i32_binop(op)
    I64 => i64_binop(op)
    F32 => f32_binop(op)
    F64 => f64_binop(op)
    V128 | Ref(_) => None
  }
}

///|
fn i32_binop(op : @ast.BinOp) -> @wasm_bin.Instruction? {
  match op {
    Add => Some(I32Add)
    Sub => Some(I32Sub)
    Mul => Some(I32Mul)
    Div(Some(Signed)) => Some(I32DivS)
    Div(Some(Unsigned)) => Some(I32DivU)
    Rem(Signed) => Some(I32RemS)
    Rem(Unsigned) => Some(I32RemU)
    And => Some(I32And)
    Or => Some(I32Or)
    Xor => Some(I32Xor)
    Shl => Some(I32Shl)
    Shr(Signed) => Some(I32ShrS)
    Shr(Unsigned) => Some(I32ShrU)
    Eq => Some(I32Eq)
    Ne => Some(I32Ne)
    Lt(Some(Signed)) => Some(I32LtS)
    Lt(Some(Unsigned)) => Some(I32LtU)
    Gt(Some(Signed)) => Some(I32GtS)
    Gt(Some(Unsigned)) => Some(I32GtU)
    Le(Some(Signed)) => Some(I32LeS)
    Le(Some(Unsigned)) => Some(I32LeU)
    Ge(Some(Signed)) => Some(I32GeS)
    Ge(Some(Unsigned)) => Some(I32GeU)
    // An unsigned-less comparison or division is the FLOAT spelling; on an
    // integer it means the source said `/` where it had to say `/s` or `/u`,
    // which the checker has already reported.
    Div(None) | Lt(None) | Gt(None) | Le(None) | Ge(None) => None
  }
}

///|
fn i64_binop(op : @ast.BinOp) -> @wasm_bin.Instruction? {
  match op {
    Add => Some(I64Add)
    Sub => Some(I64Sub)
    Mul => Some(I64Mul)
    Div(Some(Signed)) => Some(I64DivS)
    Div(Some(Unsigned)) => Some(I64DivU)
    Rem(Signed) => Some(I64RemS)
    Rem(Unsigned) => Some(I64RemU)
    And => Some(I64And)
    Or => Some(I64Or)
    Xor => Some(I64Xor)
    Shl => Some(I64Shl)
    Shr(Signed) => Some(I64ShrS)
    Shr(Unsigned) => Some(I64ShrU)
    Eq => Some(I64Eq)
    Ne => Some(I64Ne)
    Lt(Some(Signed)) => Some(I64LtS)
    Lt(Some(Unsigned)) => Some(I64LtU)
    Gt(Some(Signed)) => Some(I64GtS)
    Gt(Some(Unsigned)) => Some(I64GtU)
    Le(Some(Signed)) => Some(I64LeS)
    Le(Some(Unsigned)) => Some(I64LeU)
    Ge(Some(Signed)) => Some(I64GeS)
    Ge(Some(Unsigned)) => Some(I64GeU)
    Div(None) | Lt(None) | Gt(None) | Le(None) | Ge(None) => None
  }
}

///|
fn f32_binop(op : @ast.BinOp) -> @wasm_bin.Instruction? {
  match op {
    Add => Some(F32Add)
    Sub => Some(F32Sub)
    Mul => Some(F32Mul)
    Div(None) => Some(F32Div)
    Eq => Some(F32Eq)
    Ne => Some(F32Ne)
    Lt(None) => Some(F32Lt)
    Gt(None) => Some(F32Gt)
    Le(None) => Some(F32Le)
    Ge(None) => Some(F32Ge)
    // A float has no signed form of anything, and no remainder or bitwise
    // operator at all.
    _ => None
  }
}

///|
fn f64_binop(op : @ast.BinOp) -> @wasm_bin.Instruction? {
  match op {
    Add => Some(F64Add)
    Sub => Some(F64Sub)
    Mul => Some(F64Mul)
    Div(None) => Some(F64Div)
    Eq => Some(F64Eq)
    Ne => Some(F64Ne)
    Lt(None) => Some(F64Lt)
    Gt(None) => Some(F64Gt)
    Le(None) => Some(F64Le)
    Ge(None) => Some(F64Ge)
    _ => None
  }
}
