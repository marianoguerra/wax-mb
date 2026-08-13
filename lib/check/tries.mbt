// The three `try` forms, factored out of the dispatcher.
//
// Ported from wax/src/lib-wax/typing.ml.
//
// They live here rather than inline because each is typed against a RESULT that
// does not always come from its own annotation. In statement position it does;
// in check position the context supplies it; and under inference it is a
// `Collecting` cell that records what reaches the exit instead of constraining
// it. The three forms are otherwise unchanged by which of those it is, which is
// exactly why the result is a parameter and not read from `typ` inside.

///|
/// A raw `try_table`: a body, and catches that branch to labels OUTSIDE it.
///
/// The catches are checked after the body has closed its frame, and that is not
/// a detail: a catch branches to a label in the ENCLOSING scope, never to the
/// try's own, so checking them inside the frame's lifetime would resolve the
/// wrong labels.
fn Checker::trytable_node(
  self : Checker,
  i : @ast.Instr[@basic.Location],
  label : @ast.Ident?,
  typ : @ast.FuncType,
  catches : Array[@ast.Catch],
  block : @basic.Annotated[Array[@ast.Instr[@basic.Location]], @basic.Location],
  params : Array[@infer.Cell[@infer.InferredType]],
  results : Array[@infer.Cell[@infer.InferredType]],
) -> @ast.Instr[@typing_env.InferredAnnotation] {
  let body = self.body(i.info, label, params, results, results, block.desc)
  check_trytable_catches(self.ctx, catches)
  {
    desc: TryTable(label~, typ~, catches~, block={
      desc: body,
      info: block.info,
    }),
    info: annotate(results, i.info),
    hints: i.hints,
    expected: i.expected,
  }
}

///|
/// A structured `try`, with one handler per tag.
///
/// Each handler is a block of its own, entered on the tag's payload and
/// producing the try's results, with the try's label in scope so a `br` to it
/// exits carrying the value.
fn Checker::try_node(
  self : Checker,
  i : @ast.Instr[@basic.Location],
  label : @ast.Ident?,
  typ : @ast.FuncType,
  block : @basic.Annotated[Array[@ast.Instr[@basic.Location]], @basic.Location],
  catches : Array[
    (
      @ast.Ident,
      @basic.Annotated[Array[@ast.Instr[@basic.Location]], @basic.Location],
    ),
  ],
  catch_all : @basic.Annotated[
    Array[@ast.Instr[@basic.Location]],
    @basic.Location,
  ]?,
  params : Array[@infer.Cell[@infer.InferredType]],
  results : Array[@infer.Cell[@infer.InferredType]],
) -> @ast.Instr[@typing_env.InferredAnnotation] {
  let body = self.body(i.info, label, params, results, results, block.desc)
  let handled : Array[
    (
      @ast.Ident,
      @basic.Annotated[
        Array[@ast.Instr[@typing_env.InferredAnnotation]],
        @basic.Location,
      ],
    ),
  ] = []
  for c in catches {
    let (tag, arm) = c
    guard self.tag_payload(tag) is Some(entry) else { continue }
    // The HANDLER's own span, not the try's: its parameters are pushed there,
    // and anchoring a leftover at the try's opening would be both misleading
    // and indistinguishable from the try's own report.
    let checked = self.body(arm.info, label, entry, results, results, arm.desc)
    handled.push((tag, { desc: checked, info: arm.info }))
  }
  let all = match catch_all {
    Some(arm) => {
      let checked = self.body(arm.info, label, [], results, results, arm.desc)
      Some(
        (
          { desc: checked, info: arm.info } :
          @basic.Annotated[
            Array[@ast.Instr[@typing_env.InferredAnnotation]],
            @basic.Location,
          ]),
      )
    }
    None => None
  }
  {
    desc: Try(
      label~,
      typ~,
      block={ desc: body, info: block.info },
      catches=handled,
      catch_all=all,
    ),
    info: annotate(results, i.info),
    hints: i.hints,
    expected: i.expected,
  }
}

///|
/// A structured `try` whose arms fall through into each other.
///
/// Arm k is entered on its tag's payload and must COMPLETE with arm k+1's entry
/// stack, the last arm's completion being the try's results. That chaining is
/// the whole shape of this construct, and it is why the entries are computed for
/// every arm before any body is checked.
fn Checker::trycatch_node(
  self : Checker,
  i : @ast.Instr[@basic.Location],
  label : @ast.Ident?,
  typ : @ast.FuncType,
  block : @basic.Annotated[Array[@ast.Instr[@basic.Location]], @basic.Location],
  arms : Array[@ast.TryCatchArm[@basic.Location]],
  results : Array[@infer.Cell[@infer.InferredType]],
) -> @ast.Instr[@typing_env.InferredAnnotation] {
  let body = self.body(i.info, label, [], results, results, block.desc)
  let entries = arms.map(a => self.arm_entry(a))
  let checked : Array[@ast.TryCatchArm[@typing_env.InferredAnnotation]] = []
  for k, arm in arms {
    let exits = if k + 1 < entries.length() {
      entries[k + 1]
    } else {
      Some(results)
    }
    // A type in the chain that did not resolve was already reported; the body
    // is typed as a plain result-producing block rather than cascading.
    let (params, exit_types) = match (entries[k], exits) {
      (Some(p), Some(e)) => (p, e)
      _ => ([], results)
    }
    let arm_body = self.body(
      i.info,
      label,
      params,
      exit_types,
      results,
      arm.arm_body.desc,
    )
    checked.push({
      arm_tag: arm.arm_tag,
      arm_ref: arm.arm_ref,
      arm_types: self.arm_entry_types(arm),
      arm_body: { desc: arm_body, info: arm.arm_body.info },
    })
  }
  {
    desc: TryCatch(
      label~,
      typ~,
      block={ desc: body, info: block.info },
      arms=checked,
    ),
    info: annotate(results, i.info),
    hints: i.hints,
    expected: i.expected,
  }
}

///|
/// An arm's entry stack in SOURCE form, for the block the lowering wraps it in.
///
/// The same list `arm_entry` computes as inference cells, but written as value
/// types: the block that delivers the arm its values needs a result type, and
/// a block type is spelled, not inferred. The field is empty as parsed and
/// this is the typer filling it, which is what the AST says it is for.
fn Checker::arm_entry_types(
  self : Checker,
  arm : @ast.TryCatchArm[@basic.Location],
) -> Array[@ast.ValType] {
  let out : Array[@ast.ValType] = []
  if arm.arm_tag is Some(tag) {
    if self.ctx.tags.find_no_mark(tag.name) is Some(ft) {
      for p in ft.params {
        out.push(p.desc.1)
      }
    }
  }
  // A `&` arm is handed the exception itself, above its payload.
  if arm.arm_ref {
    out.push(Ref({ nullable: false, typ: Exn }))
  }
  out
}
