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
  let span_start = out.length()
  // The children lower through this same function, so each pushes its span
  // before this node pushes its own. Where the LAST of them ended is where
  // this node's own emission began -- which is the one thing a plain extent
  // cannot say, and the thing the text form needs.
  //
  // A node that emits nothing of its own -- a tuple, say, which is just its
  // elements -- has that boundary at the end. It is not a folded instruction,
  // and the printer must not make one of it by taking the last element as a
  // head that consumes the rest.
  let child_spans = self.spans.length()
  self.instr_span(out, i)
  if out.length() > span_start {
    let mut head_start = span_start
    for k in child_spans..<self.spans.length() {
      if self.spans[k].end > head_start {
        head_start = self.spans[k].end
      }
    }
    self.spans.push({
      start: span_start,
      head: head_start,
      end: out.length(),
      loc: i.info.1,
    })
  }
}

///|
/// Lower into an array of its own, keeping the spans it produced.
///
/// Some nodes have to see what they emitted before deciding what to emit --
/// a tail call replaces the call it ends with, a hinted instruction wraps it
/// -- and that needs a scratch array. The spans come back numbered from zero,
/// so the caller moves them to where the instructions land.
fn Lowering::detached(
  self : Lowering,
  build : (Array[@wasm_bin.Instruction]) -> Unit raise LowerError,
) -> (Array[@wasm_bin.Instruction], Array[@wasm_bin.Span]) raise LowerError {
  let outer = self.spans
  self.spans = []
  let scratch : Array[@wasm_bin.Instruction] = []
  build(scratch)
  let spans = self.spans
  self.spans = outer
  (scratch, spans)
}

///|
/// Record spans lowered elsewhere, at the offset their instructions landed at.
fn Lowering::rebase(
  self : Lowering,
  spans : Array[@wasm_bin.Span],
  base : Int,
) -> Unit {
  for sp in spans {
    self.spans.push({
      ..sp,
      start: sp.start + base,
      head: sp.head + base,
      end: sp.end + base,
    })
  }
}

///|
/// One character as the bytes that spell it.
fn utf8_of_char(c : Char) -> Bytes {
  Bytes::from_array(@unicode.utf8_bytes(c.to_string()).map(b => b.to_byte()))
}

///|
/// Read a name, recording the one-instruction span it takes.
fn Lowering::read_span(
  self : Lowering,
  out : Array[@wasm_bin.Instruction],
  name : @ast.Ident,
  loc : @basic.Location,
) -> Unit raise LowerError {
  let at = out.length()
  out.push(self.read(name, loc))
  self.spans.push({ start: at, head: at, end: at + 1, loc })
}

///|
/// Lower one instruction, without recording where it landed.
fn Lowering::instr_span(
  self : Lowering,
  out : Array[@wasm_bin.Instruction],
  i : @ast.Instr[@typing_env.InferredAnnotation],
) -> Unit raise LowerError {
  // A branch hint attaches to the instruction it annotates, and the format
  // records it by BYTE OFFSET in a custom section -- so it has to be carried
  // on the instruction until the encoder knows where that instruction landed.
  // The wrapper is how it rides along.
  guard i.hints.is_empty() else {
    // Lowered into an array of its own so the last instruction can be picked
    // out, which means its spans are numbered from zero and have to be moved
    // to where the instructions actually land. Left unmoved they point into
    // whatever else is in this body, and the printer folds by them.
    let base = out.length()
    let (inner, inner_spans) = self.detached(scratch => self.hinted(scratch, i))
    guard inner.length() >= 1 else { return }
    // The hint belongs to the LAST instruction emitted, which is the one the
    // node is: everything before it computed the operands.
    for k in 0..<(inner.length() - 1) {
      out.push(inner[k])
    }
    out.push(Hinted(self.lower_hints(i.hints), inner[inner.length() - 1]))
    self.rebase(inner_spans, base)
    return
  }
  self.hinted(out, i)
}

///|
/// The hints an instruction carries, in the form the encoder writes.
fn Lowering::lower_hints(
  self : Lowering,
  h : @ast.Hints,
) -> @wasm_bin.InstrHints {
  {
    branch: h.branch.map(x => x.value),
    freq: h.freq.map(x => x.value),
    // A call-target hint names FUNCTIONS, and the section stores indices, so
    // it is the one hint that needs the index space resolved. A name that does
    // not resolve drops that entry rather than the whole hint: the section is
    // advisory, and a partial list is still true.
    targets: h.targets.map(x => {
      let out : Array[(Int, Int)] = []
      for entry in x.value {
        if self.indices.funcs.get(entry.0.name) is Some(f) {
          out.push((f, entry.1))
        }
      }
      out
    }),
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
    // The literal's TEXT rides along with its value. `0x4` and `4` denote the
    // same i32 and are two different programs to read, and no reading of a
    // float's bits gives back `0x1.4p+3`.
    Int(s) =>
      match node_valtype(i) {
        Some(I32) => out.push(Spelled(s, I32Const(parse_i32(s, loc))))
        Some(I64) => out.push(Spelled(s, I64Const(parse_i64(s, loc))))
        Some(F32) => out.push(Spelled(s, F32Const(parse_f32(s, loc))))
        Some(F64) =>
          out.push(Spelled(s, F64Const(parse_float_bits(s, true, loc))))
        _ => raise Unresolved("integer literal type", loc)
      }
    Float(s) =>
      match node_valtype(i) {
        Some(F32) => out.push(Spelled(s, F32Const(parse_f32(s, loc))))
        Some(F64) =>
          out.push(Spelled(s, F64Const(parse_float_bits(s, true, loc))))
        _ => raise Unresolved("float literal type", loc)
      }
    // A character literal is an i32 code point, and remembers being written as
    // a character: 65 says nothing about having been `'A'`.
    Char(c) => out.push(FromChar(utf8_of_char(c), I32Const(c.to_int())))
    Get(name) => out.push(self.read(name, loc))
    Set(name, op, value) => {
      // `x op= e` is `x = x op e`: the read comes first, then the operand, then
      // the operator, then the write. The compound form is kept in the typed
      // AST so it round-trips; here it is spelled out.
      match op {
        None => self.instr(out, value)
        Some(binop) => {
          // `x op= e` spells out a tree the source did not write, so the
          // lowering records it: the read and the operand are the operator's
          // children, and the operator is a node of its own. Without that the
          // read has no span and the printer folds it into whatever follows.
          let at = out.length()
          self.read_span(out, name, loc)
          self.instr(out, value)
          guard node_valtype(value) is Some(ty) else {
            raise Unresolved("compound operand type", loc)
          }
          guard binop_instruction(binop.desc, ty) is Some(instruction) else {
            raise NotLowered("compound operator at this type", loc)
          }
          let op_at = out.length()
          out.push(instruction)
          self.spans.push({ start: at, head: op_at, end: op_at + 1, loc })
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
                // The MINUS is part of the spelling: `-0` and `0` are the same
                // i32 and two different things to read.
                out.push(
                  Spelled("-" + s, I32Const(-parse_i64(s, loc).to_int())),
                )
              } else {
                out.push(I32Const(0))
                self.instr(out, a)
                out.push(I32Sub)
              }
            Some(I64) =>
              if a.desc is Int(s) {
                out.push(Spelled("-" + s, I64Const(-parse_i64(s, loc))))
              } else {
                out.push(I64Const(0))
                self.instr(out, a)
                out.push(I64Sub)
              }
            // A negated float LITERAL folds too, and it has to: `-nan:0x..`
            // is a bit pattern, and reaching it by negating the positive one
            // flips a bit the source named explicitly. Every float negation
            // fits, so unlike the integers there is nothing to check.
            Some(F32) =>
              if a.desc is (Int(_) | Float(_)) {
                let t = literal_text(i, loc)
                out.push(Spelled(t, F32Const(parse_f32(t, loc))))
              } else {
                self.instr(out, a)
                out.push(F32Neg)
              }
            Some(F64) =>
              if a.desc is (Int(_) | Float(_)) {
                let t = literal_text(i, loc)
                out.push(Spelled(t, F64Const(parse_float_bits(t, true, loc))))
              } else {
                self.instr(out, a)
                out.push(F64Neg)
              }
            _ => raise Unresolved("negation type", loc)
          }
        // `!x` is `x == 0` on an integer and `ref.is_null` on a reference --
        // the same question, asked of two different kinds of nothing.
        Not => {
          self.instr(out, a)
          // In UNREACHABLE code there is no operand type, and `i32.eqz` stands
          // in: nothing runs, and the width is all that would have differed.
          match node_valtype(a) {
            Some(I64) => out.push(I64Eqz)
            Some(Ref(_)) => out.push(RefIsNull)
            Some(I32) | None => out.push(I32Eqz)
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
    // A declaration with NO initializer emits nothing at all: it reserves the
    // slot, and the slot is already reserved by the local collection pass.
    // Storing into it would take a value nobody pushed.
    Let(bindings, None) =>
      // Nothing is emitted, but the names still come into scope: a later read
      // of the binding has to find it.
      for b in bindings {
        if b.0 is Some(name) {
          self.bind_local(name, loc)
        }
      }
    Let(bindings, Some(init)) => {
      // The initializer is lowered BEFORE the names come into scope, so `let x
      // = x + 1` reads the outer `x` -- which is what the checker scoped it to.
      self.instr(out, init)
      for b in bindings {
        if b.0 is Some(name) {
          self.bind_local(name, loc)
        }
      }
      // Bound right to left: the values are on the stack with the LAST on top,
      // and each `local.set` takes the top one.
      //
      // SEVERAL bindings take a span each, because each is a statement: they
      // take turns off the same stack rather than nesting over one another,
      // and without the spans the printer reads the run as one tree and writes
      // `(local.set $q (local.set $r (call ...)))`.
      //
      // ONE binding is the opposite: `let x = e;` is `(local.set $x e)`, the
      // set folding over the initialiser, so it stays the node's own emission
      // and takes no span. Spanning it too was measured at 1395 exact to 1087.
      let many = bindings.length() > 1
      for k = bindings.length() - 1; k >= 0; k = k - 1 {
        let at = out.length()
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
        if many {
          self.spans.push({ start: at, head: at, end: at + 1, loc })
        }
      }
    }
    Block(label~, typ~, block~) =>
      out.push(Block(self.block_type(typ, loc), self.body(label, block.desc)))
    Loop(label~, typ~, block~) =>
      out.push(Loop(self.block_type(typ, loc), self.body(label, block.desc)))
    If(label~, typ~, cond~, if_block~, else_block~) => {
      self.instr(out, cond)
      // An `if`/`else` is ONE block in the label space -- a `br` inside either
      // branch counts it once, and it carries one name -- so the label frame
      // is opened once around both bodies rather than once per body.
      self.open_label(label)
      let then_ = self.instrs(if_block.desc)
      // Lowered even when there is none, so that an `if` always records TWO
      // nested span lists. The printer pairs them by count, and an `if` that
      // sometimes records one and sometimes two shifts every list after it.
      let else_ = match else_block {
        Some(b) => self.instrs(b.desc)
        None => self.instrs([])
      }
      let _ = self.labels.pop()
      out.push(If(self.block_type(typ, loc), then_, else_))
    }
    // A tail call lowers exactly like the call it is, and then the trailing
    // CALL becomes its `return_call` form. Reusing the whole call dispatch is
    // the point: `become f(x)` and `become tab[i](x)` are the same two
    // questions the plain forms answer, and answering them twice is how the
    // two spellings drift apart.
    TailCall(callee, args) => {
      // Lowered into an array of its own so the trailing call can be replaced,
      // which numbers its spans from zero -- so they are moved to where the
      // instructions land rather than left behind as a nested body that
      // belongs to nothing.
      let base = out.length()
      let (inner, inner_spans) = self.detached(scratch => {
        self.instr(scratch, { ..i, desc: Call(callee, args) })
      })
      guard inner.length() >= 1 else { return }
      let last = inner[inner.length() - 1]
      let tail : @wasm_bin.Instruction? = match last {
        Call(f) => Some(ReturnCall(f))
        CallIndirect(t, tab) => Some(ReturnCallIndirect(t, tab))
        CallRef(t) => Some(ReturnCallRef(t))
        // An INTRINSIC is not a call and has no tail form: it is evaluated and
        // its result returned, which is what the source asked for anyway.
        _ => None
      }
      for k in 0..<(inner.length() - 1) {
        out.push(inner[k])
      }
      match tail {
        Some(t) => out.push(t)
        None => {
          out.push(last)
          out.push(Return)
        }
      }
      self.rebase(inner_spans, base)
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
          let stored = if args.length() >= 2 {
            node_valtype(args[1])
          } else {
            None
          }
          if store_instruction(meth.name, mem, align, offset, stored)
            is Some(st) {
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
      // `tab[i](args)` is ONE instruction. A table read followed by a call
      // through the reference is what the syntax says, but `call_indirect`
      // does both, and the cast wax writes to name the signature is exactly
      // the type immediate it takes. The operands go args-then-index, which is
      // the reverse of how they are written.
      if self.indirect_call(out, callee, args, loc) {
        return
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
            out.push(Atomic(@atomics.opcode(op), mem, align, offset))
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
      // Dropping a SEGMENT. The receiver names one, not a value, so nothing
      // is emitted for it -- the segment index is the whole instruction.
      if callee.desc is StructGet(recv, meth) && meth.name == "drop" {
        if recv.desc is Get(seg) && !self.locals.contains(seg.name) {
          if self.indices.elems.get(seg.name) is Some(e) {
            out.push(ElemDrop(e))
            return
          }
          if self.indices.datas.get(seg.name) is Some(d) {
            out.push(DataDrop(d))
            return
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
      let inner : Array[@ast.Instr[@typing_env.InferredAnnotation]] = []
      for x in block.desc {
        inner.push(x)
      }
      for a in arms {
        for x in a.arm_body.desc {
          inner.push(x)
        }
      }
      let taken = self.enclosing_labels()
      if label is Some(l) {
        taken.push(l.name)
      }
      for name in labels_within(inner) {
        taken.push(name)
      }
      let arm_labels : Array[@ast.Ident] = []
      for k in 0..<arms.length() {
        let base = if k == 0 { "catch" } else { "catch_" + k.to_string() }
        let name = fresh_name(taken, base, 0)
        taken.push(name)
        arm_labels.push({ name, loc })
      }
      let join : @ast.Ident = match label {
        Some(l) => l
        None => { name: fresh_name(taken, "join", 0), loc }
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
      // The lowering's synthetic labels are the ones the DECOMPILER would have
      // written, because they reach the name section: a label-less `while`
      // becomes `loop`, and only a collision with an enclosing label, a label
      // nested in the body, or the while's own gives it a number.
      let inner = [cond]
      if step is Some(x) {
        inner.push(x)
      }
      for x in block.desc {
        inner.push(x)
      }
      let taken = self.enclosing_labels()
      if label is Some(l) {
        taken.push(l.name)
      }
      for name in labels_within(inner) {
        taken.push(name)
      }
      let fresh : @ast.Ident = { name: fresh_name(taken, "loop", 1), loc }
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
      // One `arm`/`arm_1`/... per arm, then `default` for the escape block,
      // each picked fresh so that neither an arm body's branch to an outer
      // label nor its own labelled block is captured.
      let inner : Array[@ast.Instr[@typing_env.InferredAnnotation]] = []
      for x in default.desc {
        inner.push(x)
      }
      for a in arms {
        for x in a.1.desc {
          inner.push(x)
        }
      }
      let taken = self.enclosing_labels()
      for name in labels_within(inner) {
        taken.push(name)
      }
      let labels : Array[@ast.Ident] = []
      for k in 0..<arms.length() {
        let base = if k == 0 { "arm" } else { "arm_" + k.to_string() }
        let name = fresh_name(taken, base, 0)
        taken.push(name)
        labels.push({ name, loc })
      }
      let escape = fresh_name(taken, "default", 0)
      labels.push({ name: escape, loc })
      // The synthesized nodes carry the SCRUTINEE's type, not the match's:
      // each threaded `br_on_cast` reads its source type off its operand's
      // annotation, and every fall-through value in the chain stays a subtype
      // of the scrutinee -- so the scrutinee's type is a valid source for all
      // of them, and the match's own result type is not.
      let chain_info = (scrutinee.info.0, loc)
      for
        x in @ast.lower_match(chain_info, labels~, scrutinee~, arms~, default~) {
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
      if target is Signed(typ~, signage~, ..) &&
        self.fused_atomic_load(out, operand, typ, signage, loc) {
        return
      }
      // A PACKED field or element reads the same way: the width is written on
      // the declaration and the sign on the cast, and the binary has one
      // instruction for the pair.
      if target is Signed(typ~, signage~, ..) &&
        self.fused_packed_read(out, operand, typ, signage, loc) {
        return
      }
      // A NULL cast to a reference type is simply that type's null. Emitting
      // a bottom null and then a `ref.cast` would not even validate: the bottom
      // of the `any` hierarchy is not in the `func` one, so the cast has no
      // common ground to stand on. A non-null target still needs the cast --
      // that is the trap the source is asking for.
      if operand.desc is Null && target is Value(Ref(r)) {
        let want = self.reftype_index(r, loc)
        out.push(RefNull(want.typ))
        if !want.nullable {
          out.push(RefCast(want))
        }
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
      // In UNREACHABLE code there is no type, and the untyped form is right
      // there too: nothing runs, so nothing needs telling apart.
      match node_valtype(i) {
        Some(Ref(_) as ty) => out.push(SelectTyped([ty]))
        Some(_) | None => out.push(Select)
      }
    }
    Str(named, bytes) => {
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
      // The construction remembers it was written as a string, and under
      // which type name if the source gave one: a run of constants says
      // nothing about having been text, and the index says nothing about
      // whether a name was written for it.
      let named_type = match named {
        Some(n) => Some(self.type_index_of(n, loc))
        None => None
      }
      out.push(FromString(bytes, named_type, ArrayNewFixed(t, units.length())))
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
          // The shorthand still READS a name, so it is a node like any other
          // and gets a span like any other -- without one the printer cannot
          // tell it apart from an instruction the construction emitted itself.
          None => self.read_span(out, f.0, loc)
        }
      }
      out.push(StructNew(t))
    }
    // The custom-descriptors constructions. The DESCRIPTOR is pushed last,
    // above the field values, because that is the order the instruction reads
    // them -- and the type is the construction's own (exact) result type
    // rather than anything the descriptor names.
    StructDesc(descriptor, fields) => {
      let (t, declared) = self.struct_fields_of(i, loc)
      guard fields.length() == declared.length() else {
        raise Unresolved("struct field count", loc)
      }
      for f in fields {
        match f.1 {
          Some(v) => self.instr(out, v)
          // The shorthand still READS a name, so it is a node like any other
          // and gets a span like any other -- without one the printer cannot
          // tell it apart from an instruction the construction emitted itself.
          None => self.read_span(out, f.0, loc)
        }
      }
      self.instr(out, descriptor)
      out.push(StructNewDesc(t))
    }
    StructDefaultDesc(descriptor) => {
      let (t, _) = self.struct_fields_of(i, loc)
      self.instr(out, descriptor)
      out.push(StructNewDefaultDesc(t))
    }
    // `v as ?descriptor(d)` tests a value against a DESCRIPTOR rather than a
    // type immediate -- so the descriptor is an operand, pushed last, and the
    // immediate is the cast's own (exact) result type. The branching forms are
    // the same test with the residual routed to a label.
    CastDesc(value, _, descriptor) => {
      self.instr(out, value)
      self.instr(out, descriptor)
      guard node_valtype(i) is Some(Ref(r)) else {
        raise Unresolved("descriptor cast type", loc)
      }
      out.push(RefCastDescEq(r))
    }
    BrOnCastDescEq(label, nullable, value, descriptor) => {
      self.instr(out, value)
      self.instr(out, descriptor)
      let to = self.descriptor_target(i, nullable, loc)
      out.push(
        BrOnCastDescEq(self.depth(label, loc), br_on_cast_source(value, to), to),
      )
    }
    BrOnCastDescEqFail(label, nullable, value, descriptor) => {
      self.instr(out, value)
      self.instr(out, descriptor)
      let to = self.descriptor_target(i, nullable, loc)
      out.push(
        BrOnCastDescEqFail(
          self.depth(label, loc),
          br_on_cast_source(value, to),
          to,
        ),
      )
    }
    // A struct's descriptor, read back off it. The type immediate is the
    // RECEIVER's, not the descriptor's: it says which struct is being asked.
    GetDescriptor(e) => {
      self.instr(out, e)
      guard node_type_index(e) is Some(t) else {
        raise Unresolved("descriptor receiver type", loc)
      }
      out.push(RefGetDesc(t))
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
    // An unresolved `#[if(..)]` has nowhere to go in the binary format, and
    // the reference refuses it there too -- the fix is `-D`. The TEXT format
    // writes it, and then BOTH branches are lowered side by side and told
    // apart afterwards by where each was written. That is not a body anyone
    // could run, which is why it is only ever built for the text form.
    IfAnnotation(cond~, then_body~, else_body~) => {
      guard self.keep_conditionals else {
        raise Unemittable("conditional annotations", loc)
      }
      self.body_conditionals.push({
        cond: wat_cond(cond),
        loc,
        then_: then_body.info,
        else_: else_body.map(b => b.info),
      })
      for st in then_body.desc {
        self.instr(out, st)
      }
      if else_body is Some(b) {
        for st in b.desc {
          self.instr(out, st)
        }
      }
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
  let out = self.instrs(instrs)
  let _ = self.labels.pop()
  out
}

///|
/// Bring a `let` binding's name into scope, at the slot it was assigned.
fn Lowering::bind_local(
  self : Lowering,
  name : @ast.Ident,
  loc : @basic.Location,
) -> Unit raise LowerError {
  guard self.binding_slots.get(name.loc.start.cnum) is Some(slot) else {
    raise Unresolved("local binding", loc)
  }
  self.locals[name.name] = slot
}

///|
/// Lower a run of instructions into a fresh array, opening no label of its own.
fn Lowering::instrs(
  self : Lowering,
  instrs : Array[@ast.Instr[@typing_env.InferredAnnotation]],
) -> Array[@wasm_bin.Instruction] raise LowerError {
  // A nested body is its OWN array with its own indices, so it collects its
  // own spans; they are handed to the nested list as the body completes.
  let outer = self.spans
  self.spans = []
  let out : Array[@wasm_bin.Instruction] = []
  for s in instrs {
    self.instr(out, s)
  }
  self.nested_spans.push(self.spans)
  self.spans = outer
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
            Some(f) => {
              // Record which side of the declaration question this reference
              // falls on: one inside a body declares nothing.
              let into = if self.in_body {
                self.func_refs_in_body
              } else {
                self.func_refs_outside
              }
              if !into.contains(name.name) {
                into.push(name.name)
              }
              RefFunc(f)
            }
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
/// A NARROW ATOMIC LOAD and its zero-extending cast, as one instruction.
///
/// The same fusion the plain loads get, for the same reason: wax writes the
/// width on the method and the extension on the cast, and the binary has a
/// single opcode for the pair. Only the UNSIGNED direction exists -- there is
/// no sign-extending atomic load -- so a signed cast falls through to the
/// generic path, which is right: it really is two operations.
fn Lowering::fused_atomic_load(
  self : Lowering,
  out : Array[@wasm_bin.Instruction],
  operand : @ast.Instr[@typing_env.InferredAnnotation],
  typ : @ast.NumType,
  signage : @wasm_types.Signage,
  loc : @basic.Location,
) -> Bool raise LowerError {
  guard signage is Unsigned else { return false }
  guard operand.desc is Call(callee, args) else { return false }
  guard callee.desc is StructGet(recv, meth) else { return false }
  guard recv.desc is Get(memname) else { return false }
  guard self.indices.memories.get(memname.name) is Some(mem) else {
    return false
  }
  guard @atomics.of_method_name(meth.name) is Some(Load(width)) else {
    return false
  }
  let op : @atomics.Op = match (width, typ) {
    (W8, I32) => Load(I32, Some(N8))
    (W8, I64) => Load(I64, Some(N8))
    (W16, I32) => Load(I32, Some(N16))
    (W16, I64) => Load(I64, Some(N16))
    (W32, I64) => Load(I64, Some(N32))
    _ => return false
  }
  let (align, offset) = self.memarg_natural(
    log2_exact(@atomics.family_bytes(Load(width)).to_int64(), loc),
    args,
    loc,
  )
  for a in args {
    if !(a.desc is Labelled(_, _)) {
      self.instr(out, a)
    }
  }
  out.push(Atomic(@atomics.opcode(op), mem, align, offset))
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
/// Re-fuse a table read and a call through it into `call_indirect`.
///
/// Three spellings reach the same instruction: the read cast to a named
/// function type, the read cast to an inline one, and the bare read when the
/// table's own element type already names a signature. What they share is that
/// the type is known WITHOUT running anything, which is the whole condition --
/// `call_indirect` carries its signature as an immediate.
fn Lowering::indirect_call(
  self : Lowering,
  out : Array[@wasm_bin.Instruction],
  callee : @ast.Instr[@typing_env.InferredAnnotation],
  args : Array[@ast.Instr[@typing_env.InferredAnnotation]],
  loc : @basic.Location,
) -> Bool raise LowerError {
  let (read, signature) = match callee.desc {
    Cast(inner, Value(Ref({ typ: Type(ft), .. }))) =>
      (inner, Some(self.type_index_of(ft, loc)))
    // A bare read: the table's element type names the signature, so there is
    // nothing for a cast to add.
    ArrayGet(_, _) => (callee, None)
    _ => return false
  }
  guard read.desc is ArrayGet(recv, index) else { return false }
  guard self.table_of(recv) is Some(tab) else { return false }
  let type_idx = match signature {
    Some(t) => t
    None =>
      match node_type_index(read) {
        Some(t) => t
        None => return false
      }
  }
  for a in args {
    self.instr(out, a)
  }
  self.instr(out, index)
  out.push(CallIndirect(type_idx, tab))
  true
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
        // The SHAPE is part of the spelling. Sixteen bytes are sixteen bytes
        // whichever shape wrote them, and the text says which one did.
        let texts : Array[String] = []
        for a in args {
          texts.push(literal_text(a, loc))
        }
        let spelling = StringBuilder::new()
        spelling.write_string(shape.to_str())
        for t in texts {
          spelling.write_string(" " + t)
        }
        out.push(
          Spelled(
            spelling.to_string(),
            V128Const(vector_bytes(shape, texts, loc)),
          ),
        )
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
/// The 16 bytes of a vector, from its lanes as written.
pub fn vector_bytes(
  shape : @simd.Shape,
  texts : Array[String],
  loc : @basic.Location,
) -> Bytes raise LowerError {
  let lanes = @simd.const_arity(shape)
  guard texts.length() == lanes else { raise Unresolved("vector lanes", loc) }
  let width = 16 / lanes
  let out : Array[Byte] = Array::make(16, b'\x00')
  for k in 0..<lanes {
    let text = texts[k]
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
/// The target reference type of a descriptor branch.
///
/// The node's own type is the RESIDUAL -- what is left when the test fails --
/// so the target is recovered from it and the nullability the branch wrote.
fn Lowering::descriptor_target(
  self : Lowering,
  i : @ast.Instr[@typing_env.InferredAnnotation],
  nullable : Bool,
  loc : @basic.Location,
) -> @wasm_types.RefType[Int] raise LowerError {
  ignore(self)
  guard node_last_reftype(i) is Some(r) else {
    raise Unresolved("descriptor branch type", loc)
  }
  { ..r, nullable, }
}

///|
/// The `tag:` immediate a stack-switching method carries.
fn labelled_tag(
  args : Array[@ast.Instr[@typing_env.InferredAnnotation]],
  loc : @basic.Location,
) -> @ast.Ident raise LowerError {
  for a in args {
    if a.desc is Labelled(l, v) && l.name == "tag" && v.desc is Get(t) {
      return t
    }
  }
  raise Unresolved("tag immediate", loc)
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
    // A CROSS-space copy names the source first: `dst.copy(src, i, j, n)`.
    // It is told from the same-space `dst.copy(i, j, n)` by the first argument
    // naming a memory or table rather than being a value -- which is what
    // makes the two spellings one method.
    "copy" =>
      if args.length() >= 1 &&
        args[0].desc is Get(n) &&
        (
          self.indices.memories.get(n.name) is Some(_) ||
          self.indices.tables.get(n.name) is Some(_)
        ) &&
        !self.locals.contains(n.name) {
        (Some(n), args[1:].to_owned())
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
      out.push(MemoryInit(m, d))
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
      out.push(TableInit(t, e))
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
fn Lowering::functype_of(
  self : Lowering,
  typ : @ast.FuncType,
  loc : @basic.Location,
) -> Int raise LowerError {
  self.block_functype_index(typ, loc)
}

///|
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
  // The pre-built table first, then the section itself -- which may have to
  // grow: a block's signature is named by SHAPE, and nothing is obliged to
  // have interned that shape before the block asked for it.
  if self.functypes.get((params, results)) is Some(i) {
    return i
  }
  guard emitted_shape_index(params, results) is Some(i) else {
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
  typ : @ast.NumType,
  signage : @wasm_types.Signage,
  loc : @basic.Location,
) -> Bool raise LowerError {
  // A packed read yields an i32 and nothing else: there is no `array.get` or
  // `struct.get` that produces an i64. So `as i64_u` is the fused read AND a
  // widening, and dropping the widening leaves an i32 where an i64 is wanted.
  fn widen(out : Array[@wasm_bin.Instruction]) -> Unit {
    if typ is I64 {
      out.push(if signage is Signed { I64ExtendI32S } else { I64ExtendI32U })
    }
  }

  guard typ is (I32 | I64) else { return false }
  match operand.desc {
    ArrayGet(recv, index) => {
      guard self.table_of(recv) is None else { return false }
      let (t, f) = self.array_element_of(recv, loc)
      guard is_packed(f) else { return false }
      self.instr(out, recv)
      self.instr(out, index)
      out.push(if signage is Signed { ArrayGetS(t) } else { ArrayGetU(t) })
      widen(out)
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
      widen(out)
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
  // By NAME first. Two declarations of one shape share a store entry but not an
  // emitted index, and a reference that names one of them means that one.
  if self.layout.by_name.get(name.name) is Some(emitted) {
    return emitted
  }
  guard self.ctx.type_context.types.find_no_mark(name.name) is Some((idx, _)) else {
    raise Unresolved("type name", loc)
  }
  match idx {
    Def(id) => emitted_type_index(id.to_int_for_tests_only())
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
    // Both remaining forms name a TAG, and the checker leaves it labelled on
    // the node for exactly this read -- `switch` because that is how it was
    // written, `resume_throw` because an invocation is not a shape a code
    // generator can read a name out of twice.
    "resume_throw" =>
      ResumeThrow(ct, self.tag_of(labelled_tag(args, loc), loc), on)
    _ => Switch(ct, self.tag_of(labelled_tag(args, loc), loc))
  }
}
