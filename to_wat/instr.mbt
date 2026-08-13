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
/// The constructor name of an instruction, for the gap report: the debug
/// rendering up to its first immediate.
fn constructor_of(i : @wasm_bin.Instruction) -> String {
  let s = @debug.to_string(i)
  match s.find("(") {
    Some(k) => s[:k].to_owned()
    None => s
  }
}

///|
/// The label a branch depth names: the enclosing blocks are counted outward
/// from the innermost, so a depth is a distance from the END of the scope.
fn label(scope : Array[String?], depth : Int) -> String {
  let k = scope.length() - 1 - depth
  if k >= 0 && k < scope.length() && scope[k] is Some(name) {
    "$" + name
  } else {
    depth.to_string()
  }
}

///|
/// The mnemonic and immediates of one instruction, without its operands.
pub fn mnemonic(
  i : @wasm_bin.Instruction,
  names : @wasm_bin.Names,
  locals : Map[Int, Bytes],
  scope? : Array[String?] = [],
) -> String raise WatError {
  // Everything with no immediate follows one rule and lives in its own table;
  // what is left here is the instructions whose immediates have to be written.
  if nullary(i) is Some(name) {
    return name
  }
  if memarg_instr(i, names) is Some(name) {
    return name
  }
  match i {
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
    RefFunc(k) => "ref.func " + name_or(names.functions, k)
    Br(d) => "br " + label(scope, d)
    BrIf(d) => "br_if " + label(scope, d)
    CallIndirect(t, tab) =>
      "call_indirect " +
      name_or(names.tables, tab) +
      " (type " +
      t.to_string() +
      ")"
    ReturnCallIndirect(t, tab) =>
      "return_call_indirect " +
      name_or(names.tables, tab) +
      " (type " +
      t.to_string() +
      ")"
    CallRef(t) => "call_ref " + t.to_string()
    ReturnCallRef(t) => "return_call_ref " + t.to_string()
    RefNull(h) => "ref.null " + heaptype(h, names.types)
    F32Const(v) => "f32.const " + v.to_double().to_string()
    F64Const(v) => "f64.const " + v.to_string()
    StructNew(t) => "struct.new " + name_or(names.types, t)
    StructNewDefault(t) => "struct.new_default " + name_or(names.types, t)
    ArrayNew(t) => "array.new " + name_or(names.types, t)
    ArrayNewDefault(t) => "array.new_default " + name_or(names.types, t)
    ArrayNewFixed(t, n) =>
      "array.new_fixed " + name_or(names.types, t) + " " + n.to_string()
    RefTest(r) => "ref.test " + reftype(r, names.types)
    RefCast(r) => "ref.cast " + reftype(r, names.types)
    Throw(t) => "throw " + name_or(names.tags, t)
    // Everything else is a gap, not a guess: reporting it keeps the burn-down
    // honest, exactly as the lowering's own gaps do -- and NAMING it is what
    // makes the remainder countable rather than one undifferentiated pile.
    _ => raise NotPrinted(constructor_of(i))
  }
}
