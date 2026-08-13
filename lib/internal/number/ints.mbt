// Integer literals, and the range predicates the type checker asks.
//
// Ported from the first half of wax/src/lib-wasm/misc.ml. The typer uses these
// to decide whether a flexible numeric literal can take a given width -- which
// is the question the whole raw-string representation exists to keep open.

///|
/// The value of an integer literal as a 64-bit two's-complement pattern.
///
/// Signed and unsigned spellings both land here: `-1` and `18446744073709551615`
/// are the same 64 bits, and the format accepts either for an i64. The
/// reference expresses this as "parse as signed, and if that fails, parse again
/// with a `0u` prefix"; this parses once and range-checks against both.
pub fn parse_int64(s : String) -> Int64? {
  parse_integer(s, 64).map(v => v.reinterpret_as_int64())
}

///|
/// As `parse_int64`, for 32 bits.
pub fn parse_int32(s : String) -> Int? {
  parse_integer(s, 32).map(v => v.to_int())
}

///|
/// The magnitude and sign of an integer literal, or `None` if it does not fit
/// `width` bits under either the signed or the unsigned reading.
fn parse_integer(s : String, width : Int) -> UInt64? {
  let (sign, body) = split_sign(s)
  let (digits, radix) = if body.has_prefix("0x") {
    (body[2:].to_owned(), 16)
  } else {
    (body, 10)
  }
  let cleaned = digits.replace_all(old="_", new="")
  if cleaned.is_empty() {
    return None
  }
  let mut acc = 0UL
  let limit = if width == 64 { 0xFFFF_FFFF_FFFF_FFFFUL } else { 0xFFFF_FFFFUL }
  for c in cleaned {
    let d = if radix == 16 {
      match hex_digit(c) {
        None => return None
        Some(v) => v
      }
    } else if c >= '0' && c <= '9' {
      c.to_int() - '0'.to_int()
    } else {
      return None
    }
    // Overflow past the width is out of range under either reading.
    if acc > (limit - d.to_uint64()) / radix.to_uint64() {
      return None
    }
    acc = acc * radix.to_uint64() + d.to_uint64()
  }
  if sign < 0 {
    // A negative literal has to fit the SIGNED range; its two's complement is
    // what the width actually stores.
    let signed_min = if width == 64 {
      0x8000_0000_0000_0000UL
    } else {
      0x8000_0000UL
    }
    if acc > signed_min {
      return None
    }
    Some((limit - acc + 1UL) & limit)
  } else {
    Some(acc)
  }
}

///|
pub fn is_int64(s : String) -> Bool {
  parse_integer(s, 64) is Some(_)
}

///|
pub fn is_int32(s : String) -> Bool {
  parse_integer(s, 32) is Some(_)
}

///|
/// Does the literal fit an i16 field?
///
/// The reference's comment is the thing to keep: a valid i8/i16 value fits a
/// SIGNED 32-bit integer, so a literal that only passes `is_int32` through its
/// unsigned reading -- one above i32-max -- is correctly out of range here
/// rather than crashing the narrower parse.
pub fn is_int16(s : String) -> Bool {
  match signed_int32(s) {
    None => false
    Some(v) => v >= -32768 && v < 65536
  }
}

///|
pub fn is_int8(s : String) -> Bool {
  match signed_int32(s) {
    None => false
    Some(v) => v >= -128 && v < 256
  }
}

///|
/// The literal as a signed 32-bit value, or `None` if it does not fit one.
fn signed_int32(s : String) -> Int? {
  guard is_int32(s) else { return None }
  guard parse_integer(s, 32) is Some(bits) else { return None }
  let v = bits.to_int()
  // A literal above i32-max reached us only through the unsigned reading, and
  // has no signed value.
  if s.has_prefix("-") || bits <= 0x7FFF_FFFFUL {
    Some(v)
  } else {
    None
  }
}

///|
/// Does the literal denote a value an f32 can hold?
///
/// `inf` and `nan` are accepted as written. A finite literal is valid iff its
/// correct rounding does not overflow to infinity -- which is why this needs
/// the rounding to be correct, not merely close.
pub fn is_float32(s : String) -> Bool {
  match float32_bits(s) {
    None => false
    Some(bits) => (bits & 0x7FFF_FFFF) != 0x7F80_0000 || spells_infinity(s)
  }
}

///|
/// As `is_float32`, for f64.
pub fn is_float64(s : String) -> Bool {
  match parse_double(s) {
    None => false
    Some(d) => !d.is_inf() || spells_infinity(s)
  }
}

///|
/// Did the literal say `inf` or `nan` outright, rather than overflowing to it?
fn spells_infinity(s : String) -> Bool {
  let (_, body) = split_sign(s)
  body == "inf" ||
  body == "infinity" ||
  body == "nan" ||
  body.has_prefix("nan:")
}
