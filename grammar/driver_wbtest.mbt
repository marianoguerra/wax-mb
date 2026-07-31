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
