// Inferring a block's result from what reaches its exit.
//
// Ported from wax/src/lib-wax/typing.ml.
//
// This is the other end of the machinery `join.mbt` finishes. A block whose
// result type is being inferred gets a `Collecting` cell instead of a concrete
// one: every value checked against it is RECORDED rather than unified, and the
// recordings are folded into one type once the body is typed.
//
// Three things reach a block's exit and all three land in the same place: the
// fall-through, each `br` to the block's label, and -- for a `try` -- each
// caught value. `subtype` records the branches, because a branch checks its
// value against the label's result; this file records the fall-through, which
// nothing checks against anything and so has to be taken off the stack by hand.

///|
/// A block's declared single result as a cell, or `None` when there is no
/// single result to speak of.
///
/// A block with several results is never inferred -- inference is for the forms
/// that carry at most one -- so anything but a lone result answers `None`.
pub fn declared_result(
  ctx : @typing_env.TypeContext,
  diagnostics : @diagnostic.Context,
  typ : @ast.FuncType,
) -> @infer.Cell[@infer.InferredType]? {
  if typ.results.length() == 1 {
    internalize(ctx, diagnostics, typ.results[0])
  } else {
    None
  }
}

///|
/// A fresh `Collecting` result cell and the record behind it.
///
/// `declared` is the annotation under test -- what a wasm-to-Wax conversion
/// wrote, which inference is deciding whether to keep -- or `None` when the
/// source omitted it. `needed` is preset when the annotation is already known
/// to be load-bearing.
pub fn fresh_collecting(
  declared : @infer.Cell[@infer.InferredType]?,
  needed? : Bool = false,
) -> (@infer.Collecting, @infer.Cell[@infer.InferredType]) {
  let cs : @infer.Collecting = { collected: [], exacts: [], declared, needed }
  (cs, @infer.Cell::make(Collecting(cs)))
}

///|
/// Whether a block's result should be inferred in expression position.
///
/// Only the parameterless, at-most-one-result forms qualify: a block with
/// parameters takes them off the stack, and expression position has no stack to
/// take them from. Beyond that, either the annotation was omitted -- a re-parse
/// of one that was dropped, which must be re-inferred to write back -- or
/// `simplify` is converting from wasm, where a redundant annotation is exactly
/// what inference exists to remove.
pub fn infer_block_applies(
  ctx : @typing_env.ModuleContext,
  typ : @ast.FuncType,
) -> Bool {
  typ.params.is_empty() &&
  (typ.results.is_empty() || (ctx.simplify && typ.results.length() == 1))
}

///|
/// Take the fall-through off the stack and record it as an exit.
///
/// The four cases are four different things, and collapsing any two of them
/// loses a diagnostic:
///
///   * One value on an empty base is the ordinary fall-through. Consume it, so
///     the leftover report does not also complain about it.
///   * One value on an UNREACHABLE base is a dead fall-through -- a value
///     pushed after a `br`, say. It is still recorded, and the base stays
///     unreachable, exactly as a check-position `pop_args` would leave it.
///   * A reachable exit delivering NOTHING while some branch delivered a value
///     means the block yields a result its own exit does not produce. The
///     lowering would emit a block whose declared result the body never leaves,
///     so it is reported here -- an inferred result must be delivered by every
///     exit, just as a declared one is. An unreachable exit needs no value:
///     nothing reaches the exit that way.
///   * Anything else is left alone, for the leftover report to speak about.
pub fn collect_exit(
  ops : Operands,
  cs : @infer.Collecting,
  diagnostics : @diagnostic.Context,
  location : @basic.Location,
) -> Unit {
  match ops.stack {
    Cons(loc, tv, Empty) => {
      cs.collected.push((loc, tv))
      ops.stack = Empty
    }
    Cons(loc, tv, Unreachable) | Cons(loc, tv, Poisoned) => {
      cs.collected.push((loc, tv))
      ops.stack = Unreachable
    }
    Empty =>
      if !cs.collected.is_empty() {
        // Anchored at the block's closing token, as every other output
        // underflow is.
        short_stack(diagnostics, Output, loc_last_char(location), 0, 1)
      }
    Unreachable | Poisoned | Cons(_, _, _) => ()
  }
}

///|
/// Type one block body against a shared `Collecting` result cell, recording
/// every value that reaches its exit.
///
/// The label is bound to `r`, so a `br` to it records its value; `r` is also
/// the body's result type, so a trailing nested block is synthesized and its
/// value collected rather than typed as a void statement and lost.
///
/// `check_body` is the instruction checker, passed in rather than called
/// directly: an `if` runs this once per branch with the SAME cell, which is how
/// both branches' exits come to be joined together.
pub fn collect_into(
  ctx : @typing_env.ModuleContext,
  ops : Operands,
  location : @basic.Location,
  label : @ast.Ident?,
  cs : @infer.Collecting,
  r : @infer.Cell[@infer.InferredType],
  check_body : () -> Unit,
) -> Unit {
  with_empty_stack(ops, ctx.diagnostics, location, () => {
    ctx.with_frame(@typing_env.ControlFrame::new([r], label~), check_body)
    // Outside the frame: the fall-through is not a branch to the label, and by
    // here the label is out of scope anyway.
    collect_exit(ops, cs, ctx.diagnostics, location)
  })
}

///|
/// Fold what was collected into the block's inferred result.
///
/// `None` when nothing reached the exit -- a void body, or one that always
/// diverges. Either way the block produces no value, which is a different thing
/// from producing one nobody can name.
pub fn infer_result(
  ctx : @typing_env.ModuleContext,
  location : @basic.Location,
  cs : @infer.Collecting,
  lub : ValLub,
) -> @infer.Cell[@infer.InferredType]? {
  join_collected(ctx.diagnostics, location, cs.collected, lub)
}
