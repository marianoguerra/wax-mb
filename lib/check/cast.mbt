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

///|
/// Ground a cast's operand at the type the cast names, when it is still
/// flexible.
///
/// `1.5 as f32` is an `f32.const`, not an `f64.const` and a demote. The
/// difference is that a literal is a VALUE, not a computation: there is nothing
/// to convert, only a width to settle on, and the cast is the thing that says
/// which. Leaving it flexible makes the literal default to its own width and
/// turns the cast into a real conversion -- which rounds twice, and rounding a
/// decimal to f64 and then demoting is not always the f32 rounding of that
/// decimal.
///
/// Only the still-abstract types move. A value already committed to a width is
/// pinned, and converting it is exactly what the cast is then for.
///
/// Grounding and the VERDICT are one act, as they are in the reference: the
/// pairs a plain `as` can ground are exactly the ones it can lower, so the
/// arm that settles the operand is the arm that says yes. `false` means there
/// is no instruction for this pair -- `i32 as i64` is one, since widening an
/// integer needs a sign to name (`as i64_s`) and a plain cast cannot supply it.
///
/// Where the reference spells the rejecting side out pair by pair, this
/// defaults it: an unlisted pair is not castable. The two arms that only exist
/// to reject -- a `LargeInt` to anything but a number or an i31/extern box, and
/// a reference to a numeric type -- are kept, because they have to be reached
/// BEFORE the catch-alls below them.
pub fn value_cast(
  ctx : @typing_env.ModuleContext,
  operand : @infer.Cell[@infer.InferredType],
  target : @infer.InferredValType,
) -> Bool {
  let tc = ctx.type_context
  let info = tc.subtyping_info()
  fn ground(v : @infer.InferredValType) -> Bool {
    operand.set(Valtype(v))
    true
  }

  match (operand.get(), target.typ) {
    // An integer literal boxed as an i31 or handed to the extern hierarchy is
    // an i32: `ref.i31` takes one.
    (Number | Int, Ref({ typ: I31 | Extern, .. })) => ground(@infer.i32_valtype)
    (Number | Int, I32) => ground(@infer.i32_valtype)
    (Number | Int, I64) => ground(@infer.i64_valtype)
    // A still-flexible literal folds straight to the target float. A value
    // already committed to the other FAMILY does not: `int` to `float` needs a
    // signedness to name a `convert`, so it is a signed cast or nothing.
    (Number | Float, F32) => ground(@infer.f32_valtype)
    (Number | Float, F64) => ground(@infer.f64_valtype)
    // A literal too big for i32 is an i64; casting it to i32 wraps.
    (LargeInt, I32 | I64) => ground(@infer.i64_valtype)
    (LargeInt, F32) => ground(@infer.f32_valtype)
    (LargeInt, F64) => ground(@infer.f64_valtype)
    (LargeInt, Ref({ typ: I31 | Extern, .. })) => ground(@infer.i64_valtype)
    // Not a number, and not the i31/extern box: nothing to fold it into.
    (LargeInt, _) => false
    // `null` is a value of every nullable reference type; pin it at the top of
    // the target's hierarchy so the code generator has one to emit.
    (Null, Ref({ typ: h, .. })) => {
      if hierarchy_top(tc, h) is Some(top) {
        let t : @wasm_types.ValType[@ast.Ident] = Ref({
          nullable: true,
          typ: top,
        })
        if internalize_valtype(tc, ctx.diagnostics, t) is Some(v) {
          operand.set(Valtype(v))
        }
      }
      true
    }
    // Same width, or a width change a plain cast names on its own: float to
    // float is demote/promote, and i64 to i32 is a wrap.
    (Valtype({ internal: F32 | F64, .. }), F32 | F64)
    | (Valtype({ internal: I32 | I64, .. }), I32)
    | (Valtype({ internal: I64, .. }), I64)
    | (Valtype({ internal: V128, .. }), V128) => true
    // `i32 as &i31` is `ref.i31`, and `as &extern` appends `extern.convert_any`;
    // an i64 source wraps to i32 first.
    (Valtype({ internal: I32 | I64, .. }), Ref({ typ: I31 | Extern, .. })) =>
      true
    (Valtype({ internal: Ref(op), .. }), Ref({ typ: h, .. })) => {
      fn sub(a, b : @wasm_types.ValType[@type_store.Id]) {
        @type_store.val_subtype(info, a, b)
      }

      fn nullable_top(
        t : @wasm_types.HeapType[@ast.Ident],
      ) -> @wasm_types.ValType[@type_store.Id]? {
        internalize_valtype(
          tc,
          ctx.diagnostics,
          Ref({ nullable: true, typ: t }),
        ).map(v => v.internal)
      }

      // Within one hierarchy every cast is a `ref.cast`, valid as long as the
      // operand is under the target's top -- the cast itself narrows.
      let within = match hierarchy_top(tc, h) {
        Some(top) =>
          match nullable_top(top) {
            Some(t) => sub(Ref(op), t)
            // An unresolved target names no hierarchy to be outside of.
            None => true
          }
        None => true
      }
      if within {
        return true
      }
      // Across the `any`/`extern` divide the conversion is lossless
      // (`any.convert_extern` / `extern.convert_any`), followed by a `ref.cast`
      // to the concrete target -- so only hierarchy membership is asked here,
      // and against a NULLABLE reference whatever the target's nullability,
      // since the `ref.cast` is what checks for null.
      let in_any = match nullable_top(Any) {
        Some(t) => sub(Ref(op), t)
        None => false
      }
      let in_extern = match nullable_top(Extern) {
        Some(t) => sub(Ref(op), t)
        None => false
      }
      match h {
        Extern => in_any
        Any => in_extern
        _ =>
          match hierarchy_top(tc, h) {
            Some(Any) => in_extern
            Some(Extern) => in_any
            _ => false
          }
      }
    }
    // A value already known to be a REFERENCE cannot be cast to a numeric type.
    // `UnknownRef` is "some reference, heap type not yet resolved", not
    // "unknown whether a reference" -- left to the polymorphic arm below it
    // passed here and handed the code generator a cast it has no lowering for.
    (UnknownRef, I32 | I64 | F32 | F64 | V128) => false
    // A polymorphic value is a dead-code stack value that unifies with whatever
    // its block needs, and `Error` absorbs so a chain reports once.
    (Unknown | Error | UnknownRef | Collecting(_), _) => true
    _ => false
  }
}

///|
/// The same for a cast that states a signedness.
///
/// Every one of these is a real instruction -- a widen, a truncation, a
/// conversion -- so what is being settled is the SOURCE the instruction reads,
/// not the value. `n as f64_s` converts an integer, so a flexible `n` is the
/// i32 the `f64.convert_i32_s` takes; `n as i32_s` truncates a float, so a
/// flexible `n` is the f64 that `i32.trunc_f64_s` reads. The same literal
/// grounds differently under the two, and the cast is the only thing that says
/// which.
/// As for a plain cast, grounding and the verdict are one act, and the
/// rejecting side is a default rather than a list.
pub fn signed_cast(
  ctx : @typing_env.ModuleContext,
  operand : @infer.Cell[@infer.InferredType],
  target : @ast.NumType,
) -> Bool {
  let info = ctx.type_context.subtyping_info()
  fn ground(v : @infer.InferredValType) -> Bool {
    operand.set(Valtype(v))
    true
  }

  match (operand.get(), target) {
    // A packed narrow read widens: the cast fuses into the load.
    (Int8 | Int16, I32 | I64) => true
    // `i31.get` extracts an i32, which `as i64_X` widens further. Only the
    // `any` hierarchy has an i31 to get.
    (Valtype({ internal: Ref(op), .. }), I32 | I64) =>
      match
        internalize_valtype(
          ctx.type_context,
          ctx.diagnostics,
          Ref({ nullable: true, typ: Any }),
        ) {
        Some(t) => @type_store.val_subtype(info, Ref(op), t.internal)
        None => false
      }
    // As for a concrete any-hierarchy reference: `ref.cast (ref i31)` then
    // `i31.get`, which traps at run time. Pin the operand so the code
    // generator takes that path.
    (Null, I32 | I64) =>
      match
        internalize_valtype(
          ctx.type_context,
          ctx.diagnostics,
          Ref({ nullable: true, typ: Any }),
        ) {
        Some(v) => ground(v)
        None => true
      }
    (Number | Int, I64 | F32 | F64) => ground(@infer.i32_valtype)
    (LargeInt, F32 | F64) => ground(@infer.i64_valtype)
    // The only numeric-to-integer signed cast is a float truncation: there is
    // no signed integer-to-integer conversion, so the source is a float.
    (LargeInt, I32 | I64) => ground(@infer.f64_valtype)
    (Number, I32) => ground(@infer.f64_valtype)
    // A bare float literal defaults to its canonical f64, like the concrete
    // float arms below, so a truncation of one type-checks.
    (Float, I32 | I64) => ground(@infer.f64_valtype)
    // The real conversions: extend, convert, truncate.
    (Valtype({ internal: I32, .. }), I64)
    | (Valtype({ internal: I32 | I64, .. }), F32 | F64)
    | (Valtype({ internal: F32 | F64, .. }), I32 | I64) => true
    // A polymorphic reference is still a reference: `i31.get` reaches an
    // integer, and nothing reaches a float.
    (UnknownRef, I32 | I64) => true
    (UnknownRef, F32 | F64) => false
    (Unknown | Error | Collecting(_), _) => true
    // Everything else: no instruction. `i32 as i32_s` and `f64 as f32_s` are
    // the notable ones -- a signedness names an integer/float conversion, and
    // neither pair crosses the families.
    _ => false
  }
}
