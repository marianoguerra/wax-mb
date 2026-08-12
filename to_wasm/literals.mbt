// Reading a literal's value out of its source spelling.
//
// Ported from the constant-folding of wax/src/lib-conversion/to_wasm.ml.
//
// The literals reach here as the TEXT the author wrote, which is deliberate: a
// float's exact bit pattern survives only in its spelling, and re-deriving it
// from a parsed double would lose a NaN payload that the module may depend on.
// So the conversion happens once, here, at the point the bytes are chosen.

///|
/// A wax integer literal as an `Int64`, underscores ignored.
///
/// Read UNSIGNED on a signed-parse failure, because a hex literal past 2^63 is
/// written as a bit pattern rather than a negative number, and that pattern is
/// what the encoder emits.
pub fn parse_i64(s : String, loc : @basic.Location) -> Int64 raise LowerError {
  let cleaned = s.split("_").join("")
  @string.parse_int64(cleaned) catch {
    _ =>
      @string.parse_uint64(cleaned).reinterpret_as_int64() catch {
        _ => raise Unresolved("integer literal", loc)
      }
  }
}

///|
/// The same, truncated to the 32 bits an `i32.const` carries.
pub fn parse_i32(s : String, loc : @basic.Location) -> Int raise LowerError {
  parse_i64(s, loc).to_int()
}

///|
/// A wax float literal as a double.
pub fn parse_f64(s : String, loc : @basic.Location) -> Double raise LowerError {
  let cleaned = s.split("_").join("")
  @string.parse_double(cleaned) catch {
    _ =>
      // An integer literal in a float position, and the `nan:0x..` payload form,
      // both reach here; the first parses as an integer, the second does not
      // survive a double at all and is not lowered yet.
      @string.parse_int64(cleaned).to_double() catch {
        _ => raise NotLowered("float literal spelling", loc)
      }
  }
}

///|
/// A readable name for an instruction, for the "not lowered" report.
pub fn construct_name(
  d : @ast.InstrDesc[@typing_env.InferredAnnotation],
) -> String {
  match d {
    Block(..) | Loop(..) => "block"
    While(..) => "while"
    If(..) => "if"
    TryTable(..) => "try_table"
    Try(..) | TryCatch(..) => "try"
    Dispatch(..) => "dispatch"
    Match(..) => "match"
    Hole => "hole"
    Null => "null"
    Path(_, _) => "qualified name"
    Call(_, _) => "call"
    TailCall(_, _) => "tail call"
    Labelled(_, _) => "labelled argument"
    Str(_, _) => "string literal"
    Cast(_, _) | CastDesc(_, _, _) => "cast"
    Test(_, _) => "type test"
    NonNull(_) => "non-null assertion"
    Struct(_, _) | StructDefault(_) | StructDesc(_, _) | StructDefaultDesc(_) =>
      "struct construction"
    StructGet(_, _) | StructSet(_, _, _) | GetDescriptor(_) => "field access"
    Array(_, _, _)
    | ArrayDefault(_, _)
    | ArrayFixed(_, _)
    | ArraySegment(_, _, _, _) => "array construction"
    ArrayGet(_, _) | ArraySet(_, _, _) => "array access"
    BrTable(_, _) => "br_table"
    BrOnNull(_, _) | BrOnNonNull(_, _) => "br_on_null"
    BrOnCast(_, _, _) | BrOnCastFail(_, _, _) => "br_on_cast"
    BrOnCastDescEq(_, _, _, _) | BrOnCastDescEqFail(_, _, _, _) =>
      "br_on_cast_desc"
    Throw(_, _) | ThrowRef(_) => "throw"
    ContNew(_, _)
    | ContBind(_, _, _)
    | Suspend(_, _)
    | Resume(_, _, _)
    | ResumeThrow(_, _, _, _)
    | ResumeThrowRef(_, _, _)
    | Switch(_, _, _)
    | On(_, _) => "stack switching"
    Select(_, _, _) => "select"
    IfAnnotation(..) => "conditional annotation"
    _ => "instruction"
  }
}

///|
/// A wax float literal as the exact bits it names.
///
/// Three spellings, and only the first is ordinary. A HEX float
/// (`0x1.ce45573fd156bp-252`) names a mantissa and a binary exponent directly,
/// which is how a decompiler writes a double without losing a bit. A `nan:0x..`
/// names a NaN PAYLOAD, which no decimal spelling can carry -- two NaNs with
/// different payloads are different values to a program that inspects them, and
/// re-deriving one through a parsed double would silently pick the canonical
/// payload instead.
///
/// So the bits are assembled here rather than parsed: for these two forms there
/// is nothing to parse them INTO that would keep them.
pub fn parse_float_bits(
  s : String,
  wide : Bool,
  loc : @basic.Location,
) -> Double raise LowerError {
  let cleaned = s.split("_").join("")
  let (negative, body) = if cleaned.has_prefix("-") {
    (true, cleaned[1:].to_owned())
  } else if cleaned.has_prefix("+") {
    (false, cleaned[1:].to_owned())
  } else {
    (false, cleaned)
  }
  if body.has_prefix("nan") {
    return nan_of(body, negative, wide, loc)
  }
  if body.has_prefix("0x") || body.has_prefix("0X") {
    return hex_float(body, negative, loc)
  }
  let v = @string.parse_double(body) catch {
    _ =>
      @string.parse_int64(body).to_double() catch {
        _ => raise NotLowered("float literal spelling", loc)
      }
  }
  if negative {
    -v
  } else {
    v
  }
}

///|
/// A NaN, with the payload the source named.
///
/// `nan` alone is the canonical one; `nan:0x..` names the mantissa bits. The
/// width matters: an f32 payload occupies 23 bits and an f64's 52, and a value
/// destined for an f32 is built at that width so the demotion does not discard
/// what the source went to the trouble of writing.
fn nan_of(
  body : String,
  negative : Bool,
  wide : Bool,
  loc : @basic.Location,
) -> Double raise LowerError {
  let payload = if body == "nan" {
    // The canonical quiet NaN: the top mantissa bit and nothing else.
    if wide {
      0x8000000000000UL
    } else {
      0x400000UL
    }
  } else if body.has_prefix("nan:0x") {
    let hex = body[6:].to_owned()
    @string.parse_uint64("0x" + hex) catch {
      _ => raise NotLowered("nan payload", loc)
    }
  } else {
    raise NotLowered("float literal spelling", loc)
  }
  if wide {
    let bits = (if negative {
        0xFFF0000000000000UL
      } else {
        0x7FF0000000000000UL
      }) |
      payload
    bits.reinterpret_as_int64().reinterpret_as_double()
  } else {
    let bits32 = (if negative { 0xFF800000U } else { 0x7F800000U }) |
      payload.to_uint()
    Float::reinterpret_from_int(bits32.reinterpret_as_int()).to_double()
  }
}

///|
/// A hex float: `0x<hex>.<hex>p<±dec>`.
///
/// Assembled by scaling rather than parsed, because there is no decimal
/// spelling of these bits to go through. Each hex digit after the point is
/// worth a sixteenth of the one before it, and `p` is a power of TWO.
fn hex_float(
  body : String,
  negative : Bool,
  loc : @basic.Location,
) -> Double raise LowerError {
  let rest = body[2:].to_owned()
  let (mantissa_part, exponent) = match rest.split("p").collect() {
    [m] => (m.to_owned(), 0)
    [m, e] =>
      (
        m.to_owned(),
        @string.parse_int(e.to_owned()) catch {
          _ => raise NotLowered("hex float exponent", loc)
        },
      )
    _ => raise NotLowered("hex float spelling", loc)
  }
  let (whole, frac) = match mantissa_part.split(".").collect() {
    [w] => (w.to_owned(), "")
    [w, f] => (w.to_owned(), f.to_owned())
    _ => raise NotLowered("hex float spelling", loc)
  }
  let mut v = 0.0
  for k in 0..<whole.length() {
    v = v * 16.0 + hex_digit(whole[k], loc).to_double()
  }
  let mut scale = 1.0 / 16.0
  for k in 0..<frac.length() {
    v = v + hex_digit(frac[k], loc).to_double() * scale
    scale = scale / 16.0
  }
  // `p` is a binary exponent, applied by repeated doubling or halving so the
  // result is exact wherever the value is.
  let mut e = exponent
  while e > 0 {
    v = v * 2.0
    e = e - 1
  }
  while e < 0 {
    v = v / 2.0
    e = e + 1
  }
  if negative {
    -v
  } else {
    v
  }
}

///|
fn hex_digit(c : UInt16, loc : @basic.Location) -> Int raise LowerError {
  let n = c.to_int()
  if n >= 48 && n <= 57 {
    n - 48
  } else if n >= 97 && n <= 102 {
    n - 87
  } else if n >= 65 && n <= 70 {
    n - 55
  } else {
    raise NotLowered("hex float digit", loc)
  }
}
