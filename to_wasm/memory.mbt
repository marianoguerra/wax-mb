// Lowering memory accesses.
//
// Ported from the memory cases of wax/src/lib-conversion/to_wasm.ml.
//
// A load has a WIDTH and a SIGNEDNESS, and wax splits them across two
// constructs: `m.load8(p)` says the width, and a following `as i32_s` says the
// sign. The binary has one instruction for the pair, so the cast fuses into the
// load rather than following it -- and it has to, because there is no separate
// sign-extension to emit afterwards. A bare `load8` with no cast is the
// zero-extending form, which is what the source means by saying nothing.

///|
/// The natural alignment, as a power of two, of an access of this width.
pub fn natural_align(meth : String) -> Int {
  match meth {
    "load8" | "store8" => 0
    "load16" | "store16" => 1
    "load32" | "store32" | "loadf32" | "storef32" => 2
    _ => 3
  }
}

///|
/// The memarg an access carries: its alignment and offset immediates.
///
/// They arrive as `Labelled` nodes among the arguments -- kept there by the
/// checker precisely so the code generator can read them -- and default to the
/// natural alignment and a zero offset when unwritten.
pub fn Lowering::memarg(
  self : Lowering,
  meth : @ast.Ident,
  args : Array[@ast.Instr[@typing_env.InferredAnnotation]],
  loc : @basic.Location,
) -> (Int, Int64) raise LowerError {
  self.memarg_natural(natural_align(meth.name), args, loc)
}

///|
/// The same, for an access whose natural alignment is not read off a scalar
/// method name -- the vector accesses, whose widths the SIMD registry knows.
pub fn Lowering::memarg_natural(
  self : Lowering,
  natural : Int,
  args : Array[@ast.Instr[@typing_env.InferredAnnotation]],
  loc : @basic.Location,
) -> (Int, Int64) raise LowerError {
  ignore(self)
  let mut align = natural
  let mut offset = 0L
  for a in args {
    guard a.desc is Labelled(label, value) else { continue }
    guard value.desc is Int(s) else {
      raise Unresolved("memory immediate", loc)
    }
    let n = parse_i64(s, loc)
    match label.name {
      // The written alignment is a BYTE COUNT; the format stores its log.
      "align" => align = log2_exact(n, loc)
      "offset" => offset = n
      // `lane:` rides along in the same argument list but is not part of the
      // memarg -- it is a separate immediate the lane accesses take, read by
      // the caller that knows whether there is one.
      "lane" => ()
      _ => raise Unresolved("memory immediate label", loc)
    }
  }
  (align, offset)
}

///|
/// The base-2 log of a power of two.
fn log2_exact(n : Int64, loc : @basic.Location) -> Int raise LowerError {
  let mut v = n
  let mut k = 0
  guard v > 0 else { raise Unresolved("alignment", loc) }
  while v > 1 {
    guard v % 2 == 0 else { raise Unresolved("alignment", loc) }
    v = v / 2
    k = k + 1
  }
  k
}

///|
/// The instruction a load becomes, given the width and how the result is used.
///
/// `as_` is the type a following cast asks for, and the sign it asks for; with
/// no cast the narrow loads zero-extend into an i32, which is what a bare
/// `load8` means.
pub fn load_instruction(
  meth : String,
  mem : Int,
  align : Int,
  offset : Int64,
  as_ : (@ast.NumType, @wasm_types.Signage)?,
) -> @wasm_bin.Instruction? {
  match (meth, as_) {
    ("load8", None) => Some(I32Load8U(mem, align, offset))
    ("load8", Some((I32, Signed))) => Some(I32Load8S(mem, align, offset))
    ("load8", Some((I32, Unsigned))) => Some(I32Load8U(mem, align, offset))
    ("load8", Some((I64, Signed))) => Some(I64Load8S(mem, align, offset))
    ("load8", Some((I64, Unsigned))) => Some(I64Load8U(mem, align, offset))
    ("load16", None) => Some(I32Load16U(mem, align, offset))
    ("load16", Some((I32, Signed))) => Some(I32Load16S(mem, align, offset))
    ("load16", Some((I32, Unsigned))) => Some(I32Load16U(mem, align, offset))
    ("load16", Some((I64, Signed))) => Some(I64Load16S(mem, align, offset))
    ("load16", Some((I64, Unsigned))) => Some(I64Load16U(mem, align, offset))
    // A 32-bit load is already an i32; only widening it to an i64 needs a sign.
    ("load32", None) | ("load32", Some((I32, _))) =>
      Some(I32Load(mem, align, offset))
    ("load32", Some((I64, Signed))) => Some(I64Load32S(mem, align, offset))
    ("load32", Some((I64, Unsigned))) => Some(I64Load32U(mem, align, offset))
    ("load64", None) => Some(I64Load(mem, align, offset))
    ("loadf32", None) => Some(F32Load(mem, align, offset))
    ("loadf64", None) => Some(F64Load(mem, align, offset))
    _ => None
  }
}

///|
/// The instruction a store becomes. A store has no signedness: it writes the low
/// bytes of whatever it is given.
pub fn store_instruction(
  meth : String,
  mem : Int,
  align : Int,
  offset : Int64,
  value : @wasm_types.ValType[Int]?,
) -> @wasm_bin.Instruction? {
  // A narrow store writes the low bytes of the VALUE, so which instruction it
  // is depends on how wide that value is -- the width alone does not say. In
  // unreachable code there is no value type to read; the width is what matters
  // there, so the i32 form stands in.
  let wide = value is Some(I64)
  match (meth, wide) {
    ("store8", true) => Some(I64Store8(mem, align, offset))
    ("store8", false) => Some(I32Store8(mem, align, offset))
    ("store16", true) => Some(I64Store16(mem, align, offset))
    ("store16", false) => Some(I32Store16(mem, align, offset))
    ("store32", true) => Some(I64Store32(mem, align, offset))
    ("store32", false) => Some(I32Store(mem, align, offset))
    ("store64", _) => Some(I64Store(mem, align, offset))
    ("storef32", _) => Some(F32Store(mem, align, offset))
    ("storef64", _) => Some(F64Store(mem, align, offset))
    _ => None
  }
}
