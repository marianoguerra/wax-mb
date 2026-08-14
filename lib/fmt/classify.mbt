// Classifying instructions: how tightly one binds, and whether it opens with a
// brace.

///|
/// The precedence an instruction produces.
fn[Info] get_prec(i : @ast.Instr[Info]) -> Prec {
  // A hint attribute is parsed at the LOOSEST precedence -- it takes the whole
  // expression that follows it -- so a hinted instruction in a tighter context
  // must be parenthesised however tightly its own desc would bind.
  if !i.hints.is_empty() {
    return Instruction
  }
  match i.desc {
    Block(..)
    | Loop(..)
    | While(..)
    | If(..)
    | Try(..)
    | TryCatch(..)
    | TryTable(..)
    | IfAnnotation(..)
    | Dispatch(..)
    | Match(..) => Atom
    Unreachable
    | Nop
    | Hole
    | Null
    | Get(_)
    | Path(_)
    | Char(_)
    | Str(_)
    | Int(_)
    | Float(_)
    | Struct(_)
    | StructDefault(_)
    | StructDesc(_)
    | StructDefaultDesc(_)
    | Array(_)
    | ArrayDefault(_)
    | ArrayFixed(_)
    | ArraySegment(_)
    | ArrayGet(_)
    | Sequence(_) => Atom
    ArraySet(_) | Set(_) | Tee(_) => Assignement
    Call(_) | TailCall(_) => CallAndFieldAccess
    ContNew(_) | ContBind(_) | Suspend(_) | Switch(_) => CallAndFieldAccess
    // A resume-family instruction carrying handlers has a postfix `on` clause,
    // which binds like `as`/`is`.
    Resume(_, h, _) | ResumeThrow(_, _, h, _) | ResumeThrowRef(_, h, _) =>
      if h.is_empty() {
        CallAndFieldAccess
      } else {
        Cast
      }
    On(_) => Cast
    Cast(_) | CastDesc(_) | Test(_) => Cast
    NonNull(_) => UnaryPostfix
    UnOpI(_) => UnaryPrefix
    StructGet(_) | StructSet(_) | GetDescriptor(_) => CallAndFieldAccess
    BinOpI(op, _, _) => {
      let (out, _, _) = prec_op(op.desc)
      out
    }
    Let(_) | Labelled(_) => Instruction
    Br(_)
    | BrIf(_)
    | BrTable(_)
    | BrOnNull(_)
    | BrOnNonNull(_)
    | BrOnCast(_)
    | BrOnCastFail(_)
    | BrOnCastDescEq(_)
    | BrOnCastDescEqFail(_)
    | Throw(_)
    | ThrowRef(_)
    | Return(_) => Branch
    Select(_) => Select
  }
}

///|
/// Whether this instruction is one of the brace-delimited forms.
fn[Info] is_block(i : @ast.Instr[Info]) -> Bool {
  match i.desc {
    Block(..)
    | Loop(..)
    | While(..)
    | If(..)
    | Try(..)
    | TryCatch(..)
    | TryTable(..)
    | IfAnnotation(..)
    | Dispatch(..)
    | Match(..) => true
    _ => false
  }
}

///|
/// Whether the printed form of `i` BEGINS with a brace-delimited construct.
///
/// A statement starting with `{` would be read as a block rather than as an
/// expression, so such a statement needs disambiguating. This walks down the
/// leftmost operand -- the token actually emitted first -- rather than looking
/// only at the outermost node.
fn[Info] starts_with_block_prec(prec : Prec, i : @ast.Instr[Info]) -> Bool {
  let actual = get_prec(i)
  // A hinted instruction starts with its attribute's `#`, not with a brace, so
  // it needs none of the disambiguation.
  if !i.hints.is_empty() {
    return false
  }
  if prec.rank() > actual.rank() {
    // It will be parenthesised, so it starts with `(`.
    return false
  }
  match i.desc {
    Block(..)
    | Loop(..)
    | While(..)
    | If(..)
    | Try(..)
    | TryCatch(..)
    | TryTable(..)
    | IfAnnotation(..)
    | Dispatch(..)
    | Match(..) => true
    Call(inner, _) | ArrayGet(inner, _) =>
      starts_with_block_prec(CallAndFieldAccess, inner)
    ArraySet(inner, _, _) => starts_with_block_prec(Assignement, inner)
    Cast(inner, _) | CastDesc(inner, _, _) | Test(inner, _) =>
      starts_with_block_prec(Cast, inner)
    NonNull(inner) => starts_with_block_prec(UnaryPostfix, inner)
    UnOpI(_, inner) => starts_with_block_prec(UnaryPrefix, inner)
    StructGet(inner, _) | StructSet(inner, _, _) | GetDescriptor(inner) =>
      starts_with_block_prec(CallAndFieldAccess, inner)
    BinOpI(op, inner, _) => {
      let (_, left, _) = prec_op(op.desc)
      starts_with_block_prec(left, inner)
    }
    Select(inner, _, _) => starts_with_block_prec(Select, inner)
    On(inner, _) => starts_with_block_prec(Cast, inner)
    // The method-form stack-switching instructions print their RECEIVER -- the
    // last operand -- first.
    Resume(_, _, l)
    | ResumeThrow(_, _, _, l)
    | ResumeThrowRef(_, _, l)
    | Switch(_, _, l) =>
      if l.length() > 0 {
        starts_with_block_prec(CallAndFieldAccess, l[l.length() - 1])
      } else {
        false
      }
    _ => false
  }
}

///|
fn[Info] starts_with_block(i : @ast.Instr[Info]) -> Bool {
  starts_with_block_prec(Instruction, i)
}

///|
/// The precedence an array literal's first element is printed at.
///
/// `[a | b]` would read as a typed array literal, so a bare `a | b` in first
/// position is printed as an atom (parenthesised) to keep the two apart.
fn[Info] array_element_precedence(
  nm : @ast.Ident?,
  first : Bool,
  i : @ast.Instr[Info],
) -> Prec {
  if nm is None && first {
    match i.desc {
      BinOpI(op, lhs, _) =>
        if op.desc is Or && lhs.desc is Get(_) {
          Atom
        } else {
          Instruction
        }
      _ => Instruction
    }
  } else {
    Instruction
  }
}

///|
fn cond_op_string(op : @wasm_types.CmpOp) -> String {
  match op {
    Eq => "="
    Ne => "!="
    Lt => "<"
    Gt => ">"
    Le => "<="
    Ge => ">="
  }
}

///|
/// A conditional-compilation condition, rendered as source text.
///
/// Rendered to a string rather than through the printer: a condition never
/// wraps, and it appears inside an attribute where the printer's boxes would
/// have nothing to decide.
fn cond_to_string(c : @wasm_types.Cond) -> String {
  match c {
    Var(v) => v.desc
    Str(s) => ocaml_escaped(s.desc)
    Version(a, b, cc) => "(\{a}, \{b}, \{cc})"
    Cmp(op, a, b) =>
      "\{cond_to_string(a)} \{cond_op_string(op)} \{cond_to_string(b)}"
    And(l) => "all(\{cond_list(l)})"
    Or(l) => "any(\{cond_list(l)})"
    Not(c2) => "not(\{cond_to_string(c2)})"
  }
}

///|
fn cond_list(l : Array[@wasm_types.Cond]) -> String {
  let parts = []
  for c in l {
    parts.push(cond_to_string(c))
  }
  parts.join(", ")
}

///|
/// Whether an instruction is simple enough to sit inline inside brackets.
///
/// A name or a literal only: anything with structure gets the broken-out form
/// so the brackets do not have to hold a multi-line expression.
fn[Info] simple_inline_instr(i : @ast.Instr[Info]) -> Bool {
  match i.desc {
    Get(_) | Path(_) | Char(_) | Str(_) | Int(_) | Float(_) => true
    _ => false
  }
}

///|
/// A byte string quoted the way OCaml's `%S` does it, which is what the
/// reference uses for a cfg string.
///
/// NOT `escape_string`: this is a different escaping dialect, with `\b` among
/// the named escapes and DECIMAL `\ddd` -- three digits, always -- for
/// anything else outside printable ASCII.
fn ocaml_escaped(b : Bytes) -> String {
  let out = StringBuilder::new()
  out.write_char('"')
  for byte in b {
    let n = byte.to_int()
    match n {
      34 => out.write_string("\\\"")
      92 => out.write_string("\\\\")
      10 => out.write_string("\\n")
      9 => out.write_string("\\t")
      13 => out.write_string("\\r")
      8 => out.write_string("\\b")
      _ =>
        if n >= 32 && n <= 126 {
          out.write_char(n.unsafe_to_char())
        } else {
          out.write_string("\\")
          out.write_string((n / 100).to_string())
          out.write_string((n / 10 % 10).to_string())
          out.write_string((n % 10).to_string())
        }
    }
  }
  out.write_char('"')
  out.to_string()
}
