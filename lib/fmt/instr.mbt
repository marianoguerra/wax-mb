// The instruction printer.
//
// Ported from `instr` in wax/src/lib-wax/output.ml. Every instruction routes
// through `instr`, which looks up the node's trivia, parenthesises it if the
// context binds tighter than it does, emits any hint attributes, and then
// dispatches on the form.

///|
/// Print one instruction at the precedence `prec` demands.
pub fn Ctx::instr(
  self : Ctx[@basic.Location],
  prec : Prec,
  i : @ast.Instr[@basic.Location],
) -> Unit {
  self.atomic_node((self.locate)(i.info), () => {
    self.parenthesized(prec, get_prec(i), () => {
      self.hint_attrs(i)
      self.instr_desc(i)
    })
  })
}

///|
/// A brace-delimited block: `label: kind blocktype { body }`.
fn Ctx::block(
  self : Ctx[@basic.Location],
  label : @ast.Ident?,
  kind : String?,
  bt : @ast.FuncType,
  l : @ast.Body[@basic.Location],
) -> Unit {
  self.p.hvbox(() => {
    self.p.box(() => {
      self.block_label(label)
      match kind {
        Some(k) => {
          self.kw(k)
          self.space()
        }
        None => ()
      }
      if need_blocktype(bt) {
        self.blocktype(bt)
        self.space()
      }
      self.punct("{")
    })
    let after = self.located_block_contents(l)
    self.close_block(after)
  })
}

///|
/// A statement, with its terminating `;` when it needs one.
fn Ctx::delimited_instr(
  self : Ctx[@basic.Location],
  i : @ast.Instr[@basic.Location],
) -> Unit {
  // A block statement needs no `;` -- its `}` ends it -- hinted or not, since a
  // statement-level hint prefixes the statement list and what follows the
  // attributes is a plain block statement.
  if is_block(i) {
    self.instr(Instruction, i)
  } else {
    // A statement that would BEGIN with a brace is printed as an atom, so it
    // gains parentheses: otherwise it would read as a block.
    self.instr(if starts_with_block(i) { Atom } else { Instruction }, i)
    // Hold any deferred trailing comment so the `;` prints on the statement's
    // line ahead of it -- `expr; // c`, not `expr // c` then a lone `;`.
    self.p.with_held_eol(() => self.punct(";"))
  }
}

///|
/// The contents of a brace-delimited block, looked up by the block's own span.
///
/// Looking it up here means a comment opening the clause attaches to the block
/// rather than to the condition, and an own-line comment trailing the last
/// statement renders INSIDE the block at statement indentation.
///
/// The block's `after` -- comments past the closing `}` -- is RETURNED rather
/// than printed, so the caller can emit it on the far side of the brace.
fn Ctx::located_block_contents(
  self : Ctx[@basic.Location],
  b : @ast.Body[@basic.Location],
) -> Array[@trivia.Entry] {
  let assoc = self.get_trivia(Some(b.info))
  self.print_trivia(assoc.before)
  if b.desc.length() > 0 || assoc.within.length() > 0 {
    // A non-empty block ALWAYS breaks across lines -- rustfmt never keeps a
    // block body on one line -- so every separator here is a hard newline.
    self.p.indent(indent_level, () => {
      for i in b.desc {
        self.newline()
        self.delimited_instr(i)
      }
      self.print_trivia(assoc.within)
    })
    self.newline()
  } else {
    // An empty body stays `{}`, but the zero-width cut lets the `}` drop to the
    // next line when the enclosing box breaks anyway -- an empty `if` body
    // beside a multi-line `else` -- rather than the head's `{` wrapping oddly.
    self.cut()
  }
  assoc.after
}

///|
/// Emit a block's closing `}` and the trailing comments the body returned.
///
/// A comment anchored past the `}` renders after it and, before an
/// `else`/`catch` continuation, back between the `}` and that keyword -- where
/// it was written.
fn Ctx::close_block(
  self : Ctx[@basic.Location],
  after : Array[@trivia.Entry],
) -> Unit {
  self.punct("}")
  self.print_trivia(after)
}

///|
/// Dispatch on the instruction form.
fn Ctx::instr_desc(
  self : Ctx[@basic.Location],
  i : @ast.Instr[@basic.Location],
) -> Unit {
  match i.desc {
    // -- leaves ------------------------------------------------------------
    Unreachable => self.kw("unreachable")
    // `nop` is an OPERATOR, not a keyword, in the reference's palette.
    Nop => self.op("nop")
    Hole => self.op("_")
    Null => self.kw("null")
    Get(x) => self.ident(x.name)
    Path(ns, mem) => {
      self.ident(ns.name)
      self.op("::")
      self.ident(mem.name)
    }
    // Numeric literals are reproduced from their RAW source text, which is why
    // the AST keeps them as strings.
    Int(s) => self.constant(s)
    Float(s) => self.constant(s)
    Char(c) => {
      // Like a string literal: three atoms in the STRING style, the middle one
      // carrying the escaped form's display width.
      let (len, body) = @unicode.escape_string(
        @utf8.encode(c.to_string()),
        hex_prefix="x",
      )
      self.str("'")
      self.styled_as(Str, len, body)
      self.str("'")
    }
    Str(prefix, s) => {
      match prefix {
        Some(t) => {
          self.typ(t.name)
          self.op("#")
        }
        None => ()
      }
      // Three atoms, and the middle one carries the ESCAPED form's display
      // width: `\x00` occupies four columns while standing for one byte, and
      // it is the printed width that line breaking must count.
      let (len, body) = @unicode.escape_string(s, hex_prefix="x")
      self.str("\"")
      self.styled_as(Str, len, body)
      self.str("\"")
    }

    // -- structured control flow --------------------------------------------
    // A plain block is always introduced by `do`. A bare or labelled `{ ... }`
    // also parses, but `do` is the canonical form.
    Block(label~, typ~, block~) => self.block(label, Some("do"), typ, block)
    Loop(label~, typ~, block~) => self.block(label, Some("loop"), typ, block)
    While(label~, cond~, step~, block~) =>
      self.p.hvbox(() => {
        self.p.box(() => {
          self.block_label(label)
          self.kw("while")
          self.p.indent(indent_level, () => {
            self.space()
            self.instr(Instruction, cond)
            // Zig-style continue-expression: `: (step)` after the condition.
            match step {
              None => ()
              Some(s) => {
                self.space()
                self.punct(":")
                self.space()
                self.punct("(")
                self.instr(Instruction, s)
                self.punct(")")
              }
            }
          })
          self.space()
          self.punct("{")
        })
        let after = self.located_block_contents(block)
        self.close_block(after)
      })
    If(label~, typ~, cond~, if_block~, else_block~) =>
      self.p.hvbox(() => {
        self.p.box(() => {
          self.block_label(label)
          self.kw("if")
          self.p.indent(indent_level, () => {
            self.space()
            self.instr(Instruction, cond)
            if need_blocktype(typ) {
              self.space()
              self.p.box(indent=indent_level, () => {
                self.punct("=>")
                self.space()
                self.blocktype(typ)
              })
            }
          })
          self.space()
          self.punct("{")
        })
        let if_after = self.located_block_contents(if_block)
        match else_block {
          Some(eb) =>
            self.p.hvbox(() => {
              self.p.box(() => {
                self.punct("}")
                // The comment written between `}` and `else` renders there.
                self.print_trivia(if_after)
                self.space()
                self.kw("else")
                self.space()
                self.punct("{")
              })
              let else_after = self.located_block_contents(eb)
              self.close_block(else_after)
            })
          None => self.close_block(if_after)
        }
      })

    // -- operators -----------------------------------------------------------
    BinOpI(op, lhs, rhs) => {
      let (_, left, right) = prec_op(op.desc)
      // The precedence lint flags a shift mixed with arithmetic, or a
      // comparison with a bitwise operator, written without parentheses --
      // precedence alone would not require them. Demand an Atom there so
      // reprinted Wax stays quiet under the project's own lint.
      let operand_prec = fn(
        default : Prec,
        child : @ast.Instr[@basic.Location],
      ) -> Prec {
        match child.desc {
          BinOpI(child_op, _, _) =>
            if confusing_precedence(
                binop_kind(op.desc),
                binop_kind(child_op.desc),
              ) {
              Atom
            } else {
              default
            }
          _ => default
        }
      }
      self.p.box(indent=indent_level, () => {
        self.instr(operand_prec(left, lhs), lhs)
        // Break BEFORE the operator (rustfmt style: a wrapped operator leads
        // its continuation line), so only the space ahead of it may break; the
        // space after it is a plain, non-breaking blank. The operator carries
        // its own span, so a comment between the left operand and it attaches
        // to the operand, ahead of the break.
        self.space()
        self.atomic_node(Some(op.info), () => self.op(binop_str(op.desc)))
        self.p.string(" ")
        self.instr(operand_prec(right, rhs), rhs)
      })
    }
    UnOpI(op, operand) => {
      self.atomic_node(Some(op.info), () => self.op(unop_str(op.desc)))
      self.instr(UnaryPrefix, operand)
    }

    // -- assignment ----------------------------------------------------------
    Set(x, op, v) =>
      self.p.box(indent=indent_level, () => {
        self.ident(x.name)
        self.space()
        // `x op= e` for a compound assignment; a plain `=` otherwise.
        self.op(
          match op {
            None => "="
            Some(o) => binop_str(o.desc) + "="
          },
        )
        self.space()
        self.instr(Instruction, v)
      })
    Tee(x, v) =>
      self.p.box(indent=indent_level, () => {
        self.ident(x.name)
        self.space()
        self.op(":=")
        self.space()
        self.instr(Instruction, v)
      })

    // -- calls ---------------------------------------------------------------
    Call(callee, args) => self.call_instr(callee, args)
    TailCall(callee, args) =>
      self.call_instr(callee, args, prefix=Some("become"))
    Labelled(l, v) => self.key_value(l.name, v, x => self.instr(Instruction, x))

    // -- casts and tests -----------------------------------------------------
    Cast(v, t) =>
      self.p.box(indent=indent_level, () => {
        self.instr(Cast, v)
        self.space()
        self.p.box(() => {
          self.kw("as")
          self.space()
          self.casttype(t)
        })
      })
    CastDesc(v, nullable, d) =>
      self.p.box(indent=indent_level, () => {
        self.instr(Cast, v)
        self.space()
        self.p.box(() => {
          self.kw("as")
          self.space()
          self.descriptor_operand(d, nullable~)
        })
      })
    Test(v, t) =>
      self.p.box(indent=indent_level, () => {
        self.instr(Cast, v)
        self.space()
        self.p.box(() => {
          self.kw("is")
          self.space()
          self.reftype(t)
        })
      })
    NonNull(v) => {
      self.instr(UnaryPostfix, v)
      self.op("!")
    }

    // -- aggregates ----------------------------------------------------------
    Struct(nm, fields) =>
      self.struct_instr(nm, () => {
        self.list_commasep_trailing(fields, f => self.struct_field_kv(f.0, f.1))
      })
    StructDefault(nm) => self.struct_instr(nm, () => self.punct(".."))
    StructDesc(d, fields) =>
      self.struct_desc_instr(() => self.descriptor_operand(d), () => {
        self.list_commasep_trailing(fields, f => self.struct_field_kv(f.0, f.1))
      })
    StructDefaultDesc(d) =>
      self.struct_desc_instr(() => self.descriptor_operand(d), () => {
        self.punct("..")
      })
    StructGet(recv, field) => {
      self.field_receiver(recv)
      self.op(".")
      self.ident(field.name)
    }
    GetDescriptor(recv) => {
      self.field_receiver(recv)
      self.op(".")
      self.kw("descriptor")
    }
    StructSet(recv, field, v) =>
      self.p.box(indent=indent_level, () => {
        self.field_receiver(recv)
        self.op(".")
        self.ident(field.name)
        self.space()
        self.op("=")
        self.space()
        self.instr(Instruction, v)
      })
    ArrayGet(recv, idx) =>
      // The zero-width cut lets a long index break onto its own line, taking
      // the whole `[...]` with it rather than splitting inside the brackets.
      self.p.box(indent=indent_level, () => {
        self.instr(CallAndFieldAccess, recv)
        self.cut()
        self.p.box(() => {
          self.op("[")
          self.instr(Instruction, idx)
          self.op("]")
        })
      })
    ArraySet(recv, idx, v) =>
      self.p.box(indent=indent_level, () => {
        self.instr(CallAndFieldAccess, recv)
        self.cut()
        self.p.box(() => {
          self.op("[")
          self.instr(Instruction, idx)
          self.op("]")
        })
        self.space()
        self.op("=")
        self.space()
        self.instr(Instruction, v)
      })

    // -- branches ------------------------------------------------------------
    Br(l, v) => self.branch_instr("br", l, v)
    BrIf(l, v) => self.branch_instr("br_if", l, Some(v))
    BrOnNull(l, v) => self.branch_instr("br_on_null", l, Some(v))
    BrOnNonNull(l, v) => self.branch_instr("br_on_non_null", l, Some(v))
    BrOnCast(l, t, v) => self.branch_ref_instr("br_on_cast", l, t, v)
    BrOnCastFail(l, t, v) => self.branch_ref_instr("br_on_cast_fail", l, t, v)
    BrOnCastDescEq(l, n, v, d) =>
      self.branch_ref_desc_instr("br_on_cast", l, n, v, d)
    BrOnCastDescEqFail(l, n, v, d) =>
      self.branch_ref_desc_instr("br_on_cast_fail", l, n, v, d)
    Return(v) =>
      self.p.box(indent=indent_level, () => {
        self.kw("return")
        match v {
          Some(x) => {
            self.space()
            self.instr(Branch, x)
          }
          None => ()
        }
      })
    // Call-like: `throw tag(x, y)`.
    Throw(tag, args) =>
      self.p.hvbox(() => {
        self.p.hbox(() => {
          self.kw("throw")
          self.space()
          self.ident(tag.name)
        })
        self.arg_list(args, a => self.instr(Instruction, a))
      })
    ThrowRef(v) =>
      self.p.box(indent=indent_level, () => {
        self.kw("throw_ref")
        self.space()
        self.instr(Branch, v)
      })

    // -- bindings ------------------------------------------------------------
    Let(binds, init) =>
      if binds.length() == 1 && binds[0].0 is None && init is Some(_) {
        // An anonymous binding is a DISCARDED value: printed `_ = e`, or
        // `_: t = e` when the width annotation is load-bearing -- without
        // `let`, since nothing is bound. Mirrors the Set layout.
        let typ = binds[0].1
        let v = match init {
          Some(x) => x
          None => panic()
        }
        self.p.box(indent=indent_level, () => {
          self.p.hbox(() => {
            self.op("_")
            match typ {
              Some(t) => {
                self.punct(":")
                self.space()
                self.valtype(t)
              }
              None => ()
            }
            self.space()
            self.op("=")
          })
          self.space()
          self.instr(Instruction, v)
        })
      } else {
        self.p.box(indent=indent_level, () => {
          // Keep `let pat =` together as one unit: when the value breaks the
          // line after `=`, without this box the outer box would also split
          // `let`/`pat`/`=` across lines.
          self.p.hbox(() => {
            self.kw("let")
            self.space()
            if binds.length() == 1 {
              self.typed_pat(binds[0].0, binds[0].1)
            } else {
              self.paren_list(binds, b => self.typed_pat(b.0, b.1))
            }
            if init is Some(_) {
              self.space()
              self.kw("=")
            }
          })
          match init {
            Some(v) => {
              self.space()
              self.instr(Instruction, v)
            }
            None => ()
          }
        })
      }

    // -- misc ----------------------------------------------------------------
    Sequence(items) => self.paren_list(items, x => self.instr(Instruction, x))
    Select(c, a, b) =>
      // No spaces around `?` and `:`: the separators are zero-width cuts, so a
      // ternary prints as `x?1:2` when it fits and breaks AT the operators when
      // it does not. Both branches print at Assignement, not at Select.
      self.p.box(indent=indent_level, () => {
        self.instr(Comparison, c)
        self.cut()
        self.op("?")
        self.instr(Assignement, a)
        self.cut()
        self.op(":")
        self.instr(Assignement, b)
      })
    On(v, handlers) =>
      self.p.box(indent=indent_level, () => {
        self.instr(Cast, v)
        self.space()
        self.kw("on")
        self.space()
        self.on_clauses(handlers)
      })

    // -- exception handling --------------------------------------------------
    TryCatch(label~, typ~, block~, arms~) =>
      self.p.hvbox(() => {
        self.try_head(label, "try", typ)
        let block_after = self.located_block_contents(block)
        self.p.hvbox(() => {
          self.catch_hinge(block_after, "{")
          // Like a block body, a non-empty `catch` always lays its arms out
          // vertically with hard newlines, matching `match` and `dispatch`; an
          // empty one stays `{}`.
          if arms.length() > 0 {
            self.p.indent(indent_level, () => {
              for arm in arms {
                self.newline()
                self.braced_arm(
                  () => {
                    match arm.arm_tag {
                      Some(tag) => self.ident(tag.name)
                      None => self.op("_")
                    }
                    // A `&` arm, which is delivered the exception reference above
                    // the payload.
                    if arm.arm_ref {
                      self.space()
                      self.op("&")
                    }
                  },
                  arm.arm_body,
                )
              }
            })
            // The break before the closing `}` sits OUTSIDE the indent above,
            // so it lands at the catch block's own column.
            self.newline()
          }
          self.punct("}")
        })
      })
    Try(label~, typ~, block~, catches~, catch_all~) =>
      self.p.hvbox(() => {
        self.try_head(label, "try_legacy", typ)
        let block_after = self.located_block_contents(block)
        self.p.hvbox(() => {
          self.catch_hinge(block_after, "{")
          if catches.length() > 0 || catch_all is Some(_) {
            self.p.indent(indent_level, () => {
              for c in catches {
                let (tag, body) = c
                self.newline()
                self.braced_arm(() => self.ident(tag.name), body)
              }
              match catch_all {
                Some(body) => {
                  self.newline()
                  self.braced_arm(() => self.op("_"), body)
                }
                None => ()
              }
            })
            self.newline()
          }
          self.punct("}")
        })
      })
    TryTable(label~, typ~, catches~, block~) =>
      self.p.hvbox(() => {
        self.try_head(label, "try", typ)
        let block_after = self.located_block_contents(block)
        self.p.hvbox(() => {
          self.catch_hinge(block_after, "[")
          self.p.indent(indent_level, () => {
            let last = catches.length() - 1
            for i, c in catches {
              self.space()
              self.p.box(() => {
                // A `&` handler takes the exception reference as well as the
                // payload; `_` is the catch-all.
                let (tag, ref_, label2) = match c {
                  Catch(t, l2) => (Some(t), false, l2)
                  CatchRef(t, l2) => (Some(t), true, l2)
                  CatchAll(l2) => (None, false, l2)
                  CatchAllRef(l2) => (None, true, l2)
                }
                match tag {
                  Some(t) => self.ident(t.name)
                  None => self.op("_")
                }
                self.space()
                if ref_ {
                  self.op("&")
                  self.space()
                }
                self.punct("->")
                self.space()
                self.ident("'")
                self.ident(label2.name)
                if i < last {
                  self.punct(",")
                }
              })
            }
          })
          // Break before the closing `]` so a wrapped handler list dedents it
          // to the `try`'s column rather than hugging the last handler.
          self.cut()
          self.punct("]")
        })
      })
    // -- multi-way branches --------------------------------------------------
    BrTable(labels, v) => {
      // The default is the LAST label; the rest are the indexed cases.
      let default = labels[labels.length() - 1]
      let cases = labels[:labels.length() - 1].to_owned()
      self.p.box(indent=indent_level, () => {
        self.bracketed_labels(
          () => {
            self.kw("br_table")
            self.space()
          },
          cases,
          default,
        )
        self.space()
        self.instr(Branch, v)
      })
    }
    Dispatch(index~, cases~, default~, arms~) =>
      self.p.hvbox(() => {
        // Head: `dispatch <index> [ <labels> else <default> ] {`, on one line
        // or, when too wide, with the labels filled and indented and the `]`
        // dedented to the `dispatch` column.
        self.bracketed_labels(
          () => {
            self.kw("dispatch")
            self.space()
            // A non-atomic index is parenthesised: the following `[` would
            // otherwise bind to its last atom as an array access.
            self.instr(Atom, index)
            self.space()
          },
          cases,
          default,
          after=() => {
            self.space()
            self.punct("{")
          },
        )
        if arms.length() > 0 {
          self.p.indent(indent_level, () => {
            for a in arms {
              let (l, body) = a
              self.newline()
              self.block(Some(l), None, { params: [], results: [], }, body)
            }
          })
          self.newline()
        }
        self.punct("}")
      })
    Match(scrutinee~, arms~, default~) => {
      let arm = fn(
        head : () -> Unit,
        body : @ast.Body[@basic.Location],
      ) -> Unit {
        self.newline()
        self.braced_arm(head, body)
      }
      self.p.hvbox(() => {
        self.p.box(() => {
          self.kw("match")
          self.space()
          // A non-atomic scrutinee is parenthesised: the following `{` would
          // otherwise read as a struct literal or block continuation.
          self.instr(Atom, scrutinee)
          self.space()
          self.punct("{")
        })
        self.p.indent(indent_level, () => {
          for a in arms {
            let (pat, body) = a
            arm(() => self.match_pattern(pat), body)
          }
          // The default arm is compulsory, so it is always printed.
          arm(() => self.op("_"), default)
        })
        self.newline()
        self.punct("}")
      })
    }
    IfAnnotation(cond~, then_body~, else_body~) => {
      let branch = fn(body : @ast.Body[@basic.Location]) -> Unit {
        self.space()
        self.punct("{")
        let after = self.located_block_contents(body)
        self.close_block(after)
      }
      self.p.hvbox(() => {
        self.attr("#[if(" + cond_to_string(cond) + ")]")
        branch(then_body)
        match else_body {
          Some(b) => {
            self.newline()
            self.attr("#[else]")
            branch(b)
          }
          None => ()
        }
      })
    }

    // -- array literals ------------------------------------------------------
    Array(nm, elem, n) =>
      self.array_instr(nm, () => {
        self.instr(array_element_precedence(nm, true, elem), elem)
        self.punct(";")
        self.space()
        self.instr(Instruction, n)
      })
    ArrayDefault(nm, n) =>
      self.array_instr(nm, () => {
        self.punct("..;")
        self.space()
        self.instr(Instruction, n)
      })
    ArrayFixed(nm, elems) =>
      self.array_instr(nm, () => {
        self.list_commasep_trailing(elems.mapi((n, i) => (n == 0, i)), pair => {
          let (first, i) = pair
          self.instr(array_element_precedence(nm, first, i), i)
        })
      })
    ArraySegment(nm, d, off, len) =>
      self.p.hvbox(() => {
        self.p.box(() => {
          self.punct("[")
          match nm {
            Some(t) => {
              self.ident(t.name)
              self.punct("|")
            }
            None => ()
          }
          self.space()
          self.ident(d.name)
          self.space()
          self.op("@")
        })
        self.p.indent(indent_level, () => {
          self.space()
          self.instr(Instruction, off)
        })
        self.punct(";")
        self.p.indent(indent_level, () => {
          self.space()
          self.instr(Instruction, len)
        })
        self.cut()
        self.punct("]")
      })

    // -- stack switching -----------------------------------------------------
    ContNew(ct, v) => self.cont_construct_instr(ct, "new", [v])
    // The SOURCE continuation type is inferred from the last operand's static
    // type, so only the destination -- the namespace -- is written.
    ContBind(_, dst, l) => self.cont_construct_instr(dst, "bind", l)
    Suspend(tag, l) =>
      self.p.box(indent=indent_level, () => {
        self.kw("suspend")
        self.space()
        self.ident(tag.name)
        self.cut()
        self.paren_list(l, i => self.instr(Instruction, i))
      })
    // The type immediate of the resume family and of `switch` is inferred from
    // the receiver's static type, so it is never written.
    Resume(_, handlers, l) =>
      self.cont_method_instr(
        "resume",
        l,
        drop_last(l).map(a => () => self.instr(Instruction, a)),
        handlers,
      )
    ResumeThrow(_, tag, handlers, l) =>
      // The tag is invoked with its payload, `c.resume_throw(exc(p))`, exactly
      // as `throw exc(p)` spells it.
      self.cont_method_instr(
        "resume_throw",
        l,
        [
          () => {
            self.p.box(indent=indent_level, () => {
              self.ident(tag.name)
              self.arg_list(drop_last(l), a => self.instr(Instruction, a))
            })
          },
        ],
        handlers,
      )
    ResumeThrowRef(_, handlers, l) =>
      self.cont_method_instr(
        "resume_throw_ref",
        l,
        drop_last(l).map(a => () => self.instr(Instruction, a)),
        handlers,
      )
    Switch(_, tag, l) =>
      self.cont_method_instr(
        "switch",
        l,
        [
          ..drop_last(l).map(a => () => self.instr(Instruction, a)),
          () => self.key_value("tag", tag, t => self.ident(t.name)),
        ],
        [],
      )
  }
}

///|
/// The hint attributes prefixing an instruction.
fn Ctx::hint_attrs(
  self : Ctx[@basic.Location],
  i : @ast.Instr[@basic.Location],
) -> Unit {
  match i.hints.branch {
    Some(h) => {
      self.attr(if h.value { "#[likely]" } else { "#[unlikely]" })
      self.space()
    }
    None => ()
  }
  match i.hints.freq {
    Some(h) => {
      // The reserved values print as their own keywords; any other byte stands
      // for an executions-per-call ratio.
      if h.value == never_opt {
        self.attr("#[never_opt]")
      } else if h.value == always_opt {
        self.attr("#[always_opt]")
      } else {
        self.attr("#[freq = " + freq_ratio_string(h.value) + "]")
      }
      self.space()
    }
    None => ()
  }
  match i.hints.targets {
    Some(h) => {
      let parts = []
      for t in h.value {
        parts.push(t.0.name + ": " + percent_string(t.1))
      }
      // Three atoms rather than one string: the opening, each target, and the
      // close are emitted separately, exactly as the reference does.
      self.attr("#[targets(")
      for n, part in parts {
        if n > 0 {
          self.attr(", ")
        }
        self.attr(part)
      }
      self.attr(")]")
      self.space()
    }
    None => ()
  }
}

///|
/// `metadata.code.instr_freq`: never optimize.
let never_opt : Int = 0

///|
/// `metadata.code.instr_freq`: always optimize.
let always_opt : Int = 127

///|
/// Decode a frequency byte back to the ratio it stands for.
fn freq_ratio_string(f : Int) -> String {
  // The byte is an offset base-2 logarithm, so 32 means once per call.
  let e = f - 32
  if e >= 0 {
    (1 << e).to_string()
  } else {
    // A fractional ratio: print it so it reads back as the same value.
    let denom = 1 << -e
    "1/" + denom.to_string()
  }
}

///|
fn percent_string(p : Int) -> String {
  if p % 100 == 0 {
    (p / 100).to_string()
  } else {
    let frac = p % 100
    if frac % 10 == 0 {
      "0." + (frac / 10).to_string()
    } else {
      "0." + (if frac < 10 { "0" } else { "" }) + frac.to_string()
    }
  }
}
