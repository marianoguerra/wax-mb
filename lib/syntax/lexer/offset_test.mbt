///|
test "utf8_len counts BYTES, not UTF-16 code units" {
  assert_eq(@lexer.utf8_len("abc"), 3)
  assert_eq(@lexer.utf8_len("é"), 2) // U+00E9  -> 2 bytes, 1 unit
  assert_eq(@lexer.utf8_len("→"), 3) // U+2192  -> 3 bytes, 1 unit
  assert_eq(@lexer.utf8_len("😀"), 4) // U+1F600 -> 4 bytes, 2 units
  // The mismatch this file exists to prevent: MoonBit says 2, UTF-8 says 4.
  assert_eq("😀".length(), 2)
}

///|
test "mixed text accumulates correctly" {
  //  f  n     é  (  )
  assert_eq(@lexer.utf8_len("fn é()"), 7)
  assert_eq(@lexer.utf8_len(""), 0)
}
