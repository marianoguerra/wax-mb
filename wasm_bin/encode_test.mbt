// Encoder tests.
//
// Every expected byte string here was checked against `wasm-tools print` and
// `wasm-tools validate` before being written down, so these are not the encoder
// agreeing with itself. What they pin is the part a differential run over the
// corpus cannot reach yet -- the encoder has no front end in front of it until
// the code generator lands -- and in particular the four fixes made while
// vendoring: rec groups, the reference-type shorthand, heap-type operands, and
// multi-memory memargs. None of those is visible to a test that only asks
// whether the result validates.

///|
/// Hex, so an expectation reads as the bytes the format specifies.
fn hex(b : Bytes) -> String {
  let digits : Array[Char] = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f',
  ]
  let out = StringBuilder::new()
  for i in 0..<b.length() {
    let byte = b[i].to_int()
    out.write_char(digits[byte >> 4])
    out.write_char(digits[byte & 0xF])
  }
  out.to_string()
}

///|
/// The eight bytes every module starts with.
let header : String = "0061736d01000000"

///|
/// A module with one function of type `() -> ()`, whose body is `instrs`.
fn one_func(instrs : Array[@wasm_bin.Instruction]) -> @wasm_bin.Module {
  let m = @wasm_bin.Module::empty()
  m.types.push(@wasm_bin.SubType::func([], []))
  m.rec_groups.push({ start: 0, len: 1, explicit: false })
  m.funcs.push(0)
  m.codes.push({ locals: [], body: instrs })
  m
}

///|
fn default_limits() -> @wasm_bin.Limits {
  { mi: 1UL, ma: None, address_type: I32, page_size_log2: None, shared: false }
}

///|
test "an empty module is just the header" {
  inspect(hex(@wasm_bin.encode(@wasm_bin.Module::empty())), content=header)
}

///|
test "one exported function" {
  let m = @wasm_bin.Module::empty()
  m.types.push(@wasm_bin.SubType::func([I32, I32], [I32]))
  m.rec_groups.push({ start: 0, len: 1, explicit: false })
  m.funcs.push(0)
  m.exports.push({ name: b"add", desc: Func(0) })
  m.codes.push({ locals: [], body: [LocalGet(0), LocalGet(1), I32Add] })
  inspect(
    hex(@wasm_bin.encode(m)),
    content=header +
      // type section: one rec group, a bare func type, (i32 i32) -> i32
      "0107" +
      "01" +
      "60" +
      "02" +
      "7f7f" +
      "01" +
      "7f" +
      // function section: one function, type 0
      "0302" +
      "01" +
      "00" +
      // export section: "add" -> func 0
      "0707" +
      "01" +
      "03" +
      "616464" +
      "00" +
      "00" +
      // code section: one body, no locals, local.get 0/1, i32.add, end
      "0a09" +
      "01" +
      "07" +
      "00" +
      "2000" +
      "2001" +
      "6a" +
      "0b",
  )
}

///|
/// A singleton `rec` is a different type from the same definition written bare
/// -- recursive type identity is by group -- so the encoder cannot infer the
/// prefix from the group's length. Upstream dropped rec groups entirely and
/// wrote every type flat, which silently unrelated any types that referred to
/// each other.
test "rec groups are emitted, and a singleton rec keeps its prefix" {
  let bare = @wasm_bin.Module::empty()
  bare.types.push(@wasm_bin.SubType::func([], []))
  bare.rec_groups.push({ start: 0, len: 1, explicit: false })
  inspect(
    hex(@wasm_bin.encode(bare)),
    content=header + "0104" + "01" + "600000",
  )
  let singleton = @wasm_bin.Module::empty()
  singleton.types.push(@wasm_bin.SubType::func([], []))
  singleton.rec_groups.push({ start: 0, len: 1, explicit: true })
  inspect(
    hex(@wasm_bin.encode(singleton)),
    content=header + "0106" + "01" + "4e01" + "600000",
  )
}

///|
test "two mutually recursive types are one rec group" {
  let m = @wasm_bin.Module::empty()
  let ref_to = idx => {
    @wasm_bin.SubType::simple(
      Struct({
        fields: [
          { mut_: false, typ: Value(Ref({ nullable: false, typ: Type(idx) })) },
        ],
      }),
    )
  }
  m.types.push(ref_to(1))
  m.types.push(ref_to(0))
  m.rec_groups.push({ start: 0, len: 2, explicit: true })
  inspect(
    hex(@wasm_bin.encode(m)),
    content=header +
      "010d" +
      "01" +
      "4e02" +
      // each: struct, one field, immutable (ref $n)
      "5f" +
      "01" +
      "6401" +
      "00" +
      "5f" +
      "01" +
      "6400" +
      "00",
  )
}

///|
/// A nullable reference to an abstract heap type has a one-byte abbreviation,
/// and both spellings are valid -- which is exactly why the choice has to be
/// made once, by rule, rather than per constructor as upstream did. It came out
/// inconsistent there: `funcref` short, `anyref` long.
test "reference types take the short form only where the format allows" {
  fn global_of(rt : @wasm_bin.RefType) -> String raise {
    let m = @wasm_bin.Module::empty()
    m.globals.push({
      type_: { mut_: false, typ: Ref(rt) },
      init: [RefNull(rt.typ)],
    })
    let h = hex(@wasm_bin.encode(m))
    // global section: id 06, size, count 01, then the global type
    h[header.length() + 6:].to_owned()
  }
  // nullable + abstract: the abbreviation, one byte, then `00` immutable
  inspect(global_of({ nullable: true, typ: Func }), content="7000" + "d0700b")
  inspect(global_of({ nullable: true, typ: Extern }), content="6f00" + "d06f0b")
  inspect(global_of({ nullable: true, typ: Any }), content="6e00" + "d06e0b")
  inspect(global_of({ nullable: true, typ: Eq }), content="6d00" + "d06d0b")
  inspect(global_of({ nullable: true, typ: NoCont }), content="7500" + "d0750b")
  // non-nullable: 0x64 then the heap type, never abbreviated
  inspect(
    global_of({ nullable: false, typ: Func }),
    content="647000" + "d0700b",
  )
  inspect(global_of({ nullable: false, typ: Any }), content="646e00" + "d06e0b")
  // a concrete index is not abstract, so it is never abbreviated either way
  inspect(
    global_of({ nullable: true, typ: Type(0) }),
    content="630000" + "d0000b",
  )
  inspect(
    global_of({ nullable: false, typ: Type(0) }),
    content="640000" + "d0000b",
  )
  // exact: 0x62 then a u32
  inspect(
    global_of({ nullable: false, typ: Exact(0) }),
    content="64620000" + "d062000b",
  )
}

///|
/// `ref.null`, `ref.test` and `ref.cast` take a HEAP type, with nullability
/// either implicit (ref.null) or in the opcode (the other two). Upstream wrote
/// a value type for all three, prefixing each with a spurious 0x63 or 0x64.
test "the cast instructions take heap types, and nullability picks the opcode" {
  fn tail(
    instrs : Array[@wasm_bin.Instruction],
    want : String,
  ) -> String raise {
    let h = hex(@wasm_bin.encode(one_func(instrs)))
    if h.has_suffix(want) {
      want
    } else {
      h
    }
  }
  // ref.test (ref func) is 0xFB 0x14, ref.test (ref null func) 0xFB 0x15, and
  // the operand is the bare heap type 0x70 -- no 0x63/0x64 in front of it.
  inspect(
    tail([RefTest({ nullable: false, typ: Func })], "fb14700b"),
    content="fb14700b",
  )
  inspect(
    tail([RefTest({ nullable: true, typ: Func })], "fb15700b"),
    content="fb15700b",
  )
  inspect(
    tail([RefCast({ nullable: false, typ: Func })], "fb16700b"),
    content="fb16700b",
  )
  inspect(
    tail([RefCast({ nullable: true, typ: Func })], "fb17700b"),
    content="fb17700b",
  )
  // br_on_cast carries nullability in a flags byte, then two heap types.
  inspect(
    tail(
      [BrOnCast(0, { nullable: true, typ: Any }, { nullable: false, typ: Eq })],
      "fb1801" + "00" + "6e6d" + "0b",
    ),
    content="fb1801006e6d0b",
  )
}

///|
/// Multi-memory rides in the alignment field: bit 6 set means a memory index
/// follows. Upstream's parameter was literally named `_memidx` -- it ignored
/// the index, so every access to a memory other than 0 was silently encoded as
/// an access to memory 0.
test "a memarg on a memory other than zero carries its index" {
  fn code(instrs : Array[@wasm_bin.Instruction]) -> String raise {
    let m = one_func(instrs)
    m.memories.push({ limits: default_limits() })
    m.memories.push({ limits: default_limits() })
    hex(@wasm_bin.encode(m))
  }
  // i32.load memory 0, align 2, offset 0
  inspect(
    code([I32Const(0), I32Load(0, 2, 0L), Drop]).has_suffix("41002802001a0b"),
    content="true",
  )
  // i32.load memory 1: align gains bit 6, then the index, then the offset
  inspect(
    code([I32Const(0), I32Load(1, 2, 0L), Drop]).has_suffix(
      "410028420100" + "1a0b",
    ),
    content="true",
  )
}

///|
/// The flags byte carries four independent facts. Upstream needed two
/// near-identical copies of this and a bool to pick between them, and had no
/// `shared` at all -- so a shared memory was not merely misencoded, it was
/// unrepresentable.
test "limits flags" {
  fn mem(l : @wasm_bin.Limits) -> String raise {
    let m = @wasm_bin.Module::empty()
    m.memories.push({ limits: l })
    // memory section: id 05, size, count 01, then the limits
    hex(@wasm_bin.encode(m))[header.length() + 6:].to_owned()
  }
  inspect(mem(default_limits()), content="0001")
  inspect(mem({ ..default_limits(), ma: Some(2UL) }), content="010102")
  inspect(
    mem({ ..default_limits(), shared: true, ma: Some(2UL) }),
    content="030102",
  )
  inspect(mem({ ..default_limits(), address_type: I64 }), content="0401")
  inspect(
    mem({ ..default_limits(), page_size_log2: Some(0) }),
    content="080100",
  )
}

///|
/// An unresolved block type used to become `0x40`, the empty block type, which
/// silently threw the results away.
test "an inline block type is an error, not an empty one" {
  try @wasm_bin.encode(one_func([Block(MultiValue([I32, I32]), [])])) catch {
    e =>
      inspect(
        e.to_string(),
        content="block type is still inline; intern it as a type index before encoding",
      )
  } noraise {
    _ => fail("expected an error")
  }
}

///|
/// The 256 instructions the removed catch-all was hiding: all of SIMD beyond
/// loads and stores, `i64.mul_wide_s`/`_u`, and every atomic. Upstream emitted
/// `unreachable` for each -- a module that loads, validates and does the wrong
/// thing, which against a byte-identity oracle is the worst available failure
/// mode.
test "an unencodable instruction is an error, not an unreachable" {
  try @wasm_bin.encode(one_func([I32x4Splat])) catch {
    e =>
      inspect(
        e.to_string(),
        content="instruction not encodable yet: I32x4Splat",
      )
  } noraise {
    _ => fail("expected an error")
  }
}
