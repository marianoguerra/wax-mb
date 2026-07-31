// Shared shapes the instruction cases build on.

///|
/// `br 'label [value]` and friends.
fn Ctx::branch_instr(
  self : Ctx[@basic.Location],
  name : String,
  label : @ast.Ident,
  operand : @ast.Instr[@basic.Location]?,
) -> Unit {
  self.p.box(indent=indent_level, () => {
    self.kw(name)
    self.space()
    self.ident("'")
    self.ident(label.name)
    match operand {
      Some(i) => {
        self.space()
        self.instr(Branch, i)
      }
      None => ()
    }
  })
}

///|
/// `br_on_cast 'label &t value`.
fn Ctx::branch_ref_instr(
  self : Ctx[@basic.Location],
  name : String,
  label : @ast.Ident,
  ty : @ast.RefType,
  operand : @ast.Instr[@basic.Location],
) -> Unit {
  self.p.box(indent=indent_level, () => {
    self.kw(name)
    self.space()
    self.ident("'")
    self.ident(label.name)
    self.space()
    self.reftype(ty)
    self.space()
    self.instr(Branch, operand)
  })
}

///|
/// `[?]descriptor(d)` -- the target-spec of the custom-descriptors
/// instructions.
///
/// The target type is recovered from `d`'s descriptor type, so only the operand
/// is written; a leading `?` marks a nullable result. The parentheses let `d` be
/// any expression with no precedence clash.
fn Ctx::descriptor_operand(
  self : Ctx[@basic.Location],
  d : @ast.Instr[@basic.Location],
  nullable? : Bool = false,
) -> Unit {
  if nullable {
    self.punct("?")
  }
  self.kw("descriptor")
  self.punct("(")
  self.p.box(() => self.instr(Instruction, d))
  self.punct(")")
}

///|
/// As `branch_ref_instr`, for the custom-descriptors branch forms: the
/// target-spec precedes the value, so the value is the sole trailing operand.
fn Ctx::branch_ref_desc_instr(
  self : Ctx[@basic.Location],
  name : String,
  label : @ast.Ident,
  nullable : Bool,
  operand : @ast.Instr[@basic.Location],
  d : @ast.Instr[@basic.Location],
) -> Unit {
  self.p.box(indent=indent_level, () => {
    self.kw(name)
    self.space()
    self.ident("'")
    self.ident(label.name)
    self.space()
    self.descriptor_operand(d, nullable~)
    self.space()
    self.instr(Branch, operand)
  })
}

///|
/// A call, optionally prefixed by `become`.
fn Ctx::call_instr(
  self : Ctx[@basic.Location],
  callee : @ast.Instr[@basic.Location],
  args : Array[@ast.Instr[@basic.Location]],
  prefix? : String? = None,
) -> Unit {
  self.p.hvbox(() => {
    // The prefix and the callee stay glued to the opening `(`: only the
    // argument list may break.
    self.p.hbox(() => {
      match prefix {
        Some(s) => {
          self.kw(s)
          self.space()
        }
        None => ()
      }
      self.instr(CallAndFieldAccess, callee)
    })
    self.arg_list(args, a => self.instr(Instruction, a))
  })
}

///|
/// A braced or bracketed container with an optional `type|` prefix.
fn Ctx::container(
  self : Ctx[@basic.Location],
  opening : String,
  closing : String,
  opt_type : @ast.Ident?,
  f : () -> Unit,
  indent? : Int = 0,
) -> Unit {
  self.p.hvbox(indent~, () => {
    self.p.box(() => {
      self.punct(opening)
      match opt_type {
        Some(t) => {
          self.ident(t.name)
          self.punct("|")
        }
        None => ()
      }
    })
    f()
    self.punct(closing)
  })
}

///|
fn Ctx::struct_instr(
  self : Ctx[@basic.Location],
  nm : @ast.Ident?,
  f : () -> Unit,
) -> Unit {
  self.container("{", "}", nm, () => {
    self.p.indent(indent_level, () => {
      self.space()
      f()
    })
    self.space()
  })
}

///|
/// As `struct_instr`, but with a leading `descriptor(d)` target-spec instead of
/// a type name; the struct type is recovered from `d`.
fn Ctx::struct_desc_instr(
  self : Ctx[@basic.Location],
  print_desc : () -> Unit,
  f : () -> Unit,
) -> Unit {
  self.p.hvbox(() => {
    self.p.box(() => {
      self.punct("{")
      self.space()
      print_desc()
      self.punct("|")
    })
    self.p.indent(indent_level, () => {
      self.space()
      f()
    })
    self.space()
    self.punct("}")
  })
}

///|
/// An array literal.
///
/// The elements indent one level and the closing `]` breaks at the array's own
/// column, so a wrapped array dedents its bracket rather than letting it hug
/// the last element.
fn Ctx::array_instr(
  self : Ctx[@basic.Location],
  nm : @ast.Ident?,
  f : () -> Unit,
) -> Unit {
  self.container("[", "]", nm, () => {
    self.p.indent(indent_level, () => {
      self.cut()
      f()
    })
    self.cut()
  })
}

///|
/// One field of a struct literal.
///
/// A `None` value is the punning shorthand `{x}`, which must print back as
/// written rather than being expanded to `{x: x}`.
fn Ctx::struct_field_kv(
  self : Ctx[@basic.Location],
  nm : @ast.Ident,
  v : @ast.Instr[@basic.Location]?,
) -> Unit {
  match v {
    Some(i) => self.key_value(nm.name, i, x => self.instr(Instruction, x))
    None => self.ident(nm.name)
  }
}

///|
/// The receiver of a field access.
///
/// Printed at CallAndFieldAccess so `(a + b).x` keeps its parentheses.
fn Ctx::field_receiver(
  self : Ctx[@basic.Location],
  i : @ast.Instr[@basic.Location],
) -> Unit {
  self.instr(CallAndFieldAccess, i)
}

///|
/// A `match` arm pattern.
fn Ctx::match_pattern(
  self : Ctx[@basic.Location],
  pat : @ast.MatchPattern,
) -> Unit {
  match pat {
    MatchCast(bind, ty) => {
      match bind {
        Some(x) => {
          self.ident(x.name)
          self.punct(":")
          self.space()
        }
        None => ()
      }
      self.reftype(ty)
    }
    MatchNull => self.kw("null")
  }
}

///|
/// The comma-separated case labels of a br_table/dispatch bracket, ending in
/// the mandatory `else <default>`.
fn Ctx::label_seq(
  self : Ctx[@basic.Location],
  cases : Array[@ast.Ident],
  default : @ast.Ident,
) -> Unit {
  for c in cases {
    self.ident("'")
    self.ident(c.name)
    self.punct(",")
    self.space()
  }
  self.kw("else")
  self.space()
  self.ident("'")
  self.ident(default.name)
}

///|
/// A bracketed label list, indented and with its `]` dedented to the
/// construct's own column.
fn Ctx::bracketed_labels(
  self : Ctx[@basic.Location],
  before : () -> Unit,
  cases : Array[@ast.Ident],
  default : @ast.Ident,
  after? : () -> Unit = () => (),
) -> Unit {
  self.p.hvbox(() => {
    self.p.box(() => {
      before()
      self.punct("[")
    })
    self.p.indent(indent_level, () => {
      self.cut()
      self.p.box(() => self.label_seq(cases, default))
    })
    self.cut()
    self.punct("]")
    after()
  })
}

///|
/// The postfix `on [tag -> 'label, ...]` handler clause.
fn Ctx::on_clauses(
  self : Ctx[@basic.Location],
  handlers : Array[@ast.OnClause],
) -> Unit {
  self.space()
  self.kw("on")
  self.space()
  self.punct("[")
  self.p.indent(indent_level, () => {
    self.cut()
    self.list_commasep(handlers, h => {
      self.p.box(() => {
        match h {
          OnLabel(tag, label) => {
            self.ident(tag.name)
            self.space()
            self.punct("->")
            self.space()
            self.ident("'")
            self.ident(label.name)
          }
          OnSwitch(tag) => {
            self.ident(tag.name)
            self.space()
            self.punct("->")
            self.space()
            self.kw("switch")
          }
        }
      })
    })
  })
  self.cut()
  self.punct("]")
}

///|
/// All but the last element: the non-receiver operands of a stack-switching
/// method call, which prints its receiver first.
fn drop_last(
  l : Array[@ast.Instr[@basic.Location]],
) -> Array[@ast.Instr[@basic.Location]] {
  if l.length() == 0 {
    []
  } else {
    l[:l.length() - 1].to_owned()
  }
}
