// The instruction dispatcher.
//
// Ported from `instruction` / `toplevel_instruction` in
// wax/src/lib-wax/typing.ml.
//
// This is where everything the last several files built gets used: the operand
// stack, the name tables, block inference, the branch frames. One arm per AST
// constructor, and there are seventy-one of them.
//
// It is being built incrementally, and the match is TOTAL from the start. An
// arm that is not written yet does not fall through silently -- it recurses
// into its children, so they are still annotated, and TALLIES itself under its
// constructor name. `Checker::unported` is that tally, and it is the burn-down
// number for the rest of this stage. A silent fallback here would be the same
// mistake as the vendored encoder's `_ => 0x00`, which hid 256 instructions
// until it was removed.

///|
/// One run of the checker over one function body.
pub struct Checker {
  ctx : @typing_env.ModuleContext
  ops : Operands
  /// Constructors reached that have no arm yet, and how often. Empty when the
  /// dispatcher is complete.
  unported : Map[String, Int]
}

///|
pub fn Checker::new(ctx : @typing_env.ModuleContext, ops : Operands) -> Checker {
  { ctx, ops, unported: Map([]) }
}

///|
/// Note that a constructor has no arm yet.
fn Checker::tally(self : Checker, name : String) -> Unit {
  self.unported[name] = self.unported.get(name).unwrap_or(0) + 1
}

///|
/// The unported constructors, most frequent first, for a report.
pub fn Checker::gaps(self : Checker) -> Array[(String, Int)] {
  let out : Array[(String, Int)] = []
  for name, count in self.unported {
    out.push((name, count))
  }
  out.sort_by((a, b) => {
    if a.1 != b.1 {
      b.1 - a.1
    } else if a.0 < b.0 {
      -1
    } else {
      1
    }
  })
  out
}

///|
/// The annotation an instruction carries once checked: the values it leaves on
/// the stack, and its span.
fn annotate(
  types : Array[@infer.Cell[@infer.InferredType]],
  location : @basic.Location,
) -> @typing_env.InferredAnnotation {
  (types, location)
}

///|
/// Check one instruction in STATEMENT position, returning the typed node.
///
/// Statement position is the general case: the instruction may leave any number
/// of values, including none. Expression position is the special one, and goes
/// through `expression_type` to insist on exactly one.
pub fn Checker::statement(
  self : Checker,
  i : @ast.Instr[@basic.Location],
) -> @ast.Instr[@typing_env.InferredAnnotation] {
  let loc = i.info
  let ctx = self.ctx
  match i.desc {
    // --- Values that need nothing but their own token ---
    Int(_) | Float(_) | Char(_) | Null => {
      let ty = @infer.Cell::make(literal_type(i.desc).unwrap())
      self.ops.push(Some(loc), ty)
      self.rebuild(i, [ty])
    }

    // --- Statements that leave nothing ---
    Nop => self.rebuild(i, [])
    Unreachable => {
      // Everything after this is dead code, and the polymorphic stack is how
      // the rest of the checker knows it.
      self.ops.set_unreachable()
      self.rebuild(i, [])
    }

    // --- Reading a variable ---
    Get(idx) => {
      let ty = type_get(ctx, idx)
      self.ops.push(Some(loc), ty)
      self.rebuild(i, [ty])
    }

    // --- A hole: a value the surrounding call will supply ---
    Hole => {
      let batch : Ref[MissingBatch?] = @ref.new(None)
      let ty = self.ops.pop_any(batch, 0, 1)
      report_missing_hole(self.ops, ctx.diagnostics, loc, ty)
      self.ops.push(Some(loc), ty)
      self.rebuild(i, [ty])
    }

    // --- A qualified intrinsic name outside a call ---
    Path(ns, name) => {
      intrinsic_not_called(ctx.diagnostics, loc, ns.name, name.name)
      let ty = @infer.Cell::make(@infer.InferredType::Error)
      self.ops.push(Some(loc), ty)
      self.rebuild(i, [ty])
    }

    // --- A labelled argument anywhere but a memory access ---
    Labelled(_, e) => {
      labelled_argument_not_allowed(ctx.diagnostics, loc)
      // Recover by checking the payload in place, so one misplaced label does
      // not lose the expression it labelled.
      let e_ = self.statement(e)
      self.rebuild_labelled(i, e_)
    }

    // --- A plain sequence: each in turn, the last one's values are the
    // sequence's ---
    Sequence(l) => {
      let checked : Array[@ast.Instr[@typing_env.InferredAnnotation]] = []
      let mut types : Array[@infer.Cell[@infer.InferredType]] = []
      for s in l {
        let c = self.statement(s)
        types = c.info.0
        checked.push(c)
      }
      {
        desc: Sequence(checked),
        info: annotate(types, loc),
        hints: i.hints,
        expected: i.expected,
      }
    }

    // --- The block constructs ---
    Block(label~, typ~, block~) =>
      self.block_construct(i, label, typ, block, loop_=false)
    Loop(label~, typ~, block~) =>
      self.block_construct(i, label, typ, block, loop_=true)
    If(label~, typ~, cond~, if_block~, else_block~) => {
      // The condition is checked FIRST, on the enclosing stack, because it is
      // consumed before the block is entered -- it is not part of the block's
      // parameters.
      let cond_ = self.statement(cond)
      check_subtype(
        ctx.type_context.subtyping_info(),
        ctx.diagnostics,
        cond.info,
        expression_type(ctx, cond_.info),
        @infer.valtype_cell(@infer.i32_valtype),
      )
      guard self.signature_of(typ) is Some((params, results)) else {
        return self.poisoned(i)
      }
      self.ops.pop_args(
        ctx.type_context.subtyping_info(),
        ctx.diagnostics,
        Input,
        loc,
        params,
      )
      let then_ = self.body(loc, label, params, results, results, if_block.desc)
      let else_ = match else_block {
        Some(b) => {
          let checked = self.body(loc, label, params, results, results, b.desc)
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
          // With no `else` the false path falls straight through, delivering
          // what it was given. Sound only when the parameters already are the
          // results.
          if !missing_else_ok(
              ctx.type_context.subtyping_info(),
              params,
              results,
            ) {
            if_without_else(ctx.diagnostics, loc)
          }
          None
        }
      }
      self.ops.push_results(loc, results)
      {
        desc: If(
          label~,
          typ~,
          cond=cond_,
          if_block={ desc: then_, info: if_block.info },
          else_block=else_,
        ),
        info: annotate(results, loc),
        hints: i.hints,
        expected: i.expected,
      }
    }

    // --- The branch family ---
    Br(label, operand) => {
      let params = branch_target(ctx, label)
      // An unbound label was already reported by `branch_target`, and its empty
      // parameter list is not a real arity -- checking against it would anchor
      // derived errors here rather than at the unbound name.
      let bound = label_in_scope(ctx, label)
      let checked = match operand {
        Some(e) => {
          let c = self.statement(e)
          if bound {
            check_subtypes(
              ctx.type_context.subtyping_info(),
              ctx.diagnostics,
              e.info,
              c.info.0,
              params,
            )
          }
          Some(c)
        }
        None => {
          if bound && !params.is_empty() {
            value_count_mismatch(
              ctx.diagnostics,
              loc,
              expected=params.length(),
              provided=0,
            )
          }
          None
        }
      }
      // Control never falls out of a `br`, so everything after it is dead.
      self.ops.set_unreachable()
      {
        desc: Br(label, checked),
        info: annotate([], loc),
        hints: i.hints,
        expected: i.expected,
      }
    }
    BrIf(label, operand) => {
      let c = self.statement(operand)
      let (cond_ty, delivered) = self.split_on_last(operand.info, c.info.0)
      check_subtype(
        ctx.type_context.subtyping_info(),
        ctx.diagnostics,
        operand.info,
        cond_ty,
        @infer.valtype_cell(@infer.i32_valtype),
      )
      // A `br_if` does not end the block: it delivers when taken and falls
      // through when not, so the values it leaves are what the fall-through
      // sees. `deliver_to_branch_target` is what records them as pass-through
      // exits, which have to match the target EXACTLY.
      let result = if label_in_scope(ctx, label) {
        deliver_to_branch_target(
          ctx.type_context.subtyping_info(),
          ctx.diagnostics,
          operand.info,
          delivered,
          branch_target(ctx, label),
        )
      } else {
        delivered
      }
      {
        desc: BrIf(label, c),
        info: annotate(result, loc),
        hints: i.hints,
        expected: i.expected,
      }
    }
    BrTable(labels, operand) => {
      let c = self.statement(operand)
      let (index_ty, delivered) = self.split_on_last(operand.info, c.info.0)
      check_subtype(
        ctx.type_context.subtyping_info(),
        ctx.diagnostics,
        operand.info,
        index_ty,
        @infer.valtype_cell(@infer.i32_valtype),
      )
      // Every target is resolved, so an unbound one reports at its own span and
      // each occurrence marks its label used. Only the BOUND ones impose a
      // shape.
      let bound : Array[Array[@infer.Cell[@infer.InferredType]]] = []
      for label in labels {
        let params = branch_target(ctx, label)
        if label_in_scope(ctx, label) {
          bound.push(params)
        }
      }
      if !bound.is_empty() {
        // How many values the `br_table` provides is ONE fact about the
        // instruction, so it is checked once against the first bound target's
        // arity. Checking it per target would repeat an identical report for
        // every one of them.
        if delivered.length() != bound[0].length() {
          value_count_mismatch(
            ctx.diagnostics,
            loc,
            expected=bound[0].length(),
            provided=delivered.length(),
          )
        }
        // Checked without PINNING: one set of values is checked against every
        // target, so resolving a polymorphic value against the first target's
        // type would wrongly reject a later, differently typed one.
        for params in bound {
          if params.length() == delivered.length() {
            check_subtypes(
              ctx.type_context.subtyping_info(),
              ctx.diagnostics,
              operand.info,
              delivered,
              params,
              pin=false,
            )
          }
        }
      }
      self.ops.set_unreachable()
      {
        desc: BrTable(labels, c),
        info: annotate([], loc),
        hints: i.hints,
        expected: i.expected,
      }
    }

    // --- Leaving the function ---
    Return(operand) => {
      let checked = match operand {
        Some(e) => {
          let c = self.statement(e)
          check_subtypes(
            ctx.type_context.subtyping_info(),
            ctx.diagnostics,
            e.info,
            c.info.0,
            ctx.return_types,
          )
          Some(c)
        }
        None => {
          if !ctx.return_types.is_empty() {
            value_count_mismatch(
              ctx.diagnostics,
              loc,
              expected=ctx.return_types.length(),
              provided=0,
            )
          }
          None
        }
      }
      self.ops.set_unreachable()
      {
        desc: Return(checked),
        info: annotate([], loc),
        hints: i.hints,
        expected: i.expected,
      }
    }

    // --- Raising ---
    Throw(tag, args) => {
      let checked : Array[@ast.Instr[@typing_env.InferredAnnotation]] = []
      for a in args {
        checked.push(self.statement(a))
      }
      if find(ctx.tags, ctx.diagnostics, tag) is Some(ft) {
        // A tag describes what is thrown, and a throw does not return, so there
        // is nothing for a result to be.
        if !ft.results.is_empty() {
          tag_with_results(ctx.diagnostics, tag.loc)
        }
        let want : Array[@infer.Cell[@infer.InferredType]] = []
        let mut ok = true
        for p in ft.params {
          match internalize(ctx.type_context, ctx.diagnostics, p.desc.1) {
            Some(c) => want.push(c)
            None => ok = false
          }
        }
        if ok {
          // An argument may itself produce several values -- a multi-result
          // call -- so the FLATTENED values are what is checked, each against
          // the tag parameter it lines up with and at its own argument's span.
          let provided = flatten_operands(
            checked.map(c => (c.info.0, c.info.1)),
          )
          if provided.length() != want.length() {
            operand_count_mismatch(
              ctx.diagnostics,
              tag.loc,
              expected=want.length(),
              provided=provided.length(),
            )
          } else {
            for k, v in provided {
              check_subtype(
                ctx.type_context.subtyping_info(),
                ctx.diagnostics,
                v.1,
                v.0,
                want[k],
              )
            }
          }
        }
      }
      self.ops.set_unreachable()
      {
        desc: Throw(tag, checked),
        info: annotate([], loc),
        hints: i.hints,
        expected: i.expected,
      }
    }
    ThrowRef(e) => {
      let c = self.statement(e)
      check_subtype(
        ctx.type_context.subtyping_info(),
        ctx.diagnostics,
        e.info,
        expression_type(ctx, c.info),
        @infer.valtype_cell(@typing_env.ref_none_valtype(nullable=true)),
      )
      self.ops.set_unreachable()
      {
        desc: ThrowRef(c),
        info: annotate([], loc),
        hints: i.hints,
        expected: i.expected,
      }
    }

    // --- Choosing between two values ---
    Select(cond, a, b) => {
      // Typed in EMISSION order: the two branch values, then the condition,
      // because a `select` pops the condition last.
      let a_ = self.statement(a)
      let b_ = self.statement(b)
      let cond_ = self.statement(cond)
      check_subtype(
        ctx.type_context.subtyping_info(),
        ctx.diagnostics,
        cond.info,
        expression_type(ctx, cond_.info),
        @infer.valtype_cell(@infer.i32_valtype),
      )
      let ty1 = expression_type(ctx, a_.info)
      let ty2 = expression_type(ctx, b_.info)
      // A select's two branch values join exactly as the values reaching a
      // block's exit do, so this is the same fold -- including the pinning of a
      // flexible literal against whatever it is chosen alongside.
      let ty = match join_value_types(ty1, ty2, (_, _) => None) {
        Some(r) => r
        None => {
          select_type_mismatch(ctx.diagnostics, loc, a.info, b.info, ty1, ty2)
          @infer.Cell::make(@infer.InferredType::Error)
        }
      }
      self.ops.push(Some(loc), ty)
      {
        desc: Select(cond_, a_, b_),
        info: annotate([ty], loc),
        hints: i.hints,
        expected: i.expected,
      }
    }

    // --- Arithmetic ---
    BinOpI(op, a, b) => {
      let a_ = self.statement(a)
      let b_ = self.statement(b)
      let ty1 = expression_type(ctx, a_.info)
      let ty2 = expression_type(ctx, b_.info)
      // Snapshotted BEFORE `type_binop`, which unifies an `Error` operand onto
      // the other's type as recovery and so erases the poison.
      let poisoned = ty1.get() is Error || ty2.get() is Error
      let ty = type_binop(
        ctx.type_context.subtyping_info(),
        ctx.diagnostics,
        op,
        ty1,
        ty2,
      )
      // An operand that already failed poisons the RESULT. The arms above treat
      // `Error` like `Unknown` on purpose, so the operand cells still get a
      // usable recovery type -- but the value this produces derives from a
      // reported failure, and a consumer must not report about it again.
      let ty = if poisoned {
        @infer.Cell::make(@infer.InferredType::Error)
      } else {
        ty
      }
      self.ops.push(Some(loc), ty)
      {
        desc: BinOpI(op, a_, b_),
        info: annotate([ty], loc),
        hints: i.hints,
        expected: i.expected,
      }
    }
    UnOpI(op, e) => {
      let e_ = self.statement(e)
      let typ = expression_type(ctx, e_.info)
      let poisoned = typ.get() is Error
      let ty = type_unop(ctx.diagnostics, op, e.info, typ)
      let ty = if poisoned {
        @infer.Cell::make(@infer.InferredType::Error)
      } else {
        ty
      }
      self.ops.push(Some(loc), ty)
      {
        desc: UnOpI(op, e_),
        info: annotate([ty], loc),
        hints: i.hints,
        expected: i.expected,
      }
    }

    // --- Everything else: not written yet ---
    _ => {
      self.tally(constructor_name(i.desc))
      self.placeholder(i)
    }
  }
}

///|
/// Rebuild a leaf node with its annotation.
fn Checker::rebuild(
  self : Checker,
  i : @ast.Instr[@basic.Location],
  types : Array[@infer.Cell[@infer.InferredType]],
) -> @ast.Instr[@typing_env.InferredAnnotation] {
  ignore(self)
  {
    desc: i.desc.map_desc(
      instr=_ => abort("a leaf node has no sub-instructions"),
      block=_ => abort("a leaf node has no blocks"),
    ),
    info: annotate(types, i.info),
    hints: i.hints,
    expected: i.expected,
  }
}

///|
/// Rebuild a `Labelled` around an already-checked payload.
fn Checker::rebuild_labelled(
  self : Checker,
  i : @ast.Instr[@basic.Location],
  payload : @ast.Instr[@typing_env.InferredAnnotation],
) -> @ast.Instr[@typing_env.InferredAnnotation] {
  ignore(self)
  guard i.desc is Labelled(l, _) else {
    abort("rebuild_labelled on something else")
  }
  {
    desc: Labelled(l, payload),
    info: annotate(payload.info.0, i.info),
    hints: i.hints,
    expected: i.expected,
  }
}

///|
/// An arm with no implementation yet: annotate the children, and leave this
/// node's own values unknown.
///
/// The children are still walked, so a missing arm costs the annotations of the
/// node itself and nothing below it. What it does NOT do is guess: an empty
/// annotation says "this produced nothing we know of", which is what it is.
fn Checker::placeholder(
  self : Checker,
  i : @ast.Instr[@basic.Location],
) -> @ast.Instr[@typing_env.InferredAnnotation] {
  {
    desc: i.desc.map_desc(instr=s => self.statement(s), block=b => {
      b.map(s => self.statement(s))
    }),
    info: annotate([], i.info),
    hints: i.hints,
    expected: i.expected,
  }
}

///|
/// The constructor's name, for the burn-down tally.
///
/// Spelled out rather than derived, because the tally is read by a human
/// deciding what to write next and the AST's own debug rendering would carry
/// the whole subtree with it.
pub fn constructor_name(d : @ast.InstrDesc[@basic.Location]) -> String {
  match d {
    Block(..) => "Block"
    Loop(..) => "Loop"
    While(..) => "While"
    If(..) => "If"
    TryTable(..) => "TryTable"
    Try(..) => "Try"
    TryCatch(..) => "TryCatch"
    Unreachable => "Unreachable"
    Nop => "Nop"
    Hole => "Hole"
    Null => "Null"
    Get(_) => "Get"
    Path(_, _) => "Path"
    Set(_, _, _) => "Set"
    Tee(_, _) => "Tee"
    Call(_, _) => "Call"
    TailCall(_, _) => "TailCall"
    Labelled(_, _) => "Labelled"
    Char(_) => "Char"
    Str(_, _) => "Str"
    Int(_) => "Int"
    Float(_) => "Float"
    Cast(_, _) => "Cast"
    CastDesc(_, _, _) => "CastDesc"
    Test(_, _) => "Test"
    NonNull(_) => "NonNull"
    Struct(_, _) => "Struct"
    StructDefault(_) => "StructDefault"
    StructDesc(_, _) => "StructDesc"
    StructDefaultDesc(_) => "StructDefaultDesc"
    StructGet(_, _) => "StructGet"
    GetDescriptor(_) => "GetDescriptor"
    StructSet(_, _, _) => "StructSet"
    Array(_, _, _) => "Array"
    ArrayDefault(_, _) => "ArrayDefault"
    ArrayFixed(_, _) => "ArrayFixed"
    ArraySegment(_, _, _, _) => "ArraySegment"
    ArrayGet(_, _) => "ArrayGet"
    ArraySet(_, _, _) => "ArraySet"
    BinOpI(_, _, _) => "BinOp"
    UnOpI(_, _) => "UnOp"
    Let(_, _) => "Let"
    Br(_, _) => "Br"
    BrIf(_, _) => "BrIf"
    BrTable(_, _) => "BrTable"
    Dispatch(..) => "Dispatch"
    Match(..) => "Match"
    BrOnNull(_, _) => "BrOnNull"
    BrOnNonNull(_, _) => "BrOnNonNull"
    BrOnCast(_, _, _) => "BrOnCast"
    BrOnCastFail(_, _, _) => "BrOnCastFail"
    BrOnCastDescEq(_, _, _, _) => "BrOnCastDescEq"
    BrOnCastDescEqFail(_, _, _, _) => "BrOnCastDescEqFail"
    Throw(_, _) => "Throw"
    ThrowRef(_) => "ThrowRef"
    ContNew(_, _) => "ContNew"
    ContBind(_, _, _) => "ContBind"
    Suspend(_, _) => "Suspend"
    Resume(_, _, _) => "Resume"
    ResumeThrow(_, _, _, _) => "ResumeThrow"
    ResumeThrowRef(_, _, _) => "ResumeThrowRef"
    Switch(_, _, _) => "Switch"
    On(_, _) => "On"
    Return(_) => "Return"
    Sequence(_) => "Sequence"
    Select(_, _, _) => "Select"
    IfAnnotation(..) => "IfAnnotation"
  }
}

///|
/// A block's declared shape, or `None` when it did not resolve.
fn Checker::signature_of(
  self : Checker,
  typ : @ast.FuncType,
) -> (
  Array[@infer.Cell[@infer.InferredType]],
  Array[@infer.Cell[@infer.InferredType]],
)? {
  block_signature(self.ctx.type_context, self.ctx.diagnostics, typ)
}

///|
/// Check a block's body and hand back the typed instructions.
///
/// The body is collected through a captured array rather than returned, because
/// `checked_block` takes a `() -> Unit`: what it wraps the body IN -- the fresh
/// stack, the control frame, the output check -- is the same whatever the body
/// produces, so threading a result through it would only obscure that.
fn Checker::body(
  self : Checker,
  location : @basic.Location,
  label : @ast.Ident?,
  params : Array[@infer.Cell[@infer.InferredType]],
  results : Array[@infer.Cell[@infer.InferredType]],
  branch_target : Array[@infer.Cell[@infer.InferredType]],
  instrs : Array[@ast.Instr[@basic.Location]],
) -> Array[@ast.Instr[@typing_env.InferredAnnotation]] {
  let checked : Array[@ast.Instr[@typing_env.InferredAnnotation]] = []
  checked_block(
    self.ctx,
    self.ops,
    location,
    label,
    params,
    results,
    branch_target,
    () => {
      for s in instrs {
        checked.push(self.statement(s))
      }
    },
  )
  checked
}

///|
/// A `block` or a `loop`, which differ in exactly one thing.
///
/// A `br` to a BLOCK's label jumps to its end and delivers its results; a `br`
/// to a LOOP's label jumps to its top and delivers its parameters. That is the
/// only difference between them here, and it is the `branch_target` argument.
fn Checker::block_construct(
  self : Checker,
  i : @ast.Instr[@basic.Location],
  label : @ast.Ident?,
  typ : @ast.FuncType,
  block : @basic.Annotated[Array[@ast.Instr[@basic.Location]], @basic.Location],
  loop_~ : Bool,
) -> @ast.Instr[@typing_env.InferredAnnotation] {
  let ctx = self.ctx
  let loc = i.info
  guard self.signature_of(typ) is Some((params, results)) else {
    return self.poisoned(i)
  }
  // The parameters come off the ENCLOSING stack here; `checked_block` puts them
  // back on the block's own.
  self.ops.pop_args(
    ctx.type_context.subtyping_info(),
    ctx.diagnostics,
    Input,
    loc,
    params,
  )
  let branch_target = if loop_ { params } else { results }
  let checked = self.body(
    loc,
    label,
    params,
    results,
    branch_target,
    block.desc,
  )
  self.ops.push_results(loc, results)
  let body = (
    { desc: checked, info: block.info } :
    @basic.Annotated[
      Array[@ast.Instr[@typing_env.InferredAnnotation]],
      @basic.Location,
    ])
  {
    desc: if loop_ {
      Loop(label~, typ~, block=body)
    } else {
      Block(label~, typ~, block=body)
    },
    info: annotate(results, loc),
    hints: i.hints,
    expected: i.expected,
  }
}

///|
/// Recover from a block whose declared shape did not resolve.
///
/// The body is still walked, so its instructions are annotated, but the failure
/// was already reported by the resolver and checking the body against a shape
/// we do not have would only invent complaints. Pushing `Error` poisons the
/// stack, which is what keeps the enclosing scope quiet too.
fn Checker::poisoned(
  self : Checker,
  i : @ast.Instr[@basic.Location],
) -> @ast.Instr[@typing_env.InferredAnnotation] {
  let ty = @infer.Cell::make(@infer.InferredType::Error)
  let node = self.placeholder(i)
  self.ops.push(Some(i.info), ty)
  { ..node, info: annotate([ty], i.info) }
}

///|
/// Split an annotation into its last value and the rest.
///
/// The branch forms that take a condition take it LAST -- `br_if $l (v, cond)`
/// -- because that is the order the values are pushed in, and the condition is
/// the one on top. Everything below it is what the branch delivers.
fn Checker::split_on_last(
  self : Checker,
  location : @basic.Location,
  types : Array[@infer.Cell[@infer.InferredType]],
) -> (@infer.Cell[@infer.InferredType], Array[@infer.Cell[@infer.InferredType]]) {
  if types.is_empty() {
    operand_count_mismatch(
      self.ctx.diagnostics,
      location,
      expected=1,
      provided=0,
    )
    return (@infer.Cell::make(@infer.InferredType::Error), [])
  }
  (types[types.length() - 1], types[0:types.length() - 1].to_owned())
}
