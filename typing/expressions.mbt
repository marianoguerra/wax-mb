// Reading the value an instruction produced.
//
// Ported from wax/src/lib-wax/typing.ml.
//
// Every checked instruction carries the types of the values it leaves on the
// stack -- an array, because an instruction may leave none or several. Asking
// for THE value it produced is therefore a question that can fail, and failing
// is a diagnostic rather than an option the caller inspects. That makes this a
// query with a reporting side effect, which is why it needs the suppression
// below.

///|
/// The single value an instruction produced.
///
/// An instruction that left no value, or several, is not an expression, and
/// this says so and recovers with `Error` poison -- so a caller that asked in
/// vain still has something to carry on with.
///
/// Reported ONCE per rendered position and count. One node is legitimately
/// asked by several consumers -- a call's callee twice, a labelled block as
/// both value and statement -- and nested value-less expressions share a start
/// column (`a.m().m()`, both halves value-less), so a full-span key would let
/// two identical reports print at the same place. Keying on what the reader
/// actually sees -- the start column and the count -- keeps a genuine second
/// error with a different count.
pub fn expression_type(
  ctx : @typing_env.ModuleContext,
  annotation : @typing_env.InferredAnnotation,
) -> @infer.Cell[@infer.InferredType] {
  let (types, location) = annotation
  if types.length() == 1 {
    return types[0]
  }
  let key = (location.start.cnum, types.length())
  if !ctx.not_expression_reported.contains(key) {
    ctx.not_expression_reported[key] = ()
    // An unresolved label in this function makes the value shape unreliable: a
    // block whose only value delivery was the unresolved branch legitimately
    // computes nothing, and saying so would anchor a derived error away from
    // the unbound label.
    if !ctx.unresolved_label.val {
      not_an_expression(ctx.diagnostics, location, types.length())
    }
  }
  @infer.Cell::make(@infer.InferredType::Error)
}

///|
/// The type of a literal, from its spelling alone.
///
/// These are the arms of the instruction match that need nothing but the token:
/// no operands, no name to resolve, no recursion. They commit only as far as
/// the spelling requires, which is what lets `1` become an `i64` where one is
/// wanted and an `f32` where one is.
pub fn literal_type(
  desc : @ast.InstrDesc[@basic.Location],
) -> @infer.InferredType? {
  match desc {
    // A character is its code point, which is an i32 and nothing else.
    Char(_) => Some(Valtype(@infer.i32_valtype))
    Int(s) => Some(int_literal_lattice(s))
    Float(s) => Some(float_literal_lattice(s))
    // A bare `null` is the null reference: it belongs to every reference type
    // and picks one from whatever it is used as.
    Null => Some(Null)
    _ => None
  }
}
