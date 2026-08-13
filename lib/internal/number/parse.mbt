// Numeric literals: from the source spelling to exact bits.
//
// Ported from wax/src/lib-utils/number_parsing.ml.
//
// This is where the Phase 2 decision to keep numeric literals as RAW STRINGS
// all the way through the front end is finally cashed in. A literal has no
// width until something gives it one, so nothing has been rounded yet, and the
// conversion that happens here is the only one -- which is what makes an exact
// bit pattern reachable at all.
//
// `@strconv.parse_double` is not enough on its own. It rejects hex float
// literals, which wasm uses throughout, and it raises on overflow where the
// reference yields infinity. Decimal is delegated to it, because correctly
// rounding a decimal is exactly the hard part and it already does; hex and the
// rest are here.

///|
/// The bits of a hex significand, accumulated left to right.
///
/// Only the top 64 bits can matter to a double, so digits past that are folded
/// into a sticky bit -- they cannot change the value except by ruling out an
/// exact tie. That is the standard technique, and it is what keeps this exact
/// without arbitrary-precision arithmetic.
priv struct Significand {
  mut bits : UInt64
  /// How many binary places the accumulated bits sit above the radix point.
  mut exponent : Int
  /// Whether any non-zero digit was dropped.
  mut sticky : Bool
  mut any_digit : Bool
}

///|
fn Significand::new() -> Significand {
  { bits: 0UL, exponent: 0, sticky: false, any_digit: false }
}

///|
fn Significand::push_hex(self : Significand, v : Int) -> Unit {
  self.any_digit = true
  if self.bits == 0UL && v == 0 {
    // Leading zeros carry no information and must not consume headroom.
    return
  }
  if self.bits <= 0x0FFF_FFFF_FFFF_FFFFUL {
    self.bits = (self.bits << 4) | v.to_uint64()
  } else {
    if v != 0 {
      self.sticky = true
    }
    self.exponent += 4
  }
}

///|
fn hex_digit(c : Char) -> Int? {
  let n = c.to_int()
  if n >= '0'.to_int() && n <= '9'.to_int() {
    Some(n - '0'.to_int())
  } else if n >= 'a'.to_int() && n <= 'f'.to_int() {
    Some(n - 'a'.to_int() + 10)
  } else if n >= 'A'.to_int() && n <= 'F'.to_int() {
    Some(n - 'A'.to_int() + 10)
  } else {
    None
  }
}

///|
/// The value of a hex float literal, correctly rounded to a double.
///
/// A hex literal's significand is exact in binary, so the only rounding is the
/// truncation to 53 bits -- which makes this the easy direction, and the reason
/// hex is how a wasm test suite pins a bit pattern.
fn parse_hex_float(s : String) -> Double? {
  let cs = s.to_array()
  let mut i = 0
  let mut negative = false
  if i < cs.length() && (cs[i] == '+' || cs[i] == '-') {
    negative = cs[i] == '-'
    i += 1
  }
  guard i + 1 < cs.length() &&
    cs[i] == '0' &&
    (cs[i + 1] == 'x' || cs[i + 1] == 'X') else {
    return None
  }
  i += 2
  let sig = Significand::new()
  while i < cs.length() {
    if cs[i] == '_' {
      i += 1
      continue
    }
    match hex_digit(cs[i]) {
      Some(v) => {
        sig.push_hex(v)
        i += 1
      }
      None => break
    }
  }
  if i < cs.length() && cs[i] == '.' {
    i += 1
    while i < cs.length() {
      if cs[i] == '_' {
        i += 1
        continue
      }
      match hex_digit(cs[i]) {
        Some(v) => {
          sig.push_hex(v)
          // A fractional digit lowers the exponent by its four places.
          sig.exponent -= 4
          i += 1
        }
        None => break
      }
    }
  }
  guard sig.any_digit else { return None }
  // The binary exponent, which hex floats spell with `p`.
  let mut exp = 0
  if i < cs.length() && (cs[i] == 'p' || cs[i] == 'P') {
    i += 1
    let mut exp_neg = false
    if i < cs.length() && (cs[i] == '+' || cs[i] == '-') {
      exp_neg = cs[i] == '-'
      i += 1
    }
    let start = i
    while i < cs.length() && cs[i] >= '0' && cs[i] <= '9' {
      // Saturate rather than overflow: an exponent this large is infinity or
      // zero either way, and the sign is all that is still needed.
      if exp < 1_000_000 {
        exp = exp * 10 + (cs[i].to_int() - '0'.to_int())
      }
      i += 1
    }
    guard i > start else { return None }
    if exp_neg {
      exp = -exp
    }
  }
  guard i == cs.length() else { return None }
  let value = scale(sig, exp)
  Some(if negative { -value } else { value })
}

///|
/// Turn an accumulated significand and a binary exponent into a double,
/// rounding to nearest with ties to even.
fn scale(sig : Significand, exp : Int) -> Double {
  if sig.bits == 0UL {
    return if sig.sticky { 0.0 } else { 0.0 }
  }
  let mut bits = sig.bits
  let mut e = sig.exponent + exp
  // Normalize so the significand occupies exactly 54 bits: 53 of value plus one
  // to round on.
  let mut width = 64
  while bits >> (width - 1) == 0UL {
    width -= 1
  }
  let mut sticky = sig.sticky
  if width > 54 {
    let drop = width - 54
    let mask = (1UL << drop) - 1UL
    if (bits & mask) != 0UL {
      sticky = true
    }
    bits = bits >> drop
    e += drop
  } else if width < 54 {
    let add = 54 - width
    bits = bits << add
    e -= add
  }
  // Round the guard bit away, ties to even, with sticky breaking the tie.
  let guard_bit = (bits & 1UL) != 0UL
  bits = bits >> 1
  e += 1
  if guard_bit && (sticky || (bits & 1UL) != 0UL) {
    bits += 1UL
    if bits >= 1UL << 54 {
      bits = bits >> 1
      e += 1
    }
  }
  // `bits` now holds 53 significant bits, worth 2^e each. Assemble the double
  // from those directly rather than by scaling: repeated multiplication would
  // round again on the way into the subnormal range, and rounding twice is the
  // whole thing this module exists to avoid.
  assemble(bits, e)
}

///|
/// A double from an exact `significand * 2^exponent`, with the significand
/// normalized to 53 bits.
fn assemble(significand : UInt64, exponent : Int) -> Double {
  // value = significand * 2^exponent, and significand is in [2^52, 2^53), so
  // the unbiased exponent is `exponent + 52`.
  let e = exponent + 52 + 1023
  if e >= 2047 {
    return @double.infinity
  }
  if e > 0 {
    let bits = (e.to_uint64() << 52) | (significand & 0xF_FFFF_FFFF_FFFFUL)
    return bits.reinterpret_as_int64().reinterpret_as_double()
  }
  // Subnormal: shift right into place, rounding to nearest with ties to even.
  let shift = 1 - e
  if shift > 54 {
    return 0.0
  }
  let dropped_mask = (1UL << shift) - 1UL
  let dropped = significand & dropped_mask
  let mut kept = significand >> shift
  let halfway = 1UL << (shift - 1)
  if dropped > halfway || (dropped == halfway && (kept & 1UL) != 0UL) {
    kept += 1UL
  }
  kept.reinterpret_as_int64().reinterpret_as_double()
}
