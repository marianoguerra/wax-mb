// Expressions.
//
// A wap body is a sequence of groups and every group is an expression, so this
// file is the whole statement language too. Shrubbery hands over a flat term
// list per group with no precedence applied -- that is the notation's job
// finished and the language's job starting -- so what follows is an ordinary
// precedence-climbing parser over terms rather than over characters.

///|
/// Binding powers for infix operators, tightest last.
///
/// `as` and `is` bind tightest because their right operand is a type, not an
/// expression, and `||` loosest. Assignment is handled separately: it is
/// right-associative and its left side is a pattern, not a value.
fn infix_bp(name : String) -> (Int, Int)? {
  match name {
    "||" => Some((1, 2))
    "&&" => Some((3, 4))
    "==" | "!=" | "<" | "<=" | ">" | ">=" => Some((5, 6))
    "in" => Some((5, 6))
    "&" | "^" => Some((9, 10))
    "<<" | ">>" => Some((11, 12))
    "+" | "-" => Some((13, 14))
    "*" | "/" | "%" => Some((15, 16))
    "as" | "is" => Some((19, 20))
    _ => None
  }
}

///|
/// The assignment operators, and the binary operation each folds in.
fn assign_op(name : String) -> @wap.AssignOp? {
  match name {
    "=" => Some(Set)
    "+=" => Some(OpSet(Add))
    "-=" => Some(OpSet(Sub))
    "*=" => Some(OpSet(Mul))
    "/=" => Some(OpSet(Div))
    "%=" => Some(OpSet(Rem))
    "&=" | "&&=" => Some(OpSet(BitAnd))
    "||=" => Some(OpSet(BitOr))
    "^=" => Some(OpSet(BitXor))
    "<<=" => Some(OpSet(Shl))
    ">>=" => Some(OpSet(Shr))
    _ => None
  }
}

///|
fn binop_of(name : String) -> @wap.BinOp? {
  match name {
    "+" => Some(Add)
    "-" => Some(Sub)
    "*" => Some(Mul)
    "/" => Some(Div)
    "%" => Some(Rem)
    "<<" => Some(Shl)
    ">>" => Some(Shr)
    "&" => Some(BitAnd)
    "^" => Some(BitXor)
    "==" => Some(Eq)
    "!=" => Some(Ne)
    "<" => Some(Lt)
    ">" => Some(Gt)
    "<=" => Some(Le)
    ">=" => Some(Ge)
    _ => None
  }
}

///|
fn node(it : @wap.Expr, span : @wap.Span) -> @wap.Node {
  { it, span, }
}

///|
/// The name an infix term carries, whether it is written as an operator or as
/// a word. `as`, `is` and `in` are identifiers to shrubbery and operators to
/// wap, which is the same trick Wax plays with `as` and `on`.
fn infix_name(n : @sh.Node) -> String? {
  match n.it {
    Op(s) => Some(s)
    Id(s) => if s == "as" || s == "is" || s == "in" { Some(s) } else { None }
    _ => None
  }
}

// ------------------------------------------------------------------ bodies

///|
/// Parse a sequence of groups into a sequence of expressions.
pub fn parse_body(
  groups : Array[@sh.Node],
  src : @er.SourceId,
) -> Array[@wap.Node] raise ParseError {
  let out = []
  for g in groups {
    out.push(parse_group(g, src))
  }
  out
}

///|
/// Parse one group. A group whose head is a keyword is a form; anything else
/// is an expression, possibly an assignment.
pub fn parse_group(
  g : @sh.Node,
  src : @er.SourceId,
) -> @wap.Node raise ParseError {
  let p = split(g)
  match parse_form(p, src) {
    Some(n) => return n
    None => ()
  }
  if p.block is Some(_) {
    fail_at(
      "this line ends with a block, but `" +
      head_word(p.head) +
      "` does not take one",
      p.span,
      source=src,
      help="a block belongs to `if`, `while`, `for`, `loop`, `match`, `fn`, `impl` or `import`",
    )
  }
  parse_assign_or_expr(Cursor::new(p.head, src), p.span, src, tail=p)
}

///|
/// One of the forms whose head is a keyword, or nothing.
///
/// A form can appear wherever an expression can -- `let n = if c | a | b` --
/// and when it does it still owns the group's block and alternatives, because
/// shrubbery attached them to the group rather than to the term. Splitting the
/// head and keeping the tail is what makes that work.
fn parse_form(p : Parts, src : @er.SourceId) -> @wap.Node? raise ParseError {
  let head = p.head
  if head.length() == 0 {
    return None
  }
  match as_id(head[0]) {
    Some(kw) =>
      match kw {
        "let" => Some(parse_bind(p, src, false))
        "var" => Some(parse_bind(p, src, true))
        "if" => Some(parse_if(p, src))
        "while" => Some(parse_while(p, src))
        "for" => Some(parse_for(p, src))
        "loop" => Some(parse_loop(p, src))
        "match" => Some(parse_match(p, src))
        "return" => {
          let rest = head[1:].to_owned()
          if rest.length() == 0 {
            Some(node(Return(None), p.span))
          } else {
            Some(node(Return(Some(parse_tail(rest, p, src))), p.span))
          }
        }
        "break" => Some(node(Break(label_of(head[1:])), p.span))
        "continue" => Some(node(Continue(label_of(head[1:])), p.span))
        "unreachable" => Some(node(Unreachable, p.span))
        "nop" => Some(node(Nop, p.span))
        _ => None
      }
    None => None
  }
}

///|
/// An expression that may itself be a form, and then takes the group's block
/// and alternatives with it.
fn parse_tail(
  ts : Array[@sh.Node],
  p : Parts,
  src : @er.SourceId,
) -> @wap.Node raise ParseError {
  let sub : Parts = { head: ts, block: p.block, alts: p.alts, span: p.span, }
  match parse_form(sub, src) {
    Some(n) => n
    None => parse_expr_all(Cursor::new(ts, src), src)
  }
}

///|
fn head_word(head : Array[@sh.Node]) -> String {
  if head.length() == 0 {
    "this"
  } else {
    match head[0].it {
      Id(s) => s
      Op(s) => s
      _ => "this"
    }
  }
}

///|
/// A leading `~label`, if there is one.
fn label_of(ts : ArrayView[@sh.Node]) -> String? {
  if ts.length() > 0 {
    as_kw(ts[0])
  } else {
    None
  }
}

// ------------------------------------------------------------------ forms

///|
/// `let x :: t = e`, `var (q, r) = e`, `let x :: t` with no initialiser.
fn parse_bind(
  p : Parts,
  src : @er.SourceId,
  mutable : Bool,
) -> @wap.Node raise ParseError {
  let ts = p.head[1:].to_owned()
  // Split at the top-level `=`.
  let mut eq = -1
  for i, t in ts {
    if is_op(t, "=") {
      eq = i
      break
    }
  }
  let lhs = if eq < 0 { ts } else { ts[0:eq].to_owned() }
  let binders = parse_binders(lhs, src)
  let value = if eq < 0 {
    None
  } else {
    let rest = ts[eq + 1:].to_owned()
    if rest.length() == 0 {
      fail_at("expected an expression after `=`", p.span, source=src)
    }
    Some(parse_tail(rest, p, src))
  }
  node(Bind(binders~, value~, mutable~), p.span)
}

///|
fn parse_binders(
  ts : Array[@sh.Node],
  src : @er.SourceId,
) -> Array[@wap.Binder] raise ParseError {
  if ts.length() == 0 {
    fail_at("expected a name to bind", @wap.nowhere, source=src)
  }
  // `(a, b)` -- a tuple destructuring.
  if ts.length() == 1 && ts[0].it is Parens(gs) {
    let out = []
    for g in gs {
      out.append(parse_binders(children(g), src))
    }
    return out
  }
  // `name :: t`
  let name = match as_id(ts[0]) {
    Some(s) => s
    None => fail_at("expected a name", node_span(ts[0]), source=src)
  }
  let mut typ = None
  if ts.length() > 1 {
    if !is_op(ts[1], "::") {
      fail_at(
        "expected `::` and a type after `" + name + "`",
        node_span(ts[1]),
        source=src,
      )
    }
    typ = Some(parse_type(Cursor::new(ts[2:].to_owned(), src)))
  }
  [{ name, typ, span: node_span(ts[0]), }]
}

///|
/// `if c | a | b`, `if c: ...`, and the multi-arm `if | c: a | _: b`.
fn parse_if(p : Parts, src : @er.SourceId) -> @wap.Node raise ParseError {
  let cond_ts = p.head[1:].to_owned()
  // An explicit `-> t` result type, as in `if c -> i32 | a | b`.
  let (cond_ts, typ) = split_result_type(cond_ts, src)
  let arms : Array[(@wap.Node?, Array[@wap.Node])] = []
  if cond_ts.length() == 0 {
    // Multi-arm: every alternative is `cond: body`, with `_` or `else` last.
    match p.alts {
      None =>
        fail_at(
          "`if` with no condition needs `|` alternatives",
          p.span,
          source=src,
        )
      Some(alts) =>
        for alt in alts {
          if alt.length() != 1 {
            fail_at(
              "each `|` arm of a multi-arm `if` is one `condition: body`",
              terms_span(alt[:]),
              source=src,
            )
          }
          let ap = split(alt[0])
          let body = match ap.block {
            Some(gs) => parse_body(gs, src)
            None =>
              fail_at(
                "expected `:` and a body after this condition",
                ap.span,
                source=src,
              )
          }
          if is_default_head(ap.head) {
            arms.push((None, body))
          } else {
            arms.push((Some(parse_expr(Cursor::new(ap.head, src), 0)), body))
          }
        }
    }
  } else {
    let cond = parse_expr(Cursor::new(cond_ts, src), 0)
    match (p.block, p.alts) {
      (Some(gs), None) => arms.push((Some(cond), parse_body(gs, src)))
      (Some(gs), Some(alts)) => {
        arms.push((Some(cond), parse_body(gs, src)))
        if alts.length() != 1 {
          fail_at(
            "an `if` with a `:` body takes exactly one `|` alternative, the else",
            p.span,
            source=src,
          )
        }
        arms.push((None, parse_body(alts[0], src)))
      }
      (None, Some(alts)) => {
        if alts.length() < 1 || alts.length() > 2 {
          fail_at(
            "`if c | then | else` takes one or two alternatives",
            p.span,
            source=src,
          )
        }
        arms.push((Some(cond), parse_body(alts[0], src)))
        if alts.length() == 2 {
          arms.push((None, parse_body(alts[1], src)))
        }
      }
      (None, None) =>
        fail_at("expected `:` or `|` after the condition", p.span, source=src)
    }
  }
  node(If(arms~, typ~), p.span)
}

///|
fn is_default_head(head : Array[@sh.Node]) -> Bool {
  head.length() == 1 && (is_id(head[0], "_") || is_id(head[0], "else"))
}

///|
/// Peel a trailing `-> t` off a term run.
fn split_result_type(
  ts : Array[@sh.Node],
  src : @er.SourceId,
) -> (Array[@sh.Node], @wap.Type?) raise ParseError {
  for i, t in ts {
    if is_op(t, "->") {
      let c = Cursor::new(ts[i + 1:].to_owned(), src)
      return (ts[0:i].to_owned(), Some(parse_type(c)))
    }
  }
  (ts, None)
}

///|
/// `while ~label cond ~step(e):`
fn parse_while(p : Parts, src : @er.SourceId) -> @wap.Node raise ParseError {
  let ts = p.head[1:].to_owned()
  let mut i = 0
  let mut label = None
  if ts.length() > 0 && as_kw(ts[0]) is Some(k) && k != "step" {
    label = Some(k)
    i = 1
  }
  let mut step = None
  let mut end = ts.length()
  for j = i; j < ts.length(); j = j + 1 {
    if as_kw(ts[j]) is Some("step") {
      end = j
      if j + 1 < ts.length() && ts[j + 1].it is Parens(gs) && gs.length() == 1 {
        step = Some(parse_group(gs[0], src))
      } else {
        fail_at(
          "`~step` takes one parenthesised expression",
          node_span(ts[j]),
          source=src,
        )
      }
      break
    }
  }
  let cond_ts = ts[i:end].to_owned()
  if cond_ts.length() == 0 {
    fail_at("expected a condition after `while`", p.span, source=src)
  }
  let cond = parse_expr(Cursor::new(cond_ts, src), 0)
  let body = match p.block {
    Some(gs) => parse_body(gs, src)
    None => fail_at("expected `:` and a body after `while`", p.span, source=src)
  }
  node(While(label~, cond~, step~, body~), p.span)
}

///|
/// `for ~label x in a .. b by n:` and `for x in xs:`
fn parse_for(p : Parts, src : @er.SourceId) -> @wap.Node raise ParseError {
  let ts = p.head[1:].to_owned()
  let mut i = 0
  let mut label = None
  if ts.length() > 0 && as_kw(ts[0]) is Some(k) {
    label = Some(k)
    i = 1
  }
  let var_name = if i < ts.length() { as_id(ts[i]) } else { None }
  let var_ = match var_name {
    Some(s) => s
    None => fail_at("expected a loop variable after `for`", p.span, source=src)
  }
  i += 1
  if !(i < ts.length() && is_id(ts[i], "in")) {
    fail_at("expected `in` after the loop variable", p.span, source=src)
  }
  i += 1
  let rest = ts[i:].to_owned()
  let body = match p.block {
    Some(gs) => parse_body(gs, src)
    None => fail_at("expected `:` and a body after `for`", p.span, source=src)
  }
  // `by n` splits off the end.
  let mut by_at = -1
  for j, t in rest {
    if is_id(t, "by") {
      by_at = j
      break
    }
  }
  let seq_ts = if by_at < 0 { rest } else { rest[0:by_at].to_owned() }
  let by = if by_at < 0 {
    None
  } else {
    Some(parse_expr(Cursor::new(rest[by_at + 1:].to_owned(), src), 0))
  }
  // A range splits at a top-level `..` or `..<`.
  let mut dots = -1
  let mut inclusive = true
  for j, t in seq_ts {
    if is_op(t, "..") {
      dots = j
      inclusive = true
      break
    }
    if is_op(t, "..<") {
      dots = j
      inclusive = false
      break
    }
  }
  if dots >= 0 {
    let from = parse_expr(Cursor::new(seq_ts[0:dots].to_owned(), src), 0)
    let to = parse_expr(Cursor::new(seq_ts[dots + 1:].to_owned(), src), 0)
    node(ForRange(label~, var_~, from~, to~, inclusive~, by~, body~), p.span)
  } else {
    if by is Some(_) {
      fail_at("`by` applies to a range, not to a sequence", p.span, source=src)
    }
    let seq = parse_expr(Cursor::new(seq_ts, src), 0)
    node(ForIn(label~, var_~, seq~, body~), p.span)
  }
}

///|
fn parse_loop(p : Parts, src : @er.SourceId) -> @wap.Node raise ParseError {
  let label = label_of(p.head[1:])
  let body = match p.block {
    Some(gs) => parse_body(gs, src)
    None => fail_at("expected `:` and a body after `loop`", p.span, source=src)
  }
  node(Loop(label~, body~), p.span)
}

///|
/// `match e | pat: body | ...`
fn parse_match(p : Parts, src : @er.SourceId) -> @wap.Node raise ParseError {
  let (scrut_ts, typ) = split_result_type(p.head[1:].to_owned(), src)
  if scrut_ts.length() == 0 {
    fail_at("expected an expression after `match`", p.span, source=src)
  }
  let scrutinee = parse_expr(Cursor::new(scrut_ts, src), 0)
  let arms = []
  match p.alts {
    None => fail_at("`match` needs `|` arms", p.span, source=src)
    Some(alts) =>
      for alt in alts {
        if alt.length() != 1 {
          fail_at(
            "each `match` arm is one `pattern: body`",
            terms_span(alt[:]),
            source=src,
          )
        }
        let ap = split(alt[0])
        let body = match ap.block {
          Some(gs) => parse_body(gs, src)
          None =>
            fail_at(
              "expected `:` and a body after this pattern",
              ap.span,
              source=src,
            )
        }
        arms.push(
          ({ pat: parse_pattern(ap.head, src), body, span: ap.span, } : @wap.Arm),
        )
      }
  }
  node(Match(scrutinee~, arms~, typ~), p.span)
}

///|
fn parse_pattern(
  ts : Array[@sh.Node],
  src : @er.SourceId,
) -> @wap.Pattern raise ParseError {
  if ts.length() == 0 {
    fail_at("expected a pattern", @wap.nowhere, source=src)
  }
  if is_default_head(ts) {
    return PWild
  }
  if ts.length() == 1 && is_id(ts[0], "null") {
    return PNull
  }
  // `{1, 7}` -- a set of labels.
  if ts.length() == 1 && ts[0].it is Braces(gs) {
    let items = []
    for g in gs {
      items.push(parse_pattern(children(g), src))
    }
    return PSet(items)
  }
  // `lo .. hi`
  for i, t in ts {
    if is_op(t, "..") {
      return PRange(
        low=literal_text(ts[0:i].to_owned(), src),
        high=literal_text(ts[i + 1:].to_owned(), src),
      )
    }
  }
  // `name :: t` or a bare type.
  for i, t in ts {
    if is_op(t, "::") {
      let name = match as_id(ts[0]) {
        Some(s) => s
        None =>
          fail_at("expected a name before `::`", node_span(ts[0]), source=src)
      }
      let typ = parse_type(Cursor::new(ts[i + 1:].to_owned(), src))
      return PType(name=Some(name), typ~)
    }
  }
  match ts[0].it {
    Lit(Int_(_)) => PInt(raw_text(ts[0]))
    Op("-") => PInt(literal_text(ts, src))
    _ => PType(name=None, typ=parse_type(Cursor::new(ts, src)))
  }
}

///|
fn literal_text(
  ts : Array[@sh.Node],
  src : @er.SourceId,
) -> String raise ParseError {
  if ts.length() == 1 {
    raw_text(ts[0])
  } else if ts.length() == 2 && is_op(ts[0], "-") {
    "-" + raw_text(ts[1])
  } else {
    fail_at("expected a literal", terms_span(ts[:]), source=src)
  }
}

// ------------------------------------------------------------- expressions

///|
/// An expression, or an assignment to one or more targets.
fn parse_assign_or_expr(
  c : Cursor,
  span : @wap.Span,
  src : @er.SourceId,
  tail? : Parts,
) -> @wap.Node raise ParseError {
  // Find a top-level assignment operator.
  let mut at = -1
  let mut op = @wap.AssignOp::Set
  for i, t in c.ts {
    if as_op(t) is Some(s) && assign_op(s) is Some(a) {
      at = i
      op = a
      break
    }
  }
  if at < 0 {
    return parse_expr_all(c, src)
  }
  let lhs_ts = c.ts[0:at].to_owned()
  let rhs_ts = c.ts[at + 1:].to_owned()
  if rhs_ts.length() == 0 {
    fail_at(
      "expected an expression on the right of the assignment",
      span,
      source=src,
    )
  }
  let value = match tail {
    Some(p) => parse_tail(rhs_ts, p, src)
    None => parse_expr_all(Cursor::new(rhs_ts, src), src)
  }
  // `_ = e` evaluates and drops.
  if lhs_ts.length() == 1 && is_id(lhs_ts[0], "_") && op is Set {
    return node(Drop(value), span)
  }
  let targets = if lhs_ts.length() == 1 && lhs_ts[0].it is Parens(gs) {
    let out = []
    for g in gs {
      out.push(parse_expr(Cursor::new(children(g), src), 0))
    }
    out
  } else {
    [parse_expr(Cursor::new(lhs_ts, src), 0)]
  }
  node(Assign(targets~, op~, value~), span)
}

///|
/// Parse an expression that must consume every term it was given.
///
/// Without this a term the parser does not understand is silently dropped,
/// which is the one kind of parser bug that produces a program rather than a
/// message.
fn parse_expr_all(c : Cursor, src : @er.SourceId) -> @wap.Node raise ParseError {
  let e = parse_expr(c, 0)
  if !c.done() {
    fail_at(
      "this is not part of the expression before it",
      node_span(c.ts[c.i]),
      source=src,
    )
  }
  e
}

///|
/// Precedence climbing over the term list.
fn parse_expr(c : Cursor, min_bp : Int) -> @wap.Node raise ParseError {
  let mut lhs = parse_unary(c)
  while c.peek() is Some(t) {
    let name = match infix_name(t) {
      Some(s) => s
      None => break
    }
    let (lbp, rbp) = match infix_bp(name) {
      Some(bp) => bp
      None => break
    }
    if lbp < min_bp {
      break
    }
    c.i += 1
    let start = lhs.span
    match name {
      "as" => {
        let typ = parse_type(c)
        lhs = node(Cast(lhs, typ), start)
      }
      "is" => {
        let typ = parse_type(c)
        lhs = node(Test(lhs, typ), start)
      }
      "&&" => {
        let rhs = parse_expr(c, rbp)
        lhs = node(AndAlso(lhs, rhs), start)
      }
      "||" => {
        let rhs = parse_expr(c, rbp)
        lhs = node(OrElse(lhs, rhs), start)
      }
      "in" => {
        let rhs = parse_expr(c, rbp)
        lhs = node(InSet(lhs, rhs), start)
      }
      _ => {
        let rhs = parse_expr(c, rbp)
        match binop_of(name) {
          Some(op) => lhs = node(Bin(op, lhs, rhs), start)
          None =>
            fail_at(
              "`" + name + "` is not an operator in wap",
              start,
              source=c.src,
            )
        }
      }
    }
  }
  lhs
}

///|
fn parse_unary(c : Cursor) -> @wap.Node raise ParseError {
  match c.peek() {
    Some(t) =>
      if is_op(t, "-") {
        c.i += 1
        let e = parse_unary(c)
        return node(Un(Neg, e), node_span(t))
      } else if is_op(t, "!") {
        c.i += 1
        let e = parse_unary(c)
        return node(Un(Not, e), node_span(t))
      }
    None => ()
  }
  parse_postfix(c)
}

///|
fn parse_postfix(c : Cursor) -> @wap.Node raise ParseError {
  let mut e = parse_primary(c)
  while c.peek() is Some(t) {
    match t.it {
      Parens(gs) => {
        c.i += 1
        let args = []
        for g in gs {
          args.push(parse_expr(Cursor::new(children(g), c.src), 0))
        }
        e = match e.it {
          Field(recv, name) => node(MethodCall(recv, name, args), e.span)
          _ => node(Call(e, args), e.span)
        }
      }
      Brackets(gs) => {
        c.i += 1
        e = bracketed(e, gs, c.src)
      }
      Braces(gs) =>
        // `point{x: 1}` -- a record literal named by the preceding term.
        match e.it {
          Var(name) => {
            c.i += 1
            e = braced(Some(name), gs, e.span, c.src)
          }
          _ => break
        }
      Op(".") => {
        c.i += 1
        match c.next() {
          Some(f) =>
            match as_id(f) {
              Some(name) => e = node(Field(e, name), e.span)
              None =>
                fail_at(
                  "expected a field name after `.`",
                  node_span(f),
                  source=c.src,
                )
            }
          None =>
            fail_at("expected a field name after `.`", e.span, source=c.src)
        }
      }
      Op("!") => {
        c.i += 1
        e = node(NonNull(e), e.span)
      }
      // `v!.field` -- shrubbery's maximal munch makes `!.` one operator, so
      // the assertion and the field access arrive together.
      Op("!.") => {
        c.i += 1
        let nn = node(NonNull(e), e.span)
        match c.next() {
          Some(f) =>
            match as_id(f) {
              Some(name) => e = node(Field(nn, name), e.span)
              None =>
                fail_at(
                  "expected a field name after `!.`",
                  node_span(f),
                  source=c.src,
                )
            }
          None =>
            fail_at("expected a field name after `!.`", e.span, source=c.src)
        }
      }
      _ => break
    }
  }
  e
}

///|
/// `T[...]` after a name: an array literal, an array repeat, or an index.
///
/// `xs[i]` and `ints[1]` are the same shape; which one it is depends on whether
/// `ints` names a type, and only the lowering knows that. A one-group bracket
/// with no `**` therefore stays an `Index` and is reinterpreted there.
fn bracketed(
  e : @wap.Node,
  gs : Array[@sh.Node],
  src : @er.SourceId,
) -> @wap.Node raise ParseError {
  let typ = match e.it {
    Var(name) => Some(name)
    _ => None
  }
  // `t[v ** n]`
  if gs.length() == 1 {
    let ts = children(gs[0])
    for i, t in ts {
      if is_op(t, "**") {
        let value = parse_expr(Cursor::new(ts[0:i].to_owned(), src), 0)
        let count = parse_expr(Cursor::new(ts[i + 1:].to_owned(), src), 0)
        return node(ArrayRepeat(typ~, value~, count~), e.span)
      }
    }
    return node(Index(e, parse_expr(Cursor::new(ts, src), 0)), e.span)
  }
  let items = []
  for g in gs {
    items.push(parse_expr(Cursor::new(children(g), src), 0))
  }
  node(ArrayLit(typ~, items~), e.span)
}

///|
/// `{...}` -- a record literal, a record default, or a set.
fn braced(
  typ : String?,
  gs : Array[@sh.Node],
  span : @wap.Span,
  src : @er.SourceId,
) -> @wap.Node raise ParseError {
  if gs.length() == 1 {
    let ts = children(gs[0])
    if ts.length() == 1 && is_op(ts[0], "..") {
      return node(RecordDefault(typ~), span)
    }
  }
  // A field with a value is written `name: value`, which shrubbery gives us as
  // a group with a block. Any of those makes this a record.
  let mut keyed = false
  for g in gs {
    if split(g).block is Some(_) {
      keyed = true
      break
    }
  }
  if keyed || typ is Some(_) {
    let fields = []
    for g in gs {
      let p = split(g)
      let name = if p.head.length() == 1 && as_id(p.head[0]) is Some(s) {
        s
      } else {
        fail_at("expected a field name", p.span, source=src)
      }
      let value = match p.block {
        Some(bs) =>
          if bs.length() == 1 {
            Some(parse_group(bs[0], src))
          } else {
            fail_at("a field takes one value", p.span, source=src)
          }
        None => None
      }
      fields.push((name, value))
    }
    return node(RecordLit(typ~, fields~), span)
  }
  let items = []
  for g in gs {
    items.push(parse_expr(Cursor::new(children(g), src), 0))
  }
  node(SetLit(items), span)
}

///|
fn parse_primary(c : Cursor) -> @wap.Node raise ParseError {
  let here = c.rest_span()
  match c.next() {
    None => fail_at("expected an expression", here, source=c.src)
    Some(t) => {
      let sp = node_span(t)
      match t.it {
        Lit(d) =>
          match d {
            Int_(_) => node(Int(raw_text(t)), sp)
            Flo(_) => node(Float(raw_text(t)), sp)
            Str(s) => node(StrLit(s), sp)
            Bool_(b) => node(BoolLit(b), sp)
            Ch(ch) => node(CharLit(ch), sp)
            _ => fail_at("this literal has no wap meaning", sp, source=c.src)
          }
        Id("null") => node(Null, sp)
        Id("true") => node(BoolLit(true), sp)
        Id("false") => node(BoolLit(false), sp)
        Id("char") =>
          // `char"A"` -- two terms, because shrubbery's `'` is a bracket.
          match c.peek() {
            Some(s) =>
              match as_str(s) {
                Some(text) => {
                  c.i += 1
                  if text.length() == 0 {
                    fail_at("an empty character literal", sp, source=c.src)
                  }
                  node(CharLit(text.get_char(0).unwrap()), sp)
                }
                None => node(Var("char"), sp)
              }
            None => node(Var("char"), sp)
          }
        Id(name) => node(Var(name), sp)
        Parens(gs) => {
          if gs.length() == 1 {
            let inner = parse_expr(Cursor::new(children(gs[0]), c.src), 0)
            return node(inner.it, sp)
          }
          let items = []
          for g in gs {
            items.push(parse_expr(Cursor::new(children(g), c.src), 0))
          }
          node(TupleLit(items), sp)
        }
        Brackets(gs) => {
          let items = []
          for g in gs {
            items.push(parse_expr(Cursor::new(children(g), c.src), 0))
          }
          node(ArrayLit(typ=None, items~), sp)
        }
        Braces(gs) => braced(None, gs, sp, c.src)
        Kw(k) => node(Var("~" + k), sp)
        _ => fail_at("expected an expression", sp, source=c.src)
      }
    }
  }
}
