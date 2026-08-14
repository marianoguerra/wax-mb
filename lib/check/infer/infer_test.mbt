// The substrate everything else in the checker will rest on, so it is tested
// harder than its size suggests: a union-find that loses an update, or a
// literal family that renders as its default width, would show up as a wrong
// type in a message thousands of lines away.

///|
test "a cell carries its value" {
  let c = @infer.Cell::make(@infer.InferredType::Number)
  inspect(c.get() is Number, content="true")
  c.set(Int)
  inspect(c.get() is Int, content="true")
}

///|
test "merging makes two cells one" {
  // The point of the union-find: narrowing one narrows the other, for good.
  let a = @infer.Cell::make(@infer.InferredType::Number)
  let b = @infer.Cell::make(@infer.InferredType::Number)
  a.merge(b, Int)
  inspect(a.get() is Int, content="true")
  inspect(b.get() is Int, content="true")
  // And a later narrowing through EITHER handle is seen through both.
  b.set(@infer.i32_valtype |> Valtype)
  inspect(@infer.to_string(a), content="i32")
  inspect(@infer.to_string(b), content="i32")
}

///|
test "merging a cell with itself just sets it" {
  // The two roots coincide; the reference guards this case explicitly, because
  // linking a root to itself would build a cycle that `representative` would
  // never leave.
  let a = @infer.Cell::make(@infer.InferredType::Number)
  a.merge(a, Int)
  inspect(a.get() is Int, content="true")
}

///|
test "merging chains stays consistent" {
  // Three classes joined in sequence: every handle must see the last value,
  // whichever path through the links it takes.
  let a = @infer.Cell::make(@infer.InferredType::Number)
  let b = @infer.Cell::make(@infer.InferredType::Number)
  let c = @infer.Cell::make(@infer.InferredType::Number)
  a.merge(b, Int)
  b.merge(c, LargeInt)
  c.set(Float)
  inspect(
    "\{@infer.to_string(a)} \{@infer.to_string(b)} \{@infer.to_string(c)}",
    content="float float float",
  )
}

///|
test "the flexible literals render by family, not by their default" {
  // A diagnostic has to say `number`, not `i32`: the whole point is that the
  // width is not decided yet. `large number` is deliberately in the number
  // family rather than the int one -- it is float-capable.
  let each = [
    @infer.InferredType::Number,
    Int,
    LargeInt,
    Float,
    Int8,
    Int16,
    Null,
    UnknownRef,
    Unknown,
    Error,
  ]
  inspect(
    each.map(t => @infer.to_string(@infer.Cell::make(t))).join(" "),
    content="number int large number float i8 i16 null &_ any any",
  )
}

///|
test "a block result under inference renders as the annotation being tested" {
  // Not as `any`: the reader that failed was checked against the declared type,
  // so that is the type the message has to name.
  let declared = @infer.Cell::make(
    @infer.InferredType::Valtype(@infer.i64_valtype),
  )
  let collecting = @infer.Cell::make(
    @infer.InferredType::Collecting({
      collected: [],
      exacts: [],
      declared: Some(declared),
      needed: false,
      empty_exits: [],
    }),
  )
  inspect(@infer.to_string(collecting), content="i64")
  // With no annotation there is nothing to name yet.
  let bare = @infer.Cell::make(
    @infer.InferredType::Collecting({
      collected: [],
      exacts: [],
      declared: None,
      needed: false,
      empty_exits: [],
    }),
  )
  inspect(@infer.to_string(bare), content="any")
}

///|
test "the unknown family is one question with three answers" {
  // They differ in what they license -- Unknown still earns an error, Error
  // stays silent, UnknownRef is known to be a reference -- but every site that
  // only asks "is anything known" shares this.
  for t in [@infer.InferredType::Unknown, Error, UnknownRef] {
    assert_true(@infer.is_unknown_or_error(@infer.Cell::make(t)))
  }
  for t in [@infer.InferredType::Number, Null, Valtype(@infer.i32_valtype)] {
    assert_false(@infer.is_unknown_or_error(@infer.Cell::make(t)))
  }
}

///|
test "the shared base cells are the resolved numeric types" {
  inspect(
    [@infer.i32_cell, @infer.i64_cell, @infer.f32_cell, @infer.f64_cell]
    .map(@infer.to_string)
    .join(" "),
    content="i32 i64 f32 f64",
  )
}
