// String and character literals.

///|
/// Scan a `"..."` string literal.
///
/// The token carries the DECODED text plus its span. Escapes are resolved here
/// rather than left raw, because the value is what a data segment or an export
/// name means; the printer re-escapes on the way out.
///
/// `\xNN` denotes a raw BYTE, which is why the decoded value is a byte string
/// in the reference. MoonBit strings are UTF-16, so a byte escape above 0x7F
/// cannot be represented as a character here -- see the note in `push_byte`.
fn scan_string(cur : Cursor, fail : (LexError, Location) -> Unit) -> Token? {
  let start = cur.pos()
  cur.eat("\"")
  let buf = StringBuilder::new()
  while true {
    let c = match cur.peek() {
      Some(c) => c
      None => {
        // End of input inside a string.
        fail(MalformedString, cur.span(start))
        return None
      }
    }
    if c == '"' {
      cur.bump() |> ignore
      let loc = cur.span(start)
      return Some(STRING({ desc: buf.to_string(), info: loc }))
    }
    if c == '\\' {
      if !scan_escape(cur, buf, fail) {
        return None
      }
      continue
    }
    // Raw control characters are not allowed in a string literal; they must be
    // written as escapes.
    let code = c.to_int()
    if code <= 31 || code == 0x7F {
      let from = cur.pos()
      cur.bump() |> ignore
      fail(MalformedString, cur.span(from))
      return None
    }
    buf.write_char(c)
    cur.bump() |> ignore
  }
  None
}

///|
/// Consume one backslash escape, appending its value to `buf`.
fn scan_escape(
  cur : Cursor,
  buf : StringBuilder,
  fail : (LexError, Location) -> Unit,
) -> Bool {
  let start = cur.pos()
  cur.eat("\\")
  match cur.peek() {
    Some('t') => {
      cur.bump() |> ignore
      buf.write_char('\t')
    }
    Some('n') => {
      cur.bump() |> ignore
      buf.write_char('\n')
    }
    Some('r') => {
      cur.bump() |> ignore
      buf.write_char('\r')
    }
    Some('\'') => {
      cur.bump() |> ignore
      buf.write_char('\'')
    }
    Some('"') => {
      cur.bump() |> ignore
      buf.write_char('"')
    }
    Some('\\') => {
      cur.bump() |> ignore
      buf.write_char('\\')
    }
    Some('x') => {
      cur.bump() |> ignore
      let d0 = cur.peek()
      let d1 = cur.peek(n=1)
      if d0 is Some(a) && d1 is Some(b) && is_hex_digit(a) && is_hex_digit(b) {
        cur.bump() |> ignore
        cur.bump() |> ignore
        buf.write_char((hex_val(a) * 16 + hex_val(b)).unsafe_to_char())
      } else {
        fail(MalformedString, cur.span(start))
        return false
      }
    }
    Some('u') =>
      if cur.looking_at("u{") {
        cur.eat("u{")
        let from = cur.idx
        while cur.peek() is Some(c) && (is_hex_digit(c) || c == '_') {
          cur.bump() |> ignore
        }
        let digits = cur.slice(from, cur.idx)
        if !(cur.peek() is Some('}')) {
          fail(MalformedString, cur.span(start))
          return false
        }
        cur.bump() |> ignore
        match scalar_of_hex(digits) {
          Some(u) => buf.write_char(u)
          None => {
            fail(MalformedUnicodeEscape, cur.span(start))
            return false
          }
        }
      } else {
        fail(MalformedString, cur.span(start))
        return false
      }
    _ => {
      fail(MalformedString, cur.span(start))
      return false
    }
  }
  true
}

///|
fn hex_val(c : Char) -> Int {
  if c >= '0' && c <= '9' {
    c.to_int() - '0'.to_int()
  } else if c >= 'a' && c <= 'f' {
    c.to_int() - 'a'.to_int() + 10
  } else {
    c.to_int() - 'A'.to_int() + 10
  }
}

///|
/// Parse hex digits as a Unicode SCALAR value.
///
/// Rejects anything above U+10FFFF and the surrogate range U+D800-U+DFFF:
/// surrogates are code points but not scalar values, so they cannot appear in
/// well-formed text and the reference's `scalar_of_hex` refuses them too.
fn scalar_of_hex(digits : String) -> Char? {
  if digits.length() == 0 {
    return None
  }
  let mut n = 0
  for c in digits {
    if c == '_' {
      continue
    }
    n = n * 16 + hex_val(c)
    if n > 0x10FFFF {
      return None
    }
  }
  if n >= 0xD800 && n <= 0xDFFF {
    return None
  }
  Some(n.unsafe_to_char())
}

///|
/// Scan a `'x'` character literal.
///
/// Returns None WITHOUT recording an error when the input is not a character
/// literal at all, so the caller can fall back to the bare QUOTE token that
/// introduces a label (`'loop:`). It returns None *with* an error only once it
/// is committed to a character literal that turns out to be malformed.
fn scan_char(cur : Cursor, fail : (LexError, Location) -> Unit) -> Token? {
  let start = cur.pos()
  let save_idx = cur.idx
  let save_cnum = cur.cnum
  let save_bol = cur.bol
  let save_lnum = cur.lnum

  fn rewind() -> Unit {
    cur.idx = save_idx
    cur.cnum = save_cnum
    cur.bol = save_bol
    cur.lnum = save_lnum
  }

  cur.eat("'")
  match cur.peek() {
    // `'\u{...}'`
    Some('\\') =>
      if cur.looking_at("\\u{") {
        cur.eat("\\u{")
        let from = cur.idx
        while cur.peek() is Some(c) && (is_hex_digit(c) || c == '_') {
          cur.bump() |> ignore
        }
        let digits = cur.slice(from, cur.idx)
        if !cur.looking_at("}'") {
          rewind()
          return None
        }
        cur.eat("}'")
        match scalar_of_hex(digits) {
          Some(u) => return Some(CHAR(u))
          None => {
            fail(MalformedUnicodeEscape, cur.span(start))
            return None
          }
        }
      } else if cur.looking_at("\\x") {
        cur.eat("\\x")
        let a = cur.peek()
        let b = cur.peek(n=1)
        if a is Some(x) && b is Some(y) && is_hex_digit(x) && is_hex_digit(y) {
          cur.bump() |> ignore
          cur.bump() |> ignore
          if !(cur.peek() is Some('\'')) {
            rewind()
            return None
          }
          cur.bump() |> ignore
          let n = hex_val(x) * 16 + hex_val(y)
          // A byte escape in a CHARACTER literal denotes a code point, so it is
          // capped at ASCII: 0x80-0xFF would be an incomplete UTF-8 sequence,
          // not a character. (In a STRING the same escape is a raw byte and is
          // legal.)
          if n > 127 {
            fail(InvalidUnicodeChar, cur.span(start))
            return None
          }
          return Some(CHAR(n.unsafe_to_char()))
        }
        rewind()
        return None
      } else {
        // Simple escapes: '\t' '\n' '\r' '\'' '\"' '\\'
        cur.bump() |> ignore
        let e = cur.peek()
        let v = match e {
          Some('t') => Some('\t')
          Some('n') => Some('\n')
          Some('r') => Some('\r')
          Some('\'') => Some('\'')
          Some('"') => Some('"')
          Some('\\') => Some('\\')
          _ => None
        }
        match v {
          Some(ch) => {
            cur.bump() |> ignore
            if !(cur.peek() is Some('\'')) {
              rewind()
              return None
            }
            cur.bump() |> ignore
            return Some(CHAR(ch))
          }
          None => {
            rewind()
            return None
          }
        }
      }
    // `'x'` -- one code point, possibly multibyte.
    Some(c) => {
      let code = c.to_int()
      if code <= 31 || code == 0x7F || c == '"' || c == '\\' {
        rewind()
        return None
      }
      let from = cur.idx
      cur.bump() |> ignore
      let text = cur.slice(from, cur.idx)
      if !(cur.peek() is Some('\'')) {
        rewind()
        return None
      }
      cur.bump() |> ignore
      // Re-decode so a surrogate pair becomes one code point.
      let mut scalar = text.unsafe_get(0).to_int()
      if text.length() == 2 {
        let lo = text.unsafe_get(1).to_int()
        scalar = 0x10000 + ((scalar - 0xD800) << 10) + (lo - 0xDC00)
      }
      return Some(CHAR(scalar.unsafe_to_char()))
    }
    None => {
      rewind()
      return None
    }
  }
}
