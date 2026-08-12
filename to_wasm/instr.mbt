// Lowering instructions.
//
// Ported from the instruction cases of wax/src/lib-conversion/to_wasm.ml.
//
// One wax instruction becomes a SEQUENCE of wasm instructions, because wax is an
// expression language and wasm is a stack machine: `a + b` emits `a`, then `b`,
// then the add. So every case here appends, and the order it appends in is the
// evaluation order the checker validated.

///|
/// Lower one instruction, appending to `out`.
pub fn Lowering::instr(
  self : Lowering,
  out : Array[@wasm_bin.Instruction],
  i : @ast.Instr[@typing_env.InferredAnnotation],
) -> Unit raise LowerError {
  // A branch hint attaches to the instruction it annotates, and the format
  // records it by BYTE OFFSET in a custom section -- so it has to be carried
  // on the instruction until the encoder knows where that instruction landed.
  // The wrapper is how it rides along.
  guard i.hints.is_empty() else {
    let inner : Array[@wasm_bin.Instruction] = []
    self.hinted(inner, i)
    guard inner.length() >= 1 else { return }
    // The hint belongs to the LAST instruction emitted, which is the one the
    // node is: everything before it computed the operands.
    for k in 0..<(inner.length() - 1) {
      out.push(inner[k])
    }
    out.push(Hinted(lower_hints(i.hints), inner[inner.length() - 1]))
    return
  }
  self.hinted(out, i)
}

///|
/// The hints an instruction carries, in the form the encoder writes.
fn lower_hints(h : @ast.Hints) -> @wasm_bin.InstrHints {
  {
    branch: h.branch.map(x => x.value),
    freq: h.freq.map(x => x.value),
    // A call-target hint names functions, which this lowering has no index for
    // at the point the hint is read; it is dropped rather than guessed.
    targets: None,
  }
}

///|
/// Lower one instruction, appending to `out`.
fn Lowering::hinted(
  self : Lowering,
  out : Array[@wasm_bin.Instruction],
  i : @ast.Instr[@typing_env.InferredAnnotation],
) -> Unit raise LowerError {
  let loc = i.info.1
  match i.desc {
    // A hole emits NOTHING. `_` means "the value already on the stack", put
    // there by an earlier statement -- so the instruction that consumes it
    // simply finds it, and there is nothing for the hole itself to push. The
    // checker has already validated that the value is there and has the right
    // type; that is the whole content of the hole machinery.
    Hole => ()
    Nop => out.push(Nop)
    Unreachable => out.push(Unreachable)
    Int(s) =>
      match node_valtype(i) {
        Some(I32) => out.push(I32Const(parse_i32(s, loc)))
        Some(I64) => out.push(I64Const(parse_i64(s, loc)))
        Some(F32) =>
          out.push(
            F32Const(Float::from_double(parse_float_bits(s, false, loc))),
          )
        Some(F64) => out.push(F64Const(parse_float_bits(s, true, loc)))
        _ => raise Unresolved("integer literal type", loc)
      }
    Float(s) =>
      match node_valtype(i) {
        Some(F32) =>
          out.push(
            F32Const(Float::from_double(parse_float_bits(s, false, loc))),
          )
        Some(F64) => out.push(F64Const(parse_float_bits(s, true, loc)))
        _ => raise Unresolved("float literal type", loc)
      }
    // A character literal is an i32 code point.
    Char(c) => out.push(I32Const(c.to_int()))
    Get(name) => out.push(self.read(name, loc))
    Set(name, op, value) => {
      // `x op= e` is `x = x op e`: the read comes first, then the operand, then
      // the operator, then the write. The compound form is kept in the typed
      // AST so it round-trips; here it is spelled out.
      match op {
        None => self.instr(out, value)
        Some(binop) => {
          out.push(self.read(name, loc))
          self.instr(out, value)
          guard node_valtype(value) is Some(ty) else {
            raise Unresolved("compound operand type", loc)
          }
          guard binop_instruction(binop.desc, ty) is Some(instruction) else {
            raise NotLowered("compound operator at this type", loc)
          }
          out.push(instruction)
        }
      }
      out.push(self.write(name, loc))
    }
    Tee(name, value) => {
      self.instr(out, value)
      guard self.locals.get(name.name) is Some(k) else {
        raise Unresolved("tee target", loc)
      }
      out.push(LocalTee(k))
    }
    BinOpI(op, a, b) => {
      self.instr(out, a)
      self.instr(out, b)
      // The OPERANDS' type, not the result's: a comparison yields i32 whatever
      // it compared, so reading the result would pick `i32.lt_s` for a pair of
      // f64s.
      guard node_valtype(a) is Some(ty) else {
        raise Unresolved("operand type", loc)
      }
      // Reference equality is its own instruction, and there is no `ref.ne`:
      // `a != b` on references is the negation of `a == b`.
      if ty is Ref(_) {
        match op.desc {
          Eq => {
            out.push(RefEqInstr)
            return
          }
          Ne => {
            out.push(RefEqInstr)
            out.push(I32Eqz)
            return
          }
          _ => ()
        }
      }
      guard binop_instruction(op.desc, ty) is Some(instruction) else {
        raise NotLowered("operator at this type", loc)
      }
      out.push(instruction)
    }
    UnOpI(op, a) =>
      match op.desc {
        // `+x` is the identity; it exists to be written, not emitted.
        Pos => self.instr(out, a)
        // `-x` is `0 - x` for an integer and a real instruction for a float.
        Neg =>
          match node_valtype(i) {
            // A negated LITERAL folds into the constant, exactly as the code
            // generator folds it -- `-40` is one instruction, not a subtraction
            // from zero. Only a bare literal folds; `--x` is a real
            // subtraction, and the checker has already told them apart.
            Some(I32) =>
              if a.desc is Int(s) {
                out.push(I32Const(-parse_i64(s, loc).to_int()))
              } else {
                out.push(I32Const(0))
                self.instr(out, a)
                out.push(I32Sub)
              }
            Some(I64) =>
              if a.desc is Int(s) {
                out.push(I64Const(-parse_i64(s, loc)))
              } else {
                out.push(I64Const(0))
                self.instr(out, a)
                out.push(I64Sub)
              }
            Some(F32) => {
              self.instr(out, a)
              out.push(F32Neg)
            }
            Some(F64) => {
              self.instr(out, a)
              out.push(F64Neg)
            }
            _ => raise Unresolved("negation type", loc)
          }
        // `!x` is `x == 0` on an integer and `ref.is_null` on a reference --
        // the same question, asked of two different kinds of nothing.
        Not => {
          self.instr(out, a)
          match node_valtype(a) {
            Some(I32) => out.push(I32Eqz)
            Some(I64) => out.push(I64Eqz)
            Some(Ref(_)) => out.push(RefIsNull)
            _ => raise NotLowered("logical not at this type", loc)
          }
        }
      }
    Sequence(l) =>
      for s in l {
        self.instr(out, s)
      }
    Return(operand) => {
      if operand is Some(e) {
        self.instr(out, e)
      }
      out.push(Return)
    }
    Br(label, operand) => {
      if operand is Some(e) {
        self.instr(out, e)
      }
      out.push(Br(self.depth(label, loc)))
    }
    BrIf(label, operand) => {
      self.instr(out, operand)
      out.push(BrIf(self.depth(label, loc)))
    }
    Let(bindings, init) => {
      if init is Some(e) {
        self.instr(out, e)
      }
      // Bound right to left: the values are on the stack with the LAST on top,
      // and each `local.set` takes the top one.
      for k = bindings.length() - 1; k >= 0; k = k - 1 {
        match bindings[k].0 {
          // An anonymous binding is a drop: `_ = e` computes and discards.
          None => out.push(Drop)
          Some(name) => {
            guard self.locals.get(name.name) is Some(slot) else {
              raise Unresolved("local binding", loc)
            }
            out.push(LocalSet(slot))
          }
        }
      }
    }
    Block(label~, typ~, block~) =>
      out.push(Block(self.block_type(typ, loc), self.body(label, block.desc)))
    Loop(label~, typ~, block~) =>
      out.push(Loop(self.block_type(typ, loc), self.body(label, block.desc)))
    If(label~, typ~, cond~, if_block~, else_block~) => {
      self.instr(out, cond)
      let then_ = self.body(label, if_block.desc)
      let else_ = match else_block {
        Some(b) => self.body(label, b.desc)
        None => []
      }
      out.push(If(self.block_type(typ, loc), then_, else_))
    }
    TailCall(callee, args) => {
      for a in args {
        self.instr(out, a)
      }
      guard callee.desc is Get(name) else {
        raise NotLowered("indirect tail call", loc)
      }
      guard self.indices.funcs.get(name.name) is Some(f) else {
        raise Unresolved("tail-call target", loc)
      }
      out.push(ReturnCall(f))
    }
    Call(callee, args) => {
      // The special forms come FIRST and emit their own operands, because they
      // do not all take them in written order and some of the arguments are
      // immediates rather than values. Only the ordinary call falls through to
      // the plain left-to-right walk below.
      //
      // A memory access: the receiver names the memory, and the labelled
      // immediates among the arguments are the memarg.
      if callee.desc is StructGet(recv, meth) && recv.desc is Get(memname) {
        if self.indices.memories.get(memname.name) is Some(mem) {
          let (align, offset) = self.memarg(meth, args, loc)
          if store_instruction(meth.name, mem, align, offset) is Some(st) {
            for a in args {
              if !(a.desc is Labelled(_, _)) {
                self.instr(out, a)
              }
            }
            out.push(st)
            return
          }
          if load_instruction(meth.name, mem, align, offset, None) is Some(ld) {
            for a in args {
              if !(a.desc is Labelled(_, _)) {
                self.instr(out, a)
              }
            }
            out.push(ld)
            return
          }
        }
      }
      // The qualified-path intrinsics, which have no receiver: the `v128::`
      // constants and bitselect, `atomic::fence`, and the wide arithmetic.
      if callee.desc is Path(ns, name) {
        if self.path_intrinsic(out, ns, name, args, loc) {
          return
        }
      }
      // The ATOMIC accesses: `m.atomic_load32(p)`, `m.atomic_rmw_add32(p, v)`.
      // The method name carries the width -- which is also the natural
      // alignment, and an atomic's alignment is not merely a hint -- but not
      // the operand type, which comes from the VALUE the access is given.
      if callee.desc is StructGet(recv, meth) && recv.desc is Get(memname) {
        if self.indices.memories.get(memname.name) is Some(mem) {
          if @atomics.of_method_name(meth.name) is Some(family) {
            let (align, offset) = self.memarg_natural(
              log2_exact(@atomics.family_bytes(family).to_int64(), loc),
              args,
              loc,
            )
            let operands = args.filter(a => !(a.desc is Labelled(_, _)))
            let op = atomic_op(family, operands)
            for a in operands {
              self.instr(out, a)
            }
            out.push(Atomic(mem, @atomics.opcode(op), align, offset))
            return
          }
        }
      }
      // The SIMD memory accesses: `m.loadv128(p)`, `m.load8_lane(p, v, lane:
      // 3)`. Their widths -- and so their natural alignments -- come from the
      // registry rather than from the name, and a lane access takes a
      // mandatory `lane:` immediate alongside the memarg.
      if callee.desc is StructGet(recv, meth) && recv.desc is Get(memname) {
        if self.indices.memories.get(memname.name) is Some(mem) {
          if @simd.mem_method(meth.name) is Some(op) {
            let (align, offset) = self.memarg_natural(
              log2_exact(op.nat_align.to_int64(), loc),
              args,
              loc,
            )
            let lane = if op.lane { labelled_lane(args, loc) } else { 0 }
            for a in args {
              if !(a.desc is Labelled(_, _)) {
                self.instr(out, a)
              }
            }
            out.push((op.build)(mem, align, offset, lane))
            return
          }
        }
      }
      // A SIMD vector operation, written as a method on the first operand:
      // `v.add_i32x4(w)`, `v.extract_lane_s_i8x16(lane)`. The lane shape is in
      // the NAME, so the registry knows the whole instruction; what varies is
      // how many leading arguments are lane immediates rather than operands.
      if callee.desc is StructGet(recv, meth) {
        if @simd.classify(meth.name) is Some(op) {
          let nimm = match op.imm {
            NoImm => 0
            Lane(_) => 1
            Shuffle => 16
          }
          let lanes = []
          for k in 0..<nimm {
            guard k < args.length() else {
              raise Unresolved("lane immediate", loc)
            }
            lanes.push(lane_immediate(args[k], loc))
          }
          self.instr(out, recv)
          for a in args[nimm:] {
            self.instr(out, a)
          }
          out.push((op.build)(lanes))
          return
        }
      }
      // The no-argument instruction methods: `x.clz()`, `arr.length()`. Their
      // opcode comes from the RECEIVER's type, which is the only thing that
      // distinguishes `i32.clz` from `i64.clz`.
      if callee.desc is StructGet(recv, meth) && args.is_empty() {
        if unary_instruction(meth.name, node_valtype(recv)) is Some(op) {
          self.instr(out, recv)
          out.push(op)
          return
        }
        // `array.len` takes NO immediate, so unlike its bulk-method siblings
        // it does not need a concrete element type: the abstract `array` heap
        // type and the bottom reference are receivers too.
        if meth.name == "length" && receiver_is_array(recv) {
          self.instr(out, recv)
          out.push(ArrayLen)
          return
        }
      }
      // A scalar binary intrinsic: `x.min(y)`, `x.rotl(n)`.
      if callee.desc is StructGet(recv, meth) && args.length() == 1 {
        if binary_intrinsic(meth.name, node_valtype(recv)) is Some(op) {
          self.instr(out, recv)
          self.instr(out, args[0])
          out.push(op)
          return
        }
      }
      // The stack-switching METHODS: `c.resume(x)` and its siblings, which are
      // the same instructions as the raw forms written on the continuation.
      // The type comes from the RECEIVER, because that is where the
      // continuation is.
      if callee.desc is StructGet(recv, meth) {
        if cont_method_instruction(meth.name) is Some(_) {
          if node_type_index(recv) is Some(ct) {
            // Emission order is the payload arguments, then the continuation
            // receiver on top -- which is the operand order the instruction
            // takes, and the reverse of how it is written.
            for a in args {
              if !(a.desc is Labelled(_, _)) {
                self.instr(out, a)
              }
            }
            self.instr(out, recv)
            out.push(
              self.cont_method(meth, args, ct, self.pending_handlers, loc),
            )
            return
          }
        }
      }
      // The ARRAY bulk methods wear the same three names as the memory and
      // table ones. What tells them apart is that the receiver is a VALUE of
      // array type rather than the name of a space, so the type index it
      // carries is the immediate.
      if callee.desc is StructGet(recv, meth) {
        if node_type_index(recv) is Some(at) {
          match meth.name {
            "fill" if args.length() == 3 => {
              self.instr(out, recv)
              for a in args {
                self.instr(out, a)
              }
              out.push(ArrayFill(at))
              return
            }
            // `dst.copy(i, src, j, n)` names TWO array types: the destination
            // is the receiver and the source is the second argument, and both
            // are immediates. The source array is still emitted as an operand.
            "copy" if args.length() == 4 => {
              guard node_type_index(args[1]) is Some(st) else {
                raise Unresolved("source array type", loc)
              }
              self.instr(out, recv)
              for a in args {
                self.instr(out, a)
              }
              out.push(ArrayCopy(at, st))
              return
            }
            // `arr.init(seg, dst, src, n)`: the segment name is an immediate,
            // and which of the two instructions this is depends on whether the
            // name is an element segment or a data one.
            "init" if args.length() == 4 && args[0].desc is Get(seg) => {
              self.instr(out, recv)
              for a in args[1:] {
                self.instr(out, a)
              }
              if self.indices.elems.get(seg.name) is Some(e) {
                out.push(ArrayInitElem(at, e))
              } else if self.indices.datas.get(seg.name) is Some(d) {
                out.push(ArrayInitData(at, d))
              } else {
                raise Unresolved("array init segment", loc)
              }
              return
            }
            _ => ()
          }
        }
      }
      // Memory and table management: the same five names on both, told apart
      // by which space the receiver is in -- `size` on a memory counts pages
      // and on a table counts elements.
      if callee.desc is StructGet(recv, meth) && recv.desc is Get(rname) {
        if self.mgmt_call(out, rname, meth, args, loc) {
          return
        }
      }
      for a in args {
        self.instr(out, a)
      }
      match callee.desc {
        // A DIRECT call: the callee names a function, and the index is enough.
        Get(name) if self.indices.funcs.get(name.name) is Some(_) &&
          !self.locals.contains(name.name) => {
          guard self.indices.funcs.get(name.name) is Some(f) else {
            raise Unresolved("call target", loc)
          }
          out.push(Call(f))
        }
        // Anything else that produced a function REFERENCE is called through
        // it. The type index comes from the reference's own type, which is
        // what makes `call_ref` typed at all.
        _ =>
          if node_type_index(callee) is Some(t) {
            self.instr(out, callee)
            out.push(CallRef(t))
          } else {
            // Named precisely, because these are different jobs wearing one
            // syntax and the burn-down needs to tell them apart.
            raise NotLowered(
              match callee.desc {
                StructGet(_, meth) => "method '" + meth.name + "'"
                Path(ns, meth) =>
                  "intrinsic '" + ns.name + "::" + meth.name + "'"
                _ => "indirect call"
              },
              loc,
            )
          }
      }
    }
    BrOnNull(label, operand) => {
      self.instr(out, operand)
      out.push(BrOnNull(self.depth(label, loc)))
    }
    BrOnNonNull(label, operand) => {
      self.instr(out, operand)
      out.push(BrOnNonNull(self.depth(label, loc)))
    }
    NonNull(e) => {
      self.instr(out, e)
      out.push(RefAsNonNull)
    }
    Test(e, target) => {
      self.instr(out, e)
      out.push(RefTest(self.reftype_index(target, loc)))
    }
    BrOnCast(label, target, operand) => {
      self.instr(out, operand)
      // Both types are immediates: the SOURCE the value is known to have, and
      // the TARGET being tested for. The source comes from the operand's own
      // annotation, since the syntax writes only the target.
      let to = self.reftype_index(target, loc)
      out.push(
        BrOnCast(self.depth(label, loc), br_on_cast_source(operand, to), to),
      )
    }
    BrOnCastFail(label, target, operand) => {
      self.instr(out, operand)
      let to = self.reftype_index(target, loc)
      out.push(
        BrOnCastFail(self.depth(label, loc), br_on_cast_source(operand, to), to),
      )
    }
    TryTable(label~, typ~, catches~, block~) => {
      let handlers : Array[@wasm_bin.CatchHandler] = []
      for c in catches {
        handlers.push(self.catch_handler(c, loc))
      }
      let bt = self.block_type(typ, loc)
      out.push(TryTable(bt, handlers, self.body(label, block.desc)))
    }
    // The DEPRECATED legacy handler. Unlike `try_table`, whose handlers are
    // immediates naming labels to branch to, these handlers are inline bodies
    // that run in place -- so each is lowered inside the try's own label frame,
    // which is the one frame the whole construct occupies.
    Try(label~, typ~, block~, catches~, catch_all~) => {
      let bt = self.block_type(typ, loc)
      let body = self.body(label, block.desc)
      let handlers : Array[(Int, Array[@wasm_bin.Instruction])] = []
      for c in catches {
        guard self.indices.tags.get(c.0.name) is Some(t) else {
          raise Unresolved("tag", loc)
        }
        handlers.push((t, self.body(label, c.1.desc)))
      }
      let all = match catch_all {
        Some(b) => Some(self.body(label, b.desc))
        None => None
      }
      out.push(LegacyTry(bt, body, handlers, all))
    }
    // The structured form, which the checker validated against a lowering to
    // `try_table` plus a block ladder -- so it is emitted from that same
    // lowering. `join` is the try's OWN label when it has one, because a `br`
    // to the try has to leave the join block carrying the value; only when
    // there is no such label does the lowering invent one.
    TryCatch(label~, typ~, block~, arms~) => {
      let arm_labels : Array[@ast.Ident] = []
      for k in 0..<arms.length() {
        arm_labels.push({
          name: "<catch:" +
          loc.start.cnum.to_string() +
          ":" +
          k.to_string() +
          ">",
          loc,
        })
      }
      let join = match label {
        Some(l) => l
        None => { name: "<join:" + loc.start.cnum.to_string() + ">", loc }
      }
      self.instr(
        out,
        @ast.lower_trycatch(i.info, join~, arm_labels~, typ~, block~, arms~),
      )
    }
    BrTable(labels, operand) => {
      self.instr(out, operand)
      // The written list is the cases and the DEFAULT last, which is how the
      // syntax reads and how the format stores it.
      guard labels.length() >= 1 else {
        raise Unresolved("br_table targets", loc)
      }
      let targets : Array[Int] = []
      for k in 0..<(labels.length() - 1) {
        targets.push(self.depth(labels[k], loc))
      }
      out.push(BrTable(targets, self.depth(labels[labels.length() - 1], loc)))
    }
    ContNew(ct, f) => {
      self.instr(out, f)
      out.push(ContNew(self.type_index_of(ct, loc)))
    }
    ContBind(src, dst, args) => {
      for a in args {
        self.instr(out, a)
      }
      out.push(
        ContBind(self.type_index_of(src, loc), self.type_index_of(dst, loc)),
      )
    }
    Suspend(tag, args) => {
      for a in args {
        self.instr(out, a)
      }
      out.push(Suspend(self.tag_of(tag, loc)))
    }
    Resume(ct, handlers, args) => {
      for a in args {
        self.instr(out, a)
      }
      out.push(
        Resume(self.type_index_of(ct, loc), self.on_clauses(handlers, loc)),
      )
    }
    ResumeThrow(ct, tag, handlers, args) => {
      for a in args {
        self.instr(out, a)
      }
      out.push(
        ResumeThrow(
          self.type_index_of(ct, loc),
          self.tag_of(tag, loc),
          self.on_clauses(handlers, loc),
        ),
      )
    }
    ResumeThrowRef(ct, handlers, args) => {
      for a in args {
        self.instr(out, a)
      }
      out.push(
        ResumeThrowRef(
          self.type_index_of(ct, loc),
          self.on_clauses(handlers, loc),
        ),
      )
    }
    Switch(ct, tag, args) => {
      for a in args {
        self.instr(out, a)
      }
      out.push(Switch(self.type_index_of(ct, loc), self.tag_of(tag, loc)))
    }
    // An `on` clause is the surface spelling that writes a resume's handlers
    // OUTSIDE the call. They belong to the resume, so they are handed down to
    // it rather than emitted here -- there is no instruction for the clause
    // itself.
    On(inner, handlers) => {
      let saved = self.pending_handlers
      self.pending_handlers = handlers
      self.instr(out, inner)
      self.pending_handlers = saved
    }
    Throw(tag, args) => {
      for a in args {
        self.instr(out, a)
      }
      guard self.indices.tags.get(tag.name) is Some(t) else {
        raise Unresolved("tag", loc)
      }
      out.push(Throw(t))
    }
    ThrowRef(e) => {
      self.instr(out, e)
      out.push(ThrowRef)
    }
    // The three constructs the CHECKER validated against a lowering are emitted
    // from that same lowering: there is no second shape to keep in step, and
    // the code that runs is the code that was checked. The synthetic labels the
    // lowering invents are spelled `<..>`, so they never reach the name section.
    While(label~, cond~, step~, block~) => {
      let fresh : @ast.Ident = {
        name: "<while:" + loc.start.cnum.to_string() + ">",
        loc,
      }
      for
        x in @ast.lower_while(
          i.info,
          fresh_loop=fresh,
          label~,
          cond~,
          step~,
          block=block.desc,
        ) {
        self.instr(out, x)
      }
    }
    Dispatch(index~, cases~, default~, arms~) =>
      for x in @ast.lower_dispatch(i.info, index~, cases~, default~, arms~) {
        self.instr(out, x)
      }
    Match(scrutinee~, arms~, default~) => {
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
      for x in @ast.lower_match(i.info, labels~, scrutinee~, arms~, default~) {
        self.instr(out, x)
      }
    }
    Cast(operand, target) => {
      // A narrow load and a following sign cast are ONE instruction: wax splits
      // the width and the signedness across two constructs, and the binary has
      // no separate sign-extension to emit afterwards.
      if target is Signed(typ~, signage~, ..) &&
        self.fused_load(out, operand, typ, signage, loc) {
        return
      }
      // A PACKED field or element reads the same way: the width is written on
      // the declaration and the sign on the cast, and the binary has one
      // instruction for the pair.
      if target is Signed(signage~, ..) &&
        self.fused_packed_read(out, operand, signage, loc) {
        return
      }
      // `(x as i32) as i64_s` where `x` is an i64 is ONE instruction. There is
      // no wax spelling for `i64.extend32_s`, so the decompiler renders it as
      // the wrap-then-widen pair; re-fuse it. Only a SIGNED widening of a
      // genuinely wrapped i64 is that instruction -- an unsigned widen, or an
      // i32 source where the inner cast is the identity, is something else.
      if target is Signed(typ=I64, signage=Signed, ..) &&
        operand.desc is Cast(inner, Value(I32)) &&
        node_valtype(inner) is Some(I64) {
        self.instr(out, inner)
        out.push(I64Extend32S)
        return
      }
      self.instr(out, operand)
      // In UNREACHABLE code the operand has no type, and so the cast has no
      // instruction: there is nothing on the stack to convert. Validation
      // accepts whatever follows, which is exactly why nothing has to be
      // invented here.
      guard node_valtype(operand) is Some(operand_type) else { return }
      let from = cast_prologue(out, operand_type, target)
      self.cast_instruction(out, from, target, i, loc)
    }
    Null =>
      match node_valtype(i) {
        Some(Ref(r)) => out.push(RefNull(r.typ))
        // A bare `null` with no type is the bottom reference; the checker gives
        // it one whenever the context pins one, so reaching here means it did
        // not.
        _ => raise Unresolved("null type", loc)
      }
    Select(cond, a, b) => {
      self.instr(out, a)
      self.instr(out, b)
      self.instr(out, cond)
      // A `select` over a REFERENCE needs its type written out: the untyped
      // form only works where the value type is unambiguous, which a reference
      // never is.
      match node_valtype(i) {
        Some(Ref(_) as ty) => out.push(SelectTyped([ty]))
        Some(_) => out.push(Select)
        None => raise Unresolved("select type", loc)
      }
    }
    Str(_, bytes) => {
      // A string literal is an ARRAY of its bytes, built one constant at a
      // time. There is no shortcut through a data segment: `array.new_data`
      // takes a segment the source named, and a literal names none.
      let (t, f) = self.array_element_of(i, loc)
      // An `i16` array holds code UNITS, so the bytes are decoded first; an
      // `i8` array holds the bytes as they stand.
      let units = if f.typ is Packed(I16) {
        utf16_units(bytes, loc)
      } else {
        let out : Array[Int] = []
        for k in 0..<bytes.length() {
          out.push(bytes[k].to_int())
        }
        out
      }
      for u in units {
        out.push(I32Const(u))
      }
      out.push(ArrayNewFixed(t, units.length()))
    }
    ArraySegment(_, seg, off, len) => {
      self.instr(out, off)
      self.instr(out, len)
      let (t, _) = self.array_element_of(i, loc)
      // An ELEMENT segment means `array.new_elem`; anything else is a data
      // segment. The two spaces are separate, so the name decides.
      match self.indices.elems.get(seg.name) {
        Some(e) => out.push(ArrayNewElem(t, e))
        None =>
          match self.indices.datas.get(seg.name) {
            Some(d) => out.push(ArrayNewData(t, d))
            None => raise Unresolved("array segment", loc)
          }
      }
    }
    Struct(_, fields) => {
      let (t, declared) = self.struct_fields_of(i, loc)
      guard fields.length() == declared.length() else {
        raise Unresolved("struct field count", loc)
      }
      // The checker rebuilt the fields in DECLARED order, which is the order
      // `struct.new` takes them in -- so they are emitted as they stand.
      //
      // A field written with no value is the shorthand `{ x }`, which means
      // the name in scope. It reads that name here rather than being an
      // omission: `struct.new` takes every field, and there is no hole in it.
      for f in fields {
        match f.1 {
          Some(v) => self.instr(out, v)
          None => out.push(self.read(f.0, loc))
        }
      }
      out.push(StructNew(t))
    }
    StructDefault(_) => {
      let (t, _) = self.struct_fields_of(i, loc)
      out.push(StructNewDefault(t))
    }
    StructGet(recv, field) => {
      self.instr(out, recv)
      let (t, declared) = self.struct_fields_of(recv, loc)
      guard self.field_index(t, declared, field.name) is Some((k, f)) else {
        raise Unresolved("struct field", loc)
      }
      // A packed field read is unsigned unless a sign cast follows and fuses;
      // this is the bare form, so it is the unsigned one.
      out.push(if is_packed(f) { StructGetU(t, k) } else { StructGet(t, k) })
    }
    StructSet(recv, field, value) => {
      self.instr(out, recv)
      self.instr(out, value)
      let (t, declared) = self.struct_fields_of(recv, loc)
      guard self.field_index(t, declared, field.name) is Some((k, _)) else {
        raise Unresolved("struct field", loc)
      }
      out.push(StructSet(t, k))
    }
    Array(_, init, size) => {
      self.instr(out, init)
      self.instr(out, size)
      let (t, _) = self.array_element_of(i, loc)
      out.push(ArrayNew(t))
    }
    ArrayDefault(_, size) => {
      self.instr(out, size)
      let (t, _) = self.array_element_of(i, loc)
      out.push(ArrayNewDefault(t))
    }
    ArrayFixed(_, elems) => {
      for e in elems {
        self.instr(out, e)
      }
      let (t, _) = self.array_element_of(i, loc)
      out.push(ArrayNewFixed(t, elems.length()))
    }
    ArrayGet(recv, index) if self.table_of(recv) is Some(_) => {
      guard self.table_of(recv) is Some(t) else { return }
      self.instr(out, index)
      out.push(TableGet(t))
    }
    ArraySet(recv, index, value) if self.table_of(recv) is Some(_) => {
      guard self.table_of(recv) is Some(t) else { return }
      self.instr(out, index)
      self.instr(out, value)
      out.push(TableSet(t))
    }
    ArrayGet(recv, index) => {
      self.instr(out, recv)
      self.instr(out, index)
      let (t, f) = self.array_element_of(recv, loc)
      out.push(if is_packed(f) { ArrayGetU(t) } else { ArrayGet(t) })
    }
    ArraySet(recv, index, value) => {
      self.instr(out, recv)
      self.instr(out, index)
      self.instr(out, value)
      let (t, _) = self.array_element_of(recv, loc)
      out.push(ArraySet(t))
    }
    _ => raise NotLowered(construct_name(i.desc), loc)
  }
}

///|
/// Lower a block body under a new label scope.
fn Lowering::body(
  self : Lowering,
  label : @ast.Ident?,
  instrs : Array[@ast.Instr[@typing_env.InferredAnnotation]],
) -> Array[@wasm_bin.Instruction] raise LowerError {
  self.open_label(label)
  let out : Array[@wasm_bin.Instruction] = []
  for s in instrs {
    self.instr(out, s)
  }
  let _ = self.labels.pop()
  out
}

///|
/// Enter a block, recording its label's name.
///
/// Labels are numbered for the name section in the order the blocks OPEN, which
/// is not the order a `br` counts them in -- depth is relative to where the
/// branch stands, while a name belongs to the block itself.
fn Lowering::open_label(self : Lowering, label : @ast.Ident?) -> Unit {
  self.labels.push(label.map(l => l.name))
  if label is Some(l) {
    note_name(self.label_names, self.label_counter, l.name)
  }
  self.label_counter = self.label_counter + 1
}

///|
/// A block's signature, as the format spells it.
fn Lowering::block_type(
  self : Lowering,
  typ : @ast.FuncType,
  loc : @basic.Location,
) -> @wasm_bin.BlockType raise LowerError {
  if typ.params.is_empty() {
    match typ.results {
      [] => Empty
      [r] =>
        match r {
          I32 => Value(I32)
          I64 => Value(I64)
          F32 => Value(F32)
          F64 => Value(F64)
          V128 => Value(V128)
          // A block type IS a value type, and a reference is one -- its type
          // names just have to become indices first.
          Ref(rt) => Value(Ref(self.reftype_index(rt, loc)))
        }
      // Anything else needs a type INDEX: the inline forms only reach one
      // result and no parameters.
      _ => TypeIndex(self.block_functype_index(typ, loc))
    }
  } else {
    TypeIndex(self.block_functype_index(typ, loc))
  }
}

///|
/// Read a name: a local, a global, or a function reference.
///
/// The order is the language's -- a local shadows everything -- and it is the
/// same order the checker resolved it in, which is what makes the two agree.
fn Lowering::read(
  self : Lowering,
  name : @ast.Ident,
  loc : @basic.Location,
) -> @wasm_bin.Instruction raise LowerError {
  match self.locals.get(name.name) {
    Some(k) => LocalGet(k)
    None =>
      match self.indices.globals.get(name.name) {
        Some(g) => GlobalGet(g)
        None =>
          match self.indices.funcs.get(name.name) {
            Some(f) => RefFunc(f)
            None => raise Unresolved("name", loc)
          }
      }
  }
}

///|
/// Write a name: a local or a global.
fn Lowering::write(
  self : Lowering,
  name : @ast.Ident,
  loc : @basic.Location,
) -> @wasm_bin.Instruction raise LowerError {
  match self.locals.get(name.name) {
    Some(k) => LocalSet(k)
    None =>
      match self.indices.globals.get(name.name) {
        Some(g) => GlobalSet(g)
        None => raise Unresolved("assignment target", loc)
      }
  }
}

///|
/// Emit a narrow load fused with the sign cast that follows it.
///
/// `true` when it applied. The pair is one instruction, so recognising it here
/// is not an optimisation -- emitting the load and then the cast separately
/// would emit a zero-extending load and no sign extension at all.
fn Lowering::fused_load(
  self : Lowering,
  out : Array[@wasm_bin.Instruction],
  operand : @ast.Instr[@typing_env.InferredAnnotation],
  typ : @ast.NumType,
  signage : @wasm_types.Signage,
  loc : @basic.Location,
) -> Bool raise LowerError {
  guard operand.desc is Call(callee, args) else { return false }
  guard callee.desc is StructGet(recv, meth) else { return false }
  guard recv.desc is Get(memname) else { return false }
  guard self.indices.memories.get(memname.name) is Some(mem) else {
    return false
  }
  let (align, offset) = self.memarg(meth, args, loc)
  guard load_instruction(meth.name, mem, align, offset, Some((typ, signage)))
    is Some(ld) else {
    return false
  }
  for a in args {
    if !(a.desc is Labelled(_, _)) {
      self.instr(out, a)
    }
  }
  out.push(ld)
  true
}

///|
/// A field's position in a struct's declared fields, with the field itself.
///
/// The position comes from the SOURCE declaration, because the store erases
/// field names -- wasm has none -- and the two lists are the same fields in the
/// same order.
fn Lowering::field_index(
  self : Lowering,
  t : Int,
  declared : Array[@wasm_types.MutType[@wasm_types.StorageType[@type_store.Id]]],
  name : String,
) -> (Int, @wasm_types.MutType[@wasm_types.StorageType[@type_store.Id]])? {
  guard self.source_types.get(t) is Some(sub) else { return None }
  guard sub.typ is Struct(fields) else { return None }
  for k, f in fields {
    if f.desc.0.name == name && k < declared.length() {
      return Some((k, declared[k]))
    }
  }
  None
}

///|
/// The table a receiver names, if it names one.
///
/// `tab[i]` and `arr[i]` are one syntax; the receiver decides, exactly as it
/// does for the management methods.
fn Lowering::table_of(
  self : Lowering,
  recv : @ast.Instr[@typing_env.InferredAnnotation],
) -> Int? {
  guard recv.desc is Get(name) else { return None }
  // A LOCAL of the same name shadows the table, which is the order the checker
  // resolved it in too.
  guard !self.locals.contains(name.name) else { return None }
  self.indices.tables.get(name.name)
}

///|
/// Lower a qualified-path intrinsic, returning whether it applied.
///
/// These are the operations with no receiver to hang a method off. A `v128::`
/// constant is the odd one: its arguments are not operands at all but the lane
/// LITERALS of a single 16-byte immediate, so nothing is emitted for them.
fn Lowering::path_intrinsic(
  self : Lowering,
  out : Array[@wasm_bin.Instruction],
  ns : @ast.Ident,
  name : @ast.Ident,
  args : Array[@ast.Instr[@typing_env.InferredAnnotation]],
  loc : @basic.Location,
) -> Bool raise LowerError {
  match (ns.name, name.name) {
    ("v128", part) => {
      let full = @simd.free_full(part)
      if @simd.const_shape_of_name(full) is Some(shape) {
        out.push(V128Const(self.vector_constant(shape, args, loc)))
        return true
      }
      guard @simd.classify(full) is Some(op) else { return false }
      for a in args {
        self.instr(out, a)
      }
      out.push((op.build)([]))
      true
    }
    ("atomic", "fence") => {
      out.push(AtomicFence)
      true
    }
    // The wide arithmetic: two 64-bit halves in, two out. The operands are
    // already on the stack in call order, so there is nothing to reorder.
    ("i64", wide) => {
      let instruction : @wasm_bin.Instruction = match wide {
        "add128" => I64Add128
        "sub128" => I64Sub128
        "mul_wide_s" => I64MulWideS
        "mul_wide_u" => I64MulWideU
        _ => return false
      }
      for a in args {
        self.instr(out, a)
      }
      out.push(instruction)
      true
    }
    _ => false
  }
}

///|
/// The 16 bytes of a `v128::<shape>(..)` constant.
///
/// Each argument is one lane's literal, written in the lane's own type and
/// stored little-endian at its own width -- which is what makes the shape part
/// of the constant rather than of the instruction: the bytes are all the
/// binary keeps.
fn Lowering::vector_constant(
  self : Lowering,
  shape : @simd.Shape,
  args : Array[@ast.Instr[@typing_env.InferredAnnotation]],
  loc : @basic.Location,
) -> Bytes raise LowerError {
  ignore(self)
  let lanes = @simd.const_arity(shape)
  guard args.length() == lanes else { raise Unresolved("vector lanes", loc) }
  let width = 16 / lanes
  let out : Array[Byte] = Array::make(16, b'\x00')
  for k in 0..<lanes {
    let text = literal_text(args[k], loc)
    let bits = match shape {
      F32x4 =>
        Float::from_double(parse_float_bits(text, false, loc))
        .reinterpret_as_int()
        .to_int64() &
        0xFFFFFFFFL
      F64x2 => parse_float_bits(text, true, loc).reinterpret_as_int64()
      _ => parse_i64(text, loc)
    }
    for b in 0..<width {
      out[k * width + b] = ((bits.reinterpret_as_uint64() >> (b * 8)).to_int() &
      0xFF).to_byte()
    }
  }
  Bytes::from_array(out)
}

///|
/// The literal text of a lane argument. A negative lane arrives as a negation
/// applied to its magnitude, and the parsers below want the sign back.
fn literal_text(
  a : @ast.Instr[@typing_env.InferredAnnotation],
  loc : @basic.Location,
) -> String raise LowerError {
  match a.desc {
    Int(s) | Float(s) => s
    UnOpI(op, b) if op.desc is Neg => "-" + literal_text(b, loc)
    _ => raise Unresolved("lane literal", loc)
  }
}

///|
/// The atomic operation a family becomes, once the operand type is known.
///
/// The family says the WIDTH; what it cannot say is whether the access is an
/// i32 or an i64 one, because the same `atomic_store32` serves both -- storing
/// the low half of an i64 is a different opcode from storing an i32. The
/// answer is the type of the VALUE operand, and in unreachable code, where
/// there is no type to read, the i32 form is the default.
fn atomic_op(
  family : @atomics.Family,
  operands : Array[@ast.Instr[@typing_env.InferredAnnotation]],
) -> @atomics.Op {
  fn value_type() {
    if operands.length() >= 2 && node_valtype(operands[1]) is Some(I64) {
      @atomics.NumTy::I64
    } else {
      @atomics.NumTy::I32
    }
  }

  fn narrow(w : @atomics.Width, t : @atomics.NumTy) {
    match w {
      W8 => (t, Some(@atomics.Narrow::N8))
      W16 => (t, Some(@atomics.Narrow::N16))
      W32 =>
        match t {
          I64 => (@atomics.NumTy::I64, Some(@atomics.Narrow::N32))
          I32 => (@atomics.NumTy::I32, None)
        }
      W64 => (@atomics.NumTy::I64, None)
    }
  }

  match family {
    Notify => Notify
    Wait(t) => Wait(t)
    Load(W32) => Load(I32, None)
    Load(W64) => Load(I64, None)
    Load(W8) => Load(I32, Some(N8))
    Load(W16) => Load(I32, Some(N16))
    Store(w) => {
      let (t, n) = narrow(w, value_type())
      Store(t, n)
    }
    Rmw(op, w) => {
      let (t, n) = narrow(w, value_type())
      Rmw(op, t, n)
    }
  }
}

///|
/// The SOURCE type a branching cast emits, given the target it tests for.
///
/// Wax writes only the target; the binary wants both, and the typer recovers
/// the source from the operand. When the operand has no usable heap type of its
/// own -- a hole in dead code, or a literal `ref.null none` -- the TARGET
/// stands in, which is always a valid source against itself. Its nullability
/// still has to carry over, though: a nullable operand is not a subtype of a
/// non-null target, and the check the instruction carries would reject it.
fn br_on_cast_source(
  operand : @ast.Instr[@typing_env.InferredAnnotation],
  target : @wasm_types.RefType[Int],
) -> @wasm_types.RefType[Int] {
  match node_last_reftype(operand) {
    Some(r) => r
    None =>
      { ..target, nullable: target.nullable || node_last_nullable(operand) }
  }
}

///|
/// The integer literal a lane immediate is written as. Typing has already
/// rejected anything else, so a non-literal here is a lowering bug.
fn lane_immediate(
  a : @ast.Instr[@typing_env.InferredAnnotation],
  loc : @basic.Location,
) -> Int raise LowerError {
  let value = if a.desc is Labelled(_, v) { v } else { a }
  guard value.desc is Int(s) else { raise Unresolved("lane immediate", loc) }
  parse_i64(s, loc).to_int()
}

///|
/// The mandatory `lane:` immediate of a vector lane access.
fn labelled_lane(
  args : Array[@ast.Instr[@typing_env.InferredAnnotation]],
  loc : @basic.Location,
) -> Int raise LowerError {
  for a in args {
    if a.desc is Labelled(label, _) && label.name == "lane" {
      return lane_immediate(a, loc)
    }
  }
  raise Unresolved("lane immediate", loc)
}

///|
/// Whether a receiver is something `array.len` accepts: a concrete array type,
/// the abstract `array` heap type, or the bottom reference that is below it.
/// The bulk methods need a real element type and are checked separately.
fn receiver_is_array(recv : @ast.Instr[@typing_env.InferredAnnotation]) -> Bool {
  if node_type_index(recv) is Some(_) {
    return true
  }
  node_valtype(recv) is Some(Ref({ typ: Array | None_, .. }))
}

///|
/// Lower a management call, returning whether it applied.
///
/// The five names -- `size`, `grow`, `fill`, `copy`, `init` -- serve memories
/// and tables alike, so the receiver's SPACE picks the instruction. `init` and
/// `copy` name a second thing (a segment, or the other memory or table), and
/// that name is an immediate rather than a value: it is not emitted, it is
/// encoded.
fn Lowering::mgmt_call(
  self : Lowering,
  out : Array[@wasm_bin.Instruction],
  recv : @ast.Ident,
  meth : @ast.Ident,
  args : Array[@ast.Instr[@typing_env.InferredAnnotation]],
  loc : @basic.Location,
) -> Bool raise LowerError {
  guard !self.locals.contains(recv.name) else { return false }
  let on_memory = self.indices.memories.get(recv.name)
  let on_table = self.indices.tables.get(recv.name)
  guard on_memory is Some(_) || on_table is Some(_) else { return false }
  // The leading segment or source name of `init`/`copy` is an immediate.
  let (immediate, values) = match meth.name {
    "init" =>
      if args.length() >= 1 && args[0].desc is Get(n) {
        (Some(n), args[1:].to_owned())
      } else {
        (None, args)
      }
    "copy" =>
      if args.length() == 4 && args[1].desc is Get(n) {
        // `dst.copy(i, src, j, n)`: the source is the second argument.
        (Some(n), [args[0], args[2], args[3]])
      } else {
        (None, args)
      }
    _ => (None, args)
  }
  for a in values {
    self.instr(out, a)
  }
  match (meth.name, on_memory, on_table) {
    ("size", Some(m), _) => out.push(MemorySize(m))
    ("grow", Some(m), _) => out.push(MemoryGrow(m))
    ("fill", Some(m), _) => out.push(MemoryFill(m))
    ("copy", Some(m), _) => {
      let src = match immediate {
        Some(n) =>
          match self.indices.memories.get(n.name) {
            Some(k) => k
            None => raise Unresolved("source memory", loc)
          }
        None => m
      }
      out.push(MemoryCopy(m, src))
    }
    ("init", Some(m), _) => {
      guard immediate is Some(n) else {
        raise Unresolved("data segment name", loc)
      }
      guard self.indices.datas.get(n.name) is Some(d) else {
        raise Unresolved("data segment", loc)
      }
      out.push(MemoryInit(d, m))
    }
    ("size", _, Some(t)) => out.push(TableSize(t))
    ("grow", _, Some(t)) => out.push(TableGrow(t))
    ("fill", _, Some(t)) => out.push(TableFill(t))
    ("copy", _, Some(t)) => {
      let src = match immediate {
        Some(n) =>
          match self.indices.tables.get(n.name) {
            Some(k) => k
            None => raise Unresolved("source table", loc)
          }
        None => t
      }
      out.push(TableCopy(t, src))
    }
    ("init", _, Some(t)) => {
      guard immediate is Some(n) else {
        raise Unresolved("element segment name", loc)
      }
      guard self.indices.elems.get(n.name) is Some(e) else {
        raise Unresolved("element segment", loc)
      }
      out.push(TableInit(e, t))
    }
    _ => return false
  }
  true
}

///|
/// The type index a block signature needs when no inline form fits.
///
/// A block with parameters, or with several results, cannot be written inline:
/// the format spells those as a reference into the type section. The signature
/// has to be there already -- the checker interned every block type it saw --
/// so this is a lookup, and its failure means the two disagree about what was
/// declared rather than that something is missing.
fn Lowering::block_functype_index(
  self : Lowering,
  typ : @ast.FuncType,
  loc : @basic.Location,
) -> Int raise LowerError {
  let params : Array[@wasm_types.ValType[Int]] = []
  for p in typ.params {
    params.push(self.valtype_index(p.desc.1, loc))
  }
  let results : Array[@wasm_types.ValType[Int]] = []
  for r in typ.results {
    results.push(self.valtype_index(r, loc))
  }
  guard self.functypes.get((params, results)) is Some(i) else {
    raise Unresolved("block type", loc)
  }
  i
}

///|
/// The branch depth a label names.
fn Lowering::depth(
  self : Lowering,
  label : @ast.Ident,
  loc : @basic.Location,
) -> Int raise LowerError {
  match self.depth_of(label.name) {
    Some(d) => d
    None => raise Unresolved("branch target", loc)
  }
}

///|
/// One `try_table` catch clause.
///
/// The handler branches OUT of the try, so its label is resolved in the
/// enclosing scope -- which is where it is written, and where the checker
/// resolved it too.
fn Lowering::catch_handler(
  self : Lowering,
  c : @ast.Catch,
  loc : @basic.Location,
) -> @wasm_bin.CatchHandler raise LowerError {
  fn tag_of(t : @ast.Ident) -> Int raise LowerError {
    match self.indices.tags.get(t.name) {
      Some(i) => i
      None => raise Unresolved("catch tag", loc)
    }
  }

  match c {
    Catch(tag, label) => Catch(tag_of(tag), self.depth(label, loc))
    CatchRef(tag, label) => CatchRef(tag_of(tag), self.depth(label, loc))
    CatchAll(label) => CatchAll(self.depth(label, loc))
    CatchAllRef(label) => CatchAllRef(self.depth(label, loc))
  }
}

///|
/// A byte string as UTF-16 code units.
///
/// An `i16` array holds code units rather than bytes, so a literal destined for
/// one is decoded and re-encoded. An astral scalar becomes a surrogate PAIR,
/// which is why the count can differ from the character count.
fn utf16_units(b : Bytes, loc : @basic.Location) -> Array[Int] raise LowerError {
  guard @unicode.utf8_text(b) is Some(text) else {
    raise NotLowered("non-UTF-8 string in a code-unit array", loc)
  }
  let out : Array[Int] = []
  for k in 0..<text.length() {
    out.push(text[k].to_int())
  }
  out
}

///|
/// Emit a packed field or element read fused with the sign cast that follows.
///
/// `true` when it applied. A packed slot stores fewer bits than it reads back
/// as, so the read has to say how to fill the rest -- and wax writes that on the
/// CAST rather than the access, exactly as it does for a narrow memory load.
fn Lowering::fused_packed_read(
  self : Lowering,
  out : Array[@wasm_bin.Instruction],
  operand : @ast.Instr[@typing_env.InferredAnnotation],
  signage : @wasm_types.Signage,
  loc : @basic.Location,
) -> Bool raise LowerError {
  match operand.desc {
    ArrayGet(recv, index) => {
      guard self.table_of(recv) is None else { return false }
      let (t, f) = self.array_element_of(recv, loc)
      guard is_packed(f) else { return false }
      self.instr(out, recv)
      self.instr(out, index)
      out.push(if signage is Signed { ArrayGetS(t) } else { ArrayGetU(t) })
      true
    }
    StructGet(recv, field) => {
      let (t, declared) = self.struct_fields_of(recv, loc)
      guard self.field_index(t, declared, field.name) is Some((k, f)) else {
        return false
      }
      guard is_packed(f) else { return false }
      self.instr(out, recv)
      out.push(
        if signage is Signed {
          StructGetS(t, k)
        } else {
          StructGetU(t, k)
        },
      )
      true
    }
    _ => false
  }
}

///|
/// A named type's index.
fn Lowering::type_index_of(
  self : Lowering,
  name : @ast.Ident,
  loc : @basic.Location,
) -> Int raise LowerError {
  guard self.ctx.type_context.types.find_no_mark(name.name) is Some((idx, _)) else {
    raise Unresolved("type name", loc)
  }
  match idx {
    Def(id) => id.to_int_for_tests_only()
    Rec(_) => raise Unresolved("rec-group type reference", loc)
  }
}

///|
/// A tag's index.
fn Lowering::tag_of(
  self : Lowering,
  tag : @ast.Ident,
  loc : @basic.Location,
) -> Int raise LowerError {
  match self.indices.tags.get(tag.name) {
    Some(i) => i
    None => raise Unresolved("tag", loc)
  }
}

///|
/// A resume's handler clauses.
///
/// `on t -> 'l` sends a suspension to a label; `on t switch` lets the
/// suspending side switch directly instead. They are two ways of answering the
/// same question, so they share the clause list.
fn Lowering::on_clauses(
  self : Lowering,
  handlers : Array[@ast.OnClause],
  loc : @basic.Location,
) -> Array[@wasm_bin.OnClause] raise LowerError {
  let out : Array[@wasm_bin.OnClause] = []
  for h in handlers {
    match h {
      OnLabel(tag, label) =>
        out.push(OnLabel(self.tag_of(tag, loc), self.depth(label, loc)))
      OnSwitch(tag) => out.push(OnSwitch(self.tag_of(tag, loc)))
    }
  }
  out
}

///|
/// Whether a method name is one of the stack-switching operations.
fn cont_method_instruction(meth : String) -> Unit? {
  match meth {
    "resume" | "resume_throw" | "resume_throw_ref" | "switch" => Some(())
    _ => None
  }
}

///|
/// The instruction a stack-switching method becomes.
///
/// `switch` and `resume_throw` name a TAG, written as a labelled immediate and
/// as an invocation respectively -- neither is a value, so both are read out of
/// the arguments rather than emitted from them.
fn Lowering::cont_method(
  self : Lowering,
  meth : @ast.Ident,
  args : Array[@ast.Instr[@typing_env.InferredAnnotation]],
  ct : Int,
  handlers : Array[@ast.OnClause],
  loc : @basic.Location,
) -> @wasm_bin.Instruction raise LowerError {
  let on = self.on_clauses(handlers, loc)
  match meth.name {
    "resume" => Resume(ct, on)
    "resume_throw_ref" => ResumeThrowRef(ct, on)
    "resume_throw" => {
      guard args.length() >= 1 && args[0].desc is Call(callee, _) else {
        raise Unresolved("resume_throw tag", loc)
      }
      guard callee.desc is Get(t) else {
        raise Unresolved("resume_throw tag", loc)
      }
      ResumeThrow(ct, self.tag_of(t, loc), on)
    }
    _ => {
      let mut tag : @ast.Ident? = None
      for a in args {
        if a.desc is Labelled(l, v) && l.name == "tag" && v.desc is Get(t) {
          tag = Some(t)
        }
      }
      guard tag is Some(t) else { raise Unresolved("switch tag", loc) }
      Switch(ct, self.tag_of(t, loc))
    }
  }
}
