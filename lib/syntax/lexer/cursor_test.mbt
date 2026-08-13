// The cursor is where UTF-16 indexing and UTF-8 byte offsets are kept in step.
// Every position the lexer reports comes from here, and oracle 3 compares those
// offsets exactly against the reference, so the arithmetic is pinned closely.

///|
fn drain(c : @lexer.Cursor) -> Unit {
  while c.bump() is Some(_) {

  }
}

///|
test "ASCII: byte offset tracks character count" {
  let c = @lexer.Cursor::new("abc")
  assert_eq(c.pos().cnum, 0)
  c.bump() |> ignore
  assert_eq(c.pos().cnum, 1)
  drain(c)
  assert_eq(c.pos().cnum, 3)
  assert_true(c.at_end())
}

///|
test "non-ASCII: byte offset outruns the UTF-16 index" {
  // "é→😀": 1+1+2 = 4 UTF-16 units, but 2+3+4 = 9 UTF-8 bytes.
  let c = @lexer.Cursor::new("é→😀")
  c.bump() |> ignore
  assert_eq(c.pos().cnum, 2)
  c.bump() |> ignore
  assert_eq(c.pos().cnum, 5)
  c.bump() |> ignore // one bump consumes the whole surrogate pair
  assert_eq(c.pos().cnum, 9)
  assert_true(c.at_end())
}

///|
test "newline advances the line and moves bol past the break" {
  let c = @lexer.Cursor::new("ab\ncd")
  drain_to(c, 3)
  let p = c.pos()
  assert_eq(p.lnum, 2)
  assert_eq(p.bol, 3) // 'c' is the first byte of line 2
  assert_eq(p.cnum, 3)
  assert_eq(p.column0(), 0) // column is measured from bol
  c.bump() |> ignore
  assert_eq(c.pos().column0(), 1)
}

///|
fn drain_to(c : @lexer.Cursor, byte : Int) -> Unit {
  while c.pos().cnum < byte && c.bump() is Some(_) {

  }
}

///|
test "CRLF is one line break, and bol lands after both bytes" {
  let c = @lexer.Cursor::new("ab\r\ncd")
  c.bump() |> ignore
  c.bump() |> ignore
  c.bump() |> ignore // consumes \r AND \n together
  let p = c.pos()
  assert_eq(p.lnum, 2)
  assert_eq(p.cnum, 4)
  assert_eq(p.bol, 4)
  assert_eq(p.column0(), 0)
}

///|
test "a lone CR still ends a line" {
  let c = @lexer.Cursor::new("a\rb")
  c.bump() |> ignore
  c.bump() |> ignore
  assert_eq(c.pos().lnum, 2)
  assert_eq(c.pos().bol, 2)
}

///|
test "columns on a line with non-ASCII are BYTE counts, like the reference" {
  // `é` is 2 bytes, so the character after it sits at column 2, not 1.
  let c = @lexer.Cursor::new("éx")
  c.bump() |> ignore
  assert_eq(c.pos().column0(), 2)
}

///|
test "looking_at matches without consuming" {
  let c = @lexer.Cursor::new(">>s= rest")
  assert_true(c.looking_at(">>s="))
  assert_true(c.looking_at(">>s"))
  assert_false(c.looking_at(">>u"))
  assert_eq(c.pos().cnum, 0) // nothing consumed
  c.eat(">>s=")
  assert_eq(c.pos().cnum, 4)
  assert_true(c.looking_at(" rest"))
}

///|
test "looking_at does not run past the end" {
  let c = @lexer.Cursor::new(">>")
  assert_false(c.looking_at(">>s="))
  assert_true(c.looking_at(">>"))
}

///|
test "peek looks ahead without consuming; bump returns None at the end" {
  let c = @lexer.Cursor::new("ab")
  assert_eq(c.peek(), Some('a'))
  assert_eq(c.peek(n=1), Some('b'))
  assert_eq(c.peek(n=2), None)
  drain(c)
  assert_eq(c.bump(), None)
  assert_eq(c.peek(), None)
}

///|
test "span runs from a remembered start to the current position" {
  let c = @lexer.Cursor::new("fn foo")
  c.eat("fn ")
  let start = c.pos()
  c.eat("foo")
  let loc = c.span(start)
  assert_eq(loc.start.cnum, 3)
  assert_eq(loc.end.cnum, 6)
}
