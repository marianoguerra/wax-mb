// The numeric operators, where the literal lattice meets arithmetic.
//
// Ported from wax/src/lib-wax/typing.ml.
//
// Three rules, one per operator group: integer-only (`&`, `<<`, `/`), float-only
// (`sqrt`), and the ones that accept either (`+`, `-`, `*`, `==`). Each UNIFIES
// its operands as well as checking them -- an operator is the commonest way a
// literal acquires a width, because `x + 1` says what `1` is the moment `x` is
// known.
//
// The three differ only in what they will accept, so what is worth reading is
// where they disagree: an integer operator pins a large literal to i64 because
// the result cannot be a float, while an either-operator leaves it flexible
// because it still could be.

///|
/// Are both operands the same concrete numeric type?
fn same_concrete(a : @infer.InferredType, b : @infer.InferredType) -> Bool {
  match (a, b) {
    (Valtype({ internal: I32, .. }), Valtype({ internal: I32, .. }))
    | (Valtype({ internal: I64, .. }), Valtype({ internal: I64, .. }))
    | (Valtype({ internal: F32, .. }), Valtype({ internal: F32, .. }))
    | (Valtype({ internal: F64, .. }), Valtype({ internal: F64, .. })) => true
    _ => false
  }
}

///|
/// Check and unify the operands of an INTEGER-only operator.
///
/// Two fully flexible operands become `Int` rather than staying `Number`: the
/// operator has committed them to being integers even though it has not said
/// which width.
///
/// A large literal is pinned to i64 outright. It cannot be i32, and the result
/// of an integer operator cannot be a float, so i64 is the only type left --
/// which is exactly where this differs from the either-group rule below.
pub fn check_int_bin_op(
  diagnostics : @diagnostic.Context,
  location : @basic.Location,
  typ1 : @infer.Cell[@infer.InferredType],
  typ2 : @infer.Cell[@infer.InferredType],
) -> @infer.Cell[@infer.InferredType] {
  let a = typ1.get()
  let b = typ2.get()
  if same_concrete(a, b) {
    typ1.merge(typ2, a)
    return typ1
  }
  match (a, b) {
    (Valtype({ internal: I32 | I64, .. }) | Int, Number | Int) =>
      typ1.merge(typ2, a)
    (Number | Int, Valtype({ internal: I32 | I64, .. })) => typ1.merge(typ2, b)
    (Number, Number) => typ1.merge(typ2, Int)
    (Valtype({ internal: I64, .. }), LargeInt) => typ1.merge(typ2, a)
    (LargeInt, Valtype({ internal: I64, .. })) => typ1.merge(typ2, b)
    (LargeInt, LargeInt | Number | Int) | (Number | Int, LargeInt) =>
      typ1.merge(typ2, Valtype(@infer.i64_valtype))
    (Number, Int) => typ1.merge(typ2, Int)
    _ => binop_type_mismatch(diagnostics, location, typ1, typ2)
  }
  typ1
}

///|
/// Check and unify the operands of a FLOAT-only operator.
///
/// A large literal is taken as a float here without complaint -- the operator
/// has already ruled out every integer reading, so there is nothing to object
/// to.
pub fn check_float_bin_op(
  diagnostics : @diagnostic.Context,
  location : @basic.Location,
  typ1 : @infer.Cell[@infer.InferredType],
  typ2 : @infer.Cell[@infer.InferredType],
) -> @infer.Cell[@infer.InferredType] {
  let a = typ1.get()
  let b = typ2.get()
  if same_concrete(a, b) {
    typ1.merge(typ2, a)
    return typ1
  }
  match (a, b) {
    (Valtype({ internal: F32 | F64, .. }) | Float, Number | Float | LargeInt) =>
      typ1.merge(typ2, a)
    (Number | Float | LargeInt, Valtype({ internal: F32 | F64, .. })) =>
      typ1.merge(typ2, b)
    (Number | LargeInt, Number | Float | LargeInt) => typ1.merge(typ2, Float)
    _ => binop_type_mismatch(diagnostics, location, typ1, typ2)
  }
  typ1
}

///|
/// Check and unify the operands of an operator that accepts EITHER group --
/// `+`, `-`, `*`, `==`, `!=`.
///
/// Two fully flexible operands stay `Number`, because the operator has not
/// ruled anything out: it could still resolve either way. Any more committed
/// operand pins the pair to its group.
///
/// The instructive case is a large literal with a committed integer. The
/// integer cannot be a float and the large literal cannot be i32, so their sole
/// common type is i64 -- but with another large literal or a bare number it
/// stays `LargeInt`, because a float is still reachable. The integer-only rule
/// above pins in that case; this one does not, and the difference is exactly
/// what each operator has ruled out.
pub fn check_num_concrete(
  diagnostics : @diagnostic.Context,
  location : @basic.Location,
  ty1 : @infer.Cell[@infer.InferredType],
  ty2 : @infer.Cell[@infer.InferredType],
) -> Unit {
  let a = ty1.get()
  let b = ty2.get()
  if same_concrete(a, b) {
    return
  }
  match (a, b) {
    (Valtype({ internal: I32 | I64, .. }) | Int, Number | Int)
    | (Valtype({ internal: F32 | F64, .. }) | Float, Number | Float | LargeInt) =>
      ty1.merge(ty2, a)
    (Number | Int, Valtype({ internal: I32 | I64, .. }))
    | (Number | Float | LargeInt, Valtype({ internal: F32 | F64, .. })) =>
      ty1.merge(ty2, b)
    (Valtype({ internal: I64, .. }), LargeInt) => ty1.merge(ty2, a)
    (LargeInt, Valtype({ internal: I64, .. })) => ty1.merge(ty2, b)
    (LargeInt, Int) | (Int, LargeInt) =>
      ty1.merge(ty2, Valtype(@infer.i64_valtype))
    (LargeInt, LargeInt | Number) | (Number, LargeInt) =>
      ty1.merge(ty2, LargeInt)
    (LargeInt, Float) | (Number, Float) => ty1.merge(ty2, Float)
    (Number, Int) => ty1.merge(ty2, Int)
    (Number, Number) => ty1.merge(ty2, Number)
    _ => binop_type_mismatch(diagnostics, location, ty1, ty2)
  }
}
