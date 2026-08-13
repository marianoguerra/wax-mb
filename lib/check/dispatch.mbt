// The instruction dispatcher.
//
// Ported from `instruction` / `toplevel_instruction` in
// wax/src/lib-wax/typing.ml.
//
// This is where everything the last several files built gets used: the operand
// stack, the name tables, block inference, the branch frames. One arm per AST
// constructor, and there are seventy-one of them.
//
// It was built incrementally, and while arms were missing the match carried a
// catch-all that TALLIED each one it met rather than falling through silently
// -- the burn-down number for the stage. Every constructor now has an arm, so
// that catch-all is gone: the match is total WITHOUT one, and adding a
// constructor to the AST is a compile error here rather than a silent gap.
//
// That is the same discipline as the vendored encoder, which hid 256
// instructions behind a `_ => 0x00` until removing it made the compiler name
// them. The tally was the stand-in for a compiler that could not help while the
// match was incomplete; it is not needed once the compiler can.

///|
/// One run of the checker over one function body.
pub struct Checker {
  ctx : @typing_env.ModuleContext
  ops : Operands
  /// Lowerings whose typed form could not be peeled back to the construct they
  /// came from, and how often. Empty unless recovery from an error inside one
  /// produced a shape the lowering never emits.
  unpeeled : Map[String, Int]
}

///|
pub fn Checker::new(ctx : @typing_env.ModuleContext, ops : Operands) -> Checker {
  { ctx, ops, unpeeled: Map([]) }
}

///|
/// Note a lowering that could not be peeled back.
fn Checker::note_unpeeled(self : Checker, name : String) -> Unit {
  self.unpeeled[name] = self.unpeeled.get(name).unwrap_or(0) + 1
}

///|
/// The constructs whose lowering could not be peeled back, most frequent
/// first. Empty on well-formed input.
pub fn Checker::gaps(self : Checker) -> Array[(String, Int)] {
  let out : Array[(String, Int)] = []
  for name, count in self.unpeeled {
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
/// What a `#[targets(f: 0.73, ..)]` hint on a call needs beyond the parser's
/// check that it prefixes a call at all.
///
/// The mirror of the wasm validator's `call_targets` arm, which the checker
/// owes because `wax check` never converts: a problem only the lowering would
/// hit would otherwise pass.
///
/// Each target is resolved but NOT marked used -- naming a function in
/// advisory metadata is not a use, and marking it would keep an otherwise-dead
/// function out of the unused lint.
fn Checker::check_call_targets_hint(
  self : Checker,
  i : @ast.Instr[@basic.Location],
) -> Unit {
  guard i.hints.targets is Some(h) else { return }
  let ctx = self.ctx
  // The direct-call test, mirroring the lowering: a bare name that denotes a
  // module function and is not shadowed by a local lowers to `call`, whose
  // target is already known, so a target list says nothing.
  match i.desc {
    Call(callee, _) | TailCall(callee, _) =>
      if callee.desc is Get(name) &&
        !ctx.locals.contains(name.name) &&
        ctx.functions.find_no_mark(name.name) is Some(_) {
        call_targets_direct_call(ctx.diagnostics, h.loc)
      }
    _ => ()
  }
  let mut total = 0
  for entry in h.value {
    let (f, pct) = entry
    if ctx.locals.contains(f.name) || ctx.functions.find_no_mark(f.name) is None {
      unbound_name(ctx.diagnostics, f.loc, "function", f.name)
    }
    total = total + pct
  }
  if total > 100 {
    call_targets_over_100(ctx.diagnostics, h.loc, total)
  }
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
  self.check_call_targets_hint(i)
  match i.desc {
    // --- Values that need nothing but their own token ---
    Int(_) | Float(_) | Char(_) | Null => {
      let ty = @infer.Cell::make(literal_type(i.desc).unwrap())
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
      self.rebuild(i, [ty])
    }

    // --- A hole: a value the surrounding call will supply ---
    Hole => {
      let batch : Ref[MissingBatch?] = @ref.new(None)
      let ty = self.ops.pop_any(batch, 0, 1)
      report_missing_hole(self.ops, ctx.diagnostics, loc, ty)
      self.rebuild(i, [ty])
    }

    // --- A qualified intrinsic name outside a call ---
    Path(ns, name) => {
      intrinsic_not_called(ctx.diagnostics, loc, ns.name, name.name)
      let ty = @infer.Cell::make(@infer.InferredType::Error)
      self.rebuild(i, [ty])
    }

    // --- A labelled argument anywhere but a memory access ---
    Labelled(_, e) => {
      labelled_argument_not_allowed(ctx.diagnostics, loc)
      // Recover by checking the payload in place, so one misplaced label does
      // not lose the expression it labelled.
      let e_ = self.expression(e)
      self.rebuild_labelled(i, e_)
    }

    // --- A tuple: each element contributes ONE value, in order ---
    //
    // This is how a multi-value operand is written -- `br_if 'l (9, cond)`
    // delivers 9 and tests cond -- so the sequence produces one value per
    // element rather than only its last one's. `expression_type` is what
    // insists on the one, and reports an element that produces none or several.
    Sequence(l) => {
      // A sequence leaves its values with the LAST on top, so a run of holes
      // takes them from the top backwards: the rightmost hole gets the top,
      // and the leftmost gets the deepest. Popping them in written order would
      // hand the first hole the last value and pair every one of them with the
      // wrong expectation.
      //
      // They are resolved in a pass of their own because a hole takes a value
      // that is already there, while every other element PUSHES one -- so only
      // the holes see the incoming stack, and they see it in reverse.
      // An element that CONTAINS a hole -- the hole itself, or anything built
      // over one -- is typed in this backwards pass, and the rest afterwards
      // in written order. An element that consumes nothing does not care when
      // it is typed; one that does has to be reached before everything to its
      // left, or it takes a value meant for its neighbour.
      let taken : Map[Int, @ast.Instr[@typing_env.InferredAnnotation]] = Map([])
      for k = l.length() - 1; k >= 0; k = k - 1 {
        if contains_hole(l[k]) {
          taken[k] = self.expression(l[k])
        }
      }
      let checked : Array[@ast.Instr[@typing_env.InferredAnnotation]] = []
      let types : Array[@infer.Cell[@infer.InferredType]] = []
      for k, s in l {
        let c = match taken.get(k) {
          Some(c) => c
          None => self.expression(s)
        }
        types.push(expression_type(ctx, c.info))
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
      let cond_ = self.expression(cond)
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
        Some(e) =>
          Some(
            if bound {
              self.check_against(params, e)
            } else {
              self.expression(e)
            },
          )
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
      let c = self.expression(operand)
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
      let c = self.expression(operand)
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
        Some(e) => Some(self.check_against(ctx.return_types, e))
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
        checked.push(self.expression(a))
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
      let c = self.expression(e)
      // `throw_ref` takes the EXCEPTION OBJECT -- an `&?exn`, the thing a `&`
      // catch arm binds. It was checked against the bottom reference, which
      // only a null satisfies, so rethrowing a caught exception was rejected.
      check_subtype(
        ctx.type_context.subtyping_info(),
        ctx.diagnostics,
        e.info,
        expression_type(ctx, c.info),
        @infer.valtype_cell(@typing_env.ref_exn_valtype(nullable=true)),
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
      let a_ = self.expression(a)
      let b_ = self.expression(b)
      let cond_ = self.expression(cond)
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
      let ty = match
        join_value_types(
          ty1,
          ty2,
          inferred_lub(ctx.type_context, ctx.diagnostics),
        ) {
        Some(r) => r
        None => {
          select_type_mismatch(ctx.diagnostics, loc, a.info, b.info, ty1, ty2)
          @infer.Cell::make(@infer.InferredType::Error)
        }
      }
      {
        desc: Select(cond_, a_, b_),
        info: annotate([ty], loc),
        hints: i.hints,
        expected: i.expected,
      }
    }

    // --- Arithmetic ---
    BinOpI(op, a, b) => {
      let a_ = self.expression(a)
      let b_ = self.expression(b)
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
      if ctx.warn_unused {
        // DEFERRED: the shift lint reads the operand width off `ty`, which a
        // later context can still widen -- `1 << 40` pinned to i64 is fine.
        ctx.deferred_lints.push(() => lint_shift(ctx, op, ty, b))
        lint_division(ctx, op, b)
        lint_comparison(ctx, op, a_, b_, a, b)
      }
      // An operand that already failed poisons the RESULT. The arms above treat
      // `Error` like `Unknown` on purpose, so the operand cells still get a
      // usable recovery type -- but the value this produces derives from a
      // reported failure, and a consumer must not report about it again.
      let ty = if poisoned {
        @infer.Cell::make(@infer.InferredType::Error)
      } else {
        ty
      }
      {
        desc: BinOpI(op, a_, b_),
        info: annotate([ty], loc),
        hints: i.hints,
        expected: i.expected,
      }
    }
    UnOpI(op, e) => {
      let e_ = self.expression(e)
      let typ = expression_type(ctx, e_.info)
      let poisoned = typ.get() is Error
      let ty = type_unop(ctx.diagnostics, op, e.info, typ)
      let ty = if poisoned {
        @infer.Cell::make(@infer.InferredType::Error)
      } else {
        ty
      }
      {
        desc: UnOpI(op, e_),
        info: annotate([ty], loc),
        hints: i.hints,
        expected: i.expected,
      }
    }

    // --- Assignment ---
    Set(idx, op, value) => {
      // The target is resolved FIRST -- a pure lookup -- so the value can be
      // checked against its type. The local is marked initialized only after
      // the value is typed, so `x = x + 1` still sees its pre-assignment state.
      let resolved = resolve_variable(ctx, idx)
      let target = match resolved {
        Local(Some(v), _) | Global(_, Some(v)) => Some(@infer.valtype_cell(v))
        _ => None
      }
      let checked = match op {
        // A compound `x op= e` is checked as `x = x op e`: reading `x` requires
        // it to be initialized already, and the operator validates against its
        // type through the ordinary arithmetic path. The compound form is kept
        // in the typed AST, so it round-trips and lowers back to get/op/set.
        Some(binop) => {
          let read = type_get(ctx, idx)
          let rhs = self.expression(value)
          let ty = type_binop(
            ctx.type_context.subtyping_info(),
            ctx.diagnostics,
            binop,
            read,
            expression_type(ctx, rhs.info),
          )
          if target is Some(t) {
            check_subtype(
              ctx.type_context.subtyping_info(),
              ctx.diagnostics,
              value.info,
              ty,
              t,
            )
          }
          rhs
        }
        // A plain assignment CHECKS its value against the target's type, which
        // is what lets `xs = [| .. |]` take the target's array type rather than
        // having to name one.
        None =>
          match target {
            Some(t) => self.check(t, value)
            None => self.expression(value)
          }
      }
      // A compound assignment's desugared READ already reported an unbound name
      // at this span; reporting the write too would say it twice.
      assign_target(ctx, idx, resolved, compound=op is Some(_))
      {
        desc: Set(idx, op, checked),
        info: annotate([], loc),
        hints: i.hints,
        expected: i.expected,
      }
    }
    Tee(idx, value) => {
      let resolved = resolve_variable(ctx, idx)
      // A tee assigns AND leaves the value, so where the target has a type the
      // value is CHECKED against it -- and the tee then produces the target's
      // type, not the value's.
      let checked = match resolved {
        Local(Some(v), _) => self.check(@infer.valtype_cell(v), value)
        _ => self.expression(value)
      }
      let ty = tee_target(
        ctx,
        idx,
        resolved,
        expression_type(ctx, checked.info),
      )
      {
        desc: Tee(idx, checked),
        info: annotate([ty], loc),
        hints: i.hints,
        expected: i.expected,
      }
    }

    // --- Local binding ---
    Let(bindings, Some(init)) => {
      // A single ANNOTATED name is BIDIRECTIONAL: the initializer is CHECKED
      // against the annotation, which is what lets a construction there be
      // written without naming its type. That is then the ONLY check -- the
      // binding takes the annotated type as given rather than resolving it a
      // second time and comparing again, which said everything twice: an
      // unbound annotation, and a value that does not fit it. Several names,
      // or an unannotated one, have nothing to check against and synthesize
      // instead.
      let single_annotated = bindings.length() == 1 && bindings[0].1 is Some(_)
      let annotated = match bindings[0].1 {
        Some(t) if single_annotated =>
          internalize_valtype(ctx.type_context, ctx.diagnostics, t)
        _ => None
      }
      let checked = match annotated {
        Some(ity) => self.check(@infer.valtype_cell(ity), init)
        None => self.expression(init)
      }
      if single_annotated {
        // An annotation that did not resolve was reported where it was
        // resolved, and declares nothing: a local with no type is worse than
        // no local at all.
        if annotated is Some(ity) && bindings[0].0 is Some(name) {
          bind_local(ctx, name, Some(ity))
        }
      } else if bindings.length() == 1 {
        // One name takes the whole initializer, which must therefore be a
        // one-value expression -- `expression_type` says so if it is not.
        let ty = expression_type(ctx, checked.info)
        self.bind(init.info, bindings[0], ty)
      } else {
        // Each name takes one value off a multi-value initializer, left to
        // right: the names match the values in order.
        let values = checked.info.0
        if values.length() != bindings.length() {
          value_count_mismatch(
            ctx.diagnostics,
            init.info,
            expected=bindings.length(),
            provided=values.length(),
          )
        }
        for k, binding in bindings {
          let ty = if k < values.length() {
            values[k]
          } else {
            @infer.Cell::make(@infer.InferredType::Error)
          }
          self.bind(init.info, binding, ty)
        }
      }
      {
        desc: Let(bindings, Some(checked)),
        info: annotate([], loc),
        hints: i.hints,
        expected: i.expected,
      }
    }
    Let(bindings, None) => {
      // No initializer: each annotated name declares a local at its zero value.
      // An unannotated one has no type to take and declares nothing at all.
      for binding in bindings {
        if binding.0 is Some(name) && binding.1 is Some(typ) {
          declare_local(ctx, name, typ)
        }
      }
      {
        desc: Let(bindings, None),
        info: annotate([], loc),
        hints: i.hints,
        expected: i.expected,
      }
    }

    // --- Reading a struct field ---
    StructGet(recv, field) => {
      let recv_ = self.expression(recv)
      let ty = self.field_type_of(
        recv.info,
        expression_type(ctx, recv_.info),
        field,
      )
      {
        desc: StructGet(recv_, field),
        info: annotate([ty], loc),
        hints: i.hints,
        expected: i.expected,
      }
    }

    // --- Writing one ---
    StructSet(recv, field, value) => {
      // Emission order: the struct receiver, then the stored value.
      let recv_ = self.expression(recv)
      let declared = self.field_slot(
        recv.info,
        expression_type(ctx, recv_.info),
        field,
      )
      // Written at the UNPACKED width: a packed field takes a plain i32 and
      // narrows implicitly, unlike a read, which remembers how narrow it was.
      // Resolved BEFORE the value, so a literal stored there can take the
      // field's type rather than having to name one.
      let want = match declared {
        Some(ft) => {
          if !ft.mut_ {
            immutable(ctx.diagnostics, field.loc, "field")
          }
          internalize(ctx.type_context, ctx.diagnostics, unpack_type(ft))
        }
        None => None
      }
      let value_ = match want {
        Some(w) => self.check(w, value)
        None => self.expression(value)
      }
      {
        desc: StructSet(recv_, field, value_),
        info: annotate([], loc),
        hints: i.hints,
        expected: i.expected,
      }
    }

    // --- Reading a table slot ---
    ArrayGet(recv, index) if self.is_table_receiver(recv) => {
      // `tab[i]` on a TABLE name is `table.get`, the mirror of the `table.set`
      // that `a[i] = v` becomes. The table is a static immediate, so the
      // receiver is never typed as a value.
      guard recv.desc is Get(tabname) else { return self.poisoned(i) }
      note_use(ctx, ctx.tables, tabname)
      let (at, rt) = match ctx.tables.find_no_mark(tabname.name) {
        Some(t) => t
        None => (@wasm_types.AddressType::I32, { nullable: true, typ: Func })
      }
      let index_ = self.expression(index)
      check_subtype(
        ctx.type_context.subtyping_info(),
        ctx.diagnostics,
        index.info,
        expression_type(ctx, index_.info),
        address_cell(at),
      )
      let ty = match internalize(ctx.type_context, ctx.diagnostics, Ref(rt)) {
        Some(c) => c
        None => @infer.Cell::make(@infer.InferredType::Error)
      }
      {
        desc: ArrayGet(recv.map_info(_ => annotate([], recv.info)), index_),
        info: annotate([ty], loc),
        hints: i.hints,
        expected: i.expected,
      }
    }

    // --- Reading an array element ---
    ArrayGet(recv, index) => {
      // Emission order: the array, then the index.
      let recv_ = self.expression(recv)
      let index_ = self.expression(index)
      check_subtype(
        ctx.type_context.subtyping_info(),
        ctx.diagnostics,
        index.info,
        expression_type(ctx, index_.info),
        @infer.valtype_cell(@infer.i32_valtype),
      )
      let ty = match
        self.element_slot(recv.info, expression_type(ctx, recv_.info)) {
        Some(ft) =>
          match field_read_type(ctx.type_context, ctx.diagnostics, ft) {
            Some(c) => c
            None => @infer.Cell::make(@infer.InferredType::Error)
          }
        None => @infer.Cell::make(@infer.InferredType::Error)
      }
      {
        desc: ArrayGet(recv_, index_),
        info: annotate([ty], loc),
        hints: i.hints,
        expected: i.expected,
      }
    }

    // --- Constructing a struct ---
    Struct(name, fields) => {
      // Field inference takes PRECEDENCE over anything else: the fields name
      // the exact struct being constructed, where an expected type could be a
      // supertype of it.
      let resolved = match name {
        Some(n) => Some(n)
        None =>
          match infer_struct_by_fields(ctx, fields.map(f => f.0)) {
            Some(n) => Some(n)
            None => {
              cannot_infer_struct_type(ctx.diagnostics, loc)
              None
            }
          }
      }
      let declared = match resolved {
        Some(n) =>
          lookup_struct_type(
            ctx.type_context,
            ctx.diagnostics,
            n,
            location=Some(loc),
          )
        None => None
      }
      let checked = self.struct_fields(loc, declared, fields)
      let ty = match (resolved, declared) {
        (Some(n), Some(_)) =>
          match construction_result(ctx, n) {
            Some(c) => c
            None => @infer.Cell::make(@infer.InferredType::Error)
          }
        _ => @infer.Cell::make(@infer.InferredType::Error)
      }
      {
        desc: Struct(name, checked),
        info: annotate([ty], loc),
        hints: i.hints,
        expected: i.expected,
      }
    }

    // --- Constructing one at its zero values ---
    StructDefault(name) => {
      let ty = match name {
        Some(n) => {
          // Every field must have a zero to start at; a non-nullable reference
          // does not, so it has to be given explicitly.
          if lookup_struct_type(
              ctx.type_context,
              ctx.diagnostics,
              n,
              location=Some(loc),
            )
            is Some(declared) {
            // Said once for the type, not once per field: the construction as a
            // whole is what cannot be written.
            if declared.iter().any(f => !field_has_default(f.desc.1)) {
              not_defaultable(ctx.diagnostics, loc)
            }
          }
          match construction_result(ctx, n) {
            Some(c) => c
            None => @infer.Cell::make(@infer.InferredType::Error)
          }
        }
        None => {
          cannot_infer_struct_type(ctx.diagnostics, loc)
          @infer.Cell::make(@infer.InferredType::Error)
        }
      }
      {
        desc: StructDefault(name),
        info: annotate([ty], loc),
        hints: i.hints,
        expected: i.expected,
      }
    }

    // --- Constructing an array ---
    Array(name, init, size) => {
      // The element type is resolved BEFORE the value is typed, so a nested
      // literal there can be inferred and drop its own name. The value is still
      // typed first and the count second, which is the emission order.
      let elt = self.element_of(loc, name)
      let init_ = match elt {
        Some(cell) => self.check(cell, init)
        None => self.expression(init)
      }
      let size_ = self.expression(size)
      check_subtype(
        ctx.type_context.subtyping_info(),
        ctx.diagnostics,
        size.info,
        expression_type(ctx, size_.info),
        @infer.valtype_cell(@infer.i32_valtype),
      )
      let ty = self.allocated(loc, name)
      {
        desc: Array(name, init_, size_),
        info: annotate([ty], loc),
        hints: i.hints,
        expected: i.expected,
      }
    }
    ArrayDefault(name, size) => {
      let size_ = self.expression(size)
      check_subtype(
        ctx.type_context.subtyping_info(),
        ctx.diagnostics,
        size.info,
        expression_type(ctx, size_.info),
        @infer.valtype_cell(@infer.i32_valtype),
      )
      if name is Some(n) {
        // Every element starts at its zero, so the element type must have one.
        if lookup_array_type(ctx.type_context, ctx.diagnostics, n) is Some(f) {
          if !field_has_default(f) {
            not_defaultable(ctx.diagnostics, n.loc)
          }
        }
      }
      let ty = self.allocated(loc, name)
      {
        desc: ArrayDefault(name, size_),
        info: annotate([ty], loc),
        hints: i.hints,
        expected: i.expected,
      }
    }
    ArrayFixed(name, elems) => {
      let elt = self.element_of(loc, name)
      let checked : Array[@ast.Instr[@typing_env.InferredAnnotation]] = []
      for e in elems {
        checked.push(
          match elt {
            Some(cell) => self.check(cell, e)
            None => self.expression(e)
          },
        )
      }
      let ty = self.allocated(loc, name)
      {
        desc: ArrayFixed(name, checked),
        info: annotate([ty], loc),
        hints: i.hints,
        expected: i.expected,
      }
    }

    // --- Casts and tests ---
    Cast(operand, target) => {
      let operand_ = self.expression(operand)
      let natural = expression_type(ctx, operand_.info)
      // Set when the cast names no instruction, so its result is poisoned
      // below. A chain anchors every "cannot be cast" at the same leftmost
      // operand, so without the poison one unlowerable value reports once per
      // cast in the chain.
      let mut cast_failed = false
      if ctx.warn_unused {
        lint_conversion(ctx, loc, target, operand)
      }
      let ty = match target {
        // `e as t` for a value type: the result IS the target, and a reference
        // target is worth linting -- it can be impossible or pointless before
        // it is ever run.
        Value(v) => {
          let want = internalize(ctx.type_context, ctx.diagnostics, v)
          // The operand's type as it stands BEFORE the cast settles it to the
          // target: what the lint below has to judge, and what the "cannot be
          // cast" report names.
          let natural_before = natural.get()
          // A continuation carries no RTT, so there is no `ref.cast` into one:
          // `e as &k` with a continuation target is a compile-time ASCRIPTION,
          // and is accepted exactly when it lowers to no instruction at all.
          // Not the castability test below, which admits runtime downcasts.
          let cont_target = v is Ref(t) &&
            is_cont_heaptype(ctx.type_context, t.typ)
          if cont_target {
            // ASKED, not applied: `subtype` settles inference cells as a side
            // effect, and this is a question about the operand's type, not a
            // constraint on it. Pinning here changed the bytes of two files
            // whose operand is polymorphic dead code.
            if want is Some(w) &&
              !subtype(ctx.type_context.subtyping_info(), natural, w, pin=false) {
              cont_cast_not_ascription(ctx.diagnostics, loc)
            }
          }
          // Settle a still-flexible operand at the type the cast names, BEFORE
          // the result type is decided: a literal has no width of its own, and
          // the cast is what says which one it takes. The same act answers
          // whether the cast lowers to anything at all.
          if !cont_target && want is Some(w) && w.get() is Valtype(target) {
            if !value_cast(ctx, natural, target) {
              invalid_cast(
                ctx.diagnostics,
                operand.info,
                @infer.Cell::make(natural_before),
              )
              cast_failed = true
            }
          }
          // A continuation target's "redundant" upcast is the intended use --
          // it is an ascription, and saying so of every one would be noise.
          if !cont_target && want is Some(w) {
            lint_ref_cast(
              ctx,
              loc,
              is_test=false,
              natural_before,
              w.get(),
              operand_location=Some(operand.info),
            )
          }
          match want {
            Some(w) => w
            None => @infer.Cell::make(@infer.InferredType::Error)
          }
        }
        // `e as &fn(..)` mints a function type for the target.
        Func(nullable~, sign~) =>
          match self.inline_functype(loc, sign) {
            Some(name) =>
              match
                internalize(
                  ctx.type_context,
                  ctx.diagnostics,
                  Ref({ nullable, typ: Type(name) }),
                  inline=Some(Func(sign)),
                ) {
                Some(c) => c
                None => @infer.Cell::make(@infer.InferredType::Error)
              }
            None => @infer.Cell::make(@infer.InferredType::Error)
          }
        // `e as i32_s` and friends: a numeric conversion, whose result is the
        // named numeric type and nothing else.
        Signed(typ~, signage~, ..) => {
          // An atomic narrow load has no sign-extending form -- only the
          // zero-extending `_u` instructions exist -- so reject `as iN_s` on
          // one outright, naming the spelling to use, rather than quietly
          // compiling a load and a separate sign-extend.
          let narrow = if signage is Signed && typ is (I32 | I64) {
            atomic_narrow_load_width(ctx, operand)
          } else {
            None
          }
          if narrow is Some(w) {
            atomic_signed_load(
              ctx.diagnostics,
              loc,
              "as " + (if typ is I32 { "i32" } else { "i64" }) + "_u",
              match w {
                @atomics.Width::W8 => ".extend8_s()"
                _ => ".extend16_s()"
              },
            )
          } else if !signed_cast(ctx, natural, typ) {
            invalid_cast(ctx.diagnostics, operand.info, natural)
            cast_failed = true
          }
          @infer.valtype_cell(
            match typ {
              I32 => @infer.i32_valtype
              I64 => @infer.i64_valtype
              F32 => @infer.f32_valtype
              F64 => @infer.f64_valtype
            },
          )
        }
      }
      // `Error` is castable to anything, so a failed cast's result absorbs the
      // rest of the chain instead of repeating the same complaint.
      if cast_failed || natural.get() is Error {
        ty.set(Error)
      }
      {
        desc: Cast(operand_, target),
        info: annotate([ty], loc),
        hints: i.hints,
        expected: i.expected,
      }
    }
    Test(operand, target) => {
      let operand_ = self.expression(operand)
      let natural = expression_type(ctx, operand_.info)
      // A continuation has no RTT to test against, so `is` cannot ask about
      // one -- the same reason `as` into one is an ascription rather than a
      // cast.
      if is_cont_heaptype(ctx.type_context, target.typ) {
        invalid_cast_type(ctx.diagnostics, loc)
      }
      if internalize(ctx.type_context, ctx.diagnostics, Ref(target)) is Some(w) {
        lint_ref_cast(
          ctx,
          loc,
          is_test=true,
          natural.get(),
          w.get(),
          operand_location=Some(operand.info),
        )
      }
      // A test answers a question, so it produces an i32 whatever it asked.
      let ty = @infer.valtype_cell(@infer.i32_valtype)
      {
        desc: Test(operand_, target),
        info: annotate([ty], loc),
        hints: i.hints,
        expected: i.expected,
      }
    }
    NonNull(operand) => {
      let operand_ = self.expression(operand)
      let ty = match expression_type(ctx, operand_.info).get() {
        Valtype({ typ: Ref(r), internal: Ref(ir), anon_comptype }) => {
          let v : @infer.InferredValType = {
            typ: Ref({ nullable: false, typ: r.typ }),
            internal: Ref({ nullable: false, typ: ir.typ }),
            anon_comptype,
          }
          @infer.Cell::make(@infer.InferredType::Valtype(v))
        }
        // A reference recovered from a polymorphic value -- dead code, a value
        // known only as a reference, or a bare `null`. The bottom reference is
        // a subtype of every reference type, so it satisfies any consumer, and
        // `ref.as_non_null` of a null is valid wasm that always traps.
        Unknown | UnknownRef | Null =>
          @infer.Cell::make(@infer.InferredType::UnknownRef)
        Error => @infer.Cell::make(@infer.InferredType::Error)
        _ => {
          expected_ref(ctx.diagnostics, operand.info)
          @infer.Cell::make(@infer.InferredType::Error)
        }
      }
      {
        desc: NonNull(operand_),
        info: annotate([ty], loc),
        hints: i.hints,
        expected: i.expected,
      }
    }

    // --- A string literal, which builds a byte array ---
    Str(name, bytes) => {
      // Its natural type is the canonical `<string>` array. It adopts another
      // only when one is named explicitly.
      let typ : @ast.Ident = match name {
        Some(n) => n
        None => {
          // Registered ON DEMAND, when a literal actually resolves to it. The
          // store IS the type section, so registering it up front would put the
          // canonical array in every module that mentions a string -- including
          // the ones whose literals all name a type of their own. Interning
          // appends, so an index already handed out does not move.
          register_string_type(ctx)
          { name: string_type_name, loc }
        }
      }
      // A string that resolves to the canonical array is a use of every source
      // type that deduplicated onto it, even though it names none of them --
      // which is why this is recorded by INDEX rather than by name.
      if name is None {
        if resolve_type_name(ctx.type_context, ctx.diagnostics, typ)
          is Some(canonical) {
          let entry = (ctx.origin.val, canonical)
          if !ctx.canonical_type_references.contains(entry) {
            ctx.canonical_type_references.push(entry)
          }
        }
      }
      if lookup_array_type(ctx.type_context, ctx.diagnostics, typ)
        is Some(field) {
        match field.typ {
          Packed(I8) => ()
          // An `i16` array holds code units, so the bytes have to decode.
          Packed(I16) =>
            if !is_valid_utf8(bytes) {
              string_not_unicode(ctx.diagnostics, loc)
            }
          Value(_) => invalid_string_element_type(ctx.diagnostics, loc)
        }
      }
      let ty = match construction_result(ctx, typ) {
        Some(c) => c
        None => @infer.Cell::make(@infer.InferredType::Error)
      }
      {
        desc: Str(name, bytes),
        info: annotate([ty], loc),
        hints: i.hints,
        expected: i.expected,
      }
    }

    // --- An array built from a segment ---
    ArraySegment(name, seg, off, len) => {
      let off_ = self.expression(off)
      let len_ = self.expression(len)
      let i32c = () => @infer.valtype_cell(@infer.i32_valtype)
      check_subtype(
        ctx.type_context.subtyping_info(),
        ctx.diagnostics,
        off.info,
        expression_type(ctx, off_.info),
        i32c(),
      )
      check_subtype(
        ctx.type_context.subtyping_info(),
        ctx.diagnostics,
        len.info,
        expression_type(ctx, len_.info),
        i32c(),
      )
      match name {
        None => cannot_infer_array_type(ctx.diagnostics, loc)
        Some(n) =>
          if lookup_array_type(ctx.type_context, ctx.diagnostics, n)
            is Some(field) {
            // WHICH segment space this names is decided by the element type: a
            // reference element makes it `array.new_elem` and an element
            // segment, anything else `array.new_data` and a data segment. The
            // same written name means different things in the two.
            match field.typ {
              Value(Ref(dst)) =>
                if find(ctx.elems, ctx.diagnostics, seg) is Some(src) {
                  check_elem_subtype(ctx, loc, src, dst)
                }
              _ => {
                let _ = find(ctx.datas, ctx.diagnostics, seg)
              }
            }
          }
      }
      let ty = self.allocated(loc, name)
      {
        desc: ArraySegment(name, seg, off_, len_),
        info: annotate([ty], loc),
        hints: i.hints,
        expected: i.expected,
      }
    }

    // --- The descriptor of a value ---
    GetDescriptor(recv) => {
      let recv_ = self.expression(recv)
      let ty = match expression_type(ctx, recv_.info).get() {
        Valtype({ typ: Ref({ typ: Type(n) | Exact(n) as ht, .. }), .. }) => {
          // Exactness carries through: the descriptor of an EXACT reference is
          // itself exact, since the type is known and so is its descriptor.
          let exact = ht is Exact(_)
          match ctx.types.find_no_mark(n.name) {
            Some((_, def)) =>
              match def.descriptor {
                None => {
                  type_without_descriptor(ctx.diagnostics, recv.info)
                  @infer.Cell::make(@infer.InferredType::Error)
                }
                Some(d) =>
                  match
                    internalize(
                      ctx.type_context,
                      ctx.diagnostics,
                      Ref({
                        nullable: false,
                        typ: if exact {
                          Exact(d)
                        } else {
                          Type(d)
                        },
                      }),
                    ) {
                    Some(c) => c
                    None => @infer.Cell::make(@infer.InferredType::Error)
                  }
              }
            None => @infer.Cell::make(@infer.InferredType::Error)
          }
        }
        Error => @infer.Cell::make(@infer.InferredType::Error)
        Unknown | UnknownRef => {
          unknown_operand_type(ctx.diagnostics, recv.info)
          @infer.Cell::make(@infer.InferredType::Error)
        }
        _ => {
          expected_struct(ctx.diagnostics, recv.info)
          @infer.Cell::make(@infer.InferredType::Error)
        }
      }
      {
        desc: GetDescriptor(recv_),
        info: annotate([ty], loc),
        hints: i.hints,
        expected: i.expected,
      }
    }

    // --- A raw try_table ---
    TryTable(label~, typ~, catches~, block~) => {
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
      self.trytable_node(i, label, typ, catches, block, params, results)
    }

    // --- A structured try, with one handler per tag ---
    Try(label~, typ~, block~, catches~, catch_all~) => {
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
      self.try_node(i, label, typ, block, catches, catch_all, params, results)
    }

    // --- A structured try whose arms fall through into each other ---
    TryCatch(label~, typ~, block~, arms~) => {
      // Unlike the raw table, this form takes no parameters: it is a source
      // construct, and expression position has no stack to take them from.
      if !typ.params.is_empty() {
        parameterized_block_expression(ctx.diagnostics, loc)
      }
      guard self.signature_of(typ) is Some((_, results)) else {
        return self.poisoned(i)
      }
      self.trycatch_node(i, label, typ, block, arms, results)
    }

    // --- A while loop, checked as what it lowers to ---
    While(label~, cond~, step~, block~) => {
      // Checked against its LOWERING rather than by its own rules, so the loop
      // and the branch it becomes are validated exactly as if they had been
      // written out -- and there is no second set of rules to drift from the
      // first. The high-level form is then rebuilt for the formatter and for
      // the identical re-lowering in the code generator.
      let fresh : @ast.Ident = {
        name: "<while:" + loc.start.cnum.to_string() + ">",
        loc,
      }
      let (cond, _) = reject_control_holes(
        ctx,
        "while",
        "condition",
        Int("0"),
        cond,
      )
      let lowered = @ast.lower_while(
        loc,
        fresh_loop=fresh,
        label~,
        cond~,
        step~,
        block=block.desc,
      )
      let typed = self.body(loc, None, [], [], [], lowered)
      // The peel is deterministic: the shape is the one `lower_while` just
      // produced. If it is not -- which recovery can cause -- the original
      // children are kept unannotated rather than crashing on a shape nobody
      // promised.
      match
        peel_while(typed, stepped=step is Some(_), labelled=label is Some(_)) {
        Some((cond_, step_, body_)) =>
          {
            desc: While(label~, cond=cond_, step=step_, block={
              desc: body_,
              info: block.info,
            }),
            info: annotate([], loc),
            hints: i.hints,
            expected: i.expected,
          }
        None => {
          self.note_unpeeled("While")
          self.placeholder(i)
        }
      }
    }

    // --- A dispatch, checked as the block ladder it becomes ---
    Dispatch(index~, cases~, default~, arms~) => {
      // The arm labels become distinct block labels in the lowering and key the
      // arm bodies, so two arms sharing a label would build one block and lose
      // the other's body entirely.
      let seen : Map[String, @basic.Location] = Map([])
      for a in arms {
        match seen.get(a.0.name) {
          Some(prev) =>
            dispatch_duplicate_arm(ctx.diagnostics, a.0.loc, prev, a.0.name)
          None => seen[a.0.name] = a.0.loc
        }
      }
      let (index, _) = reject_control_holes(
        ctx,
        "dispatch",
        "index",
        Int("0"),
        index,
      )
      let lowered = @ast.lower_dispatch(loc, index~, cases~, default~, arms~)
      // Typed as a SEQUENCE in the current stack rather than as an isolated
      // block, so a value the trailing arm leaves -- the dispatch's own
      // fall-through -- reaches the enclosing block, exactly as it would for the
      // blocks written out. `Checker::expression` isolates it instead, because
      // there the dispatch is a value on its own.
      let typed = self.block_contents([], lowered)
      match peel_dispatch(typed, arms.length()) {
        Some((index_, bodies)) => {
          let rebuilt : Array[
            (
              @ast.Ident,
              @basic.Annotated[
                Array[@ast.Instr[@typing_env.InferredAnnotation]],
                @basic.Location,
              ],
            ),
          ] = []
          for k, a in arms {
            rebuilt.push((a.0, { desc: bodies[k], info: a.1.info }))
          }
          {
            desc: Dispatch(index=index_, cases~, default~, arms=rebuilt),
            info: annotate([], loc),
            hints: i.hints,
            expected: i.expected,
          }
        }
        None => {
          self.note_unpeeled("Dispatch")
          self.placeholder(i)
        }
      }
    }

    // --- Branching on a reference being null, or not ---
    BrOnNull(label, operand) => {
      let operand_ = self.expression(operand)
      let (ref_ty, below) = self.split_on_last(operand.info, operand_.info.0)
      // The FALL-THROUGH value is the non-null form: the branch was not taken,
      // so the reference is known not to be null.
      let non_null = self.non_null_of(operand.info, ref_ty)
      let delivered = if label_in_scope(ctx, label) {
        deliver_to_branch_target(
          ctx.type_context.subtyping_info(),
          ctx.diagnostics,
          operand.info,
          below,
          branch_target(ctx, label),
        )
      } else {
        below
      }
      let result = delivered.copy()
      result.push(non_null)
      {
        desc: BrOnNull(label, operand_),
        info: annotate(result, loc),
        hints: i.hints,
        expected: i.expected,
      }
    }
    BrOnNonNull(label, operand) => {
      let operand_ = self.expression(operand)
      let params = branch_target(ctx, label)
      let bound = label_in_scope(ctx, label)
      let (ref_ty, below) = self.split_on_last(operand.info, operand_.info.0)
      if bound && !(ref_ty.get() is (Unknown | Error | UnknownRef)) {
        // The BRANCH carries the non-null reference, so that is what the target
        // is checked against -- the mirror of `br_on_null`, where the non-null
        // form is what falls through instead.
        let delivered = below.copy()
        delivered.push(self.non_null_of(operand.info, ref_ty))
        check_subtypes(
          ctx.type_context.subtyping_info(),
          ctx.diagnostics,
          operand.info,
          delivered,
          params,
        )
      }
      // The fall-through keeps everything BUT the reference, which went to the
      // target. A target with no parameters is malformed and was reported
      // above; taking nothing then is what keeps this from indexing past it.
      let result = if bound {
        if params.length() > 0 {
          params[0:params.length() - 1].to_owned()
        } else {
          []
        }
      } else {
        below
      }
      {
        desc: BrOnNonNull(label, operand_),
        info: annotate(result, loc),
        hints: i.hints,
        expected: i.expected,
      }
    }

    // --- Branching on a cast succeeding, or on it failing ---
    BrOnCast(label, target, operand) => {
      let operand_ = self.expression(operand)
      if is_cont_heaptype(ctx.type_context, target.typ) {
        invalid_cast_type(ctx.diagnostics, loc)
      }
      let (ref_ty, below) = self.split_on_last(operand.info, operand_.info.0)
      let params = branch_target(ctx, label)
      let bound = label_in_scope(ctx, label)
      if bound &&
        internalize(ctx.type_context, ctx.diagnostics, Ref(target))
        is Some(cast_to) {
        // The BRANCH carries the cast target, so that is what the label sees.
        let delivered = below.copy()
        delivered.push(cast_to)
        check_subtypes(
          ctx.type_context.subtyping_info(),
          ctx.diagnostics,
          operand.info,
          delivered,
          params,
        )
      }
      // The FALL-THROUGH keeps the value at its residual type: what is left of
      // it once the cast target is taken away. The OPERAND is re-typed to the
      // source the instruction will name -- the join of its own type and the
      // target -- because that is the type the emitted immediate has to state,
      // and a source narrower than the target is not a well-formed one.
      let residual = match
        conditional_cast_types(ctx, operand.info, ref_ty, target) {
        Some((source, r)) => {
          ref_ty.set(source.get())
          r
        }
        None => @infer.Cell::make(@infer.InferredType::Error)
      }
      let result = if bound {
        if params.length() > 0 {
          params[0:params.length() - 1].to_owned()
        } else {
          []
        }
      } else {
        below
      }
      result.push(residual)
      {
        desc: BrOnCast(label, target, operand_),
        info: annotate(result, loc),
        hints: i.hints,
        expected: i.expected,
      }
    }
    BrOnCastFail(label, target, operand) => {
      let operand_ = self.expression(operand)
      if is_cont_heaptype(ctx.type_context, target.typ) {
        invalid_cast_type(ctx.diagnostics, loc)
      }
      let (ref_ty, below) = self.split_on_last(operand.info, operand_.info.0)
      // The mirror: the BRANCH carries the residual (the cast failed), and the
      // fall-through carries the target (it succeeded). The operand is re-typed
      // to the source for the same reason as in the non-failing form -- the
      // instruction names both types, and a source narrower than the target is
      // not a well-formed pair.
      let residual = match
        conditional_cast_types(ctx, operand.info, ref_ty, target) {
        Some((source, r)) => {
          ref_ty.set(source.get())
          r
        }
        None => @infer.Cell::make(@infer.InferredType::Error)
      }
      let params = branch_target(ctx, label)
      if label_in_scope(ctx, label) {
        let delivered = below.copy()
        delivered.push(residual)
        check_subtypes(
          ctx.type_context.subtyping_info(),
          ctx.diagnostics,
          operand.info,
          delivered,
          params,
        )
      }
      let result = below.copy()
      match internalize(ctx.type_context, ctx.diagnostics, Ref(target)) {
        Some(c) => result.push(c)
        None => result.push(@infer.Cell::make(@infer.InferredType::Error))
      }
      {
        desc: BrOnCastFail(label, target, operand_),
        info: annotate(result, loc),
        hints: i.hints,
        expected: i.expected,
      }
    }

    // --- A match, checked as the type-test ladder it becomes ---
    Match(scrutinee~, arms~, default~) => {
      // One block label per arm plus an escape label. Synthesized and
      // unwritable, so they cannot capture a `br` the author wrote.
      let labels : Array[@ast.Ident] = []
      for k in 0..<=arms.length() {
        labels.push({
          name: "<match:" +
          loc.start.cnum.to_string() +
          ":" +
          k.to_string() +
          ">",
          loc,
        })
      }
      let (scrutinee, _) = reject_control_holes(
        ctx,
        "match",
        "scrutinee",
        Null,
        scrutinee,
      )
      let lowered = @ast.lower_match(loc, labels~, scrutinee~, arms~, default~)
      // In the current stack, as for `Dispatch` above: the escape block's
      // fall-through -- the no-match path through the default -- is the match's
      // value and belongs to the enclosing block.
      let typed = self.block_contents([], lowered)
      match peel_match(typed, arms.length()) {
        Some((bodies, default_body, scrutinee_)) => {
          let rebuilt : Array[
            (
              @ast.MatchPattern,
              @basic.Annotated[
                Array[@ast.Instr[@typing_env.InferredAnnotation]],
                @basic.Location,
              ],
            ),
          ] = []
          for k, a in arms {
            rebuilt.push((a.0, { desc: bodies[k], info: a.1.info }))
          }
          {
            // With no arms the scrutinee never reaches the lowering, so there
            // is nothing typed to recover and it is checked here instead.
            desc: Match(
              scrutinee=match scrutinee_ {
                Some(sc) => sc
                None => self.expression(scrutinee)
              },
              arms=rebuilt,
              default={ desc: default_body, info: default.info },
            ),
            info: annotate([], loc),
            hints: i.hints,
            expected: i.expected,
          }
        }
        None => {
          self.note_unpeeled("Match")
          self.placeholder(i)
        }
      }
    }

    // --- Dropping a data or element segment ---
    //
    // `seg.drop()` names a SEGMENT, which is not a value: typing the receiver
    // as an expression would look for a variable of that name and report it
    // unbound, which is what was happening.
    Call(callee, _) if self.segment_drop(callee) => {
      guard callee.desc is StructGet(recv, _) else { return self.poisoned(i) }
      guard recv.desc is Get(name) else { return self.poisoned(i) }
      note_use(ctx, ctx.datas, name)
      note_use(ctx, ctx.elems, name)
      {
        desc: Call(
          {
            desc: StructGet(
              {
                desc: Get(name),
                info: annotate([], recv.info),
                hints: recv.hints,
                expected: recv.expected,
              },
              match callee.desc {
                StructGet(_, m) => m
                _ => { name: "drop", loc }
              },
            ),
            info: annotate([], callee.info),
            hints: callee.hints,
            expected: callee.expected,
          },
          [],
        ),
        info: annotate([], loc),
        hints: i.hints,
        expected: i.expected,
      }
    }

    // --- A memory access written as a method call ---
    Call(callee, args) if self.mgmt_kind(callee) is Some(_) => {
      guard callee.desc is StructGet(recv, meth) else {
        return self.poisoned(i)
      }
      guard recv.desc is Get(name) else { return self.poisoned(i) }
      let on_memory = self.mgmt_kind(callee) == Some(true)
      let (checked_args, results) = if on_memory {
        self.mem_mgmt(loc, name, meth, args)
      } else {
        self.table_mgmt(loc, name, meth, args)
      }
      {
        desc: Call(
          callee.map_info(_ => annotate([], callee.info)),
          checked_args,
        ),
        info: annotate(results, loc),
        hints: i.hints,
        expected: i.expected,
      }
    }
    // --- A continuation constructor: `k::new(f)`, `k::bind(x, c)` ---
    Call(callee, args) if self.cont_namespace(callee) is Some(_) => {
      guard callee.desc is Path(ns, name) else { return self.poisoned(i) }
      self.cont_construct(i, callee.info, ns, name, args)
    }

    // --- Wide arithmetic: `i64::add128(..)`, `i64::mul_wide_s(..)` ---
    Call(callee, args) if self.wide_arith(callee) => {
      guard callee.desc is Path(ns, name) else { return self.poisoned(i) }
      self.wide_arith_call(i, callee, ns, name, args)
    }

    // --- `atomic::fence()`: the one atomic with no memory and no operands ---
    Call(callee, args) if is_atomic_fence(callee) => {
      // Any arguments are still typed, so a mistake inside one is reported
      // where it is rather than swallowed by the arity complaint.
      for a in args {
        let _ = self.expression(a)
      }
      {
        desc: Call(callee.map_info(_ => annotate([], callee.info)), []),
        info: annotate([], loc),
        hints: i.hints,
        expected: i.expected,
      }
    }

    // --- A SIMD operation written on a value: `x.add_i32x4(y)` ---
    // --- A free intrinsic: `v128::i8x16(..)`, `v128::bitselect(..)` ---
    Call(callee, args) if callee.desc is Path(_, _) => {
      guard callee.desc is Path(ns, name) else { return self.poisoned(i) }
      let checked = args.map(a => self.expression(a))
      let ty = self.free_intrinsic(callee.info, ns, name, args, checked)
      {
        desc: Call(callee.map_info(_ => annotate([], callee.info)), checked),
        info: annotate([ty], loc),
        hints: i.hints,
        expected: i.expected,
      }
    }

    // --- A no-argument instruction method: `x.sqrt()`, `arr.length()` ---
    Call(callee, args) if self.is_unary_intrinsic(callee, args) => {
      guard callee.desc is StructGet(recv, meth) else {
        return self.poisoned(i)
      }
      let recv_ = self.expression(recv)
      let ty = self.unary_intrinsic(
        recv.info,
        meth,
        expression_type(ctx, recv_.info),
      )
      {
        desc: Call(
          {
            desc: StructGet(recv_, meth),
            info: annotate([], callee.info),
            hints: callee.hints,
            expected: callee.expected,
          },
          [],
        ),
        info: annotate([ty], loc),
        hints: i.hints,
        expected: i.expected,
      }
    }
    Call(callee, args) if self.simd_vector_op(callee) is Some(_) => {
      guard callee.desc is StructGet(recv, meth) else {
        return self.poisoned(i)
      }
      guard self.simd_vector_op(callee) is Some(op) else {
        return self.poisoned(i)
      }
      let (recv_, checked_args, results) = self.simd_vector_call(
        callee.info,
        recv,
        op,
        args,
      )
      {
        desc: Call(
          {
            desc: StructGet(recv_, meth),
            info: annotate([], callee.info),
            hints: callee.hints,
            expected: callee.expected,
          },
          checked_args,
        ),
        info: annotate(results, loc),
        hints: i.hints,
        expected: i.expected,
      }
    }
    Call(callee, args) if self.simd_mem_intrinsic(callee) is Some(_) => {
      guard callee.desc is StructGet(recv, meth) else {
        return self.poisoned(i)
      }
      guard recv.desc is Get(memname) else { return self.poisoned(i) }
      guard self.simd_mem_intrinsic(callee) is Some(mop) else {
        return self.poisoned(i)
      }
      let (checked_args, results) = self.simd_mem_access(
        loc, memname, meth, mop, args,
      )
      {
        desc: Call(
          callee.map_info(_ => annotate([], callee.info)),
          checked_args,
        ),
        info: annotate(results, loc),
        hints: i.hints,
        expected: i.expected,
      }
    }
    Call(callee, args) if self.atomic_family(callee) is Some(_) => {
      guard callee.desc is StructGet(recv, meth) else {
        return self.poisoned(i)
      }
      guard recv.desc is Get(memname) else { return self.poisoned(i) }
      guard self.atomic_family(callee) is Some(family) else {
        return self.poisoned(i)
      }
      let (checked_args, results) = self.atomic_access(
        loc, memname, meth, family, args,
      )
      {
        desc: Call(
          callee.map_info(_ => annotate([], callee.info)),
          checked_args,
        ),
        info: annotate(results, loc),
        hints: i.hints,
        expected: i.expected,
      }
    }
    Call(callee, args) if self.is_mem_access(callee) => {
      guard callee.desc is StructGet(recv, meth) else {
        return self.poisoned(i)
      }
      guard recv.desc is Get(memname) else { return self.poisoned(i) }
      let (checked_args, results) = self.mem_access(loc, memname, meth, args)
      {
        desc: Call(
          callee.map_info(_ => annotate([], callee.info)),
          checked_args,
        ),
        info: annotate(results, loc),
        hints: i.hints,
        expected: i.expected,
      }
    }

    // --- An array bulk method: `a.fill(..)`, `a.copy(..)`, `a.init(..)` ---
    Call(callee, args) if self.array_bulk_method(callee, args) is Some(_) => {
      guard callee.desc is StructGet(recv, meth) else {
        return self.poisoned(i)
      }
      self.array_bulk_call(i, callee, recv, meth, args)
    }

    // --- Stack switching written as a method on the continuation ---
    Call(callee, args) if self.cont_method(callee) is Some(_) => {
      guard callee.desc is StructGet(recv, meth) else {
        return self.poisoned(i)
      }
      self.cont_method_call(i, callee, recv, meth, args, [])
    }

    // --- A scalar binary intrinsic: `x.min(y)`, `x.rotl(1)` ---
    Call(callee, args) if self.is_binary_intrinsic(callee) => {
      guard callee.desc is StructGet(recv, meth) else {
        return self.poisoned(i)
      }
      self.binary_intrinsic(i, callee, recv, meth, args)
    }

    // --- An ordinary call through a function reference ---
    Call(callee, args) => {
      let (callee_, args_, results, not_a_function) = self.call(
        loc, callee, args,
      )
      if not_a_function {
        // `lookup_func_type` already said the named type is not a function, so
        // there is no call here to build. Recovered with the shape a failed
        // lookup yields everywhere else -- an `unreachable` typed `Error` --
        // which is also what tells a wrapping `become` it has nothing to tail
        // call rather than letting it form one over an `Error` result.
        return {
          desc: Unreachable,
          info: annotate([@infer.Cell::make(@infer.InferredType::Error)], loc),
          hints: i.hints,
          expected: i.expected,
        }
      }
      {
        desc: Call(callee_, args_),
        info: annotate(results, loc),
        hints: i.hints,
        expected: i.expected,
      }
    }
    TailCall(callee, args) => {
      // Typed exactly as the call it is -- through the WHOLE call dispatch, so
      // `become mem.grow(n)` and `become x.min(y)` are accepted wherever the
      // plain forms are -- and then re-tagged, with one extra demand: the
      // callee's results must satisfy THIS function's, since its return is what
      // the caller will see.
      let typed = self.statement({ ..i, desc: Call(callee, args) })
      if typed.desc is Unreachable {
        // Typing the call already failed and said so; there is no tail call to
        // form, so the failed result is passed straight through rather than
        // re-reported as a stack-switching operation.
        return typed
      }
      guard typed.desc is Call(callee_, args_) else {
        // It type-checked but is not a call: a stack-switching operation, which
        // hands control away by its own means and cannot be tail-called.
        // Reported rather than silently dropping the `become` -- which would
        // also skip the return-type check -- and recovered with the operation.
        become_on_stack_switching(ctx.diagnostics, loc)
        return typed
      }
      check_subtypes(
        ctx.type_context.subtyping_info(),
        ctx.diagnostics,
        loc,
        typed.info.0,
        ctx.return_types,
      )
      // A tail call does not return here, so nothing follows it.
      self.ops.set_unreachable()
      {
        desc: TailCall(callee_, args_),
        info: annotate([], loc),
        hints: i.hints,
        expected: i.expected,
      }
    }

    // --- Creating a continuation ---
    ContNew(ct, f) => {
      let f_ = self.expression(f)
      if lookup_cont_inner(ctx.type_context, ctx.diagnostics, ct) is Some(ft) {
        // The function a continuation is made of, as a nullable reference: a
        // null one traps when resumed rather than being rejected here.
        if internalize(
            ctx.type_context,
            ctx.diagnostics,
            Ref({ nullable: true, typ: Type(ft) }),
          )
          is Some(want) {
          check_subtype(
            ctx.type_context.subtyping_info(),
            ctx.diagnostics,
            f.info,
            expression_type(ctx, f_.info),
            want,
          )
        }
      }
      let ty = self.fresh_continuation(ct)
      {
        desc: ContNew(ct, f_),
        info: annotate([ty], loc),
        hints: i.hints,
        expected: i.expected,
      }
    }

    // --- Binding a continuation's leading parameters ---
    ContBind(src, dst, args) => {
      let checked = args.map(a => self.expression(a))
      self.check_cont_bind(loc, src, dst, args, checked)
      let ty = self.fresh_continuation(dst)
      {
        desc: ContBind(src, dst, checked),
        info: annotate([ty], loc),
        hints: i.hints,
        expected: i.expected,
      }
    }

    // --- Suspending to a tag ---
    Suspend(tag, args) => {
      // The TAG says what the operands are, so they are checked against it
      // rather than inferred: a block written as one -- `suspend y('l: do {..})`
      // -- has no result type of its own and takes the parameter's.
      let want_params : Array[@infer.Cell[@infer.InferredType]] = []
      if find(ctx.tags, ctx.diagnostics, tag) is Some(ft) {
        for p in ft.params {
          if internalize(ctx.type_context, ctx.diagnostics, p.desc.1) is Some(c) {
            want_params.push(c)
          }
        }
      }
      let paired = want_params.length() == args.length()
      let checked = args.mapi((k, a) => {
        if paired {
          self.check(want_params[k], a)
        } else {
          self.expression(a)
        }
      })
      let results = match find(ctx.tags, ctx.diagnostics, tag) {
        None => []
        Some(ft) => {
          // A suspend hands the tag's parameters out and takes its RESULTS back
          // when resumed -- unlike a throw, where a tag with results is a
          // mistake, because a throw never comes back.
          let want : Array[@infer.Cell[@infer.InferredType]] = []
          for p in ft.params {
            if internalize(ctx.type_context, ctx.diagnostics, p.desc.1)
              is Some(c) {
              want.push(c)
            }
          }
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
          let out : Array[@infer.Cell[@infer.InferredType]] = []
          for r in ft.results {
            if internalize(ctx.type_context, ctx.diagnostics, r) is Some(c) {
              out.push(c)
            }
          }
          out
        }
      }
      {
        desc: Suspend(tag, checked),
        info: annotate(results, loc),
        hints: i.hints,
        expected: i.expected,
      }
    }

    // --- Resuming a continuation ---
    Resume(ct, handlers, args) => {
      // The operands' types come from the continuation's signature, so they are
      // resolved before the operands are typed -- the same reason the method
      // form types its receiver first.
      let checked = self.resume_operands(ct, "resume", None, args)
      let results = self.type_resume(
        loc,
        ct,
        handlers,
        checked,
        None,
        ref_first=false,
      )
      {
        desc: Resume(ct, handlers, checked),
        info: annotate(results, loc),
        hints: i.hints,
        expected: i.expected,
      }
    }
    ResumeThrow(ct, tag, handlers, args) => {
      let checked = self.resume_operands(ct, "resume_throw", Some(tag), args)
      // The operands are the TAG's parameters, not the continuation's: the
      // resume throws into the continuation rather than passing values to it.
      let results = self.type_resume(
        loc,
        ct,
        handlers,
        checked,
        Some(tag),
        ref_first=false,
      )
      {
        desc: ResumeThrow(ct, tag, handlers, checked),
        info: annotate(results, loc),
        hints: i.hints,
        expected: i.expected,
      }
    }
    ResumeThrowRef(ct, handlers, args) => {
      let checked = self.resume_operands(ct, "resume_throw_ref", None, args)
      let results = self.type_resume(
        loc,
        ct,
        handlers,
        checked,
        None,
        ref_first=true,
      )
      {
        desc: ResumeThrowRef(ct, handlers, checked),
        info: annotate(results, loc),
        hints: i.hints,
        expected: i.expected,
      }
    }

    // --- Switching directly to another continuation ---
    Switch(ct, tag, args) => {
      let checked = self.resume_operands(ct, "switch", Some(tag), args)
      let results = self.type_switch(loc, ct, tag, checked)
      {
        desc: Switch(ct, tag, checked),
        info: annotate(results, loc),
        hints: i.hints,
        expected: i.expected,
      }
    }

    // --- Handlers attached to a resume ---
    On(inner, handlers) => {
      // The surface spelling `c.resume(x) on (...)`, where the handlers are
      // written outside the call. They belong to the resume, so the only thing
      // to check here is that there IS one.
      if !(inner.desc is Resume(_, _, _)) &&
        !(inner.desc is ResumeThrow(_, _, _, _)) &&
        !(inner.desc is ResumeThrowRef(_, _, _)) &&
        !self.is_resume_call(inner) {
        on_clause_context(ctx.diagnostics, loc)
      }
      // The handlers belong to the resume, so they are handed to it -- the raw
      // `resume` forms carry their own, and the METHOD form has none of its own
      // to carry, which is the whole reason this spelling exists.
      let inner_ = match inner.desc {
        Call(callee, args) if self.cont_method(callee) is Some(_) => {
          guard callee.desc is StructGet(recv, meth) else {
            return self.poisoned(i)
          }
          self.cont_method_call(inner, callee, recv, meth, args, handlers)
        }
        // Recover by typing the wrapped expression and carrying its result: the
        // handlers being misplaced says nothing about what it computes.
        _ => self.expression(inner)
      }
      {
        desc: On(inner_, handlers),
        info: annotate(inner_.info.0, loc),
        hints: i.hints,
        expected: i.expected,
      }
    }

    // --- Constructing a struct through its descriptor ---
    StructDesc(desc, fields) => {
      // The DESCRIPTOR is typed first, because it is what says which struct is
      // being built -- the type is not written down anywhere else.
      let desc_ = self.expression(desc)
      let target = descriptor_reftype(
        ctx,
        desc.info,
        nullable=false,
        expression_type(ctx, desc_.info),
      )
      let declared = match target {
        Some({ typ: Type(n) | Exact(n), .. }) =>
          lookup_struct_type(
            ctx.type_context,
            ctx.diagnostics,
            n,
            location=Some(loc),
          )
        _ => None
      }
      let checked = self.struct_fields(loc, declared, fields)
      let ty = match target {
        Some(rt) =>
          match internalize(ctx.type_context, ctx.diagnostics, Ref(rt)) {
            Some(c) => c
            None => @infer.Cell::make(@infer.InferredType::Error)
          }
        None => @infer.Cell::make(@infer.InferredType::Error)
      }
      {
        desc: StructDesc(desc_, checked),
        info: annotate([ty], loc),
        hints: i.hints,
        expected: i.expected,
      }
    }
    StructDefaultDesc(desc) => {
      let desc_ = self.expression(desc)
      let target = descriptor_reftype(
        ctx,
        desc.info,
        nullable=false,
        expression_type(ctx, desc_.info),
      )
      if target is Some({ typ: Type(n) | Exact(n), .. }) {
        if lookup_struct_type(
            ctx.type_context,
            ctx.diagnostics,
            n,
            location=Some(loc),
          )
          is Some(declared) {
          if declared.iter().any(f => !field_has_default(f.desc.1)) {
            not_defaultable(ctx.diagnostics, loc)
          }
        }
      }
      let ty = match target {
        Some(rt) =>
          match internalize(ctx.type_context, ctx.diagnostics, Ref(rt)) {
            Some(c) => c
            None => @infer.Cell::make(@infer.InferredType::Error)
          }
        None => @infer.Cell::make(@infer.InferredType::Error)
      }
      {
        desc: StructDefaultDesc(desc_),
        info: annotate([ty], loc),
        hints: i.hints,
        expected: i.expected,
      }
    }

    // --- Casting through a descriptor ---
    CastDesc(value, nullable, desc) => {
      // Emission order: the value, then the descriptor on top of it.
      let value_ = self.expression(value)
      let desc_ = self.expression(desc)
      let target = descriptor_reftype(
        ctx,
        desc.info,
        nullable~,
        expression_type(ctx, desc_.info),
      )
      let ty = match target {
        Some(rt) => {
          if internalize(ctx.type_context, ctx.diagnostics, Ref(rt)) is Some(w) {
            lint_ref_cast(
              ctx,
              loc,
              is_test=false,
              expression_type(ctx, value_.info).get(),
              w.get(),
              operand_location=Some(value.info),
            )
          }
          match internalize(ctx.type_context, ctx.diagnostics, Ref(rt)) {
            Some(c) => c
            None => @infer.Cell::make(@infer.InferredType::Error)
          }
        }
        None => @infer.Cell::make(@infer.InferredType::Error)
      }
      {
        desc: CastDesc(value_, nullable, desc_),
        info: annotate([ty], loc),
        hints: i.hints,
        expected: i.expected,
      }
    }

    // --- Branching on a descriptor cast ---
    BrOnCastDescEq(label, nullable, value, desc) =>
      self.desc_branch(i, label, nullable, value, desc, on_success=true)
    BrOnCastDescEqFail(label, nullable, value, desc) =>
      self.desc_branch(i, label, nullable, value, desc, on_success=false)

    // --- Writing an array element, or a table slot ---
    ArraySet(recv, index, value) if self.is_table_receiver(recv) => {
      guard recv.desc is Get(tabname) else { return self.poisoned(i) }
      // `tab[i] = v` on a TABLE name is `table.set`: the table is a static
      // immediate, not a value, so the receiver is never typed as one.
      note_use(ctx, ctx.tables, tabname)
      let (at, rt) = match ctx.tables.find_no_mark(tabname.name) {
        Some(t) => t
        None => (@wasm_types.AddressType::I32, { nullable: true, typ: Func })
      }
      let index_ = self.expression(index)
      check_subtype(
        ctx.type_context.subtyping_info(),
        ctx.diagnostics,
        index.info,
        expression_type(ctx, index_.info),
        address_cell(at),
      )
      let value_ = match
        internalize(ctx.type_context, ctx.diagnostics, Ref(rt)) {
        Some(want) => self.check(want, value)
        None => self.expression(value)
      }
      {
        desc: ArraySet(
          recv.map_info(_ => annotate([], recv.info)),
          index_,
          value_,
        ),
        info: annotate([], loc),
        hints: i.hints,
        expected: i.expected,
      }
    }
    ArraySet(recv, index, value) => {
      // Emission order: the array, the index, then the value.
      let recv_ = self.expression(recv)
      let index_ = self.expression(index)
      check_subtype(
        ctx.type_context.subtyping_info(),
        ctx.diagnostics,
        index.info,
        expression_type(ctx, index_.info),
        @infer.valtype_cell(@infer.i32_valtype),
      )
      let slot = self.element_slot(recv.info, expression_type(ctx, recv_.info))
      // Written at the UNPACKED width, as a struct field is: the array
      // remembers the narrow type, the value being stored does not have to.
      // Resolved before the value, so a literal stored there can take the
      // element type rather than having to name one.
      let want = match slot {
        Some(ft) => {
          if !ft.mut_ {
            immutable(ctx.diagnostics, loc, "array")
          }
          internalize(ctx.type_context, ctx.diagnostics, unpack_type(ft))
        }
        None => None
      }
      let value_ = match want {
        Some(w) => self.check(w, value)
        None => self.expression(value)
      }
      {
        desc: ArraySet(recv_, index_, value_),
        info: annotate([], loc),
        hints: i.hints,
        expected: i.expected,
      }
    }

    // --- Conditional compilation inside a body ---
    IfAnnotation(cond~, then_body~, else_body~) => {
      // Each branch is typed as an isolated block UNDER ITS OWN ASSUMPTION, so
      // names resolve per branch: one may be declared only in the matching
      // configuration, or declared there with a different type.
      let then_ = with_cond(ctx, loc, cond, true, () => {
        self.body(loc, None, [], [], [], then_body.desc)
      })
      let else_ = match else_body {
        Some(b) => {
          let checked = with_cond(ctx, loc, cond, false, () => {
            self.body(loc, None, [], [], [], b.desc)
          })
          Some(
            (
              { desc: checked, info: b.info } :
              @basic.Annotated[
                Array[@ast.Instr[@typing_env.InferredAnnotation]],
                @basic.Location,
              ]),
          )
        }
        None => None
      }
      {
        desc: IfAnnotation(
          cond~,
          then_body={ desc: then_, info: then_body.info },
          else_body=else_,
        ),
        info: annotate([], loc),
        hints: i.hints,
        expected: i.expected,
      }
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
/// Annotate a node's children and leave its own values unknown.
///
/// Reached only when a lowering could not be peeled back, or a block's declared
/// shape did not resolve. The children are still walked, so the failure costs
/// the annotation of one node and nothing below it -- and it does NOT guess: an
/// empty annotation says "this produced nothing we know of", which is the
/// truth.
fn Checker::placeholder(
  self : Checker,
  i : @ast.Instr[@basic.Location],
) -> @ast.Instr[@typing_env.InferredAnnotation] {
  {
    desc: i.desc.map_desc(instr=s => self.expression(s), block=b => {
      b.map(s => self.statement(s))
    }),
    info: annotate([], i.info),
    hints: i.hints,
    expected: i.expected,
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
      for c in self.block_contents(results, instrs) {
        checked.push(c)
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

///|
/// Bind one name of a `let` to one value of its initializer.
///
/// With an annotation the value is checked against it, and the local takes the
/// ANNOTATION's type -- which is the point of writing one: it may be wider than
/// what the initializer happens to produce.
///
/// Without one the local takes the value's own type, resolved to a width, since
/// a local has to have one even where the value it was given has not committed.
fn Checker::bind(
  self : Checker,
  location : @basic.Location,
  binding : (@ast.Ident?, @wasm_types.ValType[@ast.Ident]?),
  value : @infer.Cell[@infer.InferredType],
) -> Unit {
  let ctx = self.ctx
  match binding.1 {
    Some(typ) => {
      guard internalize_valtype(ctx.type_context, ctx.diagnostics, typ)
        is Some(ity) else {
        return
      }
      check_subtype(
        ctx.type_context.subtyping_info(),
        ctx.diagnostics,
        location,
        value,
        @infer.valtype_cell(ity),
      )
      if binding.0 is Some(name) {
        bind_local(ctx, name, Some(ity))
      }
    }
    None =>
      if binding.0 is Some(name) {
        bind_local(ctx, name, bound_value_type(ctx, location, value))
      }
  }
}

///|
/// The struct type a receiver refers to, as its declared fields.
///
/// `None` with a complaint already made. The three no-answer cases are three
/// different things: an `Error` receiver has been reported elsewhere and is
/// left alone, an `Unknown` or bottom-reference one has a type nobody can name,
/// and anything else is simply not a struct.
fn Checker::receiver_fields(
  self : Checker,
  location : @basic.Location,
  ty : @infer.Cell[@infer.InferredType],
  field : @ast.Ident,
) -> Array[
  @basic.Annotated[
    (@ast.Ident, @wasm_types.MutType[@wasm_types.StorageType[@ast.Ident]]),
    @basic.Location,
  ],
]? {
  let ctx = self.ctx
  match ty.get() {
    Valtype({ typ: Ref({ typ: Type(name) | Exact(name), .. }), .. }) =>
      match ctx.types.find_no_mark(name.name) {
        Some((_, def)) =>
          match def.typ {
            Struct(fields) => Some(fields)
            _ => {
              // A name that is an instruction method was almost certainly meant
              // as the parenthesised call.
              if is_unary_method(field.name) {
                method_needs_parentheses(ctx.diagnostics, field.loc, field.name)
              } else {
                expected_struct(ctx.diagnostics, location)
              }
              None
            }
          }
        None => None
      }
    // Already reported where it failed; nothing more to say.
    Error => None
    Unknown | UnknownRef => {
      unknown_operand_type(ctx.diagnostics, location)
      None
    }
    _ => {
      if is_unary_method(field.name) {
        method_needs_parentheses(ctx.diagnostics, field.loc, field.name)
      } else {
        expected_struct(ctx.diagnostics, location)
      }
      None
    }
  }
}

///|
/// The declared slot of a named field on a receiver.
fn Checker::field_slot(
  self : Checker,
  location : @basic.Location,
  ty : @infer.Cell[@infer.InferredType],
  field : @ast.Ident,
) -> @wasm_types.MutType[@wasm_types.StorageType[@ast.Ident]]? {
  guard self.receiver_fields(location, ty, field) is Some(fields) else {
    return None
  }
  match find_field(fields, field.name) {
    Some((_, ft)) => Some(ft)
    None => {
      missing_field(self.ctx.diagnostics, field.loc, field.name)
      None
    }
  }
}

///|
/// The type reading a named field produces.
fn Checker::field_type_of(
  self : Checker,
  location : @basic.Location,
  ty : @infer.Cell[@infer.InferredType],
  field : @ast.Ident,
) -> @infer.Cell[@infer.InferredType] {
  match self.field_slot(location, ty, field) {
    Some(ft) =>
      match field_read_type(self.ctx.type_context, self.ctx.diagnostics, ft) {
        Some(c) => c
        None => @infer.Cell::make(@infer.InferredType::Error)
      }
    None => @infer.Cell::make(@infer.InferredType::Error)
  }
}

///|
/// The element slot of an array receiver.
fn Checker::element_slot(
  self : Checker,
  location : @basic.Location,
  ty : @infer.Cell[@infer.InferredType],
) -> @wasm_types.MutType[@wasm_types.StorageType[@ast.Ident]]? {
  let ctx = self.ctx
  match ty.get() {
    Valtype({ typ: Ref({ typ: Type(name) | Exact(name), .. }), .. }) =>
      lookup_array_type(
        ctx.type_context,
        ctx.diagnostics,
        name,
        location=Some(location),
      )
    Error => None
    Unknown | UnknownRef => {
      unknown_operand_type(ctx.diagnostics, location)
      None
    }
    _ => {
      expected_array(ctx.diagnostics, location)
      None
    }
  }
}

///|
/// Check a struct literal's field values against the type's declaration.
///
/// Walked in DECLARATION order, not source order, because that is the order the
/// values are pushed and the order the lowering emits them. A source field with
/// no counterpart in the declaration is left untyped: the construction is being
/// rejected anyway, and its slot in the pending values is simply dropped.
///
/// A punned field -- `{x}` for `{x: x}` -- carries no written value, and stays
/// that way in the typed AST so the printer re-emits the pun. Its value is the
/// like-named variable, which is checked like any other.
fn Checker::struct_fields(
  self : Checker,
  location : @basic.Location,
  declared : Array[
    @basic.Annotated[
      (@ast.Ident, @wasm_types.MutType[@wasm_types.StorageType[@ast.Ident]]),
      @basic.Location,
    ],
  ]?,
  fields : Array[(@ast.Ident, @ast.Instr[@basic.Location]?)],
) -> Array[(@ast.Ident, @ast.Instr[@typing_env.InferredAnnotation]?)] {
  let ctx = self.ctx
  let out : Array[(@ast.Ident, @ast.Instr[@typing_env.InferredAnnotation]?)] = []
  guard declared is Some(declared) else {
    // Unresolved type: still type the values, so they consume their stack slots
    // and their own mistakes are still reported.
    for f in fields {
      out.push((f.0, self.field_value(f.0, f.1).map(c => c)))
    }
    return out
  }
  if fields.length() > declared.length() {
    field_count_mismatch(
      ctx.diagnostics,
      location,
      expected=declared.length(),
      provided=fields.length(),
    )
  }
  // Paired with the declared fields first, in DECLARED order: that is the
  // order the values are emitted in, whatever order they were written.
  let slots : Array[
    (
      @ast.Ident,
      @ast.Instr[@basic.Location]?,
      @infer.Cell[@infer.InferredType]?,
    ),
  ] = []
  for d in declared {
    let want = d.desc.0
    let mut found : (@ast.Ident, @ast.Instr[@basic.Location]?)? = None
    for f in fields {
      if f.0.name == want.name {
        found = Some(f)
      }
    }
    match found {
      None => missing_field(ctx.diagnostics, location, want.name)
      Some((fname, written)) =>
        // The field's declared type, at the width a WRITE takes, is resolved
        // BEFORE the value is typed -- that is what lets a nested literal there
        // take it as its own type rather than having to name one.
        slots.push(
          (
            fname,
            written,
            internalize(
              ctx.type_context,
              ctx.diagnostics,
              unpack_type(d.desc.1),
            ),
          ),
        )
    }
  }
  // A field value that reads the incoming stack -- a hole, or anything built
  // over one -- has to be reached before the fields emitted BEFORE it, or they
  // take the values meant for it. The same backwards pass a sequence and a
  // call's arguments need, and for the same reason; here it is DECLARED order
  // that is walked backwards, since that is the order the fields are emitted
  // in. A struct written `{S| y: _, x: _}` over a stack of `1; 2.0` therefore
  // pairs `x` with the `1` and `y` with the `2.0`, not the other way round.
  let taken : Map[Int, @ast.Instr[@typing_env.InferredAnnotation]?] = Map([])
  for k = slots.length() - 1; k >= 0; k = k - 1 {
    let (fname, written, cell) = slots[k]
    if written is Some(w) && contains_hole(w) {
      taken[k] = self.field_value(fname, written, expect=cell)
    }
  }
  for k, s in slots {
    let (fname, written, cell) = s
    let checked = match taken.get(k) {
      Some(c) => c
      None => self.field_value(fname, written, expect=cell)
    }
    // Punning preserved: a field with no written value stays without one.
    out.push((fname, if written is Some(_) { checked } else { None }))
  }
  out
}

///|
/// Type a struct-literal field's value.
///
/// A punned field stands for the like-named variable, so it is typed as an
/// explicit read of it. The pun is a spelling, not a different construct.
fn Checker::field_value(
  self : Checker,
  name : @ast.Ident,
  written : @ast.Instr[@basic.Location]?,
  expect? : @infer.Cell[@infer.InferredType]? = None,
) -> @ast.Instr[@typing_env.InferredAnnotation]? {
  let e = match written {
    Some(e) => e
    None => {
      @typing_env.record_pun(self.ctx.pun_spans, name.loc)
      (
        {
          desc: Get(name),
          info: name.loc,
          hints: { branch: None, freq: None, targets: None },
          expected: None,
        } : @ast.Instr[@basic.Location])
    }
  }
  match expect {
    Some(cell) => Some(self.check(cell, e))
    None => Some(self.expression(e))
  }
}

///|
/// The element type an array construction stores at, at the width a WRITE
/// takes.
///
/// Resolved before the element values are typed, so a nested literal among them
/// can be inferred from it and drop its own name. `None` when the array type is
/// missing or does not resolve; the values are still typed, just unchecked.
fn Checker::element_of(
  self : Checker,
  location : @basic.Location,
  name : @ast.Ident?,
) -> @infer.Cell[@infer.InferredType]? {
  guard name is Some(n) else {
    cannot_infer_array_type(self.ctx.diagnostics, location)
    return None
  }
  guard lookup_array_type(self.ctx.type_context, self.ctx.diagnostics, n)
    is Some(field) else {
    return None
  }
  internalize(self.ctx.type_context, self.ctx.diagnostics, unpack_type(field))
}

///|
/// The reference an allocation produces, or `Error` when its type is unusable.
///
/// A missing name was already reported by `element_of`, so this stays quiet:
/// one construction with no type is one complaint.
fn Checker::allocated(
  self : Checker,
  location : @basic.Location,
  name : @ast.Ident?,
) -> @infer.Cell[@infer.InferredType] {
  ignore(location)
  match name {
    Some(n) =>
      match construction_result(self.ctx, n) {
        Some(c) => c
        None => @infer.Cell::make(@infer.InferredType::Error)
      }
    None => @infer.Cell::make(@infer.InferredType::Error)
  }
}

///|
/// Mint a function type for an inline `&fn(..)` cast target.
///
/// The name is synthesized and unwritable -- it begins with `<` -- so it cannot
/// collide with anything the author declared, and it exists only so the target
/// has an index to point at. The renderer shows the composite type instead of
/// the name, which is why `anon_comptype` rides along with it.
fn Checker::inline_functype(
  self : Checker,
  location : @basic.Location,
  sign : @ast.FuncType,
) -> @ast.Ident? {
  let name = "<fn:" + location.start.cnum.to_string() + ">"
  let id : @ast.Ident = { name, loc: location }
  match
    add_type(self.ctx.type_context, self.ctx.diagnostics, [
      {
        desc: (
          id,
          {
            typ: Func(sign),
            supertype: None,
            final_: true,
            descriptor: None,
            describes: None,
          },
        ),
        info: location,
      },
    ]) {
    Some(_) => Some(id)
    None => None
  }
}

///|
/// A tag's payload as cells: what a handler for it is entered on.
///
/// `None` when the tag or one of its parameter types does not resolve; the
/// failure was reported, and inventing a payload would only cascade.
fn Checker::tag_payload(
  self : Checker,
  tag : @ast.Ident,
) -> Array[@infer.Cell[@infer.InferredType]]? {
  let ctx = self.ctx
  guard find(ctx.tags, ctx.diagnostics, tag) is Some(ft) else { return None }
  // A tag describes what is thrown, and a throw does not return.
  if !ft.results.is_empty() {
    tag_with_results(ctx.diagnostics, tag.loc)
  }
  let out : Array[@infer.Cell[@infer.InferredType]] = []
  for p in ft.params {
    guard internalize(ctx.type_context, ctx.diagnostics, p.desc.1) is Some(c) else {
      return None
    }
    out.push(c)
  }
  Some(out)
}

///|
/// The entry stack of one `try`/`catch` arm: the tag's payload, plus the
/// non-null `&exn` when the arm asked to bind it.
///
/// A catch-all arm names no tag and is entered on nothing -- except the
/// exception itself, if it asked for it.
fn Checker::arm_entry(
  self : Checker,
  arm : @ast.TryCatchArm[@basic.Location],
) -> Array[@infer.Cell[@infer.InferredType]]? {
  let payload = match arm.arm_tag {
    Some(tag) =>
      match self.tag_payload(tag) {
        Some(p) => p
        None => return None
      }
    None => []
  }
  guard arm.arm_ref else { return Some(payload) }
  guard internalize(
      self.ctx.type_context,
      self.ctx.diagnostics,
      Ref({ nullable: false, typ: Exn }),
    )
    is Some(e) else {
    return None
  }
  let all = payload.copy()
  all.push(e)
  Some(all)
}

///|
/// Peel a checked `while` lowering back to its condition, step and body.
///
/// Deterministic: the shape is the one `lower_while` produced a moment ago.
/// `None` only when recovery from an error inside it produced something else,
/// in which case the caller keeps the original rather than crashing on a shape
/// nobody promised.
pub fn peel_while(
  typed : Array[@ast.Instr[@typing_env.InferredAnnotation]],
  stepped~ : Bool,
  labelled~ : Bool,
) -> (
  @ast.Instr[@typing_env.InferredAnnotation],
  @ast.Instr[@typing_env.InferredAnnotation]?,
  Array[@ast.Instr[@typing_env.InferredAnnotation]],
)? {
  guard typed.length() == 1 else { return None }
  guard typed[0].desc is Loop(block=outer, ..) else { return None }
  guard outer.desc.length() == 1 else { return None }
  guard outer.desc[0].desc is If(cond~, if_block~, ..) else { return None }
  let body = if_block.desc
  if stepped && labelled {
    // The labelled form wraps the body in a block of its own, so the label has
    // something to name: `block { body } ; step ; br`.
    guard body.length() == 3 else { return None }
    guard body[0].desc is Block(block=inner, ..) else { return None }
    guard body[2].desc is Br(_, _) else { return None }
    return Some((cond, Some(body[1]), inner.desc))
  }
  // Otherwise the body is inline, ending in the back edge -- preceded by the
  // step when there is one.
  guard body.length() >= 1 else { return None }
  guard body[body.length() - 1].desc is Br(_, _) else { return None }
  if stepped {
    guard body.length() >= 2 else { return None }
    Some(
      (
        cond,
        Some(body[body.length() - 2]),
        body[0:body.length() - 2].to_owned(),
      ),
    )
  } else {
    Some((cond, None, body[0:body.length() - 1].to_owned()))
  }
}

///|
/// Check a run of instructions as STATEMENTS, pushing what each leaves.
///
/// This is the only place values reach the operand stack, and that distinction
/// is the one the checker turns on. An instruction checked as a STATEMENT
/// leaves its results for the next one; an instruction checked as an OPERAND
/// hands its type back through its annotation and touches no stack. Pushing
/// inside `statement` itself -- which is what this used to do -- left every
/// consumed operand behind, and a `while`'s condition showed up as a value
/// remaining on the stack.
pub fn Checker::statements(
  self : Checker,
  instrs : Array[@ast.Instr[@basic.Location]],
) -> Array[@ast.Instr[@typing_env.InferredAnnotation]] {
  let out : Array[@ast.Instr[@typing_env.InferredAnnotation]] = []
  for s in instrs {
    let c = self.statement(s)
    self.ops.push_results(s.info, c.info.0)
    out.push(c)
  }
  out
}

///|
/// Peel a checked `dispatch` lowering back to its index and arm bodies.
///
/// The lowering nests one block per arm, each holding the block for the
/// PREVIOUS arm followed by that previous arm's body, with the `br_table` at
/// the centre. So descending from the outside walks the arms in reverse, and
/// the last arm's body is the trailing code after the outermost block rather
/// than inside anything.
pub fn peel_dispatch(
  typed : Array[@ast.Instr[@typing_env.InferredAnnotation]],
  arm_count : Int,
) -> (
  @ast.Instr[@typing_env.InferredAnnotation],
  Array[Array[@ast.Instr[@typing_env.InferredAnnotation]]],
)? {
  if arm_count == 0 {
    guard typed.length() == 1 else { return None }
    guard typed[0].desc is BrTable(_, index) else { return None }
    return Some((index, []))
  }
  guard typed.length() >= 1 else { return None }
  // Everything after the outermost block is the LAST arm's body.
  let bodies : Array[Array[@ast.Instr[@typing_env.InferredAnnotation]]] = Array::make(
    arm_count,
    [],
  )
  bodies[arm_count - 1] = typed[1:].to_owned()
  let mut node = typed[0]
  for k = arm_count - 1; k > 0; k = k - 1 {
    guard node.desc is Block(block~, ..) else { return None }
    guard block.desc.length() >= 1 else { return None }
    bodies[k - 1] = block.desc[1:].to_owned()
    node = block.desc[0]
  }
  // The innermost block holds the `br_table`, and with it the typed index.
  guard node.desc is Block(block~, ..) else { return None }
  guard block.desc.length() == 1 else { return None }
  guard block.desc[0].desc is BrTable(_, index) else { return None }
  Some((index, bodies))
}

///|
/// The non-null form of a reference, for the path where it is known not to be
/// null.
///
/// A polymorphic value or a bare `null` yields the bottom reference. That is a
/// well-defined answer rather than a contradiction: `br_on_null` on a bare null
/// always branches, so the fall-through is unreachable and any reference type
/// satisfies it.
fn Checker::non_null_of(
  self : Checker,
  location : @basic.Location,
  ty : @infer.Cell[@infer.InferredType],
) -> @infer.Cell[@infer.InferredType] {
  match ty.get() {
    Valtype({ typ: Ref(r), internal: Ref(ir), anon_comptype }) => {
      let v : @infer.InferredValType = {
        typ: Ref({ nullable: false, typ: r.typ }),
        internal: Ref({ nullable: false, typ: ir.typ }),
        anon_comptype,
      }
      @infer.Cell::make(@infer.InferredType::Valtype(v))
    }
    Unknown | UnknownRef | Null =>
      @infer.Cell::make(@infer.InferredType::UnknownRef)
    Error => @infer.Cell::make(@infer.InferredType::Error)
    _ => {
      expected_ref(self.ctx.diagnostics, location)
      @infer.Cell::make(@infer.InferredType::Error)
    }
  }
}

///|
/// Peel a checked `match` lowering back to its arm bodies, default and
/// scrutinee.
///
/// The lowering nests one block per arm inside an outer escape block, each
/// wrapping the previous block -- whose result the previous arm consumes --
/// then that arm's body. So descending from the escape block meets the arms in
/// REVERSE source order, and the innermost block holds the threaded test chain
/// with the scrutinee at its bottom.
pub fn peel_match(
  typed : Array[@ast.Instr[@typing_env.InferredAnnotation]],
  arm_count : Int,
) -> (
  Array[Array[@ast.Instr[@typing_env.InferredAnnotation]]],
  Array[@ast.Instr[@typing_env.InferredAnnotation]],
  @ast.Instr[@typing_env.InferredAnnotation]?,
)? {
  // No arms: the lowering IS the default, and the scrutinee never appears in it.
  if arm_count == 0 {
    return Some(([], typed, None))
  }
  guard typed.length() >= 1 else { return None }
  guard typed[0].desc is Block(block=escape, ..) else { return None }
  let default_body = typed[1:].to_owned()
  let bodies : Array[Array[@ast.Instr[@typing_env.InferredAnnotation]]] = Array::makei(
    arm_count,
    _ => [],
  )
  let mut contents = escape.desc
  for k = arm_count - 1; k >= 0; k = k - 1 {
    guard contents.length() >= 1 else { return None }
    // The wrapped block is bound by a `let` for a cast arm -- which names what
    // it matched -- and stands bare for a null arm, which binds nothing.
    let inner = match contents[0].desc {
      Let(_, Some(b)) => b
      _ => contents[0]
    }
    bodies[k] = contents[1:].to_owned()
    guard inner.desc is Block(block~, ..) else { return None }
    if k == 0 {
      // The innermost block holds the test chain and the escape branch.
      guard block.desc.length() >= 1 else { return None }
      guard block.desc[0].desc is Let(_, Some(chain)) else { return None }
      return Some((bodies, default_body, Some(peel_chain(chain))))
    }
    contents = block.desc
  }
  None
}

///|
/// The scrutinee at the bottom of a threaded test chain.
///
/// Each test passes the value through to the next, so the innermost operand is
/// the one the author wrote -- typed once, inside the chain, rather than a
/// second time out here.
fn peel_chain(
  chain : @ast.Instr[@typing_env.InferredAnnotation],
) -> @ast.Instr[@typing_env.InferredAnnotation] {
  match chain.desc {
    BrOnCast(_, _, inner) | BrOnNull(_, inner) => peel_chain(inner)
    _ => chain
  }
}

///|
/// Type a call: the callee, its arguments, and what it leaves behind.
///
/// The callee is typed FIRST, out of emission order -- the arguments are pushed
/// before it at run time. That inversion is deliberate: the callee's function
/// type is what gives the parameter types the arguments are checked against, so
/// typing it first is what lets an argument that is a struct or array literal
/// be inferred from the parameter and drop its own name.
fn Checker::call(
  self : Checker,
  location : @basic.Location,
  callee : @ast.Instr[@basic.Location],
  args : Array[@ast.Instr[@basic.Location]],
) -> (
  @ast.Instr[@typing_env.InferredAnnotation],
  Array[@ast.Instr[@typing_env.InferredAnnotation]],
  Array[@infer.Cell[@infer.InferredType]],
  Bool,
) {
  let ctx = self.ctx
  // The callee is typed FIRST, because its function type is what the arguments
  // are checked against -- but it is EMITTED LAST, after them, since `call_ref`
  // takes the reference off the top of the stack. So its reads of locals are
  // deferred to that slot (an argument may initialize one first) and its own
  // writes are withheld from it (an argument runs before it and must not see
  // them). `replay` below puts both back in the right place.
  let (callee_, replay) = type_trailing_operand(ctx, () => {
    self.expression(callee)
  })
  // Asked ONCE: `expression_type` reports a callee that produces no value or
  // several, so asking twice would report it twice.
  let callee_type = expression_type(ctx, callee_.info)
  let functype = match callee_type.get() {
    Valtype({ typ: Ref({ typ: Type(n) | Exact(n), .. }), .. }) =>
      // Anchored at the TYPE NAME, not at the whole callee: what is wrong is
      // the type, and the reader has to look at where it was named to see it.
      lookup_func_type(ctx.type_context, ctx.diagnostics, n)
    _ => None
  }
  let params : Array[@infer.Cell[@infer.InferredType]] = []
  let mut have_params = false
  if functype is Some(ft) {
    have_params = true
    for p in ft.params {
      match internalize(ctx.type_context, ctx.diagnostics, p.desc.1) {
        Some(c) => params.push(c)
        None => have_params = false
      }
    }
  }
  // The arguments are typed in EMISSION order, whatever order their types were
  // worked out in.
  let args_ : Array[@ast.Instr[@typing_env.InferredAnnotation]] = []
  // Checked against the parameter when there is one, so a literal argument can
  // take the parameter's type as its own; synthesized when the arity does not
  // line up, since then no argument is reliably paired with any parameter.
  let paired = have_params && params.length() == args.length()
  // An argument that reads the incoming stack -- a hole, or anything built
  // over one -- has to be reached before the arguments to its LEFT, or they
  // take the values meant for it. Everything else is typed in written order,
  // which is the order it is emitted in.
  let taken : Map[Int, @ast.Instr[@typing_env.InferredAnnotation]] = Map([])
  for k = args.length() - 1; k >= 0; k = k - 1 {
    if contains_hole(args[k]) {
      taken[k] = if paired {
        self.check(params[k], args[k])
      } else {
        self.expression(args[k])
      }
    }
  }
  for k, a in args {
    let c = match taken.get(k) {
      Some(c) => c
      None => if paired { self.check(params[k], a) } else { self.expression(a) }
    }
    if have_params && !paired && k < params.length() {
      check_subtype(
        ctx.type_context.subtyping_info(),
        ctx.diagnostics,
        a.info,
        expression_type(ctx, c.info),
        params[k],
      )
    }
    args_.push(c)
  }
  // The callee's emission slot: after every argument.
  replay()
  let results : Array[@infer.Cell[@infer.InferredType]] = match
    callee_type.get() {
    Valtype({ typ: Ref({ typ: Type(_) | Exact(_), .. }), .. }) =>
      match functype {
        // `lookup_func_type` already said the named type is not a function.
        None => [@infer.Cell::make(@infer.InferredType::Error)]
        Some(ft) => {
          if have_params && params.length() != args.length() {
            operand_count_mismatch(
              ctx.diagnostics,
              callee.info,
              expected=params.length(),
              provided=args.length(),
            )
          }
          let out : Array[@infer.Cell[@infer.InferredType]] = []
          for r in ft.results {
            match internalize(ctx.type_context, ctx.diagnostics, r) {
              Some(c) => out.push(c)
              None => ()
            }
          }
          out
        }
      }
    // The callee already failed to type -- an unbound name, say. Recover
    // silently rather than adding a spurious "expected function".
    Error => [@infer.Cell::make(@infer.InferredType::Error)]
    Unknown | UnknownRef => {
      unknown_operand_type(ctx.diagnostics, callee.info)
      [@infer.Cell::make(@infer.InferredType::Error)]
    }
    _ => {
      expected_func(ctx.diagnostics, callee.info)
      [@infer.Cell::make(@infer.InferredType::Error)]
    }
  }
  ignore(location)
  // The last component says the callee named a type that is NOT a function --
  // already reported, and there is no call to build.
  (
    callee_,
    args_,
    results,
    callee_type.get()
    is Valtype({ typ: Ref({ typ: Type(_) | Exact(_), .. }), .. }) &&
    functype is None,
  )
}

///|
/// Type a memory load or store written as `mem.load32(addr, offset: 16)`.
///
/// The stack operands come first -- an address, and a value for a store -- and
/// the alignment and offset are LABELLED immediates rather than operands, since
/// they are constants in the instruction rather than values on the stack.
fn Checker::mem_access(
  self : Checker,
  location : @basic.Location,
  memname : @ast.Ident,
  meth : @ast.Ident,
  args : Array[@ast.Instr[@basic.Location]],
) -> (
  Array[@ast.Instr[@typing_env.InferredAnnotation]],
  Array[@infer.Cell[@infer.InferredType]],
) {
  let ctx = self.ctx
  note_use(ctx, ctx.memories, memname)
  let address_type = match ctx.memories.find_no_mark(memname.name) {
    Some((_, at)) => at
    None => @wasm_types.AddressType::I32
  }
  let addr_cell = @infer.valtype_cell(
    match address_type {
      I32 => @infer.i32_valtype
      I64 => @infer.i64_valtype
    },
  )
  let is_store = mem_store_method(meth.name)
  let nstack = if is_store { 2 } else { 1 }
  let split = split_labelled_args(args)
  let found = take_labels(ctx.diagnostics, ["offset", "align"], split.labelled)
  let example = memname.name + "." + meth.name + "(..., offset: 16, align: 1)"
  let (_, align, offset) = mem_immediates(
    ctx.diagnostics,
    location,
    example,
    nstack,
    has_lane=false,
    found,
    split.positional,
  )
  let checked : Array[@ast.Instr[@typing_env.InferredAnnotation]] = []
  for k, a in split.positional {
    let c = self.expression(a)
    let ty = expression_type(ctx, c.info)
    if k == 0 {
      // The address is checked against the MEMORY's address type, which is what
      // makes a 64-bit memory take an i64 index.
      check_subtype(
        ctx.type_context.subtyping_info(),
        ctx.diagnostics,
        a.info,
        ty,
        addr_cell,
      )
    } else if k == 1 && is_store {
      self.check_stored_value(a.info, meth, ty)
    }
    checked.push(c)
  }
  check_memarg(
    ctx.diagnostics,
    address_type,
    mem_natural_align(meth.name),
    align,
    offset,
  )
  // The immediates are kept on the typed node, re-wrapped with their labels.
  // They are not values -- nothing pushes them -- but they ARE part of the
  // instruction, and the code generator has no other place to read them from.
  for entry in split.labelled {
    let (label, value) = entry
    checked.push({
      desc: Labelled(label, {
        desc: value.desc.map_desc(
          instr=_ => abort("a memory immediate has no sub-instructions"),
          block=_ => abort("a memory immediate has no blocks"),
        ),
        info: annotate([], value.info),
        hints: value.hints,
        expected: value.expected,
      }),
      info: annotate([], value.info),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    })
  }
  let results = if is_store {
    []
  } else {
    match mem_load_result(meth.name) {
      Some(t) => [@infer.Cell::make(t)]
      None => []
    }
  }
  (checked, results)
}

///|
/// Check the value a store writes.
///
/// The wide stores demand their exact width. The NARROWING ones -- `store8`,
/// `store16`, `store32` -- wrap, so they take an i64-wide value too, including
/// a literal too large for an i32: writing the low bytes of a big number is
/// what they are for.
fn Checker::check_stored_value(
  self : Checker,
  location : @basic.Location,
  meth : @ast.Ident,
  ty : @infer.Cell[@infer.InferredType],
) -> Unit {
  let ctx = self.ctx
  let want = match meth.name {
    "store64" => Some(@infer.i64_valtype)
    "storef32" => Some(@infer.f32_valtype)
    "storef64" => Some(@infer.f64_valtype)
    _ => None
  }
  match want {
    Some(v) =>
      check_subtype(
        ctx.type_context.subtyping_info(),
        ctx.diagnostics,
        location,
        ty,
        @infer.valtype_cell(v),
      )
    None =>
      match ty.get() {
        Valtype({ internal: I32 | I64, .. })
        | Int
        | Number
        | LargeInt
        | Unknown
        | Error => ()
        _ =>
          expression_type_mismatch(
            ctx.diagnostics,
            location,
            ty,
            @infer.Cell::make(Int),
          )
      }
  }
}

///|
/// Whether a call is a plain memory load or store.
///
/// Both halves have to hold: the method name has to be one of the accesses, and
/// the receiver has to actually be a memory -- a local named `mem` shadows it
/// and makes this an ordinary call.
fn Checker::is_mem_access(
  self : Checker,
  callee : @ast.Instr[@basic.Location],
) -> Bool {
  guard callee.desc is StructGet(recv, meth) else { return false }
  guard recv.desc is Get(memname) else { return false }
  classify_method_call(self.ctx, memname, meth.name) is MemAccess
}

///|
/// Whether a call manages a memory (`Some(true)`) or a table (`Some(false)`).
///
/// The same five method names serve both, so only the RECEIVER tells them
/// apart -- `size` on a memory counts pages, `size` on a table counts elements.
fn contains_hole(i : @ast.Instr[@basic.Location]) -> Bool {
  if i.desc is Hole {
    return true
  }
  for sub in i.sub_instrs() {
    if contains_hole(sub) {
      return true
    }
  }
  false
}

///|
/// `atomic::fence()`: the one atomic with no memory operand and no memarg.
fn is_atomic_fence(callee : @ast.Instr[@basic.Location]) -> Bool {
  guard callee.desc is Path(ns, name) else { return false }
  ns.name == "atomic" && name.name == "fence"
}

///|
/// `seg.drop()` names a segment, which is not a value.
fn Checker::segment_drop(
  self : Checker,
  callee : @ast.Instr[@basic.Location],
) -> Bool {
  guard callee.desc is StructGet(recv, meth) else { return false }
  guard recv.desc is Get(name) else { return false }
  classify_method_call(self.ctx, name, meth.name) is SegmentDrop
}

///|
fn Checker::mgmt_kind(
  self : Checker,
  callee : @ast.Instr[@basic.Location],
) -> Bool? {
  guard callee.desc is StructGet(recv, meth) else { return None }
  guard recv.desc is Get(name) else { return None }
  match classify_method_call(self.ctx, name, meth.name) {
    MemManage => Some(true)
    TableManage => Some(false)
    _ => None
  }
}

///|
/// The cell for an address type: what indexes a memory or table of that width.
fn address_cell(
  at : @wasm_types.AddressType,
) -> @infer.Cell[@infer.InferredType] {
  @infer.valtype_cell(
    match at {
      I32 => @infer.i32_valtype
      I64 => @infer.i64_valtype
    },
  )
}

///|
/// The NARROWER of two address types.
///
/// A cross-memory copy's length indexes both sides, so it has to fit whichever
/// is smaller -- typing it at the wider one would accept a length the narrow
/// side cannot address.
fn narrower(
  a : @wasm_types.AddressType,
  b : @wasm_types.AddressType,
) -> @wasm_types.AddressType {
  match (a, b) {
    (I64, I64) => I64
    _ => I32
  }
}

///|
/// Type a memory management call: `mem.size()`, `mem.grow(n)`, `mem.fill(..)`,
/// `mem.copy(..)`, `mem.init(seg, ..)`.
fn Checker::mem_mgmt(
  self : Checker,
  location : @basic.Location,
  name : @ast.Ident,
  meth : @ast.Ident,
  args : Array[@ast.Instr[@basic.Location]],
) -> (
  Array[@ast.Instr[@typing_env.InferredAnnotation]],
  Array[@infer.Cell[@infer.InferredType]],
) {
  let ctx = self.ctx
  note_use(ctx, ctx.memories, name)
  let at = match ctx.memories.find_no_mark(name.name) {
    Some((_, a)) => a
    None => @wasm_types.AddressType::I32
  }
  // A leading name argument is the OTHER memory of a copy, or the segment of an
  // init: it names a static operand rather than a value, so it is not typed as
  // an expression.
  let leading = if args.length() == 4 && args[0].desc is Get(n) {
    Some(n)
  } else {
    None
  }
  let rest = if leading is Some(_) { args[1:].to_owned() } else { args }
  let checked : Array[@ast.Instr[@typing_env.InferredAnnotation]] = []
  if leading is Some(n) {
    checked.push(args[0].map_info(_ => annotate([], args[0].info)))
    if meth.name == "init" {
      let _ = find(ctx.datas, ctx.diagnostics, n)
    }
  }
  let typed = rest.map(a => self.expression(a))
  for c in typed {
    checked.push(c)
  }
  fn want(k : Int, cell : @infer.Cell[@infer.InferredType]) -> Unit {
    if k < typed.length() {
      check_subtype(
        ctx.type_context.subtyping_info(),
        ctx.diagnostics,
        rest[k].info,
        expression_type(ctx, typed[k].info),
        cell,
      )
    }
  }

  let i32c = () => @infer.valtype_cell(@infer.i32_valtype)
  match (meth.name, leading, typed.length()) {
    ("size", None, 0) => (checked, [address_cell(at)])
    ("grow", None, 1) => {
      want(0, address_cell(at))
      (checked, [address_cell(at)])
    }
    ("fill", None, 3) => {
      want(0, address_cell(at))
      want(1, i32c())
      want(2, address_cell(at))
      (checked, [])
    }
    ("copy", None, 3) => {
      want(0, address_cell(at))
      want(1, address_cell(at))
      want(2, address_cell(at))
      (checked, [])
    }
    ("copy", Some(src), 3) => {
      note_use(ctx, ctx.memories, src)
      let src_at = match ctx.memories.find_no_mark(src.name) {
        Some((_, a)) => a
        None => at
      }
      want(0, address_cell(at))
      want(1, address_cell(src_at))
      want(2, address_cell(narrower(at, src_at)))
      (checked, [])
    }
    ("init", Some(_), 3) => {
      want(0, address_cell(at))
      want(1, i32c())
      want(2, i32c())
      (checked, [])
    }
    _ => {
      invalid_management_call(ctx.diagnostics, location, meth.name)
      // Recovered with a VALUE rather than nothing: `size` and `grow` produce
      // one, and claiming none would cascade into a spurious value-count
      // complaint wherever the call was used as an expression.
      (checked, [@infer.Cell::make(@infer.InferredType::Error)])
    }
  }
}

///|
/// Type a table management call. The same five names as a memory's, with the
/// element type standing where a memory has an i32 byte.
fn Checker::table_mgmt(
  self : Checker,
  location : @basic.Location,
  name : @ast.Ident,
  meth : @ast.Ident,
  args : Array[@ast.Instr[@basic.Location]],
) -> (
  Array[@ast.Instr[@typing_env.InferredAnnotation]],
  Array[@infer.Cell[@infer.InferredType]],
) {
  let ctx = self.ctx
  note_use(ctx, ctx.tables, name)
  let (at, rt) = match ctx.tables.find_no_mark(name.name) {
    Some(t) => t
    None => (@wasm_types.AddressType::I32, { nullable: true, typ: Func })
  }
  let elt = internalize(ctx.type_context, ctx.diagnostics, Ref(rt))
  let leading = if args.length() == 4 && args[0].desc is Get(n) {
    Some(n)
  } else {
    None
  }
  let rest = if leading is Some(_) { args[1:].to_owned() } else { args }
  let checked : Array[@ast.Instr[@typing_env.InferredAnnotation]] = []
  if leading is Some(n) {
    checked.push(args[0].map_info(_ => annotate([], args[0].info)))
    match meth.name {
      "init" =>
        if find(ctx.elems, ctx.diagnostics, n) is Some(src) {
          check_elem_subtype(ctx, location, src, rt)
        }
      "copy" =>
        if ctx.tables.find_no_mark(n.name) is Some((_, src_rt)) {
          check_elem_subtype(ctx, location, src_rt, rt)
        }
      _ => ()
    }
  }
  let typed = rest.map(a => self.expression(a))
  for c in typed {
    checked.push(c)
  }
  fn want(k : Int, cell : @infer.Cell[@infer.InferredType]) -> Unit {
    if k < typed.length() {
      check_subtype(
        ctx.type_context.subtyping_info(),
        ctx.diagnostics,
        rest[k].info,
        expression_type(ctx, typed[k].info),
        cell,
      )
    }
  }

  fn want_elt(k : Int) -> Unit {
    if elt is Some(e) {
      want(k, e)
    }
  }

  let i32c = () => @infer.valtype_cell(@infer.i32_valtype)
  match (meth.name, leading, typed.length()) {
    ("size", None, 0) => (checked, [address_cell(at)])
    ("grow", None, 2) => {
      want_elt(0)
      want(1, address_cell(at))
      (checked, [address_cell(at)])
    }
    ("fill", None, 3) => {
      want(0, address_cell(at))
      want_elt(1)
      want(2, address_cell(at))
      (checked, [])
    }
    ("copy", None, 3) => {
      want(0, address_cell(at))
      want(1, address_cell(at))
      want(2, address_cell(at))
      (checked, [])
    }
    ("copy", Some(src), 3) => {
      note_use(ctx, ctx.tables, src)
      let src_at = match ctx.tables.find_no_mark(src.name) {
        Some((a, _)) => a
        None => at
      }
      want(0, address_cell(at))
      want(1, address_cell(src_at))
      want(2, address_cell(narrower(at, src_at)))
      (checked, [])
    }
    ("init", Some(_), 3) => {
      want(0, address_cell(at))
      want(1, i32c())
      want(2, i32c())
      (checked, [])
    }
    _ => {
      invalid_management_call(ctx.diagnostics, location, meth.name)
      (checked, [@infer.Cell::make(@infer.InferredType::Error)])
    }
  }
}

///|
/// The atomic family a call belongs to, if any.
fn Checker::atomic_family(
  self : Checker,
  callee : @ast.Instr[@basic.Location],
) -> @atomics.Family? {
  guard callee.desc is StructGet(recv, meth) else { return None }
  guard recv.desc is Get(memname) else { return None }
  match classify_method_call(self.ctx, memname, meth.name) {
    Atomic(f) => Some(f)
    _ => None
  }
}

///|
/// Type an atomic memory operation.
///
/// The address comes first, then the value operands, then the labelled
/// immediates -- the same shape as an ordinary access, with one rule of its
/// own: an atomic access requires EXACTLY its natural alignment. For an
/// ordinary access the alignment is a promise the engine may ignore, so less
/// than natural is merely pessimistic; an atomic access that is not aligned is
/// not atomic, so anything but the exact value is rejected.
fn Checker::atomic_access(
  self : Checker,
  location : @basic.Location,
  memname : @ast.Ident,
  meth : @ast.Ident,
  family : @atomics.Family,
  args : Array[@ast.Instr[@basic.Location]],
) -> (
  Array[@ast.Instr[@typing_env.InferredAnnotation]],
  Array[@infer.Cell[@infer.InferredType]],
) {
  let ctx = self.ctx
  note_use(ctx, ctx.memories, memname)
  let address_type = match ctx.memories.find_no_mark(memname.name) {
    Some((_, at)) => at
    None => @wasm_types.AddressType::I32
  }
  let n_values = match family {
    Load(_) => 0
    Store(_) | Notify => 1
    Rmw(Cmpxchg, _) | Wait(_) => 2
    Rmw(_, _) => 1
  }
  let nstack = 1 + n_values
  let split = split_labelled_args(args)
  let found = take_labels(ctx.diagnostics, ["offset", "align"], split.labelled)
  let example = memname.name + "." + meth.name + "(..., offset: 16)"
  let (_, align, offset) = mem_immediates(
    ctx.diagnostics,
    location,
    example,
    nstack,
    has_lane=false,
    found,
    split.positional,
  )
  let checked : Array[@ast.Instr[@typing_env.InferredAnnotation]] = []
  let values : Array[@infer.Cell[@infer.InferredType]] = []
  let value_locs : Array[@basic.Location] = []
  for k, a in split.positional {
    let c = self.expression(a)
    let ty = expression_type(ctx, c.info)
    if k == 0 {
      check_subtype(
        ctx.type_context.subtyping_info(),
        ctx.diagnostics,
        a.info,
        ty,
        address_cell(address_type),
      )
    } else {
      values.push(ty)
      value_locs.push(a.info)
    }
    checked.push(c)
  }
  let i32c = () => @infer.valtype_cell(@infer.i32_valtype)
  let i64c = () => @infer.valtype_cell(@infer.i64_valtype)
  fn want(k : Int, cell : @infer.Cell[@infer.InferredType]) -> Unit {
    if k < values.length() {
      check_subtype(
        ctx.type_context.subtyping_info(),
        ctx.diagnostics,
        value_locs[k],
        values[k],
        cell,
      )
    }
  }

  // A narrow store or read-modify-write picks the i32/i64 family from its VALUE,
  // so either is accepted -- pinned to the integer group, with a still-flexible
  // literal defaulting to i32 as usual.
  fn integral(k : Int) -> @infer.Cell[@infer.InferredType] {
    guard k < values.length() else {
      return @infer.Cell::make(@infer.InferredType::Error)
    }
    let ty = values[k]
    match ty.get() {
      // A hole on the polymorphic stack is pinned to the flexible `Int` rather
      // than left unknown: the operation is concrete and has to be emitted, and
      // an unknown result would drop a cast around it instead of taking its
      // width. As `Int` it still defaults to i32 and can still be pinned wider.
      Unknown => {
        ty.set(Int)
        ty
      }
      Error => ty
      _ =>
        check_int_bin_op(
          ctx.diagnostics,
          value_locs[k],
          ty,
          @infer.Cell::make(Int),
        )
    }
  }

  let results : Array[@infer.Cell[@infer.InferredType]] = match family {
    Load(W8) => [@infer.Cell::make(Int8)]
    Load(W16) => [@infer.Cell::make(Int16)]
    Load(W32) => [i32c()]
    Load(W64) => [i64c()]
    Store(W64) => {
      want(0, i64c())
      []
    }
    Store(_) => {
      let _ = integral(0)

      []
    }
    Rmw(_, W64) => {
      for k in 0..<values.length() {
        want(k, i64c())
      }
      [i64c()]
    }
    Rmw(op, _) => {
      let vty = integral(0)
      // A compare-and-exchange's expected and replacement values must agree on
      // the family, so their cells are merged as a binary operator's would be.
      if op is Cmpxchg && values.length() >= 2 {
        if !(vty.get() is (Unknown | Error)) &&
          !(values[1].get() is (Unknown | Error)) {
          let _ = check_int_bin_op(
            ctx.diagnostics,
            value_locs[1],
            vty,
            values[1],
          )
        }
      }
      [vty]
    }
    Wait(t) => {
      want(
        0,
        match t {
          I32 => i32c()
          I64 => i64c()
        },
      )
      for k = 1; k < values.length(); k = k + 1 {
        want(k, i64c())
      }
      [i32c()]
    }
    Notify => {
      for k in 0..<values.length() {
        want(k, i32c())
      }
      [i32c()]
    }
  }
  let natural = @atomics.family_bytes(family)
  // Only the OFFSET is range-checked the ordinary way; the alignment has its
  // own, stricter rule below.
  check_memarg(ctx.diagnostics, address_type, natural, None, offset)
  if align is Some(a) {
    match int_literal_u64(a.desc) {
      Some(v) if v == natural.to_uint64() => ()
      _ => atomic_alignment(ctx.diagnostics, a.info, natural)
    }
  }
  (checked, results)
}

///|
/// The SIMD memory intrinsic a call names, if any.
fn Checker::simd_mem_intrinsic(
  self : Checker,
  callee : @ast.Instr[@basic.Location],
) -> @simd.MemIntrinsic? {
  guard callee.desc is StructGet(recv, meth) else { return None }
  guard recv.desc is Get(memname) else { return None }
  guard classify_method_call(self.ctx, memname, meth.name) is SimdMemAccess else {
    return None
  }
  @simd.mem_method(meth.name)
}

///|
/// The cell for a SIMD operand type.
fn simd_cell(t : @simd.Ty) -> @infer.Cell[@infer.InferredType] {
  match t {
    // `infer` carries no v128 constant, the type having no flexible form to
    // sit alongside -- a vector is only ever itself.
    TV128 =>
      @infer.valtype_cell({ typ: V128, internal: V128, anon_comptype: None })
    TI32 => @infer.valtype_cell(@infer.i32_valtype)
    TI64 => @infer.valtype_cell(@infer.i64_valtype)
    TF32 => @infer.valtype_cell(@infer.f32_valtype)
    TF64 => @infer.valtype_cell(@infer.f64_valtype)
  }
}

///|
/// Type a SIMD memory access: `mem.loadv128(a)`, `mem.load8_lane(a, v, lane: 0)`.
///
/// The lane-taking forms need their `lane:` immediate, and its bound comes from
/// the access WIDTH -- a `load8_lane` writes into one of sixteen byte lanes, a
/// `load64_lane` into one of two.
fn Checker::simd_mem_access(
  self : Checker,
  location : @basic.Location,
  memname : @ast.Ident,
  meth : @ast.Ident,
  mop : @simd.MemIntrinsic,
  args : Array[@ast.Instr[@basic.Location]],
) -> (
  Array[@ast.Instr[@typing_env.InferredAnnotation]],
  Array[@infer.Cell[@infer.InferredType]],
) {
  let ctx = self.ctx
  note_use(ctx, ctx.memories, memname)
  let address_type = match ctx.memories.find_no_mark(memname.name) {
    Some((_, at)) => at
    None => @wasm_types.AddressType::I32
  }
  let nstack = mop.operands.length()
  let split = split_labelled_args(args)
  let allowed = if mop.lane {
    ["lane", "offset", "align"]
  } else {
    ["offset", "align"]
  }
  let found = take_labels(ctx.diagnostics, allowed, split.labelled)
  let example = memname.name +
    "." +
    meth.name +
    (if mop.lane { "(..., lane: 0, offset: 16)" } else { "(..., offset: 16)" })
  let (lane, align, offset) = mem_immediates(
    ctx.diagnostics,
    location,
    example,
    nstack,
    has_lane=mop.lane,
    found,
    split.positional,
  )
  let checked : Array[@ast.Instr[@typing_env.InferredAnnotation]] = []
  for k, a in split.positional {
    let c = self.expression(a)
    let ty = expression_type(ctx, c.info)
    if k == 0 {
      check_subtype(
        ctx.type_context.subtyping_info(),
        ctx.diagnostics,
        a.info,
        ty,
        address_cell(address_type),
      )
    } else if k < nstack {
      check_subtype(
        ctx.type_context.subtyping_info(),
        ctx.diagnostics,
        a.info,
        ty,
        simd_cell(mop.operands[k]),
      )
    }
    checked.push(c)
  }
  if mop.lane {
    match lane {
      Some(l) =>
        check_lane_immediate(ctx.diagnostics, mem_lane_bound(mop.nat_align), l)
      None =>
        // Only when the stack operands are exactly accounted for and no
        // ill-formed `lane:` was written: too few or too many positional
        // arguments were reported just above, and a non-constant lane payload
        // by `take_labels`.
        if split.positional.length() == nstack &&
          !split.labelled.iter().any(p => p.0.name == "lane") {
          missing_lane_immediate(ctx.diagnostics, meth.loc)
        }
    }
  }
  check_memarg(ctx.diagnostics, address_type, mop.nat_align, align, offset)
  // The immediates are kept on the typed node, re-wrapped with their labels,
  // exactly as the scalar accesses keep theirs. They are not values -- nothing
  // pushes them -- but they ARE part of the instruction, and the code generator
  // has no other place to read them from.
  for entry in split.labelled {
    let (label, value) = entry
    checked.push({
      desc: Labelled(label, {
        desc: value.desc.map_desc(
          instr=_ => abort("a memory immediate has no sub-instructions"),
          block=_ => abort("a memory immediate has no blocks"),
        ),
        info: annotate([], value.info),
        hints: value.hints,
        expected: value.expected,
      }),
      info: annotate([], value.info),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    })
  }
  let results = match mop.result {
    Some(t) => [simd_cell(t)]
    None => []
  }
  (checked, results)
}

///|
/// The SIMD operation a `recv.meth(..)` call names, if any.
///
/// Unlike the memory intrinsics this needs no receiver check: the operation is
/// identified by its NAME alone, since the names carry their shape
/// (`add_i32x4`) and cannot collide with anything else.
fn Checker::simd_vector_op(
  self : Checker,
  callee : @ast.Instr[@basic.Location],
) -> @simd.Intrinsic? {
  ignore(self)
  guard callee.desc is StructGet(_, meth) else { return None }
  match @simd.classify(meth.name) {
    Some(op) if !op.free => Some(op)
    _ => None
  }
}

///|
/// Type a SIMD operation on a value.
///
/// Emission order is the receiver, then the trailing stack operands. The
/// LEADING immediates are static -- not pushed, never holes -- so they sit
/// between the two and are typed plainly.
fn Checker::simd_vector_call(
  self : Checker,
  location : @basic.Location,
  recv : @ast.Instr[@basic.Location],
  op : @simd.Intrinsic,
  args : Array[@ast.Instr[@basic.Location]],
) -> (
  @ast.Instr[@typing_env.InferredAnnotation],
  Array[@ast.Instr[@typing_env.InferredAnnotation]],
  Array[@infer.Cell[@infer.InferredType]],
) {
  let ctx = self.ctx
  let nimm = match op.imm {
    NoImm => 0
    Lane(_) => 1
    Shuffle => 16
  }
  let recv_ = self.expression(recv)
  let checked : Array[@ast.Instr[@typing_env.InferredAnnotation]] = []
  for a in args {
    checked.push(self.expression(a))
  }
  let nstack_extra = op.operands.length() - 1
  if args.length() != nimm + nstack_extra {
    operand_count_mismatch(
      ctx.diagnostics,
      location,
      expected=nimm + nstack_extra,
      provided=args.length(),
    )
  }
  // The receiver is the operation's FIRST operand.
  let recv_ty = expression_type(ctx, recv_.info)
  let recv_expected = simd_cell(op.operands[0])
  let recv_ok = subtype(
    ctx.type_context.subtyping_info(),
    recv_ty,
    recv_expected,
  )
  if !recv_ok {
    expression_type_mismatch(ctx.diagnostics, recv.info, recv_ty, recv_expected)
  }
  // A chained lane operation anchors each receiver mismatch at the shared
  // leftmost operand, so without poisoning the inner receiver and the outer
  // one -- the inner call's result -- would report an identical error at one
  // location.
  let poisoned = !recv_ok || recv_ty.get() is Error
  let bound = lane_bound(op.imm)
  for k, a in args {
    if k < nimm {
      if bound is Some(b) {
        check_lane_immediate(ctx.diagnostics, b, { desc: a.desc, info: a.info })
      }
    } else {
      let operand = 1 + (k - nimm)
      if operand < op.operands.length() {
        check_subtype(
          ctx.type_context.subtyping_info(),
          ctx.diagnostics,
          a.info,
          expression_type(ctx, checked[k].info),
          simd_cell(op.operands[operand]),
        )
      }
    }
  }
  let results = if poisoned {
    [@infer.Cell::make(@infer.InferredType::Error)]
  } else {
    match op.result {
      Some(t) => [simd_cell(t)]
      None => []
    }
  }
  (recv_, checked, results)
}

///|
/// The reference a freshly allocated continuation has.
///
/// EXACT only under custom-descriptors, as for `struct.new` and `array.new`:
/// the allocation really does produce exactly that type, but exact reference
/// types are part of that proposal, so without it the plain form is what can be
/// written down.
fn Checker::fresh_continuation(
  self : Checker,
  ct : @ast.Ident,
) -> @infer.Cell[@infer.InferredType] {
  let ctx = self.ctx
  let exact = ctx.type_context.features.is_enabled(CustomDescriptors)
  match
    internalize(
      ctx.type_context,
      ctx.diagnostics,
      Ref({ nullable: false, typ: if exact { Exact(ct) } else { Type(ct) } }),
    ) {
    Some(c) => c
    None => @infer.Cell::make(@infer.InferredType::Error)
  }
}

///|
/// Check a `cont.bind`: the destination must be the source with its LEADING
/// parameters bound away.
///
/// So the destination takes fewer parameters, and what remains -- the unbound
/// tail and the results -- must match. The arguments supplied are exactly the
/// bound prefix, followed by the source continuation itself.
fn Checker::check_cont_bind(
  self : Checker,
  location : @basic.Location,
  src : @ast.Ident,
  dst : @ast.Ident,
  args : Array[@ast.Instr[@basic.Location]],
  checked : Array[@ast.Instr[@typing_env.InferredAnnotation]],
) -> Unit {
  let ctx = self.ctx
  guard lookup_cont_inner(ctx.type_context, ctx.diagnostics, src)
    is Some(src_inner) else {
    return
  }
  guard lookup_func_type(ctx.type_context, ctx.diagnostics, src_inner)
    is Some(src_sig) else {
    return
  }
  guard lookup_cont_inner(ctx.type_context, ctx.diagnostics, dst)
    is Some(dst_inner) else {
    return
  }
  guard lookup_func_type(ctx.type_context, ctx.diagnostics, dst_inner)
    is Some(dst_sig) else {
    return
  }
  let np = src_sig.params.length() - dst_sig.params.length()
  if np < 0 {
    stack_switching_type_mismatch(
      ctx.diagnostics,
      location,
      "the resulting continuation takes more parameters than the original one",
    )
  } else if internal_functype(ctx.type_context, ctx.diagnostics, src_sig)
    is Some(src_ft) &&
    internal_functype(ctx.type_context, ctx.diagnostics, dst_sig)
    is Some(dst_ft) {
    // What is left of the source once the prefix is bound has to BE the
    // destination: same remaining parameters, same results.
    let tail = src_ft.params[np:np + dst_ft.params.length()].to_owned()
    if !functype_matches(
        ctx.type_context.subtyping_info(),
        { params: tail, results: src_ft.results },
        dst_ft,
      ) {
      stack_switching_type_mismatch(
        ctx.diagnostics,
        location,
        "the bound parameters and results do not match between the two continuation types",
      )
    }
  }
  // The operands are the bound prefix, then the source continuation itself.
  let want : Array[@infer.Cell[@infer.InferredType]] = []
  let n = if np > 0 { np } else { 0 }
  for k in 0..<n {
    if k < src_sig.params.length() {
      if internalize(
          ctx.type_context,
          ctx.diagnostics,
          src_sig.params[k].desc.1,
        )
        is Some(c) {
        want.push(c)
      }
    }
  }
  if internalize(
      ctx.type_context,
      ctx.diagnostics,
      Ref({ nullable: true, typ: Type(src) }),
    )
    is Some(c) {
    want.push(c)
  }
  ignore(args)
  check_operands(
    ctx.type_context.subtyping_info(),
    ctx.diagnostics,
    location,
    checked.map(c => (c.info.0, c.info.1)),
    want,
  )
}

///|
/// Type a resume instruction: operands, handler table, results.
///
/// What goes on the stack differs by form -- the continuation's own parameters
/// for a plain `resume`, a tag's for `resume_throw`, an `exnref` for
/// `resume_throw_ref` -- but the CONTINUATION reference is always last, and the
/// results are always the continuation's own. That is what makes one function
/// of the three.
fn Checker::type_resume(
  self : Checker,
  location : @basic.Location,
  ct : @ast.Ident,
  handlers : Array[@ast.OnClause],
  checked : Array[@ast.Instr[@typing_env.InferredAnnotation]],
  throw_tag : @ast.Ident?,
  ref_first~ : Bool,
) -> Array[@infer.Cell[@infer.InferredType]] {
  let ctx = self.ctx
  guard lookup_cont_inner(ctx.type_context, ctx.diagnostics, ct) is Some(inner) else {
    return []
  }
  guard lookup_func_type(ctx.type_context, ctx.diagnostics, inner) is Some(sg) else {
    return []
  }
  let want : Array[@infer.Cell[@infer.InferredType]] = []
  if ref_first {
    // `resume_throw_ref` throws an exception object that was caught elsewhere.
    if internalize(
        ctx.type_context,
        ctx.diagnostics,
        Ref({ nullable: true, typ: Exn }),
      )
      is Some(c) {
      want.push(c)
    }
  } else {
    let params = match throw_tag {
      Some(tag) =>
        match find(ctx.tags, ctx.diagnostics, tag) {
          Some(ft) => ft.params
          None => []
        }
      None => sg.params
    }
    for p in params {
      if internalize(ctx.type_context, ctx.diagnostics, p.desc.1) is Some(c) {
        want.push(c)
      }
    }
  }
  // The continuation itself, always last and always nullable: a null one traps
  // rather than being rejected here.
  if internalize(
      ctx.type_context,
      ctx.diagnostics,
      Ref({ nullable: true, typ: Type(ct) }),
    )
    is Some(c) {
    want.push(c)
  }
  check_operands(
    ctx.type_context.subtyping_info(),
    ctx.diagnostics,
    location,
    checked.map(c => (c.info.0, c.info.1)),
    want,
  )
  check_resume_handlers(ctx, sg.results, handlers)
  let out : Array[@infer.Cell[@infer.InferredType]] = []
  for r in sg.results {
    if internalize(ctx.type_context, ctx.diagnostics, r) is Some(c) {
      out.push(c)
    }
  }
  out
}

///|
/// Type a `switch`: hand control to another continuation without going through
/// a handler.
///
/// The switched-to continuation's LAST parameter must itself be a continuation
/// -- that is the slot the current one is passed in, so the other side can
/// switch back. What this instruction produces is that inner continuation's
/// parameters: the values that will arrive when it does.
fn Checker::type_switch(
  self : Checker,
  location : @basic.Location,
  ct : @ast.Ident,
  tag : @ast.Ident,
  checked : Array[@ast.Instr[@typing_env.InferredAnnotation]],
) -> Array[@infer.Cell[@infer.InferredType]] {
  let ctx = self.ctx
  guard lookup_cont_inner(ctx.type_context, ctx.diagnostics, ct) is Some(inner) else {
    return []
  }
  guard lookup_func_type(ctx.type_context, ctx.diagnostics, inner) is Some(sg) else {
    return []
  }
  let tag_sig = find(ctx.tags, ctx.diagnostics, tag)
  let np = sg.params.length()
  if np >= 1 {
    // Everything but that last slot goes on the stack, then the continuation.
    let want : Array[@infer.Cell[@infer.InferredType]] = []
    for k in 0..<(np - 1) {
      if internalize(ctx.type_context, ctx.diagnostics, sg.params[k].desc.1)
        is Some(c) {
        want.push(c)
      }
    }
    if internalize(
        ctx.type_context,
        ctx.diagnostics,
        Ref({ nullable: true, typ: Type(ct) }),
      )
      is Some(c) {
      want.push(c)
    }
    check_operands(
      ctx.type_context.subtyping_info(),
      ctx.diagnostics,
      location,
      checked.map(c => (c.info.0, c.info.1)),
      want,
    )
  }
  // The last parameter must itself be a continuation type.
  let inner_sg = if np == 0 {
    None
  } else {
    match sg.params[np - 1].desc.1 {
      Ref({ typ: Type(ct2) | Exact(ct2), .. }) =>
        match lookup_cont_inner(ctx.type_context, ctx.diagnostics, ct2) {
          Some(i2) => lookup_func_type(ctx.type_context, ctx.diagnostics, i2)
          None => None
        }
      _ => None
    }
  }
  fn results_match(
    a : Array[@wasm_types.ValType[@ast.Ident]],
    b : Array[@wasm_types.ValType[@ast.Ident]],
  ) -> Bool {
    guard a.length() == b.length() else { return false }
    let info = ctx.type_context.subtyping_info()
    for k in 0..<a.length() {
      let x = internalize_valtype(ctx.type_context, ctx.diagnostics, a[k])
      let y = internalize_valtype(ctx.type_context, ctx.diagnostics, b[k])
      // Either failing to resolve was reported; do not add a second complaint
      // about a comparison that cannot be made.
      if x is Some(x) && y is Some(y) {
        if !@type_store.val_subtype(info, x.internal, y.internal) {
          return false
        }
      }
    }
    true
  }

  match inner_sg {
    None =>
      stack_switching_type_mismatch(
        ctx.diagnostics,
        location,
        "the continuation's last parameter must itself be a continuation type",
      )
    Some(inner2) =>
      // A `switch` tag carries no values -- it names the switch, it does not
      // pass anything -- and its results have to agree with BOTH continuations,
      // since they are what flows across the exchange.
      if tag_sig is Some(ts) {
        if !ts.params.is_empty() ||
          !results_match(sg.results, ts.results) ||
          !results_match(ts.results, inner2.results) {
          stack_switching_type_mismatch(
            ctx.diagnostics,
            location,
            "the 'switch' tag must take no parameters and its results must match the two continuation types",
          )
        }
      }
  }
  let out : Array[@infer.Cell[@infer.InferredType]] = []
  if inner_sg is Some(s2) {
    for p in s2.params {
      if internalize(ctx.type_context, ctx.diagnostics, p.desc.1) is Some(c) {
        out.push(c)
      }
    }
  }
  out
}

///|
/// Whether an instruction is a resume written in method form.
///
/// The surface spells the handlers outside the call -- `c.resume(x) on (..)` --
/// so this is what an `on` clause is allowed to wrap, alongside the dedicated
/// nodes a decompiled module carries.
fn Checker::is_resume_call(
  self : Checker,
  inner : @ast.Instr[@basic.Location],
) -> Bool {
  ignore(self)
  guard inner.desc is Call(callee, _) else { return false }
  guard callee.desc is StructGet(_, meth) else { return false }
  match meth.name {
    "resume" | "resume_throw" | "resume_throw_ref" => true
    _ => false
  }
}

///|
/// The two descriptor branches, which are mirrors of the plain cast branches.
///
/// `br_on_cast_desc_eq` branches when the value's descriptor IS the given one,
/// carrying the described type; the `_fail` form branches when it is not,
/// carrying the residual. The target type is recovered from the descriptor
/// operand rather than written.
fn Checker::desc_branch(
  self : Checker,
  i : @ast.Instr[@basic.Location],
  label : @ast.Ident,
  nullable : Bool,
  value : @ast.Instr[@basic.Location],
  desc : @ast.Instr[@basic.Location],
  on_success~ : Bool,
) -> @ast.Instr[@typing_env.InferredAnnotation] {
  let ctx = self.ctx
  let loc = i.info
  let value_ = self.expression(value)
  let desc_ = self.expression(desc)
  let target = descriptor_reftype(
    ctx,
    desc.info,
    nullable~,
    expression_type(ctx, desc_.info),
  )
  let value_ty = expression_type(ctx, value_.info)
  let params = branch_target(ctx, label)
  let bound = label_in_scope(ctx, label)
  let (delivered, fallthrough) = match target {
    None =>
      (
        @infer.Cell::make(@infer.InferredType::Error),
        @infer.Cell::make(@infer.InferredType::Error),
      )
    Some(rt) => {
      let cast_to = match
        internalize(ctx.type_context, ctx.diagnostics, Ref(rt)) {
        Some(c) => c
        None => @infer.Cell::make(@infer.InferredType::Error)
      }
      let residual = match
        conditional_cast_types(ctx, value.info, value_ty, rt) {
        Some((_, r)) => r
        None => @infer.Cell::make(@infer.InferredType::Error)
      }
      if on_success {
        (cast_to, residual)
      } else {
        (residual, cast_to)
      }
    }
  }
  if bound {
    check_subtypes(
      ctx.type_context.subtyping_info(),
      ctx.diagnostics,
      value.info,
      [delivered],
      params,
    )
  }
  {
    desc: if on_success {
      BrOnCastDescEq(label, nullable, value_, desc_)
    } else {
      BrOnCastDescEqFail(label, nullable, value_, desc_)
    },
    info: annotate([fallthrough], loc),
    hints: i.hints,
    expected: i.expected,
  }
}

///|
/// Whether an `a[i] = v` receiver names a TABLE rather than an array value.
///
/// A table is a static immediate, so `tab[i] = v` is `table.set` and the
/// receiver is never typed as a value at all. A local named `tab` shadows it
/// and makes this an ordinary array write.
fn Checker::is_table_receiver(
  self : Checker,
  recv : @ast.Instr[@basic.Location],
) -> Bool {
  guard recv.desc is Get(name) else { return false }
  table_receiver(self.ctx, name)
}

///|
/// Whether a call is one of the no-argument instruction methods.
///
/// Checked AFTER the intrinsic families, so a name they claim wins: these are
/// operations on a VALUE, and nothing here takes a memory or table receiver.
fn Checker::is_unary_intrinsic(
  self : Checker,
  callee : @ast.Instr[@basic.Location],
  args : Array[@ast.Instr[@basic.Location]],
) -> Bool {
  ignore(self)
  guard args.is_empty() else { return false }
  guard callee.desc is StructGet(_, meth) else { return false }
  is_unary_method(meth.name)
}

///|
/// Type a no-argument instruction method from its receiver.
///
/// The METHOD fixes the family and the receiver fixes the width -- so a
/// still-flexible receiver is pinned here, by the only thing that can pin it.
/// `clz` makes an integer of a bare literal, `sqrt` makes a float of one, and
/// `to_bits` makes an f64 even of a literal written without a point, because a
/// float constant decompiled to a bare integer is still a float.
fn Checker::unary_intrinsic(
  self : Checker,
  location : @basic.Location,
  meth : @ast.Ident,
  ty : @infer.Cell[@infer.InferredType],
) -> @infer.Cell[@infer.InferredType] {
  let ctx = self.ctx
  let i32c = () => @infer.valtype_cell(@infer.i32_valtype)
  let i64c = () => @infer.valtype_cell(@infer.i64_valtype)
  let f32c = () => @infer.valtype_cell(@infer.f32_valtype)
  let f64c = () => @infer.valtype_cell(@infer.f64_valtype)
  let err = () => @infer.Cell::make(@infer.InferredType::Error)
  match (ty.get(), meth.name) {
    (Valtype({ typ: Ref({ typ: Type(t) | Exact(t), .. }), .. }), "length") =>
      match ctx.types.find_no_mark(t.name) {
        Some((_, def)) =>
          match def.typ {
            Array(_) => i32c()
            _ => {
              expected_array(ctx.diagnostics, location)
              err()
            }
          }
        None => err()
      }
    // `array.len` accepts any subtype of `(ref null array)`: the abstract
    // array, a bare null, and the bottom reference, which is below it.
    (Null | Valtype({ typ: Ref({ typ: Array | None_, .. }), .. }), "length") =>
      i32c()
    (Valtype({ typ: I32, .. }), "from_bits") => f32c()
    (Valtype({ typ: I64, .. }), "from_bits") => f64c()
    (Valtype({ typ: F32, .. }), "to_bits") => i32c()
    (Valtype({ typ: F64, .. }), "to_bits") => i64c()
    // An abstract numeric receiver defaults like any other operation. A value
    // already committed to the INTEGER family is not coerced: `to_bits` on an
    // integer is meaningless, and coercing its shared cell to f64 would make
    // the integer-producing operation below it lower against an f64 operand.
    (Float | Number | LargeInt | Unknown, "to_bits") => {
      ty.set(Valtype(@infer.f64_valtype))
      i64c()
    }
    (Number | Int | Unknown, "from_bits") => {
      ty.set(Valtype(@infer.i32_valtype))
      f32c()
    }
    (LargeInt, "from_bits") => {
      ty.set(Valtype(@infer.i64_valtype))
      f64c()
    }
    (
      Number
      | Int
      | LargeInt
      | Unknown
      | Valtype({ typ: I32 | I64, .. }),
      "clz"
      | "ctz"
      | "popcnt"
      | "extend8_s"
      | "extend16_s",
    ) => {
      match ty.get() {
        Number | Unknown => ty.set(Int)
        LargeInt => ty.set(Valtype(@infer.i64_valtype))
        _ => ()
      }
      ty
    }
    (
      Number
      | Float
      | Unknown
      | LargeInt
      | Valtype({ typ: F32 | F64, .. }),
      "abs"
      | "ceil"
      | "floor"
      | "trunc"
      | "nearest"
      | "sqrt",
    ) => {
      // A large literal is a FLOAT here: this is a float intrinsic, so the
      // literal's float-capability is what applies.
      match ty.get() {
        Number | Unknown | LargeInt => ty.set(Float)
        _ => ()
      }
      ty
    }
    (Error, _) => err()
    (Unknown | UnknownRef, _) => {
      // Only a reference, so no method resolves; or unknown with a method that
      // fixes no numeric family. Either way it cannot be compiled.
      unknown_operand_type(ctx.diagnostics, location)
      err()
    }
    _ => {
      invalid_method_receiver(ctx.diagnostics, meth.loc, ty)
      err()
    }
  }
}

///|
/// Type a free intrinsic call -- one written as a qualified name rather than on
/// a receiver.
///
/// The vector constants are the interesting half: `v128::i8x16(...)` takes one
/// literal per lane, and each must FIT its lane width. That check earns its
/// keep twice over -- it rejects a malformed constant, and it stops an
/// out-of-range literal reaching the encoder, which would parse it and fail
/// there instead.
fn Checker::free_intrinsic(
  self : Checker,
  location : @basic.Location,
  ns : @ast.Ident,
  name : @ast.Ident,
  args : Array[@ast.Instr[@basic.Location]],
  checked : Array[@ast.Instr[@typing_env.InferredAnnotation]],
) -> @infer.Cell[@infer.InferredType] {
  let ctx = self.ctx
  let full = @simd.free_full(name.name)
  guard @simd.is_free_intrinsic(full) else {
    unknown_intrinsic(ctx.diagnostics, location, ns.name, name.name)
    return @infer.Cell::make(@infer.InferredType::Error)
  }
  let v128 = simd_cell(TV128)
  match @simd.const_shape_of_name(full) {
    Some(shape) => {
      let arity = @simd.const_arity(shape)
      if args.length() != arity {
        operand_count_mismatch(
          ctx.diagnostics,
          location,
          expected=arity,
          provided=args.length(),
        )
      }
      // A float shape accepts any numeric literal; an integer shape bounds each
      // lane by its width.
      let bits = match shape {
        I8x16 => Some(8)
        I16x8 => Some(16)
        I32x4 => Some(32)
        I64x2 => Some(64)
        F32x4 | F64x2 => None
      }
      for a in args {
        check_lane_literal(ctx, bits, a)
      }
      v128
    }
    // The only non-constant free intrinsic is `bitselect`, which takes exactly
    // three vectors. Its arity is checked here for the same reason the
    // constants' is: an under- or over-application rejected now beats an
    // unrelated stack complaint during lowering.
    None => {
      if args.length() != 3 {
        operand_count_mismatch(
          ctx.diagnostics,
          location,
          expected=3,
          provided=args.length(),
        )
      }
      for k, a in args {
        check_subtype(
          ctx.type_context.subtyping_info(),
          ctx.diagnostics,
          a.info,
          expression_type(ctx, checked[k].info),
          simd_cell(TV128),
        )
      }
      v128
    }
  }
}

///|
/// Check one lane of a vector constant.
///
/// An integer lane accepts BOTH the signed and unsigned range of its width --
/// an i8 lane is -128 to 255 -- because the constant is a bit pattern and both
/// spellings name the same byte.
fn check_lane_literal(
  ctx : @typing_env.ModuleContext,
  bits : Int?,
  a : @ast.Instr[@basic.Location],
) -> Unit {
  // A leading `-` is a separate negation in the AST, so the magnitude and the
  // sign arrive apart.
  let (negated, lit) = match a.desc {
    UnOpI(op, inner) if op.desc is Neg => (true, inner.desc)
    _ => (false, a.desc)
  }
  match (bits, lit) {
    (Some(b), Int(_)) =>
      if !lane_fits(b, negated, lit) {
        lane_value_out_of_range(ctx.diagnostics, a.info, b)
      }
    // A float literal is not a valid integer lane, whatever its value.
    (Some(b), Float(_)) => lane_value_out_of_range(ctx.diagnostics, a.info, b)
    (None, Int(_) | Float(_)) => ()
    _ => number_literal_required(ctx.diagnostics, a.info)
  }
}

///|
/// Whether an integer lane literal fits its width.
fn lane_fits(
  bits : Int,
  negated : Bool,
  lit : @ast.InstrDesc[@basic.Location],
) -> Bool {
  guard int_literal_u64(lit) is Some(v) else { return false }
  if negated {
    // A magnitude of at most 2^(b-1): the most negative value of the width.
    v <= 1UL << (bits - 1)
  } else if bits == 64 {
    true
  } else {
    v <= (1UL << bits) - 1UL
  }
}
