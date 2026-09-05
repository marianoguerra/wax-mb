// Expressions: precedence climbing over a group's terms.

///|
/// An expression that must consume every term it was given.
fn Reader::expr_all(
  self : Reader,
  ts : Array[@sh.Node],
) -> @ast.Instr[@basic.Location] raise ReadError {
  let c = Cursor::new(ts, self)
  let e = self.expr_from_bp(c, 0)
  if !c.done() {
    fail_at(
      "this is not part of the expression before it",
      node_span(c.ts[c.i]),
      source=self.src,
    )
  }
  e
}

///|
/// An expression starting where the cursor is.
fn Reader::expr_from(
  self : Reader,
  c : Cursor,
) -> @ast.Instr[@basic.Location] raise ReadError {
  self.expr_from_bp(c, 0)
}

///|
/// An assignment, or an expression.
fn Reader::assign_or_expr(
  self : Reader,
  ts : Array[@sh.Node],
  span : Span,
) -> @ast.Instr[@basic.Location] raise ReadError {
  let mut at = -1
  let mut op = ""
  for i, t in ts {
    match as_op(t) {
      Some(s) =>
        if s == "=" || s == ":=" || assign_binop(s) is Some(_) {
          at = i
          op = s
          break
        }
      None => ()
    }
  }
  if at < 0 {
    return self.expr_all(ts)
  }
  let lhs = ts[0:at].to_owned()
  let rhs = ts[at + 1:].to_owned()
  if rhs.length() == 0 {
    fail_at(
      "expected an expression on the right of the assignment",
      span,
      source=self.src,
    )
  }
  let value = self.expr_all(rhs)
  // `x := e` yields the value; every other form does not.
  if op == ":=" {
    let name = match (lhs.length() == 1, as_id(lhs[0])) {
      (true, Some(n)) => self.ident(n, node_span(lhs[0]))
      _ =>
        fail_at("`:=` assigns to a local", terms_span(lhs[:]), source=self.src)
    }
    return self.instr(Tee(name, value), span)
  }
  let folded : @basic.Annotated[@ast.BinOp, @basic.Location]? = match
    assign_binop(op) {
    Some(b) => Some({ desc: b, info: self.loc(span), })
    None => None
  }
  // A bare name is a local; anything else is a field or an element.
  if lhs.length() == 1 && as_id(lhs[0]) is Some(n) {
    return self.instr(
      Set(self.ident(n, node_span(lhs[0])), folded, value),
      span,
    )
  }
  let target = self.expr_all(lhs)
  match target.desc {
    StructGet(recv, field) =>
      self.instr(
        StructSet(recv, field, self.fold(folded, target, value, span)),
        span,
      )
    ArrayGet(arr, index) =>
      self.instr(
        ArraySet(arr, index, self.fold(folded, target, value, span)),
        span,
      )
    _ =>
      fail_at(
        "this is not something that can be assigned to",
        span,
        source=self.src,
      )
  }
}

///|
/// `p.x += e` is `p.x = p.x + e`; Wax has no compound form for a field, so the
/// receiver is evaluated twice, exactly as it is written.
fn Reader::fold(
  self : Reader,
  op : @basic.Annotated[@ast.BinOp, @basic.Location]?,
  old : @ast.Instr[@basic.Location],
  value : @ast.Instr[@basic.Location],
  span : Span,
) -> @ast.Instr[@basic.Location] {
  match op {
    None => value
    Some(o) => self.instr(BinOpI(o, old, value), span)
  }
}

///|
fn Reader::expr_from_bp(
  self : Reader,
  c : Cursor,
  min_bp : Int,
) -> @ast.Instr[@basic.Location] raise ReadError {
  let mut lhs = self.unary(c)
  let mut compared = false
  while c.peek() is Some(t) {
    let name = match infix_name(t) {
      Some(s) => s
      None => break
    }
    let (lbp, rbp) = match infix_bp(name) {
      Some(bp) => bp
      None => break
    }
    if lbp < min_bp {
      break
    }
    c.i += 1
    let span = node_span(t)
    match name {
      "as" =>
        // `as ?descriptor(d)` is a different instruction, not a different
        // cast type, so it is peeled off before the type is read.
        match self.desc_cast(c) {
          Some((nullable, d)) =>
            lhs = self.instr(CastDesc(lhs, nullable, d), span)
          None => lhs = self.instr(Cast(lhs, self.cast_type(c)), span)
        }
      "is" => lhs = self.instr(Test(lhs, c.reftype()), span)
      "on" => {
        let clauses = match c.next() {
          Some(n) =>
            match n.it {
              Brackets(gs) => self.on_clauses(gs)
              _ =>
                fail_at(
                  "`on` takes a bracketed handler list",
                  node_span(n),
                  source=self.src,
                )
            }
          None =>
            fail_at(
              "`on` takes a bracketed handler list",
              span,
              source=self.src,
            )
        }
        lhs = self.instr(On(lhs, clauses), span)
      }
      _ => {
        // Wax rejects `a < b < c`; the level is non-associative there and the
        // rejection is reproduced here rather than silently re-associated.
        if lbp == 3 {
          if compared {
            fail_at(
              "comparisons do not chain",
              span,
              source=self.src,
              help="parenthesise one of them",
            )
          }
          compared = true
        }
        let rhs = self.expr_from_bp(c, rbp)
        match binop_of(name) {
          Some(op) =>
            lhs = self.instr(
              BinOpI({ desc: op, info: self.loc(span), }, lhs, rhs),
              span,
            )
          None =>
            fail_at("`" + name + "` is not an operator", span, source=self.src)
        }
      }
    }
  }
  lhs
}

///|
/// The `on [tag -> ~l, switch]` clauses of a resume.
fn Reader::on_clauses(
  self : Reader,
  gs : Array[@sh.Node],
) -> Array[@ast.OnClause] raise ReadError {
  let out = []
  for g in gs {
    let ts = children(g)
    let mut arrow = -1
    for i, t in ts {
      if is_op(t, "->") {
        arrow = i
        break
      }
    }
    if arrow < 0 {
      if ts.length() == 1 && as_id(ts[0]) is Some(n) {
        out.push(@ast.OnClause::OnSwitch(self.ident(n, node_span(ts[0]))))
        continue
      }
      fail_at("expected `tag -> ~label`", terms_span(ts[:]), source=self.src)
    }
    let tag = match as_id(ts[0]) {
      Some(n) => self.ident(n, node_span(ts[0]))
      None => fail_at("expected a tag name", terms_span(ts[:]), source=self.src)
    }
    let label = match as_kw(ts[arrow + 1]) {
      Some(k) => self.ident(k, node_span(ts[arrow + 1]))
      None =>
        fail_at(
          "expected a `~label`",
          node_span(ts[arrow + 1]),
          source=self.src,
        )
    }
    out.push(@ast.OnClause::OnLabel(tag, label))
  }
  out
}

///|
/// What `as` casts to.
fn Reader::cast_type(
  self : Reader,
  c : Cursor,
) -> @ast.CastType raise ReadError {
  let here = c.here()
  match c.peek() {
    None => fail_at("expected a type after `as`", here, source=self.src)
    Some(n) => {
      // `as i32_u` -- widening, where the signedness is not in the type.
      match as_id(n) {
        Some(name) =>
          match signed_cast(name) {
            Some((typ, signage)) => {
              c.i += 1
              return Signed(typ~, signage~, strict=false)
            }
            None => ()
          }
        None => ()
      }
      Value(c.valtype())
    }
  }
}

///|
/// `as ?descriptor(d)` / `as descriptor(d)`, if that is what follows.
fn Reader::desc_cast(
  self : Reader,
  c : Cursor,
) -> (Bool, @ast.Instr[@basic.Location])? raise ReadError {
  let save = c.i
  let nullable = c.eat_op("?")
  if !(c.peek() is Some(d) && is_id(d, "descriptor")) {
    c.i = save
    return None
  }
  c.i += 1
  let here = c.here()
  let arg = match c.next() {
    Some(a) =>
      match a.it {
        Parens(gs) =>
          if gs.length() == 1 {
            self.group(gs[0])
          } else {
            fail_at(
              "`descriptor` takes one expression",
              node_span(a),
              source=self.src,
            )
          }
        _ =>
          fail_at(
            "`descriptor` takes one expression",
            node_span(a),
            source=self.src,
          )
      }
    None => fail_at("`descriptor` takes one expression", here, source=self.src)
  }
  Some((nullable, arg))
}

///|
/// The Wax `as i32_u` family.
fn signed_cast(name : String) -> (@ast.NumType, @wasm_types.Signage)? {
  match name {
    "i32_s" => Some((I32, Signed))
    "i32_u" => Some((I32, Unsigned))
    "i64_s" => Some((I64, Signed))
    "i64_u" => Some((I64, Unsigned))
    _ => None
  }
}

///|
fn Reader::unary(
  self : Reader,
  c : Cursor,
) -> @ast.Instr[@basic.Location] raise ReadError {
  match c.peek() {
    Some(t) =>
      if is_op(t, "-") {
        c.i += 1
        let e = self.unary(c)
        return self.instr(
          UnOpI({ desc: Neg, info: self.loc(node_span(t)), }, e),
          node_span(t),
        )
      } else if is_op(t, "+") {
        c.i += 1
        let e = self.unary(c)
        return self.instr(
          UnOpI({ desc: Pos, info: self.loc(node_span(t)), }, e),
          node_span(t),
        )
      } else if is_op(t, "!") {
        c.i += 1
        let e = self.unary(c)
        return self.instr(
          UnOpI({ desc: Not, info: self.loc(node_span(t)), }, e),
          node_span(t),
        )
      }
    None => ()
  }
  self.postfix(c)
}

///|
fn Reader::postfix(
  self : Reader,
  c : Cursor,
) -> @ast.Instr[@basic.Location] raise ReadError {
  let mut e = self.primary(c)
  while c.peek() is Some(t) {
    let sp = node_span(t)
    match t.it {
      Parens(gs) => {
        c.i += 1
        let args = []
        for g in gs {
          args.push(self.arg(g))
        }
        e = self.instr(Call(e, args), sp)
      }
      Brackets(gs) => {
        c.i += 1
        e = self.bracketed(e, gs, sp)
      }
      Braces(gs) => {
        c.i += 1
        e = self.braced(Some(e), gs, sp)
      }
      Op(".") => {
        c.i += 1
        match c.next() {
          Some(f) =>
            match as_id(f) {
              Some("descriptor") => e = self.instr(GetDescriptor(e), sp)
              Some(name) =>
                e = self.instr(StructGet(e, self.ident(name, node_span(f))), sp)
              None =>
                fail_at(
                  "expected a field name after `.`",
                  node_span(f),
                  source=self.src,
                )
            }
          None =>
            fail_at("expected a field name after `.`", sp, source=self.src)
        }
      }
      Op("!") => {
        c.i += 1
        e = self.instr(NonNull(e), sp)
      }
      Op("!.") => {
        c.i += 1
        let nn = self.instr(NonNull(e), sp)
        match c.next() {
          Some(f) =>
            match as_id(f) {
              Some(name) =>
                e = self.instr(
                  StructGet(nn, self.ident(name, node_span(f))),
                  sp,
                )
              None =>
                fail_at(
                  "expected a field name after `!.`",
                  node_span(f),
                  source=self.src,
                )
            }
          None =>
            fail_at("expected a field name after `!.`", sp, source=self.src)
        }
      }
      _ => break
    }
  }
  e
}

///|
/// One argument, which may be labelled: `m.load32(p, align: 2)`.
fn Reader::arg(
  self : Reader,
  g : @sh.Node,
) -> @ast.Instr[@basic.Location] raise ReadError {
  let p = split(g)
  if p.head.length() == 1 &&
    as_id(p.head[0]) is Some(name) &&
    p.block is Some(bs) {
    if bs.length() != 1 {
      fail_at("a labelled argument takes one value", p.span, source=self.src)
    }
    return self.instr(
      Labelled(self.ident(name, node_span(p.head[0])), self.group(bs[0])),
      p.span,
    )
  }
  self.group(g)
}
