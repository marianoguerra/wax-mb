// The forms whose head is a keyword.

///|
/// One of Wax's keyword forms, or nothing.
fn Reader::form(
  self : Reader,
  p : Parts,
) -> @ast.Instr[@basic.Location]? raise ReadError {
  let head = p.head
  if head.length() == 0 {
    return None
  }
  let kw = match as_id(head[0]) {
    Some(k) => k
    None => return None
  }
  let rest = head[1:].to_owned()
  let at = p.span
  match kw {
    "unreachable" => Some(self.instr(Unreachable, at))
    "nop" => Some(self.instr(Nop, at))
    "let" => Some(self.let_form(rest, p))
    "if" => Some(self.if_form(rest, p))
    "do" => Some(self.block_form(rest, p, false))
    "loop" => Some(self.block_form(rest, p, true))
    "while" => Some(self.while_form(rest, p))
    "match" => Some(self.match_form(rest, p))
    "dispatch" => Some(self.dispatch_form(rest, p))
    "try" => Some(self.try_form(rest, p))
    "return" =>
      Some(
        self.instr(
          Return(
            if rest.length() == 0 {
              None
            } else {
              Some(self.expr_all(rest))
            },
          ),
          at,
        ),
      )
    "become" => {
      let call = self.expr_all(rest)
      match call.desc {
        Call(f, args) => Some(self.instr(TailCall(f, args), at))
        _ => fail_at("`become` takes a call", at, source=self.src)
      }
    }
    "throw" => {
      let (name, args) = self.tag_call(rest, "throw")
      Some(self.instr(Throw(name, args), at))
    }
    "suspend" => {
      let (name, args) = self.tag_call(rest, "suspend")
      Some(self.instr(Suspend(name, args), at))
    }
    "throw_ref" => Some(self.instr(ThrowRef(self.expr_all(rest)), at))
    // Wax spells this `c ? a : b`, whose `:` would open a block here.
    "select" => {
      if rest.length() != 1 {
        fail_at(
          "`select` takes three parenthesised expressions",
          at,
          source=self.src,
        )
      }
      match rest[0].it {
        Parens(gs) =>
          if gs.length() == 3 {
            Some(
              self.instr(
                Select(self.group(gs[0]), self.group(gs[1]), self.group(gs[2])),
                at,
              ),
            )
          } else {
            fail_at(
              "`select` takes three expressions",
              node_span(rest[0]),
              source=self.src,
            )
          }
        _ =>
          fail_at(
            "`select` takes three parenthesised expressions",
            at,
            source=self.src,
          )
      }
    }
    "br" => {
      let (l, r) = self.label_and_rest(rest, "br")
      Some(
        self.instr(
          Br(l, if r.length() == 0 { None } else { Some(self.expr_all(r)) }),
          at,
        ),
      )
    }
    "br_if" => {
      let (l, r) = self.label_and_rest(rest, "br_if")
      Some(self.instr(BrIf(l, self.expr_all(r)), at))
    }
    "br_on_null" => {
      let (l, r) = self.label_and_rest(rest, "br_on_null")
      Some(self.instr(BrOnNull(l, self.expr_all(r)), at))
    }
    "br_on_non_null" => {
      let (l, r) = self.label_and_rest(rest, "br_on_non_null")
      Some(self.instr(BrOnNonNull(l, self.expr_all(r)), at))
    }
    "br_on_cast" | "br_on_cast_fail" => {
      let (l, r) = self.label_and_rest(rest, kw)
      let c = Cursor::new(r, self)
      let rt = c.reftype()
      let value = self.expr_from(c)
      Some(
        self.instr(
          if kw == "br_on_cast" {
            BrOnCast(l, rt, value)
          } else {
            BrOnCastFail(l, rt, value)
          },
          at,
        ),
      )
    }
    "br_table" => {
      if rest.length() == 0 {
        fail_at("`br_table` takes a label list", at, source=self.src)
      }
      let labels = match rest[0].it {
        Brackets(gs) => self.label_list(gs)
        _ =>
          fail_at(
            "expected a label list in brackets",
            node_span(rest[0]),
            source=self.src,
          )
      }
      Some(self.instr(BrTable(labels, self.expr_all(rest[1:].to_owned())), at))
    }
    _ => None
  }
}

///|
/// `let x :: t = e`, `let (q, r) = e`, `let x :: t`.
fn Reader::let_form(
  self : Reader,
  ts : Array[@sh.Node],
  p : Parts,
) -> @ast.Instr[@basic.Location] raise ReadError {
  let mut eq = -1
  for i, t in ts {
    if is_op(t, "=") {
      eq = i
      break
    }
  }
  let lhs = if eq < 0 { ts } else { ts[0:eq].to_owned() }
  let binders = self.binders(lhs)
  let value = if eq < 0 {
    None
  } else {
    Some(self.expr_all(ts[eq + 1:].to_owned()))
  }
  self.instr(Let(binders, value), p.span)
}

///|
/// The names a `let` binds, with their optional annotations.
fn Reader::binders(
  self : Reader,
  ts : Array[@sh.Node],
) -> Array[(@ast.Ident?, @wasm_types.ValType[@ast.Ident]?)] raise ReadError {
  if ts.length() == 1 && ts[0].it is Parens(gs) {
    let out = []
    for g in gs {
      for b in self.binders(children(g)) {
        out.push(b)
      }
    }
    return out
  }
  if ts.length() == 0 {
    fail_at("expected a name to bind", nowhere, source=self.src)
  }
  if is_id(ts[0], "_") && ts.length() == 1 {
    return [(None, None)]
  }
  let name = match as_id(ts[0]) {
    Some(s) => s
    None => fail_at("expected a name", node_span(ts[0]), source=self.src)
  }
  if ts.length() == 1 {
    return [(Some(self.ident(name, node_span(ts[0]))), None)]
  }
  if !is_op(ts[1], "::") {
    fail_at("expected `::` and a type", node_span(ts[1]), source=self.src)
  }
  let typ = Cursor::new(ts[2:].to_owned(), self).valtype()
  [(Some(self.ident(name, node_span(ts[0]))), Some(typ))]
}

///|
/// `if ~l c -> t: ... | else`, and `if c | then | else`.
fn Reader::if_form(
  self : Reader,
  ts : Array[@sh.Node],
  p : Parts,
) -> @ast.Instr[@basic.Location] raise ReadError {
  let (label, ts) = label_of(ts)
  let c = Cursor::new(ts, self)
  let cond = self.expr_from_bp(c, 0)
  let typ = self.block_type(c)
  let (if_block, else_block) = match (p.block, p.alts) {
    (Some(gs), None) => (self.body(gs), None)
    (Some(gs), Some(alts)) => {
      if alts.length() != 1 {
        fail_at(
          "an `if` with a `:` body takes one alternative, the else",
          p.span,
          source=self.src,
        )
      }
      (self.body(gs), Some(self.body(alts[0])))
    }
    (None, Some(alts)) => {
      if alts.length() < 1 || alts.length() > 2 {
        fail_at(
          "`if c | then | else` takes one or two alternatives",
          p.span,
          source=self.src,
        )
      }
      (
        self.body(alts[0]),
        if alts.length() == 2 {
          Some(self.body(alts[1]))
        } else {
          None
        },
      )
    }
    (None, None) =>
      fail_at(
        "expected `:` or `|` after the condition",
        p.span,
        source=self.src,
      )
  }
  self.instr(
    If(
      label=self.opt_ident(label, p.span),
      typ~,
      cond~,
      if_block=self.blk(if_block, p.span),
      else_block=match else_block {
        Some(b) => Some(self.blk(b, p.span))
        None => None
      },
    ),
    p.span,
  )
}

///|
/// `do ~l -> t:` and `loop ~l -> t:`.
fn Reader::block_form(
  self : Reader,
  ts : Array[@sh.Node],
  p : Parts,
  looping : Bool,
) -> @ast.Instr[@basic.Location] raise ReadError {
  let (label, ts) = label_of(ts)
  let c = Cursor::new(ts, self)
  let typ = self.block_type(c)
  if !c.done() {
    fail_at("expected `:` after the block's type", c.here(), source=self.src)
  }
  let body = self.need_block(p, if looping { "loop" } else { "do" })
  let lbl = self.opt_ident(label, p.span)
  let block = self.blk(body, p.span)
  self.instr(
    if looping {
      Loop(label=lbl, typ~, block~)
    } else {
      Block(label=lbl, typ~, block~)
    },
    p.span,
  )
}

///|
/// `while ~l c ~step(s):`
fn Reader::while_form(
  self : Reader,
  ts : Array[@sh.Node],
  p : Parts,
) -> @ast.Instr[@basic.Location] raise ReadError {
  let (label, ts) = label_of(ts)
  let mut end = ts.length()
  let mut step = None
  for j, t in ts {
    if as_kw(t) is Some("step") {
      end = j
      if j + 1 < ts.length() && ts[j + 1].it is Parens(gs) && gs.length() == 1 {
        step = Some(self.group(gs[0]))
      } else {
        fail_at(
          "`~step` takes one parenthesised expression",
          node_span(t),
          source=self.src,
        )
      }
      break
    }
  }
  let cond = self.expr_all(ts[0:end].to_owned())
  let body = self.need_block(p, "while")
  self.instr(
    While(
      label=self.opt_ident(label, p.span),
      cond~,
      step~,
      block=self.blk(body, p.span),
    ),
    p.span,
  )
}

///|
/// `match e | p :: &t: ... | null: ... | _: ...`
fn Reader::match_form(
  self : Reader,
  ts : Array[@sh.Node],
  p : Parts,
) -> @ast.Instr[@basic.Location] raise ReadError {
  let scrutinee = self.expr_all(ts)
  let arms : Array[
    (
      @ast.MatchPattern,
      @basic.Annotated[Array[@ast.Instr[@basic.Location]], @basic.Location],
    ),
  ] = []
  let mut default = self.blk([self.instr(Unreachable, p.span)], p.span)
  match p.alts {
    None => fail_at("`match` needs `|` arms", p.span, source=self.src)
    Some(alts) =>
      for alt in alts {
        if alt.length() != 1 {
          fail_at(
            "each `match` arm is one `pattern: body`",
            terms_span(alt[:]),
            source=self.src,
          )
        }
        let ap = split(alt[0])
        let body = self.blk(self.need_block(ap, "this pattern"), ap.span)
        let head = ap.head
        if head.length() == 1 && is_id(head[0], "_") {
          default = body
        } else if head.length() == 1 && is_id(head[0], "null") {
          arms.push((MatchNull, body))
        } else {
          let mut name = None
          let mut rest = head
          if head.length() >= 3 &&
            as_id(head[0]) is Some(n) &&
            is_op(head[1], "::") {
            name = Some(self.ident(n, node_span(head[0])))
            rest = head[2:].to_owned()
          }
          let rt = Cursor::new(rest, self).reftype()
          arms.push((MatchCast(name, rt), body))
        }
      }
  }
  self.instr(Match(scrutinee~, arms~, default~), p.span)
}

///|
/// `dispatch e [~a, ~b, else ~d] | ~a: ... | ~b: ...`
fn Reader::dispatch_form(
  self : Reader,
  ts : Array[@sh.Node],
  p : Parts,
) -> @ast.Instr[@basic.Location] raise ReadError {
  if ts.length() == 0 {
    fail_at(
      "`dispatch` takes an index and a label list",
      p.span,
      source=self.src,
    )
  }
  // The label list is the last bracketed term of the head.
  let mut table = -1
  for i, t in ts {
    if t.it is Brackets(_) {
      table = i
    }
  }
  if table < 0 {
    fail_at("expected a label list in brackets", p.span, source=self.src)
  }
  let index = self.expr_all(ts[0:table].to_owned())
  let (cases, default) = match ts[table].it {
    Brackets(gs) => self.dispatch_labels(gs, p.span)
    _ => fail_at("expected a label list", node_span(ts[table]), source=self.src)
  }
  let arms : Array[
    (
      @ast.Ident,
      @basic.Annotated[Array[@ast.Instr[@basic.Location]], @basic.Location],
    ),
  ] = []
  match p.alts {
    None => fail_at("`dispatch` needs `|` arms", p.span, source=self.src)
    Some(alts) =>
      for alt in alts {
        if alt.length() != 1 {
          fail_at(
            "each `dispatch` arm is one `~label: body`",
            terms_span(alt[:]),
            source=self.src,
          )
        }
        let ap = split(alt[0])
        let body = self.blk(self.need_block(ap, "this label"), ap.span)
        if ap.head.length() != 1 || as_kw(ap.head[0]) is None {
          fail_at("expected a `~label`", ap.span, source=self.src)
        }
        arms.push((self.ident(as_kw(ap.head[0]).unwrap(), ap.span), body))
      }
  }
  self.instr(Dispatch(index~, cases~, default~, arms~), p.span)
}

///|
fn Reader::dispatch_labels(
  self : Reader,
  gs : Array[@sh.Node],
  at : Span,
) -> (Array[@ast.Ident], @ast.Ident) raise ReadError {
  let cases = []
  let mut default = None
  for g in gs {
    let ts = children(g)
    if ts.length() == 2 && is_id(ts[0], "else") && as_kw(ts[1]) is Some(k) {
      default = Some(self.ident(k, node_span(ts[1])))
    } else if ts.length() == 1 && as_kw(ts[0]) is Some(k) {
      cases.push(self.ident(k, node_span(ts[0])))
    } else {
      fail_at(
        "expected `~label` or `else ~label`",
        terms_span(ts[:]),
        source=self.src,
      )
    }
  }
  match default {
    Some(d) => (cases, d)
    None => fail_at("a label list needs an `else ~label`", at, source=self.src)
  }
}

///|
/// `try ~l -> t: ... | tag(binders): ...` and `try on [tag -> ~h] -> t: ...`
fn Reader::try_form(
  self : Reader,
  ts : Array[@sh.Node],
  p : Parts,
) -> @ast.Instr[@basic.Location] raise ReadError {
  let (label, ts) = label_of(ts)
  let lbl = self.opt_ident(label, p.span)
  // The branch-to-label form: `try on [tag -> ~h]:`
  if ts.length() >= 2 && is_id(ts[0], "on") && ts[1].it is Brackets(gs) {
    let catches = self.catch_list(gs)
    let c = Cursor::new(ts[2:].to_owned(), self)
    let typ = self.block_type(c)
    let body = self.need_block(p, "try")
    return self.instr(
      TryTable(label=lbl, typ~, catches~, block=self.blk(body, p.span)),
      p.span,
    )
  }
  let c = Cursor::new(ts, self)
  let typ = self.block_type(c)
  let body = self.blk(self.need_block(p, "try"), p.span)
  let arms : Array[@ast.TryCatchArm[@basic.Location]] = []
  match p.alts {
    None => fail_at("`try` needs `|` catch arms", p.span, source=self.src)
    Some(alts) =>
      for alt in alts {
        if alt.length() != 1 {
          fail_at(
            "each catch arm is one `tag: body`",
            terms_span(alt[:]),
            source=self.src,
          )
        }
        let ap = split(alt[0])
        let arm_body = self.blk(self.need_block(ap, "this catch"), ap.span)
        let head = ap.head
        if head.length() == 1 && is_id(head[0], "_") {
          arms.push({ arm_tag: None, arm_ref: false, arm_types: [], arm_body, })
        } else {
          let name = match as_id(head[0]) {
            Some(n) => n
            None => fail_at("expected a tag name", ap.span, source=self.src)
          }
          let arm_types = if head.length() > 1 && head[1].it is Parens(gs) {
            let out = []
            for g in gs {
              out.push(Cursor::new(children(g), self).valtype())
            }
            out
          } else {
            []
          }
          arms.push({
            arm_tag: Some(self.ident(name, node_span(head[0]))),
            arm_ref: false,
            arm_types,
            arm_body,
          })
        }
      }
  }
  self.instr(TryCatch(label=lbl, typ~, block=body, arms~), p.span)
}

///|
/// `[tag -> ~h, _ -> ~a]`, the catches of a `try_table`.
fn Reader::catch_list(
  self : Reader,
  gs : Array[@sh.Node],
) -> Array[@ast.Catch] raise ReadError {
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
    if arrow < 0 || arrow + 1 >= ts.length() {
      fail_at("expected `tag -> ~label`", terms_span(ts[:]), source=self.src)
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
    let lhs = ts[0:arrow].to_owned()
    let by_ref = lhs.length() > 0 && is_op(lhs[lhs.length() - 1], "!")
    let names = if by_ref { lhs[0:lhs.length() - 1].to_owned() } else { lhs }
    if names.length() == 1 && is_id(names[0], "_") {
      out.push(
        if by_ref {
          @ast.Catch::CatchAllRef(label)
        } else {
          CatchAll(label)
        },
      )
    } else if names.length() == 1 && as_id(names[0]) is Some(n) {
      let tag = self.ident(n, node_span(names[0]))
      out.push(
        if by_ref {
          @ast.Catch::CatchRef(tag, label)
        } else {
          Catch(tag, label)
        },
      )
    } else {
      fail_at(
        "expected a tag name or `_`",
        terms_span(names[:]),
        source=self.src,
      )
    }
  }
  out
}

///|
/// `[~a, ~b]`, a plain list of labels.
fn Reader::label_list(
  self : Reader,
  gs : Array[@sh.Node],
) -> Array[@ast.Ident] raise ReadError {
  let out = []
  for g in gs {
    let ts = children(g)
    if ts.length() == 1 && as_kw(ts[0]) is Some(k) {
      out.push(self.ident(k, node_span(ts[0])))
    } else {
      fail_at("expected a `~label`", terms_span(ts[:]), source=self.src)
    }
  }
  out
}

///|
/// `tag(a, b)` after `throw` or `suspend`.
fn Reader::tag_call(
  self : Reader,
  ts : Array[@sh.Node],
  what : String,
) -> (@ast.Ident, Array[@ast.Instr[@basic.Location]]) raise ReadError {
  if ts.length() == 0 || as_id(ts[0]) is None {
    fail_at(
      "`" + what + "` takes a tag name",
      terms_span(ts[:]),
      source=self.src,
    )
  }
  let name = self.ident(as_id(ts[0]).unwrap(), node_span(ts[0]))
  let args = if ts.length() > 1 && ts[1].it is Parens(gs) {
    let out = []
    for g in gs {
      out.push(self.group(g))
    }
    out
  } else {
    []
  }
  (name, args)
}

///|
/// A leading `~label` that a branch requires.
fn Reader::label_and_rest(
  self : Reader,
  ts : Array[@sh.Node],
  what : String,
) -> (@ast.Ident, Array[@sh.Node]) raise ReadError {
  if ts.length() == 0 || as_kw(ts[0]) is None {
    fail_at(
      "`" + what + "` takes a `~label`",
      terms_span(ts[:]),
      source=self.src,
    )
  }
  (self.ident(as_kw(ts[0]).unwrap(), node_span(ts[0])), ts[1:].to_owned())
}

///|
fn Reader::opt_ident(self : Reader, name : String?, span : Span) -> @ast.Ident? {
  match name {
    Some(n) => Some(self.ident(n, span))
    None => None
  }
}

///|
/// An optional `-> t` on a block-shaped form. An absent one is the empty
/// function type, which Wax reads as "no annotation, infer".
fn Reader::block_type(
  self : Reader,
  c : Cursor,
) -> @ast.FuncType raise ReadError {
  ignore(self)
  { params: [], results: c.results(), }
}
