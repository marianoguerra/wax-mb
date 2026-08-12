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
          let rhs = self.statement(value)
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
        None => {
          let rhs = self.statement(value)
          if target is Some(t) {
            check_subtype(
              ctx.type_context.subtyping_info(),
              ctx.diagnostics,
              value.info,
              expression_type(ctx, rhs.info),
              t,
            )
          }
          rhs
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
      let checked = self.statement(value)
      let operand = expression_type(ctx, checked.info)
      let ty = tee_target(ctx, idx, resolved, operand)
      // A tee assigns AND leaves the value, so where the target has a type the
      // operand is checked against it -- and the tee produces the target's
      // type, not the operand's.
      if resolved is Local(Some(_), _) {
        check_subtype(
          ctx.type_context.subtyping_info(),
          ctx.diagnostics,
          value.info,
          operand,
          ty,
        )
      }
      self.ops.push(Some(loc), ty)
      {
        desc: Tee(idx, checked),
        info: annotate([ty], loc),
        hints: i.hints,
        expected: i.expected,
      }
    }

    // --- Local binding ---
    Let(bindings, Some(init)) => {
      let checked = self.statement(init)
      if bindings.length() == 1 {
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
      let recv_ = self.statement(recv)
      let ty = self.field_type_of(
        recv.info,
        expression_type(ctx, recv_.info),
        field,
      )
      self.ops.push(Some(loc), ty)
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
      let recv_ = self.statement(recv)
      let declared = self.field_slot(
        recv.info,
        expression_type(ctx, recv_.info),
        field,
      )
      let value_ = self.statement(value)
      if declared is Some(ft) {
        if !ft.mut_ {
          immutable(ctx.diagnostics, field.loc, "field")
        }
        // Written at the UNPACKED width: a packed field takes a plain i32 and
        // narrows implicitly, unlike a read, which remembers how narrow it was.
        if internalize(ctx.type_context, ctx.diagnostics, unpack_type(ft))
          is Some(want) {
          check_subtype(
            ctx.type_context.subtyping_info(),
            ctx.diagnostics,
            value.info,
            expression_type(ctx, value_.info),
            want,
          )
        }
      }
      {
        desc: StructSet(recv_, field, value_),
        info: annotate([], loc),
        hints: i.hints,
        expected: i.expected,
      }
    }

    // --- Reading an array element ---
    ArrayGet(recv, index) => {
      // Emission order: the array, then the index.
      let recv_ = self.statement(recv)
      let index_ = self.statement(index)
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
      self.ops.push(Some(loc), ty)
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
      self.ops.push(Some(loc), ty)
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
      self.ops.push(Some(loc), ty)
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
      let init_ = self.statement(init)
      if elt is Some(cell) {
        check_subtype(
          ctx.type_context.subtyping_info(),
          ctx.diagnostics,
          init.info,
          expression_type(ctx, init_.info),
          cell,
        )
      }
      let size_ = self.statement(size)
      check_subtype(
        ctx.type_context.subtyping_info(),
        ctx.diagnostics,
        size.info,
        expression_type(ctx, size_.info),
        @infer.valtype_cell(@infer.i32_valtype),
      )
      let ty = self.allocated(loc, name)
      self.ops.push(Some(loc), ty)
      {
        desc: Array(name, init_, size_),
        info: annotate([ty], loc),
        hints: i.hints,
        expected: i.expected,
      }
    }
    ArrayDefault(name, size) => {
      let size_ = self.statement(size)
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
      self.ops.push(Some(loc), ty)
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
        let c = self.statement(e)
        if elt is Some(cell) {
          check_subtype(
            ctx.type_context.subtyping_info(),
            ctx.diagnostics,
            e.info,
            expression_type(ctx, c.info),
            cell,
          )
        }
        checked.push(c)
      }
      let ty = self.allocated(loc, name)
      self.ops.push(Some(loc), ty)
      {
        desc: ArrayFixed(name, checked),
        info: annotate([ty], loc),
        hints: i.hints,
        expected: i.expected,
      }
    }

    // --- Casts and tests ---
    Cast(operand, target) => {
      let operand_ = self.statement(operand)
      let natural = expression_type(ctx, operand_.info)
      let ty = match target {
        // `e as t` for a value type: the result IS the target, and a reference
        // target is worth linting -- it can be impossible or pointless before
        // it is ever run.
        Value(v) => {
          let want = internalize(ctx.type_context, ctx.diagnostics, v)
          if want is Some(w) {
            lint_ref_cast(
              ctx,
              loc,
              is_test=false,
              natural.get(),
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
        Signed(typ~, ..) =>
          @infer.valtype_cell(
            match typ {
              I32 => @infer.i32_valtype
              I64 => @infer.i64_valtype
              F32 => @infer.f32_valtype
              F64 => @infer.f64_valtype
            },
          )
      }
      self.ops.push(Some(loc), ty)
      {
        desc: Cast(operand_, target),
        info: annotate([ty], loc),
        hints: i.hints,
        expected: i.expected,
      }
    }
    Test(operand, target) => {
      let operand_ = self.statement(operand)
      let natural = expression_type(ctx, operand_.info)
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
      self.ops.push(Some(loc), ty)
      {
        desc: Test(operand_, target),
        info: annotate([ty], loc),
        hints: i.hints,
        expected: i.expected,
      }
    }
    NonNull(operand) => {
      let operand_ = self.statement(operand)
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
      self.ops.push(Some(loc), ty)
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
        None => { name: string_type_name, loc }
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
      self.ops.push(Some(loc), ty)
      {
        desc: Str(name, bytes),
        info: annotate([ty], loc),
        hints: i.hints,
        expected: i.expected,
      }
    }

    // --- An array built from a segment ---
    ArraySegment(name, seg, off, len) => {
      let off_ = self.statement(off)
      let len_ = self.statement(len)
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
      self.ops.push(Some(loc), ty)
      {
        desc: ArraySegment(name, seg, off_, len_),
        info: annotate([ty], loc),
        hints: i.hints,
        expected: i.expected,
      }
    }

    // --- The descriptor of a value ---
    GetDescriptor(recv) => {
      let recv_ = self.statement(recv)
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
      self.ops.push(Some(loc), ty)
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
      let body = self.body(loc, label, params, results, results, block.desc)
      // Checked INSIDE the frame's lifetime is wrong: a catch branches to a
      // label in the ENCLOSING scope, not to the try's own. Checking after the
      // body has closed its frame is what makes that true.
      check_trytable_catches(ctx, catches)
      self.ops.push_results(loc, results)
      {
        desc: TryTable(label~, typ~, catches~, block={
          desc: body,
          info: block.info,
        }),
        info: annotate(results, loc),
        hints: i.hints,
        expected: i.expected,
      }
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
      let body = self.body(loc, label, params, results, results, block.desc)
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
        // Each handler is a block of its own, entered on the tag's payload and
        // producing the try's results, with the try's label in scope so a `br`
        // to it exits carrying the value.
        guard self.tag_payload(tag) is Some(entry) else { continue }
        // The HANDLER's own span, not the try's: its parameters are pushed
        // there, and anchoring a leftover at the try's opening would be both
        // misleading and indistinguishable from the try's own report.
        let checked = self.body(
          arm.info,
          label,
          entry,
          results,
          results,
          arm.desc,
        )
        handled.push((tag, { desc: checked, info: arm.info }))
      }
      let all = match catch_all {
        Some(arm) => {
          let checked = self.body(
            arm.info,
            label,
            [],
            results,
            results,
            arm.desc,
          )
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
      self.ops.push_results(loc, results)
      {
        desc: Try(
          label~,
          typ~,
          block={ desc: body, info: block.info },
          catches=handled,
          catch_all=all,
        ),
        info: annotate(results, loc),
        hints: i.hints,
        expected: i.expected,
      }
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
      let body = self.body(loc, label, [], results, results, block.desc)
      // Arm k is entered on its tag's payload and must COMPLETE with arm k+1's
      // entry stack -- the last arm's completion being the try's results. That
      // chaining is the whole shape of this construct, and it is why the
      // entries are computed for all the arms before any body is checked.
      let entries = arms.map(a => self.arm_entry(a))
      let checked : Array[@ast.TryCatchArm[@typing_env.InferredAnnotation]] = []
      for k, arm in arms {
        let exits = if k + 1 < entries.length() {
          entries[k + 1]
        } else {
          Some(results)
        }
        // A type in the chain that did not resolve was already reported; the
        // body is typed as a plain result-producing block rather than cascading.
        let (params, exit_types) = match (entries[k], exits) {
          (Some(p), Some(e)) => (p, e)
          _ => ([], results)
        }
        let arm_body = self.body(
          loc,
          label,
          params,
          exit_types,
          results,
          arm.arm_body.desc,
        )
        checked.push({
          arm_tag: arm.arm_tag,
          arm_ref: arm.arm_ref,
          arm_types: arm.arm_types,
          arm_body: { desc: arm_body, info: arm.arm_body.info },
        })
      }
      self.ops.push_results(loc, results)
      {
        desc: TryCatch(
          label~,
          typ~,
          block={ desc: body, info: block.info },
          arms=checked,
        ),
        info: annotate(results, loc),
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
      Some((fname, written)) => {
        let checked = self.field_value(fname, written)
        // Checked against the field's declared type at the width a WRITE takes,
        // which is what lets a nested literal drop its own name.
        if checked is Some(c) &&
          internalize(ctx.type_context, ctx.diagnostics, unpack_type(d.desc.1))
          is Some(cell) {
          check_subtype(
            ctx.type_context.subtyping_info(),
            ctx.diagnostics,
            c.info.1,
            expression_type(ctx, c.info),
            cell,
          )
        }
        // Punning preserved: a field with no written value stays without one.
        out.push((fname, if written is Some(_) { checked } else { None }))
      }
    }
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
) -> @ast.Instr[@typing_env.InferredAnnotation]? {
  match written {
    Some(e) => Some(self.statement(e))
    None => {
      @typing_env.record_pun(self.ctx.pun_spans, name.loc)
      Some(
        self.statement({
          desc: Get(name),
          info: name.loc,
          hints: { branch: None, freq: None, targets: None },
          expected: None,
        }),
      )
    }
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
