// Resolving a branch to the control frame it targets.
//
// Ported from wax/src/lib-wax/typing.ml.

///|
/// The types a branch to this label delivers.
///
/// Searches the enclosing frames innermost first, so a shadowing inner label of
/// the same name wins -- which is what makes a label a lexical binding rather
/// than a module-wide name.
///
/// An unresolved label reports and yields no types. It also SETS a flag on the
/// context, and that flag is what stops the failure becoming two: a block whose
/// only value delivery was the unresolved branch legitimately computes no
/// value, and complaining about that as well would anchor a derived error away
/// from the unbound label the reader actually has to fix.
pub fn branch_target(
  ctx : @typing_env.ModuleContext,
  label : @ast.Ident,
) -> Array[@infer.Cell[@infer.InferredType]] {
  for frame in ctx.control_types {
    if frame.label is Some(l) && l.name == label.name {
      // Keyed by the LABEL DECLARATION's offset rather than its name, so a
      // shadowing inner label does not mask an unused outer one. The wasm
      // validator likewise tracks usage per control frame.
      ctx.used_labels.push(l.loc.start.cnum)
      @typing_env.record_reference(ctx.resolve_links, label.loc, [l.loc])
      return frame.results
    }
  }
  unbound_name(
    ctx.diagnostics,
    label.loc,
    "label",
    label.name,
    suggestions=label_suggestions(ctx, label.name),
  )
  ctx.unresolved_label.val = true
  []
}

///|
/// Does this label resolve to a frame in scope?
///
/// Reports nothing and records no use. It exists to tell an UNBOUND label --
/// already diagnosed -- from a legitimately void target, which otherwise look
/// the same, both delivering no types.
pub fn label_in_scope(
  ctx : @typing_env.ModuleContext,
  label : @ast.Ident,
) -> Bool {
  for frame in ctx.control_types {
    if frame.label is Some(l) && l.name == label.name {
      return true
    }
  }
  false
}

///|
/// Labels close enough to be worth suggesting.
///
/// Drawn from the frames in scope, because a label is lexical: one from a block
/// that has already closed is not a thing the author could have meant here.
fn label_suggestions(
  ctx : @typing_env.ModuleContext,
  name : String,
) -> Array[String] {
  let candidates : Array[String] = []
  for frame in ctx.control_types {
    if frame.label is Some(l) {
      candidates.push(l.name)
    }
  }
  @spell.suggest(candidates.iter(), name)
}

///|
/// Deliver the values below a `br_if` / `br_on_null` operand to the branch
/// target, and answer what they are typed as on the fall-through.
///
/// A pass-through branch is the odd one out among branches: the value is
/// delivered to the target when the branch is taken AND stays on the stack when
/// it is not. So it is typed as the target's result either way -- which makes
/// the requirement stricter than for an ordinary `br`. An ordinary delivery
/// need only be a SUBTYPE of the result. A pass-through value has to be
/// EXACTLY it, because the fall-through path will go on using it at that type.
///
/// That is what `exacts` records, and the snapshot has to be taken HERE, before
/// the delivery below pins the value: after pinning, its natural type is gone
/// and every value would look like it matched.
pub fn deliver_to_branch_target(
  info : @type_store.SubtypingInfo,
  diagnostics : @diagnostic.Context,
  location : @basic.Location,
  types : Array[@infer.Cell[@infer.InferredType]],
  params : Array[@infer.Cell[@infer.InferredType]],
) -> Array[@infer.Cell[@infer.InferredType]] {
  let same_arity = types.length() == params.length()
  if same_arity {
    for i in 0..<types.length() {
      guard params[i].get() is Collecting(cs) else { continue }
      cs.exacts.push((Some(location), @infer.Cell::make(types[i].get())))
      // A flexible literal here can still be pinned to a non-default width by
      // something downstream on re-parse, and the fall-through value would then
      // disagree with the block's inferred result. Keeping the annotation is
      // what makes the round trip stable.
      if types[i].get() is (Number | Int | LargeInt | Float) {
        cs.needed = true
      }
    }
  }
  check_subtypes(info, diagnostics, location, types, params)
  // On the fall-through the values stay typed as the target's result. When the
  // target has no declared result that cell would leak out of inference, so
  // fall back to the operands' own types.
  //
  // Guarded on arity for the same reason as the snapshot: a mismatch has been
  // reported already, and pairing unequal lengths would only crash.
  let any_inferring = params.iter().any(p => is_inferring(p))
  if any_inferring && same_arity {
    let out : Array[@infer.Cell[@infer.InferredType]] = []
    for i in 0..<types.length() {
      out.push(
        if params[i].get() is Collecting({ declared: None, .. }) {
          types[i]
        } else {
          resolve_declared(params[i])
        },
      )
    }
    out
  } else {
    params
  }
}

///|
/// Report every pass-through value whose type is not exactly the block's
/// inferred result.
///
/// Only when the result resolves to a single value type: with no standalone
/// type there is nothing to compare against, and the block has other complaints
/// already.
pub fn report_exact_mismatches(
  diagnostics : @diagnostic.Context,
  location : @basic.Location,
  result : @infer.Cell[@infer.InferredType],
  exacts : Array[(@basic.Location?, @infer.Cell[@infer.InferredType])],
) -> Unit {
  guard @typing_env.standalone_valtype(result) is Some(t) else { return }
  for e in exacts {
    let (loc, ty) = e
    if ty.get() is Valtype(v) && v.internal != t.internal {
      br_if_result_mismatch(
        diagnostics,
        location,
        loc.unwrap_or(location),
        result,
        ty,
      )
    }
  }
}
