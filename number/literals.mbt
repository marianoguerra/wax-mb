// The public surface: a literal's value, its bits, and whether it fits a type.

///|
/// The value of a float literal, as a double.
///
/// Handles what the format spells and `@strconv.parse_double` does not: hex
/// significands, `inf`, `nan`, `nan:0x...`, and an overflowing decimal, which
/// is infinity rather than an error.
pub fn parse_double(s : String) -> Double? {
  let (sign, body) = split_sign(s)
  if body.has_prefix("nan:") {
    return match parse_nan_payload(body) {
      None => None
      Some(payload) => {
        let bits = (if sign < 0 { 1UL << 63 } else { 0UL }) |
          (0x7FFUL << 52) |
          (payload & 0xF_FFFF_FFFF_FFFFUL)
        Some(bits.reinterpret_as_int64().reinterpret_as_double())
      }
    }
  }
  if body == "nan" {
    return Some(if sign < 0 { -nan() } else { nan() })
  }
  if body == "inf" || body == "infinity" {
    return Some(if sign < 0 { @double.neg_infinity } else { @double.infinity })
  }
  if body.has_prefix("0x") || body.has_prefix("0X") {
    return parse_hex_float(s)
  }
  // Decimal. `@strconv` rounds correctly, which is the hard part; it only has
  // to be taught that overflow is infinity rather than a refusal.
  try Some(@string.parse_double(s)) catch {
    _ =>
      // `@strconv` refuses an overflowing decimal where the reference yields
      // infinity, so tell "too big" from "not a number at all" by shape.
      if looks_decimal(body) {
        Some(if sign < 0 { @double.neg_infinity } else { @double.infinity })
      } else {
        None
      }
  } noraise {
    r => r
  }
}

///|
fn nan() -> Double {
  @double.not_a_number
}

///|
/// Split a leading sign from the rest, lowercased for the keyword comparisons.
fn split_sign(s : String) -> (Int, String) {
  if s.has_prefix("-") {
    (-1, s[1:].to_owned().to_lower())
  } else if s.has_prefix("+") {
    (1, s[1:].to_owned().to_lower())
  } else {
    (1, s.to_lower())
  }
}

///|
/// The payload of a `nan:0x...` literal.
fn parse_nan_payload(body : String) -> UInt64? {
  let rest = body[4:].to_owned()
  let hex = if rest.has_prefix("0x") { rest[2:].to_owned() } else { rest }
  let cleaned = hex.replace_all(old="_", new="")
  if cleaned.is_empty() {
    return None
  }
  let mut acc = 0UL
  for c in cleaned {
    match hex_digit(c) {
      None => return None
      Some(v) => acc = (acc << 4) | v.to_uint64()
    }
  }
  Some(acc)
}

///|
/// Does this look like a decimal float, as opposed to something that is not a
/// number at all? Used only to tell an overflow from a syntax error.
fn looks_decimal(body : String) -> Bool {
  let mut seen_digit = false
  for c in body {
    if c >= '0' && c <= '9' {
      seen_digit = true
    } else if c != '.' && c != '_' && c != 'e' && c != '+' && c != '-' {
      return false
    }
  }
  seen_digit
}

///|
/// The exact 32-bit pattern of an f32 literal.
///
/// A `nan:0x...` literal is assembled into bits directly rather than routed
/// through a double: widening single to double sets the quiet bit, so a
/// signalling NaN would not survive the trip. Everything else is correctly
/// rounded to f32 and reinterpreted.
pub fn float32_bits(s : String) -> Int? {
  let (sign, body) = split_sign(s)
  if body.has_prefix("nan:") {
    return match parse_nan_payload(body) {
      None => None
      Some(payload) => {
        let sign_bit = if sign < 0 { 0x8000_0000UL } else { 0UL }
        let bits = sign_bit | 0x7F80_0000UL | (payload & 0x7F_FFFFUL)
        Some(bits.to_uint().reinterpret_as_int())
      }
    }
  }
  match parse_double(s) {
    None => None
    Some(d) => Some(narrow_to_f32(s, d).reinterpret_as_int())
  }
}

///|
/// The exact 64-bit pattern of an f64 literal.
pub fn float64_bits(s : String) -> Int64? {
  parse_double(s).map(d => d.reinterpret_as_int64())
}

///|
/// Round a double to the nearest f32, breaking the double-rounding tie by the
/// literal's own digits.
///
/// Parsing to a double and narrowing rounds twice. A decimal landing exactly on
/// an f32 midpoint would be resolved by ties-to-even against the DOUBLE, which
/// can disagree with the correctly rounded f32 of the true value. When the
/// double is exactly the midpoint between the two bracketing f32 values, the
/// literal's digits decide instead -- which is a single correctly rounded
/// decimal-to-f32 step, spelled in two parts.
fn narrow_to_f32(s : String, d : Double) -> Float {
  if d.is_nan() || d.is_inf() || d == 0.0 {
    return Float::from_double(d)
  }
  let negative = d < 0.0
  let magnitude = d.abs()
  let f = Float::from_double(magnitude)
  let back = f.to_double()
  let result = if magnitude == back {
    // Already exactly an f32.
    f
  } else {
    // The double lies strictly between `f` and its neighbour one ULP toward it.
    let bits = f.reinterpret_as_int()
    let other = if magnitude > back { bits + 1 } else { bits - 1 }
    let neighbour = Float::reinterpret_from_int(other)
    let midpoint = if !f.to_double().is_inf() && !neighbour.to_double().is_inf() {
      (f.to_double() + neighbour.to_double()) * 0.5
    } else {
      // The neighbour is infinity, so the boundary is max-finite plus half an
      // ULP -- the value at and above which round-to-nearest overflows.
      0x1.ffffffp127
    }
    if magnitude != midpoint {
      f
    } else {
      // A genuine tie as far as the double can tell. Compare the literal's
      // exact value against the midpoint: equal means the literal IS the
      // midpoint, so ties-to-even applies and the double already chose right.
      let larger = if f.to_double() > neighbour.to_double() {
        f
      } else {
        neighbour
      }
      let smaller = if f.to_double() < neighbour.to_double() {
        f
      } else {
        neighbour
      }
      match compare_literal_to_double(s, midpoint) {
        None => f
        Some(0) => f
        Some(c) => if c > 0 { larger } else { smaller }
      }
    }
  }
  if negative {
    -result
  } else {
    result
  }
}
