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
