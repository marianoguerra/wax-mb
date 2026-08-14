// Instruction methods that take arguments.
//
// Ported from `type_binary_intrinsic_call` and `type_cont_method_call` in
// wax/src/lib-wax/typing.ml.
//
// A method call is one syntax covering two quite different things. `x.min(y)` is
// a wasm instruction with the receiver as its first operand; `s.min(a, b)` is an
// indirect call through a struct field that happens to be called `min`. Nothing
// about the SPELLING distinguishes them -- not even the argument count -- so the
// receiver's type does, which is why the guard below reads that type without
// typing anything.
//
// The no-argument methods (`x.clz()`, `arr.length()`) were already here. These
// are their siblings that take operands, and until now they fell straight past
// every intrinsic guard into the indirect-call path, where the receiver was
// looked up as a struct and reported as not being one.

///|
/// The scalar binary intrinsics: the receiver and one operand, both numeric.
///
/// Gated on a NON-reference receiver, so a struct with a field of the same name
/// stays an indirect call. Any argument count is accepted past that gate: the
/// empty `x.min()` an auto-closed call leaves still yields the method node, with
/// an arity error, so recovery keeps the call rather than losing it.
fn Checker::is_binary_intrinsic(
  self : Checker,
  callee : @ast.Instr[@basic.Location],
) -> Bool {
  guard callee.desc is StructGet(recv, meth) else { return false }
  guard is_binary_method(meth.name) else { return false }
  !receiver_is_ref(self.ctx, recv)
}

///|
/// Whether a method name is a scalar binary instruction.
fn is_binary_method(m : String) -> Bool {
  match m {
    "rotl" | "rotr" | "copysign" | "min" | "max" => true
    _ => false
  }
}

///|
/// Type `x.op(y)`: the receiver is pushed first, then the operand.
///
/// The METHOD fixes the family -- `rotl`/`rotr` are integer, the rest float --
/// and the two operands are unified against each other exactly as the infix
/// operators are, because they lower to the same instructions.
fn Checker::binary_intrinsic(
  self : Checker,
  i : @ast.Instr[@basic.Location],
  callee : @ast.Instr[@basic.Location],
  recv : @ast.Instr[@basic.Location],
  meth : @ast.Ident,
  args : Array[@ast.Instr[@basic.Location]],
) -> @ast.Instr[@typing_env.InferredAnnotation] {
  let ctx = self.ctx
  let recv_ = self.expression(recv)
  let args_ = args.map(a => self.expression(a))
  let is_int = meth.name is ("rotl" | "rotr")
  fn rebuilt(
    ty : Array[@infer.Cell[@infer.InferredType]],
  ) -> @ast.Instr[@typing_env.InferredAnnotation] {
    {
      desc: Call(
        {
          desc: StructGet(recv_, meth),
          info: annotate([], callee.info),
          hints: callee.hints,
          expected: callee.expected,
        },
        args_,
      ),
      info: annotate(ty, i.info),
      hints: i.hints,
      expected: i.expected,
    }
  }

  guard args_.length() == 1 else {
    // The wrong arity: report it, but still hand back the method node with the
    // receiver typed, so the call survives for recovery.
    operand_count_mismatch(
      ctx.diagnostics,
      callee.info,
      expected=1,
      provided=args_.length(),
    )
    return rebuilt([expression_type(ctx, recv_.info)])
  }
  let ty1 = expression_type(ctx, recv_.info)
  let ty2 = expression_type(ctx, args_[0].info)
  fn check() -> @infer.Cell[@infer.InferredType] {
    if is_int {
      check_int_bin_op(ctx.diagnostics, meth.loc, ty1, ty2)
    } else {
      check_float_bin_op(ctx.diagnostics, meth.loc, ty1, ty2)
    }
  }

  // An abstract operand -- a value off the polymorphic stack of unreachable or
  // branch-terminated code -- is unified onto the other's type; two abstract
  // ones take the family's default, which is the only thing left to go on.
  let ty = match (ty1.get(), ty2.get()) {
    (Unknown | Error, Unknown | Error) => {
      ty1.merge(ty2, if is_int { Int } else { Float })
      ty1
    }
    (Unknown | Error, _) => {
      ty1.merge(ty2, ty2.get())
      check()
    }
    (_, Unknown | Error) => {
      ty1.merge(ty2, ty1.get())
      check()
    }
    _ => check()
  }
  rebuilt([ty])
}

///|
/// The stack-switching methods, which are written on the continuation itself.
///
/// These were keywords before they were methods, so claiming the names shadows
/// no struct field and the guard needs no receiver test.
fn Checker::cont_method(
  self : Checker,
  callee : @ast.Instr[@basic.Location],
) -> String? {
  ignore(self)
  guard callee.desc is StructGet(_, meth) else { return None }
  match meth.name {
    "resume" | "resume_throw" | "resume_throw_ref" | "switch" => Some(meth.name)
    _ => None
  }
}

///|
/// Type `c.resume(x)` and its siblings.
///
/// Emission order is the payload arguments and THEN the continuation receiver,
/// which is why the receiver is appended last: that is the operand list the
/// instruction actually takes, and it is what `type_resume` is written against.
///
/// The tag is an immediate rather than a value, and each form spells it
/// differently: `switch` takes it as a labelled argument, `resume_throw` as an
/// invocation carrying the payload. Both are extracted before the arguments are
/// typed, because neither is one.
fn Checker::cont_method_call(
  self : Checker,
  i : @ast.Instr[@basic.Location],
  callee : @ast.Instr[@basic.Location],
  recv : @ast.Instr[@basic.Location],
  meth : @ast.Ident,
  args : Array[@ast.Instr[@basic.Location]],
  handlers : Array[@ast.OnClause],
) -> @ast.Instr[@typing_env.InferredAnnotation] {
  let ctx = self.ctx
  let (tag, rest) = self.cont_method_tag(meth, args)
  // The RECEIVER is typed first, out of emission order: its continuation
  // signature is what says what the value operands should be, and an operand
  // that needs that -- a block whose result was omitted, a construction with no
  // name -- cannot be typed usefully before it is known.
  let recv_ = self.expression(recv)
  let ct = cont_receiver_type(ctx, recv_)
  let want = match ct {
    Some(c) => self.resume_operand_types(c, meth.name, tag)
    None => None
  }
  let args_ = rest.mapi((k, a) => {
    match want {
      Some(w) if k < w.length() => self.check(w[k], a)
      _ => self.expression(a)
    }
  })
  // The operands as the instruction takes them: payload first, continuation on
  // top.
  let operands = args_.copy()
  operands.push(recv_)
  // A missing continuation type or a missing tag was already reported, and
  // there is no instruction left to build. Recovered with the shape every
  // failed lookup here yields -- an `unreachable` typed `Error` -- rather than
  // with an operation that produces nothing: a chained
  // `c.switch().switch()` would then have a value-less receiver, and its own
  // complaint about that would bury the two real ones.
  let recovery = () => {
    (
      {
        desc: Unreachable,
        info: annotate([@infer.Cell::make(@infer.InferredType::Error)], i.info),
        hints: i.hints,
        expected: i.expected,
      } : @ast.Instr[@typing_env.InferredAnnotation])
  }
  guard ct is Some(ct) else { return recovery() }
  let results = match meth.name {
    "resume" =>
      self.type_resume(i.info, ct, handlers, operands, None, ref_first=false)
    "resume_throw" => {
      guard tag is Some(t) else { return recovery() }
      self.type_resume(i.info, ct, handlers, operands, Some(t), ref_first=false)
    }
    "resume_throw_ref" =>
      self.type_resume(i.info, ct, handlers, operands, None, ref_first=true)
    _ => {
      guard tag is Some(t) else { return recovery() }
      self.type_switch(i.info, ct, t, operands)
    }
  }
  // The TAG is kept on the typed node, re-wrapped with a `tag:` label, exactly
  // as a memory access keeps its immediates. It is not a value -- nothing
  // pushes it -- but it IS part of the instruction, and the code generator has
  // no other place to read it from. `switch` wrote it that way already;
  // `resume_throw` wrote it as an invocation, and this is the one shape both
  // can be read out of.
  if tag is Some(t) {
    args_.push({
      desc: Labelled({ name: "tag", loc: t.loc }, {
        desc: Get(t),
        info: annotate([], t.loc),
        hints: @ast.no_hints,
        expected: None,
      }),
      info: annotate([], t.loc),
      hints: @ast.no_hints,
      expected: None,
    })
  }
  {
    desc: Call(
      {
        desc: StructGet(recv_, meth),
        info: annotate([], callee.info),
        hints: callee.hints,
        expected: callee.expected,
      },
      args_,
    ),
    info: annotate(results, i.info),
    hints: i.hints,
    expected: i.expected,
  }
}

///|
/// Split a continuation method's tag immediate out of its arguments.
///
/// `switch` writes it as `tag: t`, `resume_throw` as `exc(payload)` -- the tag
/// invoked with what it carries, as a `throw` writes it. Every other form takes
/// no tag at all.
fn Checker::cont_method_tag(
  self : Checker,
  meth : @ast.Ident,
  args : Array[@ast.Instr[@basic.Location]],
) -> (@ast.Ident?, Array[@ast.Instr[@basic.Location]]) {
  let ctx = self.ctx
  match meth.name {
    "switch" => {
      let mut tag : @ast.Ident? = None
      let rest : Array[@ast.Instr[@basic.Location]] = []
      for a in args {
        match a.desc {
          Labelled(l, v) =>
            if l.name == "tag" && v.desc is Get(t) {
              if tag is Some(prev) {
                // At the tag NAME both times, not at the whole `tag: e`: the
                // two names are what the reader compares, and the label is the
                // same word in both.
                duplicate_argument_label(
                  ctx.diagnostics,
                  t.loc,
                  prev.loc,
                  "tag",
                )
              } else {
                tag = Some(t)
              }
            } else {
              rest.push(a)
            }
          _ => rest.push(a)
        }
      }
      // Anchored at the METHOD, not the whole call: a chained
      // `c.switch().switch()` would otherwise report both at the shared
      // chain-start column.
      if tag is None {
        switch_needs_tag(ctx.diagnostics, meth.loc)
      }
      (tag, rest)
    }
    "resume_throw" =>
      match args {
        [{ desc: Call(callee, payload), .. }] if callee.desc is Get(_) => {
          guard callee.desc is Get(t) else { return (None, args) }
          (Some(t), payload)
        }
        _ => {
          resume_throw_needs_tag(ctx.diagnostics, meth.loc)
          (None, args)
        }
      }
    _ => (None, args)
  }
}

///|
/// The continuation TYPE a method receiver refers to.
///
/// The name is not a convenience: `resume` and its siblings carry the
/// continuation type as an IMMEDIATE, so a receiver that does not NAME one
/// leaves nothing to write in the instruction. Each way of failing to name one
/// is a different thing to say -- an abstract `&cont` cannot be narrowed to a
/// declared type at all, a value off the polymorphic stack has no type yet, and
/// anything else is simply not a continuation -- except poison, which was
/// reported where it was made.
fn cont_receiver_type(
  ctx : @typing_env.ModuleContext,
  recv : @ast.Instr[@typing_env.InferredAnnotation],
) -> @ast.Ident? {
  let loc = recv.info.1
  match expression_type(ctx, recv.info).get() {
    Valtype({ typ: Ref({ typ: Type(n) | Exact(n), .. }), .. }) =>
      if ctx.type_context.types.find_no_mark(n.name) is Some((_, def)) &&
        def.typ is Cont(_) {
        Some(n)
      } else {
        expected_cont_type(ctx.diagnostics, loc)
        None
      }
    Valtype({ typ: Ref({ typ: Cont | NoCont, .. }), .. }) => {
      abstract_cont_receiver(ctx.diagnostics, loc)
      None
    }
    Error => None
    Unknown | UnknownRef => {
      unknown_operand_type(ctx.diagnostics, loc)
      None
    }
    _ => {
      expected_cont_type(ctx.diagnostics, loc)
      None
    }
  }
}

///|
/// The array bulk methods, which take the array as their receiver.
///
/// At its exact arity the method is recognised whatever the receiver looks like:
/// the receiver is an EXPRESSION -- `(a as &float_array).fill(..)`,
/// `stack.v2.copy(..)`, a `br_on_cast_fail` -- and its type is not known until
/// it has been typed, which is after this guard runs. The arity is what
/// identifies the call, and the receiver's type is then checked properly by
/// `element_written`.
///
/// At the WRONG arity there is nothing to identify it by, so that case is gated
/// on a receiver whose type is visibly an array. It exists for the empty
/// `a.fill()` an auto-closed call leaves; a struct with a field of the same name
/// stays an indirect call.
fn Checker::array_bulk_method(
  self : Checker,
  callee : @ast.Instr[@basic.Location],
  args : Array[@ast.Instr[@basic.Location]],
) -> String? {
  guard callee.desc is StructGet(recv, meth) else { return None }
  guard meth.name is ("fill" | "copy" | "init") else { return None }
  let arity = if meth.name == "fill" { 3 } else { 4 }
  if args.length() == arity {
    return Some(meth.name)
  }
  guard receiver_is_array_ref(self.ctx, recv) else { return None }
  Some(meth.name)
}

///|
/// Type `a.fill(j, v, n)`, `a.copy(i, src, j, n)` and `a.init(seg, d, s, n)`.
///
/// Each takes its operands in emission order with the receiver first, and each
/// writes into the array -- so all three demand a mutable element type, and say
/// so at the array rather than at the call.
///
/// A wrong argument count still yields the method node with everything typed:
/// the empty `a.fill()` an auto-closed call leaves is worth keeping as a call,
/// so recovery and the editor still see one.
fn Checker::array_bulk_call(
  self : Checker,
  i : @ast.Instr[@basic.Location],
  callee : @ast.Instr[@basic.Location],
  recv : @ast.Instr[@basic.Location],
  meth : @ast.Ident,
  args : Array[@ast.Instr[@basic.Location]],
) -> @ast.Instr[@typing_env.InferredAnnotation] {
  let ctx = self.ctx
  let recv_ = self.expression(recv)
  // `a.init(seg, ..)` names a SEGMENT first, and a segment is not a value:
  // typing it as an expression looks for a variable of that name and reports
  // it unbound. It is kept on the node with an empty annotation, exactly as a
  // memory's `init` keeps its segment, because the code generator reads the
  // name from there.
  let segment = if meth.name == "init" &&
    args.length() >= 1 &&
    args[0].desc is Get(n) {
    Some(n)
  } else {
    None
  }
  let args_ = args.mapi((k, a) => {
    if k == 0 && segment is Some(_) {
      a.map_info(_ => annotate([], a.info))
    } else {
      self.expression(a)
    }
  })
  if segment is Some(n) {
    // Either space may hold it: `array.init_data` and `array.init_elem` are
    // told apart by which one does.
    if ctx.datas.visible(n.name).is_empty() &&
      ctx.elems.visible(n.name).is_empty() {
      let _ = find(ctx.datas, ctx.diagnostics, n)
    } else {
      note_use(ctx, ctx.datas, n)
      note_use(ctx, ctx.elems, n)
    }
  }
  let i32c = @infer.valtype_cell(@infer.i32_valtype)
  fn want_i32(k : Int) -> Unit {
    if k < args_.length() {
      check_subtype(
        ctx.type_context.subtyping_info(),
        ctx.diagnostics,
        args[k].info,
        expression_type(ctx, args_[k].info),
        i32c,
      )
    }
  }

  // The element type the receiver stores, once it is known to be an array that
  // can be written to. `None` when the receiver failed, is polymorphic, or is
  // not an array at all -- each already reported by `element_written`.
  let elt = self.element_written(recv, recv_, meth)
  let arity = if meth.name == "fill" { 3 } else { 4 }
  if args_.length() != arity {
    operand_count_mismatch(
      ctx.diagnostics,
      callee.info,
      expected=arity,
      provided=args_.length(),
    )
  } else {
    match meth.name {
      "fill" => {
        // `a.fill(j, v, n)`: the value goes into every slot, so it must fit the
        // element type.
        want_i32(0)
        want_i32(2)
        if elt is Some(field) &&
          internalize(ctx.type_context, ctx.diagnostics, unpack_type(field))
          is Some(cell) {
          check_subtype(
            ctx.type_context.subtyping_info(),
            ctx.diagnostics,
            args[1].info,
            expression_type(ctx, args_[1].info),
            cell,
          )
        }
      }
      "copy" => {
        // `dst.copy(i, src, j, n)`: the SOURCE's elements must fit the
        // destination's, which is the ordinary direction for a store.
        want_i32(0)
        want_i32(2)
        want_i32(3)
        if elt is Some(field) &&
          array_element_of(ctx, args[1].info, args_[1]) is Some(src) {
          if !elements_compatible(ctx, src.typ, field.typ) {
            incompatible_array_elements(ctx.diagnostics, args[1].info)
          }
        }
      }
      // `a.init(seg, d, s, n)`: the element type picks which kind of segment
      // the name has to be -- a reference element takes an elem segment, and
      // anything else a data segment.
      _ => {
        want_i32(1)
        want_i32(2)
        want_i32(3)
        // The segment is named in the INSTRUCTION -- `array.init_data` and
        // `array.init_elem` each carry a segment index -- so anything but a
        // name there has no lowering at all. Quiet when the receiver is
        // already poison: a failed call recovers with `Error`, so a chained
        // `a.init(..).init(..)` would repeat the rejection once per link, and
        // they share a start column and render as one line repeated.
        if segment is None &&
          !(@typing_env.expression_type_opt(recv_.info).map(c => c.get())
          is Some(Error)) {
          invalid_management_call(ctx.diagnostics, i.info, meth.name)
        }
        if elt is Some(field) && args[0].desc is Get(seg) {
          match field.typ {
            Value(Ref(dst)) =>
              if find(ctx.elems, ctx.diagnostics, seg) is Some(src) {
                check_elem_subtype(ctx, recv.info, src, dst)
              }
            _ => ignore(find(ctx.datas, ctx.diagnostics, seg))
          }
        }
      }
    }
  }
  {
    desc: Call(
      {
        desc: StructGet(recv_, meth),
        info: annotate([], callee.info),
        hints: callee.hints,
        expected: callee.expected,
      },
      args_,
    ),
    info: annotate([], i.info),
    hints: i.hints,
    expected: i.expected,
  }
}

///|
/// The element type a bulk method writes into, reporting why there is none.
///
/// The three cases below are three different failures. A poisoned receiver was
/// already complained about, so this stays quiet. A polymorphic one -- a value
/// off the stack of unreachable or branch-terminated code -- has no element type
/// to resolve, which is a different thing from having the wrong one. And
/// anything else simply is not an array.
fn Checker::element_written(
  self : Checker,
  recv : @ast.Instr[@basic.Location],
  recv_ : @ast.Instr[@typing_env.InferredAnnotation],
  meth : @ast.Ident,
) -> @wasm_types.MutType[@wasm_types.StorageType[@ast.Ident]]? {
  ignore(meth)
  let ctx = self.ctx
  match expression_type(ctx, recv_.info).get() {
    Valtype({ typ: Ref({ typ: Type(n) | Exact(n), .. }), .. }) => {
      guard lookup_array_type(
          ctx.type_context,
          ctx.diagnostics,
          n,
          location=Some(recv.info),
        )
        is Some(field) else {
        return None
      }
      if !field.mut_ {
        immutable(ctx.diagnostics, recv.info, "array")
      }
      Some(field)
    }
    Error => None
    Unknown | UnknownRef => {
      unknown_operand_type(ctx.diagnostics, recv.info)
      None
    }
    _ => {
      expected_array(ctx.diagnostics, recv.info)
      None
    }
  }
}

///|
/// The element type of an already-typed array operand.
fn array_element_of(
  ctx : @typing_env.ModuleContext,
  location : @basic.Location,
  a : @ast.Instr[@typing_env.InferredAnnotation],
) -> @wasm_types.MutType[@wasm_types.StorageType[@ast.Ident]]? {
  match expression_type(ctx, a.info).get() {
    Valtype({ typ: Ref({ typ: Type(n) | Exact(n), .. }), .. }) =>
      lookup_array_type(
        ctx.type_context,
        ctx.diagnostics,
        n,
        location=Some(location),
      )
    _ => None
  }
}

///|
/// Whether one array's elements can be stored into another's.
///
/// A packed element is a subtype of itself alone: `i8` and `i16` are different
/// widths, and neither is a value type -- so the two sides must agree on being
/// packed before there is anything to compare.
fn elements_compatible(
  ctx : @typing_env.ModuleContext,
  src : @wasm_types.StorageType[@ast.Ident],
  dst : @wasm_types.StorageType[@ast.Ident],
) -> Bool {
  match (src, dst) {
    (Packed(a), Packed(b)) => a == b
    (Value(a), Value(b)) => {
      guard internalize(ctx.type_context, ctx.diagnostics, a) is Some(x) &&
        internalize(ctx.type_context, ctx.diagnostics, b) is Some(y) else {
        return true
      }
      subtype(ctx.type_context.subtyping_info(), x, y)
    }
    _ => false
  }
}

///|
/// Whether a qualified path names a declared CONTINUATION type.
///
/// A continuation type is also a namespace, holding the two constructors that
/// build one: `k::new(f)` wraps a function, `k::bind(x, c)` binds away a leading
/// parameter of another continuation. Both yield a `&k`, which is why the type
/// itself is the namespace.
fn Checker::cont_namespace(
  self : Checker,
  callee : @ast.Instr[@basic.Location],
) -> @ast.Ident? {
  guard callee.desc is Path(ns, _) else { return None }
  guard self.ctx.type_context.types.find_no_mark(ns.name) is Some((_, def)) else {
    return None
  }
  guard def.typ is Cont(_) else { return None }
  Some(ns)
}

///|
/// Type `k::new(f)` and `k::bind(x, c)`.
///
/// Both build a FRESH continuation of exactly `k`, so both produce an exact
/// reference -- the same rule as `struct.new` and `array.new`, and gated on the
/// same feature, since exact reference types belong to custom-descriptors.
///
/// The typed node is the raw `cont.new` / `cont.bind` form rather than the path
/// spelling: the two are the same instruction, and the lowering has one place to
/// read it from.
fn Checker::cont_construct(
  self : Checker,
  i : @ast.Instr[@basic.Location],
  callee_loc : @basic.Location,
  ns : @ast.Ident,
  name : @ast.Ident,
  args : Array[@ast.Instr[@basic.Location]],
) -> @ast.Instr[@typing_env.InferredAnnotation] {
  let ctx = self.ctx
  // `bind` is typed back to front: the SOURCE continuation is the last
  // operand, and until it is known there is nothing to check the bound values
  // against. A block written as a bound value -- `k::bind('l: do { .. }, c)`
  // -- has no result type of its own and takes one from that check, so typing
  // it first leaves it producing nothing.
  if name.name == "bind" && args.length() >= 1 {
    return self.cont_bind_call(i, ns, name, args)
  }
  let checked = args.map(a => self.expression(a))
  match name.name {
    "new" =>
      if checked.length() == 1 {
        // The function a continuation is made of, as a NULLABLE reference: a
        // null one traps when resumed rather than being rejected here.
        if lookup_cont_inner(ctx.type_context, ctx.diagnostics, ns) is Some(ft) &&
          internalize(
            ctx.type_context,
            ctx.diagnostics,
            Ref({ nullable: true, typ: Type(ft) }),
          )
          is Some(want) {
          check_subtype(
            ctx.type_context.subtyping_info(),
            ctx.diagnostics,
            args[0].info,
            expression_type(ctx, checked[0].info),
            want,
          )
        }
        {
          desc: ContNew(ns, checked[0]),
          info: annotate([self.fresh_continuation(ns)], i.info),
          hints: i.hints,
          expected: i.expected,
        }
      } else {
        // At the intrinsic's name: the arity belongs to the instruction, and
        // what was written in the parentheses is not the mistake.
        operand_count_mismatch(
          ctx.diagnostics,
          callee_loc,
          expected=1,
          provided=checked.length(),
        )
        self.cont_construct_recovery(i, ns, name, checked)
      }
    "bind" =>
      // The SOURCE continuation is the last operand -- the bound values come
      // first, as they do on the stack -- and its type is what says which
      // continuation is being narrowed.
      if checked.length() >= 1 &&
        cont_receiver_type(ctx, checked[checked.length() - 1]) is Some(src) {
        self.check_cont_bind(i.info, src, ns, args, checked)
        {
          desc: ContBind(src, ns, checked),
          info: annotate([self.fresh_continuation(ns)], i.info),
          hints: i.hints,
          expected: i.expected,
        }
      } else {
        if checked.is_empty() {
          operand_count_mismatch(
            ctx.diagnostics,
            callee_loc,
            expected=1,
            provided=0,
          )
        }
        self.cont_construct_recovery(i, ns, name, checked)
      }
    _ => {
      // At the NAME, not at the whole call: what does not exist is the
      // intrinsic, and its arguments are not part of the mistake.
      unknown_intrinsic(ctx.diagnostics, callee_loc, ns.name, name.name)
      self.cont_construct_recovery(i, ns, name, checked)
    }
  }
}

///|
/// `k::bind(v.., c)`: the bound values, then the continuation they are bound
/// into.
///
/// The continuation comes LAST, as it does on the stack, and it is what says
/// how many values are being bound and what their types are -- so it is typed
/// first and the values are then CHECKED rather than merely inferred.
fn Checker::cont_bind_call(
  self : Checker,
  i : @ast.Instr[@basic.Location],
  ns : @ast.Ident,
  name : @ast.Ident,
  args : Array[@ast.Instr[@basic.Location]],
) -> @ast.Instr[@typing_env.InferredAnnotation] {
  let ctx = self.ctx
  let last = args.length() - 1
  let src_ = self.expression(args[last])
  guard cont_receiver_type(ctx, src_) is Some(src) else {
    let checked = args[:last].to_owned().map(a => self.expression(a))
    checked.push(src_)
    return self.cont_construct_recovery(i, ns, name, checked)
  }
  let want = self.cont_bind_params(src, ns)
  let checked : Array[@ast.Instr[@typing_env.InferredAnnotation]] = []
  for k in 0..<last {
    checked.push(
      if k < want.length() {
        self.check(want[k], args[k])
      } else {
        self.expression(args[k])
      },
    )
  }
  checked.push(src_)
  self.check_cont_bind(i.info, src, ns, args, checked)
  {
    desc: ContBind(src, ns, checked),
    info: annotate([self.fresh_continuation(ns)], i.info),
    hints: i.hints,
    expected: i.expected,
  }
}

///|
/// The types `k::bind` binds: the leading parameters the source continuation
/// has and the destination does not.
fn Checker::cont_bind_params(
  self : Checker,
  src : @ast.Ident,
  dst : @ast.Ident,
) -> Array[@infer.Cell[@infer.InferredType]] {
  let ctx = self.ctx
  let out : Array[@infer.Cell[@infer.InferredType]] = []
  guard lookup_cont_inner(ctx.type_context, ctx.diagnostics, src)
    is Some(src_inner) else {
    return out
  }
  guard lookup_func_type(ctx.type_context, ctx.diagnostics, src_inner)
    is Some(src_sig) else {
    return out
  }
  guard lookup_cont_inner(ctx.type_context, ctx.diagnostics, dst)
    is Some(dst_inner) else {
    return out
  }
  guard lookup_func_type(ctx.type_context, ctx.diagnostics, dst_inner)
    is Some(dst_sig) else {
    return out
  }
  let np = src_sig.params.length() - dst_sig.params.length()
  for k in 0..<np {
    if k < src_sig.params.length() {
      if internalize(
          ctx.type_context,
          ctx.diagnostics,
          src_sig.params[k].desc.1,
        )
        is Some(c) {
        out.push(c)
      }
    }
  }
  out
}

///|
/// Keep a malformed continuation construction as the call it was written as.
///
/// The arguments are already typed, so their own mistakes are reported; only
/// this node's result is poison, and poison is what stops the failure being
/// reported again by whatever consumes it.
fn Checker::cont_construct_recovery(
  self : Checker,
  i : @ast.Instr[@basic.Location],
  ns : @ast.Ident,
  name : @ast.Ident,
  checked : Array[@ast.Instr[@typing_env.InferredAnnotation]],
) -> @ast.Instr[@typing_env.InferredAnnotation] {
  ignore(self)
  {
    desc: Call(
      {
        desc: Path(ns, name),
        info: annotate([], i.info),
        hints: { branch: None, freq: None, targets: None },
        expected: None,
      },
      checked,
    ),
    info: annotate([@infer.Cell::make(@infer.InferredType::Error)], i.info),
    hints: i.hints,
    expected: i.expected,
  }
}

///|
/// Whether a qualified path names one of the `i64::` wide-arithmetic
/// intrinsics.
///
/// They need an arm of their own rather than joining the SIMD free intrinsics,
/// because they produce TWO values -- the low and high halves -- and every other
/// free intrinsic produces one.
fn Checker::wide_arith(
  self : Checker,
  callee : @ast.Instr[@basic.Location],
) -> Bool {
  ignore(self)
  guard callee.desc is Path(ns, _) else { return false }
  ns.name == "i64"
}

///|
/// Type `i64::add128(a_lo, a_hi, b_lo, b_hi)` and its siblings.
///
/// `add128`/`sub128` take each 128-bit input as a low/high pair, so four
/// operands; `mul_wide_s`/`mul_wide_u` take two. All of them are i64, and all of
/// them return the result as a low/high pair.
fn Checker::wide_arith_call(
  self : Checker,
  i : @ast.Instr[@basic.Location],
  callee : @ast.Instr[@basic.Location],
  ns : @ast.Ident,
  name : @ast.Ident,
  args : Array[@ast.Instr[@basic.Location]],
) -> @ast.Instr[@typing_env.InferredAnnotation] {
  let ctx = self.ctx
  let i64c = () => @infer.valtype_cell(@infer.i64_valtype)
  let checked = args.map(a => self.check(i64c(), a))
  let arity = match name.name {
    "add128" | "sub128" => Some(4)
    "mul_wide_s" | "mul_wide_u" => Some(2)
    _ => None
  }
  let results = match arity {
    None => {
      unknown_intrinsic(ctx.diagnostics, callee.info, ns.name, name.name)
      // Recovered with TWO poison results -- the arity every wide-arithmetic
      // intrinsic has -- so a typo does not also produce a value-count error.
      [
        @infer.Cell::make(@infer.InferredType::Error),
        @infer.Cell::make(@infer.InferredType::Error),
      ]
    }
    Some(n) => {
      if checked.length() != n {
        operand_count_mismatch(
          ctx.diagnostics,
          callee.info,
          expected=n,
          provided=checked.length(),
        )
      }
      [i64c(), i64c()]
    }
  }
  {
    desc: Call(callee.map_info(_ => annotate([], callee.info)), checked),
    info: annotate(results, i.info),
    hints: i.hints,
    expected: i.expected,
  }
}

///|
/// The types a stack-switching method's VALUE operands should have.
///
/// Each form takes them from somewhere different, and none of them from the
/// operands themselves: `resume` from the continuation's parameters, `switch`
/// from all but its last (the slot the current continuation goes in),
/// `resume_throw` from the tag it raises, and `resume_throw_ref` from the one
/// exception reference it takes.
///
/// `None` when the source is not resolvable -- the operands are then typed as
/// written, and whatever is wrong with them is reported where they are checked.
fn Checker::resume_operand_types(
  self : Checker,
  ct : @ast.Ident,
  meth : String,
  tag : @ast.Ident?,
) -> Array[@infer.Cell[@infer.InferredType]]? {
  let ctx = self.ctx
  fn cont_params() -> Array[@wasm_types.ValType[@ast.Ident]]? {
    guard lookup_cont_inner(ctx.type_context, ctx.diagnostics, ct)
      is Some(inner) else {
      return None
    }
    guard lookup_func_type(ctx.type_context, ctx.diagnostics, inner) is Some(sg) else {
      return None
    }
    Some(sg.params.map(p => p.desc.1))
  }

  fn cells(
    ts : Array[@wasm_types.ValType[@ast.Ident]],
  ) -> Array[@infer.Cell[@infer.InferredType]]? {
    let out : Array[@infer.Cell[@infer.InferredType]] = []
    for t in ts {
      guard internalize(ctx.type_context, ctx.diagnostics, t) is Some(c) else {
        return None
      }
      out.push(c)
    }
    Some(out)
  }

  match meth {
    "resume_throw_ref" => cells([Ref({ nullable: true, typ: Exn })])
    "resume_throw" => {
      guard tag is Some(t) else { return None }
      guard find(ctx.tags, ctx.diagnostics, t) is Some(ft) else { return None }
      cells(ft.params.map(p => p.desc.1))
    }
    "resume" => cont_params().bind(cells)
    "switch" =>
      cont_params().bind(ps => {
        // The last parameter is the slot the CURRENT continuation is passed
        // in, so it is not written as an operand.
        let n = if ps.length() > 0 { ps.length() - 1 } else { 0 }
        cells(ps[0:n].to_owned())
      })
    _ => None
  }
}

///|
/// Type a stack-switching instruction's value operands against the types the
/// construct says they should have.
///
/// The trailing continuation operand is not among them -- the raw forms name
/// their continuation TYPE rather than passing it as a value, so the operand
/// list here is only the payload.
fn Checker::resume_operands(
  self : Checker,
  ct : @ast.Ident,
  meth : String,
  tag : @ast.Ident?,
  args : Array[@ast.Instr[@basic.Location]],
) -> Array[@ast.Instr[@typing_env.InferredAnnotation]] {
  let want = self.resume_operand_types(ct, meth, tag)
  args.mapi((k, a) => {
    match want {
      Some(w) if k < w.length() => self.check(w[k], a)
      _ => self.expression(a)
    }
  })
}
