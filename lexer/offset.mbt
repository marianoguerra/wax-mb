// UTF-8 byte offsets over a UTF-16 string.
//
// THE central impedance mismatch of this port. The reference is OCaml: its
// source is a byte string, and every position it reports -- `pos_cnum`,
// `pos_bol`, and hence the `startOffset`/`endOffset`/`startColumn` fields of
// `--error-format json` -- is a UTF-8 BYTE offset. Columns are byte counts too,
// since a column is just `pos_cnum - pos_bol`.
//
// MoonBit strings are UTF-16, so a StringView's own indices are code units and
// do not agree with the reference on any line containing non-ASCII. Since
// oracle 3 compares those offsets exactly, the lexer tracks UTF-8 byte offsets
// itself and never reports a UTF-16 index.
//
// Scanning is strictly left to right, so the cost is one pass over each
// consumed chunk -- O(n) overall, not O(n^2).

///|
/// The number of bytes `c` occupies when encoded as UTF-8.
///
/// A code point above U+FFFF is stored in MoonBit as a surrogate PAIR (two
/// UTF-16 code units) but encodes to four UTF-8 bytes, so callers iterating by
/// character must not also add anything for the low surrogate.
pub fn utf8_len_of_char(c : Char) -> Int {
  let n = c.to_int()
  if n < 0x80 {
    1
  } else if n < 0x800 {
    2
  } else if n < 0x10000 {
    3
  } else {
    4
  }
}

///|
/// The UTF-8 byte length of `v`.
pub fn utf8_len(v : StringView) -> Int {
  let mut n = 0
  for c in v {
    n += utf8_len_of_char(c)
  }
  n
}
