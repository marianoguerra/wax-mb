// Every string here was read off the pinned reference binary with
//   tools/wax-ref check --error-format json <probe>
// rather than from the OCaml source, so the test pins observed behaviour rather
// than my reading of it. Note the absence of a trailing newline: the reference
// writes one into the message and both its renderers then drop it.

///|
test "lexical error messages match the reference verbatim" {
  assert_eq(
    @lexer.LexError::UnexpectedChar("$").message(),
    "Unexpected character '$'.",
  )
  assert_eq(@lexer.LexError::MalformedComment.message(), "Malformed comment.")
  assert_eq(@lexer.LexError::MalformedString.message(), "Malformed string.")
  assert_eq(
    @lexer.LexError::MalformedUnicodeEscape.message(),
    "Malformed Unicode escape.",
  )
  assert_eq(
    @lexer.LexError::InvalidUnicodeChar.message(),
    "Invalid Unicode character.",
  )
}

///|
test "only the two errors with hints carry them" {
  assert_eq(
    @lexer.LexError::MalformedComment.hint(),
    Some("A block comment must be closed with '*/'."),
  )
  assert_eq(
    @lexer.LexError::MalformedUnicodeEscape.hint(),
    Some(
      "A Unicode escape has the form '\\u{XXXX}', where 'XXXX' is the hexadecimal code of a Unicode scalar value.",
    ),
  )
  assert_eq(@lexer.LexError::MalformedString.hint(), None)
  assert_eq(@lexer.LexError::UnexpectedChar("$").hint(), None)
  assert_eq(@lexer.LexError::InvalidUnicodeChar.hint(), None)
}

///|
test "a lexical error becomes an error-severity report with no fix" {
  let loc : @basic.Location = {
    start: { fname: "p.wax", lnum: 1, bol: 0, cnum: 9 },
    end: { fname: "p.wax", lnum: 1, bol: 0, cnum: 10 },
  }
  let r = @lexer.LexError::UnexpectedChar("$").to_report(loc)
  assert_eq(r.severity, Error)
  assert_eq(r.message, "Unexpected character '$'.")
  assert_eq(r.warning, None)
  assert_eq(r.edit, None)
  assert_eq(r.loc.start.cnum, 9)
}
