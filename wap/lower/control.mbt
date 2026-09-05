// Assignment and control flow.
//
// This is where wap earns most of its keep: the labels a Wax loop needs are
// generated here, and `break` and `continue` name the loop rather than the
// branch target. Nothing is emitted that was not used -- a loop no one breaks
// out of gets no enclosing block.

///|
/// `x = e`, `x += e`, and `(x, y) = (a, b)`.
fn Lowering::assign(
  self : Lowering,
  targets : Array[@wap.Node],
  op : @wap.AssignOp,
  value : @wap.Node,
  sp : @wap.Span,
) -> Array[@ast.Instr[@basic.Location]] {
  let at = self.loc(sp)
  if targets.length() == 1 {
    return [self.assign_one(targets[0], op, value, sp)]
  }
  // Multiple assignment reads every right-hand side before writing any left,
  // which on wasm means one temporary per target. They are named in the
  // output; they are the whole cost of `(x, y) = (y, x)`.
  let values = match value.it {
    TupleLit(items) => items
    _ => {
      self.error(
        "assigning to several names needs as many values",
        sp,
        help="write `(x, y) = (a, b)`, or bind the call's results with `let`",
      )
      return [@ast.build(Unreachable, at)]
    }
  }
  if values.length() != targets.length() {
    self.error(
      "there are " +
      targets.length().to_string() +
      " names and " +
      values.length().to_string() +
      " values",
      sp,
    )
    return [@ast.build(Unreachable, at)]
  }
  let out = []
  let temps = []
  for i, v in values {
    let name = self.gensym("t")
    temps.push(name)
    let vt = self.type_of(v)
    match vt {
      Some(t) => self.bind(name, t)
      None => ()
    }
    out.push(
      @ast.build(
        Let(
          [(Some({ name, loc: self.fresh_loc(), }), None)],
          Some(self.expr(v, None)),
        ),
        at,
      ),
    )
    ignore(i)
  }
  for i, t in targets {
    let tmp : @wap.Node = { it: Var(temps[i]), span: sp, }
    out.push(self.assign_one(t, Set, tmp, sp))
  }
  out
}

///|
fn Lowering::assign_one(
  self : Lowering,
  target : @wap.Node,
  op : @wap.AssignOp,
  value : @wap.Node,
  sp : @wap.Span,
) -> @ast.Instr[@basic.Location] {
  let at = self.loc(sp)
  let ttyp = self.type_of(target)
  match target.it {
    Var(n) => {
      let bop : @basic.Annotated[@ast.BinOp, @basic.Location]? = match op {
        Set => None
        OpSet(o) => Some({ desc: self.wax_binop(o, ttyp, sp), info: at, })
      }
      @ast.build(
        Set(self.ident(n, target.span), bop, self.expr(value, ttyp)),
        at,
      )
    }
    Field(recv, name) => {
      let base = self.expr(recv, None)
      let rhs = match op {
        Set => self.expr(value, ttyp)
        OpSet(o) => {
          let old = self.widen(
            @ast.build(StructGet(base, self.ident(name, sp)), at),
            ttyp,
            sp,
          )
          @ast.build(
            BinOpI(
              { desc: self.wax_binop(o, ttyp, sp), info: at, },
              old,
              self.expr(value, ttyp),
            ),
            at,
          )
        }
      }
      @ast.build(
        StructSet(self.expr(recv, None), self.ident(name, sp), rhs),
        at,
      )
    }
    Index(a, i) => {
      let rhs = match op {
        Set => self.expr(value, ttyp)
        OpSet(o) => {
          let old = self.widen(
            @ast.build(ArrayGet(self.expr(a, None), self.expr(i, None)), at),
            ttyp,
            sp,
          )
          @ast.build(
            BinOpI(
              { desc: self.wax_binop(o, ttyp, sp), info: at, },
              old,
              self.expr(value, ttyp),
            ),
            at,
          )
        }
      }
      @ast.build(ArraySet(self.expr(a, None), self.expr(i, None), rhs), at)
    }
    _ => {
      self.error("this is not something that can be assigned to", target.span)
      @ast.build(Unreachable, at)
    }
  }
}

///|
/// A compound assignment's operator, with the target's signedness.
fn Lowering::wax_binop(
  self : Lowering,
  o : @wap.BinOp,
  t : @wap.Type?,
  sp : @wap.Span,
) -> @ast.BinOp {
  let sign = self.signage(t)
  match o {
    Add => Add
    Sub => Sub
    Mul => Mul
    Div => Div(sign)
    Rem =>
      match sign {
        Some(s) => Rem(s)
        None => {
          self.error("`%=` is an integer operator", sp)
          Rem(Signed)
        }
      }
    Shl => Shl
    Shr =>
      match sign {
        Some(s) => Shr(s)
        None => {
          self.error("`>>=` is an integer operator", sp)
          Shr(Signed)
        }
      }
    BitAnd => And
    BitOr => Or
    BitXor => Xor
    _ => {
      self.error("this operator has no compound form", sp)
      Add
    }
  }
}

// ---------------------------------------------------------------- if / match

///|
/// `if`, in all three of its shapes, as nested Wax conditionals.
fn Lowering::conditional(
  self : Lowering,
  arms : Array[(@wap.Node?, Array[@wap.Node])],
  typ : @wap.Type?,
  sp : @wap.Span,
) -> @ast.Instr[@basic.Location] {
  let at = self.loc(sp)
  let ftyp = match typ {
    Some(t) => ({ params: [], results: [self.valtype(t, sp)], } : @ast.FuncType)
    None => empty_type()
  }
  seq_of(self.conditional_from(arms, 0, ftyp, sp, at), at)
}

///|
/// An arm and everything after it, as the instructions it contributes.
///
/// The `else` arm's body is spliced into the else block rather than wrapped:
/// a `Sequence` is a value, and an arm whose body is an assignment does not
/// produce one.
fn Lowering::conditional_from(
  self : Lowering,
  arms : Array[(@wap.Node?, Array[@wap.Node])],
  i : Int,
  ftyp : @ast.FuncType,
  sp : @wap.Span,
  at : @basic.Location,
) -> Array[@ast.Instr[@basic.Location]] {
  if i >= arms.length() {
    return []
  }
  let (cond, body) = arms[i]
  match cond {
    None => self.body(body)
    Some(c) => {
      let rest = self.conditional_from(arms, i + 1, ftyp, sp, at)
      let else_block : @basic.Annotated[
        Array[@ast.Instr[@basic.Location]],
        @basic.Location,
      ]? = if rest.length() > 0 {
        Some({ desc: rest, info: at, })
      } else {
        None
      }
      [
        @ast.build(
          If(
            label=None,
            typ=ftyp,
            cond=self.expr(c, None),
            if_block={ desc: self.body(body), info: at, },
            else_block~,
          ),
          at,
        ),
      ]
    }
  }
}

///|
/// `match`, over types or over values.
///
/// Type patterns become Wax's `match`, which is a type switch. Value patterns
/// become a comparison chain: correct for every label set, and the printed
/// expansion says so.
fn Lowering::match_expr(
  self : Lowering,
  scrutinee : @wap.Node,
  arms : Array[@wap.Arm],
  typ : @wap.Type?,
  sp : @wap.Span,
) -> Array[@ast.Instr[@basic.Location]] {
  let mut type_match = false
  for a in arms {
    if a.pat is PType(..) || a.pat is PNull {
      type_match = true
    }
  }
  if type_match {
    [self.type_match(scrutinee, arms, typ, sp)]
  } else {
    self.value_match(scrutinee, arms, typ, sp)
  }
}

///|
fn Lowering::type_match(
  self : Lowering,
  scrutinee : @wap.Node,
  arms : Array[@wap.Arm],
  typ : @wap.Type?,
  sp : @wap.Span,
) -> @ast.Instr[@basic.Location] {
  let at = self.loc(sp)
  // Wax's `match` is a statement: every arm branches or returns, and the
  // construct itself leaves nothing behind. A wap `match` that stands for a
  // value therefore needs the block to branch out of, which is what the
  // corpus writes by hand as `do t { match ... }`.
  let mut yields = arms.length() > 0
  for a in arms {
    if a.body.length() == 0 || is_terminator(a.body[a.body.length() - 1]) {
      yields = false
    }
  }
  let result = if yields {
    match typ {
      Some(t) => Some(t)
      None => {
        let mut found = None
        for a in arms {
          if found is None {
            found = self.type_of_body(a.body)
          }
        }
        found
      }
    }
  } else {
    None
  }
  if yields && result is None {
    self.error(
      "cannot tell what type this `match` produces",
      sp,
      help="annotate it with `-> t`, or end every arm with `return`",
    )
  }
  let label = if result is Some(_) { Some(self.gensym("match")) } else { None }
  let out : Array[
    (
      @ast.MatchPattern,
      @basic.Annotated[Array[@ast.Instr[@basic.Location]], @basic.Location],
    ),
  ] = []
  let mut default : @basic.Annotated[
    Array[@ast.Instr[@basic.Location]],
    @basic.Location,
  ] = { desc: [@ast.build(Unreachable, at)], info: at, }
  for a in arms {
    match a.pat {
      PWild => {
        self.push_scope()
        default = {
          desc: self.arm_body(a.body, label, a.span),
          info: self.loc(a.span),
        }
        self.pop_scope()
      }
      PNull => {
        self.push_scope()
        out.push(
          (
            MatchNull,
            {
              desc: self.arm_body(a.body, label, a.span),
              info: self.loc(a.span),
            },
          ),
        )
        self.pop_scope()
      }
      PType(name~, typ~) => {
        let v = self.valtype(typ, a.span)
        let rt = match v {
          Ref(r) => r
          _ => {
            self.error("a `match` arm tests a reference type", a.span)
            ({ nullable: true, typ: Any, } : @wasm_types.RefType[@ast.Ident])
          }
        }
        self.push_scope()
        match name {
          Some(n) => self.bind(n, typ)
          None => ()
        }
        let body : @basic.Annotated[
          Array[@ast.Instr[@basic.Location]],
          @basic.Location,
        ] = {
          desc: self.arm_body(a.body, label, a.span),
          info: self.loc(a.span),
        }
        self.pop_scope()
        out.push(
          (
            MatchCast(
              match name {
                Some(n) => Some(self.ident(n, a.span))
                None => None
              },
              rt,
            ),
            body,
          ),
        )
      }
      _ => self.error("a type `match` cannot also match on values", a.span)
    }
  }
  let m = @ast.build(
    Match(scrutinee=self.expr(scrutinee, None), arms=out, default~),
    at,
  )
  match (label, result) {
    (Some(l), Some(t)) =>
      @ast.build(
        Block(
          label=Some(self.ident(l, sp)),
          typ={ params: [], results: [self.valtype(t, sp)], },
          block={ desc: [m], info: at, },
        ),
        at,
      )
    _ => m
  }
}

///|
/// An arm's body, ending in the branch that carries its value out.
fn Lowering::arm_body(
  self : Lowering,
  body : Array[@wap.Node],
  label : String?,
  sp : @wap.Span,
) -> Array[@ast.Instr[@basic.Location]] {
  match label {
    None => self.body(body)
    Some(l) => {
      let out = []
      for i, e in body {
        if i == body.length() - 1 {
          out.push(
            @ast.build(
              Br(self.ident(l, sp), Some(self.expr(e, None))),
              self.loc(sp),
            ),
          )
        } else {
          for x in self.stmts(e) {
            out.push(x)
          }
        }
      }
      out
    }
  }
}

///|
/// True when an expression leaves the block it is in, so nothing after it --
/// and nothing around it -- receives a value.
fn is_terminator(e : @wap.Node) -> Bool {
  match e.it {
    Return(_) | Break(_) | Continue(_) | Unreachable => true
    _ => false
  }
}

///|
fn Lowering::value_match(
  self : Lowering,
  scrutinee : @wap.Node,
  arms : Array[@wap.Arm],
  typ : @wap.Type?,
  sp : @wap.Span,
) -> Array[@ast.Instr[@basic.Location]] {
  let at = self.loc(sp)
  let stype = self.type_of(scrutinee)
  // The scrutinee is tested once per arm, so it is bound once.
  let tmp = self.gensym("m")
  match stype {
    Some(t) => self.bind(tmp, t)
    None => self.bind(tmp, I32)
  }
  let bind_instr = @ast.build(
    Let(
      [(Some({ name: tmp, loc: self.fresh_loc(), }), None)],
      Some(self.expr(scrutinee, None)),
    ),
    at,
  )
  let subject : @wap.Node = { it: Var(tmp), span: sp, }
  let chain : Array[(@wap.Node?, Array[@wap.Node])] = []
  for a in arms {
    match a.pat {
      PWild => chain.push((None, a.body))
      _ =>
        match self.pattern_test(subject, a.pat, stype, a.span) {
          Some(c) => chain.push((Some(c), a.body))
          None => ()
        }
    }
  }
  ignore(at)
  [bind_instr, self.conditional(chain, typ, sp)]
}

///|
/// The condition an arm's pattern stands for.
fn Lowering::pattern_test(
  self : Lowering,
  subject : @wap.Node,
  pat : @wap.Pattern,
  stype : @wap.Type?,
  sp : @wap.Span,
) -> @wap.Node? {
  ignore(stype)
  match pat {
    PInt(v) =>
      Some({ it: Bin(Eq, subject, { it: Int(v), span: sp, }), span: sp, })
    PRange(low~, high~) => {
      let lo : @wap.Node = {
        it: Bin(Ge, subject, { it: Int(low), span: sp, }),
        span: sp,
      }
      let hi : @wap.Node = {
        it: Bin(Le, subject, { it: Int(high), span: sp, }),
        span: sp,
      }
      Some({ it: AndAlso(lo, hi), span: sp, })
    }
    PSet(items) => {
      let mut acc : @wap.Node? = None
      for p in items {
        match self.pattern_test(subject, p, stype, sp) {
          Some(c) =>
            acc = Some(
              match acc {
                Some(a) => ({ it: OrElse(a, c), span: sp, } : @wap.Node)
                None => c
              },
            )
          None => ()
        }
      }
      acc
    }
    PWild => None
    _ => {
      self.error("this pattern cannot appear in a value `match`", sp)
      None
    }
  }
}
