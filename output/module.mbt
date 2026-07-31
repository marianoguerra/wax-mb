// Module-field printing.

///|
pub fn Ctx::modulefield(
  self : Ctx[@basic.Location],
  field : @basic.Annotated[@ast.ModuleField[@basic.Location], @basic.Location],
) -> Unit {
  self.atomic_node(Some(field.info), () => self.modulefield_desc(field.desc))
}

///|
fn Ctx::modulefield_desc(
  self : Ctx[@basic.Location],
  f : @ast.ModuleField[@basic.Location],
) -> Unit {
  match f {
    Func(name~, typ~, sign~, body~, attributes~) => {
      self.print_attributes(attributes)
      self.p.hvbox(() => {
        self.p.box(() => {
          self.fundecl(name, typ, sign, tag=false)
          self.space()
          self.punct("{")
        })
        let (label, stmts) = body
        match label {
          Some(_) => ()
          None => ()
        }
        self.block_body(stmts)
        self.punct("}")
      })
    }
    _ => self.p.string("<<unported field>>")
  }
}

///|
/// A function or tag declaration head.
///
/// The whole signature is one all-or-nothing group anchored at the `fn` column:
/// `fn name` stays glued and so does `-> Ret`, so the only thing that can break
/// when the signature overflows is the parameter list.
fn Ctx::fundecl(
  self : Ctx[@basic.Location],
  name : @ast.Ident,
  typ : @ast.Ident?,
  sign : @ast.FuncType?,
  tag~ : Bool,
) -> Unit {
  self.p.hvbox(indent=indent_level, () => {
    self.p.hbox(() => {
      self.kw(if tag { "tag" } else { "fn" })
      self.space()
      self.ident(name.name)
    })
    match typ {
      Some(t) => {
        self.punct(":")
        self.space()
        self.typ(t.name)
      }
      None => ()
    }
    match sign {
      Some(s) => self.raw_functype(s)
      None => ()
    }
  })
}

///|
/// A statement list inside braces, without looking up block trivia.
fn Ctx::block_body(
  self : Ctx[@basic.Location],
  stmts : Array[@ast.Instr[@basic.Location]],
) -> Unit {
  if stmts.length() > 0 {
    self.p.indent(indent_level, () => {
      for i in stmts {
        self.newline()
        self.delimited_instr(i)
      }
    })
    self.newline()
  } else {
    self.cut()
  }
}

///|
fn Ctx::print_attributes(
  self : Ctx[@basic.Location],
  attributes : @ast.Attributes,
) -> Unit {
  for a in attributes {
    self.print_attribute(a)
    self.newline()
  }
}

///|
fn Ctx::print_attribute(
  self : Ctx[@basic.Location],
  a : @ast.Attribute,
) -> Unit {
  self.attr("#[")
  self.attr(a.attr_name)
  match a.attr_value {
    Some(v) => {
      self.attr(" = ")
      self.instr(Instruction, v)
    }
    None => ()
  }
  match a.attr_guard {
    Some(g) => self.attr(", if(" + cond_to_string(g.desc) + ")")
    None => ()
  }
  self.attr("]")
}
