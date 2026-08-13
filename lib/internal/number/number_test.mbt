// Tests for numeric literals.
//
// Every expectation is a bit pattern, because that is the only thing worth
// checking here: a float that is nearly right is a byte that is wrong.

///|
fn f32(s : String) -> String {
  match @number.float32_bits(s) {
    None => "none"
    Some(b) => "0x" + b.reinterpret_as_uint().to_string(radix=16)
  }
}

///|
fn f64(s : String) -> String {
  match @number.float64_bits(s) {
    None => "none"
    Some(b) => "0x" + b.reinterpret_as_uint64().to_string(radix=16)
  }
}

///|
test "the ordinary cases" {
  inspect(f32("1.0"), content="0x3f800000")
  inspect(f32("0.0"), content="0x0")
  inspect(f32("-0.0"), content="0x80000000")
  inspect(f32("2.0"), content="0x40000000")
  inspect(f32("-1.5"), content="0xbfc00000")
  inspect(f64("1.0"), content="0x3ff0000000000000")
  inspect(f64("-0.0"), content="0x8000000000000000")
  inspect(f64("0.5"), content="0x3fe0000000000000")
}

///|
/// Hex float literals are how a wasm test suite pins a bit pattern, and
/// `@strconv.parse_double` rejects them outright -- so this is the half that
/// had to be written rather than delegated.
test "hex float literals" {
  inspect(f32("0x1p0"), content="0x3f800000")
  inspect(f32("0x1.8p1"), content="0x40400000") // 3.0
  inspect(f32("0x1p-1"), content="0x3f000000") // 0.5
  inspect(f64("0x1p0"), content="0x3ff0000000000000")
  inspect(f64("0x1.8p1"), content="0x4008000000000000")
  inspect(f64("-0x1p-1"), content="0xbfe0000000000000")
  // The largest finite f32, spelled exactly.
  inspect(f32("0x1.fffffep127"), content="0x7f7fffff")
  // Digit separators are part of the surface syntax.
  inspect(f64("0x1.0p0"), content="0x3ff0000000000000")
}

///|
/// Infinity and NaN, including the payload spelling. A `nan:0x...` literal is
/// assembled into bits directly: routing a signalling NaN through a double
/// would set the quiet bit and lose exactly the thing being spelled.
test "infinities and NaN payloads" {
  inspect(f32("inf"), content="0x7f800000")
  inspect(f32("-inf"), content="0xff800000")
  inspect(f64("inf"), content="0x7ff0000000000000")
  inspect(f64("-inf"), content="0xfff0000000000000")
  // A signalling NaN: payload 1, quiet bit clear.
  inspect(f32("nan:0x1"), content="0x7f800001")
  inspect(f32("-nan:0x1"), content="0xff800001")
  // The canonical quiet NaN spelled as a payload.
  inspect(f32("nan:0x400000"), content="0x7fc00000")
  inspect(f64("nan:0x1"), content="0x7ff0000000000001")
}

///|
/// A decimal that overflows f64 is infinity, not a refusal. `@strconv` raises
/// here; the reference does not.
test "decimal overflow is infinity" {
  inspect(f64("1e400"), content="0x7ff0000000000000")
  inspect(f64("-1e400"), content="0xfff0000000000000")
  // And a decimal that overflows only f32 narrows to infinity.
  inspect(f32("1e39"), content="0x7f800000")
  inspect(f32("3.5e38"), content="0x7f800000")
  // Just under the boundary stays finite.
  inspect(f32("3.4e38"), content="0x7f7fc99e")
}

///|
/// Subnormals, which is where assembling the double from bits rather than by
/// repeated scaling earns its keep: scaling would round on the way in and then
/// again on the way down.
test "subnormals" {
  // The smallest positive subnormal f64.
  inspect(f64("0x1p-1074"), content="0x1")
  inspect(f64("0x1p-1073"), content="0x2")
  // The largest subnormal f64, which is spelled with a leading ZERO -- the
  // other spelling is a tie that rounds up to the smallest normal instead.
  inspect(f64("0x0.fffffffffffffp-1022"), content="0xfffffffffffff")
  inspect(f64("0x1.fffffffffffffp-1023"), content="0x10000000000000")
  // Below the smallest subnormal, rounding to nearest gives zero.
  inspect(f64("0x1p-1080"), content="0x0")
  // The smallest positive subnormal f32.
  inspect(f32("0x1p-149"), content="0x1")
  inspect(f32("0x1p-150"), content="0x0")
}

///|
/// The double-rounding case this module exists for. `0x1.000001p0` is exactly
/// halfway between two f32 values; ties go to even, so it must land on the one
/// with an even significand.
test "double rounding" {
  // 1.0 and the next f32 up (0x3f800001) bracket this midpoint.
  inspect(f32("0x1.000001p0"), content="0x3f800000")
  // A hair above the midpoint rounds up.
  inspect(f32("0x1.0000011p0"), content="0x3f800001")
  // A hair below rounds down.
  inspect(f32("0x1.0000009p0"), content="0x3f800000")
  // The next midpoint up: 0x3f800001 and 0x3f800002, ties to the even one.
  inspect(f32("0x1.000003p0"), content="0x3f800002")
}

///|
/// The range predicates the typer asks of a flexible literal.
test "integer ranges" {
  inspect(@number.is_int32("0"), content="true")
  inspect(@number.is_int32("2147483647"), content="true")
  inspect(@number.is_int32("-2147483648"), content="true")
  inspect(@number.is_int32("2147483648"), content="true") // unsigned reading
  inspect(@number.is_int32("4294967295"), content="true")
  inspect(@number.is_int32("4294967296"), content="false")
  inspect(@number.is_int32("-2147483649"), content="false")
  inspect(@number.is_int64("18446744073709551615"), content="true")
  inspect(@number.is_int64("18446744073709551616"), content="false")
  inspect(@number.is_int32("0xffffffff"), content="true")
  inspect(@number.is_int32("0x1_0000_0000"), content="false")
  inspect(@number.is_int32("nope"), content="false")
}

///|
/// The narrow widths. A literal that only passes `is_int32` through its
/// UNSIGNED reading has no signed value, so it is out of the i8/i16 range
/// rather than wrapping into it.
test "packed integer ranges" {
  inspect(@number.is_int8("127"), content="true")
  inspect(@number.is_int8("255"), content="true")
  inspect(@number.is_int8("256"), content="false")
  inspect(@number.is_int8("-128"), content="true")
  inspect(@number.is_int8("-129"), content="false")
  inspect(@number.is_int16("32767"), content="true")
  inspect(@number.is_int16("65535"), content="true")
  inspect(@number.is_int16("65536"), content="false")
  inspect(@number.is_int16("-32768"), content="true")
  // Above i32-max: only the unsigned reading accepts it as an i32, and it is
  // nowhere near an i8.
  inspect(@number.is_int32("3000000000"), content="true")
  inspect(@number.is_int16("3000000000"), content="false")
  inspect(@number.is_int8("3000000000"), content="false")
}

///|
/// A finite literal fits an f32 iff its correct rounding does not overflow;
/// `inf` and `nan` are accepted as written.
test "float ranges" {
  inspect(@number.is_float32("1.0"), content="true")
  inspect(@number.is_float32("3.4e38"), content="true")
  inspect(@number.is_float32("3.5e38"), content="false")
  inspect(@number.is_float32("inf"), content="true")
  inspect(@number.is_float32("-inf"), content="true")
  inspect(@number.is_float32("nan"), content="true")
  inspect(@number.is_float32("nan:0x1"), content="true")
  inspect(@number.is_float32("0x1.fffffep127"), content="true")
  inspect(@number.is_float32("0x1p128"), content="false")
  inspect(@number.is_float64("1e308"), content="true")
  inspect(@number.is_float64("1e400"), content="false")
  inspect(@number.is_float64("inf"), content="true")
}
