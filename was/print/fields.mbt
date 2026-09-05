// Module fields, printed.

///|
/// The modifiers a declaration carries, as the prefix they are written as.
fn attrs_prefix(attrs : Array[@ast.Attribute]) -> String {
  let out = []
  for a in attrs {
    match (a.attr_name, a.attr_value) {
      ("export", Some(v)) => out.push("export " + expr(v))
      ("import", Some(v)) => out.push("import " + expr(v))
      ("start", _) => out.push("start")
      (name, Some(v)) => out.push(name + " " + expr(v))
      (name, None) => out.push(name)
    }
  }
  if out.length() == 0 {
    ""
  } else {
    out.join(" ") + " "
  }
}

///|
fn Out::field(self : Out, f : @ast.ModuleField[@basic.Location]) -> Unit {
  match f {
    Type(entries) =>
      if entries.length() == 1 {
        self.line(type_decl(entries[0].desc))
      } else {
        self.line("rec:")
        self.nest(() => {
          for e in entries {
            self.line(type_decl(e.desc))
          }
        })
      }
    Func(name~, sign~, body~, attributes~, ..) => {
      let s = match sign {
        Some(ft) => signature(ft)
        None => "()"
      }
      let (_, instrs) = body
      let head = attrs_prefix(attributes) + "fn " + name.name + s
      // A function with no body is a declaration, which is how an import is
      // written; one with a body takes a block.
      if instrs.length() == 0 && has_import(attributes) {
        self.line(head)
      } else {
        self.line(head + ":")
        self.nest(() => {
          if instrs.length() == 0 {
            self.line("nop")
          } else {
            for x in instrs {
              self.stmt("", x)
            }
          }
        })
      }
    }
    Global(name~, mut_~, typ~, def~, attributes~) => {
      let kw = if mut_ { "let " } else { "const " }
      let t = match typ {
        Some(v) => " :: " + valtype(v)
        None => ""
      }
      self.stmt(attrs_prefix(attributes) + kw + name.name + t + " = ", def)
    }
    Tag(name~, sign~, attributes~, ..) => {
      let s = match sign {
        Some(ft) => signature(ft)
        None => "()"
      }
      self.line(attrs_prefix(attributes) + "tag " + name.name + s)
    }
    Memory(
      name~,
      address_type~,
      limits~,
      page_size_log2~,
      shared~,
      data~,
      attributes~
    ) => {
      let at = match address_type {
        I32 => "i32"
        I64 => "i64"
      }
      let ps = match page_size_log2 {
        Some(l) => " pagesize " + (1 << l).to_string()
        None => ""
      }
      self.line(
        attrs_prefix(attributes) +
        "memory " +
        name.name +
        " :: " +
        at +
        limits_text(limits) +
        ps +
        (if shared { " shared" } else { "" }),
      )
      for d in data {
        self.nest(() => self.line(mem_data(d)))
      }
    }
    Table(name~, reftype=rt, limits~, init~, attributes~, ..) => {
      let i = match init {
        Some(v) => " = " + expr(v)
        None => ""
      }
      self.line(
        attrs_prefix(attributes) +
        "table " +
        name.name +
        " :: " +
        reftype(rt) +
        limits_text(limits) +
        i,
      )
    }
    Elem(name~, reftype=rt, mode~, init~, attributes~) => {
      let m = match mode {
        EPassive => ""
        EActive(t, off) => " at " + t.name + "[" + expr(off) + "]"
      }
      self.line(
        attrs_prefix(attributes) +
        "elem " +
        name.name +
        m +
        " :: " +
        reftype(rt) +
        " = [" +
        init.map(x => expr(x)).join(", ") +
        "]",
      )
    }
    Data(name~, mode~, init~, attributes~) => {
      let n = match name {
        Some(i) => " " + i.name
        None => ""
      }
      let m = match mode {
        Passive => ""
        Active(mem, off) => " at " + mem.name + "[" + expr(off) + "]"
      }
      self.line(
        attrs_prefix(attributes) +
        "data" +
        n +
        m +
        " = " +
        init.map(data_elem).join(" ++ "),
      )
    }
    Import(module_~, decl~) => {
      self.line("import " + string_text(module_.desc) + ":")
      self.nest(() => self.line(import_decl(decl.desc)))
    }
    ImportGroup(module_~, decls~) => {
      self.line("import " + string_text(module_.desc) + ":")
      self.nest(() => {
        for d in decls {
          self.line(import_decl(d.desc))
        }
      })
    }
    ModuleAnnotation(attrs) =>
      for a in attrs {
        match (a.attr_name, a.attr_value) {
          (name, Some(v)) => self.line(name + " " + expr(v))
          (name, None) => self.line(name)
        }
      }
    Conditional(cond~, then_fields~, else_fields~) => {
      self.line("cfg(" + cond_text(cond) + "):")
      self.nest(() => {
        for x in then_fields.desc {
          self.field(x.desc)
        }
      })
      match else_fields {
        Some(b) => {
          self.line("|")
          self.nest(() => {
            for x in b.desc {
              self.field(x.desc)
            }
          })
        }
        None => ()
      }
    }
  }
}

///|
fn has_import(attrs : Array[@ast.Attribute]) -> Bool {
  for a in attrs {
    if a.attr_name == "import" {
      return true
    }
  }
  false
}

///|
fn limits_text(l : (UInt64, UInt64?)?) -> String {
  match l {
    None => ""
    Some((mi, None)) => " [" + mi.to_string() + "]"
    Some((mi, Some(ma))) => " [" + mi.to_string() + ", " + ma.to_string() + "]"
  }
}

///|
fn type_decl(entry : (@ast.Ident, @ast.SubType)) -> String {
  let (name, sub) = entry
  let parent = match sub.supertype {
    Some(p) => " :: " + p.name
    None => ""
  }
  let openness = if sub.final_ { "" } else { "open " }
  let desc = match sub.descriptor {
    Some(d) => "descriptor " + d.name + " "
    None => ""
  }
  let describes = match sub.describes {
    Some(d) => "describes " + d.name + " "
    None => ""
  }
  "type " +
  name.name +
  parent +
  " = " +
  openness +
  desc +
  describes +
  comptype(sub.typ)
}

///|
fn comptype(c : @ast.CompType) -> String {
  match c {
    Struct(fields) => {
      let out = []
      for f in fields {
        let (n, t) = f.desc
        if @ast.is_splice_field(f) {
          out.push("..")
        } else {
          out.push(n.name + " :: " + muttype(t))
        }
      }
      "{ " + out.join(", ") + " }"
    }
    Array(t) => "[" + muttype(t) + "]"
    Func(ft) => "fn" + signature(ft)
    Cont(t) => "cont " + t.name
  }
}

///|
fn import_decl(d : @ast.ImportDecl) -> String {
  let prefix = attrs_prefix(d.attributes)
  match d.kind {
    Func(sign~, ..) => {
      let s = match sign {
        Some(ft) => signature(ft)
        None => "()"
      }
      prefix + "fn " + d.id.name + s
    }
    Global(mut_~, typ~) =>
      prefix +
      (if mut_ { "let " } else { "const " }) +
      d.id.name +
      " :: " +
      valtype(typ)
    Tag(sign~, ..) => {
      let s = match sign {
        Some(ft) => signature(ft)
        None => "()"
      }
      prefix + "tag " + d.id.name + s
    }
    Memory(address_type~, limits~, ..) =>
      prefix +
      "memory " +
      d.id.name +
      " :: " +
      (match address_type {
        I32 => "i32"
        I64 => "i64"
      }) +
      limits_text(limits)
    Table(reftype=rt, limits~, ..) =>
      prefix + "table " + d.id.name + " :: " + reftype(rt) + limits_text(limits)
  }
}

///|
fn data_elem(e : @ast.DataElem) -> String {
  match e {
    Str(b) => string_text(b)
    Run(t, vals) =>
      storagetype(t) + "[" + vals.map(v => v.desc).join(", ") + "]"
    V128Run(vals) =>
      "v128[" +
      vals
      .map(v => shape_text(v.desc.shape) + " " + v.desc.components.join(" "))
      .join(", ") +
      "]"
  }
}

///|
fn shape_text(s : @wasm_types.V128Shape) -> String {
  match s {
    I8x16 => "i8x16"
    I16x8 => "i16x8"
    I32x4 => "i32x4"
    I64x2 => "i64x2"
    F32x4 => "f32x4"
    F64x2 => "f64x2"
  }
}

///|
fn mem_data(d : @ast.MemData[@basic.Location]) -> String {
  let n = match d.data_name {
    Some(i) => " " + i.name
    None => ""
  }
  "data" +
  n +
  " at [" +
  expr(d.offset) +
  "] = " +
  d.init.map(data_elem).join(" ++ ")
}
