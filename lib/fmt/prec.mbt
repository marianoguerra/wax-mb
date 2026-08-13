// Operator spellings and the precedence ladder the printer parenthesises by.
//
// The printer does NOT record whether the source had parentheses -- the AST
// carries no paren node. It re-derives them: each context states the precedence
// it can accept, each node reports the precedence it has, and a node weaker
// than its context gets wrapped. That is why `1 + 2 * 3` reprints without
// parentheses while `(1 + 2) * 3` regains them.

///|
pub fn binop_str(op : @ast.BinOp) -> String {
  match op {
    Add => "+"
    Sub => "-"
    Mul => "*"
    Div(None) => "/"
    Div(Some(Signed)) => "/s"
    Div(Some(Unsigned)) => "/u"
    Rem(Signed) => "%s"
    Rem(Unsigned) => "%u"
    And => "&"
    Or => "|"
    Xor => "^"
    Shl => "<<"
    Shr(Signed) => ">>s"
    Shr(Unsigned) => ">>u"
    Eq => "=="
    Ne => "!="
    Lt(None) => "<"
    Lt(Some(Signed)) => "<s"
    Lt(Some(Unsigned)) => "<u"
    Gt(None) => ">"
    Gt(Some(Signed)) => ">s"
    Gt(Some(Unsigned)) => ">u"
    Le(None) => "<="
    Le(Some(Signed)) => "<=s"
    Le(Some(Unsigned)) => "<=u"
    Ge(None) => ">="
    Ge(Some(Signed)) => ">=s"
    Ge(Some(Unsigned)) => ">=u"
  }
}

///|
pub fn unop_str(op : @ast.UnOp) -> String {
  match op {
    Neg => "-"
    Pos => "+"
    Not => "!"
  }
}

///|
/// Binding strength, weakest first.
///
/// Ordered so a plain comparison decides whether parentheses are needed.
pub(all) enum Prec {
  Instruction
  Branch
  Assignement
  Select
  Comparison
  LogicalOr
  LogicalXor
  LogicalAnd
  Shift
  Addition
  Multiplication
  Cast
  UnaryPrefix
  UnaryPostfix
  CallAndFieldAccess
  Atom
} derive(Eq, Compare, Debug)

///|
fn Prec::rank(self : Prec) -> Int {
  match self {
    Instruction => 0
    Branch => 1
    Assignement => 2
    Select => 3
    Comparison => 4
    LogicalOr => 5
    LogicalXor => 6
    LogicalAnd => 7
    Shift => 8
    Addition => 9
    Multiplication => 10
    Cast => 11
    UnaryPrefix => 12
    UnaryPostfix => 13
    CallAndFieldAccess => 14
    Atom => 15
  }
}

///|
/// The precedence an operator PRODUCES, and what it accepts on each side.
///
/// The asymmetry is what encodes associativity: `Add` accepts `Addition` on the
/// left but demands `Multiplication` on the right, so `1 - (2 - 3)` keeps its
/// parentheses while `(1 - 2) - 3` loses them.
pub fn prec_op(op : @ast.BinOp) -> (Prec, Prec, Prec) {
  match op {
    Add | Sub => (Addition, Addition, Multiplication)
    Mul | Div(_) | Rem(_) => (Multiplication, Multiplication, Cast)
    And => (LogicalAnd, LogicalAnd, Shift)
    Or => (LogicalOr, LogicalOr, LogicalXor)
    Xor => (LogicalXor, LogicalXor, LogicalAnd)
    Shl | Shr(_) => (Shift, Shift, Addition)
    // Comparisons are non-associative: both sides demand a strictly stronger
    // precedence, so a chained comparison could not print unparenthesised even
    // if one could be built.
    Gt(_) | Lt(_) | Ge(_) | Le(_) | Eq | Ne =>
      (Comparison, LogicalOr, LogicalOr)
  }
}

///|
/// Wrap `g` in parentheses when the context demands more binding strength than
/// the node provides.
pub fn[Info] Ctx::parenthesized(
  self : Ctx[Info],
  expected : Prec,
  actual : Prec,
  g : () -> Unit,
) -> Unit {
  if expected.rank() > actual.rank() {
    self.punct("(")
    self.p.box(() => {
      g()
      // Hold the closing `)` past a trailing comment on the last inner token,
      // so it hugs the expression -- `(c == 108) // 'l'` -- instead of being
      // pushed onto its own line after the comment, as `;` and `,` also do.
      self.p.with_held_eol(() => self.punct(")"))
    })
  } else {
    g()
  }
}

///|
pub fn[Info] Ctx::block_label(self : Ctx[Info], label : @ast.Ident?) -> Unit {
  match label {
    Some(l) => {
      self.ident("'")
      self.ident(l.name)
      self.punct(":")
      self.space()
    }
    None => ()
  }
}

///|
pub fn need_blocktype(bt : @ast.FuncType) -> Bool {
  bt.params.length() > 0 || bt.results.length() > 0
}

///|
pub fn[Info] Ctx::casttype(self : Ctx[Info], ty : @ast.CastType) -> Unit {
  match ty {
    Value(v) => self.valtype(v)
    Func(nullable~, sign~) => {
      self.punct(if nullable { "&?" } else { "&" })
      self.functype(sign)
    }
    Signed(typ~, signage~, strict~) =>
      self.typ(@ast.format_signed_type(typ, signage, strict))
  }
}

///|
/// What family a binary operator belongs to, for the confusing-precedence rule.
pub(all) enum BinopKind {
  Shift
  Arith
  Bitwise
  Comparison
} derive(Eq, Debug)

///|
pub fn binop_kind(op : @ast.BinOp) -> BinopKind {
  match op {
    Shl | Shr(_) => Shift
    Add | Sub | Mul | Div(_) | Rem(_) => Arith
    And | Or | Xor => Bitwise
    Eq | Ne | Lt(_) | Gt(_) | Le(_) | Ge(_) => Comparison
  }
}

///|
/// Whether nesting `inner` inside `outer` is a mix a reader would misread.
///
/// Shift against arithmetic, and comparison against bitwise: in both, the
/// precedence is well defined but widely misremembered. The reference lints
/// these (`Typing.lint_precedence`) and the FORMATTER parenthesises them even
/// though precedence alone would not require it -- otherwise reprinted or
/// decompiled Wax would trip the project's own lint.
///
/// This is not an inference from the precedence ladder; it is a separate table,
/// shared with the lint.
pub fn confusing_precedence(outer : BinopKind, inner : BinopKind) -> Bool {
  match (outer, inner) {
    (Shift, Arith) | (Arith, Shift) => true
    (Comparison, Bitwise) | (Bitwise, Comparison) => true
    _ => false
  }
}
