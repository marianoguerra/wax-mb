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
