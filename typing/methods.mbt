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
pub fn is_binary_method(m : String) -> Bool {
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
  let args_ = rest.map(a => self.expression(a))
  let recv_ = self.expression(recv)
  // The operands as the instruction takes them: payload first, continuation on
  // top.
  let operands = args_.copy()
  operands.push(recv_)
  let results = match cont_receiver_type(ctx, recv_) {
    None => []
    Some(ct) =>
      match meth.name {
        "resume" =>
          self.type_resume(
            i.info,
            ct,
            handlers,
            operands,
            None,
            ref_first=false,
          )
        "resume_throw" =>
          match tag {
            Some(t) =>
              self.type_resume(
                i.info,
                ct,
                handlers,
                operands,
                Some(t),
                ref_first=false,
              )
            None => []
          }
        "resume_throw_ref" =>
          self.type_resume(i.info, ct, handlers, operands, None, ref_first=true)
        _ =>
          match tag {
            Some(t) => self.type_switch(i.info, ct, t, operands)
            None => []
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
                duplicate_argument_label(
                  ctx.diagnostics,
                  a.info,
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
/// `None` when the receiver is not a reference to a named type -- the mistake is
/// reported where the operands are checked, which has more to say about it.
fn cont_receiver_type(
  ctx : @typing_env.ModuleContext,
  recv : @ast.Instr[@typing_env.InferredAnnotation],
) -> @ast.Ident? {
  match expression_type(ctx, recv.info).get() {
    Valtype({ typ: Ref({ typ: Type(n) | Exact(n), .. }), .. }) => Some(n)
    _ => None
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
  let args_ = args.map(a => self.expression(a))
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
  ns : @ast.Ident,
  name : @ast.Ident,
  args : Array[@ast.Instr[@basic.Location]],
) -> @ast.Instr[@typing_env.InferredAnnotation] {
  let ctx = self.ctx
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
        operand_count_mismatch(
          ctx.diagnostics,
          i.info,
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
            i.info,
            expected=1,
            provided=0,
          )
        }
        self.cont_construct_recovery(i, ns, name, checked)
      }
    _ => {
      unknown_intrinsic(ctx.diagnostics, i.info, ns.name, name.name)
      self.cont_construct_recovery(i, ns, name, checked)
    }
  }
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
