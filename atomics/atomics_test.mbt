// Tests for the atomic instruction tables.
//
// Four tables have to agree -- mnemonic, sub-opcode, alignment, signature --
// which is why the module generates them from one layout rather than writing
// them out. So what is worth testing is that the layout is right at its
// boundaries, and that the round trips close.

///|
test "the sub-opcodes match the specification's layout" {
  // The three that stand alone.
  inspect(@atomics.opcode(Notify), content="0")
  inspect(@atomics.opcode(Wait(I32)), content="1")
  inspect(@atomics.opcode(Wait(I64)), content="2")
  // Loads run 0x10..0x16 in the variant order: the two full-width accesses
  // first, then the narrow ones.
  inspect(@atomics.opcode(Load(I32, None)), content="16")
  inspect(@atomics.opcode(Load(I64, None)), content="17")
  inspect(@atomics.opcode(Load(I32, Some(N8))), content="18")
  inspect(@atomics.opcode(Load(I64, Some(N32))), content="22")
  // Stores follow immediately, 0x17..0x1D.
  inspect(@atomics.opcode(Store(I32, None)), content="23")
  inspect(@atomics.opcode(Store(I64, Some(N32))), content="29")
  // Then seven RMW blocks of seven, from 0x1E.
  inspect(@atomics.opcode(Rmw(Add, I32, None)), content="30")
  inspect(@atomics.opcode(Rmw(Sub, I32, None)), content="37")
  inspect(@atomics.opcode(Rmw(Cmpxchg, I32, None)), content="72")
  inspect(@atomics.opcode(Rmw(Cmpxchg, I64, Some(N32))), content="78")
}

///|
test "every operation round-trips through its opcode" {
  let ops = @atomics.all()
  // 3 standalone, then 7 loads, 7 stores and seven RMW blocks of 7.
  inspect(ops.length(), content="66")
  for op in ops {
    let code = @atomics.opcode(op)
    inspect(@atomics.of_opcode(code) == Some(op), content="true")
  }
  // The opcodes are contiguous from 0 to 2 and 0x10 to 0x4E; nothing lives in
  // the gap or past the end.
  inspect(@atomics.of_opcode(0x03) is None, content="true")
  inspect(@atomics.of_opcode(0x4F) is None, content="true")
}

///|
test "the WAT mnemonics" {
  inspect(@atomics.name(Notify), content="memory.atomic.notify")
  inspect(@atomics.name(Wait(I32)), content="memory.atomic.wait32")
  inspect(@atomics.name(Load(I32, None)), content="i32.atomic.load")
  inspect(@atomics.name(Load(I64, Some(N16))), content="i64.atomic.load16_u")
  inspect(@atomics.name(Store(I64, Some(N32))), content="i64.atomic.store32")
  inspect(@atomics.name(Rmw(Add, I32, None)), content="i32.atomic.rmw.add")
  inspect(
    @atomics.name(Rmw(Cmpxchg, I64, Some(N8))),
    content="i64.atomic.rmw8.cmpxchg_u",
  )
}

///|
/// A Wax method name carries the ACCESS width only; the value type comes from
/// the operands. So several concrete operations share one method name, and the
/// name alone does not determine which.
test "the Wax method names, and the families they denote" {
  inspect(@atomics.method_name(Load(W8)), content="atomic_load8")
  inspect(@atomics.method_name(Store(W64)), content="atomic_store64")
  inspect(@atomics.method_name(Rmw(Add, W16)), content="atomic_rmw_add16")
  inspect(@atomics.method_name(Wait(I32)), content="atomic_wait32")
  inspect(@atomics.method_name(Notify), content="atomic_notify")
  // Every family answers to its own name.
  for f in @atomics.families() {
    inspect(
      @atomics.of_method_name(@atomics.method_name(f)) == Some(f),
      content="true",
    )
  }
  inspect(@atomics.of_method_name("atomic_nonsense") is None, content="true")
  // i32.atomic.load and i64.atomic.load32_u are different operations that read
  // the same four bytes, so they share a family and a method name.
  inspect(
    @atomics.family(Load(I32, None)) == @atomics.family(Load(I64, Some(N32))),
    content="true",
  )
  inspect(
    @atomics.family(Load(I64, None)) == @atomics.family(Load(I32, None)),
    content="false",
  )
}

///|
/// An atomic's alignment must be exactly the natural one, unlike a plain load
/// where a smaller value is a legal hint -- so this is a correctness table, not
/// an optimisation one.
test "access width and alignment" {
  inspect(@atomics.access_bytes(Load(I32, None)), content="4")
  inspect(@atomics.access_bytes(Load(I64, None)), content="8")
  inspect(@atomics.access_bytes(Load(I64, Some(N8))), content="1")
  inspect(@atomics.access_bytes(Load(I64, Some(N16))), content="2")
  inspect(@atomics.access_bytes(Notify), content="4")
  inspect(@atomics.access_bytes(Wait(I64)), content="8")
  inspect(@atomics.natural_align_log2(Load(I64, Some(N8))), content="0")
  inspect(@atomics.natural_align_log2(Load(I64, Some(N16))), content="1")
  inspect(@atomics.natural_align_log2(Load(I32, None)), content="2")
  inspect(@atomics.natural_align_log2(Load(I64, None)), content="3")
  // A family's width agrees with the operations in it.
  for op in @atomics.all() {
    inspect(
      @atomics.family_bytes(@atomics.family(op)) == @atomics.access_bytes(op),
      content="true",
    )
  }
}

///|
/// The signature after the address operand, which always has the memory's own
/// address type and so is not listed.
test "stack signatures" {
  fn sig(op : @atomics.Op) -> String {
    let (args, results) = @atomics.signature(op)
    fn render(l : Array[@atomics.NumTy]) -> String {
      l.map(t => if t is I32 { "i32" } else { "i64" }).join(" ")
    }

    "(" + render(args) + ") -> (" + render(results) + ")"
  }

  inspect(sig(Load(I32, None)), content="() -> (i32)")
  inspect(sig(Load(I64, Some(N8))), content="() -> (i64)")
  inspect(sig(Store(I64, None)), content="(i64) -> ()")
  inspect(sig(Rmw(Add, I32, None)), content="(i32) -> (i32)")
  // Compare-and-exchange takes the expected value as well as the replacement.
  inspect(sig(Rmw(Cmpxchg, I64, None)), content="(i64 i64) -> (i64)")
  inspect(sig(Notify), content="(i32) -> (i32)")
  // Wait takes the expected value and a timeout.
  inspect(sig(Wait(I32)), content="(i32 i64) -> (i32)")
  inspect(sig(Wait(I64)), content="(i64 i64) -> (i32)")
}
