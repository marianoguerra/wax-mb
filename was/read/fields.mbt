// The individual module fields.

///|
/// `type NAME = ...` and `type NAME :: PARENT = ...`
fn Reader::type_entry(
  self : Reader,
  head : Array[@sh.Node],
  p : Parts,
) -> @basic.Annotated[(@ast.Ident, @ast.SubType), @basic.Location] raise ReadError {
  let at = self.loc(p.span)
  let ts = head[1:].to_owned()
  let name = match
    (ts.length() > 0, if ts.length() > 0 { as_id(ts[0]) } else { None }) {
    (true, Some(n)) => self.ident(n, node_span(ts[0]))
    _ => fail_at("expected a name after `type`", p.span, source=self.src)
  }
  let mut i = 1
  let mut supertype = None
  if i < ts.length() && is_op(ts[i], "::") {
    match
      (
        i + 1 < ts.length(),
        if i + 1 < ts.length() {
          as_id(ts[i + 1])
        } else {
          None
        },
      ) {
      (true, Some(sn)) => {
        supertype = Some(self.ident(sn, node_span(ts[i + 1])))
        i += 2
      }
      _ =>
        fail_at(
          "expected the supertype's name after `::`",
          p.span,
          source=self.src,
        )
    }
  }
  if !(i < ts.length() && is_op(ts[i], "=")) {
    fail_at("expected `=` in a type declaration", p.span, source=self.src)
  }
  let rhs = ts[i + 1:].to_owned()
  // The body may be on the next line, as a block.
  let rhs = match (rhs.length() == 0, p.block) {
    (true, Some(gs)) =>
      if gs.length() == 1 {
        children(gs[0])
      } else {
        fail_at("a type's body is one group", p.span, source=self.src)
      }
    _ => rhs
  }
  let c = Cursor::new(rhs, self)
  let final_ = !c.eat_id("open")
  let mut descriptor = None
  let mut describes = None
  if c.eat_id("descriptor") {
    descriptor = Some(self.take_name(c, "descriptor"))
  } else if c.eat_id("describes") {
    describes = Some(self.take_name(c, "describes"))
  }
  let typ = self.comptype(c, p)
  {
    desc: (name, { typ, supertype, final_, descriptor, describes, }),
    info: at,
  }
}

///|
fn Reader::take_name(
  self : Reader,
  c : Cursor,
  what : String,
) -> @ast.Ident raise ReadError {
  let here = c.here()
  match c.next() {
    Some(n) =>
      match as_id(n) {
        Some(s) => self.ident(s, node_span(n))
        None =>
          fail_at(
            "expected a name after `" + what + "`",
            node_span(n),
            source=self.src,
          )
      }
    None =>
      fail_at("expected a name after `" + what + "`", here, source=self.src)
  }
}

///|
/// A struct, an array, a function type or a continuation type.
fn Reader::comptype(
  self : Reader,
  c : Cursor,
  p : Parts,
) -> @ast.CompType raise ReadError {
  let here = c.here()
  match c.next() {
    None => fail_at("expected a type body", here, source=self.src)
    Some(n) =>
      match n.it {
        Braces(gs) => Struct(self.fields_of(gs))
        Brackets(gs) => {
          if gs.length() != 1 {
            fail_at(
              "an array type takes one element type",
              node_span(n),
              source=self.src,
            )
          }
          Array(Cursor::new(children(gs[0]), self).muttype())
        }
        Id("fn") => {
          let params = match c.next() {
            Some(ps) => ps
            None =>
              fail_at(
                "expected a parameter list after `fn`",
                node_span(n),
                source=self.src,
              )
          }
          Func(self.signature(params, c))
        }
        Id("cont") => Cont(self.take_name(c, "cont"))
        _ => {
          ignore(p)
          fail_at(
            "expected `{ ... }`, `[ ... ]`, `fn(...)` or `cont t`",
            node_span(n),
            source=self.src,
          )
        }
      }
  }
}

///|
/// A struct's fields, including the `..` that repeats a supertype's.
fn Reader::fields_of(
  self : Reader,
  gs : Array[@sh.Node],
) -> Array[
  @basic.Annotated[
    (@ast.Ident, @wasm_types.MutType[@wasm_types.StorageType[@ast.Ident]]),
    @basic.Location,
  ],
] raise ReadError {
  let out = []
  for g in gs {
    let ts = children(g)
    let at = self.loc(terms_span(ts[:]))
    if ts.length() == 1 && is_op(ts[0], "..") {
      out.push(@ast.splice_field(at))
      continue
    }
    let name = match
      (ts.length() > 0, if ts.length() > 0 { as_id(ts[0]) } else { None }) {
      (true, Some(n)) => self.ident(n, node_span(ts[0]))
      _ => fail_at("expected a field name", terms_span(ts[:]), source=self.src)
    }
    if !(ts.length() > 2 && is_op(ts[1], "::")) {
      fail_at(
        "expected `::` and a type after the field's name",
        terms_span(ts[:]),
        source=self.src,
      )
    }
    let typ = Cursor::new(ts[2:].to_owned(), self).muttype()
    out.push({ desc: (name, typ), info: at, })
  }
  out
}

///|
/// `fn NAME(params) -> results:` and the bodiless declaration form.
fn Reader::fn_field(
  self : Reader,
  head : Array[@sh.Node],
  p : Parts,
  mods : Mods,
) -> @ast.ModuleField[@basic.Location] raise ReadError {
  let ts = head[1:].to_owned()
  let name = match
    (ts.length() > 0, if ts.length() > 0 { as_id(ts[0]) } else { None }) {
    (true, Some(n)) => self.ident(n, node_span(ts[0]))
    _ => fail_at("expected a name after `fn`", p.span, source=self.src)
  }
  if ts.length() < 2 {
    fail_at("expected a parameter list", p.span, source=self.src)
  }
  let c = Cursor::new(ts[2:].to_owned(), self)
  let sign = self.signature(ts[1], c)
  let (label, body) = match p.block {
    Some(gs) => (None, self.body(gs))
    None => (None, [])
  }
  Func(
    name~,
    typ=None,
    sign=Some(sign),
    body=(label, body),
    attributes=mods.attrs,
  )
}

///|
/// `const NAME :: t = e` (immutable) and `let NAME :: t = e` (mutable).
fn Reader::global_field(
  self : Reader,
  head : Array[@sh.Node],
  p : Parts,
  mods : Mods,
  mut_ : Bool,
) -> @ast.ModuleField[@basic.Location] raise ReadError {
  let ts = head[1:].to_owned()
  let name = match
    (ts.length() > 0, if ts.length() > 0 { as_id(ts[0]) } else { None }) {
    (true, Some(n)) => self.ident(n, node_span(ts[0]))
    _ => fail_at("expected a name", p.span, source=self.src)
  }
  let mut i = 1
  let mut typ = None
  if i < ts.length() && is_op(ts[i], "::") {
    let c = Cursor::new(ts[i + 1:].to_owned(), self)
    typ = Some(c.valtype())
    i = i + 1 + c.i
  }
  let def = if i < ts.length() && is_op(ts[i], "=") {
    self.expr_all(ts[i + 1:].to_owned())
  } else {
    // A global with no initialiser is an import; Wax still wants a node there.
    self.instr(Nop, p.span)
  }
  Global(name~, mut_~, typ~, def~, attributes=mods.attrs)
}

///|
/// `tag NAME(types) -> results`
fn Reader::tag_field(
  self : Reader,
  head : Array[@sh.Node],
  p : Parts,
  mods : Mods,
) -> @ast.ModuleField[@basic.Location] raise ReadError {
  let ts = head[1:].to_owned()
  let name = match
    (ts.length() > 0, if ts.length() > 0 { as_id(ts[0]) } else { None }) {
    (true, Some(n)) => self.ident(n, node_span(ts[0]))
    _ => fail_at("expected a name after `tag`", p.span, source=self.src)
  }
  if ts.length() < 2 {
    fail_at(
      "expected a parameter list after the tag's name",
      p.span,
      source=self.src,
    )
  }
  let c = Cursor::new(ts[2:].to_owned(), self)
  let sign = self.signature(ts[1], c)
  Tag(name~, typ=None, sign=Some(sign), attributes=mods.attrs)
}

///|
/// `memory NAME :: i32 [min, max] pagesize N shared`
fn Reader::memory_field(
  self : Reader,
  head : Array[@sh.Node],
  p : Parts,
  mods : Mods,
) -> @ast.ModuleField[@basic.Location] raise ReadError {
  let ts = head[1:].to_owned()
  let name = match
    (ts.length() > 0, if ts.length() > 0 { as_id(ts[0]) } else { None }) {
    (true, Some(n)) => self.ident(n, node_span(ts[0]))
    _ => fail_at("expected a name after `memory`", p.span, source=self.src)
  }
  let c = Cursor::new(ts[1:].to_owned(), self)
  let address_type : @wasm_types.AddressType = if c.eat_op("::") {
    if c.eat_id("i64") {
      I64
    } else {
      let _ = c.eat_id("i32")
      I32
    }
  } else {
    I32
  }
  let limits = self.limits(c)
  let mut page_size_log2 = None
  if c.eat_id("pagesize") {
    let here = c.here()
    match c.next() {
      Some(n) =>
        match int_of(raw_text(n)) {
          Some(v) => page_size_log2 = Some(log2_of(v))
          None =>
            fail_at(
              "`pagesize` takes an integer",
              node_span(n),
              source=self.src,
            )
        }
      None => fail_at("`pagesize` takes an integer", here, source=self.src)
    }
  }
  let shared = c.eat_id("shared")
  Memory(
    name~,
    address_type~,
    limits~,
    page_size_log2~,
    shared~,
    data=[],
    attributes=mods.attrs,
  )
}

///|
/// `[min]` or `[min, max]`.
fn Reader::limits(
  self : Reader,
  c : Cursor,
) -> (UInt64, UInt64?)? raise ReadError {
  match c.peek() {
    Some(n) =>
      match n.it {
        Brackets(gs) => {
          c.i += 1
          if gs.length() == 0 || gs.length() > 2 {
            fail_at(
              "limits are `[min]` or `[min, max]`",
              node_span(n),
              source=self.src,
            )
          }
          let mi = self.u64_of(gs[0])
          let ma = if gs.length() == 2 {
            Some(self.u64_of(gs[1]))
          } else {
            None
          }
          Some((mi, ma))
        }
        _ => None
      }
    None => None
  }
}

///|
fn Reader::u64_of(self : Reader, g : @sh.Node) -> UInt64 raise ReadError {
  let ts = children(g)
  if ts.length() != 1 {
    fail_at("expected an integer", terms_span(ts[:]), source=self.src)
  }
  match int_of(raw_text(ts[0])) {
    Some(v) => v.to_uint64()
    None => fail_at("expected an integer", node_span(ts[0]), source=self.src)
  }
}

///|
/// `table NAME :: &?func [min, max]`
fn Reader::table_field(
  self : Reader,
  head : Array[@sh.Node],
  p : Parts,
  mods : Mods,
) -> @ast.ModuleField[@basic.Location] raise ReadError {
  let ts = head[1:].to_owned()
  let name = match
    (ts.length() > 0, if ts.length() > 0 { as_id(ts[0]) } else { None }) {
    (true, Some(n)) => self.ident(n, node_span(ts[0]))
    _ => fail_at("expected a name after `table`", p.span, source=self.src)
  }
  let c = Cursor::new(ts[1:].to_owned(), self)
  if !c.eat_op("::") {
    fail_at("expected `::` and an element type", p.span, source=self.src)
  }
  let reftype = c.reftype()
  let limits = self.limits(c)
  let init = if c.eat_op("=") { Some(self.expr_from(c)) } else { None }
  Table(
    name~,
    address_type=I32,
    reftype~,
    limits~,
    init~,
    attributes=mods.attrs,
  )
}

///|
/// `elem NAME :: &?func = [f, g]`
fn Reader::elem_field(
  self : Reader,
  head : Array[@sh.Node],
  p : Parts,
  mods : Mods,
) -> @ast.ModuleField[@basic.Location] raise ReadError {
  let ts = head[1:].to_owned()
  let name = match
    (ts.length() > 0, if ts.length() > 0 { as_id(ts[0]) } else { None }) {
    (true, Some(n)) => self.ident(n, node_span(ts[0]))
    _ => fail_at("expected a name after `elem`", p.span, source=self.src)
  }
  let c = Cursor::new(ts[1:].to_owned(), self)
  // `elem e at t[0] :: &?func = [...]` is the active form.
  let mut mode : @ast.ElemMode[@basic.Location] = EPassive
  if c.eat_id("at") {
    let table = self.take_name(c, "at")
    let offset = match c.next() {
      Some(n) =>
        match n.it {
          Brackets(gs) =>
            if gs.length() == 1 {
              self.group(gs[0])
            } else {
              fail_at("expected one offset", node_span(n), source=self.src)
            }
          _ => fail_at("expected `[offset]`", node_span(n), source=self.src)
        }
      None => fail_at("expected `[offset]`", p.span, source=self.src)
    }
    mode = EActive(table, offset)
  }
  if !c.eat_op("::") {
    fail_at("expected `::` and an element type", p.span, source=self.src)
  }
  let reftype = c.reftype()
  let init = if c.eat_op("=") {
    match c.next() {
      Some(n) =>
        match n.it {
          Brackets(gs) => {
            let out = []
            for g in gs {
              out.push(self.group(g))
            }
            out
          }
          _ =>
            fail_at("expected a bracketed list", node_span(n), source=self.src)
        }
      None => fail_at("expected a bracketed list", p.span, source=self.src)
    }
  } else {
    []
  }
  Elem(name~, reftype~, mode~, init~, attributes=mods.attrs)
}

///|
/// `data NAME at MEM[off] = "bytes" ++ f32[1.0]`
fn Reader::data_field(
  self : Reader,
  head : Array[@sh.Node],
  p : Parts,
  mods : Mods,
) -> @ast.ModuleField[@basic.Location] raise ReadError {
  let ts = head[1:].to_owned()
  let mut i = 0
  let mut name = None
  if i < ts.length() && as_id(ts[i]) is Some(n) && !is_id(ts[i], "at") {
    name = Some(self.ident(n, node_span(ts[i])))
    i += 1
  }
  let mut mode : @ast.DataMode[@basic.Location] = Passive
  if i < ts.length() && is_id(ts[i], "at") {
    i += 1
    let mem = match
      (i < ts.length(), if i < ts.length() { as_id(ts[i]) } else { None }) {
      (true, Some(m)) => self.ident(m, node_span(ts[i]))
      _ => fail_at("expected a memory name after `at`", p.span, source=self.src)
    }
    i += 1
    let offset = match
      (i < ts.length(), if i < ts.length() { Some(ts[i]) } else { None }) {
      (true, Some(n)) =>
        match n.it {
          Brackets(gs) =>
            if gs.length() == 1 {
              self.group(gs[0])
            } else {
              fail_at("expected one offset", node_span(n), source=self.src)
            }
          _ => fail_at("expected `[offset]`", node_span(n), source=self.src)
        }
      _ => fail_at("expected `[offset]`", p.span, source=self.src)
    }
    i += 1
    mode = Active(mem, offset)
  }
  if !(i < ts.length() && is_op(ts[i], "=")) {
    fail_at("expected `=` and the segment's contents", p.span, source=self.src)
  }
  let init = self.data_elems(ts[i + 1:].to_owned())
  Data(name~, mode~, init~, attributes=mods.attrs)
}

///|
/// `"bytes" ++ f32[1.0, 0.5] ++ i16[640, 480]`
fn Reader::data_elems(
  self : Reader,
  ts : Array[@sh.Node],
) -> Array[@ast.DataElem] raise ReadError {
  let parts : Array[Array[@sh.Node]] = []
  let current = []
  for t in ts {
    if is_op(t, "++") {
      parts.push(current.copy())
      current.clear()
    } else {
      current.push(t)
    }
  }
  parts.push(current)
  let out = []
  for part in parts {
    if part.length() == 1 && as_str(part[0]) is Some(s) {
      out.push(@ast.DataElem::Str(@utf8.encode(s)))
    } else if part.length() == 2 && part[1].it is Brackets(gs) {
      let st = Cursor::new([part[0]], self).storagetype()
      let vals = []
      for g in gs {
        let vs = children(g)
        vals.push(
          (
            { desc: literal_text(vs, self), info: self.loc(terms_span(vs[:])), } :
            @basic.Annotated[String, @basic.Location]),
        )
      }
      out.push(@ast.DataElem::Run(st, vals))
    } else {
      fail_at(
        "a data segment is a string or `t[a, b]`, joined with `++`",
        terms_span(part[:]),
        source=self.src,
      )
    }
  }
  out
}

///|
/// A numeric literal, with an optional sign.
fn literal_text(ts : Array[@sh.Node], r : Reader) -> String raise ReadError {
  if ts.length() == 1 {
    raw_text(ts[0])
  } else if ts.length() == 2 && (is_op(ts[0], "-") || is_op(ts[0], "+")) {
    as_op(ts[0]).unwrap() + raw_text(ts[1])
  } else {
    fail_at("expected a literal", terms_span(ts[:]), source=r.src)
  }
}

///|
/// `import "env": <declarations>`
fn Reader::import_field(
  self : Reader,
  head : Array[@sh.Node],
  p : Parts,
) -> @ast.ModuleField[@basic.Location] raise ReadError {
  if head.length() < 2 || as_str(head[1]) is None {
    fail_at(
      "`import` takes the module name as a string",
      p.span,
      source=self.src,
    )
  }
  let module_name = as_str(head[1]).unwrap()
  let at = self.loc(node_span(head[1]))
  let decls : Array[@basic.Annotated[@ast.ImportDecl, @basic.Location]] = []
  match p.block {
    None =>
      fail_at(
        "expected `:` and a list of declarations",
        p.span,
        source=self.src,
      )
    Some(gs) =>
      for g in gs {
        decls.push(self.import_decl(g))
      }
  }
  ImportGroup(module_={ desc: @utf8.encode(module_name), info: at, }, decls~)
}

///|
fn Reader::import_decl(
  self : Reader,
  g : @sh.Node,
) -> @basic.Annotated[@ast.ImportDecl, @basic.Location] raise ReadError {
  let p = split(g)
  let (mods, head) = self.mods(p.head)
  let at = self.loc(p.span)
  if head.length() == 0 {
    fail_at("expected a declaration", p.span, source=self.src)
  }
  let ts = head[1:].to_owned()
  let name = match
    (ts.length() > 0, if ts.length() > 0 { as_id(ts[0]) } else { None }) {
    (true, Some(n)) => self.ident(n, node_span(ts[0]))
    _ => fail_at("expected a name", p.span, source=self.src)
  }
  let kind : @ast.ImportKind = match as_id(head[0]) {
    Some("fn") => {
      if ts.length() < 2 {
        fail_at("expected a parameter list", p.span, source=self.src)
      }
      let c = Cursor::new(ts[2:].to_owned(), self)
      Func(typ=None, sign=Some(self.signature(ts[1], c)), exact=false)
    }
    Some("const") | Some("let") => {
      let mut_ = is_id(head[0], "let")
      let c = Cursor::new(ts[1:].to_owned(), self)
      if !c.eat_op("::") {
        fail_at("expected `::` and a type", p.span, source=self.src)
      }
      Global(mut_~, typ=c.valtype())
    }
    Some("tag") => {
      if ts.length() < 2 {
        fail_at("expected a parameter list", p.span, source=self.src)
      }
      let c = Cursor::new(ts[2:].to_owned(), self)
      Tag(typ=None, sign=Some(self.signature(ts[1], c)))
    }
    Some("memory") => {
      let c = Cursor::new(ts[1:].to_owned(), self)
      let address_type : @wasm_types.AddressType = if c.eat_op("::") {
        if c.eat_id("i64") {
          I64
        } else {
          let _ = c.eat_id("i32")
          I32
        }
      } else {
        I32
      }
      Memory(
        address_type~,
        limits=self.limits(c),
        page_size_log2=None,
        shared=false,
      )
    }
    Some("table") => {
      let c = Cursor::new(ts[1:].to_owned(), self)
      if !c.eat_op("::") {
        fail_at("expected `::` and an element type", p.span, source=self.src)
      }
      let reftype = c.reftype()
      Table(address_type=I32, reftype~, limits=self.limits(c))
    }
    _ =>
      fail_at(
        "an import declares a `fn`, `const`, `let`, `tag`, `memory` or `table`",
        p.span,
        source=self.src,
      )
  }
  { desc: { id: name, kind, attributes: mods.attrs, }, info: at, }
}

///|
/// `cfg(cond): ... | ...`
fn Reader::cfg_field(
  self : Reader,
  head : Array[@sh.Node],
  p : Parts,
) -> @ast.ModuleField[@basic.Location] raise ReadError {
  if head.length() < 2 {
    fail_at("`cfg` takes a condition in parentheses", p.span, source=self.src)
  }
  let cond = match head[1].it {
    Parens(gs) =>
      if gs.length() == 1 {
        self.cond(children(gs[0]))
      } else {
        fail_at(
          "`cfg` takes one condition",
          node_span(head[1]),
          source=self.src,
        )
      }
    _ =>
      fail_at(
        "`cfg` takes a condition in parentheses",
        node_span(head[1]),
        source=self.src,
      )
  }
  let at = self.loc(p.span)
  let then_fields = match p.block {
    Some(gs) => self.field_list(gs)
    None =>
      match p.alts {
        Some(alts) if alts.length() >= 1 => self.field_list(alts[0])
        _ =>
          fail_at(
            "expected `:` or `|` after the condition",
            p.span,
            source=self.src,
          )
      }
  }
  let else_fields = match (p.block, p.alts) {
    (Some(_), Some(alts)) if alts.length() >= 1 =>
      Some(self.field_list(alts[0]))
    (None, Some(alts)) if alts.length() >= 2 => Some(self.field_list(alts[1]))
    _ => None
  }
  Conditional(
    cond~,
    then_fields={ desc: then_fields, info: at, },
    else_fields=match else_fields {
      Some(f) => Some({ desc: f, info: at, })
      None => None
    },
  )
}

///|
fn Reader::field_list(
  self : Reader,
  gs : Array[@sh.Node],
) -> @ast.LocModule raise ReadError {
  let out : @ast.LocModule = []
  for g in gs {
    match self.module_field(g) {
      Some(f) => out.push(f)
      None => ()
    }
  }
  out
}

///|
/// A conditional-compilation condition.
fn Reader::cond(
  self : Reader,
  ts : Array[@sh.Node],
) -> @wasm_types.Cond raise ReadError {
  // `a || b`, then `a && b`, then `!a`, then an atom.
  for i, t in ts {
    if is_op(t, "||") {
      return Or([
        self.cond(ts[0:i].to_owned()),
        self.cond(ts[i + 1:].to_owned()),
      ])
    }
  }
  for i, t in ts {
    if is_op(t, "&&") {
      return And([
        self.cond(ts[0:i].to_owned()),
        self.cond(ts[i + 1:].to_owned()),
      ])
    }
  }
  if ts.length() >= 2 && is_op(ts[0], "!") {
    return Not(self.cond(ts[1:].to_owned()))
  }
  if ts.length() == 1 {
    match ts[0].it {
      Id(n) => return Var({ desc: n, info: self.loc(node_span(ts[0])), })
      Lit(Str(s)) =>
        return Str({ desc: @utf8.encode(s), info: self.loc(node_span(ts[0])), })
      Parens(gs) => if gs.length() == 1 { return self.cond(children(gs[0])) }
      _ => ()
    }
  }
  fail_at("expected a condition", terms_span(ts[:]), source=self.src)
}

///|
/// An integer literal in any radix.
fn int_of(text : String) -> Int? {
  Some(@string.parse_int(text)) catch {
    _ => None
  }
}

///|
/// The base-2 logarithm of a page size, which is how Wax stores it.
fn log2_of(n : Int) -> Int {
  let mut v = n
  let mut k = 0
  while v > 1 {
    v = v / 2
    k += 1
  }
  k
}
