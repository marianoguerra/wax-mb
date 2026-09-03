// The per-token scanners: identifiers, numbers, strings, character literals.

///|
/// Scan an identifier or keyword.
///
/// Two stages, matching the reference. The coarse pass accepts ASCII identifier
/// characters plus ANY non-ASCII scalar; the strict pass then re-validates the
/// non-ASCII ones against XID_Start / XID_Continue. Splitting it this way means
/// a confusable or otherwise non-identifier character is reported at its own
/// offset with `Unexpected character`, rather than the whole word being
/// rejected at its start.
fn scan_ident(cur : Cursor, fail : (LexError, Location) -> Unit) -> Token? {
  let start = cur.pos()
  let from = cur.idx
  // A leading `_` needs at least one more character to be an identifier; alone
  // it is the UNDERSCORE token (the `_` hole pattern).
  let leading_underscore = cur.peek() is Some('_')
  if leading_underscore {
    cur.bump() |> ignore
    if !(cur.peek() is Some(c) && is_ident_cont(c)) {
      return Some(UNDERSCORE)
    }
  }
  while cur.peek() is Some(c) && is_ident_cont(c) {
    cur.bump() |> ignore
  }
  let text = cur.slice(from, cur.idx)
  match check_xid(text, start, leading_underscore) {
    Some((bad, loc)) => {
      fail(UnexpectedChar(bad), loc)
      return None
    }
    None => ()
  }
  match keywords.get(text) {
    Some(tok) => Some(tok)
    None => Some(IDENT(text))
  }
}

///|
/// Re-validate the non-ASCII scalars of an identifier against the XID classes.
///
/// Returns the first offending character and its one-character span. ASCII
/// characters accepted by the coarse rule are exactly the intended identifier
/// characters, so only non-ASCII ones need checking -- the first against
/// XID_Start, the rest against XID_Continue.
fn check_xid(
  text : String,
  start : Position,
  leading_underscore : Bool,
) -> (String, Location)? {
  // `_` is XID_Continue but not XID_Start, so a leading underscore means every
  // character is judged as a continuation.
  let mut first = !leading_underscore
  let mut byte = start.cnum
  let mut i = 0
  while i < text.length() {
    let unit = text.unsafe_get(i).to_int()
    let mut code = unit
    let mut units = 1
    if unit >= 0xD800 && unit <= 0xDBFF && i + 1 < text.length() {
      let lo = text.unsafe_get(i + 1).to_int()
      code = 0x10000 + ((unit - 0xD800) << 10) + (lo - 0xDC00)
      units = 2
    }
    let width = if code < 0x80 {
      1
    } else if code < 0x800 {
      2
    } else if code < 0x10000 {
      3
    } else {
      4
    }
    let ok = if code < 0x80 {
      true // already constrained by the coarse rule
    } else if first {
      @xid.is_xid_start(code)
    } else {
      @xid.is_xid_continue(code)
    }
    if !ok {
      let p0 : Position = { ..start, cnum: byte, }
      let p1 : Position = { ..start, cnum: byte + width, }
      return Some((text[i:i + units].to_owned(), { start: p0, end: p1, }))
    }
    first = false
    byte += width
    i += units
  }
  None
}

///|
/// Scan an integer or float literal.
///
/// The text is kept RAW -- `0x1_0` stays the string "0x1_0" and is never
/// converted to a number here. That is what lets the printer reproduce the
/// literal exactly as written, and what the type checker's flexible-literal
/// inference will need later.
///
/// Grammar, from the reference:
///   int      = num | "0x" hexnum
///   decfloat = num ("." num?)? ([eE] sign num) | num "." num?
///   hexfloat = "0x" hexnum ("." hexnum?)? ([pP] sign num) | "0x" hexnum "." hexnum?
///   float    = decfloat | hexfloat | "nan:0x" hexnum
/// where num/hexnum allow `_` between digits.
fn scan_number(cur : Cursor) -> Token? {
  let from = cur.idx

  // `nan:0x…` is a float, and is the reason numbers are tried before keywords.
  if cur.looking_at("nan:0x") {
    cur.eat("nan:0x")
    eat_digits(cur, hex=true)
    return Some(FLOAT(cur.slice(from, cur.idx)))
  }
  let hex = cur.looking_at("0x") || cur.looking_at("0X")
  if hex {
    cur.eat("0x")
    eat_digits(cur, hex=true)
  } else {
    eat_digits(cur, hex=false)
  }
  let mut is_float = false
  // A `.` only continues the number if it is not `..` (the range/splice token)
  // and not a field access on an integer.
  if cur.peek() is Some('.') && !(cur.peek(n=1) is Some('.')) {
    let d = cur.peek(n=1)
    let digit_follows = d is Some(c) &&
      (if hex { is_hex_digit(c) } else { is_digit(c) })
    // `1.` and `1.5` are floats; `x.field` never reaches here, but `1.foo`
    // must not swallow the dot.
    if digit_follows || !(d is Some(c2) && is_ident_start(c2)) {
      cur.bump() |> ignore
      eat_digits(cur, hex~)
      is_float = true
    }
  }
  let exp_chars = if hex { ['p', 'P'] } else { ['e', 'E'] }
  if cur.peek() is Some(c) && (c == exp_chars[0] || c == exp_chars[1]) {
    cur.bump() |> ignore
    if cur.peek() is Some('+') || cur.peek() is Some('-') {
      cur.bump() |> ignore
    }
    eat_digits(cur, hex=false)
    is_float = true
  }
  let text = cur.slice(from, cur.idx)
  if is_float {
    Some(FLOAT(text))
  } else {
    Some(INT(text))
  }
}

///|
/// Consume a digit run, allowing `_` separators between digits.
fn eat_digits(cur : Cursor, hex~ : Bool) -> Unit {
  while cur.peek() is Some(c) {
    if (if hex { is_hex_digit(c) } else { is_digit(c) }) {
      cur.bump() |> ignore
    } else if c == '_' {
      // `_` must sit between digits, never trail; stop if it does not.
      let next = cur.peek(n=1)
      let ok = next is Some(n) &&
        (if hex { is_hex_digit(n) } else { is_digit(n) })
      if ok {
        cur.bump() |> ignore
      } else {
        break
      }
    } else {
      break
    }
  }
}
