// Type definitions, attributes, and the data/element segment payloads.

///|
/// A named type definition, `type name = ...;`.
pub fn Ctx::subtype(
  self : Ctx[@basic.Location],
  field : @basic.Annotated[(@ast.Ident, @ast.SubType), @basic.Location],
) -> Unit {
  let (nm, st) = field.desc
  self.atomic_node(Some(field.info), () => {
    self.p.hvbox(() => {
      let is_struct = st.typ is Struct(_)
      self.p.box(() => {
        self.kw("type")
        self.space()
        self.ident(nm.name)
        match st.supertype {
          Some(sup) => {
            self.punct(":")
            self.space()
            self.ident(sup.name)
          }
          None => ()
        }
        self.space()
        self.punct("=")
        // `open` is the spelling; the AST stores the negation, since
        // final-by-default is what WebAssembly encodes.
        if !st.final_ {
          self.space()
          self.kw("open")
        }
        // custom-descriptors clauses, between `open` and the body.
        let clause = fn(kw : String, id : @ast.Ident?) -> Unit {
          match id {
            Some(x) => {
              self.space()
              self.kw(kw)
              self.space()
              self.ident(x.name)
            }
            None => ()
          }
        }
        clause("describes", st.describes)
        clause("descriptor", st.descriptor)
        // A struct's opening brace belongs to the head; comptype prints the rest.
        if is_struct {
          self.space()
          self.punct("{")
        }
      })
      self.space()
      self.comptype(st.typ)
      self.punct(";")
    })
  })
}

///|
pub fn Ctx::rectype(
  self : Ctx[@basic.Location],
  members : Array[@basic.Annotated[(@ast.Ident, @ast.SubType), @basic.Location]],
) -> Unit {
  if members.length() == 1 {
    self.subtype(members[0])
  } else {
    // A non-empty `rec { ... }` always breaks across lines, like a block body:
    // every separator is a hard newline, so members lay out vertically even
    // when they would fit on one line. An empty group stays `rec {}`.
    self.p.hvbox(() => {
      self.p.box(() => {
        self.kw("rec")
        self.space()
        self.punct("{")
      })
      if members.length() > 0 {
        self.p.indent(indent_level, () => {
          for m in members {
            self.newline()
            self.subtype(m)
          }
        })
        self.newline()
      }
      self.punct("}")
    })
  }
}

///|
fn Ctx::attribute_gen(
  self : Ctx[@basic.Location],
  open_ : String,
  a : @ast.Attribute,
) -> Unit {
  self.p.box(indent=indent_level, () => {
    self.attr(open_)
    self.attr(a.attr_name)
    match a.attr_value {
      None => ()
      Some(v) => {
        self.space()
        self.attr("=")
        self.space()
        // The value is coloured as part of the attribute, so `#[export = "f"]`
        // reads as one unit rather than as an attribute wrapping a
        // string-coloured literal.
        self.with_style(Attribute, () => self.instr(Instruction, v))
      }
    }
    // A per-attribute guard, `#[export = "n", if(<cond>)]`.
    match a.attr_guard {
      None => ()
      Some(c) => {
        self.attr(",")
        self.space()
        self.attr("if(" + cond_to_string(c.desc) + ")")
      }
    }
    self.attr("]")
  })
}

///|
pub fn Ctx::attribute_(self : Ctx[@basic.Location], a : @ast.Attribute) -> Unit {
  self.attribute_gen("#[", a)
}

///|
/// A module-level inner attribute, `#![module = "name"]`.
pub fn Ctx::inner_attribute(
  self : Ctx[@basic.Location],
  a : @ast.Attribute,
) -> Unit {
  self.attribute_gen("#![", a)
}

///|
/// Attributes are separated at THIS level rather than by a trailing space
/// inside each attribute's own box.
///
/// A break between them then lands at the enclosing box's indentation, so
/// stacked attributes stay aligned instead of each indenting relative to the
/// previous one's box.
fn Ctx::print_attributes(
  self : Ctx[@basic.Location],
  attributes : @ast.Attributes,
) -> Unit {
  let mut first = true
  for a in attributes {
    if !first {
      self.space()
    }
    first = false
    self.attribute_(a)
  }
}

///|
/// Run `content` preceded by its attributes, each on its own line.
fn Ctx::attr_prefix(
  self : Ctx[@basic.Location],
  attributes : @ast.Attributes,
  content : () -> Unit,
) -> Unit {
  self.p.hvbox(() => {
    if attributes.length() > 0 {
      self.print_attributes(attributes)
      self.newline()
    }
    content()
  })
}

///|
/// A byte string, re-escaped and quoted.
fn Ctx::data_bytes(self : Ctx[@basic.Location], s : Bytes) -> Unit {
  // Three atoms, the middle carrying the escaped form's display width -- the
  // same shape as an inline string literal.
  let (len, body) = @unicode.escape_string(s, hex_prefix="x")
  self.str("\"")
  self.styled_as(Str, len, body)
  self.str("\"")
}

///|
pub fn vec_shape_name(s : @wasm_types.V128Shape) -> String {
  s.to_str()
}

///|
/// A data numeric run, `[head: e1, e2, ...]`.
///
/// Laid out exactly like an array literal: inline when it fits, otherwise one
/// value per line with a trailing comma and the `]` dedented onto its own
/// line -- differing only in the `type:` head, against an array's `type|`.
fn[T] Ctx::print_run(
  self : Ctx[@basic.Location],
  head : String,
  elems : Array[T],
  print_elem : (T) -> Unit,
) -> Unit {
  self.p.hvbox(() => {
    self.p.box(() => {
      self.punct("[")
      self.typ(head)
      self.punct(":")
    })
    self.p.indent(indent_level, () => {
      self.space()
      self.list_commasep_trailing(elems, print_elem)
    })
    self.cut()
    self.punct("]")
  })
}

///|
fn Ctx::v128_group(
  self : Ctx[@basic.Location],
  v : @basic.Annotated[@wasm_types.V128, @basic.Location],
) -> Unit {
  self.atomic_node(Some(v.info), () => {
    self.typ(vec_shape_name(v.desc.shape))
    self.punct("(")
    self.list_commasep(v.desc.components, c => self.constant(c))
    self.punct(")")
  })
}

///|
fn Ctx::data_elem(self : Ctx[@basic.Location], e : @ast.DataElem) -> Unit {
  match e {
    Str(s) => self.data_bytes(s)
    Run(t, elems) =>
      self.print_run(suffix_string(t), elems, n => {
        self.atomic_node(Some(n.info), () => self.constant(n.desc))
      })
    V128Run(elems) => self.print_run("v128", elems, v => self.v128_group(v))
  }
}

///|
/// A data segment's contents: elements joined by `++`.
fn Ctx::data_init(
  self : Ctx[@basic.Location],
  init : Array[@ast.DataElem],
) -> Unit {
  self.p.box(indent=indent_level, () => {
    for i, e in init {
      if i > 0 {
        // Folded like a binary operator: the break goes BEFORE `++`, which
        // then leads its continuation line. The separator after it is a raw
        // space, not a breakable one, so `++` can never end a line.
        self.space()
        self.op("++")
        self.p.string(" ")
      }
      self.data_elem(e)
    }
  })
}

///|
fn Ctx::data_name(self : Ctx[@basic.Location], n : @ast.Ident?) -> Unit {
  match n {
    Some(x) => self.ident(x.name)
    None => self.op("_")
  }
}

///|
/// A bracketed offset instruction, `[off]`.
///
/// A SIMPLE offset -- a name or a literal -- stays inline. Anything else, or a
/// comment forcing a break, gets the indented form with the `]` on its own
/// line, so `data d @ [0x1000 // why\n]` keeps the comment where it was
/// written.
fn Ctx::square_instr(
  self : Ctx[@basic.Location],
  i : @ast.Instr[@basic.Location],
  leading_space? : Bool = false,
) -> Unit {
  if simple_inline_instr(i) {
    if leading_space {
      self.space()
    }
    self.punct("[")
    self.instr(Instruction, i)
    self.punct("]")
  } else {
    if leading_space {
      self.p.hbox(() => {
        self.space()
        self.punct("[")
      })
    } else {
      self.punct("[")
    }
    self.p.indent(indent_level, () => {
      self.newline()
      self.instr(Instruction, i)
    })
    self.newline()
    self.punct("]")
  }
}

///|
/// ` @ target [offset]` -- an active segment's placement.
///
/// The spaces are real: the reference writes `data d @ mem [0]`, not
/// `data d@mem[0]`.
fn Ctx::targeted_offset(
  self : Ctx[@basic.Location],
  target : @ast.Ident,
  off : @ast.Instr[@basic.Location],
) -> Unit {
  self.p.hbox(() => {
    self.space()
    self.op("@")
    self.space()
    self.ident(target.name)
  })
  self.square_instr(off, leading_space=true)
}

///|
/// ` = [a, b, c]` -- an element segment's initialiser.
fn Ctx::eq_square_instr_list(
  self : Ctx[@basic.Location],
  l : Array[@ast.Instr[@basic.Location]],
) -> Unit {
  self.p.hbox(() => {
    self.space()
    self.punct("=")
    self.space()
  })
  // More than three elements and the list is laid out one per line
  // UNCONDITIONALLY -- a count, not a width test, so a long element list stays
  // readable even when it would technically fit.
  if l.length() > 3 {
    self.punct("[")
    self.p.indent(indent_level, () => {
      self.newline()
      self.list_commasep(l, i => self.instr(Instruction, i))
    })
    self.newline()
    self.punct("]")
  } else {
    self.punct("[")
    self.p.box(() => self.list_commasep(l, i => self.instr(Instruction, i)))
    self.punct("]")
  }
}

///|
/// One data segment inside a memory definition.
fn Ctx::memdata(
  self : Ctx[@basic.Location],
  d : @ast.MemData[@basic.Location],
) -> Unit {
  self.p.box(indent=indent_level, () => {
    self.p.hbox(() => {
      self.kw("data")
      self.space()
      self.data_name(d.data_name)
      self.space()
      self.op("@")
    })
    self.square_instr(d.offset, leading_space=true)
    if d.init.length() > 0 {
      self.p.hbox(() => {
        self.space()
        self.punct("=")
      })
      self.space()
      self.data_init(d.init)
    }
    self.semicolon()
  })
}

///|
/// One entry of an import block.
fn Ctx::import_decl(
  self : Ctx[@basic.Location],
  decl : @ast.ImportDecl,
) -> Unit {
  self.attr_prefix(decl.attributes, () => {
    self.p.box(indent=indent_level, () => {
      match decl.kind {
        Func(typ~, sign~, exact~) =>
          self.fundecl(decl.id, typ, sign, tag=false, exact~)
        Global(mut_~, typ~) => {
          self.kw(if mut_ { "let" } else { "const" })
          self.space()
          self.ident(decl.id.name)
          self.punct(":")
          self.space()
          self.valtype(typ)
        }
        Tag(typ~, sign~) => self.fundecl(decl.id, typ, sign, tag=true)
        Memory(address_type~, limits~, page_size_log2~, shared~) => {
          self.kw("memory")
          self.space()
          self.ident(decl.id.name)
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
        }
        Table(address_type~, reftype~, limits~) => {
          self.kw("table")
          self.space()
          self.ident(decl.id.name)
          self.punct(":")
          self.space()
          match address_type {
            I32 => ()
            I64 => {
              self.kw("i64")
              self.space()
            }
          }
          self.reftype(reftype)
          self.print_limits(limits)
        }
      }
      self.semicolon()
    })
  })
}
