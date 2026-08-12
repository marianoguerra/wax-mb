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
