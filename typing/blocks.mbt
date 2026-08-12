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

///|
/// A block's declared parameters and results, as cells.
///
/// `None` when either fails to resolve: the block's shape is then unknown, and
/// checking its body against a shape we do not have would invent complaints.
/// The failure was already reported by the resolver.
pub fn block_signature(
  ctx : @typing_env.TypeContext,
  diagnostics : @diagnostic.Context,
  typ : @ast.FuncType,
) -> (
  Array[@infer.Cell[@infer.InferredType]],
  Array[@infer.Cell[@infer.InferredType]],
)? {
  let params : Array[@infer.Cell[@infer.InferredType]] = []
  for p in typ.params {
    guard internalize(ctx, diagnostics, p.desc.1) is Some(c) else {
      return None
    }
    params.push(c)
  }
  let results : Array[@infer.Cell[@infer.InferredType]] = []
  for r in typ.results {
    guard internalize(ctx, diagnostics, r) is Some(c) else { return None }
    results.push(c)
  }
  Some((params, results))
}

///|
/// Check a block body against a declared shape.
///
/// The counterpart of `collect_into`: that one is for a block whose result is
/// being INFERRED, this one for a block that already knows what it produces.
/// Both run the body on a fresh empty stack under a control frame; the
/// difference is what happens at the exit. Here the results are simply popped
/// and checked, because there is a declared type to check them against.
///
/// `branch_target` is the one parameter that is not always `results`, and the
/// distinction is the whole difference between a block and a loop. A `br` to a
/// block's label jumps to its END and so delivers the block's RESULTS. A `br`
/// to a loop's label jumps to its TOP and so delivers the loop's PARAMETERS --
/// it is re-entering, not leaving. Passing `results` for a loop would accept
/// branches carrying the wrong values entirely.
pub fn checked_block(
  ctx : @typing_env.ModuleContext,
  ops : Operands,
  location : @basic.Location,
  label : @ast.Ident?,
  params : Array[@infer.Cell[@infer.InferredType]],
  results : Array[@infer.Cell[@infer.InferredType]],
  branch_target : Array[@infer.Cell[@infer.InferredType]],
  check_body : () -> Unit,
) -> Unit {
  with_empty_stack(ops, ctx.diagnostics, location, () => {
    // The parameters were popped off the ENCLOSING stack by the caller; they go
    // back on the block's own, which is otherwise empty. That is what keeps a
    // block from reaching values it was not given.
    ops.push_results(location, params)
    ctx.with_frame(
      @typing_env.ControlFrame::new(branch_target, label~),
      check_body,
    )
    ops.pop_args(
      ctx.type_context.subtyping_info(),
      ctx.diagnostics,
      Output,
      location,
      results,
    )
  })
}

///|
/// Whether an `if` without an `else` is well formed.
///
/// A missing `else` means the false path falls straight through, delivering the
/// parameters it was given. That is only sound when the parameters already ARE
/// the results -- same count, each a subtype -- because otherwise the block
/// promises a value the false path never produces.
pub fn missing_else_ok(
  info : @type_store.SubtypingInfo,
  params : Array[@infer.Cell[@infer.InferredType]],
  results : Array[@infer.Cell[@infer.InferredType]],
) -> Bool {
  guard params.length() == results.length() else { return false }
  for i in 0..<params.length() {
    if !subtype(info, params[i], results[i]) {
      return false
    }
  }
  true
}
