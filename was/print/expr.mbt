// Instructions, printed.
//
// Two modes, and the difference is what shrubbery makes of a newline. An
// expression is printed inline with parentheses where precedence needs them; a
// statement is printed as a group, which for the block-shaped forms means a
// `:` and an indented body.

///|
/// Precedence, matching the reader's table, which matches Wax's.
fn prec_of(op : @ast.BinOp) -> Int {
  match op {
    Eq | Ne | Lt(_) | Gt(_) | Le(_) | Ge(_) => 3
    Or => 5
    Xor => 7
    And => 9
    Shl | Shr(_) => 11
    Add | Sub => 13
    Mul | Div(_) | Rem(_) => 15
  }
}

///|
/// The was spelling of an operator. `~` is signed, `$` is unsigned, and a bare
/// operator is the one Wax leaves unannotated.
fn op_text(op : @ast.BinOp) -> String {
  fn sign(s : @wasm_types.Signage) -> String {
    match s {
      Signed => "~"
      Unsigned => "$"
    }
  }

  fn opt(s : @wasm_types.Signage?) -> String {
    match s {
      Some(x) => sign(x)
      None => ""
    }
  }

  match op {
    Add => "+"
    Sub => "-"
    Mul => "*"
    Div(s) => "/" + opt(s)
    Rem(s) => "%" + sign(s)
    Shl => "<<"
    Shr(s) => ">>" + sign(s)
    And => "&"
    Or => "||"
    Xor => "^"
    Eq => "=="
    Ne => "!="
    Lt(s) => "<" + opt(s)
    Gt(s) => ">" + opt(s)
    Le(s) => "<=" + opt(s)
    Ge(s) => ">=" + opt(s)
  }
}

///|
fn unop_text(op : @ast.UnOp) -> String {
  match op {
    Neg => "-"
    Pos => "+"
    Not => "!"
  }
}

///|
/// A character literal, as `char"..."`.
fn char_text(c : Char) -> String {
  let body = match c {
    '\n' => "\\n"
    '\r' => "\\r"
    '\t' => "\\t"
    '\\' => "\\\\"
    '"' => "\\\""
    _ =>
      if c.to_int() < 0x20 {
        "\\u{" + c.to_int().to_string() + "}"
      } else {
        c.to_string()
      }
  }
  "char\"" + body + "\""
}

///|
/// A string literal, from the bytes Wax stores.
fn string_text(b : Bytes) -> String {
  let sb = StringBuilder()
  sb.write_char('"')
  for i in 0..<b.length() {
    let c = b[i].to_int()
    if c == 0x22 {
      sb.write_string("\\\"")
    } else if c == 0x5C {
      sb.write_string("\\\\")
    } else if c == 0x0A {
      sb.write_string("\\n")
    } else if c == 0x0D {
      sb.write_string("\\r")
    } else if c == 0x09 {
      sb.write_string("\\t")
    } else if c < 0x20 || c >= 0x7F {
      sb.write_string("\\u{" + c.to_string() + "}")
    } else {
      sb.write_char(c.unsafe_to_char())
    }
  }
  sb.write_char('"')
  sb.to_string()
}

///|
/// An expression, parenthesised when the context binds tighter than it does.
pub fn expr(i : @ast.Instr[@basic.Location], min_prec? : Int = 0) -> String {
  match i.desc {
    Int(s) => s
    Float(s) => s
    Char(c) => char_text(c)
    Str(None, b) => string_text(b)
    Str(Some(t), b) => t.name + string_text(b)
    Null => "null"
    Hole => "_"
    Nop => "nop"
    Unreachable => "unreachable"
    Get(id) => id.name
    Path(ns, n) => ns.name + "::" + n.name
    StructGet(v, f) => expr(v, min_prec=90) + "." + f.name
    GetDescriptor(v) => expr(v, min_prec=90) + ".descriptor"
    NonNull(v) => expr(v, min_prec=90) + "!"
    ArrayGet(a, idx) => expr(a, min_prec=90) + "[" + expr(idx) + "]"
    Call(f, args) => call_text(f, args)
    Labelled(n, v) => n.name + ": " + expr(v)
    Struct(name, fields) => struct_text(opt_name(name), fields)
    StructDesc(d, fields) => struct_text("descriptor(" + expr(d) + ")", fields)
    StructDefault(name) => opt_name(name) + "{..}"
    StructDefaultDesc(d) => "descriptor(" + expr(d) + "){..}"
    Array(t, init, n) => opt_name(t) + "[" + expr(init) + " ** " + expr(n) + "]"
    ArrayDefault(t, n) => opt_name(t) + "[.. ** " + expr(n) + "]"
    ArrayFixed(t, elems) =>
      opt_name(t) + "[" + elems.map(e => expr(e)).join(", ") + "]"
    ArraySegment(t, d, off, n) =>
      opt_name(t) + "[" + d.name + " at " + expr(off) + " ** " + expr(n) + "]"
    Cast(v, ct) =>
      paren_if(min_prec > 17, expr(v, min_prec=18) + " as " + cast_text(ct))
    CastDesc(v, nullable, d) =>
      paren_if(
        min_prec > 17,
        expr(v, min_prec=18) +
        " as " +
        (if nullable { "?" } else { "" }) +
        "descriptor(" +
        expr(d) +
        ")",
      )
    Test(v, rt) =>
      paren_if(min_prec > 17, expr(v, min_prec=18) + " is " + reftype(rt))
    On(v, clauses) =>
      paren_if(
        min_prec > 17,
        expr(v, min_prec=18) + " on [" + on_text(clauses) + "]",
      )
    BinOpI(op, a, b) => {
      let p = prec_of(op.desc)
      paren_if(
        min_prec > p,
        expr(a, min_prec=p) +
        " " +
        op_text(op.desc) +
        " " +
        expr(b, min_prec=p + 1),
      )
    }
    UnOpI(op, v) =>
      paren_if(min_prec > 80, unop_text(op.desc) + expr(v, min_prec=80))
    Set(id, None, v) => id.name + " = " + expr(v)
    Set(id, Some(op), v) => id.name + " " + op_text(op.desc) + "= " + expr(v)
    Tee(id, v) => id.name + " := " + expr(v)
    StructSet(r, f, v) => expr(r, min_prec=90) + "." + f.name + " = " + expr(v)
    ArraySet(a, idx, v) =>
      expr(a, min_prec=90) + "[" + expr(idx) + "] = " + expr(v)
    Let(bs, v) => let_text(bs, v)
    Return(Some(v)) => "return " + expr(v)
    Return(None) => "return"
    Br(l, Some(v)) => "br ~" + l.name + " " + expr(v)
    Br(l, None) => "br ~" + l.name
    BrIf(l, v) => "br_if ~" + l.name + " " + expr(v)
    BrOnNull(l, v) => "br_on_null ~" + l.name + " " + expr(v)
    BrOnNonNull(l, v) => "br_on_non_null ~" + l.name + " " + expr(v)
    BrOnCast(l, rt, v) =>
      "br_on_cast ~" + l.name + " " + reftype(rt) + " " + expr(v)
    BrOnCastFail(l, rt, v) =>
      "br_on_cast_fail ~" + l.name + " " + reftype(rt) + " " + expr(v)
    BrOnCastDescEq(l, nullable, d, v) =>
      "br_on_cast ~" +
      l.name +
      " " +
      (if nullable { "?" } else { "" }) +
      "descriptor(" +
      expr(d) +
      ") " +
      expr(v)
    BrOnCastDescEqFail(l, nullable, d, v) =>
      "br_on_cast_fail ~" +
      l.name +
      " " +
      (if nullable { "?" } else { "" }) +
      "descriptor(" +
      expr(d) +
      ") " +
      expr(v)
    BrTable(labels, v) =>
      "br_table [" + labels.map(l => "~" + l.name).join(", ") + "] " + expr(v)
    TailCall(f, args) => "become " + call_text(f, args)
    Throw(t, args) =>
      "throw " + t.name + "(" + args.map(a => expr(a)).join(", ") + ")"
    ThrowRef(v) => "throw_ref " + expr(v)
    Suspend(t, args) =>
      "suspend " + t.name + "(" + args.map(a => expr(a)).join(", ") + ")"
    ContNew(t, v) => t.name + "::new(" + expr(v) + ")"
    ContBind(t, u, args) =>
      t.name + "::bind(" + ([u.name] + args.map(a => expr(a))).join(", ") + ")"
    Resume(t, clauses, args) =>
      t.name +
      "::resume(" +
      args.map(a => expr(a)).join(", ") +
      ") on [" +
      on_text(clauses) +
      "]"
    ResumeThrow(t, tag, clauses, args) =>
      t.name +
      "::resume_throw(" +
      ([tag.name] + args.map(a => expr(a))).join(", ") +
      ") on [" +
      on_text(clauses) +
      "]"
    ResumeThrowRef(t, clauses, args) =>
      t.name +
      "::resume_throw_ref(" +
      args.map(a => expr(a)).join(", ") +
      ") on [" +
      on_text(clauses) +
      "]"
    Switch(t, tag, args) =>
      t.name +
      "::switch(" +
      ([tag.name] + args.map(a => expr(a))).join(", ") +
      ")"
    Select(c, a, b) =>
      "select(" + expr(c) + ", " + expr(a) + ", " + expr(b) + ")"
    Sequence(xs) => "(" + xs.map(x => expr(x)).join(", ") + ")"
    // The block-shaped forms have no inline spelling; a caller that reaches
    // here is printing one in a value position, which `stmt` handles instead.
    _ => "/* unprintable inline */"
  }
}

///|
fn paren_if(cond : Bool, s : String) -> String {
  if cond {
    "(" + s + ")"
  } else {
    s
  }
}

///|
fn opt_name(n : @ast.Ident?) -> String {
  match n {
    Some(i) => i.name
    None => ""
  }
}

///|
fn call_text(
  f : @ast.Instr[@basic.Location],
  args : Array[@ast.Instr[@basic.Location]],
) -> String {
  expr(f, min_prec=90) + "(" + args.map(a => expr(a)).join(", ") + ")"
}

///|
fn struct_text(
  name : String,
  fields : Array[(@ast.Ident, @ast.Instr[@basic.Location]?)],
) -> String {
  let out = []
  for f in fields {
    let (n, v) = f
    out.push(
      match v {
        Some(x) => n.name + ": " + expr(x)
        None => n.name
      },
    )
  }
  name + "{" + out.join(", ") + "}"
}

///|
fn on_text(clauses : Array[@ast.OnClause]) -> String {
  let out = []
  for c in clauses {
    out.push(
      match c {
        OnLabel(t, l) => t.name + " -> ~" + l.name
        OnSwitch(t) => t.name
      },
    )
  }
  out.join(", ")
}

///|
fn cast_text(ct : @ast.CastType) -> String {
  match ct {
    Value(v) => valtype(v)
    Signed(typ~, signage~, ..) =>
      (match typ {
        I32 => "i32"
        I64 => "i64"
        F32 => "f32"
        F64 => "f64"
      }) +
      (match signage {
        Signed => "_s"
        Unsigned => "_u"
      })
    Func(nullable~, sign~) =>
      (if nullable { "&?" } else { "&" }) + "fn" + signature(sign)
  }
}

///|
fn let_text(
  bs : Array[(@ast.Ident?, @wasm_types.ValType[@ast.Ident]?)],
  v : @ast.Instr[@basic.Location]?,
) -> String {
  let names = []
  for b in bs {
    let (n, t) = b
    let name = match n {
      Some(i) => i.name
      None => "_"
    }
    names.push(
      match t {
        Some(ty) => name + " :: " + valtype(ty)
        None => name
      },
    )
  }
  let head = if names.length() == 1 {
    "let " + names[0]
  } else {
    "let (" + names.join(", ") + ")"
  }
  match v {
    Some(x) => head + " = " + expr(x)
    None => head
  }
}
