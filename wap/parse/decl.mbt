// Top-level declarations, and the entry point.

///|
/// A parsed compilation unit, together with the source registry its
/// diagnostics point into.
pub struct Parsed {
  module_ : @wap.Module
  sources : @er.Sources
  source : @er.SourceId
}

///|
/// The module that was parsed.
pub fn Parsed::module_(self : Self) -> @wap.Module {
  self.module_
}

///|
/// The source registry, for rendering a report against the original text.
pub fn Parsed::sources(self : Self) -> @er.Sources {
  self.sources
}

///|
/// The id of the file that was parsed.
pub fn Parsed::source(self : Self) -> @er.SourceId {
  self.source
}

///|
/// Parse wap source into a wap module.
///
/// Grouping errors come from shrubbery and are re-raised unchanged: there is no
/// value in wap paraphrasing "wrong indentation, or missing `:` on the previous
/// line", and a shrubbery diagnostic already renders through error-report.
pub fn parse_module(
  text : String,
  fname? : String = "input.wap",
) -> Parsed raise ParseError {
  let sources = @er.Sources::new()
  let source = sources.add(fname, text)
  let parsed = @shparser.parse(text) catch {
    @sherror.ShrubberyError(d) => raise ParseError(d.to_report(source))
  }
  let groups = children(parsed.root())
  let decls = []
  let mut name = ""
  for g in groups {
    let d = parse_decl(g, source)
    match d {
      ModuleName(n) => name = n
      _ => ()
    }
    decls.push(d)
  }
  { module_: { name, decls, }, sources, source, }
}

///|
/// Modifiers that may sit in front of a declaration.
priv struct Mods {
  mut export_name : String?
  mut import_name : String?
  mut is_start : Bool
  mut is_pub : Bool
}

///|
/// Peel `export "n"`, `import "n"` and `start` off the head of a group.
fn take_mods(
  head : Array[@sh.Node],
  src : @er.SourceId,
) -> (Mods, Array[@sh.Node]) raise ParseError {
  let m : Mods = {
    export_name: None,
    import_name: None,
    is_start: false,
    is_pub: false,
  }
  let mut i = 0
  while i < head.length() {
    match as_id(head[i]) {
      Some("export") => {
        if i + 1 >= head.length() || as_str(head[i + 1]) is None {
          fail_at(
            "`export` takes the exported name as a string",
            node_span(head[i]),
            source=src,
          )
        }
        m.export_name = as_str(head[i + 1])
        i += 2
      }
      Some("start") => {
        m.is_start = true
        i += 1
      }
      Some("pub") => {
        m.is_pub = true
        i += 1
      }
      Some("import") =>
        // Only a modifier when a string follows AND something follows that;
        // `import "env":` on its own is a declaration.
        if i + 2 < head.length() && as_str(head[i + 1]) is Some(_) {
          m.import_name = as_str(head[i + 1])
          i += 2
        } else {
          break
        }
      _ => break
    }
  }
  (m, head[i:].to_owned())
}

///|
fn parse_decl(g : @sh.Node, src : @er.SourceId) -> @wap.Decl raise ParseError {
  let p = split(g)
  let (mods, head) = take_mods(p.head, src)
  if head.length() == 0 {
    fail_at("expected a declaration", p.span, source=src)
  }
  match as_id(head[0]) {
    Some("module") => {
      if head.length() != 2 || as_id(head[1]) is None {
        fail_at("`module` takes one name", p.span, source=src)
      }
      ModuleName(as_id(head[1]).unwrap())
    }
    Some("import") => parse_import(head, p, src)
    Some("const") => Const(parse_const(head, p, mods, src))
    Some("type") => parse_typedecl(head, p, mods, src)
    Some("fn") => Fn(parse_fn(head, p, mods, None, src))
    Some("impl") => {
      if head.length() != 2 || as_id(head[1]) is None {
        fail_at("`impl` takes one type name", p.span, source=src)
      }
      let typ = as_id(head[1]).unwrap()
      let methods = []
      match p.block {
        Some(gs) =>
          for mg in gs {
            let mp = split(mg)
            let (mmods, mhead) = take_mods(mp.head, src)
            if !(mhead.length() > 0 && is_id(mhead[0], "fn")) {
              fail_at(
                "an `impl` block contains only `fn` definitions",
                mp.span,
                source=src,
              )
            }
            methods.push(parse_fn(mhead, mp, mmods, Some(typ), src))
          }
        None =>
          fail_at("expected `:` and a body after `impl`", p.span, source=src)
      }
      Impl(typ~, methods~, span=p.span)
    }
    _ =>
      fail_at(
        "expected `module`, `import`, `const`, `type`, `fn` or `impl`",
        p.span,
        source=src,
        help="every top-level line in wap starts with one of those, optionally after `export \"name\"` or `start`",
      )
  }
}

///|
fn parse_import(
  head : Array[@sh.Node],
  p : Parts,
  src : @er.SourceId,
) -> @wap.Decl raise ParseError {
  // `import was "file.was":`
  if head.length() >= 3 && is_id(head[1], "was") && as_str(head[2]) is Some(f) {
    let (funcs, consts) = parse_extern_block(p, src)
    return ImportWas(file=f, funcs~, consts~)
  }
  // `import "env":`
  if head.length() >= 2 && as_str(head[1]) is Some(m) {
    let (funcs, consts) = parse_extern_block(p, src)
    return ImportHost(module_=m, funcs~, consts~)
  }
  // `import a.b.c`
  let path = []
  let mut i = 1
  while i < head.length() {
    match as_id(head[i]) {
      Some(s) => path.push(s)
      None =>
        if !is_op(head[i], ".") {
          fail_at("expected a module path", node_span(head[i]), source=src)
        }
    }
    i += 1
  }
  if path.length() == 0 {
    fail_at("expected a module path after `import`", p.span, source=src)
  }
  Import(path)
}

///|
fn parse_extern_block(
  p : Parts,
  src : @er.SourceId,
) -> (Array[@wap.FnDecl], Array[@wap.ConstDecl]) raise ParseError {
  let funcs = []
  let consts = []
  match p.block {
    None => fail_at("expected `:` and a list of signatures", p.span, source=src)
    Some(gs) =>
      for g in gs {
        let ip = split(g)
        let (imods, ihead) = take_mods(ip.head, src)
        if ihead.length() > 0 && is_id(ihead[0], "fn") {
          funcs.push(parse_fn(ihead, ip, imods, None, src))
        } else if ihead.length() > 0 && is_id(ihead[0], "const") {
          consts.push(parse_const(ihead, ip, imods, src))
        } else {
          fail_at("expected a `fn` or `const` signature", ip.span, source=src)
        }
      }
  }
  (funcs, consts)
}

///|
fn parse_const(
  head : Array[@sh.Node],
  p : Parts,
  mods : Mods,
  src : @er.SourceId,
) -> @wap.ConstDecl raise ParseError {
  let ts = head[1:].to_owned()
  let name = match (if ts.length() > 0 { as_id(ts[0]) } else { None }) {
    Some(s) => s
    None => fail_at("expected a name after `const`", p.span, source=src)
  }
  let mut typ = None
  let mut i = 1
  if i < ts.length() && is_op(ts[i], "::") {
    let c = Cursor::new(ts[i + 1:].to_owned(), src)
    typ = Some(parse_type(c))
    i = i + 1 + c.i
  }
  let value = if i < ts.length() && is_op(ts[i], "=") {
    parse_expr(Cursor::new(ts[i + 1:].to_owned(), src), 0)
  } else if mods.import_name is Some(_) || typ is Some(_) {
    // A declaration with no initialiser: an imported global.
    { it: Nop, span: p.span, }
  } else {
    fail_at(
      "expected `=` and a value after the constant's name",
      p.span,
      source=src,
    )
  }
  {
    name,
    typ,
    value,
    export_name: mods.export_name,
    import_name: mods.import_name,
    is_pub: mods.is_pub,
    span: p.span,
  }
}

///|
fn parse_typedecl(
  head : Array[@sh.Node],
  p : Parts,
  mods : Mods,
  src : @er.SourceId,
) -> @wap.Decl raise ParseError {
  let ts = head[1:].to_owned()
  let name = match (if ts.length() > 0 { as_id(ts[0]) } else { None }) {
    Some(s) => s
    None => fail_at("expected a name after `type`", p.span, source=src)
  }
  let mut parent = None
  let mut i = 1
  if i < ts.length() && is_op(ts[i], "::") {
    match (if i + 1 < ts.length() { as_id(ts[i + 1]) } else { None }) {
      Some(pn) => {
        parent = Some(pn)
        i += 2
      }
      None =>
        fail_at(
          "expected the parent type's name after `::`",
          p.span,
          source=src,
        )
    }
  }
  if !(i < ts.length() && is_op(ts[i], "=")) {
    fail_at("expected `=` in a type declaration", p.span, source=src)
  }
  let rhs = ts[i + 1:].to_owned()
  let def = parse_typedef(rhs, parent, p, src)
  TypeD(name~, def~, is_pub=mods.is_pub, span=p.span)
}

///|
fn parse_typedef(
  rhs : Array[@sh.Node],
  parent : String?,
  p : Parts,
  src : @er.SourceId,
) -> @wap.TypeDef raise ParseError {
  // `{ ... }` -- a record, possibly written across lines in a block.
  if rhs.length() == 1 && rhs[0].it is Braces(gs) {
    return Record(parent~, fields=parse_fields(gs, src))
  }
  // `enum { ... }`
  if rhs.length() == 2 && is_id(rhs[0], "enum") && rhs[1].it is Braces(gs) {
    let items = []
    let mut next = 0
    for g in gs {
      let ep = split(g)
      let name = match
        (if ep.head.length() > 0 { as_id(ep.head[0]) } else { None }) {
        Some(s) => s
        None => fail_at("expected an enumerator name", ep.span, source=src)
      }
      let mut value = None
      if ep.head.length() >= 3 && is_op(ep.head[1], "=") {
        match int_of(raw_text(ep.head[2])) {
          Some(v) => {
            value = Some(v)
            next = v + 1
          }
          None =>
            fail_at(
              "an enumerator's value must be an integer literal",
              ep.span,
              source=src,
            )
        }
      } else {
        value = Some(next)
        next += 1
      }
      items.push((name, value))
    }
    return Enum(items)
  }
  // `set[color]`
  if rhs.length() == 2 && is_id(rhs[0], "set") && rhs[1].it is Brackets(gs) {
    if gs.length() != 1 {
      fail_at("`set` takes one element type", p.span, source=src)
    }
    let inner = children(gs[0])
    match (if inner.length() == 1 { as_id(inner[0]) } else { None }) {
      Some(s) => return SetOf(s)
      None =>
        fail_at(
          "a set's element type must be an enumeration",
          p.span,
          source=src,
        )
    }
  }
  // `lo .. hi`
  for i, t in rhs {
    if is_op(t, "..") {
      let lo = int_of(literal_text(rhs[0:i].to_owned(), src))
      let hi = int_of(literal_text(rhs[i + 1:].to_owned(), src))
      match (lo, hi) {
        (Some(a), Some(b)) => return Subrange(low=a, high=b)
        _ =>
          fail_at(
            "a subrange's bounds must be integer literals",
            p.span,
            source=src,
          )
      }
    }
  }
  if parent is Some(_) {
    fail_at("only a record type can extend another", p.span, source=src)
  }
  Alias(parse_type(Cursor::new(rhs, src)))
}

///|
fn parse_fields(
  gs : Array[@sh.Node],
  src : @er.SourceId,
) -> Array[@wap.Field] raise ParseError {
  let out = []
  for g in gs {
    let ts = children(g)
    let name = match (if ts.length() > 0 { as_id(ts[0]) } else { None }) {
      Some(s) => s
      None => fail_at("expected a field name", terms_span(ts[:]), source=src)
    }
    if !(ts.length() > 2 && is_op(ts[1], "::")) {
      fail_at(
        "expected `::` and a type after `" + name + "`",
        terms_span(ts[:]),
        source=src,
      )
    }
    let mut rest = ts[2:].to_owned()
    let mut mut_ = false
    if rest.length() > 0 && is_id(rest[0], "mut") {
      mut_ = true
      rest = rest[1:].to_owned()
    }
    out.push(
      (
        {
          name,
          mut_,
          typ: parse_type(Cursor::new(rest, src)),
          span: node_span(ts[0]),
        } : @wap.Field),
    )
  }
  out
}

///|
fn parse_fn(
  head : Array[@sh.Node],
  p : Parts,
  mods : Mods,
  receiver : String?,
  src : @er.SourceId,
) -> @wap.FnDecl raise ParseError {
  let ts = head[1:].to_owned()
  let name = match (if ts.length() > 0 { as_id(ts[0]) } else { None }) {
    Some(s) => s
    None => fail_at("expected a name after `fn`", p.span, source=src)
  }
  let params = match (if ts.length() > 1 { Some(ts[1]) } else { None }) {
    Some(n) =>
      match n.it {
        Parens(gs) => parse_params(gs, receiver, src)
        _ => fail_at("expected a parameter list", node_span(n), source=src)
      }
    None =>
      fail_at(
        "expected a parameter list after `" + name + "`",
        p.span,
        source=src,
      )
  }
  let c = Cursor::new(ts[2:].to_owned(), src)
  let results = parse_results(c)
  let body = match p.block {
    Some(gs) => Some(parse_body(gs, src))
    None => None
  }
  {
    name,
    receiver,
    params,
    results,
    body,
    export_name: mods.export_name,
    import_name: mods.import_name,
    is_start: mods.is_start,
    is_pub: mods.is_pub,
    span: p.span,
  }
}

///|
/// Parameters, with Pascal's shared annotation: in `(a, b :: i32)` the
/// unannotated `a` takes the type of the next parameter that has one.
fn parse_params(
  gs : Array[@sh.Node],
  receiver : String?,
  src : @er.SourceId,
) -> Array[@wap.Param] raise ParseError {
  let names = []
  let types : Array[@wap.Type?] = []
  let spans = []
  for g in gs {
    let ts = children(g)
    let name = match (if ts.length() > 0 { as_id(ts[0]) } else { None }) {
      Some(s) => s
      None =>
        fail_at("expected a parameter name", terms_span(ts[:]), source=src)
    }
    names.push(name)
    spans.push(node_span(ts[0]))
    if ts.length() == 1 {
      // `self` in an impl block takes the receiver's type.
      if name == "self" && receiver is Some(r) {
        types.push(Some(Named(r)))
      } else {
        types.push(None)
      }
    } else if is_op(ts[1], "::") {
      types.push(Some(parse_type(Cursor::new(ts[2:].to_owned(), src))))
    } else {
      fail_at(
        "expected `::` and a type after `" + name + "`",
        terms_span(ts[:]),
        source=src,
      )
    }
  }
  // Fill unannotated parameters from the next annotated one.
  for i = types.length() - 2; i >= 0; i = i - 1 {
    if types[i] is None {
      types[i] = types[i + 1]
    }
  }
  let out = []
  for i, n in names {
    match types[i] {
      Some(t) => out.push(({ name: n, typ: t, span: spans[i], } : @wap.Param))
      None => fail_at("`" + n + "` has no type", spans[i], source=src)
    }
  }
  out
}

///|
/// An integer literal as written, in any of shrubbery's radixes.
fn int_of(text : String) -> Int? {
  Some(@string.parse_int(text)) catch {
    _ => None
  }
}
