// Display-width helpers.
//
// Ported from wax/src/lib-utils/unicode.ml. Used in two places that both need
// DISPLAY width rather than byte or code-point count: the formatter, when
// deciding whether a construct fits in the target width, and the human
// diagnostic renderer, when positioning a caret under a source line.

///|
/// How many columns a tab advances from `pos`: to the next multiple of 8.
pub fn tab_width(pos : Int) -> Int {
  8 - (pos & 7)
}

///|
/// The display width of one character at column `pos`.
///
/// `pos` matters only for a tab, whose width depends on where it starts.
pub fn char_width(pos : Int, c : Char) -> Int {
  if c == '\t' {
    tab_width(pos)
  } else {
    @widths.get_width(c.to_int())
  }
}

///|
/// The width of `s` when displayed in a terminal, starting at column `offset`.
///
/// Not the byte length and not the character count: a combining mark is 0
/// columns wide and a CJK ideograph is 2.
pub fn terminal_width(s : String, offset? : Int = 0) -> Int {
  let mut acc = 0
  for c in s {
    acc += char_width(acc + offset, c)
  }
  acc
}

///|
/// Replace tabs with the spaces they display as, starting at column `offset`.
pub fn expand_tabs(s : String, offset? : Int = 0) -> String {
  if !s.contains("\t") {
    return s
  }
  let buf = StringBuilder::new()
  let mut pos = offset
  for c in s {
    if c == '\t' {
      let n = tab_width(pos)
      for _ in 0..<n {
        buf.write_char(' ')
      }
      pos += n
    } else {
      buf.write_char(c)
      pos += char_width(pos, c)
    }
  }
  buf.to_string()
}
