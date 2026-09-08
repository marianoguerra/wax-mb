///|
fn terms(node : @sh.Node) -> Array[@sh.Node] {
  node.children()
}

///|
fn word(node : @sh.Node) -> String {
  match node.it {
    Id(s) | Op(s) => s
    _ => ""
  }
}

///|
fn span(node : @sh.Node) -> @w.Span {
  @wp.node_span(node)
}

///|
fn names(node : @sh.Node) -> Array[String] raise ScriptError {
  let out = []
  for group in terms(node) {
    let ts = terms(group)
    if ts.length() != 1 || word(ts[0]) == "" {
      problem("expected a parameter name", span(group))
    }
    let name = word(ts[0])
    if out.contains(name) {
      problem("duplicate parameter " + name, span(group))
    }
    out.push(name)
  }
  out
}

///|
fn read_unit(source : String) -> SourceUnit raise ScriptError {
  let tree = @shrub.parse(source) catch {
    _ => raise ScriptError("invalid Shrubbery grouping")
  }
  let functions = []
  let records = []
  let imports = []
  let requirements = []
  let mut module_name = "main"
  let seen : Map[String, Bool] = Map([])
  for group in tree.root().children() {
    let p = @wp.split(group)
    let mut h = p.head
    let exported = h.length() > 0 && word(h[0]) == "export"
    if exported {
      h = h[1:].to_owned()
    }
    if h.length() == 0 {
      problem("expected a declaration", p.span)
    }
    let kind = word(h[0])
    match kind {
      "module" | "import" => {
        if exported || p.block is Some(_) || h.length() < 2 {
          problem("invalid module declaration", p.span)
        }
        let name = h[1:].map(word).join("")
        if kind == "module" {
          module_name = name
        } else {
          imports.push(name)
        }
      }
      "require" => {
        if exported ||
          p.block is Some(_) ||
          h.length() < 4 ||
          word(h[2]) != "::" {
          problem("expected require name :: protocol.v1", p.span)
        }
        let name = word(h[1])
        if seen.contains(name) {
          problem("duplicate declaration " + name, p.span)
        }
        seen[name] = true
        requirements.push((name, h[3:].map(word).join("")))
      }
      "fn" => {
        if h.length() != 3 || !(h[2].it is Parens(_)) {
          problem("expected fn name(parameters): body", p.span)
        }
        let name = word(h[1])
        if seen.contains(name) {
          problem("duplicate declaration " + name, p.span)
        }
        seen[name] = true
        let body = match p.block {
          Some(gs) => read_body(gs)
          None => problem("function needs a body", p.span)
        }
        functions.push({
          name,
          params: names(h[2]),
          body,
          exported,
          span: p.span,
        })
      }
      "record" | "variant" => {
        if h.length() != 2 {
          problem("expected a type name", p.span)
        }
        let name = word(h[1])
        if seen.contains(name) {
          problem("duplicate declaration " + name, p.span)
        }
        seen[name] = true
        let gs = match p.block {
          Some(gs) => gs
          None => problem("type needs a body", p.span)
        }
        if kind == "record" {
          records.push({ name, fields: read_fields(gs), })
        } else {
          for g in gs {
            let arm = @wp.split(g)
            if arm.head.length() != 1 {
              problem("expected variant case name", arm.span)
            }
            let case_name = name + "." + word(arm.head[0])
            records.push({
              name: case_name,
              fields: match arm.block {
                Some(fs) => read_fields(fs)
                None => []
              },
            })
          }
        }
      }
      _ =>
        problem(
          "modules contain declarations only; no module values or initialization",
          p.span,
        )
    }
  }
  { name: module_name, imports, functions, records, requirements, source, }
}

///|
fn read_fields(
  groups : Array[@sh.Node],
) -> Array[(String, String)] raise ScriptError {
  let out = []
  let seen : Map[String, Bool] = Map([])
  for g in groups {
    let h = terms(g)
    if h.length() != 1 && (h.length() < 3 || word(h[1]) != "::") {
      problem("expected field or field :: type", span(g))
    }
    let name = word(h[0])
    if seen.contains(name) {
      problem("duplicate field " + name, span(g))
    }
    seen[name] = true
    out.push(
      (name, if h.length() == 1 { "value" } else { h[2:].map(word).join("") }),
    )
  }
  out
}

///|
fn read_body(groups : Array[@sh.Node]) -> Array[Term] raise ScriptError {
  let out = []
  for g in groups {
    out.push(read_group(g))
  }
  if out.is_empty() {
    raise ScriptError("empty function body")
  }
  out
}

///|
fn read_group(g : @sh.Node) -> Term raise ScriptError {
  let p = @wp.split(g)
  read_parts(p.head, p.block, p.alts, p.span)
}

///|
fn read_parts(
  h : Array[@sh.Node],
  block : Array[@sh.Node]?,
  alts : Array[Array[@sh.Node]]?,
  at : @w.Span,
) -> Term raise ScriptError {
  if h.is_empty() {
    problem("expected expression", at)
  }
  if word(h[0]) == "let" {
    if h.length() < 4 || word(h[2]) != "=" {
      problem("expected let name = expression", at)
    }
    let ns = if h[1].it is Brackets(_) { names(h[1]) } else { [word(h[1])] }
    return {
      expr: Bind(ns, read_parts(h[3:].to_owned(), block, alts, at)),
      span: at,
    }
  }
  if word(h[0]) == "fn" {
    if h.length() != 2 || !(h[1].it is Parens(_)) {
      problem("expected fn(parameters): expression", at)
    }
    let gs = match block {
      Some(gs) => gs
      None => problem("closure needs body", at)
    }
    return { expr: Lambda(names(h[1]), read_body(gs)), span: at, }
  }
  if word(h[0]) == "if" {
    let arms = match alts {
      Some(a) => a
      None => problem("use if condition | consequent | alternative", at)
    }
    if arms.length() != 2 || block is Some(_) {
      problem("if requires two alternatives", at)
    }
    return {
      expr: If(
        read_expression(h[1:].to_owned()),
        read_body(arms[0]),
        read_body(arms[1]),
      ),
      span: at,
    }
  }
  if word(h[0]) == "match" {
    let alternatives = match alts {
      Some(a) => a
      None => problem("match needs pattern alternatives", at)
    }
    let arms = []
    for arm in alternatives {
      if arm.length() != 1 {
        problem("each match arm is pattern: body", at)
      }
      let p = @wp.split(arm[0])
      let body = match p.block {
        Some(gs) => read_body(gs)
        None => problem("match arm needs a body", p.span)
      }
      arms.push((read_expression(p.head), body))
    }
    return { expr: Match(read_expression(h[1:].to_owned()), arms), span: at, }
  }
  if block is Some(_) || alts is Some(_) {
    problem("unexpected block", at)
  }
  read_expression(h)
}

///|
priv struct Cursor {
  ts : Array[@sh.Node]
  mut pos : Int
}

///|
fn read_expression(ts : Array[@sh.Node]) -> Term raise ScriptError {
  let c = { ts, pos: 0, }
  let result = c.expression(0)
  if c.pos != ts.length() {
    problem("unexpected token " + word(ts[c.pos]), span(ts[c.pos]))
  }
  result
}

///|
fn precedence(s : String) -> Int {
  match s {
    "or" => 1
    "and" => 2
    "==" | "!=" | "<" | "<=" | ">" | ">=" => 3
    "+" | "-" => 4
    "*" | "/" | "%" => 5
    _ => 0
  }
}

///|
fn Cursor::expression(self : Cursor, min : Int) -> Term raise ScriptError {
  if self.pos >= self.ts.length() {
    raise ScriptError("expected expression")
  }
  let t = self.ts[self.pos]
  self.pos += 1
  let at = span(t)
  let mut lhs : Term = {
    span: at,
    expr: match t.it {
      Id("nil") => Nil
      Id("true") => Boolean(true)
      Id("false") => Boolean(false)
      Id(s) => Name(s)
      Kw(s) => Text(s, true)
      Lit(Str(s)) => Text(s, false)
      Lit(Int_(_)) => Integer(@wp.raw_text(t))
      Lit(Flo(_)) => Float(@wp.raw_text(t))
      Op("-") => {
        let operand = self.expression(6)
        match operand.expr {
          Integer(s) => Integer("-" + s)
          Float(s) => Float("-" + s)
          _ => Binary("-", { expr: Integer("0"), span: at, }, operand)
        }
      }
      Parens(gs) => {
        if gs.length() != 1 {
          problem("parentheses contain one expression", at)
        }
        read_group(gs[0]).expr
      }
      Brackets(gs) => Vector(gs.map(read_group))
      Braces(gs) => {
        let pairs = []
        for g in gs {
          let ts = terms(g)
          let mut split = -1
          for i, n in ts {
            if word(n) == "=>" {
              split = i
              break
            }
          }
          if split < 1 {
            problem("map entries use key => value", span(g))
          }
          pairs.push(
            (
              read_expression(ts[:split].to_owned()),
              read_expression(ts[split + 1:].to_owned()),
            ),
          )
        }
        MapLit(pairs)
      }
      _ => problem("unsupported expression", at)
    },
  }
  while self.pos < self.ts.length() {
    let next = self.ts[self.pos]
    if next.it is Parens(gs) {
      self.pos += 1
      lhs = { expr: Call(lhs, gs.map(read_group)), span: at, }
    } else if word(next) == "." {
      self.pos += 1
      if self.pos >= self.ts.length() {
        problem("expected member name", at)
      }
      let name = word(self.ts[self.pos])
      self.pos += 1
      lhs = { expr: Field(lhs, name), span: at, }
    } else {
      let op = word(next)
      let bp = precedence(op)
      if bp == 0 || bp < min {
        break
      }
      self.pos += 1
      lhs = { expr: Binary(op, lhs, self.expression(bp + 1)), span: at, }
    }
  }
  lhs
}
