// Expressions, lowered to Wax instructions.
//
// Every case here is a translation rather than a compilation: what comes out is
// something a person could have written in was, which is the property that
// makes `wap -f was` a specification rather than a debugging aid.

///|
/// Lower a sequence of expressions.
fn Lowering::body(
  self : Lowering,
  body : Array[@wap.Node],
) -> Array[@ast.Instr[@basic.Location]] {
  let out = []
  for e in body {
    for i in self.stmts(e) {
      out.push(i)
    }
  }
  out
}

///|
/// One wap expression as the instructions it becomes in statement position.
///
/// Several wap forms are more than one Wax instruction -- a `for` is a binding
/// and a `while`, a multiple assignment is a temporary per target -- and Wax's
/// `let` scopes over the rest of the block it is in. Splicing them into the
/// enclosing block is therefore not a tidiness: wrapping them in a `Sequence`
/// would put a binding somewhere a value is expected.
fn Lowering::stmts(
  self : Lowering,
  e : @wap.Node,
) -> Array[@ast.Instr[@basic.Location]] {
  match e.it {
    Block(items) => self.body(items)
    Assign(targets~, op~, value~) => self.assign(targets, op, value, e.span)
    Match(scrutinee~, arms~, typ~) =>
      self.match_expr(scrutinee, arms, typ, e.span)
    ForRange(label~, var_~, from~, to~, inclusive~, by~, body~) =>
      self.for_range(label, var_, from, to, inclusive, by, body, e.span)
    ForIn(label~, var_~, seq~, body~) =>
      self.for_in(label, var_, seq, body, e.span)
    _ => [self.expr(e, None)]
  }
}

///|
/// A block of instructions with a location, which is what Wax's block-shaped
/// constructors take.
fn Lowering::blk(
  self : Lowering,
  body : Array[@wap.Node],
  span : @wap.Span,
) -> @basic.Annotated[Array[@ast.Instr[@basic.Location]], @basic.Location] {
  { desc: self.body(body), info: self.loc(span), }
}

///|
/// True when `&&` or `||` should short-circuit rather than combine bits.
///
/// An unannotated operand -- a bare integer literal, a call wap cannot see the
/// signature of -- is treated as a condition, because that is what an untyped
/// operand of a logical operator nearly always is.
fn Lowering::is_boolean(self : Lowering, a : @wap.Node, b : @wap.Node) -> Bool {
  let known = match self.type_of(a) {
    Some(t) => Some(t)
    None => self.type_of(b)
  }
  match known {
    Some(t) => self.underlying(t) is Bool
    None => true
  }
}

///|
/// Bitwise or, which has no infix spelling of its own.
fn Lowering::bit_or(
  self : Lowering,
  a : @wap.Node,
  b : @wap.Node,
  sp : @wap.Span,
) -> @ast.Instr[@basic.Location] {
  let at = self.loc(sp)
  let t = match self.type_of(a) {
    Some(t) => Some(t)
    None => self.type_of(b)
  }
  @ast.build(
    BinOpI({ desc: Or, info: at, }, self.expr(a, t), self.expr(b, t)),
    at,
  )
}

///|
/// One instruction, or a sequence of them.
fn seq_of(
  xs : Array[@ast.Instr[@basic.Location]],
  at : @basic.Location,
) -> @ast.Instr[@basic.Location] {
  if xs.length() == 1 {
    xs[0]
  } else {
    @ast.build(Sequence(xs), at)
  }
}

///|
/// An empty function type: Wax reads it as "no annotation", and infers.
fn empty_type() -> @ast.FuncType {
  { params: [], results: [], }
}

///|
/// A function type with one result, for the conditionals that stand in for
/// `&&` and `||`.
fn Lowering::i32_type(self : Lowering) -> @ast.FuncType {
  ignore(self)
  { params: [], results: [I32], }
}

///|
/// Lower one expression.
fn Lowering::expr(
  self : Lowering,
  e : @wap.Node,
  expected : @wap.Type?,
) -> @ast.Instr[@basic.Location] {
  let sp = e.span
  let at = self.loc(sp)
  match e.it {
    Int(s) => @ast.build(Int(s), at)
    Float(s) => @ast.build(Float(s), at)
    BoolLit(b) => @ast.build(Int(if b { "1" } else { "0" }), at)
    CharLit(c) => @ast.build(Char(c), at)
    Null => @ast.build(Null, at)
    Nop => @ast.build(Nop, at)
    Unreachable => @ast.build(Unreachable, at)
    StrLit(s) => {
      let name = self.array_type(U8, sp)
      @ast.build(Str(Some(self.ident(name, sp)), @utf8.encode(s)), at)
    }
    Var(n) => self.var_ref(n, sp)
    Drop(inner) =>
      @ast.build(Let([(None, None)], Some(self.expr(inner, None))), at)
    Field(recv, name) => {
      let base = @ast.build(
        StructGet(self.expr(recv, None), self.ident(name, sp)),
        at,
      )
      self.widen(base, self.field_of(recv, name), sp)
    }
    Index(a, i) =>
      // `ints[0]` is an array literal when `ints` is a type, and an index when
      // it is a value. Only the declarations know which.
      match a.it {
        Var(n) if self.nominal(n) =>
          @ast.build(
            ArrayFixed(Some(self.ident(self.mangle(n), sp)), [
              self.expr(i, self.elem_of_named(n)),
            ]),
            at,
          )
        _ => {
          let base = @ast.build(
            ArrayGet(self.expr(a, None), self.expr(i, None)),
            at,
          )
          let elem = match self.type_of(a) {
            Some(t) => self.elem_type(t)
            None => None
          }
          self.widen(base, elem, sp)
        }
      }
    TupleLit(items) => {
      // A tuple is its elements, in order: wasm multi-value, not a value.
      let out = []
      for it in items {
        out.push(self.expr(it, None))
      }
      @ast.build(Sequence(out), at)
    }
    SetLit(items) => self.set_literal(items, expected, sp)
    RecordLit(typ~, fields~) => {
      let name = match typ {
        Some(n) => Some(self.ident(self.mangle(n), sp))
        None => self.expected_record(expected, sp)
      }
      let fs = []
      for f in fields {
        let (fname, value) = f
        let ftyp = match typ {
          Some(t) => self.field_type(t, fname)
          None => None
        }
        fs.push(
          (
            self.ident(fname, sp),
            match value {
              Some(v) => Some(self.expr(v, ftyp))
              None => None
            },
          ),
        )
      }
      @ast.build(Struct(name, fs), at)
    }
    RecordDefault(typ~) => {
      let name = match typ {
        Some(n) => Some(self.ident(self.mangle(n), sp))
        None => self.expected_record(expected, sp)
      }
      @ast.build(StructDefault(name), at)
    }
    ArrayLit(typ~, items~) => {
      let name = match typ {
        Some(n) => Some(self.ident(self.mangle(n), sp))
        None => self.expected_array(expected, sp)
      }
      let elem = self.elem_hint(typ, expected)
      let out = []
      for it in items {
        out.push(self.expr(it, elem))
      }
      @ast.build(ArrayFixed(name, out), at)
    }
    ArrayRepeat(typ~, value~, count~) => {
      let name = match typ {
        Some(n) => Some(self.ident(self.mangle(n), sp))
        None => self.expected_array(expected, sp)
      }
      let elem = self.elem_hint(typ, expected)
      @ast.build(
        Array(name, self.expr(value, elem), self.expr(count, None)),
        at,
      )
    }
    Call(callee, args) => {
      let f = match callee.it {
        Var(n) => self.var_ref(n, callee.span)
        _ => self.expr(callee, None)
      }
      let sig = match callee.it {
        Var(n) => self.funcs.get(n)
        _ => None
      }
      let out = []
      for i, a in args {
        let hint = match sig {
          Some(s) =>
            if i < s.params.length() {
              Some(s.params[i])
            } else {
              None
            }
          None => None
        }
        out.push(self.expr(a, hint))
      }
      @ast.build(Call(f, out), at)
    }
    MethodCall(recv, name, args) => self.method_call(recv, name, args, sp)
    Bin(op, a, b) => self.binary(op, a, b, sp)
    Un(Neg, a) =>
      @ast.build(UnOpI({ desc: Neg, info: at, }, self.expr(a, expected)), at)
    Un(Not, a) =>
      @ast.build(UnOpI({ desc: Not, info: at, }, self.expr(a, None)), at)
    // `&&` and `||` are logical on `bool` and bitwise on integers, decided by
    // the operands' types -- the same rule that makes `<` a signed or an
    // unsigned comparison. Shrubbery's `|` is the alternatives marker, so
    // there is no separate bitwise spelling to give them.
    AndAlso(a, b) =>
      if self.is_boolean(a, b) {
        @ast.build(
          If(
            label=None,
            typ=self.i32_type(),
            cond=self.expr(a, None),
            if_block={ desc: [self.expr(b, None)], info: at, },
            else_block=Some({ desc: [@ast.build(Int("0"), at)], info: at, }),
          ),
          at,
        )
      } else {
        self.binary(BitAnd, a, b, sp)
      }
    OrElse(a, b) =>
      if self.is_boolean(a, b) {
        @ast.build(
          If(
            label=None,
            typ=self.i32_type(),
            cond=self.expr(a, None),
            if_block={ desc: [@ast.build(Int("1"), at)], info: at, },
            else_block=Some({ desc: [self.expr(b, None)], info: at, }),
          ),
          at,
        )
      } else {
        self.bit_or(a, b, sp)
      }
    InSet(x, s) => self.in_set(x, s, sp)
    Cast(inner, t) => self.cast(inner, t, sp)
    Test(inner, t) => {
      let v = self.valtype(t, sp)
      match v {
        Ref(r) => @ast.build(Test(self.expr(inner, None), r), at)
        _ => {
          self.error("`is` tests a reference type", sp)
          @ast.build(Int("0"), at)
        }
      }
    }
    NonNull(inner) => @ast.build(NonNull(self.expr(inner, None)), at)
    Block(items) => @ast.build(Sequence(self.body(items)), at)
    Bind(binders~, value~, ..) => {
      let bs = []
      for b in binders {
        let t = match b.typ {
          Some(t) => Some(t)
          None =>
            match value {
              Some(v) =>
                if binders.length() == 1 {
                  self.type_of(v)
                } else {
                  None
                }
              None => None
            }
        }
        match t {
          Some(t) => self.bind(b.name, t)
          None => ()
        }
        bs.push(
          (
            Some(self.ident(b.name, b.span)),
            match b.typ {
              Some(t) => Some(self.valtype(t, b.span))
              None => None
            },
          ),
        )
      }
      let v = match value {
        Some(v) =>
          Some(
            self.expr(
              v,
              if binders.length() == 1 {
                binders[0].typ
              } else {
                None
              },
            ),
          )
        None => None
      }
      @ast.build(Let(bs, v), at)
    }
    Assign(targets~, op~, value~) =>
      seq_of(self.assign(targets, op, value, sp), at)
    If(arms~, typ~) => self.conditional(arms, typ, sp)
    While(label~, cond~, step~, body~) =>
      self.while_loop(label, cond, step, body, sp)
    Loop(label~, body~) => self.plain_loop(label, body, sp)
    ForRange(label~, var_~, from~, to~, inclusive~, by~, body~) =>
      seq_of(self.for_range(label, var_, from, to, inclusive, by, body, sp), at)
    ForIn(label~, var_~, seq~, body~) => {
      let s = seq
      seq_of(self.for_in(label, var_, s, body, sp), at)
    }
    Break(label) => self.jump(label, true, sp)
    Continue(label) => self.jump(label, false, sp)
    Return(v) =>
      @ast.build(
        Return(
          match v {
            Some(v) => Some(self.expr(v, None))
            None => None
          },
        ),
        at,
      )
    Match(scrutinee~, arms~, typ~) =>
      seq_of(self.match_expr(scrutinee, arms, typ, sp), at)
  }
}

// ------------------------------------------------------------------ names

///|
/// A name in expression position: an enumerator, a local, a global or a
/// function.
fn Lowering::var_ref(
  self : Lowering,
  n : String,
  sp : @wap.Span,
) -> @ast.Instr[@basic.Location] {
  let at = self.loc(sp)
  // An enumerator is a constant, and never reaches the emitted module.
  if self.local_type(n) is None {
    match self.member_owner.get(n) {
      Some(owner) =>
        match self.enum_members.get(owner) {
          Some(ms) =>
            match ms.get(n) {
              Some(v) => return @ast.build(Int(v.to_string()), at)
              None => ()
            }
          None => ()
        }
      None => ()
    }
  }
  if self.local_type(n) is Some(_) {
    return @ast.build(Get(self.ident(n, sp)), at)
  }
  match self.funcs.get(n) {
    Some(sig) => @ast.build(Get(self.ident(sig.emitted, sp)), at)
    None =>
      if self.globals.contains(n) {
        @ast.build(Get(self.ident(self.mangle(n), sp)), at)
      } else {
        @ast.build(Get(self.ident(n, sp)), at)
      }
  }
}

///|
/// The declared type of `recv.name`, if it is knowable.
fn Lowering::field_of(
  self : Lowering,
  recv : @wap.Node,
  name : String,
) -> @wap.Type? {
  match self.type_of(recv) {
    Some(t) =>
      match self.record_name(t) {
        Some(r) => self.field_type(r, name)
        None => None
      }
    None => None
  }
}

///|
/// The element type of a named array type.
fn Lowering::elem_of_named(self : Lowering, n : String) -> @wap.Type? {
  self.elem_type(Named(n))
}

///|
/// An element-type hint for the items of an array literal.
fn Lowering::elem_hint(
  self : Lowering,
  typ : String?,
  expected : @wap.Type?,
) -> @wap.Type? {
  match typ {
    Some(n) => self.elem_type(Named(n))
    None =>
      match expected {
        Some(t) => self.elem_type(t)
        None => None
      }
  }
}

///|
/// The record an untyped `{...}` should build, from the expected type.
fn Lowering::expected_record(
  self : Lowering,
  expected : @wap.Type?,
  sp : @wap.Span,
) -> @ast.Ident? {
  match expected {
    Some(t) =>
      match self.record_name(t) {
        Some(r) => Some(self.ident(self.mangle(r), sp))
        None => None
      }
    None => None
  }
}

///|
/// The array type an untyped `[...]` should build.
fn Lowering::expected_array(
  self : Lowering,
  expected : @wap.Type?,
  sp : @wap.Span,
) -> @ast.Ident? {
  match expected {
    Some(Named(n)) if self.nominal(n) => Some(self.ident(self.mangle(n), sp))
    Some(ArrayOf(e)) => Some(self.ident(self.array_type(e, sp), sp))
    _ => None
  }
}

///|
/// Widen a packed field or element on the way out.
///
/// Wax makes this explicit -- `arr[i] as i32_u` -- because the signedness is
/// not recoverable from the storage type. In wap it is: `u8` says unsigned and
/// `i8` says signed, so the cast is inserted rather than written.
fn Lowering::widen(
  self : Lowering,
  base : @ast.Instr[@basic.Location],
  typ : @wap.Type?,
  sp : @wap.Span,
) -> @ast.Instr[@basic.Location] {
  match typ {
    Some(t) =>
      if self.is_packed(t) {
        let signage = match self.signage(Some(t)) {
          Some(s) => s
          None => @wasm_types.Signage::Unsigned
        }
        @ast.build(
          Cast(base, Signed(typ=I32, signage~, strict=false)),
          self.loc(sp),
        )
      } else {
        base
      }
    None => base
  }
}
