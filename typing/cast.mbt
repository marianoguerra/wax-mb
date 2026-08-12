// What a reference cast can and cannot do.
//
// Ported from `lint_ref_cast` in wax/src/lib-wax/typing.ml.
//
// Under single-inheritance subtyping two heap types share a value only when one
// is a subtype of the other. So unrelated types make a cast ALWAYS TRAP and a
// test ALWAYS FALSE -- unless a shared `null` slips through both -- while an
// operand that already has the target type makes the cast REDUNDANT. Both are
// worth saying, and they are different claims with different fixes.

///|
/// Whether a heap type is the bottom of its hierarchy.
///
/// A bottom reference has no values, so a cast FROM one is not a mistake: it is
/// how a value that stands for nothing gets a type at all.
pub fn is_bottom_heaptype(h : @wasm_types.HeapType[@ast.Ident]) -> Bool {
  match h {
    None_ | NoFunc | NoExtern | NoExn | NoCont => true
    _ => false
  }
}

///|
/// A span reduced to the pair of offsets that identify it.
fn span_key(l : @basic.Location) -> (Int, Int) {
  (l.start.cnum, l.end.cnum)
}

///|
/// Report what a reference cast or test does before it is even run.
///
/// Only the INNERMOST always-trapping cast of a chain is reported. A cast over
/// a value that can never be produced is unreachable, and whatever it says
/// merely follows from the inner verdict -- the fix belongs at the inner cast.
/// The span is recorded whether or not the report came out, so a longer chain
/// stays quiet past its second cast.
///
/// Only the trapping verdict chains that way. A REDUNDANT outer cast is an
/// independent claim about the cast itself -- its target is the type the
/// operand already has, whatever that operand does at run time -- with its own
/// fix, and the wasm validator reports it on the lowered form, where a source
/// chain becomes one `ref.cast` per cast.
pub fn lint_ref_cast(
  ctx : @typing_env.ModuleContext,
  location : @basic.Location,
  is_test~ : Bool,
  operand : @infer.InferredType,
  target : @infer.InferredType,
  operand_location? : @basic.Location? = None,
) -> Unit {
  let info = ctx.type_context.subtyping_info()
  let operand_traps = match operand_location {
    Some(ol) => ctx.cast_traps_reported.contains(span_key(ol))
    None => false
  }
  if operand_traps {
    ctx.cast_traps_reported[span_key(location)] = ()
  }
  fn always_fails() -> Unit {
    ctx.cast_traps_reported[span_key(location)] = ()
    if !operand_traps {
      cast_always_fails(ctx.diagnostics, location, is_test~)
    }
  }

  match (operand, target) {
    (
      Valtype({ typ: Ref({ typ: op_src, .. }), internal: Ref(op), .. }),
      Valtype({ internal: Ref(tgt), .. }),
    ) => {
      // A cast FROM a bottom reference is load-bearing: dropping it loses the
      // type the value stands in for. A TEST deletes nothing, so a bottom
      // operand is linted there like any other -- which is also what the wasm
      // validator does, having no bottom exclusion.
      if !is_test && is_bottom_heaptype(op_src) {
        return
      }
      // `any` <-> `extern` across hierarchies is the lossless
      // `extern.convert_any` / `any.convert_extern`, not a `ref.cast`. It never
      // traps and, changing hierarchy, is never redundant -- so calling it
      // either would be a false positive.
      let in_hier = (h, top) => @type_store.heap_subtype(info, h, top)
      let bridged = (in_hier(op.typ, Any) && in_hier(tgt.typ, Extern)) ||
        (in_hier(op.typ, Extern) && in_hier(tgt.typ, Any))
      let related = @type_store.heap_subtype(info, op.typ, tgt.typ) ||
        @type_store.heap_subtype(info, tgt.typ, op.typ)
      if bridged {
        return
      }
      // Unrelated types share no value -- except `null`, which belongs to every
      // nullable reference type, so two nullable references always have that
      // one value in common.
      if !related && !(op.nullable && tgt.nullable) {
        always_fails()
      } else if @type_store.ref_subtype(info, op, tgt) {
        redundant_cast(ctx.diagnostics, location, is_test~)
      }
    }
    (
      Valtype({ typ: Ref({ typ: op_src, .. }), internal: Ref(op), .. }),
      Valtype({ internal: I32 | I64, .. }),
    ) =>
      // `ref as iN` extracts an i31 payload, lowering to a `ref.cast (ref i31)`
      // and then an `i31.get`. An `any`-hierarchy reference that can never BE
      // an i31 -- a struct or an array, rather than any/eq/i31 -- makes that
      // inner cast always trap, exactly as the validator reports on the lowered
      // form.
      if !is_test &&
        !is_bottom_heaptype(op_src) &&
        @type_store.heap_subtype(info, op.typ, Any) &&
        !(@type_store.heap_subtype(info, op.typ, I31) ||
        @type_store.heap_subtype(info, I31, op.typ)) {
        always_fails()
      }
    _ => ()
  }
}

///|
/// Whether a heap type is a continuation.
///
/// Continuations form their own hierarchy with no surface cast syntax, so a
/// cast naming one is always a mistake.
pub fn is_cont_heaptype(
  ctx : @typing_env.TypeContext,
  t : @wasm_types.HeapType[@ast.Ident],
) -> Bool {
  match t {
    Cont | NoCont => true
    Type(n) | Exact(n) =>
      match ctx.types.find_no_mark(n.name) {
        Some((_, s)) => s.typ is Cont(_)
        None => false
      }
    _ => false
  }
}

///|
/// The two types a conditional cast produces: what the operand is re-typed as,
/// and the RESIDUAL left when the cast does not apply.
///
/// The residual is computed from the SOURCE the code generator will emit --
/// `lub(target, operand)` -- and not from the operand's own type. Those differ
/// exactly when the operand and target are unrelated, and then the operand's
/// own type gives a residual NARROWER than the emitted instruction delivers, so
/// the block being branched to would infer a type too narrow to accept what
/// actually arrives. Wasm derives the residual from the instruction's
/// immediates, so this has to as well.
pub fn conditional_cast_types(
  ctx : @typing_env.ModuleContext,
  location : @basic.Location,
  operand : @infer.Cell[@infer.InferredType],
  target : @wasm_types.RefType[@ast.Ident],
) -> (@infer.Cell[@infer.InferredType], @infer.Cell[@infer.InferredType])? {
  let tc = ctx.type_context
  fn internal(
    v : @wasm_types.ValType[@ast.Ident],
  ) -> @infer.Cell[@infer.InferredType]? {
    internalize(tc, ctx.diagnostics, v)
  }

  match operand.get() {
    Valtype({ typ: Ref(actual), .. }) => {
      let source = match val_lub(tc, Ref(target), Ref(actual)) {
        Some(t) => t
        None => {
          // Different hierarchies share no value, so no cast between them can
          // ever apply.
          invalid_cast(ctx.diagnostics, location, operand)
          @wasm_types.ValType::Ref(target)
        }
      }
      let residual = match source {
        Ref(lub) => @wasm_types.ValType::Ref(diff_ref_type(lub, target))
        _ => @wasm_types.ValType::Ref(diff_ref_type(actual, target))
      }
      guard internal(source) is Some(a) && internal(residual) is Some(b) else {
        return None
      }
      Some((a, b))
    }
    // A polymorphic operand: the code generator recovers the source AS the cast
    // target, so the residual is `target \ target`. Not `Unknown` -- a residual
    // is always a reference -- and not the bottom either, or a chained cast
    // would recover a source that disagrees with this one.
    Unknown | UnknownRef => {
      guard internal(Ref(diff_ref_type(target, target))) is Some(b) else {
        return None
      }
      Some((operand, b))
    }
    Error => Some((operand, @infer.Cell::make(@infer.InferredType::Error)))
    // A bare `null` carries no type wider than the target, so the generator
    // emits the source as the target made nullable. The residual has to follow
    // from THOSE immediates: typing it as the `&none` bottom instead would
    // accept programs whose emitted wasm the validator rejects.
    Null => {
      let source : @wasm_types.RefType[@ast.Ident] = {
        nullable: true,
        typ: target.typ,
      }
      guard internal(Ref(source)) is Some(a) &&
        internal(Ref(diff_ref_type(source, target))) is Some(b) else {
        return None
      }
      Some((a, b))
    }
    _ => {
      expected_ref(ctx.diagnostics, location)
      None
    }
  }
}
