// Joining the types that reach a block's exit.
//
// Ported from wax/src/lib-wax/typing.ml.
//
// `subtype` accumulates, on a `Collecting` cell, every value that reaches a
// block's exit -- from the fall-through, from each `br`, from each catch. This
// is where those are reduced to one type, and it is the other half of the
// inference: `subtype` pins a literal against a type it is CHECKED against,
// and this pins one against the types it is joined WITH.

///|
/// The least upper bound of two value types, for the case where both sides are
/// concrete and differ.
///
/// Passed in rather than computed here because it is the reference-hierarchy
/// lub, which needs the type table; every other case in the join is decided by
/// the flexible-literal lattice alone.
type ValLub = (@infer.InferredValType, @infer.InferredValType) -> @infer.InferredValType?

///|
/// The common type of two values reaching one exit, or `None` if they have
/// none.
///
/// Like `subtype`, this MUTATES: joining a flexible literal with a concrete
/// type pins it, and joining two flexible ones merges their cells so that
/// pinning either later pins both. Without that, a literal reaching a block's
/// exit keeps its default width and the lowering emits, say, an f64 constant as
/// the fall-through of an f32-typed block.
pub fn join_value_types(
  ty1 : @infer.Cell[@infer.InferredType],
  ty2 : @infer.Cell[@infer.InferredType],
  lub : ValLub,
) -> @infer.Cell[@infer.InferredType]? {
  let a = ty1.get()
  let b = ty2.get()
  match (a, b) {
    // `Unknown` is the universal bottom, so the other side wins -- and it is
    // PINNED to the result. A hole on the polymorphic stack of dead code
    // genuinely takes the block's result type, and a branch that also passes it
    // through needs to see the resolved width; left as `Unknown` the lowering
    // would drop the cast around it.
    (_, Unknown) => {
      ty1.merge(ty2, a)
      Some(ty1)
    }
    (Unknown, _) => {
      ty1.merge(ty2, b)
      Some(ty2)
    }
    // `Error` has been reported already, so it stays the untouched bottom --
    // pinning it would invent a type it never had.
    (_, Error) => Some(ty1)
    (Error, _) => Some(ty2)
    // Two bottom references merge, so pinning one later pins the other.
    (UnknownRef, UnknownRef) => {
      ty1.merge(ty2, UnknownRef)
      Some(ty1)
    }
    // A bottom reference joins with any other reference, which -- being a
    // supertype -- wins. Paired with a non-reference it has no common type and
    // falls through to the mismatch at the end.
    (Valtype({ internal: Ref(_), .. }) | Null, UnknownRef) => {
      ty2.set(a)
      Some(ty1)
    }
    (UnknownRef, Valtype({ internal: Ref(_), .. }) | Null) => {
      ty1.set(b)
      Some(ty2)
    }
    // Two nulls unify, so pinning one to a reference type pins the other.
    (Null, Null) => {
      ty1.merge(ty2, Null)
      Some(ty1)
    }
    // Identical concrete numeric types.
    (Valtype({ internal: I32, .. }), Valtype({ internal: I32, .. }))
    | (Valtype({ internal: I64, .. }), Valtype({ internal: I64, .. }))
    | (Valtype({ internal: F32, .. }), Valtype({ internal: F32, .. }))
    | (Valtype({ internal: F64, .. }), Valtype({ internal: F64, .. })) =>
      Some(ty2)
    // A flexible literal absorbed by whatever it is joined with.
    (Int | Number, Int | Valtype({ internal: I32 | I64, .. }))
    | (Float | Number, Float | Valtype({ internal: F32 | F64, .. }))
    | (Number, Number) => {
      ty1.merge(ty2, b)
      Some(ty2)
    }
    (Valtype({ internal: I32 | I64, .. }), Int | Number)
    | (Valtype({ internal: F32 | F64, .. }), Float | Number)
    | (Int | Float, Number) => {
      ty1.merge(ty2, a)
      Some(ty1)
    }
    // A literal too big for i32 defaults to i64 and can also be a float. Joined
    // with a committed `Int`, which is integer-only, their sole common type is
    // i64 -- so pin it there, or the join could later be coerced to a float the
    // `Int` cannot be.
    (LargeInt, Int) | (Int, LargeInt) => {
      ty1.merge(ty2, Valtype(@infer.i64_valtype))
      Some(ty1)
    }
    (LargeInt, LargeInt | Number) => {
      ty1.merge(ty2, LargeInt)
      Some(ty1)
    }
    (Number, LargeInt) => {
      ty1.merge(ty2, LargeInt)
      Some(ty2)
    }
    (LargeInt, Float | Valtype({ internal: I64 | F32 | F64, .. })) => {
      ty1.merge(ty2, b)
      Some(ty2)
    }
    (Float | Valtype({ internal: I64 | F32 | F64, .. }), LargeInt) => {
      ty1.merge(ty2, a)
      Some(ty1)
    }
    // Two concrete types that differ: the reference hierarchy decides.
    (Valtype(v1), Valtype(v2)) =>
      match lub(v1, v2) {
        Some(v) => Some(@infer.valtype_cell(v))
        None => None
      }
    // A reference joined with null widens to the nullable form of the same
    // heap type.
    (Valtype({ typ: Ref(r), .. }), Null) => {
      let widened = nullable_of(r)
      match lub(widened, widened) {
        Some(v) => {
          let cell = @infer.valtype_cell(v)
          ty2.set(cell.get())
          Some(cell)
        }
        None => None
      }
    }
    (Null, Valtype({ typ: Ref(r), .. })) => {
      let widened = nullable_of(r)
      match lub(widened, widened) {
        Some(v) => {
          let cell = @infer.valtype_cell(v)
          ty1.set(cell.get())
          Some(cell)
        }
        None => None
      }
    }
    _ => None
  }
}

///|
/// The nullable form of a reference type, as an inferred value type.
///
/// The internal side is left to `lub` to fill, since only it can resolve a
/// named heap type to a store index.
fn nullable_of(r : @wasm_types.RefType[@ast.Ident]) -> @infer.InferredValType {
  {
    typ: Ref({ nullable: true, typ: r.typ, }),
    internal: Ref({ nullable: true, typ: None_, }),
    anon_comptype: None,
  }
}

///|
/// Report the underflow behind the value a hole just consumed.
///
/// The report points at the HOLE, which is the most precise anchor a missing
/// value has -- the pop that noticed the underflow does not know how the
/// missing values are distributed across the holes that will consume them, so
/// it records a placeholder and says nothing.
///
/// One report per underflow: the batch is marked, and the fallback covers a
/// placeholder that never reached a hole because recovery dropped it.
pub fn report_missing_hole(
  ops : Operands,
  diagnostics : @diagnostic.Context,
  location : @basic.Location,
  ty : @infer.Cell[@infer.InferredType],
) -> Unit {
  let mut found : MissingBatch? = None
  let kept : Array[(@infer.Cell[@infer.InferredType], MissingBatch)] = []
  for entry in ops.missing_holes {
    // Identity, not equality: two placeholders are the same missing value only
    // if they are the same cell.
    if @infer.same_cell(entry.0, ty) {
      found = Some(entry.1)
    } else {
      kept.push(entry)
    }
  }
  guard found is Some(batch) else { return }
  ops.missing_holes.clear()
  for e in kept {
    ops.missing_holes.push(e)
  }
  if !batch.hole_reported {
    batch.hole_reported = true
    short_stack(
      diagnostics,
      Holes,
      location,
      batch.hole_actual,
      batch.hole_expected,
    )
  }
}

///|
/// Reduce everything that reached a block's exit to one type.
///
/// This is what the whole `Collecting` machinery exists for. `subtype` records
/// each delivery -- the fall-through, each `br`, each caught value -- and this
/// folds them together.
///
/// Folded in SOURCE order, which matters twice over: a mismatch names the
/// values in the order the reader wrote them, and recovery keeps the FIRST,
/// which is the one they most likely meant. Continuing with the first also
/// stops a single odd delivery from disagreeing with every subsequent one and
/// producing a complaint per exit.
pub fn join_collected(
  diagnostics : @diagnostic.Context,
  location : @basic.Location,
  collected : Array[(@basic.Location?, @infer.Cell[@infer.InferredType])],
  lub : ValLub,
) -> @infer.Cell[@infer.InferredType]? {
  if collected.is_empty() {
    return None
  }
  let (first_loc, first) = collected[0]
  // The first value's span is the one a mismatch is measured against, and it
  // does not move as the fold proceeds: every later value is compared with what
  // the fold has accumulated, which started there.
  let acc_loc = first_loc
  let mut acc = first
  for i in 1..<collected.length() {
    let (loc, ty) = collected[i]
    match join_value_types(acc, ty, lub) {
      Some(r) => acc = r
      None => {
        block_exit_type_mismatch(
          diagnostics,
          location,
          acc_loc.unwrap_or(location),
          loc.unwrap_or(location),
          acc,
          ty,
        )
        // Keep the accumulator rather than adopting the odd value: see above.
        ()
      }
    }
  }
  Some(acc)
}
