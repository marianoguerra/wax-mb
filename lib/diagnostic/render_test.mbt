// The renderers, pinned against output captured from the reference binary.

///|
let src : String =
  #|fn f() -> i32 {
  #|    let x = 1
  #|    x;
  #|}
  #|

///|
fn pos(lnum : Int, bol : Int, cnum : Int) -> @basic.Position {
  { fname: "e1.wax", lnum, bol, cnum, }
}

///|
/// The syntax error the reference reports for `src`: the main span is the `x`
/// opening line 3, with a related label covering the unterminated statement.
fn sample() -> @diagnostic.Diagnostic {
  {
    loc: { start: pos(3, 30, 34), end: pos(3, 30, 35), },
    severity: Error,
    warning: None,
    message: @message.text(
      "Assuming that the statement is complete, expecting ';', or '}'.",
    ),
    hint: None,
    edit: None,
    related: [
      {
        loc: { start: pos(2, 16, 20), end: pos(2, 16, 29), },
        message: @message.text("this statement"),
      },
    ],
    universal: false,
  }
}

///|
fn render(
  format : @diagnostic.OutputFormat,
  d : @diagnostic.Diagnostic,
) -> String {
  let buf = StringBuilder()
  @diagnostic.output_error(
    @diagnostic.buffer_sink(buf),
    @diagnostic.get_theme(color=Never),
    format,
    Some(src),
    d,
  )
  buf.to_string()
}

///|
test "human format, byte for byte" {
  inspect(
    render(Human, sample()),
    content=(
      #|Error: Assuming that the statement is complete, expecting ';', or '}'.
      #| ──➤  e1.wax:3:5
      #|1 │ fn f() -> i32 {
      #|2 │     let x = 1
      #|  ·     ^^^^^^^^^ this statement
      #|3 │     x;
      #|  ·     ^
      #|4 │ }
      #|5 │ 
      #|
    ),
  )
}

///|
/// Field order is part of the contract, `edit` is omitted rather than null,
/// and the column is 0-based here against the human format's 1-based one.
test "json format, field order and nulls" {
  inspect(
    render(Json, sample()),
    content=(
      #|{"severity":"error","file":"e1.wax","startLine":3,"startColumn":4,"endLine":3,"endColumn":5,"startOffset":34,"endOffset":35,"message":"Assuming that the statement is complete, expecting ';', or '}'.","warning":null,"hint":null,"related":[{"startLine":2,"startColumn":4,"endLine":2,"endColumn":13,"startOffset":20,"endOffset":29,"message":"this statement"}]}
      #|
    ),
  )
}

///|
test "short format is one line with a 1-based column" {
  inspect(
    render(Short, sample()),
    content=(
      #|e1.wax:3:5: error: Assuming that the statement is complete, expecting ';', or '}'.
      #|
    ),
  )
}

///|
let multi_src : String =
  #|fn f() {
  #|  nop;
  #|  nop;
  #|  @
  #|}
  #|

///|
fn mpos(lnum : Int, bol : Int, cnum : Int) -> @basic.Position {
  { fname: "m.wax", lnum, bol, cnum, }
}

///|
/// A span crossing several lines is drawn as a spine rather than as a caret
/// block: a corner and a reach on the first line, a connector on each middle
/// line, and a closing corner reaching the final column, then the label.
test "multi-line spans render as a spine" {
  let d : @diagnostic.Diagnostic = {
    loc: { start: mpos(4, 23, 25), end: mpos(4, 23, 26), },
    severity: Error,
    warning: None,
    message: @message.text(
      "Assuming that the statement list is complete, expecting '}'.",
    ),
    hint: None,
    edit: None,
    related: [
      {
        loc: { start: mpos(1, 0, 7), end: mpos(1, 0, 8), },
        message: @message.text("This '{' opens the enclosing construct."),
      },
      {
        loc: { start: mpos(2, 9, 11), end: mpos(3, 16, 22), },
        message: @message.text("this statement list"),
      },
    ],
    universal: false,
  }
  let buf = StringBuilder()
  @diagnostic.output_error(
    @diagnostic.buffer_sink(buf),
    @diagnostic.get_theme(color=Never),
    Human,
    Some(multi_src),
    d,
  )
  inspect(
    buf.to_string(),
    content=(
      #|Error: Assuming that the statement list is complete, expecting '}'.
      #| ──➤  m.wax:4:3
      #|1 │ fn f() {
      #|  ·        ^ This '{' opens the enclosing construct.
      #|2 │   nop;
      #|  · ╭─^
      #|3 │   nop;
      #|  · ╰────^ this statement list
      #|4 │   @
      #|  ·   ^
      #|5 │ }
      #|6 │ 
      #|
    ),
  )
}
