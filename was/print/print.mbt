// Statements and module fields, printed.

///|
/// The output buffer and where the next line starts.
priv struct Out {
  sb : StringBuilder
  mut indent : Int
}

///|
fn Out::new() -> Out {
  { sb: StringBuilder(), indent: 0, }
}

///|
fn Out::line(self : Out, text : String) -> Unit {
  for _ in 0..<self.indent {
    self.sb.write_string("  ")
  }
  self.sb.write_string(text)
  self.sb.write_char('\n')
}

///|
fn Out::blank(self : Out) -> Unit {
  self.sb.write_char('\n')
}

///|
fn Out::nest(self : Out, body : () -> Unit) -> Unit {
  self.indent += 1
  body()
  self.indent -= 1
}

///|
/// Print a whole module.
pub fn module_(fields : @ast.LocModule) -> String {
  let out = Out::new()
  for i, f in fields {
    if i > 0 {
      out.blank()
    }
    out.field(f.desc)
  }
  out.sb.to_string()
}

///|
/// Print one instruction as a statement, which for the block-shaped forms
/// means a `:` and an indented body.
pub fn instr(i : @ast.Instr[@basic.Location]) -> String {
  let out = Out::new()
  out.stmt("", i)
  out.sb.to_string()
}

///|
/// True when the instruction needs a block, and so cannot be printed inline.
fn is_block_form(i : @ast.Instr[@basic.Location]) -> Bool {
  match i.desc {
    Block(..)
    | Loop(..)
    | While(..)
    | If(..)
    | Try(..)
    | TryCatch(..)
    | TryTable(..)
    | Match(..)
    | Dispatch(..)
    | IfAnnotation(..) => true
    _ => false
  }
}

///|
fn Out::body(self : Out, b : @ast.Body[@basic.Location]) -> Unit {
  self.nest(() => {
    if b.desc.length() == 0 {
      self.line("nop")
    } else {
      for x in b.desc {
        self.stmt("", x)
      }
    }
  })
}

///|
/// One `|` alternative: the marker and whatever heads it, then the body.
///
/// The indentation is the whole subtlety. A bare `|` needs its body indented
/// past the bar; a headed one -- `| ~bad:` -- needs it indented past the HEAD,
/// because that is where the group the `:` belongs to starts. One level is
/// enough for the first and two for the second, and getting it wrong produces
/// an empty block rather than an error at the point of the mistake.
fn Out::alt(self : Out, head : String, b : @ast.Body[@basic.Location]) -> Unit {
  // A one-instruction arm goes on the bar's line, which is how the same code
  // is written by hand.
  if b.desc.length() == 1 && not_block(b.desc[0]) {
    self.line("|" + head + " " + expr(b.desc[0]))
    return
  }
  self.line("|" + head)
  let levels = if head == "" { 1 } else { 2 }
  self.indent += levels
  if b.desc.length() == 0 {
    self.line("nop")
  } else {
    for x in b.desc {
      self.stmt("", x)
    }
  }
  self.indent -= levels
}

///|
fn not_block(i : @ast.Instr[@basic.Location]) -> Bool {
  !is_block_form(i)
}

///|
fn label_text(l : @ast.Ident?) -> String {
  match l {
    Some(i) => " ~" + i.name
    None => ""
  }
}

///|
/// An instruction as a group, with whatever has to sit in front of it.
fn Out::stmt(
  self : Out,
  prefix : String,
  i : @ast.Instr[@basic.Location],
) -> Unit {
  match i.desc {
    // A binding or a return whose value is a block form keeps its head on the
    // same line: `let x = if c` and then the alternatives.
    Let(bs, Some(v)) if is_block_form(v) =>
      self.stmt(prefix + let_head(bs) + " = ", v)
    Return(Some(v)) if is_block_form(v) => self.stmt(prefix + "return ", v)
    Set(id, None, v) if is_block_form(v) =>
      self.stmt(prefix + id.name + " = ", v)
    Sequence(xs) if prefix == "" && xs.any(is_block_form) =>
      for x in xs {
        self.stmt("", x)
      }
    Block(label~, typ~, block~) => {
      self.line(prefix + "do" + label_text(label) + block_type(typ) + ":")
      self.body(block)
    }
    Loop(label~, typ~, block~) => {
      self.line(prefix + "loop" + label_text(label) + block_type(typ) + ":")
      self.body(block)
    }
    While(label~, cond~, step~, block~) => {
      let step_text = match step {
        Some(s) => " ~step(" + expr(s) + ")"
        None => ""
      }
      self.line(
        prefix +
        "while" +
        label_text(label) +
        " " +
        expr(cond) +
        step_text +
        ":",
      )
      self.body(block)
    }
    If(label~, typ~, cond~, if_block~, else_block~) => {
      self.line(
        prefix +
        "if" +
        label_text(label) +
        " " +
        expr(cond) +
        block_type(typ) +
        ":",
      )
      self.body(if_block)
      match else_block {
        Some(b) => self.alt("", b)
        None => ()
      }
    }
    Match(scrutinee~, arms~, default~) => {
      self.line(prefix + "match " + expr(scrutinee))
      for a in arms {
        let (pat, body) = a
        self.alt(" " + pattern_text(pat) + ":", body)
      }
      self.alt(" _:", default)
    }
    Dispatch(index~, cases~, default~, arms~) => {
      let table = cases.map(c => "~" + c.name) + ["else ~" + default.name]
      self.line(
        prefix + "dispatch " + expr(index) + " [" + table.join(", ") + "]",
      )
      for a in arms {
        let (label, body) = a
        self.alt(" ~" + label.name + ":", body)
      }
    }
    TryTable(label~, typ~, catches~, block~) => {
      self.line(
        prefix +
        "try" +
        label_text(label) +
        " on [" +
        catches.map(catch_text).join(", ") +
        "]" +
        block_type(typ) +
        ":",
      )
      self.body(block)
    }
    TryCatch(label~, typ~, block~, arms~) => {
      self.line(prefix + "try" + label_text(label) + block_type(typ) + ":")
      self.body(block)
      for a in arms {
        self.alt(" " + arm_head(a) + ":", a.arm_body)
      }
    }
    Try(label~, typ~, block~, catches~, catch_all~) => {
      self.line(
        prefix + "try_legacy" + label_text(label) + block_type(typ) + ":",
      )
      self.body(block)
      for c in catches {
        let (tag, body) = c
        self.alt(" " + tag.name + ":", body)
      }
      match catch_all {
        Some(b) => self.alt(" _:", b)
        None => ()
      }
    }
    IfAnnotation(cond~, then_body~, else_body~) => {
      self.line(prefix + "cfg(" + cond_text(cond) + "):")
      self.body(then_body)
      match else_body {
        Some(b) => self.alt("", b)
        None => ()
      }
    }
    _ => self.line(prefix + expr(i))
  }
}

///|
fn let_head(
  bs : Array[(@ast.Ident?, @wasm_types.ValType[@ast.Ident]?)],
) -> String {
  let_text(bs, None)
}

///|
fn pattern_text(p : @ast.MatchPattern) -> String {
  match p {
    MatchNull => "null"
    MatchCast(Some(n), rt) => n.name + " :: " + reftype(rt)
    MatchCast(None, rt) => reftype(rt)
  }
}

///|
fn arm_head(a : @ast.TryCatchArm[@basic.Location]) -> String {
  match a.arm_tag {
    None => "_"
    Some(t) => {
      let types = if a.arm_types.length() == 0 {
        ""
      } else {
        "(" + a.arm_types.map(valtype).join(", ") + ")"
      }
      t.name + types + (if a.arm_ref { "!" } else { "" })
    }
  }
}

///|
fn catch_text(c : @ast.Catch) -> String {
  match c {
    Catch(t, l) => t.name + " -> ~" + l.name
    CatchRef(t, l) => t.name + "! -> ~" + l.name
    CatchAll(l) => "_ -> ~" + l.name
    CatchAllRef(l) => "_! -> ~" + l.name
  }
}

///|
fn cond_text(c : @wasm_types.Cond) -> String {
  match c {
    Var(v) => v.desc
    Str(s) => string_text(s.desc)
    Version(a, b, d) =>
      a.to_string() + "." + b.to_string() + "." + d.to_string()
    Not(x) => "!" + cond_text(x)
    And(xs) => xs.map(cond_text).join(" && ")
    Or(xs) => xs.map(cond_text).join(" || ")
    Cmp(op, a, d) => {
      let o = match op {
        Eq => "=="
        Ne => "!="
        Lt => "<"
        Gt => ">"
        Le => "<="
        Ge => ">="
      }
      cond_text(a) + " " + o + " " + cond_text(d)
    }
  }
}
