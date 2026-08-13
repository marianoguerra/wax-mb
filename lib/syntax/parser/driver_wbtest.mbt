// The `Expecting …` list's rendering.
//
// Whitebox, because the interesting cases are properties of the renderer, not
// of any one malformed file: a class that must NOT collapse needs a state where
// exactly one of its members is legal, and no input is guaranteed to produce
// one. The end-to-end path is covered by the differential harness.

///|
test "empty set has no list to render" {
  inspect(expecting_message([]), content="Syntax error.")
}

///|
test "one item stands alone" {
  inspect(expecting_message([TK_RBRACE]), content="Expecting '}'.")
}

///|
test "two items keep the comma before 'or'" {
  // As the reference's `format_human_list` does: "a, or b", not "a or b".
  inspect(
    expecting_message([TK_LBRACE, TK_QUOTE]),
    content="Expecting ''', or '{'.",
  )
}

///|
test "sorted lexicographically, not shortlex" {
  // MoonBit's `Compare` for String orders by length first, which would put
  // '{' (one character) ahead of 'do'. The reference sorts with OCaml's
  // String.compare, so 'd' < '{' decides it.
  inspect(
    expecting_message([TK_LBRACE, TK_DO]),
    content="Expecting 'do', or '{'.",
  )
}

///|
test "a lone class member keeps its own spelling" {
  // Rendering a single legal operator as "an operator" would suggest the other
  // 26 are legal too.
  inspect(
    expecting_message([TK_PLUS, TK_RBRACE]),
    content="Expecting '+', or '}'.",
  )
}

///|
test "two or more members collapse into the class label" {
  inspect(
    expecting_message([TK_PLUS, TK_MINUS, TK_RBRACE]),
    content="Expecting '}', or an operator.",
  )
}

///|
test "each class collapses independently" {
  inspect(
    expecting_message([TK_PLUS, TK_STAR, TK_EQUALEQUAL, TK_LTS, TK_GEU, TK_SEMI]),
    content="Expecting ';', a comparison operator, or an operator.",
  )
}

///|
test "a repeated kind is listed once" {
  inspect(
    expecting_message([TK_RBRACE, TK_SEMI, TK_RBRACE]),
    content="Expecting ';', or '}'.",
  )
}

///|
test "a borrowed message may only name tokens this state accepts" {
  // `signature` is the sorted spellings of the acceptable set, as
  // `expected_signature` writes it.
  let sig = "';' '}' 'as'"
  assert_true(
    message_fits("Assuming that X is complete, expecting ';', or '}'.", sig),
  )
  // The message from a state where '{' could follow: not here, so not borrowed.
  assert_false(message_fits("Expecting '{', or '}'.", sig))
  // Nothing quoted, nothing to contradict.
  assert_true(message_fits("Expecting an expression.", sig))
}

///|
test "the QUOTE token's own spelling is read as one token" {
  // `'''` is three quote characters: the token IS a quote.
  assert_true(message_fits("Expecting ''', or '{'.", "''' '{'"))
  assert_false(message_fits("Expecting ''', or '{'.", "'{'"))
}

///|
test "a message with an unpaired quote is prose" {
  // Nothing in the golden looks like this, but a stray apostrophe must not
  // silently reject a message.
  assert_true(message_fits("Expecting the module's end.", "';'"))
}

///|
test "the reference's own message is used when the stack is one it knows" {
  // The whole point of parser_messages.mbt: the subject clause names the
  // construct under way, which no acceptable-token set determines.
  let r = parse_string("fn g(x: i32) -> i32;\n")
  inspect(
    r.errors[0].message,
    content=(
      #|Assuming that the function type is complete, expecting ''', or '{'.
    ),
  )
}

///|
test "the labels the reference draws under the snippet" {
  // Both kinds at once: the subject the hedge names, then the delimiter the
  // construct opened with. Output is byte-identical to the reference's on this
  // input, labels included.
  let r = parse_string("type t = { a: i32 b: i32 };\n")
  inspect(
    r.errors[0].message,
    content="Assuming that the structure type is complete, expecting '}'.",
  )
  inspect(
    labels_of(r.errors[0]),
    content=(
      #|11-17 this structure type
      #|9-10 This '{' opens the enclosing construct.
    ),
  )
}

///|
test "a state the table does not cover falls back, labels and all" {
  // The reference says "Assuming that the attributes are complete, expecting a
  // definition." here and underlines the attributes. Its message table is
  // keyed by ITS states; the sentence that produced this one lands in a
  // different state of ours, so we have neither its wording nor its label.
  // Falling back is the whole design: less specific, never wrong.
  let r = parse_string("#[likely] if c { nop; }\n")
  inspect(
    r.errors[0].message,
    content="Expecting '#', 'const', 'data', 'elem', 'fn', 'let', 'memory', 'table', or 'tag'.",
  )
  inspect(labels_of(r.errors[0]), content="")
}

///|
test "no enclosing delimiter, no label" {
  // The scan finds nothing open at the top level, and the reference emits no
  // such label there either.
  let lexed = @lexer.tokens_from_string("type t = i32;")
  inspect(
    enclosing_opener(lexed.tokens, lexed.tokens.length()) is None,
    content="true",
  )
}

///|
/// `start-end text` per related label, one per line: what a diagnostic draws
/// under the snippet, without the snippet.
fn labels_of(report : @basic.Report) -> String {
  let out = []
  for l in report.related {
    out.push("\{l.loc.start.cnum}-\{l.loc.end.cnum} \{l.message}")
  }
  out.join("\n")
}

///|
test "a syntax error earlier in the file beats a lexical one later" {
  // The reference's parser pulls tokens, so its lexer never reaches the `…`.
  // Ours lexes first, and without the prefix re-parse would report the stray
  // character three lines below the real problem.
  let r = parse_string("x;\ndo { … }\n")
  inspect(r.errors.length(), content="1")
  inspect(r.errors[0].loc.start.cnum, content="0")
  inspect(
    r.errors[0].message,
    content="Assuming that the attributes are complete, expecting a definition.",
  )
}

///|
test "a lexical error still wins when nothing precedes it" {
  // The prefix parses, so there is no earlier error to prefer.
  let r = parse_string("fn f() { … }\n")
  inspect(r.errors[0].message, content="Unexpected character '…'.")
  inspect(r.errors[0].loc.start.cnum, content="9")
}

///|
test "a semantic error earlier in the file beats a syntax error later" {
  // MoonYacc's actions cannot raise, so the `#[else]` check records and the
  // parse runs on into the malformed parameter list. First in the file wins.
  let r = parse_string("fn a() { #[else] { 1; } }\nfn b( { }\n")
  inspect(
    r.errors[0].message,
    content="An '#[else]' must directly follow an '#[if(...)]' group.",
  )
  inspect(r.errors[0].loc.start.cnum, content="9")
}

///|
test "recovery reports every syntax error, not just the first" {
  // The reference's own `check-all-errors.t` fixture. Both errors, at the same
  // spans it reports them at.
  let r = parse_recover(
    "fn f() -> i32 {\n    let x = ;\n    let y = * 2;\n    x + y;\n}\n",
  )
  inspect(
    describe(r.errors),
    content=(
      #|2:12 Expecting an expression.
      #|3:12 Expecting an expression.
    ),
  )
}

///|
test "a dropped separator is repaired by inserting one" {
  // Not by skipping to the next boundary: the state after a complete statement
  // can shift a `;`, and inserting it keeps the rest of the file intact. The
  // caret is where the `;` belongs, at the end of the previous line.
  let r = parse_recover("fn f() -> i32 {\n    let x = 1\n    x;\n}\n")
  inspect(describe(r.errors), content="2:13 Missing ';'.")
  inspect(r.errors[0].edit.unwrap().new_text, content=";")
}

///|
test "a `;` is not inserted where it would not help" {
  // `;` is shiftable right after `{` -- an empty statement is legal -- so
  // acceptability alone would report a missing separator in front of any junk
  // that follows a brace. The insertion has to UNBLOCK the offending token.
  let r = parse_recover("fn f() -> i32 {\n    @\n}\n")
  inspect(
    describe(r.errors),
    content="2:4 Assuming that the statement list is complete, expecting '}'.",
  )
}

///|
test "input that ends inside a block auto-closes it" {
  // Closing the construct keeps the function the user is still typing in the
  // tree, and the closer becomes the quick fix.
  let r = parse_recover("fn f() -> i32 {\n    let x = 1;\n")
  inspect(r.errors.length(), content="1")
  inspect(r.errors[0].edit.unwrap().new_text, content="}")
}

///|
test "a clean file recovers to silence" {
  let r = parse_recover("fn f() -> i32 {\n    1;\n}\n")
  inspect(r.errors.length(), content="0")
  inspect(r.module_ is Some(_), content="true")
}

///|
/// `line:col message` per error, one per line.
fn describe(errors : Array[@basic.Report]) -> String {
  let out = []
  for e in errors {
    out.push(
      "\{e.loc.start.lnum}:\{e.loc.start.cnum - e.loc.start.bol} \{e.message}",
    )
  }
  out.join("\n")
}
