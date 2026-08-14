// Module-field printing.

///|
fn Ctx::modulefield(
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
    Type(t) => self.rectype(t)
    ModuleAnnotation(attrs) =>
      self.p.hvbox(() => {
        let mut first = true
        for a in attrs {
          if !first {
            self.space()
          }
          first = false
          self.inner_attribute(a)
        }
      })
    Func(name~, typ~, sign~, body~, attributes~) =>
      self.attr_prefix(attributes, () => {
        self.p.hvbox(() => {
          let (label, stmts) = body
          self.p.box(() => {
            self.fundecl(name, typ, sign, tag=false)
            // The opening `{` is GLUED to the signature, so fundecl counts it
            // when deciding whether to break the parameter list. Otherwise a
            // signature one or two columns too long leaves `{` stranded on a
            // line of its own.
            self.p.hbox(() => {
              self.space()
              self.block_label(label)
              self.punct("{")
            })
          })
          self.block_contents(stmts)
          self.punct("}")
        })
      })
    Global(name~, mut_~, typ~, def~, attributes~) =>
      self.attr_prefix(attributes, () => {
        self.p.box(indent=indent_level, () => {
          self.kw(if mut_ { "let" } else { "const" })
          self.space()
          self.ident(name.name)
          match typ {
            Some(t) => {
              self.punct(":")
              self.space()
              self.valtype(t)
            }
            None => ()
          }
          self.space()
          self.punct("=")
          self.space()
          self.instr(Instruction, def)
          self.semicolon()
        })
      })
    Tag(name~, typ~, sign~, attributes~) =>
      self.attr_prefix(attributes, () => {
        self.p.box(() => {
          self.fundecl(name, typ, sign, tag=true)
          self.semicolon()
        })
      })
    Memory(
      name~,
      address_type~,
      limits~,
      page_size_log2~,
      shared~,
      data~,
      attributes~
    ) =>
      self.attr_prefix(attributes, () => {
        self.p.hvbox(() => {
          self.p.box(() => {
            self.kw("memory")
            self.space()
            self.ident(name.name)
            self.punct(":")
            self.space()
            self.kw(
              match address_type {
                I32 => "i32"
                I64 => "i64"
              },
            )
            self.print_limits(limits)
            match page_size_log2 {
              Some(pl) => {
                self.space()
                self.kw("pagesize")
                self.space()
                // Stored as the base-2 logarithm; printed as the size itself.
                // A SIGNED shift, matching the reference; see the note in
                // `modulefield_desc`.
                self.constant((1L << pl).to_string())
              }
              None => ()
            }
            if shared {
              self.space()
              self.kw("shared")
            }
          })
          if data.length() == 0 {
            self.semicolon()
          } else {
            self.p.hbox(() => {
              self.space()
              self.punct("{")
            })
            self.p.indent(indent_level, () => {
              for d in data {
                self.space()
                self.memdata(d)
              }
            })
            self.space()
            self.punct("}")
          }
        })
      })
    Data(name~, mode~, init~, attributes~) =>
      self.attr_prefix(attributes, () => {
        self.p.box(indent=indent_level, () => {
          self.p.hbox(() => {
            self.kw("data")
            self.space()
            self.data_name(name)
          })
          match mode {
            Passive => ()
            Active(mem, off) => self.targeted_offset(mem, off)
          }
          if init.length() > 0 {
            self.p.hbox(() => {
              self.space()
              self.punct("=")
            })
            self.space()
            self.data_init(init)
          }
          self.semicolon()
        })
      })
    Table(name~, address_type~, reftype~, limits~, init~, attributes~) =>
      self.attr_prefix(attributes, () => {
        self.p.box(indent=indent_level, () => {
          self.p.hbox(() => {
            self.kw("table")
            self.space()
            self.ident(name.name)
            self.punct(":")
            self.space()
            // i32 is the default and stays implicit.
            match address_type {
              I32 => ()
              I64 => {
                self.kw("i64")
                self.space()
              }
            }
            self.reftype(reftype)
            self.print_limits(limits)
          })
          match init {
            Some(e) => {
              self.p.hbox(() => {
                self.space()
                self.punct("=")
              })
              self.space()
              self.instr(Instruction, e)
            }
            None => ()
          }
          self.semicolon()
        })
      })
    Elem(name~, reftype~, mode~, init~, attributes~) =>
      self.attr_prefix(attributes, () => {
        self.p.box(indent=indent_level, () => {
          self.p.hbox(() => {
            self.kw("elem")
            self.space()
            self.ident(name.name)
            self.punct(":")
            self.space()
            self.reftype(reftype)
          })
          match mode {
            EPassive => ()
            EActive(tab, off) => self.targeted_offset(tab, off)
          }
          self.eq_square_instr_list(init)
          self.semicolon()
        })
      })
    Import(module_~, decl~) =>
      self.p.box(() => {
        self.kw("import")
        self.space()
        self.data_bytes(module_.desc)
        self.space()
        self.import_decl(decl.desc)
      })
    ImportGroup(module_~, decls~) =>
      self.p.hvbox(() => {
        self.p.box(() => {
          self.kw("import")
          self.space()
          self.data_bytes(module_.desc)
          self.space()
          self.punct("{")
        })
        // Like any brace-delimited block, a non-empty import group always lays
        // its declarations out vertically, one per line; an empty one stays
        // `{}`.
        if decls.length() > 0 {
          self.p.indent(indent_level, () => {
            for d in decls {
              self.newline()
              self.import_decl(d.desc)
            }
          })
          self.newline()
        }
        self.punct("}")
      })
    Conditional(cond~, then_fields~, else_fields~) => {
      // Braces are mandatory and a branch is a located field list. Like a block
      // body, a non-empty branch always breaks across lines -- hard newlines,
      // so the `{` and each field land on their own line even for a short
      // branch -- and an own-line comment trailing its last field renders
      // inside it.
      let branch = fn(
        b : @basic.Annotated[
          Array[
            @basic.Annotated[@ast.ModuleField[@basic.Location], @basic.Location],
          ],
          @basic.Location,
        ],
      ) -> Unit {
        self.space()
        self.punct("{")
        let assoc = self.get_trivia(Some(b.info))
        self.print_trivia(assoc.before)
        if b.desc.length() > 0 || assoc.within.length() > 0 {
          self.p.indent(indent_level, () => {
            for fl in b.desc {
              self.newline()
              self.modulefield(fl)
            }
            self.print_trivia(assoc.within)
          })
          self.newline()
        }
        self.close_block(assoc.after)
      }
      self.p.hvbox(() => {
        self.attr("#[if(" + cond_to_string(cond) + ")]")
        branch(then_fields)
        match else_fields {
          Some(e) => {
            self.newline()
            self.attr("#[else]")
            branch(e)
          }
          None => ()
        }
      })
    }
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
  exact? : Bool = false,
) -> Unit {
  // NO indent on this box: the parameter list supplies its own, and adding one
  // here would indent the parameters twice over and drag the closing `)` in
  // with them.
  self.p.hvbox(() => {
    self.p.hbox(() => {
      self.kw(if tag { "tag" } else { "fn" })
      self.space()
      self.ident(name.name)
      // An exact declaration with an inline signature marks the NAME
      // (`fn f!(...)`); with a named type the marker hugs the TYPE
      // (`fn f: !t`), so it is emitted below instead.
      if exact && typ is None {
        self.punct("!")
      }
    })
    match typ {
      Some(t) => {
        self.punct(":")
        self.space()
        if exact {
          self.punct("!")
        }
        self.ident(t.name)
        // A trailing space, so `fn f: t ()` keeps the type off the
        // parameter list.
        self.space()
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
/// A statement list inside braces, without a block's own trivia lookup.
fn Ctx::block_contents(
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
/// Memory and table size bounds, `[min]` or `[min, max]`.
fn Ctx::print_limits(
  self : Ctx[@basic.Location],
  limits : (UInt64, UInt64?)?,
) -> Unit {
  match limits {
    Some((mi, ma)) => {
      self.space()
      self.punct("[")
      self.constant(mi.to_string())
      match ma {
        Some(m) => {
          self.punct(",")
          self.space()
          self.constant(m.to_string())
        }
        None => ()
      }
      self.punct("]")
    }
    None => ()
  }
}
