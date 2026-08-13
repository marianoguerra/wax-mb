// What a numeric literal's type is before anything constrains it.
//
// Ported from wax/src/lib-wax/typing.ml.
//
// This is the first thing in the checker that produces an annotation, and it
// produces the LEAST committed one it can. A literal's spelling says only what
// it cannot be; `subtype` and `join_value_types` decide the rest from how it is
// used. Keeping literals as raw strings through the whole front end is what
// makes that possible, and this is the function that cashes it in.

///|
/// The lattice type of a float literal.
///
/// A literal that fits an f32 stays FLEXIBLE -- it could be either width, and
/// its use decides. One that does not fit is pinned to f64 immediately, because
/// there is no choice left to make: f32 would overflow it to infinity.
pub fn float_literal_lattice(s : String) -> @infer.InferredType {
  if @number.is_float32(s) {
    Float
  } else {
    Valtype(@infer.f64_valtype)
  }
}

///|
/// The lattice type of an integer literal.
///
/// The magnitude alone rules widths out, and each exclusion is a real one:
///
///   * Over the 32-bit range it cannot be i32, so it is `LargeInt`, which
///     defaults to i64 -- not `Number`, which defaults to i32.
///   * Too big for u64 it cannot be any integer at all, so it is treated as a
///     float. Using it as an integer is then a clean type error rather than an
///     overflow in the encoder, which is where the reference used to crash.
///
/// The sign is a separate negation in the AST, so what arrives here is
/// unsigned.
pub fn int_literal_lattice(s : String) -> @infer.InferredType {
  if !@number.is_int64(s) {
    float_literal_lattice(s)
  } else if !@number.is_int32(s) {
    LargeInt
  } else {
    Number
  }
}
