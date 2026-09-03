// The collection rules are small but each one encodes a real formatting
// decision, so they are pinned individually.

///|
fn loc(a : Int, b : Int) -> @basic.Location {
  {
    start: { fname: "t.wax", lnum: 1, bol: 0, cnum: a, },
    end: { fname: "t.wax", lnum: 1, bol: 0, cnum: b, },
  }
}

///|
test "a comment is anchored to the end of the preceding token" {
  let ctx = @trivia.Context::new()
  ctx.report_token(7) // e.g. `let x =` ends at byte 7
  ctx.report_item(LineComment, loc(8, 20), "// why")
  let e = ctx.entries()
  assert_eq(e.length(), 1)
  assert_eq(e[0].anchor, 7)
  // It trails a token, so it must not be treated as owning its own line.
  assert_eq(e[0].position, Inline)
}

///|
test "a comment with no preceding token on the line starts the line" {
  let ctx = @trivia.Context::new()
  ctx.report_item(LineComment, loc(0, 12), "// header")
  assert_eq(ctx.entries()[0].position, LineStart)
}

///|
test "a line comment ends its line, a block comment does not" {
  // After `// x`, the next comment is on a fresh line...
  let ctx = @trivia.Context::new()
  ctx.report_token(3)
  ctx.report_item(LineComment, loc(4, 8), "// a")
  ctx.report_item(LineComment, loc(9, 13), "// b")
  assert_eq(ctx.entries()[0].position, Inline)
  assert_eq(ctx.entries()[1].position, LineStart)

  // ...whereas after `/* x */` we are still mid-line.
  let ctx2 = @trivia.Context::new()
  ctx2.report_token(3)
  ctx2.report_item(BlockComment, loc(4, 11), "/* a */")
  ctx2.report_item(BlockComment, loc(12, 19), "/* b */")
  assert_eq(ctx2.entries()[0].position, Inline)
  assert_eq(ctx2.entries()[1].position, Inline)
}

///|
test "a blank line is only recorded when a line ends already empty" {
  let ctx = @trivia.Context::new()
  // `foo\n` -- the newline ends a line that had a token, so: not blank.
  ctx.report_token(3)
  ctx.report_newline()
  assert_eq(ctx.entries().length(), 0)
  // A second newline with nothing between: that line WAS empty.
  ctx.report_newline()
  assert_eq(ctx.entries().length(), 1)
  assert_eq(ctx.entries()[0].trivia, BlankLine)
  assert_eq(ctx.entries()[0].anchor, 3)
}

///|
test "consecutive blank lines are each recorded" {
  // Run length matters: the printer preserves how many blank lines there were,
  // so collapsing them here would silently reformat the source.
  let ctx = @trivia.Context::new()
  ctx.report_token(1)
  ctx.report_newline() // ends the line with the token
  ctx.report_newline() // blank
  ctx.report_newline() // blank
  assert_eq(ctx.entries().length(), 2)
}

///|
test "a file starting with a blank line records it" {
  // The context begins at_start_of_line, so a leading newline is a blank line
  // anchored at offset 0.
  let ctx = @trivia.Context::new()
  ctx.report_newline()
  assert_eq(ctx.entries().length(), 1)
  assert_eq(ctx.entries()[0].anchor, 0)
}

///|
test "entries come back in source order" {
  let ctx = @trivia.Context::new()
  ctx.report_item(LineComment, loc(0, 4), "// 1")
  ctx.report_token(10)
  ctx.report_item(LineComment, loc(11, 15), "// 2")
  let e = ctx.entries()
  assert_eq(e[0].trivia, Item(content="// 1", kind=LineComment, loc=loc(0, 4)))
  assert_eq(
    e[1].trivia,
    Item(content="// 2", kind=LineComment, loc=loc(11, 15)),
  )
}
