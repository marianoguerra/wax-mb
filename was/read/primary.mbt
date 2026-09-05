// Primary expressions, and the bracket and brace forms.

///|
fn Reader::primary(
  self : Reader,
  c : Cursor,
) -> @ast.Instr[@basic.Location] raise ReadError {
  let here = c.here()
  let t = match c.next() {
    Some(t) => t
    None => fail_at("expected an expression", here, source=self.src)
  }
  let sp = node_span(t)
  match t.it {
    Lit(d) =>
      match d {
        Int_(_) => self.instr(Int(raw_text(t)), sp)
        Flo(_) => self.instr(Float(raw_text(t)), sp)
        Str(s) => self.instr(Str(None, @utf8.encode(s)), sp)
        Bool_(b) => self.instr(Int(if b { "1" } else { "0" }), sp)
        Ch(ch) => self.instr(Char(ch), sp)
        _ => fail_at("this literal has no Wax meaning", sp, source=self.src)
      }
    Id("null") => self.instr(Null, sp)
    Id("_") => self.instr(Hole, sp)
    Id("inf") | Id("nan") => self.instr(Float(raw_text(t)), sp)
    Id("char") =>
      // `char"A"` -- two terms, because shrubbery's `'` is a bracket pair.
      match c.peek() {
        Some(s) =>
          match as_str(s) {
            Some(text) => {
              c.i += 1
              if text.length() == 0 {
                fail_at("an empty character literal", sp, source=self.src)
              }
              self.instr(Char(text.get_char(0).unwrap()), sp)
            }
            None => self.instr(Get(self.ident("char", sp)), sp)
          }
        None => self.instr(Get(self.ident("char", sp)), sp)
      }
    Id(name) => {
      // `ns::name` -- a qualified intrinsic. `::` is the annotation operator
      // in binder position and this everywhere else, which is unambiguous
      // because a binder is never an expression.
      if c.peek() is Some(n) && is_op(n, "::") {
        c.i += 1
        match c.next() {
          Some(m) =>
            match as_id(m) {
              Some(sel) =>
                return self.instr(
                  Path(self.ident(name, sp), self.ident(sel, node_span(m))),
                  sp,
                )
              None =>
                fail_at(
                  "expected a name after `::`",
                  node_span(m),
                  source=self.src,
                )
            }
          None => fail_at("expected a name after `::`", sp, source=self.src)
        }
      }
      // `bytes"text"` -- a string with the array type it builds.
      if self.type_names.contains(name) &&
        c.peek() is Some(s) &&
        as_str(s) is Some(text) {
        c.i += 1
        return self.instr(
          Str(Some(self.ident(name, sp)), @utf8.encode(text)),
          sp,
        )
      }
      self.instr(Get(self.ident(name, sp)), sp)
    }
    Parens(gs) => {
      if gs.length() == 1 {
        return self.group(gs[0])
      }
      // `(a, b)` -- several values, which is what a multi-value result is.
      let out = []
      for g in gs {
        out.push(self.group(g))
      }
      self.instr(Sequence(out), sp)
    }
    Brackets(gs) => self.bracket_literal(None, gs, sp)
    Braces(gs) => self.braced(None, gs, sp)
    _ => fail_at("expected an expression", sp, source=self.src)
  }
}

///|
/// `t[...]` after a name: an array literal when the name is a type, an index
/// when it is a value.
fn Reader::bracketed(
  self : Reader,
  e : @ast.Instr[@basic.Location],
  gs : Array[@sh.Node],
  sp : Span,
) -> @ast.Instr[@basic.Location] raise ReadError {
  match e.desc {
    Get(name) if self.type_names.contains(name.name) =>
      self.bracket_literal(Some(name), gs, sp)
    _ => {
      if gs.length() != 1 {
        fail_at("an index takes one expression", sp, source=self.src)
      }
      self.instr(ArrayGet(e, self.group(gs[0])), sp)
    }
  }
}

///|
/// The four array forms, with the type already peeled off.
///
/// Wax writes these `[t| a, b]`, `[t| v; n]`, `[t| ..; n]` and
/// `[t| d @ off; n]`. The type moves outside the brackets because `|` is the
/// alternatives marker, and `;` becomes `**` and `@` becomes `at` for the same
/// kind of reason.
fn Reader::bracket_literal(
  self : Reader,
  name : @ast.Ident?,
  gs : Array[@sh.Node],
  sp : Span,
) -> @ast.Instr[@basic.Location] raise ReadError {
  if gs.length() == 1 {
    let ts = children(gs[0])
    let mut star = -1
    for i, t in ts {
      if is_op(t, "**") {
        star = i
        break
      }
    }
    if star >= 0 {
      let lhs = ts[0:star].to_owned()
      let count = self.expr_all(ts[star + 1:].to_owned())
      // `t[.. ** n]` -- every element default.
      if lhs.length() == 1 && is_op(lhs[0], "..") {
        return self.instr(ArrayDefault(name, count), sp)
      }
      // `t[d at off ** n]` -- from a data segment.
      let mut at_pos = -1
      for i, t in lhs {
        if is_id(t, "at") {
          at_pos = i
          break
        }
      }
      if at_pos >= 0 {
        let seg = match (at_pos == 1, as_id(lhs[0])) {
          (true, Some(d)) => self.ident(d, node_span(lhs[0]))
          _ =>
            fail_at(
              "expected a data segment name before `at`",
              terms_span(lhs[:]),
              source=self.src,
            )
        }
        let off = self.expr_all(lhs[at_pos + 1:].to_owned())
        return self.instr(ArraySegment(name, seg, off, count), sp)
      }
      return self.instr(Array(name, self.expr_all(lhs), count), sp)
    }
  }
  let elems = []
  for g in gs {
    elems.push(self.group(g))
  }
  self.instr(ArrayFixed(name, elems), sp)
}

///|
/// `{...}` -- a struct literal, a default, or either of them with a
/// descriptor.
fn Reader::braced(
  self : Reader,
  prefix : @ast.Instr[@basic.Location]?,
  gs : Array[@sh.Node],
  sp : Span,
) -> @ast.Instr[@basic.Location] raise ReadError {
  // `descriptor(d){...}` builds with an explicit descriptor; `t{...}` and
  // `{...}` build by type name and by inference.
  let (name, desc) = match prefix {
    None => (None, None)
    Some(e) =>
      match e.desc {
        Get(n) => (Some(n), None)
        // `descriptor(d){...}` -- the descriptor is `d`, not the call that
        // spells it. Wax writes this `{ descriptor(d)| ... }`.
        Call(f, args) if f.desc is Get({ name: "descriptor", .. }) &&
          args.length() == 1 => (None, Some(args[0]))
        _ => (None, Some(e))
      }
  }
  let is_default = gs.length() == 1 &&
    children(gs[0]).length() == 1 &&
    is_op(children(gs[0])[0], "..")
  if is_default {
    return match desc {
      Some(d) => self.instr(StructDefaultDesc(d), sp)
      None => self.instr(StructDefault(name), sp)
    }
  }
  let fields : Array[(@ast.Ident, @ast.Instr[@basic.Location]?)] = []
  for g in gs {
    let p = split(g)
    let fname = match (p.head.length() == 1, as_id(p.head[0])) {
      (true, Some(n)) => self.ident(n, node_span(p.head[0]))
      _ => fail_at("expected a field name", p.span, source=self.src)
    }
    let value = match p.block {
      Some(bs) =>
        if bs.length() == 1 {
          Some(self.group(bs[0]))
        } else {
          fail_at("a field takes one value", p.span, source=self.src)
        }
      // `{x, y}` -- the punned form, which Wax has too.
      None => None
    }
    fields.push((fname, value))
  }
  match desc {
    Some(d) => self.instr(StructDesc(d, fields), sp)
    None => self.instr(Struct(name, fields), sp)
  }
}
