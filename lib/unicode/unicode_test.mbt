// Width is DISPLAY width, which is what the formatter's fits-on-a-line
// decisions and the diagnostic renderer's caret positioning both depend on.
// Byte length and character count are each wrong for a different set of inputs.

///|
test "ASCII is one column per character" {
  assert_eq(@unicode.terminal_width("abc"), 3)
  assert_eq(@unicode.terminal_width(""), 0)
}

///|
test "CJK is double width, combining marks are zero" {
  assert_eq(@unicode.terminal_width("世界"), 4) // 2 chars, 4 columns
  assert_eq(@unicode.terminal_width("\u{0301}"), 0) // combining acute
  // "é" written as e + combining acute is one column, though two code points.
  assert_eq(@unicode.terminal_width("e\u{0301}"), 1)
}

///|
test "an emoji is two columns but four UTF-8 bytes" {
  // Three different numbers for the same string: 2 columns, 2 UTF-16 units,
  // 4 UTF-8 bytes. Using the wrong one misaligns a caret.
  assert_eq(@unicode.terminal_width("😀"), 2)
  assert_eq("😀".length(), 2)
}

///|
test "a tab advances to the next multiple of 8" {
  assert_eq(@unicode.tab_width(0), 8)
  assert_eq(@unicode.tab_width(1), 7)
  assert_eq(@unicode.tab_width(7), 1)
  assert_eq(@unicode.tab_width(8), 8)
  // ...and its width depends on where it starts, which is why terminal_width
  // threads a column rather than summing per-character widths.
  assert_eq(@unicode.terminal_width("\t"), 8)
  assert_eq(@unicode.terminal_width("a\t"), 8) // 1 + 7
  assert_eq(@unicode.terminal_width("abcdefg\t"), 8) // 7 + 1
  assert_eq(@unicode.terminal_width("abcdefgh\t"), 16)
}

///|
test "expand_tabs reproduces what a terminal shows" {
  assert_eq(@unicode.expand_tabs("a\tb"), "a       b")
  assert_eq(@unicode.expand_tabs("\t"), "        ")
  // No tabs: returned unchanged, no allocation in the reference.
  assert_eq(@unicode.expand_tabs("plain"), "plain")
  // Offset shifts where the tab stop falls.
  assert_eq(@unicode.expand_tabs("\t", offset=7), " ")
}

///|
test "expanded tabs have the width they replaced" {
  for s in ["a\tb", "\tx", "ab\tcd\te"] {
    assert_eq(
      @unicode.terminal_width(s),
      @unicode.terminal_width(@unicode.expand_tabs(s)),
    )
  }
}
