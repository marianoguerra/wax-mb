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
///
/// A bare numeric literal receiver is parenthesised whatever its precedence
/// says: `2.rotl(3)` would lex `2.` as a float, so the printed form has to be
/// `(2).rotl(3)`.
fn Ctx::field_receiver(
  self : Ctx[@basic.Location],
  i : @ast.Instr[@basic.Location],
) -> Unit {
  match i.desc {
    Int(_) | Float(_) => {
      self.punct("(")
      self.p.box(() => {
        self.instr(Instruction, i)
        self.punct(")")
      })
    }
    _ => self.instr(CallAndFieldAccess, i)
  }
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
///
/// The brackets are padded with SOFT SPACES, not zero-width cuts, so an
/// inline list reads `[ 'a, else 'out ]`; when it does not fit, those same
/// separators become the breaks that put the labels on their own indented
/// line. The head and the `]`-plus-suffix are each glued into an hbox so
/// neither `dispatch x [` nor `] {` can be split.
fn Ctx::bracketed_labels(
  self : Ctx[@basic.Location],
  before : () -> Unit,
  cases : Array[@ast.Ident],
  default : @ast.Ident,
  after? : () -> Unit = () => (),
) -> Unit {
  self.p.hvbox(() => {
    self.p.hbox(() => {
      before()
      self.punct("[")
    })
    self.p.indent(indent_level, () => {
      self.space()
      self.p.box(() => self.label_seq(cases, default))
    })
    self.space()
    self.p.hbox(() => {
      self.punct("]")
      after()
    })
  })
}

///|
/// The bracketed `[tag -> 'label, ...]` handler list.
///
/// One plain box, with no indent and no cuts: the list packs and wraps as a
/// unit rather than each handler landing on its own line.
fn Ctx::on_clauses(
  self : Ctx[@basic.Location],
  handlers : Array[@ast.OnClause],
) -> Unit {
  self.punct("[")
  self.p.box(() => {
    self.list_commasep(handlers, h => {
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

///|
/// A continuation CONSTRUCTOR, `t::new(x)` / `t::bind(a, b)`.
fn Ctx::cont_construct_instr(
  self : Ctx[@basic.Location],
  ct : @ast.Ident,
  member_name : String,
  l : Array[@ast.Instr[@basic.Location]],
) -> Unit {
  self.p.box(indent=indent_level, () => {
    self.p.hbox(() => {
      self.ident(ct.name)
      self.op("::")
      self.ident(member_name)
    })
    self.arg_list(l, i => self.instr(Instruction, i))
  })
}

///|
/// A stack-switching METHOD call, `recv.meth(args...) on [handlers]`.
///
/// The receiver is the LAST operand of `l` -- wasm stack order, so it compiles
/// last, exactly as `call_ref`'s callee does -- and prints first. `args` is a
/// list of thunks rather than instructions, so `resume_throw`'s `tag(payload)`
/// and `switch`'s `tag: t` need no AST form of their own.
fn Ctx::cont_method_instr(
  self : Ctx[@basic.Location],
  meth : String,
  l : Array[@ast.Instr[@basic.Location]],
  args : Array[() -> Unit],
  handlers : Array[@ast.OnClause],
) -> Unit {
  self.p.box(indent=indent_level, () => {
    self.p.hvbox(() => {
      self.p.hbox(() => {
        if l.length() > 0 {
          self.instr(CallAndFieldAccess, l[l.length() - 1])
        } else {
          // An ill-formed operand list: print a hole rather than nothing, so
          // recovery output stays readable.
          self.op("_")
        }
        self.punct(".")
        self.ident(meth)
      })
      self.arg_list(args, g => g())
    })
    if handlers.length() > 0 {
      self.space()
      self.kw("on")
      self.space()
      self.on_clauses(handlers)
    }
  })
}

///|
/// The head of a `try`-family construct: `'label try [blocktype] {`.
fn Ctx::try_head(
  self : Ctx[@basic.Location],
  label : @ast.Ident?,
  kw : String,
  typ : @ast.FuncType,
) -> Unit {
  self.p.box(() => {
    self.block_label(label)
    self.kw(kw)
    self.space()
    if need_blocktype(typ) {
      self.blocktype(typ)
      self.space()
    }
    self.punct("{")
  })
}

///|
/// The `} catch <open>` hinge between a try body and its handlers.
///
/// The body's trailing comments print between the `}` and the `catch`, where
/// they were written.
fn Ctx::catch_hinge(
  self : Ctx[@basic.Location],
  block_after : Array[@trivia.Entry],
  opening : String,
) -> Unit {
  self.p.box(() => {
    self.punct("}")
    self.print_trivia(block_after)
    self.space()
    self.kw("catch")
    self.space()
    self.punct(opening)
  })
}

///|
/// One `pattern => { ... }` arm.
fn Ctx::braced_arm(
  self : Ctx[@basic.Location],
  head : () -> Unit,
  body : @ast.Body[@basic.Location],
) -> Unit {
  self.p.hvbox(() => {
    self.p.box(() => {
      head()
      self.space()
      self.punct("=>")
      self.space()
      self.punct("{")
    })
    let after = self.located_block_contents(body)
    self.close_block(after)
  })
}
