// Module fields, and the entry point.

///|
/// A module read from was source.
pub struct Read {
  fields : @ast.LocModule
  sources : @er.Sources
  source : @er.SourceId
  diagnostics : Array[@er.Report]
}

///|
/// The Wax module fields.
pub fn Read::fields(self : Self) -> @ast.LocModule {
  self.fields
}

///|
/// The source registry the reports point into.
pub fn Read::sources(self : Self) -> @er.Sources {
  self.sources
}

///|
/// The id of the file that was read.
pub fn Read::source(self : Self) -> @er.SourceId {
  self.source
}

///|
/// Problems found while reading.
pub fn Read::diagnostics(self : Self) -> Array[@er.Report] {
  self.diagnostics
}

///|
/// Read was source into the Wax AST.
///
/// Grouping errors come from shrubbery and are re-raised unchanged: there is
/// no value in was paraphrasing them, and a shrubbery diagnostic already
/// renders through error-report.
pub fn read_module(
  text : String,
  fname? : String = "input.was",
) -> Read raise ReadError {
  let sources = @er.Sources::new()
  let source = sources.add(fname, text)
  let parsed = @shparser.parse(text) catch {
    @sherror.ShrubberyError(d) => raise ReadError(d.to_report(source))
  }
  let groups = children(parsed.root())
  let r = Reader::new(fname~, text~, src=source)
  collect_type_names(r, groups)
  let fields : @ast.LocModule = []
  for g in groups {
    match r.module_field(g) {
      Some(f) => fields.push(f)
      None => ()
    }
  }
  { fields, sources, source, diagnostics: r.diagnostics, }
}

///|
/// Every type name the file declares, for the one place the reader needs them:
/// telling `ints[0]` the literal from `xs[0]` the index.
fn collect_type_names(r : Reader, groups : Array[@sh.Node]) -> Unit {
  fn scan(gs : Array[@sh.Node]) -> Unit {
    for g in gs {
      let p = split(g)
      let head = p.head
      if head.length() >= 2 &&
        is_id(head[0], "type") &&
        as_id(head[1]) is Some(n) {
        r.type_names[n] = ()
      }
      if head.length() >= 1 && is_id(head[0], "rec") {
        match p.block {
          Some(inner) => scan(inner)
          None => ()
        }
      }
    }
  }

  scan(groups)
}

///|
/// Modifiers that may precede a declaration.
priv struct Mods {
  attrs : Array[@ast.Attribute]
}

///|
fn Reader::mods(
  self : Reader,
  head : Array[@sh.Node],
) -> (Mods, Array[@sh.Node]) raise ReadError {
  let m : Mods = { attrs: [], }
  let mut i = 0
  while i < head.length() {
    let at = self.loc(node_span(head[i]))
    match as_id(head[i]) {
      Some("export") => {
        if i + 1 >= head.length() || as_str(head[i + 1]) is None {
          fail_at(
            "`export` takes the exported name as a string",
            node_span(head[i]),
            source=self.src,
          )
        }
        m.attrs.push({
          attr_name: "export",
          attr_value: Some(
            self.instr(
              Str(None, @utf8.encode(as_str(head[i + 1]).unwrap())),
              node_span(head[i + 1]),
            ),
          ),
          attr_guard: None,
          attr_span: at,
        })
        i += 2
      }
      Some("start") => {
        m.attrs.push({
          attr_name: "start",
          attr_value: None,
          attr_guard: None,
          attr_span: at,
        })
        i += 1
      }
      Some("import") =>
        if i + 2 < head.length() && as_str(head[i + 1]) is Some(n) {
          m.attrs.push({
            attr_name: "import",
            attr_value: Some(
              self.instr(Str(None, @utf8.encode(n)), node_span(head[i + 1])),
            ),
            attr_guard: None,
            attr_span: at,
          })
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
/// One top-level group as a module field.
fn Reader::module_field(
  self : Reader,
  g : @sh.Node,
) -> @basic.Annotated[@ast.ModuleField[@basic.Location], @basic.Location]? raise ReadError {
  let p = split(g)
  let (mods, head) = self.mods(p.head)
  if head.length() == 0 {
    self.error("expected a declaration", p.span)
    return None
  }
  let at = self.loc(p.span)
  let field : @ast.ModuleField[@basic.Location]? = match as_id(head[0]) {
    Some("feature") => {
      if head.length() != 2 || as_str(head[1]) is None {
        fail_at("`feature` takes one string", p.span, source=self.src)
      }
      Some(
        ModuleAnnotation([
          {
            attr_name: "feature",
            attr_value: Some(
              self.instr(
                Str(None, @utf8.encode(as_str(head[1]).unwrap())),
                node_span(head[1]),
              ),
            ),
            attr_guard: None,
            attr_span: at,
          },
        ]),
      )
    }
    Some("type") => Some(Type([self.type_entry(head, p)]))
    Some("rec") => {
      let entries = []
      match p.block {
        Some(gs) =>
          for tg in gs {
            let tp = split(tg)
            if !(tp.head.length() > 0 && is_id(tp.head[0], "type")) {
              fail_at(
                "a `rec` block contains only `type` declarations",
                tp.span,
                source=self.src,
              )
            }
            entries.push(self.type_entry(tp.head, tp))
          }
        None =>
          fail_at(
            "expected `:` and a body after `rec`",
            p.span,
            source=self.src,
          )
      }
      Some(Type(entries))
    }
    Some("fn") => Some(self.fn_field(head, p, mods))
    Some("const") => Some(self.global_field(head, p, mods, false))
    Some("let") => Some(self.global_field(head, p, mods, true))
    Some("tag") => Some(self.tag_field(head, p, mods))
    Some("memory") => Some(self.memory_field(head, p, mods))
    Some("table") => Some(self.table_field(head, p, mods))
    Some("elem") => Some(self.elem_field(head, p, mods))
    Some("data") => Some(self.data_field(head, p, mods))
    Some("import") => Some(self.import_field(head, p))
    Some("cfg") => Some(self.cfg_field(head, p))
    _ => {
      self.error(
        "expected a declaration",
        p.span,
        help="`type`, `rec`, `fn`, `const`, `let`, `tag`, `memory`, `table`, `elem`, `data`, `import`, `feature` or `cfg`",
      )
      None
    }
  }
  match field {
    Some(f) => Some({ desc: f, info: at, })
    None => None
  }
}
