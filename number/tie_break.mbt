// Breaking a double-rounding tie.
//
// The question is narrow: the literal's true value sits exactly at the midpoint
// between two f32 values as far as a double can tell, so which side is it
// really on? Only the literal's own digits know.
//
// The reference answers it by rendering the midpoint with `%.*g` at the
// literal's own precision and comparing digit strings. MoonBit has no `%g`, and
// the digit-string comparison is an approximation of the thing actually being
// asked -- so this compares the two values EXACTLY instead, as rationals with
// power-of-two and power-of-ten denominators cleared by cross-multiplication.
// Exact is both easier to be sure of and easier to explain than a rendering
// that happens to have enough digits.

///|
/// A literal's exact value, as `mantissa * base^exponent`.
priv struct Exact {
  mantissa : BigInt
  /// Base 2 for a hex literal, base 10 for a decimal one.
  base : Int
  exponent : Int
}

///|
/// Collect a literal's exact value. `None` when it is not a finite numeral.
fn exact_of_literal(s : String) -> Exact? {
  let (_, body) = split_sign(s)
  if body.has_prefix("0x") {
    exact_hex(body[2:].to_owned())
  } else {
    exact_decimal(body)
  }
}

///|
fn exact_hex(body : String) -> Exact? {
  let mut mantissa = 0N
  let mut frac_digits = 0
  let mut seen = false
  let mut after_point = false
  let mut i = 0
  let cs = body.to_array()
  while i < cs.length() {
    let c = cs[i]
    if c == '_' {
      i += 1
      continue
    }
    if c == '.' && !after_point {
      after_point = true
      i += 1
      continue
    }
    if c == 'p' || c == 'P' {
      break
    }
    match hex_digit(c) {
      None => return None
      Some(v) => {
        seen = true
        mantissa = mantissa * 16N + BigInt::from_int(v)
        if after_point {
          frac_digits += 1
        }
      }
    }
    i += 1
  }
  guard seen else { return None }
  let mut exp = 0
  if i < cs.length() && (cs[i] == 'p' || cs[i] == 'P') {
    i += 1
    let mut neg = false
    if i < cs.length() && (cs[i] == '+' || cs[i] == '-') {
      neg = cs[i] == '-'
      i += 1
    }
    while i < cs.length() && cs[i] >= '0' && cs[i] <= '9' {
      exp = exp * 10 + (cs[i].to_int() - '0'.to_int())
      i += 1
    }
    if neg {
      exp = -exp
    }
  }
  // Each fractional hex digit is four binary places.
  Some({ mantissa, base: 2, exponent: exp - frac_digits * 4 })
}

///|
fn exact_decimal(body : String) -> Exact? {
  let mut mantissa = 0N
  let mut frac_digits = 0
  let mut seen = false
  let mut after_point = false
  let mut i = 0
  let cs = body.to_array()
  while i < cs.length() {
    let c = cs[i]
    if c == '_' {
      i += 1
      continue
    }
    if c == '.' && !after_point {
      after_point = true
      i += 1
      continue
    }
    if c == 'e' {
      break
    }
    if c < '0' || c > '9' {
      return None
    }
    seen = true
    mantissa = mantissa * 10N + BigInt::from_int(c.to_int() - '0'.to_int())
    if after_point {
      frac_digits += 1
    }
    i += 1
  }
  guard seen else { return None }
  let mut exp = 0
  if i < cs.length() && cs[i] == 'e' {
    i += 1
    let mut neg = false
    if i < cs.length() && (cs[i] == '+' || cs[i] == '-') {
      neg = cs[i] == '-'
      i += 1
    }
    while i < cs.length() && cs[i] >= '0' && cs[i] <= '9' {
      exp = exp * 10 + (cs[i].to_int() - '0'.to_int())
      i += 1
    }
    if neg {
      exp = -exp
    }
  }
  Some({ mantissa, base: 10, exponent: exp - frac_digits })
}

///|
/// A finite double as `mantissa * 2^exponent`, exactly.
fn exact_of_double(d : Double) -> (BigInt, Int) {
  let bits = d.abs().reinterpret_as_int64()
  let raw_exp = ((bits >> 52) & 0x7FF).to_int()
  let raw_frac = bits & 0xF_FFFF_FFFF_FFFF
  if raw_exp == 0 {
    // Subnormal: no implicit leading one.
    (BigInt::from_int64(raw_frac), -1074)
  } else {
    (BigInt::from_int64(raw_frac | 0x10_0000_0000_0000), raw_exp - 1075)
  }
}

///|
fn pow_big(base : Int, e : Int) -> BigInt {
  let mut r = 1N
  let b = BigInt::from_int(base)
  for _ in 0..<e {
    r = r * b
  }
  r
}

///|
/// Compare the literal's exact magnitude against a double's, returning a
/// negative number, zero, or a positive number as the literal is below, at, or
/// above it.
///
/// Both sides are `m * b^e`; cross-multiplying by the positive powers clears
/// every denominator and leaves two integers to compare.
fn compare_literal_to_double(s : String, d : Double) -> Int? {
  guard exact_of_literal(s) is Some(lit) else { return None }
  let (dm, de) = exact_of_double(d)
  // Left is lit.mantissa * base^exponent; right is dm * 2^de.
  let mut left = lit.mantissa
  let mut right = dm
  if lit.exponent >= 0 {
    left = left * pow_big(lit.base, lit.exponent)
  } else {
    right = right * pow_big(lit.base, -lit.exponent)
  }
  if de >= 0 {
    right = right * pow_big(2, de)
  } else {
    left = left * pow_big(2, -de)
  }
  Some(if left < right { -1 } else if left > right { 1 } else { 0 })
}
