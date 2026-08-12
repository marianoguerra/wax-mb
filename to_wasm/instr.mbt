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
  let loc = i.info.1
  match i.desc {
    Nop => out.push(Nop)
    Unreachable => out.push(Unreachable)
    Int(s) =>
      match node_valtype(i) {
        Some(I32) => out.push(I32Const(parse_i32(s, loc)))
        Some(I64) => out.push(I64Const(parse_i64(s, loc)))
        Some(F32) => out.push(F32Const(Float::from_double(parse_f64(s, loc))))
        Some(F64) => out.push(F64Const(parse_f64(s, loc)))
        _ => raise Unresolved("integer literal type", loc)
      }
    Float(s) =>
      match node_valtype(i) {
        Some(F32) => out.push(F32Const(Float::from_double(parse_f64(s, loc))))
        Some(F64) => out.push(F64Const(parse_f64(s, loc)))
        _ => raise Unresolved("float literal type", loc)
      }
    // A character literal is an i32 code point.
    Char(c) => out.push(I32Const(c.to_int()))
    Get(name) => out.push(self.read(name, loc))
    Set(name, op, value) => {
      guard op is None else { raise NotLowered("compound assignment", loc) }
      self.instr(out, value)
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
            Some(I32) => {
              out.push(I32Const(0))
              self.instr(out, a)
              out.push(I32Sub)
            }
            Some(I64) => {
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
        // `!x` is `x == 0` on an integer.
        Not =>
          match node_valtype(a) {
            Some(I32) => {
              self.instr(out, a)
              out.push(I32Eqz)
            }
            Some(I64) => {
              self.instr(out, a)
              out.push(I64Eqz)
            }
            _ => raise NotLowered("logical not at this type", loc)
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
      guard self.depth_of(label.name) is Some(d) else {
        raise Unresolved("branch target", loc)
      }
      out.push(Br(d))
    }
    BrIf(label, operand) => {
      self.instr(out, operand)
      guard self.depth_of(label.name) is Some(d) else {
        raise Unresolved("branch target", loc)
      }
      out.push(BrIf(d))
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
    Call(callee, args) => {
      for a in args {
        self.instr(out, a)
      }
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
      guard callee.desc is Get(name) else {
        // Named precisely, because these are three different jobs wearing one
        // syntax and the burn-down needs to tell them apart.
        raise NotLowered(
          match callee.desc {
            StructGet(_, meth) => "method '" + meth.name + "'"
            Path(ns, meth) => "intrinsic '" + ns.name + "::" + meth.name + "'"
            _ => "indirect call"
          },
          loc,
        )
      }
      guard self.indices.funcs.get(name.name) is Some(f) else {
        raise Unresolved("call target", loc)
      }
      out.push(Call(f))
    }
    Cast(operand, target) => {
      // A narrow load and a following sign cast are ONE instruction: wax splits
      // the width and the signedness across two constructs, and the binary has
      // no separate sign-extension to emit afterwards.
      if target is Signed(typ~, signage~, ..) &&
        self.fused_load(out, operand, typ, signage, loc) {
        return
      }
      self.instr(out, operand)
      guard node_valtype(operand) is Some(from) else {
        raise Unresolved("cast operand type", loc)
      }
      match target {
        Value(_) => {
          guard node_valtype(i) is Some(to) else {
            raise Unresolved("cast target type", loc)
          }
          match to {
            // A reference target is a run-time check, not a conversion.
            Ref(r) => out.push(RefCast(r))
            _ => {
              guard numeric_cast(from, to) is Some(instrs) else {
                raise NotLowered("cast between these types", loc)
              }
              for x in instrs {
                out.push(x)
              }
            }
          }
        }
        Signed(typ~, signage~, strict~) => {
          guard signed_cast(from, typ, signage, strict) is Some(instrs) else {
            raise NotLowered("signed cast between these types", loc)
          }
          for x in instrs {
            out.push(x)
          }
        }
        Func(..) => raise NotLowered("function-type cast", loc)
      }
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
  self.labels.push(label.map(l => l.name))
  let out : Array[@wasm_bin.Instruction] = []
  for s in instrs {
    self.instr(out, s)
  }
  let _ = self.labels.pop()
  out
}

///|
/// A block's signature, as the format spells it.
fn Lowering::block_type(
  self : Lowering,
  typ : @ast.FuncType,
  loc : @basic.Location,
) -> @wasm_bin.BlockType raise LowerError {
  ignore(self)
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
          Ref(_) => raise NotLowered("reference block result", loc)
        }
      _ => raise NotLowered("multi-value block", loc)
    }
  } else {
    raise NotLowered("parameterized block", loc)
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
