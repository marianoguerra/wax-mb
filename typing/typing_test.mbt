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
