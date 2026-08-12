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
      // The no-argument instruction methods: `x.clz()`, `arr.length()`. Their
      // opcode comes from the RECEIVER's type, which is the only thing that
      // distinguishes `i32.clz` from `i64.clz`.
      if callee.desc is StructGet(recv, meth) && args.is_empty() {
        if unary_instruction(meth.name, node_valtype(recv)) is Some(op) {
          self.instr(out, recv)
          out.push(op)
          return
        }
        if meth.name == "length" && node_type_index(recv) is Some(_) {
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
      guard node_valtype(operand) is Some(Ref(from)) else {
        raise Unresolved("br_on_cast operand type", loc)
      }
      out.push(
        BrOnCast(self.depth(label, loc), from, self.reftype_index(target, loc)),
      )
    }
    BrOnCastFail(label, target, operand) => {
      self.instr(out, operand)
      guard node_valtype(operand) is Some(Ref(from)) else {
        raise Unresolved("br_on_cast operand type", loc)
      }
      out.push(
        BrOnCastFail(
          self.depth(label, loc),
          from,
          self.reftype_index(target, loc),
        ),
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
            Ref(r) =>
              // Crossing between the `any` and `extern` hierarchies is a
              // CONVERSION, not a check: the two share no value, so a cast
              // between them could only trap, and what the source means is the
              // lossless form.
              match (from, hierarchy_conversion_of(from, r.typ)) {
                (_, Some(conv)) => out.push(conv)
                _ => out.push(RefCast(r))
              }
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
    Struct(_, fields) => {
      let (t, declared) = self.struct_fields_of(i, loc)
      guard fields.length() == declared.length() else {
        raise Unresolved("struct field count", loc)
      }
      // The checker rebuilt the fields in DECLARED order, which is the order
      // `struct.new` takes them in -- so they are emitted as they stand.
      for f in fields {
        guard f.1 is Some(v) else {
          raise Unresolved("struct field value", loc)
        }
        self.instr(out, v)
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
/// The hierarchy conversion between a value type and a target heap type.
fn hierarchy_conversion_of(
  from : @wasm_types.ValType[Int],
  to : @wasm_types.HeapType[Int],
) -> @wasm_bin.Instruction? {
  guard from is Ref(r) else { return None }
  hierarchy_conversion(r.typ, to)
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
