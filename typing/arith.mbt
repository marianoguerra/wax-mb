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

///|
/// The type `eqref`, which is what `==` and `!=` require of a reference.
///
/// Both lower to `ref.eq` -- `!=` is the same instruction negated -- so both
/// take the same operands.
fn eqref() -> @wasm_types.ValType[@type_store.Id] {
  Ref({ nullable: true, typ: Eq })
}

///|
/// Whether a concrete type is something `==` / `!=` accepts.
fn comparable(
  info : @type_store.SubtypingInfo,
  ty : @infer.InferredType,
) -> Bool {
  match ty {
    Valtype({ internal: Ref(_) as r, .. }) =>
      @type_store.val_subtype(info, r, eqref())
    Valtype({ internal: I32 | I64 | F32 | F64, .. })
    | Number
    | Int
    | LargeInt
    | Float
    // The bottom reference IS an `eqref`, so `ref.eq` accepts it.
    | UnknownRef => true
    _ => false
  }
}

///|
/// Type a binary operator from its two operand types.
///
/// Split on how many operands are still ABSTRACT -- `Unknown` from dead code,
/// `Error` from an already-reported failure. With both abstract there is
/// nothing to validate, so the two cells are merged to the operator's own
/// default and a result is still produced. With one abstract it is merged onto
/// the known operand's type and that one is validated. With both concrete there
/// is only validation to do.
///
/// The merging is why this mutates rather than returning a verdict: an operand
/// left `Unknown` would be lowered at the i32 default while the result was
/// pinned to another width, which is an incoherent instruction.
pub fn type_binop(
  info : @type_store.SubtypingInfo,
  diagnostics : @diagnostic.Context,
  op : @basic.Annotated[@ast.BinOp, @basic.Location],
  ty1 : @infer.Cell[@infer.InferredType],
  ty2 : @infer.Cell[@infer.InferredType],
) -> @infer.Cell[@infer.InferredType] {
  let location = op.info
  let i32_cell = @infer.valtype_cell(@infer.i32_valtype)
  fn mismatch() -> Unit {
    // Pointed at the OPERATOR, not the whole expression: the operands are each
    // fine on their own, and it is their combination that is not.
    binop_type_mismatch(diagnostics, location, ty1, ty2)
  }

  let a = ty1.get()
  let b = ty2.get()
  let abstract1 = a is (Unknown | Error)
  let abstract2 = b is (Unknown | Error)
  if abstract1 && abstract2 {
    return match op.desc {
      Add | Sub | Mul => {
        ty1.merge(ty2, Number)
        ty1
      }
      Div(Some(_)) | Rem(_) | And | Or | Xor | Shl | Shr(_) => {
        ty1.merge(ty2, Int)
        ty1
      }
      Eq | Ne | Lt(Some(_)) | Gt(Some(_)) | Le(Some(_)) | Ge(Some(_)) => {
        ty1.merge(ty2, Valtype(@infer.i32_valtype))
        i32_cell
      }
      Div(None) => {
        ty1.merge(ty2, Float)
        ty1
      }
      Lt(None) | Gt(None) | Le(None) | Ge(None) => {
        ty1.merge(ty2, Valtype(@infer.f32_valtype))
        i32_cell
      }
    }
  }
  if abstract1 || abstract2 {
    let typ = if abstract1 { b } else { a }
    ty1.merge(ty2, typ)
    return match op.desc {
      Eq | Ne => {
        match typ {
          // A bare `null` compared for equality is an `eqref` null.
          Null =>
            ty1.set(
              Valtype({
                typ: Ref({ nullable: true, typ: Eq }),
                internal: eqref(),
                anon_comptype: None,
              }),
            )
          _ => if !comparable(info, typ) { mismatch() }
        }
        i32_cell
      }
      Add | Sub | Mul => {
        match typ {
          Valtype({ internal: I32 | I64 | F32 | F64, .. })
          | Number
          | Int
          | LargeInt
          | Float => ()
          _ => mismatch()
        }
        ty1
      }
      Div(Some(_)) | Rem(_) | And | Or | Xor | Shl | Shr(_) =>
        check_int_bin_op(diagnostics, location, ty1, ty2)
      Div(None) => check_float_bin_op(diagnostics, location, ty1, ty2)
      Lt(Some(_)) | Gt(Some(_)) | Le(Some(_)) | Ge(Some(_)) => {
        match typ {
          Valtype({ internal: I32 | I64, .. }) | Int => ()
          Number => ty1.set(Int)
          // A signed comparison is an integer operation, so a large literal
          // must be the i64 it defaults to rather than staying float-capable.
          LargeInt => ty1.set(Valtype(@infer.i64_valtype))
          _ => mismatch()
        }
        i32_cell
      }
      Lt(None) | Gt(None) | Le(None) | Ge(None) => {
        match typ {
          Valtype({ internal: F32 | F64, .. }) | Float => ()
          // A float comparison takes a large literal AS a float: it is a
          // numeric literal, so it is float-capable.
          Number | LargeInt => ty1.set(Float)
          _ => mismatch()
        }
        i32_cell
      }
    }
  }
  match op.desc {
    Eq | Ne => {
      match (a, b) {
        (
          Valtype({ internal: Ref(_) as r1, .. }),
          Valtype({ internal: Ref(_) as r2, .. }),
        ) =>
          if !(@type_store.val_subtype(info, r1, eqref()) &&
            @type_store.val_subtype(info, r2, eqref())) {
            mismatch()
          }
        (Valtype({ internal: Ref(_) as r, .. }), Null) => {
          if !@type_store.val_subtype(info, r, eqref()) {
            mismatch()
          }
          ty1.merge(ty2, b)
        }
        (Null, Valtype({ internal: Ref(_) as r, .. })) => {
          if !@type_store.val_subtype(info, r, eqref()) {
            mismatch()
          }
          ty1.merge(ty2, b)
        }
        // `ref.eq` needs both operands `eqref`, and the bottom reference always
        // is, so only the concrete side is checked.
        (Valtype({ internal: Ref(_) as r, .. }), UnknownRef)
        | (UnknownRef, Valtype({ internal: Ref(_) as r, .. })) =>
          if !@type_store.val_subtype(info, r, eqref()) {
            mismatch()
          }
        // Two nulls compare as two bottom references, which are `eqref`.
        (UnknownRef | Null, UnknownRef | Null) => ()
        // Anything non-reference is the ordinary numeric comparison.
        _ => check_num_concrete(diagnostics, location, ty1, ty2)
      }
      i32_cell
    }
    Add | Sub | Mul => {
      check_num_concrete(diagnostics, location, ty1, ty2)
      ty1
    }
    Div(Some(_)) | Rem(_) | And | Or | Xor | Shl | Shr(_) =>
      check_int_bin_op(diagnostics, location, ty1, ty2)
    Div(None) => check_float_bin_op(diagnostics, location, ty1, ty2)
    Lt(Some(_)) | Gt(Some(_)) | Le(Some(_)) | Ge(Some(_)) => {
      let _ = check_int_bin_op(diagnostics, location, ty1, ty2)
      i32_cell
    }
    Lt(None) | Gt(None) | Le(None) | Ge(None) => {
      let _ = check_float_bin_op(diagnostics, location, ty1, ty2)
      i32_cell
    }
  }
}

///|
/// Type a unary operator from its operand's type.
///
/// The `Neg`/`Pos` result IS the operand's cell, not a fresh one, and that is
/// the whole subtlety here. Negation preserves width, so a later pin on the
/// result -- an `as f64` promote consuming it, say -- has to pin the operand
/// too. A disconnected result cell would let the operand stay `Unknown` and
/// lower at the i32 default while the result was pinned to another width: an
/// `i32.sub` annotated as an f64 negation.
pub fn type_unop(
  diagnostics : @diagnostic.Context,
  op : @basic.Annotated[@ast.UnOp, @basic.Location],
  location : @basic.Location,
  typ : @infer.Cell[@infer.InferredType],
) -> @infer.Cell[@infer.InferredType] {
  let i32_cell = @infer.valtype_cell(@infer.i32_valtype)
  match typ.get() {
    // An already-reported failure: recover without pinning the operand, which
    // has nothing to be pinned to.
    Error =>
      match op.desc {
        Not => i32_cell
        Neg | Pos => @infer.Cell::make(Number)
      }
    Unknown =>
      match op.desc {
        Not => i32_cell
        Neg | Pos => {
          typ.set(Number)
          typ
        }
      }
    _ =>
      match op.desc {
        Not => {
          match typ.get() {
            // `!` is `i32.eqz` on an integer and `ref.is_null` on a reference.
            // The bottom reference is a reference, so it takes the second
            // reading like any other.
            Valtype({ internal: I32 | I64 | Ref(_), .. })
            | Null
            | Int
            | UnknownRef => ()
            Number => typ.set(Int)
            // `!` on a large literal is `i64.eqz`, so pin it there: there is no
            // float `eqz` for it to stay float-capable for.
            LargeInt => typ.set(Valtype(@infer.i64_valtype))
            _ =>
              expression_type_mismatch(
                diagnostics,
                location,
                typ,
                @infer.Cell::make(Int),
              )
          }
          i32_cell
        }
        Neg | Pos => {
          match typ.get() {
            Valtype({ internal: I32 | I64 | F32 | F64, .. })
            | Int
            | LargeInt
            | Float
            | Number => ()
            _ =>
              expression_type_mismatch(
                diagnostics,
                location,
                typ,
                @infer.Cell::make(Number),
              )
          }
          typ
        }
      }
  }
}
