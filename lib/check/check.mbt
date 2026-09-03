// Checking an instruction AGAINST a type the context already knows.
//
// Ported from `check_instruction` / `check_toplevel` in
// wax/src/lib-wax/typing.ml.
//
// The third and last position. Statement position takes whatever an instruction
// leaves; expression position asks it what it produces; check position tells it
// what is wanted, and that is the only one of the three under which a
// construction literal can be written without naming its type:
//
//     let xs : &bytes = [| 0; 0; 0 |];
//
// Nothing in `[| .. |]` says what it constructs. The annotation does, and only a
// position that carries the annotation INTO the literal can use it -- which is
// why an unnamed construction reported "Cannot infer the array type here" no
// matter how plainly the surrounding code said so.
//
// The mechanism is deliberately small: pin the omitted name from the expected
// type, type the literal as if it had been written that way, then put the source
// spelling back. Everything the named form already does -- resolving the element
// type before the values, checking each field, producing an exact reference --
// then applies unchanged, because it IS the named form.

///|
/// Does this cell actually pin a type?
///
/// `Unknown` is the sentinel for "no context"; a `Collecting` cell is a block
/// result still being inferred, and checking a value against it would discard
/// the value rather than constrain it. Neither is an expectation.
fn has_expectation(expected : @infer.Cell[@infer.InferredType]) -> Bool {
  match expected.get() {
    Unknown | Collecting(_) => false
    _ => true
  }
}

///|
/// The user type an expected reference names, if it names one.
///
/// This is the whole input to name inference: a construction can only take its
/// type from the context when the context pins a NAMED type. An abstract
/// reference (`&any`, `&struct`) names nothing to construct.
fn exact_named_type(expected : @infer.Cell[@infer.InferredType]) -> @ast.Ident? {
  match expected.get() {
    Valtype({ typ: Ref({ typ: Type(n) | Exact(n), .. }), .. }) => Some(n)
    _ => None
  }
}

///|
/// The same construction with an omitted type name filled in from the context.
///
/// `None` when there is nothing to do -- the source named the type, or the node
/// is not a construction at all. Only an OMITTED name is filled: a written one
/// is what the author meant, and the context is not entitled to overrule it.
fn Checker::pin_construction_name(
  self : Checker,
  name : @ast.Ident,
  desc : @ast.InstrDesc[@basic.Location],
) -> @ast.InstrDesc[@basic.Location]? {
  match desc {
    // Field inference takes PRECEDENCE over the expectation: the fields name
    // the exact struct being constructed, where the expected type may be a
    // supertype of it that has none of them. The context is the fallback for
    // when the fields are ambiguous, not the first answer.
    Struct(None, fields) =>
      if infer_struct_by_fields(self.ctx, fields.map(f => f.0)) is Some(_) {
        None
      } else {
        Some(Struct(Some(name), fields))
      }
    StructDefault(None) => Some(StructDefault(Some(name)))
    Array(None, init, size) => Some(Array(Some(name), init, size))
    ArrayDefault(None, n) => Some(ArrayDefault(Some(name), n))
    ArrayFixed(None, elems) => Some(ArrayFixed(Some(name), elems))
    ArraySegment(None, seg, off, len) =>
      Some(ArraySegment(Some(name), seg, off, len))
    Str(None, s) => Some(Str(Some(name), s))
    _ => None
  }
}

///|
/// Put the source's omitted name back on a typed construction.
///
/// The name was borrowed to type the node, not adopted: what the source wrote is
/// what the printer must print, and an omitted name stays omitted. (Dropping a
/// name that the context makes redundant is the opposite rewrite, and belongs to
/// `simplify`, which converts from wasm and is not wired yet.)
fn unpin_construction_name(
  desc : @ast.InstrDesc[@typing_env.InferredAnnotation],
) -> @ast.InstrDesc[@typing_env.InferredAnnotation] {
  match desc {
    Struct(_, fields) => Struct(None, fields)
    StructDefault(_) => StructDefault(None)
    Array(_, init, size) => Array(None, init, size)
    ArrayDefault(_, n) => ArrayDefault(None, n)
    ArrayFixed(_, elems) => ArrayFixed(None, elems)
    ArraySegment(_, seg, off, len) => ArraySegment(None, seg, off, len)
    Str(_, s) => Str(None, s)
    _ => desc
  }
}

///|
/// Check one instruction against a type the context already knows.
///
/// A construction whose name the expectation can supply is typed as though the
/// name had been written, and the spelling is restored afterwards. Everything
/// else is synthesized and then checked, which is what the call sites did by
/// hand before this existed.
pub fn Checker::check(
  self : Checker,
  expected : @infer.Cell[@infer.InferredType],
  i : @ast.Instr[@basic.Location],
) -> @ast.Instr[@typing_env.InferredAnnotation] {
  // Nothing is pinned: there is nothing to hand down, and nothing to check
  // against either.
  guard has_expectation(expected) else { return self.expression(i) }
  match i.desc {
    // A block-like form need not annotate its own result when the context
    // already says what it is. Threading the expectation in as the result type
    // is what makes `do { .. }` in a typed position produce a value at all.
    Block(label~, typ~, block~) =>
      self.check_block(expected, i, label, typ, block, loop_=false)
    Loop(label~, typ~, block~) =>
      self.check_block(expected, i, label, typ, block, loop_=true)
    If(label~, typ~, cond~, if_block~, else_block~) =>
      self.check_if(expected, i, label, typ, cond, if_block, else_block)
    Select(cond, a, b) => self.check_select(expected, i, cond, a, b)
    // The try family takes its result the same way, but has no arm of its own:
    // pinning the omitted result INTO the node and then typing it is the same
    // rewrite, and it reaches the body, every handler, and the annotation
    // written back -- because all three read the block's declared result.
    TryTable(typ~, ..) | Try(typ~, ..) | TryCatch(typ~, ..) =>
      match pin_block_result(expected, typ, i.desc) {
        Some(d) => {
          let c = self.expression({ ..i, desc: d, })
          self.want(expected, i.info, c)
          c
        }
        None => {
          let c = self.expression(i)
          self.want(expected, i.info, c)
          c
        }
      }
    _ => {
      let pinned = match exact_named_type(expected) {
        Some(n) => self.pin_construction_name(n, i.desc)
        None => None
      }
      match pinned {
        Some(d) => {
          let c = self.expression({ ..i, desc: d, })
          self.want(expected, i.info, c)
          { ..c, desc: unpin_construction_name(c.desc), }
        }
        None => {
          let c = self.expression(i)
          self.want(expected, i.info, c)
          c
        }
      }
    }
  }
}

///|
/// The single cell a block-like form types its body against: its OWN declared
/// result when it has one, and the context's expectation when it does not.
///
/// The two are not interchangeable. A block that annotates its result means it;
/// one that does not is asking the context, and there is now a context to ask.
fn context_result_cell(
  ctx : @typing_env.ModuleContext,
  typ : @ast.FuncType,
  expected : @infer.Cell[@infer.InferredType],
) -> @infer.Cell[@infer.InferredType] {
  guard typ.results.length() == 1 else { return expected }
  match internalize(ctx.type_context, ctx.diagnostics, typ.results[0]) {
    Some(c) => c
    None => expected
  }
}

///|
/// Write an omitted result back into a block's type from the cell it was typed
/// against.
///
/// The lowering reads the function type, not the annotation the source happened
/// to write, so a block that took its result from the context has to carry that
/// result out. A block that declared its own keeps what it declared.
fn fill_omitted_result(
  typ : @ast.FuncType,
  result_cell : @infer.Cell[@infer.InferredType],
) -> @ast.FuncType {
  guard typ.results.is_empty() else { return typ }
  match @typing_env.standalone_valtype(result_cell) {
    Some(iv) => { ..typ, results: [iv.typ], }
    None => typ
  }
}

///|
/// A `do` or `loop` checked against a type the context knows.
fn Checker::check_block(
  self : Checker,
  expected : @infer.Cell[@infer.InferredType],
  i : @ast.Instr[@basic.Location],
  label : @ast.Ident?,
  typ : @ast.FuncType,
  block : @basic.Annotated[Array[@ast.Instr[@basic.Location]], @basic.Location],
  loop_~ : Bool,
) -> @ast.Instr[@typing_env.InferredAnnotation] {
  if !typ.params.is_empty() {
    parameterized_block_expression(self.ctx.diagnostics, i.info)
  }
  let result_cell = context_result_cell(self.ctx, typ, expected)
  // The body is typed against a COLLECTING cell that declares the result, not
  // against the result itself. The two differ for the trailing instruction, and
  // only for one that resolves its own type: a nested block routed through the
  // collecting cell synthesizes, where checking it against the concrete result
  // would tell it what to produce. That is the difference between an `if` with
  // no `else` being told it must produce a value and the enclosing block being
  // told nothing reached its exit -- which is what actually happened.
  //
  // Everything else still goes through the concrete result, because a
  // construction there has no type of its own to resolve and the block's result
  // is what gives it one.
  let (_, collecting) = fresh_collecting(Some(result_cell))
  let self_resolving = match block.desc.last() {
    Some(last) => classify_trailing(self.ctx, last.desc).1
    None => false
  }
  // A `br` to a LOOP re-enters at its top with the loop's parameters -- none
  // here -- so it carries no result and the loop's value is its fall-through.
  let branch_target : Array[@infer.Cell[@infer.InferredType]] = if loop_ {
    []
  } else {
    [collecting]
  }
  let checked = self.body(
    i.info,
    label,
    [],
    [result_cell],
    branch_target,
    block.desc,
    body_results=if self_resolving { Some([collecting]) } else { None },
  )
  check_subtype(
    self.ctx.type_context.subtyping_info(),
    self.ctx.diagnostics,
    i.info,
    result_cell,
    expected,
  )
  let typ_ = fill_omitted_result(typ, result_cell)
  let body : @basic.Annotated[
    Array[@ast.Instr[@typing_env.InferredAnnotation]],
    @basic.Location,
  ] = { desc: checked, info: block.info, }
  {
    desc: if loop_ {
      Loop(label~, typ=typ_, block=body)
    } else {
      Block(label~, typ=typ_, block=body)
    },
    info: annotate([result_cell], i.info),
    hints: i.hints,
    expected: i.expected,
  }
}

///|
/// An `if` checked against a type the context knows: both branches deliver it.
fn Checker::check_if(
  self : Checker,
  expected : @infer.Cell[@infer.InferredType],
  i : @ast.Instr[@basic.Location],
  label : @ast.Ident?,
  typ : @ast.FuncType,
  cond : @ast.Instr[@basic.Location],
  if_block : @basic.Annotated[
    Array[@ast.Instr[@basic.Location]],
    @basic.Location,
  ],
  else_block : @basic.Annotated[
    Array[@ast.Instr[@basic.Location]],
    @basic.Location,
  ]?,
) -> @ast.Instr[@typing_env.InferredAnnotation] {
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
  let result_cell = context_result_cell(self.ctx, typ, expected)
  let results = [result_cell]
  // Each arm at its OWN span: an output underflow lands on a block's closing
  // token, and two arms sharing the `if`'s span print one line twice.
  let then_ = self.body(
    if_block.info,
    label,
    [],
    results,
    results,
    if_block.desc,
  )
  let else_ = match else_block {
    Some(b) => {
      let checked = self.body(b.info, label, [], results, results, b.desc)
      Some(
        (
          { desc: checked, info: b.info, } :
          @basic.Annotated[
            Array[@ast.Instr[@typing_env.InferredAnnotation]],
            @basic.Location,
          ]),
      )
    }
    None => {
      // No else, and a value is wanted: the false path delivers nothing.
      if !missing_else_ok(self.ctx.type_context.subtyping_info(), [], results) {
        if_without_else(self.ctx.diagnostics, i.info)
      }
      None
    }
  }
  check_subtype(
    self.ctx.type_context.subtyping_info(),
    self.ctx.diagnostics,
    i.info,
    result_cell,
    expected,
  )
  {
    desc: If(
      label~,
      typ=fill_omitted_result(typ, result_cell),
      cond=cond_,
      if_block={ desc: then_, info: if_block.info, },
      else_block=else_,
    ),
    info: annotate(results, i.info),
    hints: i.hints,
    expected: i.expected,
  }
}

///|
/// A `?:` checked against a type the context knows: the expectation goes into
/// BOTH value branches, so a construction in either can take it as its type.
///
/// The result is still the branches' JOIN and not the expectation itself. Each
/// branch is already a subtype of what was expected, so joining keeps the
/// select's own precise type rather than widening it to whatever the context
/// happened to ask for.
fn Checker::check_select(
  self : Checker,
  expected : @infer.Cell[@infer.InferredType],
  i : @ast.Instr[@basic.Location],
  cond : @ast.Instr[@basic.Location],
  a : @ast.Instr[@basic.Location],
  b : @ast.Instr[@basic.Location],
) -> @ast.Instr[@typing_env.InferredAnnotation] {
  // Emission order: the two branch values, then the condition.
  let a_ = self.check(expected, a)
  let b_ = self.check(expected, b)
  let cond_ = self.expression(cond)
  check_subtype(
    self.ctx.type_context.subtyping_info(),
    self.ctx.diagnostics,
    cond.info,
    expression_type(self.ctx, cond_.info),
    @infer.valtype_cell(@infer.i32_valtype),
  )
  let ty = match
    join_value_types(
      expression_type(self.ctx, a_.info),
      expression_type(self.ctx, b_.info),
      inferred_lub(self.ctx.type_context, self.ctx.diagnostics),
    ) {
    Some(t) => t
    // Both branches already fit the expectation, so there IS a common type even
    // when the join could not name one; recover with it rather than reporting a
    // mismatch the context has already ruled out.
    None => expected
  }
  {
    desc: Select(cond_, a_, b_),
    info: annotate([ty], i.info),
    hints: i.hints,
    expected: i.expected,
  }
}

///|
/// Check a typed node's value against the expectation, when there is one.
fn Checker::want(
  self : Checker,
  expected : @infer.Cell[@infer.InferredType],
  location : @basic.Location,
  c : @ast.Instr[@typing_env.InferredAnnotation],
) -> Unit {
  guard has_expectation(expected) else { return }
  check_subtype(
    self.ctx.type_context.subtyping_info(),
    self.ctx.diagnostics,
    location,
    expression_type(self.ctx, c.info),
    expected,
  )
}

///|
/// Check a value carried to a known destination -- a `br`'s target, a `return`'s
/// results -- against what that destination takes.
///
/// One expected value is checked against, so a construction delivered there can
/// take its type from the target. Several, or none, are synthesized and compared
/// as a tuple: there is no single type to hand down.
///
/// A target still being INFERRED is the exception, and it inverts: the value is
/// synthesized and then recorded against the cell, because that recording is
/// what the target's type will be made of. Checking against it would discard the
/// value instead.
fn Checker::check_against(
  self : Checker,
  expected : Array[@infer.Cell[@infer.InferredType]],
  e : @ast.Instr[@basic.Location],
) -> @ast.Instr[@typing_env.InferredAnnotation] {
  if expected.length() == 1 && !is_inferring(expected[0]) {
    return self.check(expected[0], e)
  }
  let c = self.expression(e)
  check_subtypes(
    self.ctx.type_context.subtyping_info(),
    self.ctx.diagnostics,
    e.info,
    c.info.0,
    expected,
  )
  c
}

///|
/// A block-like form with its omitted result filled in from the context.
///
/// `None` when there is nothing to fill -- the form declares its own result, or
/// takes parameters (which expression position has no stack to supply), or the
/// expectation is not a value type that can be written down.
///
/// This is the `context_result_cell` rewrite done on the SOURCE rather than on
/// the cells, which is what lets it reach a form whose arms compute their result
/// from the declared type: the body, every handler, and the type written back
/// all read the same place, so filling that one place reaches all of them.
fn pin_block_result(
  expected : @infer.Cell[@infer.InferredType],
  typ : @ast.FuncType,
  desc : @ast.InstrDesc[@basic.Location],
) -> @ast.InstrDesc[@basic.Location]? {
  guard typ.results.is_empty() && typ.params.is_empty() else { return None }
  guard @typing_env.standalone_valtype(expected) is Some(iv) else {
    return None
  }
  let filled : @ast.FuncType = { ..typ, results: [iv.typ], }
  match desc {
    TryTable(label~, catches~, block~, ..) =>
      Some(TryTable(label~, typ=filled, catches~, block~))
    Try(label~, block~, catches~, catch_all~, ..) =>
      Some(Try(label~, typ=filled, block~, catches~, catch_all~))
    TryCatch(label~, block~, arms~, ..) =>
      Some(TryCatch(label~, typ=filled, block~, arms~))
    _ => None
  }
}
