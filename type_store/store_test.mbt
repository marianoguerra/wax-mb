// Tests for the interned type store.
//
// The properties worth pinning are the ones the reference's design exists to
// protect: that structurally equal rec groups get the same canonical index
// however they were spelled, that a mis-normalized group is rejected rather
// than silently corrupting the subtyping relation, and that the subtyping
// relation itself agrees with the spec's hierarchy.

///|
fn func_group(
  params : Array[@wasm_types.ValType[@type_store.RefIndex]],
  results : Array[@wasm_types.ValType[@type_store.RefIndex]],
) -> @type_store.RecType[@type_store.RefIndex] {
  [
    {
      final_: true,
      supertype: None,
      descriptor: None,
      describes: None,
      typ: Func({ params, results }),
    },
  ]
}

///|
fn struct_of(
  fields : Array[@wasm_types.ValType[@type_store.RefIndex]],
  supertype? : @type_store.RefIndex? = None,
  final_? : Bool = true,
) -> @type_store.SubType[@type_store.RefIndex] {
  {
    final_,
    supertype,
    descriptor: None,
    describes: None,
    typ: Struct(fields.map(v => { mut_: false, typ: Value(v) })),
  }
}

///|
test "an empty store defines nothing" {
  inspect(@type_store.TypeStore::new().last_index(), content="0")
}

///|
test "a group advances the index by its length" {
  let s = @type_store.TypeStore::new()
  let id = s.add_rectype(func_group([I32], [I32]))
  inspect(id.to_int_for_tests_only(), content="0")
  inspect(s.last_index(), content="1")
  let id2 = s.add_rectype([struct_of([I32]), struct_of([I64])])
  inspect(id2.to_int_for_tests_only(), content="1")
  inspect(s.last_index(), content="3")
}

///|
/// Deduplication is what makes a canonical index canonical: two spellings of
/// the same recursive type are the same type, so the second registration must
/// return the first's index and define nothing new.
test "a structurally equal group is not added twice" {
  let s = @type_store.TypeStore::new()
  let a = s.add_rectype(func_group([I32], [I64]))
  let b = s.add_rectype(func_group([I32], [I64]))
  inspect(a == b, content="true")
  inspect(s.last_index(), content="1")
  // A different group is a different type.
  let c = s.add_rectype(func_group([I64], [I64]))
  inspect(c.to_int_for_tests_only(), content="1")
  inspect(s.last_index(), content="2")
}

///|
/// The point of `Rec` being a constructor rather than a negative index: a group
/// dedups regardless of where it lands, because its internal references are
/// relative.
test "mutually recursive groups dedup regardless of where they land" {
  let s = @type_store.TypeStore::new()
  let pair : @type_store.RecType[@type_store.RefIndex] = [
    struct_of([Ref({ nullable: true, typ: Type(Rec(1)) })]),
    struct_of([Ref({ nullable: true, typ: Type(Rec(0)) })]),
  ]
  let first = s.add_rectype(pair)
  let _ = s.add_rectype(func_group([], []))
  let again = s.add_rectype([
    struct_of([Ref({ nullable: true, typ: Type(Rec(1)) })]),
    struct_of([Ref({ nullable: true, typ: Type(Rec(0)) })]),
  ])
  inspect(first == again, content="true")
  inspect(s.last_index(), content="3")
}

///|
/// The backstop. A violation is a mis-normalized group -- the
/// source-versus-canonical index confusion -- and is rejected rather than left
/// to corrupt the subtyping relation.
test "a mis-normalized group is rejected" {
  let s = @type_store.TypeStore::new()
  // A back-reference past the end of a one-member group.
  try
    s.add_rectype([struct_of([Ref({ nullable: true, typ: Type(Rec(3)) })])])
  catch {
    e =>
      inspect(
        e.to_string(),
        content="back-reference 3 is outside a rec group of 1",
      )
  } noraise {
    _ => fail("expected an error")
  }
  // A Def naming a type that is not defined yet. An `Id` can only come from
  // the store -- the test cannot fabricate one, which is the abstraction doing
  // its job -- so this borrows a real index from another store and offsets it
  // past the end of this one.
  let other = @type_store.TypeStore::new()
  let borrowed = other.add_rectype(func_group([], []))
  try
    s.add_rectype([
      struct_of([Ref({ nullable: true, typ: Type(Def(borrowed)) })]),
    ])
  catch {
    e =>
      inspect(
        e.to_string(),
        content="reference to type 0, which is not defined yet",
      )
  } noraise {
    _ => fail("expected an error")
  }
  // Nothing was defined by any attempt.
  inspect(s.last_index(), content="0")
}

///|
/// Resolution turns a group-relative reference into an absolute canonical
/// index, which is the whole job of `subtyping_info`.
test "resolution makes intra-group references absolute" {
  let s = @type_store.TypeStore::new()
  let _ = s.add_rectype(func_group([], []))
  let base = s.add_rectype([
    struct_of([Ref({ nullable: true, typ: Type(Rec(1)) })]),
    struct_of([Ref({ nullable: true, typ: Type(Rec(0)) })]),
  ])
  let info = s.subtyping_info()
  // The group landed at index 1, so its members are 1 and 2. Member 0 refers to
  // Rec(1) -- the group's second member -- which resolves to 2, and vice versa.
  fn first_ref(id : @type_store.Id) -> Int {
    match info.get_subtype(id).typ {
      Struct(fields) =>
        match fields[0].typ {
          Value(Ref({ typ: Type(i), .. })) => i.to_int_for_tests_only()
          _ => -1
        }
      _ => -1
    }
  }

  inspect(first_ref(base), content="2")
  inspect(first_ref(base.add(1)), content="1")
}

///|
/// The subtyping hierarchy. Written out because the reference writes it out:
/// both arms are matched exhaustively, without a wildcard row, so that adding a
/// heap type forces every relevant case to be revisited rather than silently
/// falling through to `false`.
test "the abstract heap type hierarchy" {
  let info = @type_store.TypeStore::new().subtyping_info()
  fn sub(
    a : @wasm_types.HeapType[@type_store.Id],
    b : @wasm_types.HeapType[@type_store.Id],
  ) -> Bool {
    @type_store.heap_subtype(info, a, b)
  }

  // Each hierarchy's bottom is below its top, and nothing else is.
  inspect(sub(NoFunc, Func), content="true")
  inspect(sub(NoExtern, Extern), content="true")
  inspect(sub(NoExn, Exn), content="true")
  inspect(sub(NoCont, Cont), content="true")
  inspect(sub(None_, Any), content="true")
  // The four hierarchies do not mix.
  inspect(sub(NoFunc, Extern), content="false")
  inspect(sub(None_, Func), content="false")
  inspect(sub(Func, Any), content="false")
  inspect(sub(Extern, Any), content="false")
  // The internal hierarchy: none <: i31/struct/array <: eq <: any.
  inspect(sub(I31, Eq), content="true")
  inspect(sub(Struct, Eq), content="true")
  inspect(sub(Array, Any), content="true")
  inspect(sub(Eq, Any), content="true")
  inspect(sub(Any, Eq), content="false")
  inspect(sub(I31, Struct), content="false")
  // Reflexive.
  inspect(sub(Any, Any), content="true")
  inspect(sub(NoExn, NoExn), content="true")
}

///|
/// A concrete type belongs to the hierarchy of whatever it defines, and `exact`
/// is invariant among concrete types -- it has the same proper supertypes as
/// the type it pins, but nothing else is exactly it.
test "concrete types, and exact" {
  let s = @type_store.TypeStore::new()
  let f = s.add_rectype(func_group([I32], []))
  let st = s.add_rectype([struct_of([I32])])
  // (type $sub (sub $st (struct (field i32) (field i64))))
  let sub_st = s.add_rectype([
    {
      final_: true,
      supertype: Some(Def(st)),
      descriptor: None,
      describes: None,
      typ: Struct([
        { mut_: false, typ: Value(I32) },
        { mut_: false, typ: Value(I64) },
      ]),
    },
  ])
  let info = s.subtyping_info()
  fn sub(
    a : @wasm_types.HeapType[@type_store.Id],
    b : @wasm_types.HeapType[@type_store.Id],
  ) -> Bool {
    @type_store.heap_subtype(info, a, b)
  }

  // A function type is under func, never under any.
  inspect(sub(Type(f), Func), content="true")
  inspect(sub(Type(f), Any), content="false")
  // A struct type is an aggregate, so under struct, eq and any -- not array.
  inspect(sub(Type(st), Struct), content="true")
  inspect(sub(Type(st), Eq), content="true")
  inspect(sub(Type(st), Any), content="true")
  inspect(sub(Type(st), Array), content="false")
  // A declared supertype is walked.
  inspect(sub(Type(sub_st), Type(st)), content="true")
  inspect(sub(Type(st), Type(sub_st)), content="false")
  // The bottoms are below the concrete types of their own hierarchy.
  inspect(sub(None_, Type(st)), content="true")
  inspect(sub(NoFunc, Type(f)), content="true")
  inspect(sub(None_, Type(f)), content="false")
  inspect(sub(NoFunc, Type(st)), content="false")
  // exact: below what it pins, but only itself is below it.
  inspect(sub(Exact(st), Struct), content="true")
  inspect(sub(Exact(sub_st), Type(st)), content="true")
  inspect(sub(Exact(st), Exact(st)), content="true")
  inspect(sub(Type(st), Exact(st)), content="false")
  inspect(sub(Exact(sub_st), Exact(st)), content="false")
}

///|
/// A non-nullable reference is a subtype of a nullable one, never the reverse;
/// and subtyping is only interesting between references.
test "reference and value subtyping" {
  let info = @type_store.TypeStore::new().subtyping_info()
  fn r(
    nullable : Bool,
    typ : @wasm_types.HeapType[@type_store.Id],
  ) -> @wasm_types.RefType[@type_store.Id] {
    { nullable, typ }
  }

  inspect(
    @type_store.ref_subtype(info, r(false, Any), r(true, Any)),
    content="true",
  )
  inspect(
    @type_store.ref_subtype(info, r(true, Any), r(false, Any)),
    content="false",
  )
  inspect(
    @type_store.ref_subtype(info, r(true, None_), r(true, Any)),
    content="true",
  )
  inspect(@type_store.val_subtype(info, I32, I32), content="true")
  inspect(@type_store.val_subtype(info, I32, I64), content="false")
  inspect(
    @type_store.val_subtype(info, Ref(r(false, Eq)), Ref(r(true, Any))),
    content="true",
  )
}
