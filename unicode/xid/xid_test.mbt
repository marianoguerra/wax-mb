// Spot-checks against known Unicode facts. The table is generated, so these
// guard the transliteration and the binary search, not the data itself.

///|
test "ASCII letters start identifiers, digits do not" {
  assert_true(@xid.is_xid_start('a'.to_int()))
  assert_true(@xid.is_xid_start('Z'.to_int()))
  assert_false(@xid.is_xid_start('0'.to_int()))
  // '_' is XID_Continue but NOT XID_Start -- the Wax lexer relies on this,
  // spelling the leading-underscore case as a separate grammar alternative.
  assert_false(@xid.is_xid_start('_'.to_int()))
  assert_true(@xid.is_xid_continue('_'.to_int()))
  assert_true(@xid.is_xid_continue('7'.to_int()))
}

///|
test "non-ASCII letters are accepted, punctuation and emoji are not" {
  assert_true(@xid.is_xid_start(0x00E9)) // é
  assert_true(@xid.is_xid_start(0x03B1)) // α
  assert_true(@xid.is_xid_start(0x4E00)) // 一
  assert_false(@xid.is_xid_start(0x1F600)) // emoji
  assert_false(@xid.is_xid_start(0x0020)) // space
  assert_false(@xid.is_xid_start(0x00A9)) // ©
}

///|
test "combining marks continue but do not start" {
  assert_false(@xid.is_xid_start(0x0301)) // combining acute
  assert_true(@xid.is_xid_continue(0x0301))
}

///|
test "binary search handles range boundaries and the extremes" {
  // First range in the start table is 0x41-0x5A: probe both edges and outside.
  assert_false(@xid.is_xid_start(0x40))
  assert_true(@xid.is_xid_start(0x41))
  assert_true(@xid.is_xid_start(0x5A))
  assert_false(@xid.is_xid_start(0x5B))
  // Below every range, and above the last.
  assert_false(@xid.is_xid_start(0))
  assert_false(@xid.is_xid_start(0x10FFFF))
  assert_false(@xid.is_xid_continue(0))
}
