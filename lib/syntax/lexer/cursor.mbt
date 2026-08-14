// The lexer's position over the source.
//
// A hand-written cursor rather than MoonBit's `lexscan` DSL. Two reasons:
//
//   * Byte offsets. `lexscan` hands back StringViews, whose indices are UTF-16
//     code units; every position this lexer reports has to be a UTF-8 byte
//     offset (see offset.mbt). A cursor that advances both counters together
//     keeps them in step by construction, instead of recomputing a byte length
//     for every matched chunk.
//
//   * The reference is a hand-written longest-match table with several
//     order-sensitive cases (`nan:0x1` must beat the `nan` keyword; `>>s=` must
//     beat `>>s` must beat `>>`). Expressing those as explicit maximal-munch
//     lookahead is more obviously faithful than trusting two different regex
//     engines to agree on tie-breaking.

///|
/// A cursor over the source, tracking the three counters a `Position` needs.
///
/// `cnum` and `bol` are UTF-8 byte offsets; `idx` is the UTF-16 index used to
/// slice the string. They advance together and must never be confused.
pub struct Cursor {
  src : String
  fname : String
  /// UTF-16 index into `src` -- for slicing only, never reported.
  mut idx : Int
  /// UTF-8 byte offset -- reported as `Position::cnum`.
  mut cnum : Int
  /// UTF-8 byte offset of the start of the current line.
  mut bol : Int
  mut lnum : Int
}

///|
pub fn Cursor::new(src : String, fname? : String = "") -> Cursor {
  { src, fname, idx: 0, cnum: 0, bol: 0, lnum: 1 }
}

///|
pub fn Cursor::pos(self : Cursor) -> Position {
  { fname: self.fname, lnum: self.lnum, bol: self.bol, cnum: self.cnum }
}

///|
pub fn Cursor::span(self : Cursor, from : Position) -> Location {
  { start: from, end: self.pos() }
}

///|
pub fn Cursor::at_end(self : Cursor) -> Bool {
  self.idx >= self.src.length()
}

///|
/// The character `n` UTF-16 units ahead, or `None` past the end.
///
/// `n` is a UTF-16 offset, so `peek(1)` after a surrogate-pair character lands
/// on its low surrogate. Callers only look ahead past ASCII (operators,
/// keywords, digits), where the distinction cannot arise.
pub fn Cursor::peek(self : Cursor, n? : Int = 0) -> Char? {
  let i = self.idx + n
  if i < 0 || i >= self.src.length() {
    None
  } else {
    Some(self.src.unsafe_get(i).to_int().unsafe_to_char())
  }
}

///|
/// Whether the source continues with `s` at the cursor.
pub fn Cursor::looking_at(self : Cursor, s : String) -> Bool {
  let n = s.length()
  if self.idx + n > self.src.length() {
    return false
  }
  for k in 0..<n {
    if self.src.unsafe_get(self.idx + k) != s.unsafe_get(k) {
      return false
    }
  }
  true
}

///|
/// Consume one character, keeping the byte offset and line counters in step.
///
/// Newline handling matters for position fidelity: `\r\n` is ONE line break,
/// and `bol` must land after it, so a column is measured from the first
/// character of the line's text.
pub fn Cursor::bump(self : Cursor) -> Char? {
  if self.at_end() {
    return None
  }
  let c = self.src.unsafe_get(self.idx).to_int().unsafe_to_char()
  let code = c.to_int()
  if code >= 0xD800 && code <= 0xDBFF && self.idx + 1 < self.src.length() {
    // A surrogate pair is one code point: two UTF-16 units, four UTF-8 bytes.
    self.idx += 2
    self.cnum += 4
    return Some(c)
  }
  self.idx += 1
  self.cnum += utf8_len_of_char(c)
  if c == '\n' {
    self.lnum += 1
    self.bol = self.cnum
  } else if c == '\r' {
    // Treat \r\n as a single break; a lone \r also ends a line.
    if self.peek() is Some('\n') {
      self.idx += 1
      self.cnum += 1
    }
    self.lnum += 1
    self.bol = self.cnum
  }
  Some(c)
}

///|
/// Consume `s`, which the caller has already confirmed with `looking_at`.
pub fn Cursor::eat(self : Cursor, s : String) -> Unit {
  for _ in 0..<s.length() {
    self.bump() |> ignore
  }
}

///|
/// The source text between two UTF-16 indices.
fn Cursor::slice(self : Cursor, from : Int, to : Int) -> String {
  self.src[from:to].to_owned()
}
