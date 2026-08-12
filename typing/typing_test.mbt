// Tests for type resolution.
//
// Resolution turns a Wax type that NAMES what it refers to into one that
// NUMBERS it. The cases worth pinning are where that is more than a rename: a
// reference inside the group being built, a proposal that has to be enabled,
// and a name that does not resolve at all -- which must fail softly, because
// the first unresolvable type ending the run would hide every error after it.

///|
fn loc_at(start : Int, end_ : Int) -> @basic.Location {
  {
    start: { fname: "t.wax", lnum: 1, bol: 0, cnum: start },
    end: { fname: "t.wax", lnum: 1, bol: 0, cnum: end_ },
  }
}

///|
fn id(name : String, at? : Int = 0) -> @ast.Ident {
  { name, loc: loc_at(at, at + name.length()) }
}

///|
/// A context with the named types already defined in the store.
fn ctx_with(
  defined : Array[String],
  features? : @feature.Set = @feature.default(),
) -> @typing.TypeContext raise {
  let store = @type_store.TypeStore::new()
  let cond = @ref.new(@cond.true_)
  let ns = @typing_env.Namespace::new(cond)
  let origin = @ref.new(@typing_env.Origin::Root)
  let tbl : @typing_env.Tbl[(@type_store.RefIndex, @ast.SubType)] = @typing_env.Tbl::new(
    "type", ns, origin,
  )
  let empty : @ast.SubType = {
    typ: Func({ params: [], results: [] }),
    supertype: None,
    final_: true,
    descriptor: None,
    describes: None,
  }
  for i, n in defined {
    // A distinct type per name, so the canonical indices differ.
    let group : @type_store.RecType[@type_store.RefIndex] = [
      {
        final_: true,
        supertype: None,
        typ: Func({
          params: Array::makei(i, _ => @wasm_types.ValType::I32),
          results: [],
        }),
      },
    ]
    let idx = store.add_rectype(group)
    tbl.add(n, loc_at(0, 1), (Def(idx), empty))
  }
  @typing.TypeContext::new(store, tbl, features)
}

///|
/// The many arms that are a pure rename, and the two that are not.
test "heap types resolve constructor for constructor" {
  let ctx = ctx_with(["node"])
  let d = @diagnostic.collector()
  fn resolved(h : @wasm_types.HeapType[@ast.Ident]) -> String {
    match @typing.heaptype(ctx, d, h) {
      None => "unresolved"
      Some(r) =>
        match r {
          Type(i) => "type#" + i.to_int_for_tests_only().to_string()
          Exact(i) => "exact#" + i.to_int_for_tests_only().to_string()
          Func => "func"
          Any => "any"
          None_ => "none"
          NoCont => "nocont"
          _ => "other"
        }
    }
  }

  inspect(resolved(Func), content="func")
  inspect(resolved(Any), content="any")
  inspect(resolved(None_), content="none")
  inspect(resolved(NoCont), content="nocont")
  // A named type becomes its canonical index.
  inspect(resolved(Type(id("node"))), content="type#0")
  // A name nothing defines does not resolve, and does not raise.
  inspect(resolved(Type(id("missing"))), content="unresolved")
}

///|
/// `exact` is the custom-descriptors proposal. It is gated even when the name
/// resolves perfectly well, and checking continues either way.
test "exact is gated on its proposal" {
  let d = @diagnostic.collector()
  let off = ctx_with(["node"])
  let r = @typing.heaptype(off, d, Exact(id("node", at=7)))
  // It still resolves -- error recovery, not refusal.
  inspect(r is Some(_), content="true")
  inspect(d.collected().length(), content="1")
  inspect(
    @message.to_plain_string(d.collected()[0].message),
    content="This uses the custom-descriptors feature, which is not enabled; pass --feature custom-descriptors.",
  )
  // Reported at the name, which is where the reader has to look.
  inspect(d.collected()[0].loc.start.cnum, content="7")

  // With the proposal enabled there is nothing to say.
  let d2 = @diagnostic.collector()
  let on = ctx_with(
    ["node"],
    features=@feature.configure([(CustomDescriptors, true)]),
  )
  let _ = @typing.heaptype(on, d2, Exact(id("node")))
  inspect(d2.collected().length(), content="0")
}

///|
/// Value and reference types are the same walk one level up, and nullability
/// passes straight through.
test "value types" {
  let ctx = ctx_with(["node"])
  let d = @diagnostic.collector()
  fn ok(v : @wasm_types.ValType[@ast.Ident]) -> Bool {
    @typing.valtype(ctx, d, v) is Some(_)
  }

  inspect(ok(I32), content="true")
  inspect(ok(V128), content="true")
  inspect(ok(Ref({ nullable: true, typ: Any })), content="true")
  inspect(ok(Ref({ nullable: false, typ: Type(id("node")) })), content="true")
  inspect(
    ok(Ref({ nullable: false, typ: Type(id("missing")) })),
    content="false",
  )
  // Nullability survives the trip.
  guard! @typing.valtype(ctx, d, Ref({ nullable: true, typ: Any }))
    is Some(Ref(r))
  inspect(r.nullable, content="true")
}

///|
/// The normalized form is what a rec group is built in, and the difference from
/// the resolved form is exactly that a reference may name the group itself.
test "the normalized form keeps references relative" {
  let ctx = ctx_with(["node"])
  let d = @diagnostic.collector()
  guard! @typing.n_heaptype(ctx, d, Type(id("node"))) is Some(Type(r))
  // Already in the store, so a Def rather than a Rec.
  inspect(r is Def(_), content="true")
  // And the resolved form of the same reference is its canonical index.
  guard! @typing.heaptype(ctx, d, Type(id("node"))) is Some(Type(i))
  inspect(i.to_int_for_tests_only(), content="0")
}

///|
/// Duplicate names are reported at the SECOND occurrence, with the first
/// carried as a related label -- because "which other one" is the first thing
/// anyone asks.
test "duplicate parameter and field names" {
  let ctx = ctx_with([])
  let d = @diagnostic.collector()
  let ft : @ast.FuncType = {
    params: [
      { desc: (Some(id("x", at=1)), I32), info: loc_at(1, 2) },
      { desc: (Some(id("y", at=4)), I32), info: loc_at(4, 5) },
      { desc: (Some(id("x", at=7)), I32), info: loc_at(7, 8) },
    ],
    results: [],
  }
  let _ = @typing.n_functype(ctx, d, ft)
  inspect(d.collected().length(), content="1")
  let e = d.collected()[0]
  inspect(
    @message.to_plain_string(e.message),
    content="Several parameters have the same name 'x'.",
  )
  // At the second `x`, not the first.
  inspect(e.loc.start.cnum, content="7")
  inspect(
    e.related.map(r => r.loc.start.cnum.to_string()).join(","),
    content="1",
  )
  inspect(
    @message.to_plain_string(e.related[0].message),
    content="other parameter here",
  )

  // The same for struct fields.
  let d2 = @diagnostic.collector()
  let field = (n : String, at : Int) => {
    (
      {
        desc: (
          id(n, at~),
          (
            { mut_: false, typ: Value(I32) } :
            @wasm_types.MutType[@wasm_types.StorageType[@ast.Ident]]),
        ),
        info: loc_at(at, at + 1),
      } :
      @basic.Annotated[
        (@ast.Ident, @wasm_types.MutType[@wasm_types.StorageType[@ast.Ident]]),
        @basic.Location,
      ])
  }
  let _ = @typing.comptype(ctx, d2, Struct([field("a", 1), field("a", 5)]))
  inspect(
    @message.to_plain_string(d2.collected()[0].message),
    content="Several fields have the same name 'a'.",
  )
  inspect(d2.collected()[0].loc.start.cnum, content="5")
}

///|
/// One unresolvable component makes the whole type unresolvable, so the caller
/// drops that declaration rather than building a half-resolved one.
test "a bad component fails the whole type" {
  let ctx = ctx_with(["node"])
  let d = @diagnostic.collector()
  let good : @ast.FuncType = {
    params: [{ desc: (None, I32), info: loc_at(0, 1) }],
    results: [Ref({ nullable: true, typ: Type(id("node")) })],
  }
  inspect(@typing.n_functype(ctx, d, good) is Some(_), content="true")
  let bad : @ast.FuncType = {
    params: [{ desc: (None, I32), info: loc_at(0, 1) }],
    results: [Ref({ nullable: true, typ: Type(id("missing")) })],
  }
  inspect(@typing.n_functype(ctx, d, bad) is Some(_), content="false")
}

///|
/// `subtype` is not a predicate. When the two sides are compatible it UNIFIES
/// their cells, and that is the whole mechanism by which a literal acquires a
/// width -- so the interesting assertion is always what the cell holds
/// afterwards, not what the call returned.
test "checking a literal against a type pins it" {
  let info = @type_store.TypeStore::new().subtyping_info()
  fn pin(from : @infer.InferredType, to : @infer.InferredValType) -> String {
    let cell = @infer.Cell::make(from)
    let expected = @infer.valtype_cell(to)
    let ok = @typing.subtype(info, cell, expected)
    if !ok {
      "rejected"
    } else {
      @infer.to_string(cell)
    }
  }

  // A bare number takes whichever of the four it is checked against.
  inspect(pin(Number, @infer.i32_valtype), content="i32")
  inspect(pin(Number, @infer.i64_valtype), content="i64")
  inspect(pin(Number, @infer.f64_valtype), content="f64")
  // An integer literal is not a float.
  inspect(pin(Int, @infer.i64_valtype), content="i64")
  inspect(pin(Int, @infer.f32_valtype), content="rejected")
  // A float literal is not an integer.
  inspect(pin(Float, @infer.f32_valtype), content="f32")
  inspect(pin(Float, @infer.i32_valtype), content="rejected")
  // A literal too big for i32 is never i32, and takes i64, f32 or f64.
  inspect(pin(LargeInt, @infer.i64_valtype), content="i64")
  inspect(pin(LargeInt, @infer.f64_valtype), content="f64")
  inspect(pin(LargeInt, @infer.i32_valtype), content="rejected")
}

///|
/// The three "no concrete type" cases are not interchangeable, and this is the
/// difference.
test "unknown, error and the bottom reference" {
  let info = @type_store.TypeStore::new().subtyping_info()
  fn check_pinning(
    from : @infer.InferredType,
    to : @infer.InferredValType,
    pin : Bool,
  ) -> String {
    let cell = @infer.Cell::make(from)
    let ok = @typing.subtype(info, cell, @infer.valtype_cell(to), pin~)
    if !ok {
      "rejected"
    } else {
      @infer.to_string(cell)
    }
  }

  fn check(from : @infer.InferredType, to : @infer.InferredValType) -> String {
    check_pinning(from, to, true)
  }

  let anyref : @infer.InferredValType = {
    typ: Ref({ nullable: true, typ: Any }),
    internal: Ref({ nullable: true, typ: Any }),
    anon_comptype: None,
  }
  // A genuinely polymorphic value takes whatever consumes it -- and IS pinned,
  // because the lowering can only emit `unreachable` for a value with no type.
  inspect(check(Unknown, @infer.i32_valtype), content="i32")
  inspect(check(Unknown, anyref), content="&?any")
  // Under `pin: false` it stays polymorphic. That is what a br_table needs: its
  // one value is checked against several targets of different types, and
  // pinning it to the first would reject the rest.
  inspect(check_pinning(Unknown, @infer.i32_valtype, false), content="any")
  // An error has already been reported, so it is accepted silently and is NOT
  // pinned -- it keeps the unresolved state rather than acquiring a type it
  // never had. It renders as `any`, like Unknown, which is deliberate: a
  // cascade should not shout.
  let err = @infer.Cell::make(@infer.InferredType::Error)
  inspect(
    @typing.subtype(info, err, @infer.valtype_cell(@infer.i32_valtype)),
    content="true",
  )
  inspect(@infer.is_unknown_or_error(err), content="true")
  // Whereas Unknown, being pinned, is resolved afterwards.
  let unk = @infer.Cell::make(@infer.InferredType::Unknown)
  let _ = @typing.subtype(info, unk, @infer.valtype_cell(@infer.i32_valtype))
  inspect(@infer.is_unknown_or_error(unk), content="false")
  // The bottom reference is a subtype of every reference and of nothing else.
  inspect(check(UnknownRef, anyref), content="&?any")
  inspect(check(UnknownRef, @infer.i32_valtype), content="rejected")
}

///|
/// Null is a subtype of a NULLABLE reference and of nothing else -- which is
/// the whole point of tracking nullability in the type rather than at runtime.
test "null" {
  let info = @type_store.TypeStore::new().subtyping_info()
  fn nullable(n : Bool) -> @infer.InferredValType {
    {
      typ: Ref({ nullable: n, typ: Any }),
      internal: Ref({ nullable: n, typ: Any }),
      anon_comptype: None,
    }
  }

  fn check(to : @infer.InferredValType) -> Bool {
    @typing.subtype(info, @infer.Cell::make(Null), @infer.valtype_cell(to))
  }

  inspect(check(nullable(true)), content="true")
  inspect(check(nullable(false)), content="false")
  inspect(check(@infer.i32_valtype), content="false")
}

///|
/// A mutable field is invariant, because it is both read and written. Getting
/// this backwards is how a type system lets a caller store the wrong thing
/// through a widened reference.
test "field subtyping is invariant when mutable" {
  let info = @type_store.TypeStore::new().subtyping_info()
  fn field(
    mut_ : Bool,
    t : @wasm_types.ValType[@type_store.Id],
  ) -> @wasm_types.FieldType[@type_store.Id] {
    { mut_, typ: Value(t) }
  }

  let any : @wasm_types.ValType[@type_store.Id] = Ref({
    nullable: true,
    typ: Any,
  })
  let eq : @wasm_types.ValType[@type_store.Id] = Ref({ nullable: true, typ: Eq })
  // Immutable: covariant, so a narrower field is a subtype of a wider one.
  inspect(
    @typing.field_subtype(info, field(false, eq), field(false, any)),
    content="true",
  )
  inspect(
    @typing.field_subtype(info, field(false, any), field(false, eq)),
    content="false",
  )
  // Mutable: invariant, so neither direction holds unless they are equal.
  inspect(
    @typing.field_subtype(info, field(true, eq), field(true, any)),
    content="false",
  )
  inspect(
    @typing.field_subtype(info, field(true, eq), field(true, eq)),
    content="true",
  )
  // Mutability itself has to match.
  inspect(
    @typing.field_subtype(info, field(true, eq), field(false, eq)),
    content="false",
  )
}

///|
/// A packed type is a subtype of itself alone: the two widths are different,
/// and neither is a value type.
test "packed storage types" {
  let info = @type_store.TypeStore::new().subtyping_info()
  let i8 : @wasm_types.StorageType[@type_store.Id] = Packed(I8)
  let i16 : @wasm_types.StorageType[@type_store.Id] = Packed(I16)
  let i32 : @wasm_types.StorageType[@type_store.Id] = Value(I32)
  inspect(@typing.storage_subtype(info, i8, i8), content="true")
  inspect(@typing.storage_subtype(info, i8, i16), content="false")
  inspect(@typing.storage_subtype(info, i16, i8), content="false")
  inspect(@typing.storage_subtype(info, i8, i32), content="false")
  inspect(@typing.storage_subtype(info, i32, i8), content="false")
  inspect(@typing.storage_subtype(info, i32, i32), content="true")
}
