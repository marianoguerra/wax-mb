// Checking an instruction in EXPRESSION position.
//
// Ported from `instruction` / `type_block_construct` / `block_contents` in
// wax/src/lib-wax/typing.ml.
//
// The checker has had two positions all along -- statement and operand -- but
// only one entry point, so a block used as a value was typed exactly as a block
// used as a statement: against its DECLARED results, which for `do { .. }` are
// none. The block then produced nothing, its body's trailing value stayed on the
// stack, and both facts were reported. That is the pair the corpus kept showing:
// "This value remains on the stack" beside "An expression is expected here.
// This instruction returns 0 values."
//
// The fix is the reference's own split. A block-like construct in expression
// position is INFERRED: its result comes from what reaches its exit rather than
// from an annotation that was never written. Everything else behaves the same in
// both positions and simply falls through to `statement`.

///|
/// Check one instruction in EXPRESSION position, returning the typed node.
///
/// Expression position is where a value is wanted. The constructs that differ
/// from statement position are exactly the block-like ones, which are inferred
/// here and not there, plus the two statements that produce nothing at all and
/// so cannot stand where a value is expected.
pub fn Checker::expression(
  self : Checker,
  i : @ast.Instr[@basic.Location],
) -> @ast.Instr[@typing_env.InferredAnnotation] {
  match i.desc {
    // A statement that yields nothing, standing where a value is wanted.
    // Reported, then recovered with a poison value so nothing below cascades.
    Nop | Unreachable => {
      not_an_expression(self.ctx.diagnostics, i.info, 0)
      self.rebuild(i, [@infer.Cell::make(@infer.InferredType::Error)])
    }
    Block(label~, typ~, block~) => {
      // An expression-position block draws nothing from a stack, so a parameter
      // has no source. Report it and carry on: the fallback supplies the
      // declared parameters anyway, so the body does not then underflow.
      if !typ.params.is_empty() {
        parameterized_block_expression(self.ctx.diagnostics, i.info)
      }
      match self.block_inference(i, label, typ, block, loop_=false) {
        Some(n) => n
        None =>
          self.block_expression_fallback(i, label, typ, block, loop_=false)
      }
    }
    Loop(label~, typ~, block~) => {
      if !typ.params.is_empty() {
        parameterized_block_expression(self.ctx.diagnostics, i.info)
      }
      match self.block_inference(i, label, typ, block, loop_=true) {
        Some(n) => n
        None => self.block_expression_fallback(i, label, typ, block, loop_=true)
      }
    }
    If(label~, typ~, cond~, if_block~, else_block~) => {
      let cond_ = self.expression(cond)
      check_subtype(
        self.ctx.type_context.subtyping_info(),
        self.ctx.diagnostics,
        cond.info,
        expression_type(self.ctx, cond_.info),
        @infer.valtype_cell(@infer.i32_valtype),
      )
      if !typ.params.is_empty() {
        parameterized_block_expression(self.ctx.diagnostics, i.info)
      }
      match self.if_inference(i, label, typ, cond_, if_block, else_block) {
        Some(n) => n
        None =>
          self.if_expression_fallback(
            i, label, typ, cond_, if_block, else_block,
          )
      }
    }
    // A `dispatch` or `match` is checked against its LOWERING, and the position
    // decides where that lowering runs. As a statement it runs in the enclosing
    // stack, so a value its trailing arm leaves belongs to the enclosing block;
    // as an expression the construct is a value on its own, so it runs isolated
    // and anything left over is its own to answer for.
    Dispatch(..) | Match(..) =>
      with_empty_stack(self.ops, self.ctx.diagnostics, i.info, () => {
        self.statement(i)
      })
    // Everything else reads the same in both positions.
    _ => self.statement(i)
  }
}

///|
/// Infer a block's result from the values that reach its exit.
///
/// `None` when inference does not apply -- the block has parameters, or it
/// declares a result and `simplify` is not asking for the annotation to be
/// re-derived. The caller then falls back to the annotated path.
///
/// The `loop_` flag is the one difference between the two forms, and it is the
/// same one as everywhere else: a `br` to a LOOP re-enters at its top, so a
/// loop's value is only its fall-through, while a `br` to a BLOCK leaves it and
/// so delivers a value that must join with the fall-through.
fn Checker::block_inference(
  self : Checker,
  i : @ast.Instr[@basic.Location],
  label : @ast.Ident?,
  typ : @ast.FuncType,
  block : @basic.Annotated[Array[@ast.Instr[@basic.Location]], @basic.Location],
  loop_~ : Bool,
) -> @ast.Instr[@typing_env.InferredAnnotation]? {
  self.infer_synthesized(i, typ, (cs, r) => {
    let body = self.collected_body(i.info, label, cs, r, block.desc, loop_~)
    t => {
      if loop_ {
        @ast.InstrDesc::Loop(label~, typ=t, block={
          desc: body,
          info: block.info,
        })
      } else {
        @ast.InstrDesc::Block(label~, typ=t, block={
          desc: body,
          info: block.info,
        })
      }
    }
  })
}

///|
/// Infer an `if`'s result by typing BOTH branches against one shared cell.
///
/// That sharing is the whole mechanism: each branch records what reaches its own
/// exit into the same record, and the join at the end is what makes the two
/// agree. With no `else` there is nothing to join and no second exit, so
/// inference does not apply.
fn Checker::if_inference(
  self : Checker,
  i : @ast.Instr[@basic.Location],
  label : @ast.Ident?,
  typ : @ast.FuncType,
  cond : @ast.Instr[@typing_env.InferredAnnotation],
  if_block : @basic.Annotated[
    Array[@ast.Instr[@basic.Location]],
    @basic.Location,
  ],
  else_block : @basic.Annotated[
    Array[@ast.Instr[@basic.Location]],
    @basic.Location,
  ]?,
) -> @ast.Instr[@typing_env.InferredAnnotation]? {
  guard else_block is Some(eb) else { return None }
  self.infer_synthesized(i, typ, (cs, r) => {
    let then_ = self.collected_body(
      i.info,
      label,
      cs,
      r,
      if_block.desc,
      loop_=false,
    )
    let else_ = self.collected_body(i.info, label, cs, r, eb.desc, loop_=false)
    t => {
      @ast.InstrDesc::If(
        label~,
        typ=t,
        cond~,
        if_block={ desc: then_, info: if_block.info },
        else_block=Some({ desc: else_, info: eb.info }),
      )
    }
  })
}

///|
/// Type one body against a shared `Collecting` cell and hand back the typed
/// instructions.
///
/// `collect_into` takes a `() -> Unit`, so the body comes out through a captured
/// array -- the same reason `Checker::body` does it that way.
fn Checker::collected_body(
  self : Checker,
  location : @basic.Location,
  label : @ast.Ident?,
  cs : @infer.Collecting,
  r : @infer.Cell[@infer.InferredType],
  instrs : Array[@ast.Instr[@basic.Location]],
  loop_~ : Bool,
) -> Array[@ast.Instr[@typing_env.InferredAnnotation]] {
  let out : Array[@ast.Instr[@typing_env.InferredAnnotation]] = []
  // A `br` to a loop's label re-enters at its top with the loop's parameters --
  // none, since inference only applies to a parameterless block -- so it
  // delivers nothing to the result. Every other form's label is its exit.
  let branch_target : Array[@infer.Cell[@infer.InferredType]]? = if loop_ {
    Some([])
  } else {
    None
  }
  collect_into(
    self.ctx,
    self.ops,
    location,
    label,
    cs,
    r,
    () => {
      for c in self.block_contents([r], instrs) {
        out.push(c)
      }
    },
    branch_target~,
  )
  out
}

///|
/// The shared shape of every inferred block: a fresh `Collecting` cell, the body
/// typed against it, then the join and the write-back.
///
/// `type_body` types the body -- its whole effect is on `cs` -- and returns the
/// rebuild closure, which needs the FINALIZED function type and so cannot run
/// until the join is done.
fn Checker::infer_synthesized(
  self : Checker,
  i : @ast.Instr[@basic.Location],
  typ : @ast.FuncType,
  type_body : (@infer.Collecting, @infer.Cell[@infer.InferredType]) -> (
    @ast.FuncType,
  ) -> @ast.InstrDesc[@typing_env.InferredAnnotation],
) -> @ast.Instr[@typing_env.InferredAnnotation]? {
  guard infer_block_applies(self.ctx, typ) else { return None }
  let (cs, r) = fresh_collecting(
    declared_result(self.ctx.type_context, self.ctx.diagnostics, typ),
  )
  let rebuild = type_body(cs, r)
  // Snapshotted BEFORE the join, which resolves the cells it folds: the natural
  // types are what each exit would be on its own, and that is what decides
  // whether a written annotation is load-bearing.
  let natural = collected_natural(cs.collected)
  let inferred = infer_result(
    self.ctx,
    i.info,
    cs,
    inferred_lub(self.ctx.type_context, self.ctx.diagnostics),
  )
  let (results, typ_) = finalize_inferred(
    self.ctx,
    typ,
    inferred,
    needed=cs.needed,
    exacts=cs.exacts,
    natural~,
    location=Some(i.info),
  )
  Some({
    desc: rebuild(typ_),
    info: annotate(results, i.info),
    hints: i.hints,
    expected: i.expected,
  })
}

///|
/// A block with parameters, or one whose annotation inference is not re-deriving:
/// check the body against the declared shape.
///
/// Unlike the statement-position form this does NOT pop the parameters off the
/// enclosing stack -- expression position has no stack to pop them from. They
/// were reported as an error above; supplying them to the body anyway is
/// recovery, and it keeps a parameterized block from also reporting an underflow
/// for every parameter it was promised.
fn Checker::block_expression_fallback(
  self : Checker,
  i : @ast.Instr[@basic.Location],
  label : @ast.Ident?,
  typ : @ast.FuncType,
  block : @basic.Annotated[Array[@ast.Instr[@basic.Location]], @basic.Location],
  loop_~ : Bool,
) -> @ast.Instr[@typing_env.InferredAnnotation] {
  guard self.signature_of(typ) is Some((params, results)) else {
    return self.poisoned(i)
  }
  let branch_target = if loop_ { params } else { results }
  let checked = self.body(
    i.info,
    label,
    params,
    results,
    branch_target,
    block.desc,
  )
  let body : @basic.Annotated[
    Array[@ast.Instr[@typing_env.InferredAnnotation]],
    @basic.Location,
  ] = { desc: checked, info: block.info }
  {
    desc: if loop_ {
      Loop(label~, typ~, block=body)
    } else {
      Block(label~, typ~, block=body)
    },
    info: annotate(results, i.info),
    hints: i.hints,
    expected: i.expected,
  }
}

///|
/// The annotated path for an expression-position `if`: both branches against the
/// declared results, with the condition already typed.
fn Checker::if_expression_fallback(
  self : Checker,
  i : @ast.Instr[@basic.Location],
  label : @ast.Ident?,
  typ : @ast.FuncType,
  cond : @ast.Instr[@typing_env.InferredAnnotation],
  if_block : @basic.Annotated[
    Array[@ast.Instr[@basic.Location]],
    @basic.Location,
  ],
  else_block : @basic.Annotated[
    Array[@ast.Instr[@basic.Location]],
    @basic.Location,
  ]?,
) -> @ast.Instr[@typing_env.InferredAnnotation] {
  guard self.signature_of(typ) is Some((params, results)) else {
    return self.poisoned(i)
  }
  let then_ = self.body(i.info, label, params, results, results, if_block.desc)
  let else_ = match else_block {
    Some(b) => {
      let checked = self.body(i.info, label, params, results, results, b.desc)
      Some(
        (
          { desc: checked, info: b.info } :
          @basic.Annotated[
            Array[@ast.Instr[@typing_env.InferredAnnotation]],
            @basic.Location,
          ]),
      )
    }
    None => {
      if !missing_else_ok(
          self.ctx.type_context.subtyping_info(),
          params,
          results,
        ) {
        if_without_else(self.ctx.diagnostics, i.info)
      }
      None
    }
  }
  {
    desc: If(
      label~,
      typ~,
      cond~,
      if_block={ desc: then_, info: if_block.info },
      else_block=else_,
    ),
    info: annotate(results, i.info),
    hints: i.hints,
    expected: i.expected,
  }
}

///|
/// Whether a trailing instruction should be routed through the block's result
/// rather than typed as a plain statement.
///
/// Two different answers, and they are not the same question. A CONSTRUCTION
/// needs the surrounding type to pin its own -- an unnamed struct, an array, a
/// string, a `null` cast -- so it must be checked against the result. A NESTED
/// BLOCK resolves its own type, so it is synthesized instead, and its natural
/// type is what joins. Anything else -- a plain statement, a parameterized
/// block, a scalar `?:` -- is neither, and stays on the statement path.
pub fn classify_trailing(
  ctx : @typing_env.ModuleContext,
  desc : @ast.InstrDesc[@basic.Location],
) -> (Bool, Bool) {
  match desc {
    Struct(_, fields) =>
      match infer_struct_by_fields(ctx, fields.map(f => f.0)) {
        Some(_) => (false, true)
        None => (true, false)
      }
    // A descriptor construction takes its type from the descriptor, not from
    // the context, and carries no droppable type name -- so it resolves itself
    // whether or not its fields are unique, unlike the plain struct above.
    StructDesc(_, _) | StructDefaultDesc(_) => (false, true)
    StructDefault(_)
    | Array(_, _, _)
    | ArrayDefault(_, _)
    | ArrayFixed(_, _)
    | ArraySegment(_, _, _, _)
    | Str(_, _) => (true, false)
    If(typ~, ..)
    | Block(typ~, ..)
    | Loop(typ~, ..)
    | TryTable(typ~, ..)
    | Try(typ~, ..)
    | TryCatch(typ~, ..) =>
      if typ.params.is_empty() {
        (false, true)
      } else {
        (false, false)
      }
    Cast(e, _) => (is_null_initializer(e), false)
    // A select needs the context exactly when a branch does; it is not itself a
    // self-resolving nested block.
    Select(_, a, b) =>
      (
        classify_trailing(ctx, a.desc).0 || classify_trailing(ctx, b.desc).0,
        false,
      )
    _ => (false, false)
  }
}

///|
/// Whether an instruction is a bare `null`, however many casts are wrapped
/// around it.
pub fn is_null_initializer(i : @ast.Instr[@basic.Location]) -> Bool {
  match i.desc {
    Null => true
    Cast(e, _) => is_null_initializer(e)
    _ => false
  }
}

///|
/// Check a run of instructions as a BLOCK BODY, routing the trailing one that
/// produces the block's value.
///
/// The difference from `statements` is the last instruction, and only when the
/// block has a single result that is still being inferred and nothing has yet
/// reached the stack. Then that instruction IS the block's value, and it is
/// typed in expression position so it can resolve its own type -- a nested block
/// runs its own inference rather than being typed as a void statement and losing
/// what it produced.
///
/// When the result is CONCRETE the trailing instruction is checked against it
/// instead, so a construction there can take the block's declared result as its
/// type. What then goes on the stack is the RESULT, not the value's own type:
/// `check` has already compared the two and reported any mismatch, and pushing
/// the value's type would have the block's own output check report it a second
/// time.
///
/// When the stack already carries something, an earlier instruction produced the
/// value and the trailing one is an ordinary statement.
fn Checker::block_contents(
  self : Checker,
  results : Array[@infer.Cell[@infer.InferredType]],
  instrs : Array[@ast.Instr[@basic.Location]],
) -> Array[@ast.Instr[@typing_env.InferredAnnotation]] {
  let out : Array[@ast.Instr[@typing_env.InferredAnnotation]] = []
  let n = instrs.length()
  for k in 0..<n {
    let s = instrs[k]
    let routed = k == n - 1 &&
      results.length() == 1 &&
      self.ops.stack is Empty &&
      (match classify_trailing(self.ctx, s.desc) {
        (false, false) => false
        _ => true
      })
    if routed && is_inferring(results[0]) {
      let c = self.expression(s)
      self.ops.push_results(s.info, c.info.0)
      out.push(c)
    } else if routed {
      let c = self.check(results[0], s)
      self.ops.push_results(s.info, results)
      out.push(c)
    } else {
      let c = self.statement(s)
      self.ops.push_results(s.info, c.info.0)
      out.push(c)
    }
  }
  out
}
