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

///|
/// The UTF-8 bytes of `s`.
pub fn utf8_bytes(s : String) -> Array[Int] {
  let out = []
  for c in s {
    let n = c.to_int()
    if n < 0x80 {
      out.push(n)
    } else if n < 0x800 {
      out.push(0xC0 | (n >> 6))
      out.push(0x80 | (n & 0x3F))
    } else if n < 0x10000 {
      out.push(0xE0 | (n >> 12))
      out.push(0x80 | ((n >> 6) & 0x3F))
      out.push(0x80 | (n & 0x3F))
    } else {
      out.push(0xF0 | (n >> 18))
      out.push(0x80 | ((n >> 12) & 0x3F))
      out.push(0x80 | ((n >> 6) & 0x3F))
      out.push(0x80 | (n & 0x3F))
    }
  }
  out
}

///|
/// Whether `s` contains a character that forces hex escaping.
///
/// Control characters other than tab, newline and carriage return, plus
/// U+007F. In valid UTF-8 these are always single ASCII bytes.
fn has_hex_escape(s : String) -> Bool {
  for c in s {
    let n = c.to_int()
    if (n < 32 && n != 9 && n != 10 && n != 13) || n == 127 {
      return true
    }
  }
  false
}

///|
fn hex2(n : Int) -> String {
  let digits = "0123456789abcdef"
  let hi = digits.unsafe_get((n >> 4) & 0xF).to_int().unsafe_to_char()
  let lo = digits.unsafe_get(n & 0xF).to_int().unsafe_to_char()
  hi.to_string() + lo.to_string()
}

///|
/// The text `b` denotes, or `None` when it is not valid UTF-8.
///
/// `decode` raising IS the validity test; there is no separate check.
pub fn utf8_text(b : Bytes) -> String? {
  Some(@utf8.decode(b[:])) catch {
    _ => None
  }
}

///|
/// Escape a BYTE STRING for printing, and report its display width.
///
/// Bytes, not a String: a Wax string literal is a byte string that need not be
/// valid UTF-8, and that validity is precisely what selects the branch below.
///
/// ALL-OR-NOTHING. If the bytes are not valid UTF-8, or any character needs a
/// hex escape, EVERY byte is dumped as one -- `a\x01b` prints as
/// `\x61\x01\x62`, not as a readable `a` and `b` around an escape. The
/// reference does this deliberately: such a string is binary data, and
/// interleaving decoded text with byte escapes reads as though the text part
/// were meaningful.
///
/// Otherwise the text stays readable, with only the quote, the backslash and
/// the three whitespace escapes touched.
///
/// The width is returned alongside because the escaped form is what occupies
/// columns, and it is not the width of the original.
pub fn escape_string(s : Bytes, hex_prefix? : String = "") -> (Int, String) {
  let buf = StringBuilder::new()
  match utf8_text(s) {
    Some(t) if !has_hex_escape(t) =>
      for c in t {
        let n = c.to_int()
        if n >= 32 && n != 127 && n != 34 && n != 92 {
          buf.write_char(c)
        } else {
          match n {
            9 => buf.write_string("\\t")
            10 => buf.write_string("\\n")
            13 => buf.write_string("\\r")
            34 => buf.write_string("\\\"")
            92 => buf.write_string("\\\\")
            _ => buf.write_string("\\" + hex_prefix + hex2(n))
          }
        }
      }
    _ =>
      for b in s {
        buf.write_string("\\" + hex_prefix + hex2(b.to_int()))
      }
  }
  let out = buf.to_string()
  (terminal_width(out), out)
}
