// The registries are data, so what a test can say about them is what upstream's
// own test says: the names, the arities, and which methods reinterpret. Their
// real check is the typer accepting each one, which is task 12's to write.

///|
test "the integer methods are the eight the typer accepts" {
  inspect(
    @members.integer_methods.map(m => m.name).join(" "),
    content="clz ctz popcnt extend8_s extend16_s from_bits rotl rotr",
  )
  // Only the two rotates take a second operand.
  inspect(
    @members.integer_methods.filter(m => m.binary).map(m => m.name).join(" "),
    content="rotl rotr",
  )
  // `from_bits` crosses the int/float divide; nothing else does.
  inspect(
    @members.integer_methods
    .filter(m => m.result is Reinterpret)
    .map(m => m.name)
    .join(" "),
    content="from_bits",
  )
}

///|
test "the float methods are the ten the typer accepts" {
  inspect(
    @members.float_methods.map(m => m.name).join(" "),
    content="abs ceil floor trunc nearest sqrt to_bits min max copysign",
  )
  inspect(
    @members.float_methods.filter(m => m.binary).map(m => m.name).join(" "),
    content="min max copysign",
  )
  inspect(
    @members.float_methods
    .filter(m => m.result is Reinterpret)
    .map(m => m.name)
    .join(" "),
    content="to_bits",
  )
}

///|
test "a receiver has value methods only when it is numeric" {
  // A flexible literal has them by family; a concrete numeric type has them
  // directly. A packed i8/i16 read does NOT -- it must be cast first -- and
  // neither does anything non-numeric.
  let has = [
    @infer.InferredType::Number,
    Int,
    LargeInt,
    Float,
    Valtype(@infer.i32_valtype),
    Valtype(@infer.f64_valtype),
  ]
  for t in has {
    assert_true(@members.numeric_receiver_kind(t) is Some(_))
  }
  let has_not : Array[@infer.InferredType] = [
    Int8,
    Int16,
    Null,
    Unknown,
    Error,
    UnknownRef,
  ]
  for t in has_not {
    assert_true(@members.numeric_receiver_kind(t) is None)
  }
}

///|
test "a SIMD operand type is the resolved value type it stands for" {
  let each : Array[@members.SimdTy] = [TV128, TI32, TI64, TF32, TF64]
  inspect(
    each
    .map(t => @infer.to_string(@infer.valtype_cell(@members.simd_valtype(t))))
    .join(" "),
    content="v128 i32 i64 f32 f64",
  )
}
