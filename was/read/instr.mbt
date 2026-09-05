// Instructions.
//
// Shrubbery hands over a flat term list per group with no precedence applied,
// so this is a precedence-climbing parser over terms. The table below is Wax's
// own, transcribed from `lib/syntax/parser/parser.mbty`: comparisons bind
// LOOSER than the bitwise operators, which is the opposite of C and is the one
// thing a reader coming from C will get wrong.

///|
/// Binding powers, loosest first. Wax's `%left` declarations, in order.
fn infix_bp(name : String) -> (Int, Int)? {
  match name {
    "=="
    | "!="
    | "<"
    | "<="
    | ">"
    | ">="
    | "<~"
    | "<=~"
    | ">~"
    | ">=~"
    | "<$"
    | "<=$"
    | ">$"
    | ">=$" => Some((3, 4))
    "||" => Some((5, 6))
    "^" => Some((7, 8))
    "&" => Some((9, 10))
    "<<" | ">>~" | ">>$" => Some((11, 12))
    "+" | "-" => Some((13, 14))
    "*" | "/" | "/~" | "/$" | "%~" | "%$" => Some((15, 16))
    "as" | "is" | "on" => Some((17, 18))
    _ => None
  }
}

///|
/// The Wax operator a was operator is.
///
/// `~` is signed and `$` is unsigned, and a bare operator is the one Wax
/// leaves unannotated -- float division, float comparison, reference identity.
/// No letter can appear in a shrubbery operator, which is the whole reason
/// `/s` and `/u` had to become something else.
fn binop_of(name : String) -> @ast.BinOp? {
  match name {
    "+" => Some(Add)
    "-" => Some(Sub)
    "*" => Some(Mul)
    "/" => Some(Div(None))
    "/~" => Some(Div(Some(Signed)))
    "/$" => Some(Div(Some(Unsigned)))
    "%~" => Some(Rem(Signed))
    "%$" => Some(Rem(Unsigned))
    "<<" => Some(Shl)
    ">>~" => Some(Shr(Signed))
    ">>$" => Some(Shr(Unsigned))
    "&" => Some(And)
    "||" => Some(Or)
    "^" => Some(Xor)
    "==" => Some(Eq)
    "!=" => Some(Ne)
    "<" => Some(Lt(None))
    "<~" => Some(Lt(Some(Signed)))
    "<$" => Some(Lt(Some(Unsigned)))
    ">" => Some(Gt(None))
    ">~" => Some(Gt(Some(Signed)))
    ">$" => Some(Gt(Some(Unsigned)))
    "<=" => Some(Le(None))
    "<=~" => Some(Le(Some(Signed)))
    "<=$" => Some(Le(Some(Unsigned)))
    ">=" => Some(Ge(None))
    ">=~" => Some(Ge(Some(Signed)))
    ">=$" => Some(Ge(Some(Unsigned)))
    _ => None
  }
}

///|
/// The compound assignments, and the operation each folds in.
fn assign_binop(name : String) -> @ast.BinOp? {
  match name {
    "+=" => Some(Add)
    "-=" => Some(Sub)
    "*=" => Some(Mul)
    "/=" => Some(Div(None))
    "/~=" => Some(Div(Some(Signed)))
    "/$=" => Some(Div(Some(Unsigned)))
    "%~=" => Some(Rem(Signed))
    "%$=" => Some(Rem(Unsigned))
    "<<=" => Some(Shl)
    ">>~=" => Some(Shr(Signed))
    ">>$=" => Some(Shr(Unsigned))
    "&=" => Some(And)
    "||=" => Some(Or)
    "^=" => Some(Xor)
    _ => None
  }
}

///|
/// The name an infix term carries. `as`, `is` and `on` are identifiers to
/// shrubbery and operators to Wax.
fn infix_name(n : @sh.Node) -> String? {
  match n.it {
    Op(s) => Some(s)
    Id(s) => if s == "as" || s == "is" || s == "on" { Some(s) } else { None }
    _ => None
  }
}

// -------------------------------------------------------------------- bodies

///|
/// A sequence of groups, as the instructions they are.
fn Reader::body(
  self : Reader,
  groups : Array[@sh.Node],
) -> Array[@ast.Instr[@basic.Location]] raise ReadError {
  let out = []
  for g in groups {
    out.push(self.group(g))
  }
  out
}

///|
/// One group.
fn Reader::group(
  self : Reader,
  g : @sh.Node,
) -> @ast.Instr[@basic.Location] raise ReadError {
  let p = split(g)
  match self.form(p) {
    Some(i) => i
    None => {
      if p.block is Some(_) {
        fail_at(
          "this line ends with a block, but nothing here takes one",
          p.span,
          source=self.src,
        )
      }
      self.assign_or_expr(p.head, p.span)
    }
  }
}

///|
/// A leading `~label`, and the terms after it.
fn label_of(ts : Array[@sh.Node]) -> (String?, Array[@sh.Node]) {
  if ts.length() > 0 && as_kw(ts[0]) is Some(k) {
    (Some(k), ts[1:].to_owned())
  } else {
    (None, ts)
  }
}

///|
/// The block a form's `:` introduced, or an error naming the form.
fn Reader::need_block(
  self : Reader,
  p : Parts,
  what : String,
) -> Array[@ast.Instr[@basic.Location]] raise ReadError {
  match p.block {
    Some(gs) => self.body(gs)
    None =>
      fail_at(
        "expected `:` and a body after `" + what + "`",
        p.span,
        source=self.src,
      )
  }
}
