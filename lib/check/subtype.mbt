// Subtyping, which is also where inference happens.
//
// Ported from wax/src/lib-wax/typing.ml.
//
// `subtype` is NOT a pure relation. When the two sides are compatible it
// UNIFIES their cells, which is how an as-yet-unconstrained literal gets pinned
// to the concrete type it was checked against. That is the whole mechanism by
// which the annotation gets filled: a literal has no width until something
// checks it against a type, and this is the something.

///|
/// The part of `t1` that `t2` does not already admit -- used to narrow a
/// nullable reference once null has been ruled out.
fn diff_ref_type(
  t1 : @wasm_types.RefType[@ast.Ident],
  t2 : @wasm_types.RefType[@ast.Ident],
) -> @wasm_types.RefType[@ast.Ident] {
  { nullable: t1.nullable && !t2.nullable, typ: t1.typ, }
}

///|
/// Is one resolved storage type a subtype of another?
///
/// A packed type is a subtype of itself alone: `i8` and `i16` are different
/// widths, and neither is a value type.
pub fn storage_subtype(
  info : @type_store.SubtypingInfo,
  ty : @wasm_types.StorageType[@type_store.Id],
  ty_ : @wasm_types.StorageType[@type_store.Id],
) -> Bool {
  match (ty, ty_) {
    (Packed(I8), Packed(I8)) | (Packed(I16), Packed(I16)) => true
    (Value(a), Value(b)) => @type_store.val_subtype(info, a, b)
    (Packed(_), Packed(_)) | (Packed(_), Value(_)) | (Value(_), Packed(_)) =>
      false
  }
}

///|
/// Is one field type a subtype of another?
///
/// A MUTABLE field is invariant: it is read and written, so it has to be a
/// subtype in both directions. An immutable one is covariant, being only read.
/// Getting this backwards is how a type system lets a caller store the wrong
/// thing through a widened reference.
pub fn field_subtype(
  info : @type_store.SubtypingInfo,
  ty : @wasm_types.FieldType[@type_store.Id],
  ty_ : @wasm_types.FieldType[@type_store.Id],
) -> Bool {
  ty.mut_ == ty_.mut_ &&
  storage_subtype(info, ty.typ, ty_.typ) &&
  (!ty.mut_ || storage_subtype(info, ty_.typ, ty.typ))
}

///|
/// Is this the result cell of a block whose type is still being inferred?
fn is_inferring(ty : @infer.Cell[@infer.InferredType]) -> Bool {
  ty.get() is Collecting(_)
}

///|
/// The type a value takes when it passes through a branch to `ty`.
///
/// It continues on the stack typed as the TARGET's result. When the target is a
/// block still being inferred but with a declared result -- an annotation under
/// test, or the context type in expression position -- that declared result is
/// the right answer, so resolve to it: the pass-through must be typed as the
/// block's result rather than its own, possibly narrower, operand, which would
/// be unsound.
///
/// With no declared result the `Collecting` cell would leak out as a value, so
/// the caller keeps the operand's own type instead.
fn resolve_declared(
  ty : @infer.Cell[@infer.InferredType],
) -> @infer.Cell[@infer.InferredType] {
  for cur = ty {
    match cur.get() {
      Collecting({ declared: Some(d), .. }) => continue d
      _ => break cur
    }
  }
}

///|
/// Is the inferred type `ty` a subtype of the expected type `ty_`, unifying
/// them if so?
///
/// The asymmetry is the point. `ty` is what was inferred and may still be
/// flexible; `ty_` is expected, and comes from a declaration, an annotation or
/// an instruction signature -- so it is always concrete, or a block result
/// being inferred. That is why several shapes are impossible on the right and
/// abort rather than returning false: reaching them means a caller passed an
/// expected type that no declaration could have produced, which is a bug here
/// rather than an error in the program being checked.
///
/// `pin` is what a `br_table` turns off. Its one value is checked against
/// several targets of legitimately different types, so pinning it to the first
/// would wrongly reject the rest.
pub fn subtype(
  info : @type_store.SubtypingInfo,
  ty : @infer.Cell[@infer.InferredType],
  ty_ : @infer.Cell[@infer.InferredType],
  location? : @basic.Location? = None,
  pin? : Bool = true,
) -> Bool {
  let ity = ty.get()
  let ity_ = ty_.get()
  match (ity, ity_) {
    // The expected side is a block result still being inferred. Record what
    // reaches the block's exit, to be joined later.
    (_, Collecting(st)) =>
      match st.declared {
        Some(d) => {
          // An annotation is under test. The check below may resolve `ty`, so
          // snapshot its natural type first -- the keep-or-drop decision
          // compares that PRE-validation type against the annotation. Then
          // validate per delivery, so a `br` carrying the wrong type is
          // reported at its own site rather than once, generically, at the join.
          st.collected.push((location, @infer.Cell::make(ity)))
          subtype(info, ty, d, location~, pin~)
        }
        None => {
          // Nothing here resolves `ty`, so record the LIVE cell. When the join
          // later settles the block's result to a concrete width, that
          // propagates back to a flexible literal reaching the exit -- without
          // which the literal keeps its default width and the lowering emits,
          // say, an f64 constant as the fall-through of an f32-typed block.
          st.collected.push((location, ty))
          true
        }
      }
    // A `Collecting` cell is never a real value type, so on the left it behaves
    // like `Unknown`.
    (Collecting(_), _) => true
    (Valtype(a), Valtype(b)) =>
      @type_store.val_subtype(info, a.internal, b.internal)
    // A flexible literal never appears as the EXPECTED type: an expected type
    // comes from a declaration, an annotation or a signature.
    (_, Number | Int | LargeInt | Float) =>
      abort("a flexible numeric type cannot be an expected type")
    (Null, Null) => {
      ty.merge(ty_, ity)
      true
    }
    // What each flexible literal will accept. `LargeInt` is a literal too big
    // for i32, so it is never i32 -- it takes i64, f32 or f64.
    (Number, Valtype({ internal: I32 | I64 | F32 | F64, .. }))
    | (Int, Valtype({ internal: I32 | I64, .. }))
    | (Float, Valtype({ internal: F32 | F64, .. }))
    | (LargeInt, Valtype({ internal: I64 | F32 | F64, .. }))
    | (Null, Valtype({ internal: Ref({ nullable: true, .. }), .. })) => {
      ty.merge(ty_, ity_)
      true
    }
    (Null, Valtype(_))
    | (Valtype(_), Null)
    | (Number, Null | Valtype(_))
    | (Int, Null | Valtype(_))
    | (Float, Null | Valtype(_))
    | (LargeInt, Null | Valtype(_)) => false
    // A packed type is never on the stack, so it is neither side of this.
    (Int8 | Int16, _) | (_, Int8 | Int16) => false
    (Unknown, Valtype(_) as t) => {
      // A polymorphic value -- a hole taken off the stack of unreachable code
      // -- genuinely takes whatever concrete type consumes it. Pin it, so the
      // lowering sees a definite type rather than nothing, which it could only
      // emit as `unreachable`, dropping the enclosing instruction.
      if pin {
        ty.set(t)
      }
      true
    }
    (Unknown | Error, _) => true
    (UnknownRef, Valtype({ internal: Ref(_), .. }) as t) => {
      // The bottom reference is a subtype of every reference. Pin it to the
      // hierarchy it was checked against, so it resolves there rather than to
      // the hierarchy-less default `&none`.
      if pin {
        ty.set(t)
      }
      true
    }
    (_, Unknown | Error | UnknownRef) =>
      abort("an unknown type cannot be an expected type")
    (UnknownRef, _) => false
  }
}
