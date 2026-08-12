// Lowering a typed module to the binary form.
//
// Ported from wax/src/lib-conversion/to_wasm.ml, folding in the index
// resolution of wax/src/lib-wasm/text_to_binary.ml.
//
// The interface to the checker is narrower than its size suggests: every
// instruction node carries the types it produced, and that annotation is what
// selects an opcode. `i32.add` and `i64.add` are one `+` in the source and two
// instructions here, and the only thing that tells them apart is the cell the
// checker left behind.
//
// Anything not yet lowered RAISES rather than emitting something plausible. The
// vendored encoder shipped with a `_ => 0x00` fallback that turned every
// unhandled instruction into `unreachable`, which is a valid-looking module that
// does the wrong thing; removing it is what made the compiler name the gaps, and
// the same discipline applies here.

///|
pub suberror LowerError {
  /// A construct the lowering does not handle yet, named so the gap is legible.
  NotLowered(String, @basic.Location)
  /// A name or type the checker accepted but that did not survive to here.
  Unresolved(String, @basic.Location)
}

///|
/// A one-line description, for the CLI's report.
///
/// The location is named as `file:line:col` rather than rendered as a caret
/// diagram: this is a gap in the port, not a fault in the user's module, and
/// the two should not look alike.
pub impl Show for LowerError with fn output(self, logger) {
  let (what, kind, loc) = match self {
    NotLowered(what, loc) => (what, "not lowered yet", loc)
    Unresolved(what, loc) => (what, "did not resolve", loc)
  }
  logger.write_string(
    "\{loc.start.fname}:\{loc.start.lnum}:\{loc.start.column1()}: \{what} \{kind}",
  )
}

///|
/// What the lowering needs to know while walking one module.
pub struct Lowering {
  ctx : @typing_env.ModuleContext
  store : @type_store.TypeStore
  indices : Indices
  /// Local name to index, rebuilt per function: parameters first, in order,
  /// then each `let` as it is declared. Wasm numbers them in exactly that
  /// order, so the map is built by walking the same way.
  mut locals : Map[String, Int]
  mut local_types : Array[@wasm_types.ValType[Int]]
  /// The labels in scope, innermost last. A `br` names one; the binary counts
  /// outward from the innermost, so the depth is the distance from the end.
  mut labels : Array[String?]
}

///|
/// The branch depth of a label, counting outward from the innermost.
pub fn Lowering::depth_of(self : Lowering, name : String) -> Int? {
  let n = self.labels.length()
  for k = n - 1; k >= 0; k = k - 1 {
    if self.labels[k] is Some(l) && l == name {
      return Some(n - 1 - k)
    }
  }
  None
}

///|
/// The value type a checked node produced, as an index-form value type.
///
/// `None` when the node produced no single value, or one that never resolved --
/// the caller then raises, because an opcode cannot be chosen without it.
pub fn node_valtype(
  i : @ast.Instr[@typing_env.InferredAnnotation],
) -> @wasm_types.ValType[Int]? {
  guard i.info.0.length() == 1 else { return None }
  guard @typing_env.standalone_valtype(i.info.0[0]) is Some(v) else {
    return None
  }
  Some(lower_valtype(v.internal))
}
