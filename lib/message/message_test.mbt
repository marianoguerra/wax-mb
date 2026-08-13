// The emphasis rule and the reflow behaviour are what these pin down.

///|
fn plain(m : @message.Message) -> String {
  @message.to_plain_string(m)
}

///|
fn coloured(m : @message.Message) -> String {
  @printer.run_string(width=1000, p => @message.render(p, @colors.wax_theme, m))
}

///|
/// An emphasized atom is coloured when there is colour and quoted when there is
/// not -- never both, and never neither.
test "emphasis is colour or quotes, never both" {
  let m = @message.text("cannot find").sep(@message.ident("foo"))
  assert_eq(plain(m), "cannot find 'foo'")
  // Coloured: no quotes, and the identifier carries the theme's yellow.
  assert_eq(
    coloured(m),
    "cannot find " + @colors.yellow + "foo" + @colors.reset,
  )
}

///|
/// A styled-but-unemphasized atom is never quoted, coloured or not.
test "styled atoms are not quoted" {
  assert_eq(plain(@message.int(42)), "42")
  assert_eq(plain(@message.styled(Type, "i32")), "i32")
  // ...while type_ IS emphasized, so it quotes.
  assert_eq(plain(@message.type_("i32")), "'i32'")
}

///|
test "uint64 prints magnitude, not a negative" {
  assert_eq(plain(@message.uint64(-1L)), "18446744073709551615")
  assert_eq(plain(@message.int64(-1L)), "-1")
}

///|
test "enumerate joins with commas and a conjunction" {
  let items = [@message.code("a"), @message.code("b"), @message.code("c")]
  assert_eq(plain(@message.enumerate(items)), "'a', 'b' or 'c'")
  assert_eq(plain(@message.enumerate(items, conj="and")), "'a', 'b' and 'c'")
  assert_eq(plain(@message.enumerate([@message.code("a")])), "'a'")
  assert_eq(plain(@message.enumerate([])), "")
}

///|
/// Runs of spaces collapse to one soft break, so fragments joined with `seq`
/// can carry their own separating space without doubling it.
test "prose collapses space runs" {
  assert_eq(plain(@message.text("a   b")), "a b")
  assert_eq(plain(@message.text(" leading")), "leading")
  assert_eq(plain(@message.text("trailing ")), "trailing")
  assert_eq(plain(@message.text("one ").seq(@message.text("two"))), "one two")
}

///|
/// Prose reflows at the render width; a newline is a HARD break that survives
/// however wide the margin is.
test "prose reflows, newlines do not" {
  let m = @message.text("alpha beta gamma")
  assert_eq(
    @printer.run_string(width=11, p => @message.render(p, @colors.no_color, m)),
    "alpha beta\ngamma",
  )
  // A trailing newline is dropped rather than leaving a dangling blank line.
  assert_eq(plain(@message.text("a\nb")), "a\nb")
  assert_eq(plain(@message.text("a\n")), "a")
}
