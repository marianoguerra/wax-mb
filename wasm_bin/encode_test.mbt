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
  m.codes.push({ locals: [], body: instrs, priority: None })
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
  m.codes.push({
    locals: [],
    body: [LocalGet(0), LocalGet(1), I32Add],
    priority: None,
  })
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
/// The 256 instructions the removed catch-all used to hide: all of SIMD past
/// loads and stores, `i64.mul_wide_s`/`_u`, and the atomics. Upstream emitted
/// `unreachable` for each. Their opcodes come from `wasm-encoder`'s instruction
/// table, and this module -- one instruction of each argument shape -- was
/// checked with `wasm-tools print`, which gives back exactly these mnemonics.
test "the SIMD, wide-arithmetic and atomic opcodes" {
  let m = one_func([
    I32Const(0),
    I32x4Splat,
    Drop,
    I32Const(0),
    I8x16Splat,
    I8x16ExtractLaneS(3),
    Drop,
    I32Const(0),
    I8x16Splat,
    I32Const(0),
    I8x16Splat,
    I8x16Shuffle([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]),
    Drop,
    I64Const(2L),
    I64Const(3L),
    I64MulWideS,
    Drop,
    Drop,
  ])
  let h = hex(@wasm_bin.encode(m))
  // i32x4.splat 0xFD 0x11; i8x16.extract_lane_s 0xFD 0x15 then the lane;
  // i8x16.shuffle 0xFD 0x0D then sixteen lane bytes; i64.mul_wide_s 0xFC 0x15.
  inspect(h.contains("fd11"), content="true")
  inspect(h.contains("fd1503"), content="true")
  inspect(h.contains("fd0d000102030405060708090a0b0c0d0e0f"), content="true")
  inspect(h.contains("fc15"), content="true")
}

///|
/// `atomic.fence` is the one atomic with no memory operand, so it cannot be
/// spelled as an `Atomic` with a degenerate memarg: the format wants a single
/// 0x00 where the memarg would go, not an alignment and an offset.
test "atomics, and the fence that is not one" {
  inspect(
    hex(@wasm_bin.encode(one_func([AtomicFence]))).has_suffix("fe03000b"),
    content="true",
  )
  let load = one_func([I32Const(0), Atomic(0x10, 0, 2, 0L), Drop])
  load.memories.push({ ..default_limits(), shared: true, ma: Some(1UL) } |> mem)
  // 0xFE, the sub-opcode as a byte, then the memarg
  inspect(hex(@wasm_bin.encode(load)).contains("fe100200"), content="true")
}

///|
fn mem(l : @wasm_bin.Limits) -> @wasm_bin.MemoryType {
  { limits: l }
}

///|
/// The `name` section. Upstream emitted no custom section at all, and carried a
/// single `func_names` map it then never read -- so every name was dropped.
/// There are twelve name spaces, not one.
test "the name section carries every name space, in ascending id order" {
  let m = @wasm_bin.Module::empty()
  m.types.push(@wasm_bin.SubType::func([I32], []))
  m.rec_groups.push({ start: 0, len: 1, explicit: false })
  m.funcs.push(0)
  m.codes.push({ locals: [I64], body: [], priority: None })
  m.names.module_ = Some(b"m")
  m.names.functions[0] = b"f"
  m.names.types[0] = b"t"
  m.names.locals[0] = { 0: b"p", 1: b"l" }
  let h = hex(@wasm_bin.encode(m))
  // `wasm-tools print` on these bytes gives back
  //   (module $m (type $t (func (param i32)))
  //     (func $f (type $t) (param $p i32) (local $l i64)))
  // which is the whole point: upstream dropped all five names.
  inspect(
    h.has_suffix(
      // custom section 0, 32 bytes, named "name"
      "00" +
      "20" +
      "04" +
      "6e616d65" +
      // 0x00 module: "m"
      "00" +
      "02" +
      "01" +
      "6d" +
      // 0x01 functions: one entry, 0 -> "f"
      "01" +
      "04" +
      "01" +
      "00" +
      "01" +
      "66" +
      // 0x02 locals: function 0, two entries, 0 -> "p" and 1 -> "l"
      "02" +
      "09" +
      "01" +
      "00" +
      "02" +
      "00" +
      "01" +
      "70" +
      "01" +
      "01" +
      "6c" +
      // 0x04 types: one entry, 0 -> "t"
      "04" +
      "04" +
      "01" +
      "00" +
      "01" +
      "74",
    ),
    content="true",
  )
}

///|
/// Absent is not the same as present-and-empty: a `name` section with no
/// subsections is a different module from no `name` section, and it is bytes.
test "no names means no name section" {
  let m = one_func([])
  inspect(hex(@wasm_bin.encode(m)).contains("6e616d65"), content="false")
}

///|
test "target_features passes its entries through verbatim" {
  let m = @wasm_bin.Module::empty()
  m.target_features.push((0x2B, b"simd128"))
  // custom section, name "target_features", 1 entry, prefix 2b, "simd128"
  inspect(
    hex(@wasm_bin.encode(m)),
    content=header +
      "00" +
      "1a" +
      "0f" +
      "7461726765745f6665617475726573" +
      "01" +
      "2b" +
      "07" +
      "73696d64313238",
  )
}

///|
/// Each vector in the name section has to be in ascending index order. The
/// reference gets that free from `IntMap.bindings`; here the map is unordered,
/// so the encoder sorts -- making it the encoder's job rather than the
/// caller's, which is one fewer way to differ by a byte.
test "name entries are sorted by index, however they were inserted" {
  let m = @wasm_bin.Module::empty()
  m.types.push(@wasm_bin.SubType::func([], []))
  m.rec_groups.push({ start: 0, len: 1, explicit: false })
  for i in [2, 0, 1] {
    m.funcs.push(0)
    m.codes.push({ locals: [], body: [], priority: None })
    m.names.functions[i] = [b"a", b"b", b"c"][i]
  }
  // inserted 2, 0, 1; emitted 0, 1, 2
  inspect(
    hex(@wasm_bin.encode(m)).has_suffix(
      "01" +
      "0a" +
      "03" +
      "00" +
      "01" +
      "61" +
      "01" +
      "01" +
      "62" +
      "02" +
      "01" +
      "63",
    ),
    content="true",
  )
}

///|
/// Stack switching, which upstream's model could not express at all -- the
/// seven instructions simply were not there, though the Wax AST has had them
/// since Phase 2. Opcodes and the resume table's shape are wasm_output.ml's.
test "stack switching" {
  fn tail(instrs : Array[@wasm_bin.Instruction]) -> String raise {
    let h = hex(@wasm_bin.encode(one_func(instrs)))
    h[h.length() - 2 - _tail_len(instrs) * 2:].to_owned()
  }
  inspect(tail([ContNew(1)]), content="e0010b")
  inspect(tail([ContBind(1, 2)]), content="e101020b")
  inspect(tail([Suspend(3)]), content="e2030b")
  inspect(tail([Switch(1, 3)]), content="e601030b")
  // resume $t (on $tag $label) (on $other switch)
  inspect(
    tail([Resume(1, [OnLabel(3, 0), OnSwitch(4)])]),
    content="e301" + "02" + "00" + "03" + "00" + "01" + "04" + "0b",
  )
  inspect(
    tail([ResumeThrow(1, 3, [])]),
    content="e4" + "01" + "03" + "00" + "0b",
  )
  inspect(tail([ResumeThrowRef(1, [])]), content="e50100" + "0b")
}

///|
/// Byte length of the encoded instructions, so a test can name just the tail it
/// cares about rather than a whole module.
fn _tail_len(instrs : Array[@wasm_bin.Instruction]) -> Int raise {
  @wasm_bin.encode(one_func(instrs)).length() -
  @wasm_bin.encode(one_func([])).length()
}

///|
/// The `metadata.code.*` sections. A hint is keyed by its instruction's byte
/// offset within the function body, and a body begins with the locals
/// declaration -- so offset 0 is the locals count byte, not the first opcode.
///
/// The reference gathers these the same way, with a sink the instruction
/// encoder writes to, for the same reason: the offset is knowable exactly once,
/// while the opcode is being written.
test "metadata.code.branch_hint records the branch's offset in the body" {
  let m = one_func([
    I32Const(1),
    Hinted({ ..@wasm_bin.InstrHints::none(), branch: Some(true) }, BrIf(0)),
  ])
  let h = hex(@wasm_bin.encode(m))
  // body is: 00 (no locals) 41 01 (i32.const 1) 0d 00 (br_if 0) 0b
  // so the br_if opcode sits at offset 3.
  //
  // custom section 0: the name is 25 bytes, then 1 function, index 0, 1 entry,
  // offset 3, payload length 1, payload 01 (likely). And it sits between the
  // function section and the code section, which the proposal requires.
  inspect(
    h.contains(
      "19" +
      "6d657461646174612e636f64652e6272616e63685f68696e74" +
      "01" +
      "00" +
      "01" +
      "03" +
      "01" +
      "01",
    ),
    content="true",
  )
}

///|
/// A priority is advice about the function, not about an instruction, so it is
/// recorded at offset 0 -- the position that means "the function itself".
test "metadata.code.compilation_priority is keyed at offset zero" {
  let m = one_func([])
  m.codes[0] = {
    ..m.codes[0],
    priority: Some({ compilation: 2, optimization: Some(3) }),
  }
  inspect(
    hex(@wasm_bin.encode(m)).contains(
      "6d657461646174612e636f64652e636f6d70696c6174696f6e5f7072696f72697479" +
      "01" +
      "00" +
      "01" +
      "00" +
      "02" +
      "0203",
    ),
    content="true",
  )
}

///|
/// A function with no hints of a given kind takes no entry in that section, and
/// a section with no entries is not written at all.
test "an unhinted module has no metadata sections" {
  inspect(
    hex(@wasm_bin.encode(one_func([Nop]))).contains("6d65746164617461"),
    content="false",
  )
}

///|
/// A continuation type: the stack-switching proposal's `(cont $ft)`.
///
/// The instructions landed before the type did, which was backwards -- a module
/// that uses `cont.new` has to be able to say what it makes a continuation of.
/// The function type it names goes out as a HEAP type, not a bare index, so a
/// concrete index takes the signed form.
test "a continuation type names its function type" {
  let m = @wasm_bin.Module::empty()
  m.types.push(@wasm_bin.SubType::func([], []))
  m.types.push(@wasm_bin.SubType::simple(Cont(0)))
  m.rec_groups.push({ start: 0, len: 1, explicit: false })
  m.rec_groups.push({ start: 1, len: 1, explicit: false })
  inspect(
    hex(@wasm_bin.encode(m)),
    content=header + "0106" + "02" + "600000" + "5d00",
  )
}

///|
/// The custom-descriptors clauses wrap the composite type: `describes` (0x4C)
/// then `descriptor` (0x4D), both INSIDE the `sub` form rather than beside it.
///
/// Which is why a final, supertype-less struct that carries a descriptor still
/// takes the short form -- no `sub` prefix, just 0x4D and the index ahead of
/// the struct.
test "the descriptor clauses wrap the composite type" {
  let m = @wasm_bin.Module::empty()
  let empty_struct = ({ fields: [] } : @wasm_bin.StructType)
  // $obj describes nothing and has $desc as its descriptor; $desc describes
  // $obj. They must name each other, which is why they are one rec group.
  m.types.push({
    final_: true,
    supertypes: [],
    descriptor: Some(1),
    describes: None,
    composite: Struct(empty_struct),
  })
  m.types.push({
    final_: true,
    supertypes: [],
    descriptor: None,
    describes: Some(0),
    composite: Struct(empty_struct),
  })
  m.rec_groups.push({ start: 0, len: 2, explicit: true })
  inspect(
    hex(@wasm_bin.encode(m)),
    content=header +
      "010b" +
      "01" +
      "4e02" +
      // $obj: descriptor $desc, then the struct
      "4d01" +
      "5f00" +
      // $desc: describes $obj, then the struct
      "4c00" +
      "5f00",
  )
  // A non-final type keeps the `sub` prefix, and the clauses would stay inside
  // it -- after the supertype vector, before the composite type. The base is
  // non-final too, since nothing can extend a final type.
  let n = @wasm_bin.Module::empty()
  let open_struct = (
    {
      final_: false,
      supertypes: [],
      descriptor: None,
      describes: None,
      composite: CompositeType::Struct(empty_struct),
    } : @wasm_bin.SubType)
  n.types.push(open_struct)
  n.types.push({ ..open_struct, supertypes: [0] })
  n.rec_groups.push({ start: 0, len: 1, explicit: false })
  n.rec_groups.push({ start: 1, len: 1, explicit: false })
  inspect(
    hex(@wasm_bin.encode(n)),
    content=header +
      "010a" +
      "02" +
      "50" +
      "00" +
      "5f00" +
      "50" +
      "0100" +
      "5f00",
  )
}
