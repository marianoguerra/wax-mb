// The point of these tests is the SEAM, not the enum contents: the type family
// must genuinely work at more than one Idx, because that is the whole
// justification for keeping the parameter (see the header of types.mbt and
// plan risk #6).

///|
/// A stand-in for the Wax instance, which refers to types by name.
priv struct Name {
  text : String
} derive(Eq, Debug)

///|
test "the spine instantiates at a named Idx, as Wax does" {
  let t : @wasm_types.ValType[Name] = Ref({
    nullable: true,
    typ: Type({ text: "list", }),
  })
  match t {
    Ref(r) => {
      assert_true(r.nullable)
      assert_eq(r.typ, Type({ text: "list", }))
    }
    _ => fail("expected a reference type")
  }
}

///|
test "and at an integer Idx, as the binary form will" {
  // This is the case that does not exist yet. If it stopped compiling, the
  // parameter would have quietly become decoration and the eventual code
  // generator would need an AST change rather than an addition.
  let t : @wasm_types.ValType[Int] = Ref({ nullable: false, typ: Exact(7), })
  assert_eq(t, Ref({ nullable: false, typ: Exact(7), }))
  let s : @wasm_types.StorageType[Int] = Packed(I8)
  assert_eq(s, Packed(I8))
}

///|
test "only the index-carrying heap types lack a keyword" {
  // Their absence is meaningful: each printer spells an index its own way, so
  // there is no shared spelling to return.
  let named : @wasm_types.HeapType[Name] = Type({ text: "t", })
  assert_eq(named.keyword(), None)
  let exact : @wasm_types.HeapType[Name] = Exact({ text: "t", })
  assert_eq(exact.keyword(), None)
  let any : @wasm_types.HeapType[Name] = Any
  assert_eq(any.keyword(), Some("any"))
  let bottom : @wasm_types.HeapType[Name] = None_
  assert_eq(bottom.keyword(), Some("none"))
  let nofunc : @wasm_types.HeapType[Name] = NoFunc
  assert_eq(nofunc.keyword(), Some("nofunc"))
}

///|
test "mutability wraps both storage and value types" {
  let field : @wasm_types.FieldType[Name] = { mut_: true, typ: Packed(I16), }
  assert_true(field.mut_)
  let global : @wasm_types.GlobalType[Name] = { mut_: false, typ: I32, }
  assert_false(global.mut_)
}

///|
test "limits keep the page size as a logarithm" {
  // The binary format encodes the exponent, so storing the size itself would
  // lose a non-power-of-two spelling on the way back out.
  let l : @wasm_types.Limits = {
    mi: 1UL,
    ma: Some(16UL),
    address_type: I64,
    page_size_log2: Some(0),
    shared: true,
  }
  assert_eq(l.page_size_log2, Some(0)) // a 1-byte page, not "no custom size"
  assert_eq(l.address_type, I64)
}

///|
test "v128 components stay unparsed" {
  let v : @wasm_types.V128 = {
    shape: I32x4,
    components: ["1", "0x2", "-3", "4"],
  }
  assert_eq(v.shape.to_str(), "i32x4")
  assert_eq(v.components[1], "0x2") // not normalised to "2"
}

///|
test "conditions nest" {
  let loc = @basic.dummy_loc
  let c : @wasm_types.Cond = Not(
    And([Var({ desc: "portable", info: loc, }), Version(3, 0, 0)]),
  )
  match c {
    Not(And(parts)) => assert_eq(parts.length(), 2)
    _ => fail("shape changed")
  }
}
