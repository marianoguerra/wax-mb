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
) -> @typing_env.TypeContext raise {
  let store = @type_store.TypeStore::new()
  let diagnostics = @diagnostic.collector()
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
        descriptor: None,
        describes: None,
        typ: Func({
          params: Array::makei(i, _ => @wasm_types.ValType::I32),
          results: [],
        }),
      },
    ]
    let idx = store.add_rectype(group)
    tbl.add(diagnostics, n, loc_at(0, 1), (Def(idx), empty))
  }
  @typing_env.TypeContext::new(store, tbl, features)
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

///|
/// The stack has three ways of not having a value, and keeping them apart is
/// what stops one mistake becoming a page of them.
test "the operand stack's three empty states" {
  let info = @type_store.TypeStore::new().subtyping_info()
  fn describe(st : @typing.Stack) -> String {
    match st {
      Unreachable => "unreachable"
      Empty => "empty"
      Poisoned => "poisoned"
      Cons(_, _, _) => "values"
    }
  }

  // Popping from dead code consumes nothing and complains about nothing.
  let dead = @typing.Operands::new()
  dead.set_unreachable()
  let d = @diagnostic.collector()
  dead.pop(
    info,
    d,
    Input,
    loc_at(0, 1),
    0,
    1,
    @infer.valtype_cell(@infer.i32_valtype),
  )
  inspect(describe(dead.stack), content="unreachable")
  inspect(d.collected().length(), content="0")

  // Popping from an empty stack IS an underflow, and reports -- once. The
  // stack is poisoned so the next pop stays quiet rather than repeating it.
  let empty = @typing.Operands::new()
  let d2 = @diagnostic.collector()
  empty.pop(
    info,
    d2,
    Input,
    loc_at(4, 9),
    0,
    2,
    @infer.valtype_cell(@infer.i32_valtype),
  )
  inspect(describe(empty.stack), content="poisoned")
  inspect(d2.collected().length(), content="1")
  empty.pop(
    info,
    d2,
    Input,
    loc_at(4, 9),
    1,
    2,
    @infer.valtype_cell(@infer.i32_valtype),
  )
  inspect(d2.collected().length(), content="1")
  inspect(
    @message.to_plain_string(d2.collected()[0].message),
    content="Expecting 2 argument(s) from the stack, but there are 1.",
  )
}

///|
/// Where the caret goes says which value is missing: before the instruction for
/// an argument, after it for a result.
test "an underflow points where the value should have been" {
  let info = @type_store.TypeStore::new().subtyping_info()
  fn caret(kind : @typing.StackKind) -> String {
    let ops = @typing.Operands::new()
    let d = @diagnostic.collector()
    ops.pop(
      info,
      d,
      kind,
      loc_at(10, 20),
      0,
      1,
      @infer.valtype_cell(@infer.i32_valtype),
    )
    let l = d.collected()[0].loc
    "\{l.start.cnum}..\{l.end.cnum}"
  }

  inspect(caret(Input), content="10..10")
  inspect(caret(Output), content="20..20")
  inspect(caret(Holes), content="10..20")
}

///|
/// Pushing an error poisons rather than stacking it, because the failed
/// producer's true arity is unknown -- a call that did not resolve may have
/// produced any number of values, so later consumers must absorb any count
/// silently.
test "an error value poisons the stack" {
  let ops = @typing.Operands::new()
  ops.push(None, @infer.valtype_cell(@infer.i32_valtype))
  inspect(ops.stack is Cons(_, _, _), content="true")
  ops.push(None, @infer.Cell::make(@infer.InferredType::Error))
  inspect(ops.stack is Poisoned, content="true")
  // Dead code stays dead rather than becoming merely poisoned.
  let dead = @typing.Operands::new()
  dead.set_unreachable()
  dead.push(None, @infer.Cell::make(@infer.InferredType::Error))
  inspect(dead.stack is Unreachable, content="true")
}

///|
/// A poison value on top is LEFT there rather than consumed. Consuming it would
/// strip the poison and let a cascade surface: the genuine value beneath would
/// read as a bogus leftover.
test "popping a poison value does not consume it" {
  let info = @type_store.TypeStore::new().subtyping_info()
  let ops = @typing.Operands::new()
  // A genuine value, with a second above it that later BECOMES an error --
  // which is how this state actually arises, since cells are shared and a
  // failed check downstream can poison one already on the stack. `push` itself
  // never stacks an error.
  ops.push(None, @infer.valtype_cell(@infer.i32_valtype))
  let top = @infer.Cell::make(@infer.InferredType::Unknown)
  ops.push(None, top)
  top.set(Error)
  let d = @diagnostic.collector()
  ops.pop(
    info,
    d,
    Input,
    loc_at(0, 1),
    0,
    1,
    @infer.valtype_cell(@infer.i32_valtype),
  )
  // Nothing consumed, nothing said.
  inspect(ops.stack is Cons(_, _, _), content="true")
  inspect(d.collected().length(), content="0")
  let (locs, has_error) = @typing.leftovers(ops.stack)
  inspect(has_error, content="true")
  inspect(locs.length(), content="0")
}

///|
/// Arguments come off rightmost first, because that is the order they went on.
test "arguments are popped in reverse" {
  let info = @type_store.TypeStore::new().subtyping_info()
  let ops = @typing.Operands::new()
  // f(i32, i64): the i32 was pushed first, so the i64 is on top.
  ops.push(None, @infer.valtype_cell(@infer.i32_valtype))
  ops.push(None, @infer.valtype_cell(@infer.i64_valtype))
  let d = @diagnostic.collector()
  ops.pop_args(info, d, Input, loc_at(0, 1), [
    @infer.valtype_cell(@infer.i32_valtype),
    @infer.valtype_cell(@infer.i64_valtype),
  ])
  inspect(ops.stack is Empty, content="true")
  inspect(d.collected().length(), content="0")

  // With the arguments the wrong way round, both mismatch.
  let ops2 = @typing.Operands::new()
  ops2.push(None, @infer.valtype_cell(@infer.i32_valtype))
  ops2.push(None, @infer.valtype_cell(@infer.i64_valtype))
  let d2 = @diagnostic.collector()
  ops2.pop_args(info, d2, Input, loc_at(0, 1), [
    @infer.valtype_cell(@infer.i64_valtype),
    @infer.valtype_cell(@infer.i32_valtype),
  ])
  inspect(d2.collected().length(), content="2")
  inspect(
    @message.to_plain_string(d2.collected()[0].message),
    // The reference quotes a type in the uncoloured rendering, which is where
    // oracle 3 compares it.
    content="Argument 1 should have type 'i32' but has type 'i64'.",
  )
}

///|
/// Results carry a location only when there is exactly one of them: with
/// several, no single value is "the" thing at that span.
test "results carry a location only when unambiguous" {
  let ops = @typing.Operands::new()
  ops.push_results(loc_at(3, 4), [@infer.valtype_cell(@infer.i32_valtype)])
  guard! ops.stack is Cons(at, _, _)
  inspect(at is Some(_), content="true")
  let ops2 = @typing.Operands::new()
  ops2.push_results(loc_at(3, 4), [
    @infer.valtype_cell(@infer.i32_valtype),
    @infer.valtype_cell(@infer.i64_valtype),
  ])
  guard! ops2.stack is Cons(at2, _, _)
  inspect(at2 is None, content="true")
}

///|
/// A block is checked on its own stack, and a snapshot really is a snapshot --
/// which is what keeps its operands from leaking in or out.
test "an inner stack does not leak" {
  let ops = @typing.Operands::new()
  ops.push(None, @infer.valtype_cell(@infer.i32_valtype))
  let (_, inner) = ops.with_empty(() => {
    ops.push(None, @infer.valtype_cell(@infer.i64_valtype))
    ops.push(None, @infer.valtype_cell(@infer.i64_valtype))
  })
  // The outer stack is as it was.
  guard! ops.stack is Cons(_, _, rest)
  inspect(rest is Empty, content="true")
  // And the inner one is available to be checked for leftovers.
  let (_, has_error) = @typing.leftovers(inner)
  inspect(has_error, content="false")
  inspect(inner is Cons(_, _, _), content="true")
}

///|
/// A lub that only handles two identical types, which is enough for every join
/// case the flexible-literal lattice decides on its own.
fn no_lub(
  a : @infer.InferredValType,
  b : @infer.InferredValType,
) -> @infer.InferredValType? {
  if a == b {
    Some(a)
  } else {
    None
  }
}

///|
/// The join is the other half of inference. `subtype` pins a literal against a
/// type it is CHECKED against; this pins one against the types it is joined
/// WITH -- and both mutate, so the assertion is again about the cells
/// afterwards.
test "joining flexible literals pins them" {
  fn join(a : @infer.InferredType, b : @infer.InferredType) -> String {
    let c1 = @infer.Cell::make(a)
    let c2 = @infer.Cell::make(b)
    match @typing.join_value_types(c1, c2, no_lub) {
      None => "no common type"
      Some(r) => @infer.to_string(r)
    }
  }

  let i32 : @infer.InferredType = Valtype(@infer.i32_valtype)
  let i64 : @infer.InferredType = Valtype(@infer.i64_valtype)
  let f64 : @infer.InferredType = Valtype(@infer.f64_valtype)
  // A bare number takes whatever it meets.
  inspect(join(Number, i32), content="i32")
  inspect(join(i32, Number), content="i32")
  inspect(join(Number, Number), content="number")
  // An integer literal and a float have nothing in common.
  inspect(join(Int, f64), content="no common type")
  inspect(join(Float, i32), content="no common type")
  // Two identical concrete types join to themselves.
  inspect(join(i32, i32), content="i32")
  inspect(join(i32, i64), content="no common type")
}

///|
/// A literal too big for i32 defaults to i64 and can also be a float. Joined
/// with a COMMITTED integer, their sole common type is i64 -- so the join pins
/// it there, or the result could later be coerced to a float the integer
/// cannot be.
test "a large literal joined with a committed integer pins to i64" {
  let big = @infer.Cell::make(@infer.InferredType::LargeInt)
  let int_ = @infer.Cell::make(@infer.InferredType::Int)
  guard! @typing.join_value_types(big, int_, no_lub) is Some(r)
  inspect(@infer.to_string(r), content="i64")
  // Both cells were merged, so the commitment is visible from either.
  inspect(@infer.to_string(big), content="i64")
  inspect(@infer.to_string(int_), content="i64")
  // Joined with a fully flexible number it stays large rather than committing.
  let big2 = @infer.Cell::make(@infer.InferredType::LargeInt)
  let num = @infer.Cell::make(@infer.InferredType::Number)
  guard! @typing.join_value_types(big2, num, no_lub) is Some(r2)
  inspect(@infer.to_string(r2), content="large number")
  // And never with i32.
  let big3 = @infer.Cell::make(@infer.InferredType::LargeInt)
  let i32c = @infer.valtype_cell(@infer.i32_valtype)
  inspect(@typing.join_value_types(big3, i32c, no_lub) is None, content="true")
}

///|
/// The three bottoms behave differently here too. `Unknown` is pinned to what
/// it meets -- a hole on the dead-code stack genuinely takes the block's result
/// type -- while `Error` stays untouched, because pinning it would invent a
/// type it never had.
test "the bottoms in a join" {
  let unknown = @infer.Cell::make(@infer.InferredType::Unknown)
  let i32 = @infer.valtype_cell(@infer.i32_valtype)
  guard! @typing.join_value_types(unknown, i32, no_lub) is Some(r)
  inspect(@infer.to_string(r), content="i32")
  // Pinned, so a branch that also passes it through sees the resolved width.
  inspect(@infer.is_unknown_or_error(unknown), content="false")

  // An error is accepted and left alone.
  let err = @infer.Cell::make(@infer.InferredType::Error)
  let i32b = @infer.valtype_cell(@infer.i32_valtype)
  guard! @typing.join_value_types(err, i32b, no_lub) is Some(r2)
  inspect(@infer.to_string(r2), content="i32")
  inspect(@infer.is_unknown_or_error(err), content="true")

  // Two bottom references merge, so pinning one later pins the other.
  let a = @infer.Cell::make(@infer.InferredType::UnknownRef)
  let b = @infer.Cell::make(@infer.InferredType::UnknownRef)
  let _ = @typing.join_value_types(a, b, no_lub)
  let anyref : @infer.InferredValType = {
    typ: Ref({ nullable: true, typ: Any }),
    internal: Ref({ nullable: true, typ: Any }),
    anon_comptype: None,
  }
  let info = @type_store.TypeStore::new().subtyping_info()
  let _ = @typing.subtype(info, a, @infer.valtype_cell(anyref))
  inspect(@infer.to_string(b), content="&?any")

  // A bottom reference and a non-reference have no common type.
  let r3 = @infer.Cell::make(@infer.InferredType::UnknownRef)
  inspect(
    @typing.join_value_types(
      r3,
      @infer.valtype_cell(@infer.i32_valtype),
      no_lub,
    )
    is None,
    content="true",
  )
}

///|
/// An underflow is reported at the HOLE that ends up consuming it, because the
/// pop that noticed it does not know how the missing values are distributed.
/// And once, however many holes consume the batch.
test "an underflow is reported at the hole" {
  let ops = @typing.Operands::new()
  // Two values wanted, none available.
  let (cells, batch) = ops.pop_many(2)
  inspect(cells.length(), content="2")
  inspect(batch is Some(_), content="true")
  // Nothing said yet: the pop records placeholders and stays quiet.
  let d = @diagnostic.collector()
  inspect(d.collected().length(), content="0")
  // The hole that consumes the first placeholder reports, at its own location.
  @typing.report_missing_hole(ops, d, loc_at(40, 41), cells[0])
  inspect(d.collected().length(), content="1")
  inspect(d.collected()[0].loc.start.cnum, content="40")
  inspect(
    @message.to_plain_string(d.collected()[0].message),
    // Nothing was on the stack at all, so 0 -- `pop_many` counts up from the
    // first missing value, where `pop_args` counts down from the last.
    content="Expecting 2 value(s) from the stack, but there are 0.",
  )
  // The second hole of the same batch says nothing more.
  @typing.report_missing_hole(ops, d, loc_at(50, 51), cells[1])
  inspect(d.collected().length(), content="1")
  // A cell that was never a placeholder is not one now.
  @typing.report_missing_hole(
    ops,
    d,
    loc_at(60, 61),
    @infer.Cell::make(Unknown),
  )
  inspect(d.collected().length(), content="1")
}

///|
/// What is left on the stack when a scope ends, and when saying so would be a
/// cascade rather than a finding.
test "leftover values" {
  fn report(build : (@typing.Operands) -> Unit) -> String {
    let ops = @typing.Operands::new()
    let (_, inner) = ops.with_empty(() => build(ops))
    let d = @diagnostic.collector()
    @typing.report_leftovers(inner, d, loc_at(0, 20), @typing.render_stack)
    d
    .collected()
    .map(e => {
      let rel = e.related.map(r => r.loc.start.cnum.to_string()).join(",")
      "\{e.loc.start.cnum}: \{@message.to_plain_string(e.message)}" +
      (if rel == "" { "" } else { " (also \{rel})" })
    })
    .join("\n")
  }

  // Nothing left: nothing to say.
  inspect(report(_ => ()), content="")
  // One locatable value: a caret on it, and the singular.
  inspect(
    report(ops => {
      ops.push(Some(loc_at(5, 6)), @infer.valtype_cell(@infer.i32_valtype))
    }),
    content="5: This value remains on the stack.",
  )
  // Several: the topmost carries the caret, the rest are related labels, and
  // the message goes plural.
  inspect(
    report(ops => {
      ops.push(Some(loc_at(5, 6)), @infer.valtype_cell(@infer.i32_valtype))
      ops.push(Some(loc_at(9, 10)), @infer.valtype_cell(@infer.i64_valtype))
    }),
    content="5: These values remain on the stack. (also 9)",
  )
  // Values with no usable location are still real values -- name the construct
  // and list what is there, rather than saying nothing.
  inspect(
    report(ops => ops.push(None, @infer.valtype_cell(@infer.i32_valtype))),
    content="20: Some values remain on the stack: i32.",
  )
}

///|
/// The poison rules from the stack pay off here. A leftover of type `Error`
/// means something has already been reported, so the stack is unreliable and
/// complaining about it would be a cascade.
test "an already-reported error suppresses the leftover report" {
  let ops = @typing.Operands::new()
  let (_, inner) = ops.with_empty(() => {
    ops.push(Some(loc_at(5, 6)), @infer.valtype_cell(@infer.i32_valtype))
    // A second value that a later check poisons -- which is how this arises,
    // since `push` never stacks an error directly.
    let cell = @infer.Cell::make(@infer.InferredType::Unknown)
    ops.push(Some(loc_at(9, 10)), cell)
    cell.set(Error)
  })
  let d = @diagnostic.collector()
  @typing.report_leftovers(inner, d, loc_at(0, 20), @typing.render_stack)
  inspect(d.collected().length(), content="0")
}

///|
/// Dead code and a poisoned stack are both "nothing genuine left".
test "unreachable and poisoned scopes report nothing" {
  for
    build in [
      (ops : @typing.Operands) => ops.set_unreachable(),
      (ops : @typing.Operands) => {
        // An underflow poisons.
        let d = @diagnostic.collector()
        let info = @type_store.TypeStore::new().subtyping_info()
        ops.pop(
          info,
          d,
          Input,
          loc_at(0, 1),
          0,
          1,
          @infer.valtype_cell(@infer.i32_valtype),
        )
      },
    ] {
    let ops = @typing.Operands::new()
    let (_, inner) = ops.with_empty(() => build(ops))
    let d = @diagnostic.collector()
    @typing.report_leftovers(inner, d, loc_at(0, 20), @typing.render_stack)
    inspect(d.collected().length(), content="0")
  }
}

///|
/// A literal's spelling says only what it CANNOT be. This is the first thing in
/// the checker that produces an annotation, and it produces the least committed
/// one available -- everything else is decided by how the literal is used.
test "the literal lattice" {
  fn int_(s : String) -> String {
    @infer.to_string(@infer.Cell::make(@typing.int_literal_lattice(s)))
  }

  fn float_(s : String) -> String {
    @infer.to_string(@infer.Cell::make(@typing.float_literal_lattice(s)))
  }

  // An ordinary integer commits to nothing: it could be any of the four.
  inspect(int_("0"), content="number")
  inspect(int_("1"), content="number")
  inspect(int_("4294967295"), content="number")
  inspect(int_("0xffffffff"), content="number")
  // Past the 32-bit range it cannot be i32, so it defaults to i64 rather than
  // to i32 -- which is the whole difference between LargeInt and Number.
  inspect(int_("4294967296"), content="large number")
  inspect(int_("18446744073709551615"), content="large number")
  // Too big for u64 it cannot be any integer at all, so it falls to the float
  // lattice -- which makes an integer use a clean type error rather than an
  // overflow in the encoder. It is still FLEXIBLE, because 2^64 sits well
  // inside an f32; only a magnitude f32 cannot hold pins to f64.
  inspect(int_("18446744073709551616"), content="float")
  inspect(int_("1000000000000000000000000"), content="float")
  inspect(int_("1" + "0".repeat(40)), content="f64")

  // A float that fits an f32 stays flexible; its use picks the width.
  inspect(float_("1.0"), content="float")
  inspect(float_("0.5"), content="float")
  inspect(float_("3.4e38"), content="float")
  // One that does not fit is pinned to f64 at once, because there is no choice
  // left: f32 would overflow it to infinity.
  inspect(float_("3.5e38"), content="f64")
  inspect(float_("1e300"), content="f64")
  // inf and nan are spelled, not overflowed, so they remain flexible.
  inspect(float_("inf"), content="float")
  inspect(float_("nan"), content="float")
}

///|
/// The lattice and the two inference steps compose: a literal's spelling rules
/// widths out, and its use picks among what is left.
test "a literal's spelling and its use decide together" {
  let info = @type_store.TypeStore::new().subtyping_info()
  fn used_as(literal : String, as_ : @infer.InferredValType) -> String {
    let cell = @infer.Cell::make(@typing.int_literal_lattice(literal))
    if @typing.subtype(info, cell, @infer.valtype_cell(as_)) {
      @infer.to_string(cell)
    } else {
      "rejected"
    }
  }

  // A small literal takes whichever width its use wants.
  inspect(used_as("1", @infer.i32_valtype), content="i32")
  inspect(used_as("1", @infer.i64_valtype), content="i64")
  inspect(used_as("1", @infer.f64_valtype), content="f64")
  // A large one refuses i32 however it is used, and takes the rest.
  inspect(used_as("4294967296", @infer.i32_valtype), content="rejected")
  inspect(used_as("4294967296", @infer.i64_valtype), content="i64")
  inspect(used_as("4294967296", @infer.f64_valtype), content="f64")
  // One too big for any integer refuses both integer widths.
  inspect(
    used_as("18446744073709551616", @infer.i64_valtype),
    content="rejected",
  )
  inspect(used_as("18446744073709551616", @infer.f64_valtype), content="f64")
}

///|
fn module_ctx() -> @typing_env.ModuleContext {
  @typing_env.ModuleContext::new(
    @diagnostic.collector(),
    @type_store.TypeStore::new(),
    @feature.default(),
  )
}

///|
/// A real canonical index, which -- `Id` being opaque -- can only come from a
/// store.
fn some_id() -> @type_store.Id raise {
  @type_store.TypeStore::new().add_rectype([
    {
      final_: true,
      supertype: None,
      descriptor: None,
      describes: None,
      typ: Func({ params: [], results: [] }),
    },
  ])
}

///|
/// A bare name resolves in the language's order, and a local shadows
/// everything. Globals, functions, memories and tables share one namespace, so
/// a local is the only thing that can collide with them.
test "a local shadows everything" {
  let ctx = module_ctx()
  ctx.globals.add(ctx.diagnostics, "x", loc_at(0, 1), (false, None))
  ctx.functions.add(
    ctx.diagnostics,
    "f",
    loc_at(2, 3),
    Some((some_id(), "t", false)),
  )
  ctx.memories.add(ctx.diagnostics, "m", loc_at(4, 5), (0, I32))
  ctx.tables.add(
    ctx.diagnostics,
    "t",
    loc_at(6, 7),
    (I32, { nullable: true, typ: Func }),
  )
  ctx.datas.add(ctx.diagnostics, "d", loc_at(8, 9), ())
  fn kind(n : String) -> String {
    match @typing.resolve_variable(ctx, { name: n, loc: loc_at(20, 21) }) {
      Local(_, _) => "local"
      Global(_, _) => "global"
      FuncRef(_, _, _) => "func"
      Poisoned => "poisoned"
      Unbound => "unbound"
    }
  }

  inspect(kind("x"), content="global")
  inspect(kind("f"), content="func")
  inspect(kind("nope"), content="unbound")
  inspect(
    @typing.memory_receiver(ctx, { name: "m", loc: loc_at(0, 1) }),
    content="true",
  )
  inspect(
    @typing.table_receiver(ctx, { name: "t", loc: loc_at(0, 1) }),
    content="true",
  )
  inspect(
    @typing.segment_receiver(ctx, { name: "d", loc: loc_at(0, 1) }),
    content="true",
  )

  // Now shadow each of them with a local.
  ctx.locals["x"] = (None, loc_at(30, 31))
  ctx.locals["m"] = (None, loc_at(30, 31))
  ctx.locals["t"] = (None, loc_at(30, 31))
  ctx.locals["d"] = (None, loc_at(30, 31))
  inspect(kind("x"), content="local")
  inspect(
    @typing.memory_receiver(ctx, { name: "m", loc: loc_at(0, 1) }),
    content="false",
  )
  inspect(
    @typing.table_receiver(ctx, { name: "t", loc: loc_at(0, 1) }),
    content="false",
  )
  inspect(
    @typing.segment_receiver(ctx, { name: "d", loc: loc_at(0, 1) }),
    content="false",
  )
}

///|
/// A function whose signature failed to resolve stays BOUND, so its uses read
/// as poison rather than cascading into unbound-name reports.
test "a poisoned function is bound, not unbound" {
  let ctx = module_ctx()
  ctx.functions.add(ctx.diagnostics, "broken", loc_at(0, 1), None)
  match @typing.resolve_variable(ctx, { name: "broken", loc: loc_at(5, 6) }) {
    Poisoned => inspect("poisoned", content="poisoned")
    Unbound => fail("a poisoned function must not read as unbound")
    _ => fail("unexpected")
  }
}

///|
/// Only a non-nullable reference lacks a zero value, which is the entire reason
/// initialization is tracked.
test "what needs initializing" {
  inspect(@typing.is_defaultable(I32), content="true")
  inspect(@typing.is_defaultable(V128), content="true")
  inspect(
    @typing.is_defaultable(Ref({ nullable: true, typ: Any })),
    content="true",
  )
  inspect(
    @typing.is_defaultable(Ref({ nullable: false, typ: Any })),
    content="false",
  )
}

///|
/// An operand written before the values it follows but EMITTED after them sees
/// a state that is a subset of the true one. Three consequences, and each is
/// what makes the analysis sound rather than merely plausible.
test "a trailing operand defers what it cannot yet know" {
  // A read that fails now but would succeed later is DEFERRED, not reported --
  // and the replay finds it initialized by then.
  let ctx = module_ctx()
  let x : @ast.Ident = { name: "x", loc: loc_at(10, 11) }
  let (_, replay) = @typing.type_trailing_operand(ctx, () => {
    @typing.report_uninitialized(ctx, x)
  })
  inspect(ctx.diagnostics.collected().length(), content="0")
  // An earlier operand initializes it before the trailing one's real slot.
  @typing.mark_initialized(ctx, "x")
  replay()
  inspect(ctx.diagnostics.collected().length(), content="0")

  // A read that is still uninitialized at the slot IS reported, then.
  let ctx2 = module_ctx()
  let (_, replay2) = @typing.type_trailing_operand(ctx2, () => {
    @typing.report_uninitialized(ctx2, x)
  })
  inspect(ctx2.diagnostics.collected().length(), content="0")
  replay2()
  inspect(ctx2.diagnostics.collected().length(), content="1")
  inspect(
    @message.to_plain_string(ctx2.diagnostics.collected()[0].message),
    content="The local variable 'x' has not been initialized.",
  )
}

///|
/// The operand's own writes are WITHHELD until its real slot, because an
/// earlier operand runs first and must not see them.
test "a trailing operand's writes are withheld" {
  let ctx = module_ctx()
  let (_, replay) = @typing.type_trailing_operand(ctx, () => {
    @typing.mark_initialized(ctx, "y")
  })
  // Not visible yet: an earlier operand would run before this one.
  inspect(ctx.initialized_locals.contains("y"), content="false")
  replay()
  // Applied at the emission slot.
  inspect(ctx.initialized_locals.contains("y"), content="true")
}

///|
/// A re-check that still fails under an OUTER deferral re-defers rather than
/// reporting, because the outer operand has its own slot still to come.
test "deferrals nest" {
  let ctx = module_ctx()
  let x : @ast.Ident = { name: "x", loc: loc_at(10, 11) }
  let (_, outer_replay) = @typing.type_trailing_operand(ctx, () => {
    let (_, inner_replay) = @typing.type_trailing_operand(ctx, () => {
      @typing.report_uninitialized(ctx, x)
    })
    // The inner operand's own emission slot, which is still inside the outer
    // operand's check -- so the outer deferral is open and the read is
    // RE-deferred rather than reported.
    inner_replay()
  })
  inspect(ctx.diagnostics.collected().length(), content="0")
  // Only when the outer slot arrives does it surface.
  outer_replay()
  inspect(ctx.diagnostics.collected().length(), content="1")
}

///|
/// Reading a bare name. Every failure recovers as an error value rather than
/// stopping -- and each does so for a different reason, which is the point:
/// one mistake should produce one diagnostic.
test "reading a name" {
  let ctx = module_ctx()
  ctx.locals["x"] = (Some(@infer.i32_valtype), loc_at(2, 3))
  @typing.mark_initialized(ctx, "x")
  ctx.globals.add(
    ctx.diagnostics,
    "g",
    loc_at(4, 5),
    (false, Some(@infer.f64_valtype)),
  )
  // A poison local: its initializer failed, and was reported there.
  ctx.locals["bad"] = (None, loc_at(6, 7))
  @typing.mark_initialized(ctx, "bad")
  fn read(n : String) -> String {
    @infer.to_string(@typing.type_get(ctx, { name: n, loc: loc_at(20, 21) }))
  }

  inspect(read("x"), content="i32")
  inspect(read("g"), content="f64")
  // A poison local reads as an error, silently.
  inspect(read("bad"), content="any")
  inspect(ctx.diagnostics.collected().length(), content="0")
  // An unbound name reports once, and recovers.
  inspect(read("nope"), content="any")
  inspect(ctx.diagnostics.collected().length(), content="1")
  inspect(
    @message.to_plain_string(ctx.diagnostics.collected()[0].message),
    content="The variable 'nope' is not bound.",
  )
}

///|
/// A misspelling gets a suggestion, from everything a bare name could have
/// meant.
test "did you mean" {
  let ctx = module_ctx()
  ctx.locals["counter"] = (Some(@infer.i32_valtype), loc_at(2, 3))
  ctx.globals.add(ctx.diagnostics, "threshold", loc_at(4, 5), (false, None))
  ctx.functions.add(ctx.diagnostics, "compute", loc_at(6, 7), None)
  let _ = @typing.type_get(ctx, { name: "countr", loc: loc_at(20, 21) })
  guard! ctx.diagnostics.collected()[0].hint is Some(h)
  inspect(@message.to_plain_string(h), content="Did you mean 'counter'?")
  // Nothing close enough draws no hint at all.
  let ctx2 = module_ctx()
  ctx2.locals["counter"] = (Some(@infer.i32_valtype), loc_at(2, 3))
  let _ = @typing.type_get(ctx2, { name: "zzzzzz", loc: loc_at(20, 21) })
  inspect(ctx2.diagnostics.collected()[0].hint is None, content="true")
}

///|
/// An assignment can only target a MUTABLE global, so suggesting an immutable
/// one would send the reader somewhere that cannot work.
test "assignment suggestions are narrower than read suggestions" {
  let ctx = module_ctx()
  ctx.globals.add(ctx.diagnostics, "total", loc_at(0, 1), (true, None))
  ctx.globals.add(ctx.diagnostics, "limit", loc_at(2, 3), (false, None))
  ctx.functions.add(ctx.diagnostics, "compute", loc_at(4, 5), None)
  // A read could have meant any of them.
  inspect(@typing.get_suggestions(ctx, "totl").join(","), content="total")
  inspect(@typing.get_suggestions(ctx, "limt").join(","), content="limit")
  inspect(@typing.get_suggestions(ctx, "computa").join(","), content="compute")
  // An assignment could only have meant the mutable one.
  inspect(@typing.set_suggestions(ctx, "totl").join(","), content="total")
  inspect(@typing.set_suggestions(ctx, "limt").join(","), content="")
  inspect(@typing.set_suggestions(ctx, "computa").join(","), content="")
}

///|
/// Reading a local records the BINDING's offset, not the name -- so a
/// shadowing inner local does not mask an outer one as read.
test "reads are recorded by binding, not by name" {
  let ctx = module_ctx()
  ctx.locals["x"] = (Some(@infer.i32_valtype), loc_at(2, 3))
  @typing.mark_initialized(ctx, "x")
  let _ = @typing.type_get(ctx, { name: "x", loc: loc_at(20, 21) })
  inspect(ctx.read_locals.map(o => o.to_string()).join(","), content="2")
  // A shadowing local of the same name is a different binding.
  ctx.locals["x"] = (Some(@infer.i32_valtype), loc_at(9, 10))
  let _ = @typing.type_get(ctx, { name: "x", loc: loc_at(22, 23) })
  inspect(ctx.read_locals.map(o => o.to_string()).join(","), content="2,9")
}

///|
/// Reading an uninitialized local reports, and the type is still delivered so
/// the rest of the expression can be checked.
test "reading before initializing" {
  let ctx = module_ctx()
  ctx.locals["r"] = (
    Some({
      typ: Ref({ nullable: false, typ: Any }),
      internal: Ref({ nullable: false, typ: Any }),
      anon_comptype: None,
    }),
    loc_at(2, 3),
  )
  let cell = @typing.type_get(ctx, { name: "r", loc: loc_at(20, 21) })
  inspect(@infer.to_string(cell), content="&any")
  inspect(
    @message.to_plain_string(ctx.diagnostics.collected()[0].message),
    content="The local variable 'r' has not been initialized.",
  )
  // Once assigned, no complaint.
  let ctx2 = module_ctx()
  ctx2.locals["r"] = (Some(@infer.i32_valtype), loc_at(2, 3))
  @typing.mark_initialized(ctx2, "r")
  let _ = @typing.type_get(ctx2, { name: "r", loc: loc_at(20, 21) })
  inspect(ctx2.diagnostics.collected().length(), content="0")
}

///|
/// What an assignment target turns out to be, and what each kind costs.
test "assignment targets" {
  fn attempt_c(
    setup : (@typing_env.ModuleContext) -> Unit,
    name : String,
    compound : Bool,
  ) -> String {
    let ctx = module_ctx()
    setup(ctx)
    let idx : @ast.Ident = { name, loc: loc_at(20, 21) }
    let resolved = @typing.resolve_variable(ctx, idx)
    @typing.assign_target(ctx, idx, resolved, compound~)
    ctx.diagnostics
    .collected()
    .map(e => @message.to_plain_string(e.message))
    .join(" | ")
  }

  fn attempt(
    setup : (@typing_env.ModuleContext) -> Unit,
    name : String,
  ) -> String {
    attempt_c(setup, name, false)
  }

  // A local: no complaint, and it now holds a value.
  inspect(
    attempt(
      ctx => ctx.locals["x"] = (Some(@infer.i32_valtype), loc_at(0, 1)),
      "x",
    ),
    content="",
  )
  // A mutable global: allowed.
  inspect(
    attempt(
      ctx => ctx.globals.add(ctx.diagnostics, "g", loc_at(0, 1), (true, None)),
      "g",
    ),
    content="",
  )
  // An immutable one: not.
  inspect(
    attempt(
      ctx => ctx.globals.add(ctx.diagnostics, "g", loc_at(0, 1), (false, None)),
      "g",
    ),
    content="This global is immutable and cannot be assigned.",
  )
  // A function is not a variable.
  let real_id = some_id()
  inspect(
    attempt(
      ctx => {
        ctx.functions.add(
          ctx.diagnostics,
          "f",
          loc_at(0, 1),
          Some((real_id, "t", false)),
        )
      },
      "f",
    ),
    content="'f' cannot be assigned.",
  )
  // A function whose signature failed to resolve is POISONED rather than a
  // function reference, and says nothing further -- it was reported at its
  // definition.
  inspect(
    attempt(
      ctx => ctx.functions.add(ctx.diagnostics, "f", loc_at(0, 1), None),
      "f",
    ),
    content="",
  )
  // An unbound name reports, with the assignment-flavoured suggestions.
  inspect(attempt(_ => (), "nope"), content="The variable 'nope' is not bound.")
  // Except under a compound assignment, where the desugared read already said
  // it at this very span.
  inspect(attempt_c(_ => (), "nope", true), content="")
}

///|
/// A mutable global is recorded as assigned only where it is actually written,
/// which is what the unnecessary-mut warning reads.
test "writing a mutable global records it" {
  let ctx = module_ctx()
  ctx.globals.add(ctx.diagnostics, "used", loc_at(0, 1), (true, None))
  ctx.globals.add(ctx.diagnostics, "never", loc_at(2, 3), (true, None))
  let idx : @ast.Ident = { name: "used", loc: loc_at(20, 21) }
  @typing.assign_target(ctx, idx, @typing.resolve_variable(ctx, idx))
  inspect(ctx.assigned_globals.contains("used"), content="true")
  inspect(ctx.assigned_globals.contains("never"), content="false")
}

///|
/// Only a local is tee-able. Everything else recovers with the OPERAND's own
/// type rather than an unknown -- an unknown cannot be checked against
/// anything, and would turn one error into a second one downstream.
test "tee targets" {
  fn tee(setup : (@typing_env.ModuleContext) -> Unit, name : String) -> String {
    let ctx = module_ctx()
    setup(ctx)
    let idx : @ast.Ident = { name, loc: loc_at(20, 21) }
    let operand = @infer.valtype_cell(@infer.f64_valtype)
    let resolved = @typing.resolve_variable(ctx, idx)
    let result = @typing.tee_target(ctx, idx, resolved, operand)
    let msgs = ctx.diagnostics
      .collected()
      .map(e => @message.to_plain_string(e.message))
      .join(" | ")
    "\{@infer.to_string(result)}\{if msgs == "" { "" } else { "  -- " + msgs }}"
  }

  // A local delivers the LOCAL's type, not the operand's.
  inspect(
    tee(ctx => ctx.locals["x"] = (Some(@infer.i32_valtype), loc_at(0, 1)), "x"),
    content="i32",
  )
  // A poison local has no type to deliver, so the operand's stands.
  inspect(
    tee(ctx => ctx.locals["x"] = (None, loc_at(0, 1)), "x"),
    content="f64",
  )
  // A global cannot be tee'd, and recovery keeps the operand's type.
  inspect(
    tee(
      ctx => ctx.globals.add(ctx.diagnostics, "g", loc_at(0, 1), (true, None)),
      "g",
    ),
    content="f64  -- 'g' cannot be assigned.",
  )
  // Unbound: reported, and again the operand's type carries on.
  inspect(
    tee(_ => (), "nope"),
    content="f64  -- The variable 'nope' is not bound.",
  )
}

///|
/// A tee marks the local initialized, so a later read of it is fine.
test "a tee initializes its target" {
  let ctx = module_ctx()
  ctx.locals["x"] = (Some(@infer.i32_valtype), loc_at(0, 1))
  let idx : @ast.Ident = { name: "x", loc: loc_at(20, 21) }
  let _ = @typing.tee_target(
    ctx,
    idx,
    @typing.resolve_variable(ctx, idx),
    @infer.valtype_cell(@infer.i32_valtype),
  )
  let _ = @typing.type_get(ctx, { name: "x", loc: loc_at(30, 31) })
  inspect(ctx.diagnostics.collected().length(), content="0")
}

///|
/// Whether a declared local starts holding a value is decided by its type, and
/// this is the only place that decision is made.
test "a declared local starts initialized only if its type has a zero" {
  fn read_after_declaring(typ : @wasm_types.ValType[@ast.Ident]) -> String {
    let ctx = module_ctx()
    @typing.declare_local(ctx, { name: "x", loc: loc_at(2, 3) }, typ)
    // Reading it immediately is the question the initialization state answers.
    let _ = @typing.type_get(ctx, { name: "x", loc: loc_at(20, 21) })
    let msgs = ctx.diagnostics.collected()
    msgs.map(e => @message.to_plain_string(e.message)).join(" | ")
  }

  // A numeric local has a zero value, so it is readable at once.
  inspect(read_after_declaring(I32), content="")
  inspect(read_after_declaring(F64), content="")
  inspect(read_after_declaring(V128), content="")
  // A NULLABLE reference has null as its zero value.
  inspect(read_after_declaring(Ref({ nullable: true, typ: Any })), content="")
  // A non-nullable one has nothing to start at, so reading it before assigning
  // is an error -- which is the whole reason initialization is tracked.
  inspect(
    read_after_declaring(Ref({ nullable: false, typ: Any })),
    content="The local variable 'x' has not been initialized.",
  )
}

///|
/// Assigning a non-defaultable local makes it readable, which is the other half
/// of the same rule.
test "assigning a declared local makes it readable" {
  let ctx = module_ctx()
  let x : @ast.Ident = { name: "x", loc: loc_at(2, 3) }
  @typing.declare_local(ctx, x, Ref({ nullable: false, typ: Any }))
  let target : @ast.Ident = { name: "x", loc: loc_at(10, 11) }
  @typing.assign_target(ctx, target, @typing.resolve_variable(ctx, target))
  let _ = @typing.type_get(ctx, { name: "x", loc: loc_at(20, 21) })
  inspect(ctx.diagnostics.collected().length(), content="0")
}

///|
/// A binding with an initializer holds a value by construction.
test "a bound local is initialized" {
  let ctx = module_ctx()
  @typing.bind_local(
    ctx,
    { name: "x", loc: loc_at(2, 3) },
    Some(@infer.i32_valtype),
  )
  inspect(
    @infer.to_string(@typing.type_get(ctx, { name: "x", loc: loc_at(20, 21) })),
    content="i32",
  )
  inspect(ctx.diagnostics.collected().length(), content="0")
  // And it is recorded as a declaration, so an unread one can be reported.
  inspect(ctx.local_decls.map(d => d.name).join(","), content="x")
}

///|
/// A type that does not resolve declares nothing -- there is no type to give
/// the local, and the failure was reported where the name could not be found.
test "an unresolvable type declares no local" {
  let ctx = module_ctx()
  @typing.declare_local(
    ctx,
    { name: "x", loc: loc_at(2, 3) },
    Ref({ nullable: true, typ: Type({ name: "missing", loc: loc_at(4, 11) }) }),
  )
  inspect(ctx.locals.contains("x"), content="false")
  inspect(ctx.local_decls.length(), content="0")
}

///|
/// A resolved value type keeps BOTH forms: the name the author wrote, so a
/// diagnostic can print it, and the store index, so subtyping can be decided.
test "internalize keeps the name and the index" {
  let ctx = module_ctx()
  let store_id = ctx.type_context.store.add_rectype([
    {
      final_: true,
      supertype: None,
      descriptor: None,
      describes: None,
      typ: Func({ params: [], results: [] }),
    },
  ])
  let empty : @ast.SubType = {
    typ: Func({ params: [], results: [] }),
    supertype: None,
    final_: true,
    descriptor: None,
    describes: None,
  }
  ctx.types.add(ctx.diagnostics, "node", loc_at(0, 4), (Def(store_id), empty))
  let named : @wasm_types.ValType[@ast.Ident] = Ref({
    nullable: true,
    typ: Type({ name: "node", loc: loc_at(10, 14) }),
  })
  guard! @typing.internalize_valtype(ctx.type_context, ctx.diagnostics, named)
    is Some(v)
  // The source side still names it.
  guard! v.typ is Ref({ typ: Type(name), .. })
  inspect(name.name, content="node")
  // The internal side numbers it.
  guard! v.internal is Ref({ typ: Type(id), .. })
  inspect(id.to_int_for_tests_only(), content="0")
}

///|
/// An operator is the commonest way a literal acquires a width, because `x + 1`
/// says what `1` is the moment `x` is known. So the assertion is again what the
/// cells hold afterwards.
test "integer operators" {
  fn op(a : @infer.InferredType, b : @infer.InferredType) -> String {
    let ctx = module_ctx()
    let c1 = @infer.Cell::make(a)
    let c2 = @infer.Cell::make(b)
    let _ = @typing.check_int_bin_op(ctx.diagnostics, loc_at(0, 1), c1, c2)
    if ctx.diagnostics.collected().length() > 0 {
      "rejected"
    } else {
      "\{@infer.to_string(c1)} \{@infer.to_string(c2)}"
    }
  }

  let i32 : @infer.InferredType = Valtype(@infer.i32_valtype)
  let i64 : @infer.InferredType = Valtype(@infer.i64_valtype)
  let f64 : @infer.InferredType = Valtype(@infer.f64_valtype)
  // A concrete operand pins the literal to its width.
  inspect(op(i32, Number), content="i32 i32")
  inspect(op(Number, i64), content="i64 i64")
  // Two flexible operands become INT rather than staying Number: the operator
  // has committed them to being integers without saying which width.
  inspect(op(Number, Number), content="int int")
  // A large literal is pinned to i64 outright -- it cannot be i32, and an
  // integer operator's result cannot be a float, so nothing else is left.
  inspect(op(LargeInt, Number), content="i64 i64")
  inspect(op(LargeInt, LargeInt), content="i64 i64")
  inspect(op(LargeInt, i64), content="i64 i64")
  // Floats have no business here.
  inspect(op(i32, f64), content="rejected")
  inspect(op(Float, Number), content="rejected")
  inspect(op(i32, i64), content="rejected")
}

///|
/// A float operator takes a large literal without complaint: it has already
/// ruled out every integer reading, so there is nothing to object to.
test "float operators" {
  fn op(a : @infer.InferredType, b : @infer.InferredType) -> String {
    let ctx = module_ctx()
    let c1 = @infer.Cell::make(a)
    let c2 = @infer.Cell::make(b)
    let _ = @typing.check_float_bin_op(ctx.diagnostics, loc_at(0, 1), c1, c2)
    if ctx.diagnostics.collected().length() > 0 {
      "rejected"
    } else {
      "\{@infer.to_string(c1)} \{@infer.to_string(c2)}"
    }
  }

  let f32 : @infer.InferredType = Valtype(@infer.f32_valtype)
  let f64 : @infer.InferredType = Valtype(@infer.f64_valtype)
  let i32 : @infer.InferredType = Valtype(@infer.i32_valtype)
  inspect(op(f32, Number), content="f32 f32")
  inspect(op(Number, f64), content="f64 f64")
  inspect(op(Number, Number), content="float float")
  // A large literal is simply a float here.
  inspect(op(LargeInt, f64), content="f64 f64")
  inspect(op(LargeInt, Number), content="float float")
  // Integers have no business here.
  inspect(op(i32, Number), content="rejected")
  inspect(op(Int, Number), content="rejected")
  inspect(op(f32, f64), content="rejected")
}

///|
/// The either-group operators, and the case that shows why the three rules are
/// separate: what an operator has RULED OUT decides whether a large literal
/// gets pinned.
test "operators that accept either group" {
  fn op(a : @infer.InferredType, b : @infer.InferredType) -> String {
    let ctx = module_ctx()
    let c1 = @infer.Cell::make(a)
    let c2 = @infer.Cell::make(b)
    @typing.check_num_concrete(ctx.diagnostics, loc_at(0, 1), c1, c2)
    if ctx.diagnostics.collected().length() > 0 {
      "rejected"
    } else {
      "\{@infer.to_string(c1)} \{@infer.to_string(c2)}"
    }
  }

  let i32 : @infer.InferredType = Valtype(@infer.i32_valtype)
  let f64 : @infer.InferredType = Valtype(@infer.f64_valtype)
  // Two fully flexible operands stay Number: nothing has been ruled out, so the
  // operator could still resolve either way. The integer rule would have
  // committed them to `int` here.
  inspect(op(Number, Number), content="number number")
  // Either group is reachable.
  inspect(op(i32, Number), content="i32 i32")
  inspect(op(f64, Number), content="f64 f64")
  // A large literal with a COMMITTED integer: the integer cannot be a float and
  // the literal cannot be i32, so i64 is their only common type.
  inspect(op(LargeInt, Int), content="i64 i64")
  // But with another large literal, or a bare number, it stays flexible --
  // a float is still reachable. This is exactly where this rule and the
  // integer-only one part company.
  inspect(op(LargeInt, LargeInt), content="large number large number")
  inspect(op(LargeInt, Number), content="large number large number")
  inspect(op(LargeInt, Float), content="float float")
  // Mixing the groups is still a mistake.
  inspect(op(i32, f64), content="rejected")
  inspect(op(Int, Float), content="rejected")
}

///|
/// The message names both operand types, because which one is wrong depends on
/// what the author meant.
test "the operator mismatch message" {
  let ctx = module_ctx()
  @typing.check_num_concrete(
    ctx.diagnostics,
    loc_at(4, 9),
    @infer.valtype_cell(@infer.i32_valtype),
    @infer.valtype_cell(@infer.f64_valtype),
  )
  inspect(
    @message.to_plain_string(ctx.diagnostics.collected()[0].message),
    content="This operator cannot be applied to operands of types 'i32' and 'f64'.",
  )
}

///|
/// One argument is not one value. An argument that is itself a multi-result
/// call supplies several, so `f(g())` where `g` returns two is a two-argument
/// call written with one argument -- and counting arguments would reject it.
test "operands are counted by value, not by argument" {
  fn call(
    args : Array[(Array[@infer.Cell[@infer.InferredType]], @basic.Location)],
    params : Array[@infer.Cell[@infer.InferredType]],
  ) -> String {
    let ctx = module_ctx()
    let info = ctx.type_context.subtyping_info()
    @typing.check_operands(info, ctx.diagnostics, loc_at(0, 30), args, params)
    let msgs = ctx.diagnostics.collected()
    msgs
    .map(e => "\{e.loc.start.cnum}: \{@message.to_plain_string(e.message)}")
    .join(" | ")
  }

  let i32 = () => @infer.valtype_cell(@infer.i32_valtype)
  let i64 = () => @infer.valtype_cell(@infer.i64_valtype)
  // Two arguments, one value each.
  inspect(
    call([([i32()], loc_at(5, 6)), ([i64()], loc_at(8, 9))], [i32(), i64()]),
    content="",
  )
  // ONE argument supplying two values satisfies a two-parameter call.
  inspect(call([([i32(), i64()], loc_at(5, 12))], [i32(), i64()]), content="")
  // And the count that matters is the value count.
  inspect(
    call([([i32(), i64()], loc_at(5, 12))], [i32()]),
    content="0: This instruction expects 1 operand(s) but 2 was/were provided.",
  )
  inspect(
    call([], [i32()]),
    content="0: This instruction expects 1 operand(s) but 0 was/were provided.",
  )
}

///|
/// A wrong value is reported at ITS OWN argument's span, so a wrong third
/// argument points at the third argument rather than at the whole call.
test "a bad operand points at its own argument" {
  let ctx = module_ctx()
  let info = ctx.type_context.subtyping_info()
  @typing.check_operands(
    info,
    ctx.diagnostics,
    loc_at(0, 30),
    [
      ([@infer.valtype_cell(@infer.i32_valtype)], loc_at(5, 6)),
      ([@infer.valtype_cell(@infer.f64_valtype)], loc_at(8, 9)),
    ],
    [
      @infer.valtype_cell(@infer.i32_valtype),
      @infer.valtype_cell(@infer.i64_valtype),
    ],
  )
  let e = ctx.diagnostics.collected()[0]
  inspect(e.loc.start.cnum, content="8")
  inspect(
    @message.to_plain_string(e.message),
    content="This expression has type 'f64' but is expected to have type 'i64'.",
  )
}

///|
/// A value inside a multi-result argument has no span of its own, so it is
/// reported at the whole argument -- which is what the reader can act on
/// anyway.
test "a value inside a multi-result argument reports at the argument" {
  let ctx = module_ctx()
  let info = ctx.type_context.subtyping_info()
  @typing.check_operands(
    info,
    ctx.diagnostics,
    loc_at(0, 30),
    [
      (
        [
          @infer.valtype_cell(@infer.i32_valtype),
          @infer.valtype_cell(@infer.f64_valtype),
        ],
        loc_at(5, 12),
      ),
    ],
    [
      @infer.valtype_cell(@infer.i32_valtype),
      @infer.valtype_cell(@infer.i64_valtype),
    ],
  )
  inspect(ctx.diagnostics.collected()[0].loc.start.cnum, content="5")
}

///|
/// A count mismatch is reported once, and the values are NOT then paired up:
/// with the wrong number of them, pairing would produce a second, misleading
/// complaint about whichever happened to line up.
test "a count mismatch does not also complain about types" {
  let ctx = module_ctx()
  let info = ctx.type_context.subtyping_info()
  @typing.check_subtypes(
    info,
    ctx.diagnostics,
    loc_at(0, 30),
    [
      @infer.valtype_cell(@infer.f64_valtype),
      @infer.valtype_cell(@infer.f64_valtype),
    ],
    [@infer.valtype_cell(@infer.i32_valtype)],
  )
  inspect(ctx.diagnostics.collected().length(), content="1")
  inspect(
    @message.to_plain_string(ctx.diagnostics.collected()[0].message),
    content="This instruction provides 2 value(s) but 1 was/were expected.",
  )
}

///|
/// A flexible literal passed as an argument is pinned by the parameter, which
/// is the ordinary way a call resolves one.
test "an argument literal is pinned by the parameter" {
  let ctx = module_ctx()
  let info = ctx.type_context.subtyping_info()
  let literal = @infer.Cell::make(@typing.int_literal_lattice("1"))
  @typing.check_operands(
    info,
    ctx.diagnostics,
    loc_at(0, 30),
    [([literal], loc_at(5, 6))],
    [@infer.valtype_cell(@infer.i64_valtype)],
  )
  inspect(ctx.diagnostics.collected().length(), content="0")
  inspect(@infer.to_string(literal), content="i64")
}

///|
/// A label is a lexical binding, so an inner one of the same name shadows the
/// outer -- which is why the search runs innermost first.
test "a branch finds the innermost matching label" {
  let ctx = module_ctx()
  let outer : @ast.Ident = { name: "l", loc: loc_at(2, 3) }
  let inner : @ast.Ident = { name: "l", loc: loc_at(6, 7) }
  let i32 = @infer.valtype_cell(@infer.i32_valtype)
  let i64 = @infer.valtype_cell(@infer.i64_valtype)
  let found = ctx.with_frame(
    @typing_env.ControlFrame::new([i32], label=Some(outer)),
    () => {
      ctx.with_frame(@typing_env.ControlFrame::new([i64], label=Some(inner)), () => {
        @typing.branch_target(ctx, { name: "l", loc: loc_at(20, 21) })
      })
    },
  )
  // The inner frame's types, not the outer's.
  inspect(found.map(c => @infer.to_string(c)).join(","), content="i64")
  // And the INNER declaration is the one marked used, keyed by its offset --
  // so a shadowing inner label does not mask an unused outer one.
  inspect(ctx.used_labels.map(o => o.to_string()).join(","), content="6")
}

///|
/// An unresolved label reports once and sets a flag. That flag is what stops
/// the failure becoming two: a block whose only value delivery was the
/// unresolved branch legitimately computes no value, and saying so as well
/// would anchor a derived error away from the label the reader must fix.
test "an unbound label reports and marks the function" {
  let ctx = module_ctx()
  inspect(ctx.unresolved_label.val, content="false")
  let found = @typing.branch_target(ctx, { name: "nope", loc: loc_at(20, 24) })
  inspect(found.length(), content="0")
  inspect(ctx.unresolved_label.val, content="true")
  inspect(
    @message.to_plain_string(ctx.diagnostics.collected()[0].message),
    content="The label 'nope' is not bound.",
  )
}

///|
/// Suggestions come from the frames in SCOPE, because a label is lexical: one
/// from a block that has already closed is not something the author could have
/// meant here.
test "label suggestions are lexical" {
  let ctx = module_ctx()
  // A closed block's label is gone by the time we ask.
  ctx.with_frame(
    @typing_env.ControlFrame::new(
      [],
      label=Some({ name: "closed", loc: loc_at(2, 8) }),
    ),
    () => (),
  )
  let outer : @ast.Ident = { name: "retry", loc: loc_at(10, 15) }
  ctx.with_frame(@typing_env.ControlFrame::new([], label=Some(outer)), () => {
    let _ = @typing.branch_target(ctx, { name: "retr", loc: loc_at(20, 24) })
  })
  guard! ctx.diagnostics.collected()[0].hint is Some(h)
  inspect(@message.to_plain_string(h), content="Did you mean 'retry'?")
  // The closed block's label is not offered, however close it is.
  let ctx2 = module_ctx()
  ctx2.with_frame(
    @typing_env.ControlFrame::new(
      [],
      label=Some({ name: "closed", loc: loc_at(2, 8) }),
    ),
    () => (),
  )
  let _ = @typing.branch_target(ctx2, { name: "closd", loc: loc_at(20, 25) })
  inspect(ctx2.diagnostics.collected()[0].hint is None, content="true")
}

///|
/// An unbound label and a legitimately void target both deliver no types, so
/// they need telling apart -- which is what `label_in_scope` is for.
test "a void target is not an unbound one" {
  let ctx = module_ctx()
  let l : @ast.Ident = { name: "done", loc: loc_at(2, 6) }
  let observed = ctx.with_frame(
    @typing_env.ControlFrame::new([], label=Some(l)),
    () => {
      (
        @typing.branch_target(ctx, { name: "done", loc: loc_at(20, 24) }).length(),
        @typing.label_in_scope(ctx, { name: "done", loc: loc_at(20, 24) }),
        @typing.label_in_scope(ctx, { name: "nope", loc: loc_at(20, 24) }),
      )
    },
  )
  let (delivered, done_in_scope, nope_in_scope) = observed
  // In scope, and delivers nothing.
  inspect(delivered, content="0")
  inspect(done_in_scope, content="true")
  // Not in scope, and also delivers nothing -- but for a different reason.
  inspect(nope_in_scope, content="false")
  // Asking did not report anything.
  inspect(ctx.diagnostics.collected().length(), content="0")
}

///|
/// An unlabelled frame is still a frame -- it just cannot be branched to by
/// name.
test "an unlabelled frame is not a branch target" {
  let ctx = module_ctx()
  let in_scope = ctx.with_frame(@typing_env.ControlFrame::new([]), () => {
    @typing.label_in_scope(ctx, { name: "anything", loc: loc_at(0, 8) })
  })
  inspect(in_scope, content="false")
}

///|
/// The whole `Collecting` machinery exists for this: `subtype` records each
/// delivery reaching a block's exit -- the fall-through, each `br`, each caught
/// value -- and this folds them into one type.
test "joining what reaches a block's exit" {
  fn exits(values : Array[(Int, @infer.InferredType)]) -> String {
    let ctx = module_ctx()
    let collected = values.map(v => {
      ((Some(loc_at(v.0, v.0 + 1)) : @basic.Location?), @infer.Cell::make(v.1))
    })
    let r = @typing.join_collected(
      ctx.diagnostics,
      loc_at(0, 50),
      collected,
      no_lub,
    )
    let ty = match r {
      None => "none"
      Some(c) => @infer.to_string(c)
    }
    let msgs = ctx.diagnostics.collected()
    "\{ty}\{if msgs.is_empty() { "" } else { "  -- " + msgs.length().to_string() + " error(s)" }}"
  }

  let i32 : @infer.InferredType = Valtype(@infer.i32_valtype)
  let i64 : @infer.InferredType = Valtype(@infer.i64_valtype)
  // No exits at all: nothing to infer.
  inspect(exits([]), content="none")
  // One exit is its own answer.
  inspect(exits([(5, i32)]), content="i32")
  // Agreeing exits fold to the agreed type.
  inspect(exits([(5, i32), (9, i32)]), content="i32")
  // A flexible literal reaching the exit is pinned by a concrete sibling --
  // which is what stops the lowering emitting the wrong width for it.
  inspect(exits([(5, i32), (9, Number)]), content="i32")
  inspect(exits([(5, Number), (9, i64)]), content="i64")
  // Two flexible ones stay flexible.
  inspect(exits([(5, Number), (9, Number)]), content="number")
}

///|
/// A disagreement is reported once and the fold keeps going with the FIRST
/// value -- so one odd delivery does not disagree with every subsequent one and
/// produce a complaint per exit.
test "one odd exit produces one complaint" {
  let ctx = module_ctx()
  let i32 = () => {
    @infer.Cell::make(@infer.InferredType::Valtype(@infer.i32_valtype))
  }
  let f64 = @infer.Cell::make(@infer.InferredType::Valtype(@infer.f64_valtype))
  let r = @typing.join_collected(
    ctx.diagnostics,
    loc_at(0, 50),
    [
      (Some(loc_at(5, 6)), i32()),
      (Some(loc_at(9, 10)), f64),
      (Some(loc_at(15, 16)), i32()),
      (Some(loc_at(20, 21)), i32()),
    ],
    no_lub,
  )
  // One error, not three.
  inspect(ctx.diagnostics.collected().length(), content="1")
  // And the result is the first value's type, so the block is still checkable.
  guard! r is Some(c)
  inspect(@infer.to_string(c), content="i32")
}

///|
/// A mismatch names both values at their own spans, because which one is wrong
/// depends on what the author meant -- and the first span is the accumulator's,
/// which is where the fold started.
test "a block-exit mismatch names both values" {
  let ctx = module_ctx()
  let _ = @typing.join_collected(
    ctx.diagnostics,
    loc_at(0, 50),
    [
      (Some(loc_at(5, 6)), @infer.valtype_cell(@infer.i32_valtype)),
      (Some(loc_at(9, 10)), @infer.valtype_cell(@infer.f64_valtype)),
    ],
    no_lub,
  )
  let e = ctx.diagnostics.collected()[0]
  inspect(
    @message.to_plain_string(e.message),
    content="The values reaching this block's exit have no common supertype, so its result type cannot be inferred.",
  )
  inspect(
    e.related
    .map(r => "\{r.loc.start.cnum}:\{@message.to_plain_string(r.message)}")
    .join(" "),
    content="5:'i32' 9:'f64'",
  )
}

///|
/// A delivery with no span of its own -- a synthesized one -- falls back to the
/// block, which is at least somewhere the reader can look.
test "a spanless delivery reports against the block" {
  let ctx = module_ctx()
  let _ = @typing.join_collected(
    ctx.diagnostics,
    loc_at(0, 50),
    [
      (None, @infer.valtype_cell(@infer.i32_valtype)),
      (None, @infer.valtype_cell(@infer.f64_valtype)),
    ],
    no_lub,
  )
  inspect(
    ctx.diagnostics.collected()[0].related
    .map(r => r.loc.start.cnum.to_string())
    .join(","),
    content="0,0",
  )
}

///|
/// End to end: `subtype` records the deliveries onto a Collecting cell, and
/// `join_collected` folds exactly those. This is the seam the two halves meet
/// at, and nothing else drives it.
test "subtype records and join_collected folds" {
  let ctx = module_ctx()
  let info = ctx.type_context.subtyping_info()
  let collecting : @infer.Collecting = {
    collected: [],
    exacts: [],
    declared: None,
    needed: false,
  }
  let result = @infer.Cell::make(@infer.InferredType::Collecting(collecting))
  // Two deliveries, checked against the block's result cell.
  let fall_through = @infer.valtype_cell(@infer.i32_valtype)
  let branched = @infer.Cell::make(@typing.int_literal_lattice("7"))
  let _ = @typing.subtype(
    info,
    fall_through,
    result,
    location=Some(loc_at(5, 6)),
  )
  let _ = @typing.subtype(info, branched, result, location=Some(loc_at(9, 10)))
  inspect(collecting.collected.length(), content="2")
  // Folding them gives the block's result, and pins the literal to it.
  guard! @typing.join_collected(
      ctx.diagnostics,
      loc_at(0, 50),
      collecting.collected,
      no_lub,
    )
    is Some(r)
  inspect(@infer.to_string(r), content="i32")
  inspect(@infer.to_string(branched), content="i32")
}

///|
/// A rec group's members are registered before anything is resolved, which is
/// the only reason a member written first can name one written last.
test "a rec group's members can name each other in either direction" {
  let ctx = module_ctx()
  let tc = ctx.type_context
  fn ref_to(n : String) -> @ast.SubType {
    {
      typ: Struct([
        {
          desc: (
            id("next"),
            {
              mut_: false,
              typ: Value(Ref({ nullable: true, typ: Type(id(n)) })),
            },
          ),
          info: loc_at(0, 1),
        },
      ]),
      supertype: None,
      final_: true,
      descriptor: None,
      describes: None,
    }
  }

  // $a points at $b, which is written after it.
  let group = [
    (
      { desc: (id("a"), ref_to("b")), info: loc_at(0, 1) } :
      @basic.Annotated[(@ast.Ident, @ast.SubType), @basic.Location]),
    { desc: (id("b"), ref_to("a")), info: loc_at(2, 3) },
  ]
  let base = @typing.add_type(tc, ctx.diagnostics, group)
  inspect(ctx.diagnostics.collected().length(), content="0")
  inspect(base is Some(_), content="true")
  // And both names now resolve to real store indices, one apart -- the
  // placeholders have been replaced.
  fn index_of(n : String) -> Int {
    match @typing.resolve_type_name(tc, ctx.diagnostics, id(n)) {
      Some(i) => i.to_int_for_tests_only()
      None => -1
    }
  }

  inspect(index_of("b") - index_of("a"), content="1")
}

///|
/// A supertype must be declared before. A forward or self reference inside the
/// group is reported as unbound and DROPPED, so the subtype chain stays acyclic
/// -- keeping it would turn a reported error into a hang.
test "a forward supertype is unbound, and is dropped" {
  let ctx = module_ctx()
  let tc = ctx.type_context
  fn empty_struct(sup : String?) -> @ast.SubType {
    {
      typ: Struct([]),
      supertype: sup.map(s => id(s)),
      final_: false,
      descriptor: None,
      describes: None,
    }
  }

  let group : Array[
    @basic.Annotated[(@ast.Ident, @ast.SubType), @basic.Location],
  ] = [
    { desc: (id("a"), empty_struct(Some("b"))), info: loc_at(0, 1) },
    { desc: (id("b"), empty_struct(None)), info: loc_at(2, 3) },
  ]
  let _ = @typing.add_type(tc, ctx.diagnostics, group)
  inspect(
    @message.to_plain_string(ctx.diagnostics.collected()[0].message),
    content="The type 'b' is not bound.",
  )
  // The stored source type has lost the supertype it could not keep.
  inspect(
    @typing.get_type_definition(tc, ctx.diagnostics, id("a")).unwrap().supertype
    is None,
    content="true",
  )
}

///|
/// `..` inherits the supertype's fields, and expansion runs in source order so
/// a member can splice from one earlier in its own group.
test "a splice inherits its supertype's fields" {
  let ctx = module_ctx()
  let tc = ctx.type_context
  fn field(
    n : String,
  ) -> @basic.Annotated[
    (@ast.Ident, @wasm_types.MutType[@wasm_types.StorageType[@ast.Ident]]),
    @basic.Location,
  ] {
    { desc: (id(n), { mut_: false, typ: Value(I32) }), info: loc_at(0, 1) }
  }

  let group : Array[
    @basic.Annotated[(@ast.Ident, @ast.SubType), @basic.Location],
  ] = [
    {
      desc: (
        id("base"),
        {
          typ: Struct([field("x")]),
          supertype: None,
          final_: false,
          descriptor: None,
          describes: None,
        },
      ),
      info: loc_at(0, 1),
    },
    {
      desc: (
        id("derived"),
        {
          typ: Struct([@ast.splice_field(loc_at(4, 6)), field("y")]),
          supertype: Some(id("base")),
          final_: true,
          descriptor: None,
          describes: None,
        },
      ),
      info: loc_at(2, 3),
    },
  ]
  let _ = @typing.add_type(tc, ctx.diagnostics, group)
  inspect(ctx.diagnostics.collected().length(), content="0")
  // The stored definition has the parent's field ahead of its own; the AST it
  // was built from still holds the sentinel, for the formatter to write back.
  let stored = @typing.get_type_definition(tc, ctx.diagnostics, id("derived")).unwrap()
  let names = match stored.typ {
    Struct(fs) => fs.map(f => f.desc.0.name).join(",")
    _ => "not a struct"
  }
  inspect(names, content="x,y")
  inspect(@ast.is_splice_field(group[1].desc.1.typ_fields()[0]), content="true")
}

///|
/// The fields of a struct type, for a test that wants to look at them.
fn @ast.SubType::typ_fields(
  self : @ast.SubType,
) -> Array[
  @basic.Annotated[
    (@ast.Ident, @wasm_types.MutType[@wasm_types.StorageType[@ast.Ident]]),
    @basic.Location,
  ],
] {
  match self.typ {
    Struct(fs) => fs
    _ => []
  }
}

///|
/// A descriptor pair must name each other, and must do so inside one recursion
/// group: `$obj` says `$desc` is its descriptor, `$desc` says it describes
/// `$obj`. Half a pair is an error, and so is a descriptor declared before what
/// it describes.
test "descriptor clauses must be reciprocal, and in order" {
  fn ctx_() -> @typing_env.ModuleContext {
    @typing_env.ModuleContext::new(
      @diagnostic.collector(),
      @type_store.TypeStore::new(),
      @feature.configure([(CustomDescriptors, true)]),
    )
  }

  fn entry(
    n : String,
    descriptor : String?,
    describes : String?,
    at : Int,
  ) -> @basic.Annotated[(@ast.Ident, @ast.SubType), @basic.Location] {
    {
      desc: (
        id(n),
        {
          typ: Struct([]),
          supertype: None,
          final_: true,
          descriptor: descriptor.map(s => id(s)),
          describes: describes.map(s => id(s)),
        },
      ),
      info: loc_at(at, at + 1),
    }
  }

  // A well-formed pair: the subject first, its descriptor second.
  let good = ctx_()
  let _ = @typing.add_type(good.type_context, good.diagnostics, [
    entry("obj", Some("desc"), None, 0),
    entry("desc", None, Some("obj"), 2),
  ])
  inspect(good.diagnostics.collected().length(), content="0")
  // Half a pair: `$obj` names a descriptor that does not describe it back.
  let lone = ctx_()
  let _ = @typing.add_type(lone.type_context, lone.diagnostics, [
    entry("obj", Some("desc"), None, 0),
    entry("desc", None, None, 2),
  ])
  inspect(
    @message.to_plain_string(lone.diagnostics.collected()[0].message),
    content="The descriptor of this type does not describe it back.",
  )
  // Reciprocal, but the descriptor comes first -- so reading the group in order
  // meets it before its subject.
  let backwards = ctx_()
  let _ = @typing.add_type(backwards.type_context, backwards.diagnostics, [
    entry("desc", None, Some("obj"), 0),
    entry("obj", Some("desc"), None, 2),
  ])
  inspect(
    @message.to_plain_string(backwards.diagnostics.collected()[0].message),
    content="A described type must be declared before its descriptor.",
  )
}

///|
/// The declaration pass, end to end. What it has to get right is ORDER: types
/// before functions, so a function's declared type resolves whether it was
/// written above or below; and every name before any body, so a call to a
/// function defined later resolves at all.
test "every name is declared before any body is checked" {
  let ctx = module_ctx()
  let sig_ : @ast.FuncType = { params: [], results: [] }
  let fields : @ast.Module[@basic.Location] = [
    // `later` is defined below the type it names, and `t` below the function.
    {
      desc: Func(
        name=id("later"),
        typ=Some(id("t")),
        sign=None,
        body=(None, []),
        attributes=[],
      ),
      info: loc_at(0, 1),
    },
    {
      desc: Type([
        {
          desc: (
            id("t"),
            {
              typ: Func(sig_),
              supertype: None,
              final_: true,
              descriptor: None,
              describes: None,
            },
          ),
          info: loc_at(2, 3),
        },
      ]),
      info: loc_at(2, 3),
    },
    {
      desc: Tag(name=id("oops"), typ=None, sign=Some(sig_), attributes=[]),
      info: loc_at(4, 5),
    },
    {
      desc: Elem(
        name=id("e"),
        reftype={ nullable: true, typ: Func },
        mode=EPassive,
        init=[],
        attributes=[],
      ),
      info: loc_at(6, 7),
    },
  ]
  @typing.declare_fields(ctx, fields)
  inspect(ctx.diagnostics.collected().length(), content="0")
  // The function resolved against a type written after it.
  inspect(
    match ctx.functions.resolve("later", loc_at(20, 21)) {
      Some(Some((_, n, _))) => n
      Some(None) => "poisoned"
      None => "unbound"
    },
    content="t",
  )
  inspect(ctx.tags.resolve("oops", loc_at(22, 23)) is Some(_), content="true")
  inspect(ctx.elems.resolve("e", loc_at(24, 25)) is Some(_), content="true")
}

///|
/// Memories are numbered across imported and defined ones alike, in the order
/// they appear -- the index space is one space, not two.
///
/// And a name declared in one `#[if]` branch does not clash with the same name
/// in the other, because no configuration has both.
test "the declaration pass counts memories and honours branches" {
  let ctx = module_ctx()
  fn mem(
    n : String,
    at : Int,
  ) -> @basic.Annotated[@ast.ModuleField[@basic.Location], @basic.Location] {
    {
      desc: Memory(
        name=id(n),
        address_type=I32,
        limits=None,
        page_size_log2=None,
        shared=false,
        data=[],
        attributes=[],
      ),
      info: loc_at(at, at + 1),
    }
  }

  let imported : @basic.Annotated[
    @ast.ModuleField[@basic.Location],
    @basic.Location,
  ] = {
    desc: Import(module_={ desc: b"env", info: loc_at(0, 1) }, decl={
      desc: {
        id: id("first"),
        kind: Memory(
          address_type=I32,
          limits=None,
          page_size_log2=None,
          shared=false,
        ),
        attributes: [],
      },
      info: loc_at(0, 1),
    }),
    info: loc_at(0, 1),
  }
  // Two memories of the same name, one per branch of a `#[if]`.
  let branched : @basic.Annotated[
    @ast.ModuleField[@basic.Location],
    @basic.Location,
  ] = {
    desc: Conditional(
      cond=Var({ desc: "debug", info: loc_at(8, 9) }),
      then_fields={ desc: [mem("m", 10)], info: loc_at(10, 11) },
      else_fields=Some({ desc: [mem("m", 12)], info: loc_at(12, 13) }),
    ),
    info: loc_at(8, 9),
  }
  @typing.declare_fields(ctx, [imported, mem("second", 4), branched])
  inspect(ctx.diagnostics.collected().length(), content="0")
  fn index_of(n : String) -> Int {
    match ctx.memories.resolve(n, loc_at(30, 31)) {
      Some((i, _)) => i
      None => -1
    }
  }

  // The import is 0 and the defined one 1: one index space, in source order.
  inspect(index_of("first"), content="0")
  inspect(index_of("second"), content="1")
  // Both branches declared `m`, and neither is a duplicate of the other.
  inspect(ctx.memories.visible("m").length(), content="2")
}

///|
/// Entering a function: the declared type resolved, the parameters bound and
/// initialized, the results as cells the `return`s will be checked against.
test "entering a function establishes its scope" {
  let ctx = module_ctx()
  let sig_ : @ast.FuncType = {
    params: [
      { desc: (Some(id("n")), I32), info: loc_at(0, 1) },
      // An unnamed parameter binds nothing -- there is no name to bind.
      { desc: (None, F64), info: loc_at(2, 3) },
    ],
    results: [I64],
  }
  let fields : @ast.Module[@basic.Location] = [
    {
      desc: Func(name=id("f"), typ=None, sign=Some(sig_), body=(None, []), attributes=[]),
      info: loc_at(4, 5),
    },
  ]
  @typing.declare_fields(ctx, fields)
  let returns = @typing.enter_function_scope(ctx, id("f"), Some(sig_), [])
  inspect(ctx.diagnostics.collected().length(), content="0")
  inspect(returns.map(c => @infer.to_string(c)).join(","), content="i64")
  inspect(ctx.locals.contains("n"), content="true")
  inspect(ctx.initialized_locals.contains("n"), content="true")
  // Two parameters, one of them nameless, so one local.
  inspect(ctx.locals.length(), content="1")
  // References made while checking are attributed to the function.
  inspect(origin_name(ctx.origin.val), content="fn:f")
  @typing.leave_function_scope(ctx)
  inspect(origin_name(ctx.origin.val), content="root")
}

///|
/// A `#[start]` function is called by the host on instantiation, so there is
/// nowhere for an argument to come from or a result to go.
test "a start function takes and returns nothing" {
  let ctx = module_ctx()
  let sig_ : @ast.FuncType = {
    params: [{ desc: (Some(id("n")), I32), info: loc_at(0, 1) }],
    results: [],
  }
  let attrs : Array[@ast.Attribute] = [
    {
      attr_name: "start",
      attr_value: None,
      attr_guard: None,
      attr_span: loc_at(6, 7),
    },
  ]
  let fields : @ast.Module[@basic.Location] = [
    {
      desc: Func(
        name=id("main"),
        typ=None,
        sign=Some(sig_),
        body=(None, []),
        attributes=attrs,
      ),
      info: loc_at(4, 5),
    },
  ]
  @typing.declare_fields(ctx, fields)
  let _ = @typing.enter_function_scope(ctx, id("main"), Some(sig_), attrs)
  inspect(
    @message.to_plain_string(ctx.diagnostics.collected()[0].message),
    content="The start function must have no parameters and no results.",
  )
}

///|
/// A signature that failed to resolve was reported once, at registration. The
/// body is still checked -- against a MUTED re-resolution, so the same mistake
/// is not reported a second time and whatever fails again becomes poison.
test "a poisoned signature is not reported twice" {
  let ctx = module_ctx()
  let sig_ : @ast.FuncType = {
    params: [
      {
        desc: (Some(id("p")), Ref({ nullable: true, typ: Type(id("nope")) })),
        info: loc_at(0, 1),
      },
    ],
    results: [Ref({ nullable: true, typ: Type(id("nope")) })],
  }
  let fields : @ast.Module[@basic.Location] = [
    {
      desc: Func(name=id("f"), typ=None, sign=Some(sig_), body=(None, []), attributes=[]),
      info: loc_at(4, 5),
    },
  ]
  @typing.declare_fields(ctx, fields)
  // Registration said it, once. Resolving a function type stops at the first
  // parameter that fails, so the result -- the same unbound name -- is never
  // reached, and one mistake is one report however many times it is written.
  inspect(ctx.diagnostics.collected().length(), content="1")
  let returns = @typing.enter_function_scope(ctx, id("f"), Some(sig_), [])
  // Entering says nothing new: the re-resolution is muted.
  inspect(ctx.diagnostics.collected().length(), content="1")
  // And the body has something to check against: poison, which suppresses
  // rather than cascades.
  inspect(returns.length(), content="1")
  inspect(returns[0].get() is Error, content="true")
  // The parameter still binds its name, as a poison local.
  inspect(ctx.locals.get("p").unwrap().0 is None, content="true")
}

///|
/// An origin as a short string, `Origin` deriving Debug rather than Show.
fn origin_name(o : @typing_env.Origin) -> String {
  match o {
    Root => "root"
    FromFunction(f) => "fn:" + f
    FromType(t) => "type:" + t
    Ignored => "ignored"
  }
}

///|
/// The whole seam, driven by the block machinery rather than by hand: a body
/// pushes a value, `collect_into` takes it off the exit, and the join folds it
/// with what a branch delivered.
///
/// Three things reach a block's exit and all three land in one place. This is
/// the one nothing checks against anything -- the fall-through -- which is why
/// it has to be taken off the stack deliberately.
test "the fall-through reaches the exit alongside the branches" {
  let ctx = module_ctx()
  let ops = @typing.Operands::new()
  let info = ctx.type_context.subtyping_info()
  let (cs, r) = @typing.fresh_collecting(None)
  // A branch delivers a flexible literal, recorded by `subtype` as any `br`
  // would record it.
  let branched = @infer.Cell::make(@typing.int_literal_lattice("7"))
  let _ = @typing.subtype(info, branched, r, location=Some(loc_at(9, 10)))
  // The body leaves an i32 on the stack: the fall-through.
  @typing.collect_into(ctx, ops, loc_at(0, 50), Some(id("out")), cs, r, () => {
    ops.push(Some(loc_at(5, 6)), @infer.valtype_cell(@infer.i32_valtype))
  })
  inspect(cs.collected.length(), content="2")
  // Nothing was left over to complain about, and the enclosing stack is back.
  inspect(ctx.diagnostics.collected().length(), content="0")
  guard! @typing.infer_result(ctx, loc_at(0, 50), cs, no_lub) is Some(result)
  inspect(@infer.to_string(result), content="i32")
  // And the literal that a branch delivered is pinned to the block's result.
  inspect(@infer.to_string(branched), content="i32")
}

///|
/// A dead fall-through still reaches the exit -- a value pushed after control
/// was lost is recorded, and the base stays unreachable.
///
/// A REACHABLE exit delivering nothing while a branch delivered a value is a
/// different matter: the block would yield a result its own exit never
/// produces, so it is reported.
test "an exit that delivers nothing is reported, unless it is dead" {
  let ctx = module_ctx()
  let ops = @typing.Operands::new()
  let info = ctx.type_context.subtyping_info()

  // Dead: the body diverges, then pushes. Nothing to complain about.
  let (dead, r1) = @typing.fresh_collecting(None)
  let _ = @typing.subtype(
    info,
    @infer.valtype_cell(@infer.i32_valtype),
    r1,
    location=Some(loc_at(9, 10)),
  )
  @typing.collect_into(ctx, ops, loc_at(0, 50), None, dead, r1, () => {
    ops.set_unreachable()
    ops.push(Some(loc_at(5, 6)), @infer.valtype_cell(@infer.i32_valtype))
  })
  inspect(dead.collected.length(), content="2")
  inspect(ctx.diagnostics.collected().length(), content="0")

  // Reachable, and delivers nothing, while a branch delivered a value.
  let (short_, r2) = @typing.fresh_collecting(None)
  let _ = @typing.subtype(
    info,
    @infer.valtype_cell(@infer.i32_valtype),
    r2,
    location=Some(loc_at(9, 10)),
  )
  @typing.collect_into(ctx, ops, loc_at(0, 50), None, short_, r2, () => ())
  inspect(short_.collected.length(), content="1")
  inspect(
    @message.to_plain_string(ctx.diagnostics.collected()[0].message),
    content="Expecting 1 returned value(s) from the stack, but there are 0.",
  )
  // The caret sits at the block's closing token, as every other output
  // underflow does.
  inspect(ctx.diagnostics.collected()[0].loc.start.cnum, content="50")
}

///|
/// Asking a value-less instruction for its value is a diagnostic, not an
/// option -- and one node is legitimately asked by several consumers, so the
/// report fires once per rendered position and count.
test "an instruction that produces no value is not an expression" {
  let ctx = module_ctx()
  let one = @infer.valtype_cell(@infer.i32_valtype)
  // The ordinary case: exactly one value, no report.
  inspect(
    @infer.to_string(@typing.expression_type(ctx, ([one], loc_at(0, 4)))),
    content="i32",
  )
  inspect(ctx.diagnostics.collected().length(), content="0")
  // None: reported, and recovered with poison so the caller has something to
  // carry on with.
  let none_ = @typing.expression_type(ctx, ([], loc_at(10, 14)))
  inspect(none_.get() is Error, content="true")
  inspect(
    @message.to_plain_string(ctx.diagnostics.collected()[0].message),
    content="An expression is expected here. This instruction returns 0 values.",
  )
  // Asked again at the same position with the same count: still poison, but
  // said only once.
  let _ = @typing.expression_type(ctx, ([], loc_at(10, 99)))
  inspect(ctx.diagnostics.collected().length(), content="1")
  // A different count at the same position is a different mistake, and is said.
  let _ = @typing.expression_type(ctx, ([one, one], loc_at(10, 14)))
  inspect(ctx.diagnostics.collected().length(), content="2")
  inspect(
    @message.to_plain_string(ctx.diagnostics.collected()[1].message),
    content="An expression is expected here. This instruction returns 2 values.",
  )
}

///|
/// While a branch in this function has failed to resolve its label, the value
/// shape is unreliable -- a block whose only delivery was that branch really
/// does compute nothing -- so the complaint would anchor a derived error away
/// from the unbound label.
test "an unresolved label silences the value-shape complaint" {
  let ctx = module_ctx()
  ctx.unresolved_label.val = true
  let ty = @typing.expression_type(ctx, ([], loc_at(10, 14)))
  inspect(ty.get() is Error, content="true")
  inspect(ctx.diagnostics.collected().length(), content="0")
}

///|
/// The literal arms need nothing but the token, and commit only as far as the
/// spelling requires.
test "a literal's type comes from its spelling alone" {
  fn lat(d : @ast.InstrDesc[@basic.Location]) -> String {
    match @typing.literal_type(d) {
      Some(t) => @infer.to_string(@infer.Cell::make(t))
      None => "not a literal"
    }
  }

  inspect(lat(Char('a')), content="i32")
  inspect(lat(Int("1")), content="number")
  // Past the 32-bit range it cannot be an i32, so it defaults to i64 rather
  // than to the i32-defaulting `number`.
  inspect(lat(Int("4294967296")), content="large number")
  // Past u64 it is no integer at all: only a float can hold it, so using it as
  // an integer becomes a clean type error rather than a crash in the encoder.
  inspect(lat(Int("18446744073709551616")), content="float")
  inspect(lat(Float("1.5")), content="float")
  inspect(lat(Null), content="null")
  inspect(lat(Nop), content="not a literal")
}

///|
/// A `br` to a BLOCK's label jumps to its end and delivers the block's results.
/// A `br` to a LOOP's label jumps to its top and delivers the loop's
/// parameters -- it is re-entering, not leaving. That is the whole difference
/// between the two, and getting it backwards would accept branches carrying
/// entirely the wrong values.
test "a branch to a loop delivers its parameters, not its results" {
  let ctx = module_ctx()
  let ops = @typing.Operands::new()
  let i32_ = () => @infer.valtype_cell(@infer.i32_valtype)
  let f64_ = () => @infer.valtype_cell(@infer.f64_valtype)
  // What the label's frame says a branch to it must deliver.
  let seen : Array[String] = []
  fn peek() -> Unit {
    let target = @typing.branch_target(ctx, id("l"))
    seen.push(target.map(c => @infer.to_string(c)).join(","))
  }

  // A block taking an f64 and producing an i32: branching to it delivers i32.
  ops.push(None, f64_())
  @typing.checked_block(
    ctx,
    ops,
    loc_at(0, 20),
    Some(id("l")),
    [f64_()],
    [i32_()],
    [i32_()],
    () => {
      peek()
      // The parameter the block was given is on its OWN stack, not the caller's:
      // consume it, then produce the result.
      ops.pop_any(@ref.new(None), 0, 1) |> ignore
      ops.push(None, i32_())
    },
  )
  // A loop of the same shape: branching to it delivers f64.
  @typing.checked_block(
    ctx,
    ops,
    loc_at(0, 20),
    Some(id("l")),
    [f64_()],
    [i32_()],
    [f64_()],
    () => {
      peek()
      ops.pop_any(@ref.new(None), 0, 1) |> ignore
      ops.push(None, i32_())
    },
  )
  inspect(seen.join(" | "), content="i32 | f64")
  inspect(ctx.diagnostics.collected().length(), content="0")
}

///|
/// A missing `else` means the false path falls straight through, delivering
/// what it was given. Sound only when the parameters already are the results.
test "an if without an else must fall through to its own result" {
  let ctx = module_ctx()
  let info = ctx.type_context.subtyping_info()
  let i32_ = () => @infer.valtype_cell(@infer.i32_valtype)
  let f64_ = () => @infer.valtype_cell(@infer.f64_valtype)
  // Void: nothing promised, nothing to deliver.
  inspect(@typing.missing_else_ok(info, [], []), content="true")
  // Takes an i32 and produces one: the false path passes it along.
  inspect(@typing.missing_else_ok(info, [i32_()], [i32_()]), content="true")
  // Produces a value it was never given.
  inspect(@typing.missing_else_ok(info, [], [i32_()]), content="false")
  // Given the wrong one.
  inspect(@typing.missing_else_ok(info, [f64_()], [i32_()]), content="false")
}

///|
/// A block whose declared shape does not resolve has no shape to check its body
/// against, and inventing one would invent complaints. The failure was already
/// reported by the resolver.
test "a block whose shape does not resolve has none" {
  let ctx = module_ctx()
  let bad : @ast.FuncType = {
    params: [],
    results: [Ref({ nullable: true, typ: Type(id("nope")) })],
  }
  inspect(
    @typing.block_signature(ctx.type_context, ctx.diagnostics, bad) is None,
    content="true",
  )
  let good : @ast.FuncType = {
    params: [{ desc: (None, I32), info: loc_at(0, 1) }],
    results: [F64],
  }
  guard! @typing.block_signature(ctx.type_context, ctx.diagnostics, good)
    is Some((params, results))
  inspect(params.map(c => @infer.to_string(c)).join(","), content="i32")
  inspect(results.map(c => @infer.to_string(c)).join(","), content="f64")
}

///|
/// A pass-through branch is the odd one out. An ordinary `br` delivers its
/// value and leaves; a `br_if` delivers it when taken and KEEPS it when not, so
/// the value is typed as the block's result either way. That makes the
/// requirement exact rather than merely a subtype: the fall-through path goes
/// on using it at that type.
test "a br_if value must match the block's inferred result exactly" {
  let ctx = module_ctx()
  let info = ctx.type_context.subtyping_info()
  let (cs, r) = @typing.fresh_collecting(None)
  // The block's result is being inferred, and an ordinary exit made it f64.
  let _ = @typing.subtype(
    info,
    @infer.valtype_cell(@infer.f64_valtype),
    r,
    location=Some(loc_at(2, 3)),
  )
  // A `br_if` passes an i32 through. Snapshotted at its natural type BEFORE the
  // delivery pins anything -- after pinning there would be nothing to compare.
  let passed = @infer.valtype_cell(@infer.i32_valtype)
  let _ = @typing.deliver_to_branch_target(
    info,
    ctx.diagnostics,
    loc_at(10, 12),
    [passed],
    [r],
  )
  inspect(cs.exacts.length(), content="1")
  guard! @typing.infer_result(ctx, loc_at(0, 40), cs, no_lub) is Some(result)
  @typing.report_exact_mismatches(
    ctx.diagnostics,
    loc_at(0, 40),
    result,
    cs.exacts,
  )
  inspect(
    @message.to_plain_string(
      ctx.diagnostics.collected()[ctx.diagnostics.collected().length() - 1].message,
    ),
    content="This 'br_if' value stays on the stack as the block's result, so its type must match the inferred result exactly; add a result annotation to the block.",
  )
}

///|
/// A flexible literal passed through forces the annotation to be kept: on
/// re-parse something downstream could pin it to another width, and the
/// fall-through value would then disagree with the block's inferred result.
test "a flexible literal passed through keeps the annotation" {
  let ctx = module_ctx()
  let info = ctx.type_context.subtyping_info()
  let (cs, r) = @typing.fresh_collecting(None)
  inspect(cs.needed, content="false")
  let _ = @typing.deliver_to_branch_target(
    info,
    ctx.diagnostics,
    loc_at(10, 12),
    [@infer.Cell::make(@typing.int_literal_lattice("7"))],
    [r],
  )
  inspect(cs.needed, content="true")
  // A committed type does not force it: nothing can move it later.
  let (cs2, r2) = @typing.fresh_collecting(None)
  let _ = @typing.deliver_to_branch_target(
    info,
    ctx.diagnostics,
    loc_at(10, 12),
    [@infer.valtype_cell(@infer.i32_valtype)],
    [r2],
  )
  inspect(cs2.needed, content="false")
}

///|
/// With the annotation omitted, inference has to supply one -- and the written
/// output cannot say "number", so a flexible type commits to its default width.
test "an omitted result commits to a width" {
  let ctx = module_ctx()
  fn settle(t : @infer.InferredType) -> String {
    let (cells, typ) = @typing.finalize_inferred(
      ctx,
      { params: [], results: [] },
      Some(@infer.Cell::make(t)),
    )
    // The cell and the written annotation must agree -- one is what the rest of
    // the checker sees, the other what the output says.
    if typ.results.length() != 1 {
      return "no result"
    }
    @infer.to_string(cells[0])
  }

  inspect(settle(@typing.int_literal_lattice("1")), content="i32")
  inspect(settle(@typing.int_literal_lattice("4294967296")), content="i64")
  inspect(settle(@typing.float_literal_lattice("1.5")), content="f64")
  // Nothing reached the exit: the block produces nothing, and the annotation
  // stays empty rather than inventing a type.
  let (cells, typ) = @typing.finalize_inferred(
    ctx,
    { params: [], results: [] },
    None,
  )
  inspect(cells.length(), content="0")
  inspect(typ.results.length(), content="0")
}

///|
/// Dropping a redundant annotation is only safe when the text that remains
/// RE-INFERS to the same type. Each condition guards a way that could fail.
test "an annotation is dropped only when it can be recovered" {
  fn simplifying() -> @typing_env.ModuleContext {
    @typing_env.ModuleContext::new(
      @diagnostic.collector(),
      @type_store.TypeStore::new(),
      @feature.default(),
      simplify=true,
    )
  }

  let annotated : @ast.FuncType = { params: [], results: [I32] }
  // Local functions cannot carry defaulted labels, so every knob is passed.
  fn dropped(
    ctx : @typing_env.ModuleContext,
    inferred : @infer.InferredType,
    needed : Bool,
    natural : Array[@infer.InferredType],
    exacts : Array[(@basic.Location?, @infer.Cell[@infer.InferredType])],
  ) -> Bool {
    let (_, typ) = @typing.finalize_inferred(
      ctx,
      annotated,
      Some(@infer.Cell::make(inferred)),
      needed~,
      natural~,
      exacts~,
    )
    typ.results.is_empty()
  }

  // The plain case: an i32 block annotated i32, converting from wasm.
  inspect(
    dropped(simplifying(), Valtype(@infer.i32_valtype), false, [], []),
    content="true",
  )
  // Not converting from wasm: hand-written annotations are kept as written.
  inspect(
    dropped(module_ctx(), Valtype(@infer.i32_valtype), false, [], []),
    content="false",
  )
  // Something relies on the annotation in a way the join cannot re-derive.
  inspect(
    dropped(simplifying(), Valtype(@infer.i32_valtype), true, [], []),
    content="false",
  )
  // The inferred type disagrees with what is written.
  inspect(
    dropped(simplifying(), Valtype(@infer.f64_valtype), false, [], []),
    content="false",
  )
  // An exit is a flexible literal that would re-default to i64: delete the
  // annotation and a re-parse gives the block a different type.
  inspect(
    dropped(
      simplifying(),
      Valtype(@infer.i32_valtype),
      false,
      [@typing.int_literal_lattice("4294967296")],
      [],
    ),
    content="false",
  )
  // A pass-through value that re-defaults to something other than the result.
  inspect(
    dropped(simplifying(), Valtype(@infer.i32_valtype), false, [], [
      (None, @infer.valtype_cell(@infer.f64_valtype)),
    ]),
    content="false",
  )
  // One that re-defaults to exactly the result is no obstacle.
  inspect(
    dropped(simplifying(), Valtype(@infer.i32_valtype), false, [], [
      (None, @infer.valtype_cell(@infer.i32_valtype)),
    ]),
    content="true",
  )
}

///|
/// Asking a type name for the wrong kind of definition is a mistake worth
/// naming precisely, rather than a mismatch several steps later.
test "an aggregate lookup names the kind it wanted" {
  let ctx = module_ctx()
  let tc = ctx.type_context
  fn declare_type(n : String, t : @ast.CompType, at : Int) -> Unit {
    let _ = @typing.add_type(tc, ctx.diagnostics, [
      {
        desc: (
          id(n),
          {
            typ: t,
            supertype: None,
            final_: true,
            descriptor: None,
            describes: None,
          },
        ),
        info: loc_at(at, at + 1),
      },
    ])
  }

  declare_type("f", Func({ params: [], results: [] }), 0)
  declare_type(
    "s",
    Struct([
      { desc: (id("x"), { mut_: false, typ: Value(I32) }), info: loc_at(2, 3) },
      { desc: (id("y"), { mut_: true, typ: Packed(I8) }), info: loc_at(4, 5) },
    ]),
    2,
  )
  declare_type("a", Array({ mut_: false, typ: Value(F64) }), 6)
  inspect(ctx.diagnostics.collected().length(), content="0")
  // Each lookup finds its own kind.
  inspect(
    @typing.lookup_func_type(tc, ctx.diagnostics, id("f")) is Some(_),
    content="true",
  )
  inspect(
    @typing.lookup_struct_type(tc, ctx.diagnostics, id("s")) is Some(_),
    content="true",
  )
  inspect(
    @typing.lookup_array_type(tc, ctx.diagnostics, id("a")) is Some(_),
    content="true",
  )
  inspect(ctx.diagnostics.collected().length(), content="0")
  // And says so when handed another.
  inspect(
    @typing.lookup_struct_type(tc, ctx.diagnostics, id("a")) is None,
    content="true",
  )
  inspect(
    @message.to_plain_string(ctx.diagnostics.collected()[0].message),
    content="Expected struct type.",
  )
  inspect(
    @typing.lookup_array_type(tc, ctx.diagnostics, id("f")) is None,
    content="true",
  )
  inspect(
    @message.to_plain_string(ctx.diagnostics.collected()[1].message),
    content="Expected array type.",
  )
  // A name nothing binds is reported by the lookup, not passed on silently.
  inspect(
    @typing.lookup_struct_type(tc, ctx.diagnostics, id("nope")) is None,
    content="true",
  )
  inspect(
    @message.to_plain_string(ctx.diagnostics.collected()[2].message),
    content="The type 'nope' is not bound.",
  )
}

///|
/// A packed field is not read at the width it is stored at: `i8` and `i16` come
/// off as i32, remembering how narrow they were so the lowering can pick the
/// signed or unsigned accessor. A write takes a plain i32, with nothing to
/// remember.
test "a packed field reads wider than it is stored" {
  let ctx = module_ctx()
  let tc = ctx.type_context
  fn read(
    f : @wasm_types.MutType[@wasm_types.StorageType[@ast.Ident]],
  ) -> String {
    match @typing.field_read_type(tc, ctx.diagnostics, f) {
      Some(c) => @infer.to_string(c)
      None => "unresolved"
    }
  }

  inspect(read({ mut_: false, typ: Packed(I8) }), content="i8")
  inspect(read({ mut_: false, typ: Packed(I16) }), content="i16")
  inspect(read({ mut_: false, typ: Value(F64) }), content="f64")
  // Written as a plain i32 either way.
  inspect(
    @typing.unpack_type({ mut_: false, typ: Packed(I8) }) is I32,
    content="true",
  )
  inspect(
    @typing.unpack_type({ mut_: false, typ: Value(F64) }) is F64,
    content="true",
  )
}

///|
/// A `..default` construction may leave out any field with a default. Numbers
/// default to zero; a reference only has one if it is nullable, because there
/// is no null to default a non-null reference to.
test "only a nullable reference field has a default" {
  fn has(t : @wasm_types.StorageType[@ast.Ident]) -> Bool {
    @typing.field_has_default({ mut_: false, typ: t })
  }

  inspect(has(Packed(I8)), content="true")
  inspect(has(Value(I32)), content="true")
  inspect(has(Value(V128)), content="true")
  inspect(has(Value(Ref({ nullable: true, typ: Any }))), content="true")
  inspect(has(Value(Ref({ nullable: false, typ: Any }))), content="false")
}

///|
/// A struct literal may omit its type name when the field set names exactly one
/// struct. Two structs sharing a field set make it ambiguous, and then the
/// literal has to say which it means.
test "a field set names a struct only when it names one uniquely" {
  let ctx = module_ctx()
  fn struct_(
    n : String,
    fields : Array[String],
    at : Int,
  ) -> @basic.Annotated[@ast.ModuleField[@basic.Location], @basic.Location] {
    {
      desc: Type([
        {
          desc: (
            id(n),
            {
              typ: Struct(
                fields.map(f => {
                  (
                    {
                      desc: (id(f), { mut_: false, typ: Value(I32) }),
                      info: loc_at(at, at + 1),
                    } :
                    @basic.Annotated[
                      (
                        @ast.Ident,
                        @wasm_types.MutType[@wasm_types.StorageType[@ast.Ident]],
                      ),
                      @basic.Location,
                    ])
                }),
              ),
              supertype: None,
              final_: true,
              descriptor: None,
              describes: None,
            },
          ),
          info: loc_at(at, at + 1),
        },
      ]),
      info: loc_at(at, at + 1),
    }
  }

  @typing.declare_fields(ctx, [
    struct_("point", ["x", "y"], 0),
    struct_("colour", ["r", "g", "b"], 10),
    struct_("also_rgb", ["r", "g", "b"], 20),
  ])
  fn named(fields : Array[String]) -> String {
    match @typing.infer_struct_by_fields(ctx, fields.map(f => id(f))) {
      Some(n) => n.name
      None => "ambiguous or unknown"
    }
  }

  inspect(named(["x", "y"]), content="point")
  // Order does not matter: the key is the field SET.
  inspect(named(["y", "x"]), content="point")
  // Two structs share this one.
  inspect(named(["r", "g", "b"]), content="ambiguous or unknown")
  inspect(named(["nothing"]), content="ambiguous or unknown")
}

///|
/// Wax writes memory and table operations as method calls, so a call has to be
/// classified before it can be typed. The classification is by method name and
/// RECEIVER together, never either alone: `size` on a memory counts pages,
/// `size` on a table counts elements, and a local named `mem` shadows the
/// memory entirely.
test "a method call is classified by its receiver as much as its name" {
  let ctx = module_ctx()
  ctx.memories.add(ctx.diagnostics, "mem", loc_at(0, 3), (0, I32))
  ctx.tables.add(
    ctx.diagnostics,
    "tab",
    loc_at(4, 7),
    (I32, { nullable: true, typ: Func }),
  )
  ctx.datas.add(ctx.diagnostics, "seg", loc_at(8, 11), ())
  fn kind(recv : String, meth : String) -> String {
    match @typing.classify_method_call(ctx, id(recv), meth) {
      Atomic(_) => "atomic"
      MemAccess => "mem access"
      SimdMemAccess => "simd access"
      MemManage => "mem manage"
      TableManage => "table manage"
      SegmentDrop => "segment drop"
      Ordinary => "ordinary"
    }
  }

  inspect(kind("mem", "load32"), content="mem access")
  inspect(kind("mem", "storef64"), content="mem access")
  inspect(kind("mem", "loadv128"), content="simd access")
  // The same name, two different operations, told apart by the receiver.
  inspect(kind("mem", "size"), content="mem manage")
  inspect(kind("tab", "size"), content="table manage")
  inspect(kind("seg", "drop"), content="segment drop")
  // A name no family claims.
  inspect(kind("mem", "frobnicate"), content="ordinary")
  // A receiver that is not a memory at all.
  inspect(kind("tab", "load32"), content="ordinary")
  // And a local shadows the memory, so the intrinsic is out of reach.
  @typing.bind_local(ctx, id("mem"), Some(@infer.i32_valtype))
  inspect(kind("mem", "load32"), content="ordinary")
}

///|
/// A continuation type wraps a function type, so answering what `resume` acts
/// on is two hops through the store: the reference names a continuation, the
/// continuation names a function.
test "a continuation names the function type it continues" {
  let ctx = module_ctx()
  let tc = ctx.type_context
  let info = () => tc.subtyping_info()
  fn declare_type(n : String, t : @ast.CompType, at : Int) -> Unit {
    let _ = @typing.add_type(tc, ctx.diagnostics, [
      {
        desc: (
          id(n),
          {
            typ: t,
            supertype: None,
            final_: true,
            descriptor: None,
            describes: None,
          },
        ),
        info: loc_at(at, at + 1),
      },
    ])
  }

  declare_type("ft", Func({ params: [], results: [] }), 0)
  declare_type("k", Cont(id("ft")), 2)
  declare_type("s", Struct([]), 4)
  fn wrapped(n : String) -> String {
    guard @typing.resolve_type_name(tc, ctx.diagnostics, id(n)) is Some(t) else {
      return "unbound"
    }
    match @typing.cont_functype(info(), Type(t)) {
      Some(_) => "a function type"
      None => "not a continuation"
    }
  }

  inspect(wrapped("k"), content="a function type")
  // A struct is not a continuation, and neither is a bare function type.
  inspect(wrapped("s"), content="not a continuation")
  inspect(wrapped("ft"), content="not a continuation")
}

///|
/// Function-type matching is contravariant in the parameters and covariant in
/// the results -- what is expected must accept everything the caller may pass,
/// and produce something the caller can use. It is the one rule that is easy to
/// write backwards, so both directions are pinned.
test "function types match contravariantly in their parameters" {
  let ctx = module_ctx()
  let info = ctx.type_context.subtyping_info()
  let anyref : @wasm_types.ValType[@type_store.Id] = Ref({
    nullable: true,
    typ: Any,
  })
  let eqref : @wasm_types.ValType[@type_store.Id] = Ref({
    nullable: true,
    typ: Eq,
  })
  fn ft(
    params : Array[@wasm_types.ValType[@type_store.Id]],
    results : Array[@wasm_types.ValType[@type_store.Id]],
  ) -> @type_store.FuncType[@type_store.Id] {
    { params, results }
  }

  // `eq` is a subtype of `any`.
  inspect(@type_store.val_subtype(info, eqref, anyref), content="true")
  // A function taking `any` can be used where one taking `eq` is expected: it
  // accepts more than it has to.
  inspect(
    @typing.functype_matches(info, ft([anyref], []), ft([eqref], [])),
    content="true",
  )
  // Not the other way round: one taking `eq` cannot accept every `any`.
  inspect(
    @typing.functype_matches(info, ft([eqref], []), ft([anyref], [])),
    content="false",
  )
  // Results go the other way: producing `eq` satisfies a promise of `any`.
  inspect(
    @typing.functype_matches(info, ft([], [eqref]), ft([], [anyref])),
    content="true",
  )
  inspect(
    @typing.functype_matches(info, ft([], [anyref]), ft([], [eqref])),
    content="false",
  )
  // Arities have to agree exactly.
  inspect(
    @typing.functype_matches(info, ft([anyref], []), ft([], [])),
    content="false",
  )
}

///|
/// The alignment is a PROMISE, not a request: it tells the engine the address
/// is already aligned so the access can skip a check. Promising more than the
/// access needs is unverifiable and rejected; promising less merely forgoes an
/// optimisation and is allowed.
test "an alignment may not claim more than the access can use" {
  fn complain(meth : String, align : String) -> String {
    let d = @diagnostic.collector()
    @typing.check_memarg(
      d,
      I32,
      @typing.mem_natural_align(meth),
      Some({ desc: Int(align), info: loc_at(0, 2) }),
      None,
    )
    if d.collected().is_empty() {
      "accepted"
    } else {
      @message.to_plain_string(d.collected()[0].message)
    }
  }

  // Exactly natural, and below it.
  inspect(complain("load32", "4"), content="accepted")
  inspect(complain("load32", "1"), content="accepted")
  inspect(complain("load32", "2"), content="accepted")
  // Above natural: a guarantee the access cannot use.
  inspect(
    complain("load32", "8"),
    content="The memory alignment is larger than the natural alignment 4.",
  )
  // A narrow access has a narrow natural alignment.
  inspect(
    complain("load8", "2"),
    content="The memory alignment is larger than the natural alignment 1.",
  )
  // Not a power of two. Checked after the bound, so one that is both reports as
  // too large -- the more specific complaint.
  inspect(
    complain("load64", "3"),
    content="The memory alignment should be a power of two.",
  )
  inspect(
    complain("load8", "3"),
    content="The memory alignment is larger than the natural alignment 1.",
  )
}

///|
/// The offset is bounded by the ADDRESS TYPE rather than by the access: on a
/// 32-bit memory an offset at or past 2^32 can never name a reachable address,
/// whatever the base.
test "an offset is bounded by what the address type can reach" {
  fn complain(at : @wasm_types.AddressType, offset : String) -> String {
    let d = @diagnostic.collector()
    @typing.check_memarg(
      d,
      at,
      4,
      None,
      Some({ desc: Int(offset), info: loc_at(0, 2) }),
    )
    if d.collected().is_empty() {
      "accepted"
    } else {
      @message.to_plain_string(d.collected()[0].message)
    }
  }

  inspect(complain(I32, "4294967295"), content="accepted")
  inspect(
    complain(I32, "4294967296"),
    content="The memory offset should be less than 0x100000000.",
  )
  // A 64-bit memory reaches further, so the same offset is fine.
  inspect(complain(I64, "4294967296"), content="accepted")
  // Past u64 it is not an offset at all.
  inspect(
    complain(I64, "18446744073709551616"),
    content="This memory offset or alignment must fit a 64-bit unsigned integer.",
  )
}

///|
/// The two immediates are checked independently, because they are two separate
/// things the author wrote and either can be wrong on its own.
test "a bad offset and a bad alignment are both reported" {
  let d = @diagnostic.collector()
  @typing.check_memarg(
    d,
    I32,
    4,
    Some({ desc: Int("8"), info: loc_at(10, 12) }),
    Some({ desc: Int("4294967296"), info: loc_at(0, 2) }),
  )
  inspect(
    d.collected().map(x => @message.to_plain_string(x.message)).join(" / "),
    content="The memory offset should be less than 0x100000000. / The memory alignment is larger than the natural alignment 4.",
  )
}

///|
/// A lane index's bound comes from the OPCODE, not from the operand. A `v128`
/// is sixteen bytes however it is being read, so the same value on the stack
/// admits sixteen lanes under one shape and two under another.
test "a lane bound comes from the shape, not the value" {
  fn bound(imm : @simd.Imm) -> String {
    match @typing.lane_bound(imm) {
      Some(n) => n.to_string()
      None => "no immediate"
    }
  }

  inspect(bound(Lane(I8x16)), content="16")
  inspect(bound(Lane(I16x8)), content="8")
  inspect(bound(Lane(I32x4)), content="4")
  inspect(bound(Lane(F64x2)), content="2")
  // A shuffle names lanes across TWO vectors at once.
  inspect(bound(Shuffle), content="32")
  inspect(bound(NoImm), content="no immediate")
  // A memory access derives its bound from the width it moves: one byte into
  // one of sixteen byte lanes, eight bytes into one of two.
  inspect(@typing.mem_lane_bound(1), content="16")
  inspect(@typing.mem_lane_bound(8), content="2")
}

///|
/// A lane index has to be a constant integer -- there is no opcode for a
/// computed lane, so a non-literal is not a slower lane selection, it is not
/// one at all.
test "a lane index must be a literal in range" {
  fn complain(bound : Int, lane : @ast.InstrDesc[@basic.Location]) -> String {
    let d = @diagnostic.collector()
    @typing.check_lane_immediate(d, bound, { desc: lane, info: loc_at(0, 2) })
    if d.collected().is_empty() {
      "accepted"
    } else {
      @message.to_plain_string(d.collected()[0].message)
    }
  }

  inspect(complain(16, Int("0")), content="accepted")
  inspect(complain(16, Int("15")), content="accepted")
  inspect(
    complain(16, Int("16")),
    content="The lane index should be less than 16.",
  )
  inspect(
    complain(2, Int("2")),
    content="The lane index should be less than 2.",
  )
  // Rejected here rather than left to overflow: it would otherwise reach the
  // code generator, which parses it and crashes.
  inspect(
    complain(16, Int("18446744073709551616")),
    content="The lane index should be less than 16.",
  )
  // Not a literal at all.
  inspect(
    complain(16, Get({ name: "n", loc: loc_at(0, 1) })),
    content="Only integer literals are allowed here.",
  )
}

///|
/// Every AST constructor now has an arm, so the dispatcher's match is total
/// WITHOUT a catch-all -- adding a constructor is a compile error here rather
/// than a silent gap. What `gaps` reports now is a different thing: a lowering
/// whose typed form could not be peeled back to the construct it came from,
/// which only happens when recovery from an error inside it produced a shape
/// the lowering never emits.
test "the dispatcher has an arm for every construct" {
  let ctx = module_ctx()
  ctx.memories.add(ctx.diagnostics, "mem", loc_at(0, 3), (0, I32))
  @typing.bind_local(ctx, id("x"), Some(@infer.i32_valtype))
  let checker = @typing.Checker::new(ctx, @typing.Operands::new())
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  // A spread of constructs from every family, none of which is a gap.
  let sample : Array[@ast.InstrDesc[@basic.Location]] = [
    Int("1"),
    Nop,
    Get(id("x")),
    Select(instr(Int("1"), 0), instr(Int("2"), 2), instr(Int("3"), 4)),
    ArrayFixed(None, [instr(Int("1"), 0)]),
    Suspend(id("tag"), []),
    IfAnnotation(
      cond=Var({ desc: "debug", info: loc_at(0, 5) }),
      then_body={ desc: [instr(Nop, 0)], info: loc_at(0, 3) },
      else_body=None,
    ),
    ContNew(id("k"), instr(Null, 0)),
    Switch(id("k"), id("t"), []),
    Throw(id("t"), []),
    Return(None),
  ]
  for d in sample {
    let _ = checker.statement(instr(d, 6))
  }
  inspect(checker.gaps().length(), content="0")
}

///|
/// The arms that are written: literals, `nop`, `unreachable`, a variable read,
/// and a sequence whose values are its last statement's.
test "the dispatcher types what it has arms for" {
  let ctx = module_ctx()
  ctx.globals.add(
    ctx.diagnostics,
    "g",
    loc_at(0, 1),
    (false, Some(@infer.f64_valtype)),
  )
  let ops = @typing.Operands::new()
  let checker = @typing.Checker::new(ctx, ops)
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  fn typed(d : @ast.InstrDesc[@basic.Location]) -> String {
    checker.statement(instr(d, 0)).info.0
    .map(t => @infer.to_string(t))
    .join(",")
  }

  inspect(typed(Int("1")), content="number")
  inspect(typed(Float("1.5")), content="float")
  inspect(typed(Char('a')), content="i32")
  inspect(typed(Null), content="null")
  inspect(typed(Nop), content="")
  inspect(typed(Get({ name: "g", loc: loc_at(0, 1) })), content="f64")
  // A sequence is a tuple: one value per element, in order.
  inspect(
    typed(
      Sequence([
        instr(Int("1"), 0),
        instr(Get({ name: "g", loc: loc_at(0, 1) }), 2),
      ]),
    ),
    content="number,f64",
  )
  // `unreachable` leaves nothing, and marks everything after it dead.
  inspect(typed(Unreachable), content="")
  inspect(ops.stack is Unreachable, content="true")
  inspect(checker.gaps().length(), content="0")
}

///|
/// A qualified intrinsic name is a call target, not a value, and a labelled
/// argument means something only in a memory access. Both recover rather than
/// stopping.
test "a misplaced name or label is reported and recovered from" {
  let ctx = module_ctx()
  let checker = @typing.Checker::new(ctx, @typing.Operands::new())
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  let _ = checker.statement(
    instr(
      Path({ name: "atomic", loc: loc_at(0, 6) }, {
        name: "fence",
        loc: loc_at(8, 13),
      }),
      0,
    ),
  )
  inspect(
    @message.to_plain_string(ctx.diagnostics.collected()[0].message),
    content="The qualified name 'atomic::fence' can only be used as a function call.",
  )
  // The label is reported, and the expression it labelled is still typed.
  let labelled = checker.statement(
    instr(
      Labelled({ name: "offset", loc: loc_at(0, 6) }, instr(Int("16"), 8)),
      0,
    ),
  )
  inspect(
    @message.to_plain_string(ctx.diagnostics.collected()[1].message),
    content="Labelled arguments are only allowed for the 'offset', 'align' and 'lane' immediates of a memory access.",
  )
  inspect(
    labelled.info.0.map(t => @infer.to_string(t)).join(","),
    content="number",
  )
}

///|
/// The block constructs, through the dispatcher. A block's parameters come off
/// the enclosing stack and go onto its own; its results come back to the
/// enclosing one.
test "a block takes its parameters and leaves its results" {
  let ctx = module_ctx()
  let ops = @typing.Operands::new()
  let checker = @typing.Checker::new(ctx, ops)
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  // `block (i32) -> f64 { 1.5 }`, given an i32.
  let checked = checker.statement(
    instr(
      Block(
        label=Some(id("out")),
        typ={
          params: [{ desc: (None, I32), info: loc_at(0, 1) }],
          results: [F64],
        },
        block={ desc: [instr(Float("1.5"), 20)], info: loc_at(20, 21) },
      ),
      10,
    ),
  )
  // The parameter was never supplied, so the input check says so -- and that is
  // the enclosing stack being read, which is the point.
  inspect(ctx.diagnostics.collected().length() > 0, content="true")
  inspect(checked.info.0.map(t => @infer.to_string(t)).join(","), content="f64")
  // The body's own instruction is annotated, and the literal was pinned to the
  // block's declared result by the output check.
  guard! checked.desc is Block(block~, ..)
  inspect(
    block.desc[0].info.0.map(t => @infer.to_string(t)).join(","),
    content="f64",
  )
  inspect(checker.gaps().length(), content="0")
}

///|
/// An `if` consumes its condition from the ENCLOSING stack, before the block is
/// entered -- the condition is not one of the block's parameters.
///
/// And with no `else` the false path falls straight through, which is sound
/// only when the parameters already are the results.
test "an if consumes its condition and needs an else to produce a value" {
  fn run(
    results : Array[@wasm_types.ValType[@ast.Ident]],
    with_else : Bool,
  ) -> String {
    let ctx = module_ctx()
    let checker = @typing.Checker::new(ctx, @typing.Operands::new())
    fn instr(
      d : @ast.InstrDesc[@basic.Location],
      at : Int,
    ) -> @ast.Instr[@basic.Location] {
      {
        desc: d,
        info: loc_at(at, at + 1),
        hints: { branch: None, freq: None, targets: None },
        expected: None,
      }
    }

    let body = if results.is_empty() { [] } else { [instr(Int("1"), 30)] }
    let _ = checker.statement(
      instr(
        If(
          label=None,
          typ={ params: [], results },
          cond=instr(Int("1"), 20),
          if_block={ desc: body, info: loc_at(30, 31) },
          else_block=if with_else {
            Some({ desc: body, info: loc_at(40, 41) })
          } else {
            None
          },
        ),
        10,
      ),
    )
    ctx.diagnostics
    .collected()
    .map(d => @message.to_plain_string(d.message))
    .join(" / ")
  }

  // Void, no else: nothing promised, nothing to deliver.
  inspect(run([], false), content="")
  // Produces a value, with an else: both paths deliver.
  inspect(run([I32], true), content="")
  // Produces a value, no else: the false path never produces it.
  inspect(
    run([I32], false),
    content="This 'if' must produce a value and so requires an 'else' branch.",
  )
}

///|
/// A block whose declared shape does not resolve still has its body walked --
/// the instructions inside are annotated -- but is not checked against a shape
/// nobody has. The failure was reported by the resolver, and the poison keeps
/// the enclosing scope quiet.
test "a block with an unresolvable shape still annotates its body" {
  let ctx = module_ctx()
  let checker = @typing.Checker::new(ctx, @typing.Operands::new())
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  let checked = checker.statement(
    instr(
      Block(
        label=None,
        typ={
          params: [],
          results: [Ref({ nullable: true, typ: Type(id("nope")) })],
        },
        block={ desc: [instr(Int("1"), 20)], info: loc_at(20, 21) },
      ),
      10,
    ),
  )
  inspect(
    @message.to_plain_string(ctx.diagnostics.collected()[0].message),
    content="The type 'nope' is not bound.",
  )
  // One report, not a cascade.
  inspect(ctx.diagnostics.collected().length(), content="1")
  inspect(checked.info.0[0].get() is Error, content="true")
  guard! checked.desc is Block(block~, ..)
  inspect(
    block.desc[0].info.0.map(t => @infer.to_string(t)).join(","),
    content="number",
  )
}

///|
/// The branch family, through the dispatcher. A `br` ends the block, so
/// everything after it is dead; a `br_if` does not, so the values it did not
/// deliver stay on the stack.
test "a br ends control and a br_if does not" {
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  // Inside a block labelled `out` producing an i32.
  fn in_block(
    body : Array[@ast.Instr[@basic.Location]],
  ) -> (@typing_env.ModuleContext, @typing.Operands, @typing.Checker) {
    let ctx = module_ctx()
    let ops = @typing.Operands::new()
    let checker = @typing.Checker::new(ctx, ops)
    let _ = checker.statement(
      instr(
        Block(label=Some(id("out")), typ={ params: [], results: [I32] }, block={
          desc: body,
          info: loc_at(90, 91),
        }),
        10,
      ),
    )
    (ctx, ops, checker)
  }

  // `br $out 1` -- delivers an i32, and control never returns.
  let (ctx, _, checker) = in_block([
    instr(Br(id("out"), Some(instr(Int("1"), 20))), 20),
  ])
  inspect(ctx.diagnostics.collected().length(), content="0")
  inspect(checker.gaps().length(), content="0")

  // `br $out` with nothing, where the target wants a value.
  let (ctx2, _, _) = in_block([instr(Br(id("out"), None), 20)])
  inspect(
    @message.to_plain_string(ctx2.diagnostics.collected()[0].message),
    content="This instruction provides 0 value(s) but 1 was/were expected.",
  )
}

///|
/// A `br_if` takes its condition LAST, because that is the order the values are
/// pushed in and the condition is the one on top. Everything below it is what
/// the branch delivers -- and, since the branch may not be taken, what stays on
/// the stack.
test "a br_if takes its condition last and passes the rest through" {
  let ctx = module_ctx()
  let ops = @typing.Operands::new()
  let checker = @typing.Checker::new(ctx, ops)
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  // Inside a block producing an f64: `br_if $out (1.5, 1)`.
  let checked = checker.statement(
    instr(
      Block(label=Some(id("out")), typ={ params: [], results: [F64] }, block={
        desc: [
          instr(
            BrIf(
              id("out"),
              instr(
                Sequence([instr(Float("1.5"), 20), instr(Int("1"), 24)]),
                20,
              ),
            ),
            20,
          ),
        ],
        info: loc_at(90, 91),
      }),
      10,
    ),
  )
  inspect(checker.gaps().length(), content="0")
  inspect(checked.info.0.map(t => @infer.to_string(t)).join(","), content="f64")
}

///|
/// A `br_table`'s value count is ONE fact about the instruction, so it is
/// reported once against the first bound target rather than once per target.
/// And an unbound target is reported at its own span without imposing a shape.
test "a br_table reports its arity once, whatever the targets" {
  let ctx = module_ctx()
  let ops = @typing.Operands::new()
  let checker = @typing.Checker::new(ctx, ops)
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  // Two targets wanting one value each; the table provides only the index.
  let _ = checker.statement(
    instr(
      Block(label=Some(id("a")), typ={ params: [], results: [I32] }, block={
        desc: [
          instr(
            Block(label=Some(id("b")), typ={ params: [], results: [I32] }, block={
              desc: [
                instr(BrTable([id("a"), id("b")], instr(Int("0"), 40)), 40),
              ],
              info: loc_at(80, 81),
            }),
            30,
          ),
        ],
        info: loc_at(90, 91),
      }),
      10,
    ),
  )
  let counts = ctx.diagnostics
    .collected()
    .map(d => @message.to_plain_string(d.message))
    .filter(m => m.has_prefix("This instruction provides"))
  // One arity complaint, not one per target.
  inspect(counts.length(), content="1")
  inspect(checker.gaps().length(), content="0")
}

///|
/// A `select`'s two branch values join exactly as the values reaching a block's
/// exit do -- same fold, so a flexible literal is pinned by whatever it is
/// chosen alongside. The condition is typed LAST, in emission order, because a
/// `select` pops it last.
test "a select joins its two branches" {
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  fn select(
    a : @ast.InstrDesc[@basic.Location],
    b : @ast.InstrDesc[@basic.Location],
  ) -> (String, String) {
    let ctx = module_ctx()
    let checker = @typing.Checker::new(ctx, @typing.Operands::new())
    let checked = checker.statement(
      instr(Select(instr(Int("1"), 0), instr(a, 4), instr(b, 8)), 20),
    )
    (
      checked.info.0.map(t => @infer.to_string(t)).join(","),
      ctx.diagnostics
      .collected()
      .map(d => @message.to_plain_string(d.message))
      .join(" / "),
    )
  }

  // Two flexible literals stay flexible together.
  inspect(select(Int("1"), Int("2")).0, content="number")
  // A literal chosen alongside a float commits to the float side.
  inspect(select(Int("1"), Float("1.5")).0, content="float")
  // A null and an integer have nothing in common.
  let (ty, msg) = select(Int("1"), Null)
  // Recovered as `Error`, which RENDERS as `any`: an already-reported failure
  // shows the permissive type rather than inventing a second complaint.
  inspect(ty, content="any")
  inspect(
    msg,
    content="The two branches of this select have no common supertype, so its result type cannot be inferred.",
  )
}

///|
/// `return`, `throw` and `throw_ref` all leave the function or the frame, so
/// each ends control -- everything after is dead.
test "the raising forms end control" {
  let ctx = module_ctx()
  let ops = @typing.Operands::new()
  ctx.enter_function(return_types=[@infer.valtype_cell(@infer.i32_valtype)])
  ctx.tags.add(ctx.diagnostics, "oops", loc_at(0, 4), {
    params: [{ desc: (None, F64), info: loc_at(0, 1) }],
    results: [],
  })
  let checker = @typing.Checker::new(ctx, ops)
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  // `return 1`, against a function returning i32.
  let _ = checker.statement(instr(Return(Some(instr(Int("1"), 20))), 10))
  inspect(ops.stack is Unreachable, content="true")
  inspect(ctx.diagnostics.collected().length(), content="0")

  // `return` with nothing, where the function promises a value.
  let ops2 = @typing.Operands::new()
  let checker2 = @typing.Checker::new(ctx, ops2)
  let _ = checker2.statement(instr(Return(None), 10))
  inspect(
    @message.to_plain_string(ctx.diagnostics.collected()[0].message),
    content="This instruction provides 0 value(s) but 1 was/were expected.",
  )

  // `throw oops(1.5)` -- the argument is checked against the tag's parameter.
  let ops3 = @typing.Operands::new()
  let checker3 = @typing.Checker::new(ctx, ops3)
  let before = ctx.diagnostics.collected().length()
  let _ = checker3.statement(
    instr(Throw(id("oops"), [instr(Float("1.5"), 20)]), 10),
  )
  inspect(ctx.diagnostics.collected().length() - before, content="0")
  inspect(ops3.stack is Unreachable, content="true")
  inspect(checker3.gaps().length(), content="0")
}

///|
/// A binary operator is typed by how many of its operands are still abstract.
/// With both concrete there is only validation; with one abstract the other's
/// type is merged onto it; with both abstract the operator's own default is.
///
/// The merging is why this mutates rather than returning a verdict: an operand
/// left `Unknown` would lower at the i32 default while the result was pinned to
/// another width -- an incoherent instruction.
test "an operator's default types operands nothing else constrains" {
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  fn binop(
    op : @ast.BinOp,
    a : @ast.InstrDesc[@basic.Location],
    b : @ast.InstrDesc[@basic.Location],
  ) -> (String, String, String) {
    let ctx = module_ctx()
    let checker = @typing.Checker::new(ctx, @typing.Operands::new())
    let a_ = instr(a, 0)
    let b_ = instr(b, 4)
    let checked = checker.statement(
      instr(BinOpI({ desc: op, info: loc_at(2, 3) }, a_, b_), 0),
    )
    guard! checked.desc is BinOpI(_, ca, cb)
    (
      checked.info.0.map(t => @infer.to_string(t)).join(","),
      ca.info.0.map(t => @infer.to_string(t)).join(",") +
      "/" +
      cb.info.0.map(t => @infer.to_string(t)).join(","),
      ctx.diagnostics
      .collected()
      .map(d => @message.to_plain_string(d.message))
      .join(" / "),
    )
  }

  // Two flexible literals added: still flexible, and merged so a later pin
  // moves both.
  inspect(binop(Add, Int("1"), Int("2")).0, content="number")
  // A bitwise operator commits them to integers -- it has no float form.
  inspect(binop(And, Int("1"), Int("2")).0, content="int")
  // An unsigned division likewise.
  inspect(binop(Div(Some(Unsigned)), Int("1"), Int("2")).0, content="int")
  // A float division commits them the other way.
  inspect(binop(Div(None), Int("1"), Int("2")).0, content="float")
  // A comparison yields i32 whatever its operands were.
  inspect(binop(Lt(Some(Signed)), Int("1"), Int("2")).0, content="i32")
  // And it pins the operands to integers on the way.
  inspect(binop(Lt(Some(Signed)), Int("1"), Int("2")).1, content="int/int")
  // A float comparison takes a large literal AS a float: it is a numeric
  // literal, so it is float-capable.
  inspect(
    binop(Lt(None), Int("4294967296"), Float("1.5")).1,
    content="float/float",
  )
  // A signed comparison forces the same literal to i64 instead: it cannot be
  // an i32, and this is an integer operation.
  inspect(
    binop(Lt(Some(Signed)), Int("4294967296"), Int("1")).1,
    content="i64/i64",
  )
}

///|
/// Adding a float to a null has no meaning, and the complaint points at the
/// OPERATOR: each operand is fine on its own, and it is the combination that
/// is not.
test "a binary operator blames itself, not its operands" {
  let ctx = module_ctx()
  let checker = @typing.Checker::new(ctx, @typing.Operands::new())
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  let _ = checker.statement(
    instr(
      BinOpI(
        { desc: Add, info: loc_at(2, 3) },
        instr(Float("1.5"), 0),
        instr(Null, 4),
      ),
      0,
    ),
  )
  inspect(
    @message.to_plain_string(ctx.diagnostics.collected()[0].message),
    content="This operator cannot be applied to operands of types 'float' and 'null'.",
  )
  // At the operator's own span, not the whole expression's.
  inspect(ctx.diagnostics.collected()[0].loc.start.cnum, content="2")
  inspect(checker.gaps().length(), content="0")
}

///|
/// A unary `-` preserves width, so its result IS the operand's cell rather than
/// a fresh one. A disconnected cell would let the operand stay unconstrained
/// and lower at the i32 default while the result was pinned to another width --
/// an `i32.sub` annotated as an f64 negation.
test "a negation shares its operand's cell" {
  let ctx = module_ctx()
  let checker = @typing.Checker::new(ctx, @typing.Operands::new())
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  let operand = instr(Int("1"), 4)
  let checked = checker.statement(
    instr(UnOpI({ desc: Neg, info: loc_at(0, 1) }, operand), 0),
  )
  guard! checked.desc is UnOpI(_, inner)
  let result = checked.info.0[0]
  let inner_ty = inner.info.0[0]
  inspect(@infer.to_string(result), content="number")
  // Pinning the result pins the operand, because they are one cell.
  result.set(Valtype(@infer.f64_valtype))
  inspect(@infer.to_string(inner_ty), content="f64")
  inspect(checker.gaps().length(), content="0")
}

///|
/// `!` is `i32.eqz` on an integer and `ref.is_null` on a reference, so it takes
/// both -- and yields i32 either way.
test "a not takes an integer or a reference" {
  fn unop(op : @ast.UnOp, operand : @ast.InstrDesc[@basic.Location]) -> String {
    let ctx = module_ctx()
    let checker = @typing.Checker::new(ctx, @typing.Operands::new())
    fn instr(
      d : @ast.InstrDesc[@basic.Location],
      at : Int,
    ) -> @ast.Instr[@basic.Location] {
      {
        desc: d,
        info: loc_at(at, at + 1),
        hints: { branch: None, freq: None, targets: None },
        expected: None,
      }
    }

    let inner = instr(operand, 4)
    let checked = checker.statement(
      instr(UnOpI({ desc: op, info: loc_at(0, 1) }, inner), 0),
    )
    guard! checked.desc is UnOpI(_, c)
    // Result, operand, and anything reported -- one line, so the three move
    // together when they are meant to.
    checked.info.0.map(t => @infer.to_string(t)).join(",") +
    " | " +
    c.info.0.map(t => @infer.to_string(t)).join(",") +
    " | " +
    ctx.diagnostics
    .collected()
    .map(d => @message.to_plain_string(d.message))
    .join(" / ")
  }

  // An integer: `i32.eqz`, and the flexible literal commits to an integer.
  inspect(unop(Not, Int("1")), content="i32 | int | ")
  // A reference: `ref.is_null`, and nothing to commit.
  inspect(unop(Not, Null), content="i32 | null | ")
  // A large literal is `i64.eqz`, pinned there because there is no float eqz
  // for it to stay float-capable for.
  inspect(unop(Not, Int("4294967296")), content="i32 | i64 | ")
  // A float has no `eqz` at all.
  inspect(
    unop(Not, Float("1.5")),
    content="i32 | float | This expression has type 'float' but is expected to have type 'int'.",
  )
}

///|
/// Assignment resolves its target FIRST -- a pure lookup -- so the value can be
/// checked against the target's type. The local is marked initialized only
/// after the value is typed, so `x = x + 1` still sees its pre-assignment
/// state.
test "an assignment checks its value against the target" {
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  // A mutable f64 global, assigned an integer literal.
  let ctx = module_ctx()
  ctx.globals.add(
    ctx.diagnostics,
    "g",
    loc_at(0, 1),
    (true, Some(@infer.f64_valtype)),
  )
  let checker = @typing.Checker::new(ctx, @typing.Operands::new())
  let value = instr(Int("1"), 10)
  let checked = checker.statement(instr(Set(id("g"), None, value), 4))
  // Assignment leaves nothing on the stack.
  inspect(checked.info.0.length(), content="0")
  // The literal was pinned to the target's type.
  guard! checked.desc is Set(_, _, v)
  inspect(v.info.0.map(t => @infer.to_string(t)).join(","), content="f64")
  inspect(ctx.diagnostics.collected().length(), content="0")
  // Writing it records the global as actually assigned, which is what the
  // unnecessary-mut warning reads.
  inspect(ctx.assigned_globals.contains("g"), content="true")
  inspect(checker.gaps().length(), content="0")

  // An immutable global cannot be written.
  let ctx2 = module_ctx()
  ctx2.globals.add(
    ctx2.diagnostics,
    "k",
    loc_at(0, 1),
    (false, Some(@infer.i32_valtype)),
  )
  let checker2 = @typing.Checker::new(ctx2, @typing.Operands::new())
  let _ = checker2.statement(instr(Set(id("k"), None, instr(Int("1"), 10)), 4))
  inspect(
    @message.to_plain_string(ctx2.diagnostics.collected()[0].message),
    content="This global is immutable and cannot be assigned.",
  )
}

///|
/// A compound `x op= e` is checked as `x = x op e` -- so the operator validates
/// against the target's type through the ordinary arithmetic path, and the
/// desugared READ is what reports an unbound name, not the write.
test "a compound assignment reports an unbound name once" {
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  let ctx = module_ctx()
  let checker = @typing.Checker::new(ctx, @typing.Operands::new())
  let _ = checker.statement(
    instr(
      Set(
        id("nope"),
        Some({ desc: Add, info: loc_at(6, 8) }),
        instr(Int("1"), 10),
      ),
      4,
    ),
  )
  // One report, from the read -- not two.
  inspect(
    ctx.diagnostics
    .collected()
    .map(d => @message.to_plain_string(d.message))
    .join(" / "),
    content="The variable 'nope' is not bound.",
  )
  // A plain assignment to an unbound name reports at the write instead.
  let ctx2 = module_ctx()
  let checker2 = @typing.Checker::new(ctx2, @typing.Operands::new())
  let _ = checker2.statement(
    instr(Set(id("nope"), None, instr(Int("1"), 10)), 4),
  )
  inspect(ctx2.diagnostics.collected().length(), content="1")
}

///|
/// A `tee` assigns AND leaves the value, so it produces the TARGET's type
/// rather than the operand's -- and only a local is assignable that way.
test "a tee produces its target's type" {
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  let ctx = module_ctx()
  @typing.bind_local(ctx, id("x"), Some(@infer.f64_valtype))
  let checker = @typing.Checker::new(ctx, @typing.Operands::new())
  let checked = checker.statement(instr(Tee(id("x"), instr(Int("1"), 10)), 4))
  inspect(checked.info.0.map(t => @infer.to_string(t)).join(","), content="f64")
  inspect(ctx.diagnostics.collected().length(), content="0")
  // And the local now holds a value.
  inspect(ctx.initialized_locals.contains("x"), content="true")

  // A global is not tee-able.
  let ctx2 = module_ctx()
  ctx2.globals.add(
    ctx2.diagnostics,
    "g",
    loc_at(0, 1),
    (true, Some(@infer.i32_valtype)),
  )
  let checker2 = @typing.Checker::new(ctx2, @typing.Operands::new())
  let _ = checker2.statement(instr(Tee(id("g"), instr(Int("1"), 10)), 4))
  inspect(
    @message.to_plain_string(ctx2.diagnostics.collected()[0].message),
    content="'g' cannot be assigned.",
  )
}

///|
/// A `let` with an annotation gives the local the ANNOTATION's type, not the
/// initializer's -- which is the point of writing one: it may be wider than
/// what the initializer happens to produce.
///
/// Without one the local takes the value's own type, resolved to a width,
/// because a local has to have one even where the value has not committed.
test "a let takes its annotation's type, or resolves the value's" {
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  fn bound(
    annot : @wasm_types.ValType[@ast.Ident]?,
    init : @ast.InstrDesc[@basic.Location],
  ) -> String {
    let ctx = module_ctx()
    let checker = @typing.Checker::new(ctx, @typing.Operands::new())
    let _ = checker.statement(
      instr(Let([(Some(id("x")), annot)], Some(instr(init, 10))), 0),
    )
    match ctx.locals.get("x") {
      Some((Some(v), _)) => @infer.to_string(@infer.valtype_cell(v))
      Some((None, _)) => "poison"
      None => "unbound"
    }
  }

  // Annotated: the local is f64 even though the literal would default to i32.
  inspect(bound(Some(F64), Int("1")), content="f64")
  // Unannotated: the literal resolves to its own default width.
  inspect(bound(None, Int("1")), content="i32")
  inspect(bound(None, Float("1.5")), content="f64")
  // A large literal defaults to i64, not i32.
  inspect(bound(None, Int("4294967296")), content="i64")
}

///|
/// A multi-value initializer feeds its values to the names left to right, and a
/// count mismatch is reported at the initializer.
test "a tuple let matches names to values in order" {
  let ctx = module_ctx()
  ctx.globals.add(
    ctx.diagnostics,
    "g",
    loc_at(0, 1),
    (false, Some(@infer.f64_valtype)),
  )
  let checker = @typing.Checker::new(ctx, @typing.Operands::new())
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  // Two names take a two-element tuple, left to right.
  let _ = checker.statement(
    instr(
      Let(
        [(Some(id("a")), None), (Some(id("b")), None)],
        Some(
          instr(Sequence([instr(Get(id("g")), 10), instr(Char('x'), 14)]), 10),
        ),
      ),
      0,
    ),
  )
  inspect(ctx.diagnostics.collected().length(), content="0")
  fn bound(n : String) -> String {
    match ctx.locals.get(n) {
      Some((Some(v), _)) => @infer.to_string(@infer.valtype_cell(v))
      _ => "poison"
    }
  }

  inspect(bound("a"), content="f64")
  inspect(bound("b"), content="i32")

  // One value short of the names, and the shortfall is reported once: the
  // leftover name takes poison rather than a guess.
  let _ = checker.statement(
    instr(
      Let(
        [(Some(id("c")), None), (Some(id("d")), None)],
        Some(instr(Get(id("g")), 20)),
      ),
      0,
    ),
  )
  inspect(
    @message.to_plain_string(ctx.diagnostics.collected()[0].message),
    content="This instruction provides 1 value(s) but 2 was/were expected.",
  )
  inspect(bound("c"), content="f64")
  inspect(bound("d"), content="poison")
  inspect(checker.gaps().length(), content="0")
}

///|
/// `let x: t;` declares a local with no initializer. Whether it starts holding
/// a value is decided by the type: a defaultable one has a zero to start at, a
/// non-nullable reference does not and stays uninitialized until assigned.
test "a bare declaration starts initialized only if it can" {
  fn declared(typ : @wasm_types.ValType[@ast.Ident]) -> String {
    let ctx = module_ctx()
    let checker = @typing.Checker::new(ctx, @typing.Operands::new())
    let _ = checker.statement({
      desc: Let([(Some(id("x")), Some(typ))], None),
      info: loc_at(0, 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    })
    if ctx.locals.contains("x") {
      if ctx.initialized_locals.contains("x") {
        "holds a value"
      } else {
        "declared, uninitialized"
      }
    } else {
      "not declared"
    }
  }

  inspect(declared(I32), content="holds a value")
  inspect(declared(Ref({ nullable: true, typ: Any })), content="holds a value")
  inspect(
    declared(Ref({ nullable: false, typ: Any })),
    content="declared, uninitialized",
  )
}

///|
/// A field READ produces the packed width remembered -- `Int8`/`Int16` -- while
/// a field WRITE takes a plain i32. That asymmetry is the whole packed story,
/// and this is where it reaches an instruction.
test "a struct access reads packed and writes plain" {
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  fn with_point() -> (@typing_env.ModuleContext, @typing.Checker) {
    let ctx = module_ctx()
    let _ = @typing.add_type(ctx.type_context, ctx.diagnostics, [
      {
        desc: (
          id("point"),
          {
            typ: Struct([
              {
                desc: (id("x"), { mut_: true, typ: Packed(I8) }),
                info: loc_at(0, 1),
              },
              {
                desc: (id("y"), { mut_: false, typ: Value(F64) }),
                info: loc_at(2, 3),
              },
            ]),
            supertype: None,
            final_: true,
            descriptor: None,
            describes: None,
          },
        ),
        info: loc_at(0, 5),
      },
    ])
    @typing.bind_local(
      ctx,
      id("p"),
      @typing.internalize_valtype(
        ctx.type_context,
        ctx.diagnostics,
        Ref({ nullable: false, typ: Type(id("point")) }),
      ),
    )
    (ctx, @typing.Checker::new(ctx, @typing.Operands::new()))
  }

  // A packed read remembers how narrow it was, so the lowering can pick the
  // signed or unsigned accessor.
  let (ctx, checker) = with_point()
  let read = checker.statement(
    instr(StructGet(instr(Get(id("p")), 0), id("x")), 4),
  )
  inspect(read.info.0.map(t => @infer.to_string(t)).join(","), content="i8")
  inspect(ctx.diagnostics.collected().length(), content="0")
  inspect(checker.gaps().length(), content="0")

  // A write takes a plain i32, so an integer literal is accepted.
  let (ctx2, checker2) = with_point()
  let _ = checker2.statement(
    instr(StructSet(instr(Get(id("p")), 0), id("x"), instr(Int("1"), 10)), 4),
  )
  inspect(ctx2.diagnostics.collected().length(), content="0")

  // An immutable field cannot be written.
  let (ctx3, checker3) = with_point()
  let _ = checker3.statement(
    instr(
      StructSet(instr(Get(id("p")), 0), id("y"), instr(Float("1.5"), 10)),
      4,
    ),
  )
  inspect(
    @message.to_plain_string(ctx3.diagnostics.collected()[0].message),
    content="This field is immutable and cannot be assigned.",
  )

  // A field the type does not declare.
  let (ctx4, checker4) = with_point()
  let _ = checker4.statement(
    instr(StructGet(instr(Get(id("p")), 0), id("z")), 4),
  )
  inspect(
    @message.to_plain_string(ctx4.diagnostics.collected()[0].message),
    content="There is no field named 'z'.",
  )

  // A name that is an instruction method was almost certainly meant as a call.
  let (ctx5, checker5) = with_point()
  let _ = checker5.statement(
    instr(StructGet(instr(Int("1"), 0), id("sqrt")), 4),
  )
  inspect(
    @message.to_plain_string(ctx5.diagnostics.collected()[0].message),
    content="'sqrt' is an instruction method and must be called with parentheses, as 'sqrt()'.",
  )
}

///|
/// An array index is checked against i32, and the element type comes from the
/// array's own declaration.
test "an array index reads its element type" {
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  let ctx = module_ctx()
  let _ = @typing.add_type(ctx.type_context, ctx.diagnostics, [
    {
      desc: (
        id("bytes"),
        {
          typ: Array({ mut_: true, typ: Packed(I8) }),
          supertype: None,
          final_: true,
          descriptor: None,
          describes: None,
        },
      ),
      info: loc_at(0, 5),
    },
  ])
  @typing.bind_local(
    ctx,
    id("b"),
    @typing.internalize_valtype(
      ctx.type_context,
      ctx.diagnostics,
      Ref({ nullable: false, typ: Type(id("bytes")) }),
    ),
  )
  let checker = @typing.Checker::new(ctx, @typing.Operands::new())
  let read = checker.statement(
    instr(ArrayGet(instr(Get(id("b")), 0), instr(Int("0"), 10)), 4),
  )
  inspect(read.info.0.map(t => @infer.to_string(t)).join(","), content="i8")
  inspect(ctx.diagnostics.collected().length(), content="0")

  // Indexing something that is not an array.
  let checker2 = @typing.Checker::new(ctx, @typing.Operands::new())
  let _ = checker2.statement(
    instr(ArrayGet(instr(Int("1"), 0), instr(Int("0"), 10)), 4),
  )
  inspect(
    @message.to_plain_string(ctx.diagnostics.collected()[0].message),
    content="Expected array.",
  )
  inspect(checker2.gaps().length(), content="0")
}

///|
/// A struct literal can omit its type name when the field SET names exactly one
/// struct. Field inference takes precedence over anything else, because the
/// fields name the exact struct being constructed.
test "a struct literal finds its type from its fields" {
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  fn ctx_with_point() -> @typing_env.ModuleContext {
    let ctx = module_ctx()
    let fields : Array[
      @basic.Annotated[
        (@ast.Ident, @wasm_types.MutType[@wasm_types.StorageType[@ast.Ident]]),
        @basic.Location,
      ],
    ] = [
      { desc: (id("x"), { mut_: false, typ: Value(I32) }), info: loc_at(0, 1) },
      { desc: (id("y"), { mut_: false, typ: Value(F64) }), info: loc_at(2, 3) },
    ]
    let module_ : @ast.Module[@basic.Location] = [
      {
        desc: Type([
          {
            desc: (
              id("point"),
              {
                typ: Struct(fields),
                supertype: None,
                final_: true,
                descriptor: None,
                describes: None,
              },
            ),
            info: loc_at(0, 5),
          },
        ]),
        info: loc_at(0, 5),
      },
    ]
    @typing.declare_fields(ctx, module_)
    ctx
  }

  // No name written: the fields find `point`, and each value is checked against
  // its declared type -- so the literals pin to i32 and f64.
  let ctx = ctx_with_point()
  let checker = @typing.Checker::new(ctx, @typing.Operands::new())
  let checked = checker.statement(
    instr(
      Struct(None, [
        (id("x"), Some(instr(Int("1"), 10))),
        (id("y"), Some(instr(Int("2"), 14))),
      ]),
      0,
    ),
  )
  inspect(ctx.diagnostics.collected().length(), content="0")
  inspect(
    checked.info.0.map(t => @infer.to_string(t)).join(","),
    content="&point",
  )
  guard! checked.desc is Struct(_, fs)
  inspect(
    fs
    .map(f => f.1.unwrap().info.0.map(t => @infer.to_string(t)).join(","))
    .join(" | "),
    content="i32 | f64",
  )
  inspect(checker.gaps().length(), content="0")

  // Fields that name no struct at all.
  let ctx2 = ctx_with_point()
  let checker2 = @typing.Checker::new(ctx2, @typing.Operands::new())
  let _ = checker2.statement(
    instr(Struct(None, [(id("nope"), Some(instr(Int("1"), 10)))]), 0),
  )
  inspect(
    @message.to_plain_string(ctx2.diagnostics.collected()[0].message),
    content="Cannot infer the struct type here; add an explicit type, as in '{T| ..}'.",
  )

  // A named literal missing one of the type's fields.
  let ctx3 = ctx_with_point()
  let checker3 = @typing.Checker::new(ctx3, @typing.Operands::new())
  let _ = checker3.statement(
    instr(Struct(Some(id("point")), [(id("x"), Some(instr(Int("1"), 10)))]), 0),
  )
  inspect(
    @message.to_plain_string(ctx3.diagnostics.collected()[0].message),
    content="There is no field named 'y'.",
  )
}

///|
/// A punned field -- `{x}` for `{x: x}` -- stands for the like-named variable,
/// and stays punned in the typed AST so the printer re-emits it that way. The
/// pun is a spelling, not a different construct.
test "a punned field is typed as a read and stays punned" {
  let ctx = module_ctx()
  let fields : Array[
    @basic.Annotated[
      (@ast.Ident, @wasm_types.MutType[@wasm_types.StorageType[@ast.Ident]]),
      @basic.Location,
    ],
  ] = [
    { desc: (id("x"), { mut_: false, typ: Value(F64) }), info: loc_at(0, 1) },
  ]
  let module_ : @ast.Module[@basic.Location] = [
    {
      desc: Type([
        {
          desc: (
            id("box"),
            {
              typ: Struct(fields),
              supertype: None,
              final_: true,
              descriptor: None,
              describes: None,
            },
          ),
          info: loc_at(0, 5),
        },
      ]),
      info: loc_at(0, 5),
    },
  ]
  @typing.declare_fields(ctx, module_)
  @typing.bind_local(ctx, id("x"), Some(@infer.f64_valtype))
  let checker = @typing.Checker::new(ctx, @typing.Operands::new())
  let checked = checker.statement({
    desc: Struct(Some(id("box")), [(id("x"), None)]),
    info: loc_at(0, 1),
    hints: { branch: None, freq: None, targets: None },
    expected: None,
  })
  inspect(ctx.diagnostics.collected().length(), content="0")
  // The local was read -- so the pun really was checked.
  inspect(ctx.read_locals.length(), content="1")
  // And it is still a pun in the output.
  guard! checked.desc is Struct(_, fs)
  inspect(fs[0].1 is None, content="true")
}

///|
/// A `..default` construction needs every field to have a zero to start at. A
/// non-nullable reference does not, and the complaint is made once for the
/// TYPE rather than once per offending field.
test "a default construction needs every field to have a zero" {
  fn defaults(ref_nullable : Bool) -> String {
    let ctx = module_ctx()
    let fields : Array[
      @basic.Annotated[
        (@ast.Ident, @wasm_types.MutType[@wasm_types.StorageType[@ast.Ident]]),
        @basic.Location,
      ],
    ] = [
      {
        desc: (
          id("a"),
          { mut_: false, typ: Value(Ref({ nullable: ref_nullable, typ: Any })) },
        ),
        info: loc_at(0, 1),
      },
      {
        desc: (
          id("b"),
          { mut_: false, typ: Value(Ref({ nullable: ref_nullable, typ: Eq })) },
        ),
        info: loc_at(2, 3),
      },
    ]
    let module_ : @ast.Module[@basic.Location] = [
      {
        desc: Type([
          {
            desc: (
              id("holder"),
              {
                typ: Struct(fields),
                supertype: None,
                final_: true,
                descriptor: None,
                describes: None,
              },
            ),
            info: loc_at(0, 5),
          },
        ]),
        info: loc_at(0, 5),
      },
    ]
    @typing.declare_fields(ctx, module_)
    let checker = @typing.Checker::new(ctx, @typing.Operands::new())
    let _ = checker.statement({
      desc: StructDefault(Some(id("holder"))),
      info: loc_at(0, 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    })
    ctx.diagnostics
    .collected()
    .map(d => @message.to_plain_string(d.message))
    .join(" / ")
  }

  // Nullable references have a null to default to.
  inspect(defaults(true), content="")
  // Non-nullable ones do not -- and it is said once, though both fields fail.
  inspect(
    defaults(false),
    content="This type has no default value for all its fields.",
  )
}

///|
/// The array constructions. The element type is resolved BEFORE the values are
/// typed, so a nested literal among them can be inferred from it -- and so the
/// values are pinned to the element type rather than to their own defaults.
test "an array construction pins its elements to the element type" {
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  fn ctx_with(
    elem : @wasm_types.StorageType[@ast.Ident],
  ) -> @typing_env.ModuleContext {
    let ctx = module_ctx()
    let module_ : @ast.Module[@basic.Location] = [
      {
        desc: Type([
          {
            desc: (
              id("arr"),
              {
                typ: Array({ mut_: true, typ: elem }),
                supertype: None,
                final_: true,
                descriptor: None,
                describes: None,
              },
            ),
            info: loc_at(0, 5),
          },
        ]),
        info: loc_at(0, 5),
      },
    ]
    @typing.declare_fields(ctx, module_)
    ctx
  }

  // `[arr| 1.5; 3]` -- the initializer is checked against f64, the count i32.
  let ctx = ctx_with(Value(F64))
  let checker = @typing.Checker::new(ctx, @typing.Operands::new())
  let made = checker.statement(
    instr(Array(Some(id("arr")), instr(Int("1"), 10), instr(Int("3"), 14)), 0),
  )
  inspect(ctx.diagnostics.collected().length(), content="0")
  inspect(made.info.0.map(t => @infer.to_string(t)).join(","), content="&arr")
  guard! made.desc is Array(_, init, size)
  inspect(
    init.info.0.map(t => @infer.to_string(t)).join(",") +
    "/" +
    size.info.0.map(t => @infer.to_string(t)).join(","),
    content="f64/i32",
  )
  inspect(checker.gaps().length(), content="0")

  // A fixed array pins every element the same way, and a packed element takes
  // the plain i32 a write uses.
  let ctx2 = ctx_with(Packed(I8))
  let checker2 = @typing.Checker::new(ctx2, @typing.Operands::new())
  let fixed = checker2.statement(
    instr(
      ArrayFixed(Some(id("arr")), [instr(Int("1"), 10), instr(Int("2"), 14)]),
      0,
    ),
  )
  inspect(ctx2.diagnostics.collected().length(), content="0")
  guard! fixed.desc is ArrayFixed(_, elems)
  inspect(
    elems.map(e => e.info.0.map(t => @infer.to_string(t)).join(",")).join(" | "),
    content="i32 | i32",
  )

  // With no type name there is nothing to check against, and it is said once.
  let ctx3 = ctx_with(Value(F64))
  let checker3 = @typing.Checker::new(ctx3, @typing.Operands::new())
  let _ = checker3.statement(instr(ArrayFixed(None, [instr(Int("1"), 10)]), 0))
  inspect(
    ctx3.diagnostics
    .collected()
    .map(d => @message.to_plain_string(d.message))
    .join(" / "),
    content="Cannot infer the array type here; add an explicit type, as in '[T| ..]'.",
  )
}

///|
/// A `..default` array starts every element at its zero, so the element type
/// must have one -- a non-nullable reference does not.
test "a default array needs an element type with a zero" {
  fn defaults(nullable : Bool) -> String {
    let ctx = module_ctx()
    let module_ : @ast.Module[@basic.Location] = [
      {
        desc: Type([
          {
            desc: (
              id("arr"),
              {
                typ: Array({
                  mut_: true,
                  typ: Value(Ref({ nullable, typ: Any })),
                }),
                supertype: None,
                final_: true,
                descriptor: None,
                describes: None,
              },
            ),
            info: loc_at(0, 5),
          },
        ]),
        info: loc_at(0, 5),
      },
    ]
    @typing.declare_fields(ctx, module_)
    let checker = @typing.Checker::new(ctx, @typing.Operands::new())
    let _ = checker.statement({
      desc: ArrayDefault(Some(id("arr")), {
        desc: Int("4"),
        info: loc_at(10, 11),
        hints: { branch: None, freq: None, targets: None },
        expected: None,
      }),
      info: loc_at(0, 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    })
    ctx.diagnostics
    .collected()
    .map(d => @message.to_plain_string(d.message))
    .join(" / ")
  }

  inspect(defaults(true), content="")
  inspect(
    defaults(false),
    content="This type has no default value for all its fields.",
  )
}

///|
/// Under single-inheritance subtyping two heap types share a value only when
/// one is a subtype of the other -- so unrelated types make a cast always trap
/// and a test always false, unless a shared `null` slips through both.
test "an unrelated cast can never succeed" {
  let ctx = module_ctx()
  fn ref_(
    nullable : Bool,
    h : @wasm_types.HeapType[@ast.Ident],
    ih : @wasm_types.HeapType[@type_store.Id],
  ) -> @infer.InferredType {
    Valtype({
      typ: Ref({ nullable, typ: h }),
      internal: Ref({ nullable, typ: ih }),
      anon_comptype: None,
    })
  }

  fn lint(
    op : @infer.InferredType,
    target : @infer.InferredType,
    is_test : Bool,
  ) -> String {
    let c = module_ctx()
    @typing.lint_ref_cast(c, loc_at(0, 4), is_test~, op, target)
    c.diagnostics
    .collected()
    .map(d => @message.to_plain_string(d.message))
    .join(" / ")
  }

  ignore(ctx)
  let struct_ = ref_(false, Struct, Struct)
  let array_ = ref_(false, Array, Array)
  let any_ = ref_(false, Any, Any)
  // A struct is never an array: neither is a subtype of the other.
  inspect(
    lint(struct_, array_, false),
    content="This cast always traps: the value can never have this type.",
  )
  inspect(
    lint(struct_, array_, true),
    content="This type test is always false: the value can never have this type.",
  )
  // Related types are fine: narrowing `any` to `struct` may or may not succeed.
  inspect(lint(any_, struct_, false), content="")
  // Widening the other way is redundant -- the value already has that type.
  inspect(
    lint(struct_, any_, false),
    content="This cast is redundant: the value already has this type.",
  )
  inspect(
    lint(struct_, any_, true),
    content="This type test is always true: the value already has this type.",
  )
  // Two NULLABLE unrelated references still share one value: null. So the cast
  // is not impossible, only very likely to trap.
  inspect(
    lint(ref_(true, Struct, Struct), ref_(true, Array, Array), false),
    content="",
  )
  // `any` <-> `extern` is the lossless cross-hierarchy convert, not a cast: it
  // never traps and is never redundant, so linting it either way would be a
  // false positive.
  inspect(lint(any_, ref_(false, Extern, Extern), false), content="")
  inspect(lint(ref_(false, Extern, Extern), any_, false), content="")
}

///|
/// Only the INNERMOST always-trapping cast of a chain is reported: a cast over
/// a value that can never be produced is unreachable, and what it says merely
/// follows from the inner verdict. The fix belongs at the inner cast.
test "a chain of trapping casts is reported once" {
  let ctx = module_ctx()
  fn ref_(
    h : @wasm_types.HeapType[@ast.Ident],
    ih : @wasm_types.HeapType[@type_store.Id],
  ) -> @infer.InferredType {
    Valtype({
      typ: Ref({ nullable: false, typ: h }),
      internal: Ref({ nullable: false, typ: ih }),
      anon_comptype: None,
    })
  }

  let inner = loc_at(0, 10)
  let outer = loc_at(0, 20)
  // The inner cast traps.
  @typing.lint_ref_cast(
    ctx,
    inner,
    is_test=false,
    ref_(Struct, Struct),
    ref_(Array, Array),
  )
  // The outer one, over that operand, also would -- but says nothing.
  @typing.lint_ref_cast(
    ctx,
    outer,
    is_test=false,
    ref_(Array, Array),
    ref_(Func, Func),
    operand_location=Some(inner),
  )
  inspect(ctx.diagnostics.collected().length(), content="1")
  inspect(ctx.diagnostics.collected()[0].loc.end.cnum, content="10")
  // A third cast over the second stays quiet too: the span was recorded whether
  // or not the report came out.
  @typing.lint_ref_cast(
    ctx,
    loc_at(0, 30),
    is_test=false,
    ref_(Func, Func),
    ref_(Extern, Extern),
    operand_location=Some(outer),
  )
  inspect(ctx.diagnostics.collected().length(), content="1")
}

///|
/// The cast arms, through the dispatcher. A cast produces its TARGET's type; a
/// test produces i32 whatever it asked; a non-null assertion produces the
/// non-null form of what it was given.
test "a cast produces its target and a test produces an answer" {
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  fn typed(d : @ast.InstrDesc[@basic.Location]) -> String {
    let ctx = module_ctx()
    @typing.bind_local(
      ctx,
      id("r"),
      @typing.internalize_valtype(
        ctx.type_context,
        ctx.diagnostics,
        Ref({ nullable: true, typ: Any }),
      ),
    )
    let checker = @typing.Checker::new(ctx, @typing.Operands::new())
    let c = checker.statement(instr(d, 0))
    c.info.0.map(t => @infer.to_string(t)).join(",") +
    " | " +
    checker.gaps().length().to_string()
  }

  // A numeric cast produces exactly the named type.
  inspect(
    typed(
      Cast(
        instr(Float("1.5"), 4),
        Signed(typ=I32, signage=Signed, strict=false),
      ),
    ),
    content="i32 | 0",
  )
  // A reference cast produces the target reference.
  inspect(
    typed(
      Cast(instr(Get(id("r")), 4), Value(Ref({ nullable: false, typ: Struct }))),
    ),
    content="&struct | 0",
  )
  // A test always answers with an i32.
  inspect(
    typed(Test(instr(Get(id("r")), 4), { nullable: false, typ: Struct })),
    content="i32 | 0",
  )
  // A non-null assertion strips the nullability and keeps the heap type.
  inspect(typed(NonNull(instr(Get(id("r")), 4))), content="&any | 0")
  // On a bare null it is the INFERENCE bottom `&_`, not the concrete `&none`:
  // it is a subtype of every reference type, so any consumer is satisfied, and
  // it only concretizes when something makes it commit.
  inspect(typed(NonNull(instr(Null, 4))), content="&_ | 0")
}

///|
/// An inline `&fn(..)` cast target mints a function type, so the target has an
/// index to point at. The name is unwritable, and the renderer shows the
/// composite type rather than the synthesized name.
test "an inline function cast target mints a type" {
  let ctx = module_ctx()
  @typing.bind_local(
    ctx,
    id("f"),
    @typing.internalize_valtype(
      ctx.type_context,
      ctx.diagnostics,
      Ref({ nullable: true, typ: Func }),
    ),
  )
  let checker = @typing.Checker::new(ctx, @typing.Operands::new())
  let checked = checker.statement({
    desc: Cast(
      {
        desc: Get(id("f")),
        info: loc_at(4, 5),
        hints: { branch: None, freq: None, targets: None },
        expected: None,
      },
      Func(nullable=false, sign={ params: [], results: [I32] }),
    ),
    info: loc_at(0, 1),
    hints: { branch: None, freq: None, targets: None },
    expected: None,
  })
  inspect(ctx.diagnostics.collected().length(), content="0")
  // Rendered by its shape, not by the generated name.
  inspect(
    checked.info.0.map(t => @infer.to_string(t)).join(","),
    // By its SHAPE, not by the generated name -- which is what `anon_comptype`
    // is carried for.
    content="fn() -> i32",
  )
  inspect(checker.gaps().length(), content="0")
}

///|
/// A string literal builds a byte array. Its natural type is the canonical
/// `<string>` array -- and because that is CANONICAL, a user type declared with
/// the same shape interns to the same index, so a bare string is a genuine use
/// of it even though it names nothing.
test "a string builds the canonical byte array" {
  let ctx = module_ctx()
  let module_ : @ast.Module[@basic.Location] = [
    {
      desc: Type([
        {
          desc: (
            id("bytes"),
            {
              // The same shape as `<string>`: mutable i8.
              typ: Array({ mut_: true, typ: Packed(I8) }),
              supertype: None,
              final_: true,
              descriptor: None,
              describes: None,
            },
          ),
          info: loc_at(0, 5),
        },
      ]),
      info: loc_at(0, 5),
    },
  ]
  @typing.declare_fields(ctx, module_)
  // Both names reach the same interned type.
  inspect(
    @typing.resolve_type_name(ctx.type_context, ctx.diagnostics, id("bytes")) ==
    @typing.resolve_type_name(ctx.type_context, ctx.diagnostics, {
      name: "<string>",
      loc: loc_at(0, 1),
    }),
    content="true",
  )
  let checker = @typing.Checker::new(ctx, @typing.Operands::new())
  let checked = checker.statement({
    desc: Str(None, b"hi"),
    info: loc_at(0, 4),
    hints: { branch: None, freq: None, targets: None },
    expected: None,
  })
  inspect(ctx.diagnostics.collected().length(), content="0")
  inspect(
    checked.info.0.map(t => @infer.to_string(t)).join(","),
    // Rendered by its SHAPE: the generated `<string>` name means nothing to a
    // reader, so `anon_comptype` shows the array instead.
    content="[mut i8]",
  )
  // Recorded as a canonical reference -- a use nobody wrote a name for.
  inspect(ctx.canonical_type_references.length(), content="1")
  inspect(checker.gaps().length(), content="0")
}

///|
/// A string may name another array type, and then the element type decides what
/// it may contain: bytes take anything, code units must decode as text, and
/// anything else is not a string's array at all.
test "a string's element type decides what it may hold" {
  fn build(
    elem : @wasm_types.StorageType[@ast.Ident],
    bytes : Bytes,
  ) -> String {
    let ctx = module_ctx()
    let module_ : @ast.Module[@basic.Location] = [
      {
        desc: Type([
          {
            desc: (
              id("chars"),
              {
                typ: Array({ mut_: true, typ: elem }),
                supertype: None,
                final_: true,
                descriptor: None,
                describes: None,
              },
            ),
            info: loc_at(0, 5),
          },
        ]),
        info: loc_at(0, 5),
      },
    ]
    @typing.declare_fields(ctx, module_)
    let checker = @typing.Checker::new(ctx, @typing.Operands::new())
    let _ = checker.statement({
      desc: Str(Some(id("chars")), bytes),
      info: loc_at(0, 4),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    })
    ctx.diagnostics
    .collected()
    .map(d => @message.to_plain_string(d.message))
    .join(" / ")
  }

  // Bytes hold anything.
  inspect(build(Packed(I8), b"\xff\xfe"), content="")
  // Code units hold text.
  inspect(build(Packed(I16), b"hi"), content="")
  inspect(
    build(Packed(I16), b"\xff\xfe"),
    content="A string building an [i16] array must be a valid Unicode string.",
  )
  // Anything else is not a string's array.
  inspect(
    build(Value(F64), b"hi"),
    content="A string literal can only build an [i8] or [i16] array.",
  )
}

///|
/// An array built from a segment names a segment -- and WHICH segment space it
/// names is decided by the array's element type. A reference element makes it
/// an element segment, anything else a data segment. The same written name
/// means different things in the two.
test "a segment array picks its segment space by element type" {
  fn build(elem : @wasm_types.StorageType[@ast.Ident]) -> String {
    let ctx = module_ctx()
    let module_ : @ast.Module[@basic.Location] = [
      {
        desc: Type([
          {
            desc: (
              id("arr"),
              {
                typ: Array({ mut_: true, typ: elem }),
                supertype: None,
                final_: true,
                descriptor: None,
                describes: None,
              },
            ),
            info: loc_at(0, 5),
          },
        ]),
        info: loc_at(0, 5),
      },
    ]
    @typing.declare_fields(ctx, module_)
    // Only a DATA segment named `s` exists.
    ctx.datas.add(ctx.diagnostics, "s", loc_at(0, 1), ())
    let checker = @typing.Checker::new(ctx, @typing.Operands::new())
    fn instr(
      d : @ast.InstrDesc[@basic.Location],
      at : Int,
    ) -> @ast.Instr[@basic.Location] {
      {
        desc: d,
        info: loc_at(at, at + 1),
        hints: { branch: None, freq: None, targets: None },
        expected: None,
      }
    }

    let _ = checker.statement(
      instr(
        ArraySegment(
          Some(id("arr")),
          id("s"),
          instr(Int("0"), 10),
          instr(Int("4"), 14),
        ),
        0,
      ),
    )
    ctx.diagnostics
    .collected()
    .map(d => @message.to_plain_string(d.message))
    .join(" / ")
  }

  // A numeric element looks in the data segments, and finds it.
  inspect(build(Packed(I8)), content="")
  inspect(build(Value(I32)), content="")
  // A reference element looks in the ELEMENT segments, where there is none.
  inspect(
    build(Value(Ref({ nullable: true, typ: Func }))),
    content="The element segment 's' is not bound.",
  )
}

///|
/// A descriptor lookup follows the type's `descriptor` clause, and exactness
/// carries through: the descriptor of an EXACT reference is itself exact, since
/// the type is known and so is its descriptor.
test "a descriptor lookup follows the clause and keeps exactness" {
  fn ctx_with_pair() -> @typing_env.ModuleContext {
    let ctx = @typing_env.ModuleContext::new(
      @diagnostic.collector(),
      @type_store.TypeStore::new(),
      @feature.configure([(CustomDescriptors, true)]),
    )
    let _ = @typing.add_type(ctx.type_context, ctx.diagnostics, [
      {
        desc: (
          id("obj"),
          {
            typ: Struct([]),
            supertype: None,
            final_: true,
            descriptor: Some(id("desc")),
            describes: None,
          },
        ),
        info: loc_at(0, 3),
      },
      {
        desc: (
          id("desc"),
          {
            typ: Struct([]),
            supertype: None,
            final_: true,
            descriptor: None,
            describes: Some(id("obj")),
          },
        ),
        info: loc_at(4, 8),
      },
    ])
    ctx
  }

  fn described(exact : Bool) -> String {
    let ctx = ctx_with_pair()
    @typing.bind_local(
      ctx,
      id("o"),
      @typing.internalize_valtype(
        ctx.type_context,
        ctx.diagnostics,
        Ref({
          nullable: false,
          typ: if exact {
            Exact(id("obj"))
          } else {
            Type(id("obj"))
          },
        }),
      ),
    )
    let checker = @typing.Checker::new(ctx, @typing.Operands::new())
    let c = checker.statement({
      desc: GetDescriptor({
        desc: Get(id("o")),
        info: loc_at(10, 11),
        hints: { branch: None, freq: None, targets: None },
        expected: None,
      }),
      info: loc_at(0, 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    })
    c.info.0.map(t => @infer.to_string(t)).join(",")
  }

  inspect(described(false), content="&desc")
  // Exact in, exact out.
  inspect(described(true), content="&!desc")
}

///|
/// A catch is a BRANCH: when the exception fires, control jumps to the named
/// label carrying the tag's payload. So the payload has to fit that label's
/// branch target, exactly as a `br`'s value does. The four clause forms differ
/// only in what they deliver.
test "a catch delivers its payload to the label it names" {
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  // A handler block taking what the catch delivers, wrapping a try_table.
  fn run(
    handler_results : Array[@wasm_types.ValType[@ast.Ident]],
    catches : Array[@ast.Catch],
  ) -> String {
    let ctx = module_ctx()
    ctx.tags.add(ctx.diagnostics, "oops", loc_at(0, 4), {
      params: [{ desc: (None, I32), info: loc_at(0, 1) }],
      results: [],
    })
    let checker = @typing.Checker::new(ctx, @typing.Operands::new())
    let _ = checker.statement(
      instr(
        Block(
          label=Some(id("h")),
          typ={ params: [], results: handler_results },
          block={
            desc: [
              instr(
                TryTable(
                  label=None,
                  typ={ params: [], results: [] },
                  catches~,
                  block={ desc: [], info: loc_at(60, 61) },
                ),
                30,
              ),
              // The handler block still has to produce its own result.
              instr(Unreachable, 70),
            ],
            info: loc_at(20, 21),
          },
        ),
        10,
      ),
    )
    ctx.diagnostics
    .collected()
    .map(d => @message.to_plain_string(d.message))
    .join(" / ")
  }

  // A plain catch delivers the tag's parameters: one i32.
  inspect(run([I32], [Catch(id("oops"), id("h"))]), content="")
  // A `_ref` catch appends the exception itself, so the handler can rethrow.
  inspect(
    run([I32, Ref({ nullable: false, typ: Exn })], [
      CatchRef(id("oops"), id("h")),
    ]),
    content="",
  )
  // A catch-all delivers nothing.
  inspect(run([], [CatchAll(id("h"))]), content="")
  // And a catch-all `_ref` delivers only the exception.
  inspect(
    run([Ref({ nullable: false, typ: Exn })], [CatchAllRef(id("h"))]),
    content="",
  )
  // Delivering one value to a handler that wants none is an arity complaint.
  inspect(
    run([], [Catch(id("oops"), id("h"))]),
    content="This instruction provides 1 value(s) but 0 was/were expected.",
  )
  // Delivering an i32 where the handler wants an f64 is a type complaint.
  inspect(
    run([F64], [Catch(id("oops"), id("h"))]),
    content="Catching this exception provides a value of type 'i32' but the handler's branch target expects 'f64'.",
  )
}

///|
/// A structured `try` gives each tag its own handler, entered on that tag's
/// payload and producing the try's results. The try's label is in scope in
/// every handler, so a `br` to it exits carrying the value.
test "a try handler is entered on its tag's payload" {
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  let ctx = module_ctx()
  ctx.tags.add(ctx.diagnostics, "oops", loc_at(0, 4), {
    params: [{ desc: (None, F64), info: loc_at(0, 1) }],
    results: [],
  })
  let checker = @typing.Checker::new(ctx, @typing.Operands::new())
  // `try { 1 } catch oops { <the f64 payload> }` producing an f64.
  let checked = checker.statement(
    instr(
      Try(
        label=Some(id("t")),
        typ={ params: [], results: [F64] },
        block={ desc: [instr(Float("1.5"), 20)], info: loc_at(20, 21) },
        catches=[(id("oops"), { desc: [], info: loc_at(40, 41) })],
        catch_all=None,
      ),
      10,
    ),
  )
  // The handler is entered on the payload and falls straight through with it,
  // which is exactly the try's result -- so nothing to complain about.
  inspect(ctx.diagnostics.collected().length(), content="0")
  inspect(checked.info.0.map(t => @infer.to_string(t)).join(","), content="f64")
  inspect(checker.gaps().length(), content="0")
}

///|
/// A `try`/`catch` chain's arms fall through into EACH OTHER: arm k completes
/// with arm k+1's entry stack, and the last completes with the try's results.
/// That chaining is the whole shape of the construct.
test "a try-catch arm completes into the next arm's entry" {
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  let ctx = module_ctx()
  ctx.tags.add(ctx.diagnostics, "a", loc_at(0, 1), {
    params: [{ desc: (None, I32), info: loc_at(0, 1) }],
    results: [],
  })
  ctx.tags.add(ctx.diagnostics, "b", loc_at(2, 3), {
    params: [{ desc: (None, I32), info: loc_at(2, 3) }],
    results: [],
  })
  let checker = @typing.Checker::new(ctx, @typing.Operands::new())
  // Arm `a` is entered on an i32 and must complete with arm `b`'s entry, which
  // is also an i32 -- so falling straight through is right.
  let checked = checker.statement(
    instr(
      TryCatch(
        label=Some(id("t")),
        typ={ params: [], results: [I32] },
        block={ desc: [instr(Int("1"), 20)], info: loc_at(20, 21) },
        arms=[
          {
            arm_tag: Some(id("a")),
            arm_ref: false,
            arm_types: [],
            arm_body: { desc: [], info: loc_at(40, 41) },
          },
          {
            arm_tag: Some(id("b")),
            arm_ref: false,
            arm_types: [],
            arm_body: { desc: [], info: loc_at(50, 51) },
          },
        ],
      ),
      10,
    ),
  )
  inspect(ctx.diagnostics.collected().length(), content="0")
  inspect(checked.info.0.map(t => @infer.to_string(t)).join(","), content="i32")
  inspect(checker.gaps().length(), content="0")

  // A parameterized one is rejected: expression position has no stack to take
  // parameters from.
  let ctx2 = module_ctx()
  let checker2 = @typing.Checker::new(ctx2, @typing.Operands::new())
  let _ = checker2.statement(
    instr(
      TryCatch(
        label=None,
        typ={ params: [{ desc: (None, I32), info: loc_at(0, 1) }], results: [] },
        block={ desc: [], info: loc_at(20, 21) },
        arms=[],
      ),
      10,
    ),
  )
  inspect(
    @message.to_plain_string(ctx2.diagnostics.collected()[0].message),
    content="A block, loop or if used as an expression cannot take parameters.",
  )
}

///|
/// A `while` is checked against its LOWERING rather than by rules of its own,
/// so the loop and the back edge it becomes are validated exactly as if they
/// had been written out -- and there is no second set of rules to drift from
/// the first. The high-level form is then rebuilt, so the formatter and the
/// code generator still see a `while`.
test "a while is checked as the loop it becomes" {
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  fn run(
    label : @ast.Ident?,
    step : @ast.InstrDesc[@basic.Location]?,
    cond : @ast.InstrDesc[@basic.Location],
  ) -> String {
    let ctx = module_ctx()
    @typing.bind_local(ctx, id("n"), Some(@infer.i32_valtype))
    let checker = @typing.Checker::new(ctx, @typing.Operands::new())
    let checked = checker.statement(
      instr(
        While(
          label~,
          cond=instr(cond, 20),
          step=step.map(sd => instr(sd, 30)),
          block={ desc: [instr(Nop, 40)], info: loc_at(40, 41) },
        ),
        10,
      ),
    )
    let shape = match checked.desc {
      While(cond~, step~, block~, ..) =>
        "cond=" +
        cond.info.0.map(t => @infer.to_string(t)).join(",") +
        " step=" +
        (if step is Some(_) { "yes" } else { "no" }) +
        " body=" +
        block.desc.length().to_string()
      _ => "not a while"
    }
    shape +
    " | " +
    ctx.diagnostics
    .collected()
    .map(d => @message.to_plain_string(d.message))
    .join(" / ") +
    " | " +
    checker.gaps().length().to_string()
  }

  // The plain form: condition, body, back edge.
  inspect(
    run(None, None, Get(id("n"))),
    content="cond=i32 step=no body=1 |  | 0",
  )
  // With a step, which sits between the body and the back edge.
  inspect(
    run(None, Some(Nop), Get(id("n"))),
    content="cond=i32 step=yes body=1 |  | 0",
  )
  // Labelled AND stepped: the body gets a block of its own, so the label has
  // something to name.
  inspect(
    run(Some(id("outer")), Some(Nop), Get(id("n"))),
    content="cond=i32 step=yes body=1 |  | 0",
  )
  // A non-i32 condition is caught by the lowered `if`, not by a rule of the
  // while's own -- which is the point of checking the lowering.
  inspect(
    run(None, None, Float("1.5")),
    content="cond=float step=no body=1 | This expression has type 'float' but is expected to have type 'i32'. | 0",
  )
}

///|
/// A `dispatch` is checked as the block ladder it becomes: the index must be an
/// i32, every `br_table` target must resolve, and each arm body must be
/// well-typed -- all of which the lowered form asks for on its own.
test "a dispatch is checked as the block ladder it becomes" {
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  let ctx = module_ctx()
  @typing.bind_local(ctx, id("k"), Some(@infer.i32_valtype))
  let checker = @typing.Checker::new(ctx, @typing.Operands::new())
  let checked = checker.statement(
    instr(
      Dispatch(
        index=instr(Get(id("k")), 20),
        cases=[id("a"), id("b")],
        default=id("d"),
        arms=[
          (id("a"), { desc: [instr(Nop, 30)], info: loc_at(30, 31) }),
          (id("b"), { desc: [instr(Nop, 40)], info: loc_at(40, 41) }),
          (id("d"), { desc: [instr(Nop, 50)], info: loc_at(50, 51) }),
        ],
      ),
      10,
    ),
  )
  inspect(ctx.diagnostics.collected().length(), content="0")
  inspect(checker.gaps().length(), content="0")
  // Peeled back to a dispatch, with the index typed and every arm body kept in
  // source order.
  guard! checked.desc is Dispatch(index~, arms~, ..)
  inspect(index.info.0.map(t => @infer.to_string(t)).join(","), content="i32")
  inspect(
    arms.map(a => a.0.name + ":" + a.1.desc.length().to_string()).join(","),
    content="a:1,b:1,d:1",
  )
}

///|
/// Two arms sharing a label would build ONE block in the lowering and lose the
/// other body entirely, so it is caught before that can happen.
test "a dispatch may not name one arm twice" {
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  let ctx = module_ctx()
  @typing.bind_local(ctx, id("k"), Some(@infer.i32_valtype))
  let checker = @typing.Checker::new(ctx, @typing.Operands::new())
  let _ = checker.statement(
    instr(
      Dispatch(
        index=instr(Get(id("k")), 20),
        cases=[id("a")],
        default=id("a"),
        arms=[
          (id("a"), { desc: [], info: loc_at(30, 31) }),
          (id("a"), { desc: [], info: loc_at(40, 41) }),
        ],
      ),
      10,
    ),
  )
  inspect(
    @message.to_plain_string(ctx.diagnostics.collected()[0].message),
    content="This dispatch has several cases named 'a'.",
  )
}

///|
/// `br_on_null` and `br_on_non_null` are mirrors. One branches when the
/// reference IS null and falls through with the non-null form; the other
/// branches when it is NOT and carries the non-null form to the target.
test "the null branches put the non-null form on opposite paths" {
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  // `br_on_null` inside a void block: the fall-through carries `&any`, the
  // non-null form of the `&?any` operand.
  let ctx = module_ctx()
  @typing.bind_local(
    ctx,
    id("v"),
    @typing.internalize_valtype(
      ctx.type_context,
      ctx.diagnostics,
      Ref({ nullable: true, typ: Any }),
    ),
  )
  let checker = @typing.Checker::new(ctx, @typing.Operands::new())
  let mut seen = ""
  let _ = checker.statement(
    instr(
      Block(label=Some(id("out")), typ={ params: [], results: [] }, block={
        desc: [
          instr(BrOnNull(id("out"), instr(Get(id("v")), 30)), 20),
          instr(Nop, 40),
        ],
        info: loc_at(20, 21),
      }),
      10,
    ),
  )
  // The `br_on_null` left one value -- the non-null reference -- which the
  // block's void exit then reports as a leftover. That IS the fall-through
  // value, and seeing it is the point.
  seen = ctx.diagnostics
    .collected()
    .map(d => @message.to_plain_string(d.message))
    .join(" / ")
  inspect(seen, content="This value remains on the stack.")
  inspect(checker.gaps().length(), content="0")
}

///|
/// A `br_on_null` on a bare `null` always branches, so its fall-through is
/// unreachable -- and the bottom reference, which satisfies any consumer, is
/// the well-defined answer rather than a contradiction.
test "a br_on_null on a bare null falls through to the bottom reference" {
  let ctx = module_ctx()
  let checker = @typing.Checker::new(ctx, @typing.Operands::new())
  let checked = checker.statement({
    desc: Block(label=Some(id("out")), typ={ params: [], results: [] }, block={
      desc: [
        {
          desc: BrOnNull(id("out"), {
            desc: Null,
            info: loc_at(30, 31),
            hints: { branch: None, freq: None, targets: None },
            expected: None,
          }),
          info: loc_at(20, 21),
          hints: { branch: None, freq: None, targets: None },
          expected: None,
        },
      ],
      info: loc_at(20, 21),
    }),
    info: loc_at(10, 11),
    hints: { branch: None, freq: None, targets: None },
    expected: None,
  })
  guard! checked.desc is Block(block~, ..)
  inspect(
    block.desc[0].info.0.map(t => @infer.to_string(t)).join(","),
    content="&_",
  )
  inspect(checker.gaps().length(), content="0")
}

///|
/// The reference-hierarchy lub: the piece `join_value_types` has been taking as
/// a parameter since the block-exit fold, because it is the only part of a join
/// that needs the type table.
test "the lub climbs to a common supertype, or finds none" {
  let ctx = module_ctx()
  // `dog <: animal <: struct`, and `rock` unrelated to both.
  let module_ : @ast.Module[@basic.Location] = [
    {
      desc: Type([
        {
          desc: (
            id("animal"),
            {
              typ: Struct([]),
              supertype: None,
              final_: false,
              descriptor: None,
              describes: None,
            },
          ),
          info: loc_at(0, 6),
        },
      ]),
      info: loc_at(0, 6),
    },
    {
      desc: Type([
        {
          desc: (
            id("dog"),
            {
              // A field of its own: two structurally identical types ARE the same
              // type after interning, which would make this test say nothing.
              typ: Struct([
                {
                  desc: (id("bark"), { mut_: false, typ: Value(I32) }),
                  info: loc_at(10, 11),
                },
              ]),
              supertype: Some(id("animal")),
              final_: true,
              descriptor: None,
              describes: None,
            },
          ),
          info: loc_at(10, 13),
        },
      ]),
      info: loc_at(10, 13),
    },
    {
      desc: Type([
        {
          desc: (
            id("cat"),
            {
              typ: Struct([
                {
                  desc: (id("purr"), { mut_: false, typ: Value(F64) }),
                  info: loc_at(20, 21),
                },
              ]),
              supertype: Some(id("animal")),
              final_: true,
              descriptor: None,
              describes: None,
            },
          ),
          info: loc_at(20, 23),
        },
      ]),
      info: loc_at(20, 23),
    },
    {
      desc: Type([
        {
          desc: (
            id("thing"),
            {
              typ: Array({ mut_: false, typ: Value(I32) }),
              supertype: None,
              final_: true,
              descriptor: None,
              describes: None,
            },
          ),
          info: loc_at(30, 35),
        },
      ]),
      info: loc_at(30, 35),
    },
  ]
  @typing.declare_fields(ctx, module_)
  fn lub(
    a : @wasm_types.HeapType[@ast.Ident],
    b : @wasm_types.HeapType[@ast.Ident],
  ) -> String {
    match @typing.heap_lub(ctx.type_context, a, b) {
      Some(h) =>
        @infer.to_string(
          @infer.Cell::make(
            Valtype({
              typ: Ref({ nullable: false, typ: h }),
              internal: Ref({ nullable: false, typ: Any }),
              anon_comptype: None,
            }),
          ),
        )
      None => "none"
    }
  }

  // Two siblings meet at their declared supertype.
  inspect(lub(Type(id("dog")), Type(id("cat"))), content="&animal")
  // A type and its own supertype meet at the supertype.
  inspect(lub(Type(id("dog")), Type(id("animal"))), content="&animal")
  // A struct and an array meet at `eq`, which is where the hierarchy joins.
  inspect(lub(Type(id("dog")), Type(id("thing"))), content="&eq")
  // The bottom of a hierarchy is below everything in it, so it yields the
  // other side rather than climbing past a named type to `struct`.
  inspect(lub(None_, Type(id("dog"))), content="&dog")
  // Different hierarchies share no value at all.
  inspect(lub(Type(id("dog")), Func), content="none")
  inspect(lub(Any, Extern), content="none")
  // Exactness survives only when both sides are the same exact type.
  inspect(lub(Exact(id("dog")), Exact(id("dog"))), content="&!dog")
  inspect(lub(Exact(id("dog")), Exact(id("cat"))), content="&animal")
}

///|
/// Nullability is the OR of the two sides: a value that may be null on either
/// side may be null in the result.
test "a lub is nullable if either side was" {
  let ctx = module_ctx()
  fn lub(n1 : Bool, n2 : Bool) -> String {
    match
      @typing.val_lub(
        ctx.type_context,
        Ref({ nullable: n1, typ: Struct }),
        Ref({ nullable: n2, typ: Array }),
      ) {
      Some(v) =>
        match
          @typing.internalize_valtype(ctx.type_context, ctx.diagnostics, v) {
          Some(iv) => @infer.to_string(@infer.valtype_cell(iv))
          None => "unresolved"
        }
      None => "none"
    }
  }

  inspect(lub(false, false), content="&eq")
  inspect(lub(true, false), content="&?eq")
  inspect(lub(false, true), content="&?eq")
  inspect(lub(true, true), content="&?eq")
}

///|
/// `br_on_cast` and `br_on_cast_fail` are mirrors. One branches when the cast
/// SUCCEEDS, carrying the target, and falls through with the residual; the
/// other branches when it FAILS, carrying the residual, and falls through with
/// the target.
test "the cast branches put target and residual on opposite paths" {
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  fn run(fail : Bool) -> String {
    let ctx = module_ctx()
    @typing.bind_local(
      ctx,
      id("v"),
      @typing.internalize_valtype(
        ctx.type_context,
        ctx.diagnostics,
        Ref({ nullable: true, typ: Any }),
      ),
    )
    let checker = @typing.Checker::new(ctx, @typing.Operands::new())
    let target : @wasm_types.RefType[@ast.Ident] = {
      nullable: false,
      typ: Struct,
    }
    let inner = instr(Get(id("v")), 30)
    let br = if fail {
      instr(BrOnCastFail(id("out"), target, inner), 20)
    } else {
      instr(BrOnCast(id("out"), target, inner), 20)
    }
    // A block whose label takes what the branch delivers.
    let checked = checker.statement(
      instr(
        Block(
          label=Some(id("out")),
          typ={
            params: [],
            results: [
              if fail {
                Ref({ nullable: true, typ: Any })
              } else {
                Ref({ nullable: false, typ: Struct })
              },
            ],
          },
          // `unreachable` after the branch, so the fall-through value the
          // branch left is absorbed by dead code rather than checked against
          // the block's result -- which is what the BRANCH delivers, not what
          // falls through.
          block={ desc: [br, instr(Unreachable, 50)], info: loc_at(20, 21) },
        ),
        10,
      ),
    )
    guard! checked.desc is Block(block~, ..)
    block.desc[0].info.0.map(t => @infer.to_string(t)).join(",") +
    " | " +
    ctx.diagnostics
    .collected()
    .map(d => @message.to_plain_string(d.message))
    .join(" / ")
  }

  // `br_on_cast`: the branch takes `&struct`, so the block's result is that.
  // The fall-through keeps the residual -- what an `&?any` is once a
  // non-null struct is taken out of it.
  inspect(run(false), content="&?any | ")
  // `br_on_cast_fail`: the branch takes the residual, so the block's result is
  // `&?any`, and the fall-through keeps the target.
  inspect(run(true), content="&struct | ")
}

///|
/// A continuation type has no surface cast syntax and its own hierarchy, so
/// naming one as a cast target is always a mistake.
test "a cast branch may not target a continuation" {
  let ctx = module_ctx()
  let module_ : @ast.Module[@basic.Location] = [
    {
      desc: Type([
        {
          desc: (
            id("ft"),
            {
              typ: Func({ params: [], results: [] }),
              supertype: None,
              final_: true,
              descriptor: None,
              describes: None,
            },
          ),
          info: loc_at(0, 2),
        },
      ]),
      info: loc_at(0, 2),
    },
    {
      desc: Type([
        {
          desc: (
            id("k"),
            {
              typ: Cont(id("ft")),
              supertype: None,
              final_: true,
              descriptor: None,
              describes: None,
            },
          ),
          info: loc_at(4, 5),
        },
      ]),
      info: loc_at(4, 5),
    },
  ]
  @typing.declare_fields(ctx, module_)
  @typing.bind_local(
    ctx,
    id("v"),
    @typing.internalize_valtype(
      ctx.type_context,
      ctx.diagnostics,
      Ref({ nullable: true, typ: Any }),
    ),
  )
  let checker = @typing.Checker::new(ctx, @typing.Operands::new())
  let _ = checker.statement({
    desc: BrOnCast(id("out"), { nullable: false, typ: Type(id("k")) }, {
      desc: Get(id("v")),
      info: loc_at(30, 31),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }),
    info: loc_at(20, 21),
    hints: { branch: None, freq: None, targets: None },
    expected: None,
  })
  inspect(
    @message.to_plain_string(ctx.diagnostics.collected()[0].message),
    content="Continuation types cannot be used in a cast instruction.",
  )
}

///|
/// A `match` is checked as the type-test ladder it becomes: the scrutinee is
/// threaded ONCE through a chain of `br_on_cast`/`br_on_null` tests that branch
/// out to the arm blocks, and each cast arm binds what its test matched.
test "a match is checked as the test ladder it becomes" {
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  let ctx = module_ctx()
  @typing.bind_local(
    ctx,
    id("v"),
    @typing.internalize_valtype(
      ctx.type_context,
      ctx.diagnostics,
      Ref({ nullable: true, typ: Any }),
    ),
  )
  let checker = @typing.Checker::new(ctx, @typing.Operands::new())
  // `match v { null => nop ; s: &struct => nop } else { nop }`
  let checked = checker.statement(
    instr(
      Match(
        scrutinee=instr(Get(id("v")), 20),
        // Each arm body DIVERGES. A block's result is supplied only on the
        // matching-branch path, so an arm that falls out of its block would
        // owe a value its fall-through never produces -- which the lowered
        // block check is exactly what catches.
        arms=[
          (MatchNull, { desc: [instr(Unreachable, 30)], info: loc_at(30, 31) }),
          (
            MatchCast(Some(id("s")), { nullable: false, typ: Struct }),
            { desc: [instr(Unreachable, 40)], info: loc_at(40, 41) },
          ),
        ],
        default={ desc: [instr(Nop, 50)], info: loc_at(50, 51) },
      ),
      10,
    ),
  )
  inspect(ctx.diagnostics.collected().length(), content="0")
  inspect(checker.gaps().length(), content="0")
  // Peeled back to a match: the scrutinee typed once inside the chain, the arm
  // bodies recovered in SOURCE order, and the default kept.
  guard! checked.desc is Match(scrutinee~, arms~, default~)
  inspect(
    scrutinee.info.0.map(t => @infer.to_string(t)).join(","),
    content="&?any",
  )
  inspect(arms.map(a => a.1.desc.length().to_string()).join(","), content="1,1")
  inspect(default.desc.length(), content="1")
  // The cast arm bound its name, so its body could have used it.
  inspect(ctx.locals.contains("s"), content="true")
}

///|
/// With no arms at all the lowering IS the default, and the scrutinee never
/// reaches it -- so there is nothing typed to recover from the lowered form and
/// it is checked directly instead.
test "a match with no arms is just its default" {
  let ctx = module_ctx()
  @typing.bind_local(
    ctx,
    id("v"),
    @typing.internalize_valtype(
      ctx.type_context,
      ctx.diagnostics,
      Ref({ nullable: true, typ: Any }),
    ),
  )
  let checker = @typing.Checker::new(ctx, @typing.Operands::new())
  let checked = checker.statement({
    desc: Match(
      scrutinee={
        desc: Get(id("v")),
        info: loc_at(20, 21),
        hints: { branch: None, freq: None, targets: None },
        expected: None,
      },
      arms=[],
      default={
        desc: [
          {
            desc: Nop,
            info: loc_at(50, 51),
            hints: { branch: None, freq: None, targets: None },
            expected: None,
          },
        ],
        info: loc_at(50, 51),
      },
    ),
    info: loc_at(10, 11),
    hints: { branch: None, freq: None, targets: None },
    expected: None,
  })
  inspect(ctx.diagnostics.collected().length(), content="0")
  guard! checked.desc is Match(arms~, default~, scrutinee~)
  inspect(arms.length(), content="0")
  inspect(default.desc.length(), content="1")
  inspect(
    scrutinee.info.0.map(t => @infer.to_string(t)).join(","),
    content="&?any",
  )
  inspect(checker.gaps().length(), content="0")
}

///|
/// A call types its CALLEE first, out of emission order -- the arguments are
/// pushed before it at run time. That inversion is what lets an argument be
/// checked against the parameter type, so a literal is pinned by what it is
/// passed to rather than by its own default.
test "a call pins its arguments to the parameter types" {
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  fn ctx_with_fn() -> @typing_env.ModuleContext {
    let ctx = module_ctx()
    let module_ : @ast.Module[@basic.Location] = [
      {
        desc: Type([
          {
            desc: (
              id("ft"),
              {
                typ: Func({
                  params: [{ desc: (None, F64), info: loc_at(0, 1) }],
                  results: [I64],
                }),
                supertype: None,
                final_: true,
                descriptor: None,
                describes: None,
              },
            ),
            info: loc_at(0, 2),
          },
        ]),
        info: loc_at(0, 2),
      },
      {
        desc: Func(
          name=id("f"),
          typ=Some(id("ft")),
          sign=None,
          body=(None, []),
          attributes=[],
        ),
        info: loc_at(4, 5),
      },
    ]
    @typing.declare_fields(ctx, module_)
    ctx
  }

  let ctx = ctx_with_fn()
  let checker = @typing.Checker::new(ctx, @typing.Operands::new())
  let checked = checker.statement(
    instr(Call(instr(Get(id("f")), 20), [instr(Int("1"), 30)]), 10),
  )
  inspect(ctx.diagnostics.collected().length(), content="0")
  // The call produces the function's results.
  inspect(checked.info.0.map(t => @infer.to_string(t)).join(","), content="i64")
  // And the integer literal was pinned to the f64 parameter, not to its own
  // i32 default.
  guard! checked.desc is Call(_, args)
  inspect(args[0].info.0.map(t => @infer.to_string(t)).join(","), content="f64")
  inspect(checker.gaps().length(), content="0")

  // Too few arguments is reported against the callee.
  let ctx2 = ctx_with_fn()
  let checker2 = @typing.Checker::new(ctx2, @typing.Operands::new())
  let _ = checker2.statement(instr(Call(instr(Get(id("f")), 20), []), 10))
  inspect(
    @message.to_plain_string(ctx2.diagnostics.collected()[0].message),
    content="This instruction expects 1 operand(s) but 0 was/were provided.",
  )

  // A callee that is not a function at all.
  let ctx3 = ctx_with_fn()
  let checker3 = @typing.Checker::new(ctx3, @typing.Operands::new())
  let _ = checker3.statement(instr(Call(instr(Int("1"), 20), []), 10))
  inspect(
    @message.to_plain_string(ctx3.diagnostics.collected()[0].message),
    content="Expected function.",
  )
}

///|
/// `become f(x)` is typed exactly as `f(x)` and then re-tagged, with one extra
/// demand: the callee's results must satisfy THIS function's, since its return
/// is what the caller will see. And it does not return here, so nothing
/// follows it.
test "a tail call must return what its caller promised" {
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  fn run(returns : @wasm_types.ValType[@ast.Ident]) -> String {
    let ctx = module_ctx()
    let module_ : @ast.Module[@basic.Location] = [
      {
        desc: Type([
          {
            desc: (
              id("ft"),
              {
                typ: Func({ params: [], results: [I64] }),
                supertype: None,
                final_: true,
                descriptor: None,
                describes: None,
              },
            ),
            info: loc_at(0, 2),
          },
        ]),
        info: loc_at(0, 2),
      },
      {
        desc: Func(
          name=id("f"),
          typ=Some(id("ft")),
          sign=None,
          body=(None, []),
          attributes=[],
        ),
        info: loc_at(4, 5),
      },
    ]
    @typing.declare_fields(ctx, module_)
    ctx.enter_function(
      return_types=match
        @typing.internalize(ctx.type_context, ctx.diagnostics, returns) {
        Some(c) => [c]
        None => []
      },
    )
    let ops = @typing.Operands::new()
    let checker = @typing.Checker::new(ctx, ops)
    let _ = checker.statement(instr(TailCall(instr(Get(id("f")), 20), []), 10))
    (if ops.stack is Unreachable { "diverges" } else { "continues" }) +
    " | " +
    ctx.diagnostics
    .collected()
    .map(d => @message.to_plain_string(d.message))
    .join(" / ")
  }

  // The callee returns i64 and so does this function: fine, and control never
  // comes back.
  inspect(run(I64), content="diverges | ")
  // Returning something else is not.
  inspect(
    run(F64),
    content="diverges | This expression has type 'i64' but is expected to have type 'f64'.",
  )
}

///|
/// A memory access is written as a method call, and its alignment and offset
/// are LABELLED immediates rather than operands -- constants in the
/// instruction, not values on the stack.
test "a memory access takes operands and labelled immediates" {
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  fn access(
    at : @wasm_types.AddressType,
    meth : String,
    args : Array[@ast.Instr[@basic.Location]],
  ) -> String {
    let ctx = module_ctx()
    ctx.memories.add(ctx.diagnostics, "mem", loc_at(0, 3), (0, at))
    let checker = @typing.Checker::new(ctx, @typing.Operands::new())
    let c = checker.statement(
      instr(
        Call(
          instr(
            StructGet(instr(Get(id("mem")), 20), {
              name: meth,
              loc: loc_at(24, 30),
            }),
            20,
          ),
          args,
        ),
        10,
      ),
    )
    c.info.0.map(t => @infer.to_string(t)).join(",") +
    " | " +
    ctx.diagnostics
    .collected()
    .map(d => @message.to_plain_string(d.message))
    .join(" / ") +
    " | " +
    checker.gaps().length().to_string()
  }

  fn labelled(name : String, v : String) -> @ast.Instr[@basic.Location] {
    instr(Labelled({ name, loc: loc_at(40, 46) }, instr(Int(v), 48)), 40)
  }

  // A load produces the width it names, remembering how narrow it was.
  inspect(access(I32, "load32", [instr(Int("0"), 30)]), content="i32 |  | 0")
  inspect(access(I32, "load8", [instr(Int("0"), 30)]), content="i8 |  | 0")
  inspect(access(I32, "loadf64", [instr(Int("0"), 30)]), content="f64 |  | 0")
  // A store produces nothing.
  inspect(
    access(I32, "store32", [instr(Int("0"), 30), instr(Int("1"), 34)]),
    content=" |  | 0",
  )
  // The immediates are labelled, and an alignment within the natural one is
  // fine.
  inspect(
    access(I32, "load32", [
      instr(Int("0"), 30),
      labelled("align", "2"),
      labelled("offset", "16"),
    ]),
    content="i32 |  | 0",
  )
  // Over the natural alignment is not.
  inspect(
    access(I32, "load32", [instr(Int("0"), 30), labelled("align", "8")]),
    content="i32 | The memory alignment is larger than the natural alignment 4. | 0",
  )
  // A 64-bit memory takes an i64 address, so an i32 one does not fit.
  inspect(access(I64, "load32", [instr(Int("0"), 30)]), content="i32 |  | 0")
  // An unknown label is caught, with a suggestion.
  inspect(
    access(I32, "load32", [instr(Int("0"), 30), labelled("offst", "16")]),
    content="i32 | Unknown argument label 'offst'. | 0",
  )
}

///|
/// The narrowing stores WRAP, so they take an i64-wide value too -- writing the
/// low bytes of a big number is what they are for. The wide ones demand their
/// exact width.
test "a narrowing store accepts a value wider than it writes" {
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  fn store(meth : String, value : @ast.InstrDesc[@basic.Location]) -> String {
    let ctx = module_ctx()
    ctx.memories.add(ctx.diagnostics, "mem", loc_at(0, 3), (0, I32))
    let checker = @typing.Checker::new(ctx, @typing.Operands::new())
    let _ = checker.statement(
      instr(
        Call(
          instr(
            StructGet(instr(Get(id("mem")), 20), {
              name: meth,
              loc: loc_at(24, 30),
            }),
            20,
          ),
          [instr(Int("0"), 30), instr(value, 34)],
        ),
        10,
      ),
    )
    ctx.diagnostics
    .collected()
    .map(d => @message.to_plain_string(d.message))
    .join(" / ")
  }

  // A literal too big for i32 still fits a narrowing store.
  inspect(store("store8", Int("4294967296")), content="")
  inspect(store("store32", Int("4294967296")), content="")
  // A float does not: there is nothing to wrap.
  inspect(
    store("store8", Float("1.5")),
    content="This expression has type 'float' but is expected to have type 'int'.",
  )
  // The wide stores demand their own width.
  inspect(store("storef64", Float("1.5")), content="")
  inspect(
    store("storef32", Float("1e300")),
    content="This expression has type 'f64' but is expected to have type 'f32'.",
  )
}

///|
/// The five management names serve both memories and tables, so only the
/// RECEIVER tells them apart -- and each has its own operand shape, with the
/// table's element type standing where a memory has an i32 byte.
test "management calls take their receiver's shape" {
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  fn run(
    recv : String,
    meth : String,
    args : Array[@ast.Instr[@basic.Location]],
  ) -> String {
    let ctx = module_ctx()
    ctx.memories.add(ctx.diagnostics, "mem", loc_at(0, 3), (0, I32))
    ctx.memories.add(ctx.diagnostics, "wide", loc_at(4, 8), (1, I64))
    ctx.tables.add(
      ctx.diagnostics,
      "tab",
      loc_at(10, 13),
      (I32, { nullable: true, typ: Func }),
    )
    ctx.datas.add(ctx.diagnostics, "seg", loc_at(14, 17), ())
    let checker = @typing.Checker::new(ctx, @typing.Operands::new())
    let c = checker.statement(
      instr(
        Call(
          instr(
            StructGet(instr(Get(id(recv)), 20), {
              name: meth,
              loc: loc_at(24, 30),
            }),
            20,
          ),
          args,
        ),
        10,
      ),
    )
    c.info.0.map(t => @infer.to_string(t)).join(",") +
    " | " +
    ctx.diagnostics
    .collected()
    .map(d => @message.to_plain_string(d.message))
    .join(" / ") +
    " | " +
    checker.gaps().length().to_string()
  }

  // A memory's size and grow answer in its ADDRESS type.
  inspect(run("mem", "size", []), content="i32 |  | 0")
  inspect(run("wide", "size", []), content="i64 |  | 0")
  inspect(run("mem", "grow", [instr(Int("1"), 30)]), content="i32 |  | 0")
  // A table's too, and its size counts elements rather than pages -- same
  // spelling, different operation, told apart by the receiver alone.
  inspect(run("tab", "size", []), content="i32 |  | 0")
  // `mem.fill` writes a BYTE, so its value operand is an i32.
  inspect(
    run("mem", "fill", [
      instr(Int("0"), 30),
      instr(Int("0"), 34),
      instr(Int("4"), 38),
    ]),
    content=" |  | 0",
  )
  // `tab.fill` writes an ELEMENT, so a byte will not do.
  inspect(
    run("tab", "fill", [
      instr(Int("0"), 30),
      instr(Int("0"), 34),
      instr(Int("4"), 38),
    ]),
    content=" | This expression has type 'number' but is expected to have type '&?func'. | 0",
  )
  inspect(
    run("tab", "fill", [
      instr(Int("0"), 30),
      instr(Null, 34),
      instr(Int("4"), 38),
    ]),
    content=" |  | 0",
  )
  // A shape that matches nothing recovers with a VALUE, not with nothing: some
  // of these produce one, and claiming none would cascade where the call is
  // used as an expression.
  inspect(
    run("mem", "grow", []),
    content="any | Invalid arguments in call to 'grow'. | 0",
  )
}

///|
/// A cross-memory copy names the OTHER memory as a static operand. The length
/// indexes both sides, so it is typed at the NARROWER of the two address types
/// -- typing it at the wider one would accept a length the narrow side cannot
/// address.
test "a cross-memory copy takes its length at the narrower width" {
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  fn copy(
    dst : String,
    src : String,
    len : @ast.InstrDesc[@basic.Location],
  ) -> String {
    let ctx = module_ctx()
    ctx.memories.add(ctx.diagnostics, "narrow", loc_at(0, 6), (0, I32))
    ctx.memories.add(ctx.diagnostics, "wide", loc_at(8, 12), (1, I64))
    let checker = @typing.Checker::new(ctx, @typing.Operands::new())
    let _ = checker.statement(
      instr(
        Call(
          instr(
            StructGet(instr(Get(id(dst)), 20), {
              name: "copy",
              loc: loc_at(24, 28),
            }),
            20,
          ),
          [
            instr(Get(id(src)), 30),
            instr(Int("0"), 34),
            instr(Int("0"), 38),
            instr(len, 42),
          ],
        ),
        10,
      ),
    )
    ctx.diagnostics
    .collected()
    .map(d => @message.to_plain_string(d.message))
    .join(" / ")
  }

  // Both 64-bit: the length may be an i64.
  inspect(copy("wide", "wide", Int("4294967296")), content="")
  // One side 32-bit: the length must fit an i32, so a larger literal does not.
  inspect(
    copy("wide", "narrow", Int("4294967296")),
    content="This expression has type 'large number' but is expected to have type 'i32'.",
  )
}

///|
/// An atomic access requires EXACTLY its natural alignment. For an ordinary
/// access the alignment is a promise the engine may ignore, so less than
/// natural is merely pessimistic -- but an atomic access that is not aligned is
/// not atomic, so anything but the exact value is rejected.
test "an atomic access demands exactly its natural alignment" {
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  fn access(
    meth : String,
    args : Array[@ast.Instr[@basic.Location]],
  ) -> String {
    let ctx = module_ctx()
    ctx.memories.add(ctx.diagnostics, "mem", loc_at(0, 3), (0, I32))
    let checker = @typing.Checker::new(ctx, @typing.Operands::new())
    let c = checker.statement(
      instr(
        Call(
          instr(
            StructGet(instr(Get(id("mem")), 20), {
              name: meth,
              loc: loc_at(24, 36),
            }),
            20,
          ),
          args,
        ),
        10,
      ),
    )
    c.info.0.map(t => @infer.to_string(t)).join(",") +
    " | " +
    ctx.diagnostics
    .collected()
    .map(d => @message.to_plain_string(d.message))
    .join(" / ") +
    " | " +
    checker.gaps().length().to_string()
  }

  fn labelled(name : String, v : String) -> @ast.Instr[@basic.Location] {
    instr(Labelled({ name, loc: loc_at(40, 46) }, instr(Int(v), 48)), 40)
  }

  let addr = instr(Int("0"), 30)
  // A 32-bit atomic load: four bytes, so alignment 4 exactly.
  inspect(
    access("atomic_load32", [addr, labelled("align", "4")]),
    content="i32 |  | 0",
  )
  // Less than natural is fine for an ordinary access and NOT for this one.
  inspect(
    access("atomic_load32", [addr, labelled("align", "1")]),
    content="i32 | The alignment of an atomic access must be its natural alignment 4. | 0",
  )
  inspect(
    access("atomic_load32", [addr, labelled("align", "8")]),
    content="i32 | The alignment of an atomic access must be its natural alignment 4. | 0",
  )
  // A narrow load remembers its width, as the ordinary one does.
  inspect(access("atomic_load8", [addr]), content="i8 |  | 0")
  // A wait answers whether it timed out, so an i32 whatever it waited on.
  inspect(
    access("atomic_wait32", [addr, instr(Int("0"), 34), instr(Int("1"), 38)]),
    content="i32 |  | 0",
  )
}

///|
/// A narrow read-modify-write picks the i32/i64 family from its VALUE, so
/// either is accepted -- and the value's cell IS the result, since the
/// operation returns the old value at the same width.
test "a narrow atomic rmw takes its width from its value" {
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  fn rmw(meth : String, value : @ast.InstrDesc[@basic.Location]) -> String {
    let ctx = module_ctx()
    ctx.memories.add(ctx.diagnostics, "mem", loc_at(0, 3), (0, I32))
    let checker = @typing.Checker::new(ctx, @typing.Operands::new())
    let c = checker.statement(
      instr(
        Call(
          instr(
            StructGet(instr(Get(id("mem")), 20), {
              name: meth,
              loc: loc_at(24, 36),
            }),
            20,
          ),
          [instr(Int("0"), 30), instr(value, 34)],
        ),
        10,
      ),
    )
    c.info.0.map(t => @infer.to_string(t)).join(",") +
    " | " +
    ctx.diagnostics
    .collected()
    .map(d => @message.to_plain_string(d.message))
    .join(" / ")
  }

  // A flexible literal stays flexible and defaults to i32 like any other.
  inspect(rmw("atomic_rmw_add32", Int("1")), content="int | ")
  // A literal too big for i32 makes it the i64 family instead.
  inspect(rmw("atomic_rmw_add32", Int("4294967296")), content="i64 | ")
  // A float is not an integer operation at all.
  inspect(
    rmw("atomic_rmw_add32", Float("1.5")),
    // The operand keeps its own type; the complaint is what says it is wrong.
    content="float | This operator cannot be applied to operands of types 'float' and 'int'.",
  )
}

///|
/// A SIMD memory access is an ordinary one whose operands and result are
/// vectors -- and the lane-taking forms need a `lane:` immediate, whose bound
/// comes from the access WIDTH rather than from any shape.
test "a simd memory access needs its lane immediate" {
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  fn access(
    meth : String,
    args : Array[@ast.Instr[@basic.Location]],
  ) -> String {
    let ctx = module_ctx()
    ctx.memories.add(ctx.diagnostics, "mem", loc_at(0, 3), (0, I32))
    let checker = @typing.Checker::new(ctx, @typing.Operands::new())
    let c = checker.statement(
      instr(
        Call(
          instr(
            StructGet(instr(Get(id("mem")), 20), {
              name: meth,
              loc: loc_at(24, 36),
            }),
            20,
          ),
          args,
        ),
        10,
      ),
    )
    c.info.0.map(t => @infer.to_string(t)).join(",") +
    " | " +
    ctx.diagnostics
    .collected()
    .map(d => @message.to_plain_string(d.message))
    .join(" / ") +
    " | " +
    checker.gaps().length().to_string()
  }

  fn labelled(name : String, v : String) -> @ast.Instr[@basic.Location] {
    instr(Labelled({ name, loc: loc_at(40, 46) }, instr(Int(v), 48)), 40)
  }

  let addr = instr(Int("0"), 30)
  // A whole-vector load produces a v128.
  inspect(access("loadv128", [addr]), content="v128 |  | 0")
  // A lane load takes the vector to write into, and the lane to write.
  let vec = instr(Get(id("v")), 34)
  ignore(vec)
  // Written without its `lane:`, which is the one thing it cannot do without.
  inspect(
    access("load8_lane", [addr, instr(Int("0"), 34)]),
    content="v128 | This expression has type 'number' but is expected to have type 'v128'. / This memory access needs a 'lane:' immediate (e.g. 'lane: 0'). | 0",
  )
  // A lane past the bound: a `load8_lane` writes one of SIXTEEN byte lanes.
  inspect(
    access("load8_lane", [addr, instr(Int("0"), 34), labelled("lane", "16")]),
    content="v128 | This expression has type 'number' but is expected to have type 'v128'. / The lane index should be less than 16. | 0",
  )
  // And a `load64_lane` one of only two.
  inspect(
    access("load64_lane", [addr, instr(Int("0"), 34), labelled("lane", "2")]),
    content="v128 | This expression has type 'number' but is expected to have type 'v128'. / The lane index should be less than 2. | 0",
  )
}

///|
/// A SIMD operation on a value is identified by its NAME alone -- the names
/// carry their shape, so `add_i32x4` cannot be confused with anything. The
/// receiver is the operation's FIRST operand, and the leading immediates are
/// static: not pushed, never holes.
test "a simd operation takes its receiver as its first operand" {
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  fn op(
    recv : @ast.InstrDesc[@basic.Location],
    meth : String,
    args : Array[@ast.Instr[@basic.Location]],
  ) -> String {
    let ctx = module_ctx()
    @typing.bind_local(
      ctx,
      id("v"),
      Some({ typ: V128, internal: V128, anon_comptype: None }),
    )
    let checker = @typing.Checker::new(ctx, @typing.Operands::new())
    let c = checker.statement(
      instr(
        Call(
          instr(
            StructGet(instr(recv, 20), { name: meth, loc: loc_at(24, 36) }),
            20,
          ),
          args,
        ),
        10,
      ),
    )
    c.info.0.map(t => @infer.to_string(t)).join(",") +
    " | " +
    ctx.diagnostics
    .collected()
    .map(d => @message.to_plain_string(d.message))
    .join(" / ") +
    " | " +
    checker.gaps().length().to_string()
  }

  let v = @ast.InstrDesc::Get(id("v"))
  // A lane-wise add takes a second vector and produces one.
  inspect(op(v, "add_i32x4", [instr(v, 30)]), content="v128 |  | 0")
  // Extracting a lane produces the SCALAR the shape names, and its lane
  // immediate is bounded by the shape: `i32x4` has four.
  inspect(
    op(v, "extract_lane_i32x4", [instr(Int("3"), 30)]),
    content="i32 |  | 0",
  )
  inspect(
    op(v, "extract_lane_i32x4", [instr(Int("4"), 30)]),
    content="i32 | The lane index should be less than 4. | 0",
  )
  // A byte shape has sixteen, so the same index is fine there.
  inspect(
    op(v, "extract_lane_s_i8x16", [instr(Int("4"), 30)]),
    content="i32 |  | 0",
  )
  // A splat's receiver is the SCALAR, not a vector.
  inspect(op(Int("1"), "splat_i32x4", []), content="v128 |  | 0")
  // A receiver of the wrong type poisons the result, so a chained operation
  // does not report the same mismatch twice at the same span.
  inspect(
    op(Float("1.5"), "add_i32x4", [instr(v, 30)]),
    content="any | This expression has type 'float' but is expected to have type 'v128'. | 0",
  )
  // Too few operands is reported against the call.
  inspect(
    op(v, "add_i32x4", []),
    content="v128 | This instruction expects 1 operand(s) but 0 was/were provided. | 0",
  )
}

///|
/// `cont.bind` binds a continuation's LEADING parameters away, so the
/// destination takes fewer -- and what remains, the unbound tail and the
/// results, must match exactly.
test "cont.bind must leave the tail and results unchanged" {
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  fn bind(
    src_params : Array[@wasm_types.ValType[@ast.Ident]],
    dst_params : Array[@wasm_types.ValType[@ast.Ident]],
    args : Array[@ast.Instr[@basic.Location]],
  ) -> String {
    let ctx = module_ctx()
    fn functype(
      n : String,
      ps : Array[@wasm_types.ValType[@ast.Ident]],
      at : Int,
    ) -> @basic.Annotated[@ast.ModuleField[@basic.Location], @basic.Location] {
      {
        desc: Type([
          {
            desc: (
              id(n),
              {
                typ: Func({
                  params: ps.map(p => {
                    (
                      { desc: (None, p), info: loc_at(at, at + 1) } :
                      @basic.Annotated[
                        (@ast.Ident?, @wasm_types.ValType[@ast.Ident]),
                        @basic.Location,
                      ])
                  }),
                  results: [I32],
                }),
                supertype: None,
                final_: true,
                descriptor: None,
                describes: None,
              },
            ),
            info: loc_at(at, at + 1),
          },
        ]),
        info: loc_at(at, at + 1),
      }
    }

    fn conttype(
      n : String,
      inner : String,
      at : Int,
    ) -> @basic.Annotated[@ast.ModuleField[@basic.Location], @basic.Location] {
      {
        desc: Type([
          {
            desc: (
              id(n),
              {
                typ: Cont(id(inner)),
                supertype: None,
                final_: true,
                descriptor: None,
                describes: None,
              },
            ),
            info: loc_at(at, at + 1),
          },
        ]),
        info: loc_at(at, at + 1),
      }
    }

    let module_ : @ast.Module[@basic.Location] = [
      functype("sf", src_params, 0),
      functype("df", dst_params, 2),
      conttype("sc", "sf", 4),
      conttype("dc", "df", 6),
    ]
    @typing.declare_fields(ctx, module_)
    @typing.bind_local(
      ctx,
      id("k"),
      @typing.internalize_valtype(
        ctx.type_context,
        ctx.diagnostics,
        Ref({ nullable: true, typ: Type(id("sc")) }),
      ),
    )
    let checker = @typing.Checker::new(ctx, @typing.Operands::new())
    let c = checker.statement(instr(ContBind(id("sc"), id("dc"), args), 10))
    c.info.0.map(t => @infer.to_string(t)).join(",") +
    " | " +
    ctx.diagnostics
    .collected()
    .map(d => @message.to_plain_string(d.message))
    .join(" / ") +
    " | " +
    checker.gaps().length().to_string()
  }

  let k = instr(Get(id("k")), 30)
  // Binding the leading i32 away: the destination takes the f64 that remains.
  inspect(
    bind([I32, F64], [F64], [instr(Int("1"), 34), k]),
    content="&dc |  | 0",
  )
  // A destination taking MORE parameters than the source is backwards.
  inspect(
    bind([F64], [I32, F64], [k]),
    content="&dc | Type mismatch in this stack switching instruction: the resulting continuation takes more parameters than the original one. | 0",
  )
  // The right count, but the wrong tail.
  inspect(
    bind([I32, F64], [I32], [instr(Int("1"), 34), k]),
    content="&dc | Type mismatch in this stack switching instruction: the bound parameters and results do not match between the two continuation types. | 0",
  )
}

///|
/// A `suspend` hands the tag's parameters out and takes its RESULTS back when
/// resumed -- unlike a `throw`, where a tag with results is a mistake, because
/// a throw never comes back.
test "a suspend takes back what its tag returns" {
  let ctx = module_ctx()
  ctx.tags.add(ctx.diagnostics, "ask", loc_at(0, 3), {
    params: [{ desc: (None, I32), info: loc_at(0, 1) }],
    results: [F64],
  })
  let checker = @typing.Checker::new(ctx, @typing.Operands::new())
  let checked = checker.statement({
    desc: Suspend(id("ask"), [
      {
        desc: Int("1"),
        info: loc_at(30, 31),
        hints: { branch: None, freq: None, targets: None },
        expected: None,
      },
    ]),
    info: loc_at(10, 11),
    hints: { branch: None, freq: None, targets: None },
    expected: None,
  })
  inspect(ctx.diagnostics.collected().length(), content="0")
  inspect(checked.info.0.map(t => @infer.to_string(t)).join(","), content="f64")
  inspect(checker.gaps().length(), content="0")
}

///|
/// A resume's handler table is its whole point: `on <tag> <label>` promises
/// that when the continuation suspends to that tag, control arrives at the
/// label carrying the TAG's parameters followed by a continuation of the
/// REMAINING computation -- one taking the tag's results and producing what the
/// resume produces.
test "a resume handler receives a continuation of the rest" {
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  fn functype(
    n : String,
    ps : Array[@wasm_types.ValType[@ast.Ident]],
    rs : Array[@wasm_types.ValType[@ast.Ident]],
    at : Int,
  ) -> @basic.Annotated[@ast.ModuleField[@basic.Location], @basic.Location] {
    {
      desc: Type([
        {
          desc: (
            id(n),
            {
              typ: Func({
                params: ps.map(p => {
                  (
                    { desc: (None, p), info: loc_at(at, at + 1) } :
                    @basic.Annotated[
                      (@ast.Ident?, @wasm_types.ValType[@ast.Ident]),
                      @basic.Location,
                    ])
                }),
                results: rs,
              }),
              supertype: None,
              final_: true,
              descriptor: None,
              describes: None,
            },
          ),
          info: loc_at(at, at + 1),
        },
      ]),
      info: loc_at(at, at + 1),
    }
  }

  fn conttype(
    n : String,
    inner : String,
    at : Int,
  ) -> @basic.Annotated[@ast.ModuleField[@basic.Location], @basic.Location] {
    {
      desc: Type([
        {
          desc: (
            id(n),
            {
              typ: Cont(id(inner)),
              supertype: None,
              final_: true,
              descriptor: None,
              describes: None,
            },
          ),
          info: loc_at(at, at + 1),
        },
      ]),
      info: loc_at(at, at + 1),
    }
  }

  // The resumed continuation produces an i32. The tag `ask` takes nothing and
  // gives back an f64, so its handler receives a `cont (f64) -> i32`.
  fn run(handler_results : Array[@wasm_types.ValType[@ast.Ident]]) -> String {
    let ctx = module_ctx()
    let module_ : @ast.Module[@basic.Location] = [
      functype("body", [], [I32], 0),
      conttype("k", "body", 2),
      functype("rest", [F64], [I32], 4),
      conttype("kr", "rest", 6),
    ]
    @typing.declare_fields(ctx, module_)
    ctx.tags.add(ctx.diagnostics, "ask", loc_at(8, 11), {
      params: [],
      results: [F64],
    })
    @typing.bind_local(
      ctx,
      id("c"),
      @typing.internalize_valtype(
        ctx.type_context,
        ctx.diagnostics,
        Ref({ nullable: true, typ: Type(id("k")) }),
      ),
    )
    let checker = @typing.Checker::new(ctx, @typing.Operands::new())
    let _ = checker.statement(
      instr(
        Block(
          label=Some(id("h")),
          typ={ params: [], results: handler_results },
          block={
            desc: [
              instr(
                Resume(id("k"), [OnLabel(id("ask"), id("h"))], [
                  instr(Get(id("c")), 30),
                ]),
                20,
              ),
              instr(Unreachable, 40),
            ],
            info: loc_at(20, 21),
          },
        ),
        10,
      ),
    )
    ctx.diagnostics
    .collected()
    .map(d => @message.to_plain_string(d.message))
    .join(" / ") +
    " | " +
    checker.gaps().length().to_string()
  }

  // The handler takes exactly the continuation of the rest.
  inspect(run([Ref({ nullable: true, typ: Type(id("kr")) })]), content=" | 0")
  // A handler taking something that is not a continuation at all.
  inspect(
    run([I32]),
    content="Type mismatch in this stack switching instruction: this handler must take the tag's parameters followed by a continuation of the remaining result type. | 0",
  )
  // A continuation of the WRONG rest -- one that produces an f64 where the
  // resume produces an i32.
  inspect(
    run([Ref({ nullable: true, typ: Type(id("k")) })]),
    content="Type mismatch in this stack switching instruction: this handler must take the tag's parameters followed by a continuation of the remaining result type. | 0",
  )
}

///|
/// A `switch` hands control to another continuation without going through a
/// handler. The switched-to continuation's LAST parameter must itself be a
/// continuation -- that is the slot the current one is passed in, so the other
/// side can switch back -- and what the instruction produces is that inner
/// continuation's parameters.
test "a switch passes the current continuation in the last slot" {
  fn functype(
    n : String,
    ps : Array[@wasm_types.ValType[@ast.Ident]],
    rs : Array[@wasm_types.ValType[@ast.Ident]],
    at : Int,
  ) -> @basic.Annotated[@ast.ModuleField[@basic.Location], @basic.Location] {
    {
      desc: Type([
        {
          desc: (
            id(n),
            {
              typ: Func({
                params: ps.map(p => {
                  (
                    { desc: (None, p), info: loc_at(at, at + 1) } :
                    @basic.Annotated[
                      (@ast.Ident?, @wasm_types.ValType[@ast.Ident]),
                      @basic.Location,
                    ])
                }),
                results: rs,
              }),
              supertype: None,
              final_: true,
              descriptor: None,
              describes: None,
            },
          ),
          info: loc_at(at, at + 1),
        },
      ]),
      info: loc_at(at, at + 1),
    }
  }

  fn conttype(
    n : String,
    inner : String,
    at : Int,
  ) -> @basic.Annotated[@ast.ModuleField[@basic.Location], @basic.Location] {
    {
      desc: Type([
        {
          desc: (
            id(n),
            {
              typ: Cont(id(inner)),
              supertype: None,
              final_: true,
              descriptor: None,
              describes: None,
            },
          ),
          info: loc_at(at, at + 1),
        },
      ]),
      info: loc_at(at, at + 1),
    }
  }

  // `back` is a continuation taking an i32; `fwd` takes one of those, so a
  // switch to it hands over the current continuation and comes back with i32.
  fn run(
    last_is_cont : Bool,
    tag_results : Array[@wasm_types.ValType[@ast.Ident]],
  ) -> String {
    let ctx = module_ctx()
    let last : @wasm_types.ValType[@ast.Ident] = if last_is_cont {
      Ref({ nullable: true, typ: Type(id("back")) })
    } else {
      I32
    }
    let module_ : @ast.Module[@basic.Location] = [
      functype("bf", [I32], [], 0),
      conttype("back", "bf", 2),
      functype("ff", [last], [], 4),
      conttype("fwd", "ff", 6),
    ]
    @typing.declare_fields(ctx, module_)
    ctx.tags.add(ctx.diagnostics, "sw", loc_at(8, 10), {
      params: [],
      results: tag_results,
    })
    @typing.bind_local(
      ctx,
      id("k"),
      @typing.internalize_valtype(
        ctx.type_context,
        ctx.diagnostics,
        Ref({ nullable: true, typ: Type(id("fwd")) }),
      ),
    )
    let checker = @typing.Checker::new(ctx, @typing.Operands::new())
    let c = checker.statement({
      desc: Switch(id("fwd"), id("sw"), [
        {
          desc: Get(id("k")),
          info: loc_at(30, 31),
          hints: { branch: None, freq: None, targets: None },
          expected: None,
        },
      ]),
      info: loc_at(10, 11),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    })
    c.info.0.map(t => @infer.to_string(t)).join(",") +
    " | " +
    ctx.diagnostics
    .collected()
    .map(d => @message.to_plain_string(d.message))
    .join(" / ") +
    " | " +
    checker.gaps().length().to_string()
  }

  // The switch produces what the inner continuation takes: an i32.
  inspect(run(true, []), content="i32 |  | 0")
  // A last parameter that is not a continuation has no slot to switch through.
  inspect(
    run(false, []),
    content=" | Type mismatch in this stack switching instruction: the continuation's last parameter must itself be a continuation type. | 0",
  )
  // A switch tag carries no VALUES -- it names the switch -- and its results
  // must agree with both continuations. Here they agree with neither.
  inspect(
    run(true, [F64]),
    content="i32 | Type mismatch in this stack switching instruction: the 'switch' tag must take no parameters and its results must match the two continuation types. | 0",
  )
}

///|
/// An `on` clause is the surface spelling that writes a resume's handlers
/// outside the call. It belongs to a resume and nothing else.
test "an on clause belongs to a resume" {
  fn run(inner : @ast.InstrDesc[@basic.Location]) -> String {
    let ctx = module_ctx()
    let checker = @typing.Checker::new(ctx, @typing.Operands::new())
    let _ = checker.statement({
      desc: On(
        {
          desc: inner,
          info: loc_at(20, 21),
          hints: { branch: None, freq: None, targets: None },
          expected: None,
        },
        [],
      ),
      info: loc_at(10, 11),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    })
    ctx.diagnostics
    .collected()
    .map(d => @message.to_plain_string(d.message))
    .join(" / ")
  }

  // Attached to something that is not a resume at all. Two complaints, and they
  // are two different mistakes: the clause is in the wrong place, and recovery
  // types the wrapped expression -- where a `nop` produces no value to carry.
  inspect(
    run(Nop),
    content="An 'on' handler clause is only allowed on a 'resume', 'resume_throw' or 'resume_throw_ref' call. / An expression is expected here. This instruction returns 0 values.",
  )
}

///|
/// A descriptor construction writes only its DESCRIPTOR -- `{desc d| ..}`, not
/// the struct type -- so the type being built is recovered from it: the operand
/// has type `&$Y`, `$Y` describes `$X`, and `$X` is what was meant.
test "a descriptor construction recovers its type from the descriptor" {
  fn ctx_with_pair() -> @typing_env.ModuleContext {
    let ctx = @typing_env.ModuleContext::new(
      @diagnostic.collector(),
      @type_store.TypeStore::new(),
      @feature.configure([(CustomDescriptors, true)]),
    )
    let _ = @typing.add_type(ctx.type_context, ctx.diagnostics, [
      {
        desc: (
          id("obj"),
          {
            typ: Struct([
              {
                desc: (id("x"), { mut_: false, typ: Value(I32) }),
                info: loc_at(0, 1),
              },
            ]),
            supertype: None,
            final_: true,
            descriptor: Some(id("d")),
            describes: None,
          },
        ),
        info: loc_at(0, 3),
      },
      {
        desc: (
          id("d"),
          {
            typ: Struct([]),
            supertype: None,
            final_: true,
            descriptor: None,
            describes: Some(id("obj")),
          },
        ),
        info: loc_at(4, 5),
      },
    ])
    @typing.bind_local(
      ctx,
      id("dv"),
      @typing.internalize_valtype(
        ctx.type_context,
        ctx.diagnostics,
        Ref({ nullable: false, typ: Type(id("d")) }),
      ),
    )
    @typing.bind_local(ctx, id("bad"), Some(@infer.i32_valtype))
    ctx
  }

  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  // The descriptor `d` describes `obj`, so this builds an `obj` -- and the
  // field is checked against that struct's declaration.
  let ctx = ctx_with_pair()
  let checker = @typing.Checker::new(ctx, @typing.Operands::new())
  let checked = checker.statement(
    instr(
      StructDesc(instr(Get(id("dv")), 20), [
        (id("x"), Some(instr(Int("1"), 30))),
      ]),
      10,
    ),
  )
  inspect(ctx.diagnostics.collected().length(), content="0")
  inspect(
    checked.info.0.map(t => @infer.to_string(t)).join(","),
    content="&obj",
  )
  inspect(checker.gaps().length(), content="0")

  // A descriptor operand that describes nothing has no type to recover.
  let ctx2 = ctx_with_pair()
  let checker2 = @typing.Checker::new(ctx2, @typing.Operands::new())
  let _ = checker2.statement(
    instr(StructDesc(instr(Get(id("bad")), 20), []), 10),
  )
  inspect(
    @message.to_plain_string(ctx2.diagnostics.collected()[0].message),
    content="This descriptor instruction requires a type that has a descriptor.",
  )

  // A cast through the descriptor reaches the same described type.
  let ctx3 = ctx_with_pair()
  @typing.bind_local(
    ctx3,
    id("v"),
    @typing.internalize_valtype(
      ctx3.type_context,
      ctx3.diagnostics,
      Ref({ nullable: true, typ: Any }),
    ),
  )
  let checker3 = @typing.Checker::new(ctx3, @typing.Operands::new())
  let cast = checker3.statement(
    instr(
      CastDesc(instr(Get(id("v")), 20), false, instr(Get(id("dv")), 30)),
      10,
    ),
  )
  inspect(cast.info.0.map(t => @infer.to_string(t)).join(","), content="&obj")
  inspect(checker3.gaps().length(), content="0")
}

///|
/// `tab[i] = v` on a TABLE name is `table.set`: the table is a static
/// immediate, so the receiver is never typed as a value. A local of the same
/// name shadows it and makes the same spelling an ordinary array write.
test "an indexed write picks table or array by its receiver" {
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  fn write(shadowed : Bool, value : @ast.InstrDesc[@basic.Location]) -> String {
    let ctx = module_ctx()
    ctx.tables.add(
      ctx.diagnostics,
      "tab",
      loc_at(0, 3),
      (I32, { nullable: true, typ: Func }),
    )
    if shadowed {
      @typing.bind_local(ctx, id("tab"), Some(@infer.i32_valtype))
    }
    let checker = @typing.Checker::new(ctx, @typing.Operands::new())
    let _ = checker.statement(
      instr(
        ArraySet(
          instr(Get(id("tab")), 20),
          instr(Int("0"), 30),
          instr(value, 34),
        ),
        10,
      ),
    )
    ctx.diagnostics
    .collected()
    .map(d => @message.to_plain_string(d.message))
    .join(" / ")
  }

  // A table write takes the table's ELEMENT type.
  inspect(write(false, Null), content="")
  inspect(
    write(false, Int("1")),
    content="This expression has type 'number' but is expected to have type '&?func'.",
  )
  // Shadowed by a local, the same spelling indexes a value -- which an i32 is
  // not.
  inspect(write(true, Null), content="Expected array.")
}

///|
/// `#[if]` inside a body types each branch under ITS OWN assumption, so names
/// resolve per branch: one may be declared only in the matching configuration.
test "conditional compilation types each branch under its own assumption" {
  let ctx = module_ctx()
  let cond : @wasm_types.Cond = Var({ desc: "debug", info: loc_at(0, 5) })
  // A global declared only under `debug`.
  ctx.cond.val = ctx.cond_env.of_cond(ctx.diagnostics, loc_at(0, 5), cond)
  ctx.globals.add(
    ctx.diagnostics,
    "dbg",
    loc_at(6, 9),
    (false, Some(@infer.i32_valtype)),
  )
  ctx.cond.val = @cond.true_
  let checker = @typing.Checker::new(ctx, @typing.Operands::new())
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  // Reading it inside the matching branch is fine.
  let checked = checker.statement(
    instr(
      IfAnnotation(
        cond~,
        then_body={ desc: [instr(Get(id("dbg")), 30)], info: loc_at(20, 21) },
        else_body=None,
      ),
      10,
    ),
  )
  // The read resolved and the branch's leftover is reported at the branch, not
  // as an unbound name.
  guard! checked.desc is IfAnnotation(then_body~, ..)
  inspect(
    then_body.desc[0].info.0.map(t => @infer.to_string(t)).join(","),
    content="i32",
  )
  inspect(
    ctx.diagnostics
    .collected()
    .filter(d => @message.to_plain_string(d.message).has_prefix("The variable"))
    .length(),
    content="0",
  )
  inspect(checker.gaps().length(), content="0")
}

///|
/// The whole checker, end to end: declare every name, then check every field.
///
/// The two passes are its entire shape. Nothing can be checked until every name
/// exists, because a function may call one defined below it -- and the ORDER
/// within the second pass matters for a different reason, which the next test
/// pins.
test "a module is declared then checked" {
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  // `type t = fn() -> i32`, `let g: f64 = 1.5`, `fn f: t { 1 }`.
  let module_ : @ast.Module[@basic.Location] = [
    {
      desc: Type([
        {
          desc: (
            id("t"),
            {
              typ: Func({ params: [], results: [I32] }),
              supertype: None,
              final_: true,
              descriptor: None,
              describes: None,
            },
          ),
          info: loc_at(0, 1),
        },
      ]),
      info: loc_at(0, 1),
    },
    {
      desc: Global(
        name=id("g"),
        mut_=false,
        typ=Some(F64),
        def=instr(Int("1"), 10),
        attributes=[],
      ),
      info: loc_at(10, 11),
    },
    {
      desc: Func(
        name=id("f"),
        typ=Some(id("t")),
        sign=None,
        body=(None, [instr(Int("1"), 20)]),
        attributes=[],
      ),
      info: loc_at(20, 21),
    },
  ]
  let (ctx, typed) = @typing.check_module(
    @diagnostic.collector(),
    @type_store.TypeStore::new(),
    @feature.default(),
    module_,
  )
  inspect(
    ctx.diagnostics
    .collected()
    .map(d => @message.to_plain_string(d.message))
    .join(" / "),
    content="",
  )
  inspect(typed.length(), content="3")
  // The global's initializer was pinned to its annotation, not to its own
  // default.
  // Source order is preserved: type, global, function.
  guard! typed[1].desc is Global(def~, ..)
  inspect(def.info.0.map(t => @infer.to_string(t)).join(","), content="f64")
  // And the function's body to the type it was declared with -- which was
  // written ABOVE it and resolved during the declaration pass.
  guard! typed[2].desc is Func(body~, ..)
  inspect(
    body.1[0].info.0.map(t => @infer.to_string(t)).join(","),
    content="i32",
  )
}

///|
/// A global initializer sees the globals declared BEFORE it and not those
/// after. That is why globals are registered as they are checked rather than up
/// front, unlike every other name.
test "a global initializer sees only what precedes it" {
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  fn global(
    name : String,
    init : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @basic.Annotated[@ast.ModuleField[@basic.Location], @basic.Location] {
    {
      desc: Global(
        name=id(name),
        mut_=false,
        typ=Some(I32),
        def=instr(init, at),
        attributes=[],
      ),
      info: loc_at(at, at + 1),
    }
  }

  // `let a = 1; let b = a` -- reading backwards is fine.
  let (ctx1, _) = @typing.check_module(
    @diagnostic.collector(),
    @type_store.TypeStore::new(),
    @feature.default(),
    [global("a", Int("1"), 0), global("b", Get(id("a")), 10)],
  )
  inspect(ctx1.diagnostics.collected().length(), content="0")

  // `let b = a; let a = 1` -- reading FORWARDS is not: `a` does not exist yet.
  let (ctx2, _) = @typing.check_module(
    @diagnostic.collector(),
    @type_store.TypeStore::new(),
    @feature.default(),
    [global("b", Get(id("a")), 0), global("a", Int("1"), 10)],
  )
  inspect(
    @message.to_plain_string(ctx2.diagnostics.collected()[0].message),
    content="The variable 'a' is not bound.",
  )
}

///|
/// A no-argument instruction method takes its FAMILY from the method and its
/// WIDTH from the receiver -- so a still-flexible receiver is pinned here, by
/// the only thing that can pin it.
test "an instruction method pins the receiver it is called on" {
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  fn call(recv : @ast.InstrDesc[@basic.Location], meth : String) -> String {
    let ctx = module_ctx()
    let module_ : @ast.Module[@basic.Location] = [
      {
        desc: Type([
          {
            desc: (
              id("bytes"),
              {
                typ: Array({ mut_: true, typ: Packed(I8) }),
                supertype: None,
                final_: true,
                descriptor: None,
                describes: None,
              },
            ),
            info: loc_at(0, 5),
          },
        ]),
        info: loc_at(0, 5),
      },
    ]
    @typing.declare_fields(ctx, module_)
    @typing.bind_local(
      ctx,
      id("b"),
      @typing.internalize_valtype(
        ctx.type_context,
        ctx.diagnostics,
        Ref({ nullable: false, typ: Type(id("bytes")) }),
      ),
    )
    let checker = @typing.Checker::new(ctx, @typing.Operands::new())
    let inner = instr(recv, 20)
    let c = checker.statement(
      instr(
        Call(instr(StructGet(inner, { name: meth, loc: loc_at(24, 30) }), 20), []),
        10,
      ),
    )
    guard! c.desc is Call(callee, _)
    guard! callee.desc is StructGet(r, _)
    c.info.0.map(t => @infer.to_string(t)).join(",") +
    " from " +
    r.info.0.map(t => @infer.to_string(t)).join(",") +
    " | " +
    ctx.diagnostics
    .collected()
    .map(d => @message.to_plain_string(d.message))
    .join(" / ")
  }

  // `length` on an array answers i32 whatever the array holds.
  inspect(call(Get(id("b")), "length"), content="i32 from &bytes | ")
  // `clz` makes an INTEGER of a bare literal; `sqrt` makes a float of one.
  inspect(call(Int("1"), "clz"), content="int from int | ")
  inspect(call(Int("1"), "sqrt"), content="float from float | ")
  // `to_bits` needs a float, and a literal written without a point still is
  // one -- a float constant decompiled to a bare integer has not stopped being
  // a float.
  inspect(call(Int("1"), "to_bits"), content="i64 from f64 | ")
  // But a value already committed to the integer family is not coerced:
  // `to_bits` on an integer is meaningless, and moving its cell to f64 would
  // make the operation below it lower against the wrong operand.
  inspect(
    call(
      Cast(instr(Int("1"), 20), Signed(typ=I32, signage=Signed, strict=false)),
      "to_bits",
    ),
    content="any from i32 | This operation cannot be applied to a value of type 'i32'.",
  )
  // `length` on something that is not an array.
  inspect(
    call(Int("1"), "length"),
    content="any from number | This operation cannot be applied to a value of type 'number'.",
  )
}

///|
/// `tab[i]` on a TABLE name is `table.get`, the mirror of the `table.set` that
/// `tab[i] = v` becomes. The table is a static immediate, so its receiver is
/// never typed as a value -- and a local of the same name shadows it, making
/// the identical spelling an ordinary array read.
test "an indexed read picks table or array by its receiver" {
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  fn read(shadowed : Bool) -> String {
    let ctx = module_ctx()
    ctx.tables.add(
      ctx.diagnostics,
      "t",
      loc_at(0, 1),
      (I32, { nullable: true, typ: Func }),
    )
    if shadowed {
      @typing.bind_local(ctx, id("t"), Some(@infer.i32_valtype))
    }
    let checker = @typing.Checker::new(ctx, @typing.Operands::new())
    let c = checker.statement(
      instr(ArrayGet(instr(Get(id("t")), 20), instr(Int("0"), 30)), 10),
    )
    c.info.0.map(t => @infer.to_string(t)).join(",") +
    " | " +
    ctx.diagnostics
    .collected()
    .map(d => @message.to_plain_string(d.message))
    .join(" / ")
  }

  // The read produces the table's ELEMENT type, and the table name resolves as
  // a table rather than as an unbound variable.
  inspect(read(false), content="&?func | ")
  // Shadowed, the same spelling indexes a value -- which an i32 is not.
  inspect(read(true), content="any | Expected array.")
}

///|
/// A `v128::i8x16(..)` constant takes one literal per lane, and each must FIT
/// its lane width -- accepting BOTH the signed and unsigned range, since the
/// constant is a bit pattern and both spellings name the same byte.
test "a vector constant bounds each lane by its width" {
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  fn konst(
    shape : String,
    lanes : Array[@ast.InstrDesc[@basic.Location]],
  ) -> String {
    let ctx = module_ctx()
    let checker = @typing.Checker::new(ctx, @typing.Operands::new())
    let c = checker.statement(
      instr(
        Call(
          instr(
            Path({ name: "v128", loc: loc_at(20, 24) }, {
              name: shape,
              loc: loc_at(26, 32),
            }),
            20,
          ),
          lanes.mapi((k, l) => instr(l, 40 + k)),
        ),
        10,
      ),
    )
    c.info.0.map(t => @infer.to_string(t)).join(",") +
    " | " +
    ctx.diagnostics
    .collected()
    .map(d => @message.to_plain_string(d.message))
    .join(" / ")
  }

  fn sixteen(v : String) -> Array[@ast.InstrDesc[@basic.Location]] {
    Array::makei(16, _ => @ast.InstrDesc::Int(v))
  }

  // Sixteen byte lanes, each in range.
  inspect(konst("i8x16", sixteen("255")), content="v128 | ")
  // 256 does not fit a byte, under either reading.
  let over = sixteen("255")
  over[0] = Int("256")
  inspect(
    konst("i8x16", over),
    content="v128 | The lane value does not fit in 8 bits.",
  )
  // The wrong number of lanes.
  inspect(
    konst("i8x16", [Int("1")]),
    content="v128 | This instruction expects 16 operand(s) but 1 was/were provided.",
  )
  // A float literal is not an integer lane, whatever its value.
  let floaty = sixteen("1")
  floaty[0] = Float("1.5")
  inspect(
    konst("i8x16", floaty),
    content="v128 | The lane value does not fit in 8 bits.",
  )
  // A float SHAPE takes any numeric literal.
  inspect(
    konst("f32x4", [Float("1.5"), Int("2"), Float("3.5"), Int("4")]),
    content="v128 | ",
  )
  // A name that is no intrinsic at all.
  inspect(
    konst("nope", []),
    content="any | There is no 'v128::nope' intrinsic.",
  )
}

///|
/// A block used as a VALUE infers its result from what reaches its exit; the
/// same block used as a STATEMENT does not, and its trailing value is a leftover.
///
/// That difference is the whole point of expression position. Before it existed
/// every block was typed against its DECLARED results -- none, for a `do { .. }`
/// with no annotation -- so a block used as a value produced nothing and its
/// body's value stayed on the stack, and both were reported.
test "a block used as a value infers what its exit delivers" {
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  fn block(
    body : Array[@ast.Instr[@basic.Location]],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    instr(
      Block(label=None, typ={ params: [], results: [] }, block={
        desc: body,
        info: loc_at(at, at + 1),
      }),
      at,
    )
  }

  fn run(node : @ast.Instr[@basic.Location], as_value : Bool) -> String {
    let ctx = module_ctx()
    let checker = @typing.Checker::new(ctx, @typing.Operands::new())
    let c = if as_value {
      checker.expression(node)
    } else {
      checker.statement(node)
    }
    c.info.0.map(t => @infer.to_string(t)).join(",") +
    " | " +
    ctx.diagnostics
    .collected()
    .map(d => @message.to_plain_string(d.message))
    .join(" / ")
  }

  let five = block([instr(Int("5"), 20)], 10)
  // As a value: the fall-through IS the block's result, and it commits to a
  // width because there is no annotation to write anything else back.
  inspect(run(five, true), content="i32 | ")
  // As a statement: nothing is inferred, so the 5 is a value nobody took.
  inspect(run(five, false), content=" | This value remains on the stack.")
  // A trailing nested block is routed through the inferring result rather than
  // typed as a void statement -- so the inner block synthesizes its own type and
  // hands it out, instead of leaving its 5 behind.
  inspect(run(block([five], 5), true), content="i32 | ")

  // Checked against a type the context already knows, the block takes THAT as
  // its result rather than inferring one -- and writes it into its own function
  // type, since the lowering reads the type and not the annotation the source
  // omitted.
  let ctx = module_ctx()
  let checker = @typing.Checker::new(ctx, @typing.Operands::new())
  let c = checker.check(@infer.valtype_cell(@infer.i32_valtype), five)
  inspect(
    c.info.0.map(t => @infer.to_string(t)).join(",") +
    " results=" +
    (match c.desc {
      Block(typ~, ..) => typ.results.length().to_string()
      _ => "?"
    }) +
    " | " +
    ctx.diagnostics
    .collected()
    .map(d => @message.to_plain_string(d.message))
    .join(" / "),
    content="i32 results=1 | ",
  )
}

///|
/// A construction can leave its type unnamed when the context names it -- and
/// only check position carries the context down to it.
///
/// The same literal in expression position has nothing to take a type from, and
/// says so. The name is BORROWED, not adopted: the typed node keeps the source's
/// omitted spelling, because what was written is what the printer must print.
test "a construction takes its type from what the context expects" {
  let ctx = module_ctx()
  let tc = ctx.type_context
  let _ = @typing.add_type(tc, ctx.diagnostics, [
    {
      desc: (
        id("a"),
        {
          typ: Array({ mut_: false, typ: Value(I32) }),
          supertype: None,
          final_: true,
          descriptor: None,
          describes: None,
        },
      ),
      info: loc_at(0, 1),
    },
  ])
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  // An array of two elements, written with no type name.
  let literal = instr(
    ArrayFixed(None, [instr(Int("1"), 20), instr(Int("2"), 22)]),
    10,
  )
  let want = @typing.internalize(
    tc,
    ctx.diagnostics,
    Ref({ nullable: false, typ: Type(id("a")) }),
  ).unwrap()
  fn run(checked : Bool) -> String {
    let checker = @typing.Checker::new(ctx, @typing.Operands::new())
    let before = ctx.diagnostics.collected().length()
    let c = if checked {
      checker.check(want, literal)
    } else {
      checker.expression(literal)
    }
    let named = c.desc is ArrayFixed(Some(_), _)
    c.info.0.map(t => @infer.to_string(t)).join(",") +
    " named=\{named} | " +
    ctx.diagnostics.collected()[before:]
    .map(d => @message.to_plain_string(d.message))
    .join(" / ")
  }

  // Checked against `&a`, the literal takes `a` as its type -- and gives the
  // name straight back, so the output still reads as the source wrote it.
  inspect(run(true), content="&a named=false | ")
  // Synthesized, there is nothing to take.
  inspect(
    run(false),
    content="any named=false | Cannot infer the array type here; add an explicit type, as in '[T| ..]'.",
  )
}

///|
/// A method call is one syntax covering two different things, and the RECEIVER
/// decides which. `x.min(y)` is a wasm instruction with the receiver as its
/// first operand; `s.min(a, b)` is an indirect call through a struct field that
/// happens to be called `min`. Not even the argument count separates them.
test "a method call reads as an instruction or a call by its receiver" {
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  fn call(meth : String, recv_is_ref : Bool, nargs : Int) -> String {
    let ctx = module_ctx()
    let _ = @typing.add_type(ctx.type_context, ctx.diagnostics, [
      {
        desc: (
          id("s"),
          {
            typ: Struct([]),
            supertype: None,
            final_: true,
            descriptor: None,
            describes: None,
          },
        ),
        info: loc_at(0, 1),
      },
    ])
    let recv_type : @wasm_types.ValType[@ast.Ident] = if recv_is_ref {
      Ref({ nullable: true, typ: Type(id("s")) })
    } else {
      I32
    }
    @typing.declare_local(ctx, id("x"), recv_type)
    let checker = @typing.Checker::new(ctx, @typing.Operands::new())
    let args = Array::makei(nargs, k => instr(Int("1"), 40 + k))
    let c = checker.expression(
      instr(
        Call(
          instr(StructGet(instr(Get(id("x")), 20), id(meth, at=30)), 20),
          args,
        ),
        10,
      ),
    )
    c.info.0.map(t => @infer.to_string(t)).join(",") +
    " | " +
    ctx.diagnostics
    .collected()
    .map(d => @message.to_plain_string(d.message))
    .join(" / ")
  }

  // A numeric receiver: `x.rotl(1)` is the instruction, and its result is the
  // receiver's own type.
  inspect(call("rotl", false, 1), content="i32 | ")
  // The wrong arity still yields the method node -- an auto-closed `x.rotl()`
  // is worth keeping as a call -- with the arity reported and the receiver's
  // type carried out.
  inspect(
    call("rotl", false, 0),
    content="i32 | This instruction expects 1 operand(s) but 0 was/were provided.",
  )
  // A REFERENCE receiver with the same spelling is an indirect call through a
  // field, so it is the struct that is asked about the name.
  inspect(
    call("rotl", true, 1),
    content="any | There is no field named 'rotl'.",
  )
}

///|
/// A tuple produces ONE value per element, in order. That is how a multi-value
/// operand is written -- `br_if 'l (9, cond)` delivers 9 and tests cond -- so
/// reading only the last element's values loses every one before it.
test "a tuple produces one value per element" {
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  let ctx = module_ctx()
  let checker = @typing.Checker::new(ctx, @typing.Operands::new())
  let c = checker.expression(
    instr(
      Sequence([
        instr(Int("9"), 20),
        instr(Cast(instr(Int("1"), 22), Value(I64)), 22),
      ]),
      10,
    ),
  )
  inspect(
    c.info.0.map(t => @infer.to_string(t)).join(",") +
    " | " +
    ctx.diagnostics
    .collected()
    .map(d => @message.to_plain_string(d.message))
    .join(" / "),
    content="number,i64 | ",
  )
}

///|
/// A `#![feature = "..."]` states a fact about the WHOLE module, so it is
/// applied before anything asks whether a feature is enabled -- and a copy of it
/// inside a conditional is a misplacement rather than a guarded declaration.
test "a module declares its own features" {
  fn annotation(
    name : String,
    value : String,
  ) -> @basic.Annotated[@ast.ModuleField[@basic.Location], @basic.Location] {
    {
      desc: ModuleAnnotation([
        {
          attr_name: name,
          attr_value: Some({
            desc: Str(
              None,
              Bytes::from_array(
                @unicode.utf8_bytes(value).map(b => b.to_byte()),
              ),
            ),
            info: loc_at(10, 20),
            hints: { branch: None, freq: None, targets: None },
            expected: None,
          }),
          attr_guard: None,
          attr_span: loc_at(0, 20),
        },
      ]),
      info: loc_at(0, 20),
    }
  }

  fn run(fields : @ast.Module[@basic.Location]) -> String {
    let d = @diagnostic.collector()
    let features = @feature.default()
    @typing.apply_declared_features(d, features, fields)
    (if features.is_enabled(CustomDescriptors) { "on" } else { "off" }) +
    " | " +
    d.collected().map(x => @message.to_plain_string(x.message)).join(" / ")
  }

  // Declared at the top level: on, and nothing to say about it.
  inspect(run([annotation("feature", "custom-descriptors")]), content="on | ")
  // A name that is not a feature is reported with the list of the ones that are.
  inspect(
    run([annotation("feature", "nope")]),
    content="off | Unknown feature 'nope'. Known features: custom-descriptors, compact-import-section.",
  )
  // Inside a conditional it is not applied at all: the declaration is resolved
  // before any branch is specialized, so a guarded one would leave every
  // construct it gates erroring whichever way the branch went.
  inspect(
    run([
      {
        desc: Conditional(
          cond=Var({ desc: "wasi", info: loc_at(0, 4) }),
          then_fields={
            desc: [annotation("feature", "custom-descriptors")],
            info: loc_at(0, 30),
          },
          else_fields=None,
        ),
        info: loc_at(0, 30),
      },
    ]),
    content="off | A '#![feature = \"…\"]' declaration states a fact about the whole module and must appear at the top level, not inside a conditional.",
  )
}

///|
/// A `try` takes its result the same three ways a block does: from its own
/// annotation, from the context, or -- with neither -- from what reaches its
/// exits. A HANDLER produces the try's value just as the body does, which is why
/// a try whose body always throws still has a type.
test "a try takes its result from its annotation, its context, or its exits" {
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  // `try_legacy { 1; } catch { t => { 2; } }`, with no result annotation.
  fn node(
    results : Array[@wasm_types.ValType[@ast.Ident]],
  ) -> @ast.Instr[@basic.Location] {
    instr(
      TryCatch(
        label=None,
        typ={ params: [], results },
        block={ desc: [instr(Int("1"), 20)], info: loc_at(20, 21) },
        arms=[
          {
            arm_tag: Some(id("t", at=30)),
            arm_ref: false,
            arm_types: [],
            arm_body: { desc: [instr(Int("2"), 40)], info: loc_at(40, 41) },
          },
        ],
      ),
      10,
    )
  }

  fn run(annotated : Bool, checked : Bool) -> String {
    let ctx = module_ctx()
    ctx.tags.add(ctx.diagnostics, "t", loc_at(0, 1), { params: [], results: [] })
    let checker = @typing.Checker::new(ctx, @typing.Operands::new())
    let n = node(if annotated { [I64] } else { [] })
    let c = if checked {
      checker.check(@infer.valtype_cell(@infer.i32_valtype), n)
    } else {
      checker.expression(n)
    }
    c.info.0.map(t => @infer.to_string(t)).join(",") +
    " results=" +
    (match c.desc {
      TryCatch(typ~, ..) =>
        typ.results
        .map(t => {
          @infer.to_string(
            @infer.valtype_cell(
              @typing.internalize_valtype(ctx.type_context, ctx.diagnostics, t).unwrap(),
            ),
          )
        })
        .join(",")
      _ => "?"
    }) +
    " | " +
    ctx.diagnostics
    .collected()
    .map(d => @message.to_plain_string(d.message))
    .join(" / ")
  }

  // Its own annotation wins outright.
  inspect(run(true, false), content="i64 results=i64 | ")
  // No annotation, and a context: the context supplies it, and it is written
  // back into the type -- the lowering reads the type, not the source.
  inspect(run(false, true), content="i32 results=i32 | ")
  // Neither: the body's 1 and the handler's 2 both reach an exit, and their
  // join is the result.
  inspect(run(false, false), content="i32 results=i32 | ")
}

///|
/// Every WRITE is a check position: the destination's type is known before the
/// value is typed, so a literal stored there takes that type rather than having
/// to name one. A local, a struct field and an array element are all the same
/// rule, and getting it wrong in one place shows up as the literal being
/// uninferable.
test "a write hands its destination's type to the value" {
  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  // `[0; n]` -- an array of n zeroes, with no type named.
  let literal = instr(Array(None, instr(Int("0"), 20), instr(Int("8"), 22)), 18)
  fn run(assign : Bool) -> String {
    let ctx = module_ctx()
    let _ = @typing.add_type(ctx.type_context, ctx.diagnostics, [
      {
        desc: (
          id("ints"),
          {
            typ: Array({ mut_: true, typ: Value(I32) }),
            supertype: None,
            final_: true,
            descriptor: None,
            describes: None,
          },
        ),
        info: loc_at(0, 1),
      },
    ])
    @typing.declare_local(
      ctx,
      id("xs"),
      Ref({ nullable: false, typ: Type(id("ints")) }),
    )
    let checker = @typing.Checker::new(ctx, @typing.Operands::new())
    let c = if assign {
      checker.statement(instr(Set(id("xs", at=10), None, literal), 10))
    } else {
      checker.expression(literal)
    }
    ignore(c)
    ctx.diagnostics
    .collected()
    .map(d => @message.to_plain_string(d.message))
    .join(" / ")
  }

  // Assigned to a local of array type, the literal takes it.
  inspect(run(true), content="")
  // Standing on its own, there is nothing to take.
  inspect(
    run(false),
    content="Cannot infer the array type here; add an explicit type, as in '[T| ..]'.",
  )
}

///|
/// A struct literal's FIELDS name the exact struct being built; an expected type
/// may be a supertype of it that has none of them. So field inference takes
/// precedence, and the context is the fallback for when the fields are
/// ambiguous -- not the first answer.
test "a struct literal's fields outrank the type expected of it" {
  let ctx = module_ctx()
  let tc = ctx.type_context
  fn field(
    f : String,
    at : Int,
  ) -> @basic.Annotated[
    (@ast.Ident, @wasm_types.MutType[@wasm_types.StorageType[@ast.Ident]]),
    @basic.Location,
  ] {
    let ty : @wasm_types.MutType[@wasm_types.StorageType[@ast.Ident]] = {
      mut_: true,
      typ: Value(I32),
    }
    { desc: (id(f), ty), info: loc_at(at, at + 1) }
  }

  fn declare_struct(n : String, t : @ast.CompType, at : Int) -> Unit {
    let _ = @typing.add_type(tc, ctx.diagnostics, [
      {
        desc: (
          id(n),
          {
            typ: t,
            supertype: None,
            final_: true,
            descriptor: None,
            describes: None,
          },
        ),
        info: loc_at(at, at + 1),
      },
    ])
  }

  // `base` has one field, `derived` has that one and another. A literal naming
  // both pins `derived`, which `base` could never be.
  fn value(at : Int) -> @ast.Instr[@basic.Location] {
    {
      desc: Int("1"),
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  declare_struct("base", Struct([field("a", 0)]), 0)
  declare_struct("derived", Struct([field("a", 4), field("b", 5)]), 4)
  // The field index is built once, after every type is registered -- so a
  // literal's fields can be answered completely rather than by whatever
  // happened to be declared above it.
  @typing.index_structs_by_fields(ctx)
  let literal : @ast.Instr[@basic.Location] = {
    desc: Struct(None, [
      (id("a", at=20), Some(value(22))),
      (id("b", at=24), Some(value(26))),
    ]),
    info: loc_at(18, 19),
    hints: { branch: None, freq: None, targets: None },
    expected: None,
  }
  let want = @typing.internalize(
    tc,
    ctx.diagnostics,
    Ref({ nullable: false, typ: Type(id("base")) }),
  ).unwrap()
  let checker = @typing.Checker::new(ctx, @typing.Operands::new())
  // Checked against `&base` -- which has no `b` -- the fields still win, and
  // the mismatch is reported against the whole literal rather than the field.
  let c = checker.check(want, literal)
  inspect(c.info.0.map(t => @infer.to_string(t)).join(","), content="&derived")
  inspect(
    ctx.diagnostics
    .collected()
    .map(d => @message.to_plain_string(d.message))
    .join(" / "),
    content="This expression has type '&derived' but is expected to have type '&base'.",
  )
}

///|
/// A stack-switching instruction's value operands take their types from the
/// CONSTRUCT, not from themselves: `resume` from the continuation's parameters,
/// `resume_throw` from the tag it raises. So they are resolved before the
/// operands are typed -- which is what lets an operand that needs a type from
/// somewhere, such as a block whose result was omitted, get one.
test "a resume's operands take their types from the continuation" {
  let ctx = module_ctx()
  let tc = ctx.type_context
  fn declare_type(n : String, t : @ast.CompType, at : Int) -> Unit {
    let _ = @typing.add_type(tc, ctx.diagnostics, [
      {
        desc: (
          id(n),
          {
            typ: t,
            supertype: None,
            final_: true,
            descriptor: None,
            describes: None,
          },
        ),
        info: loc_at(at, at + 1),
      },
    ])
  }

  fn instr(
    d : @ast.InstrDesc[@basic.Location],
    at : Int,
  ) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(at, at + 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  // `type sig = fn(i64); type k = cont sig;` -- resuming `k` hands it an i64.
  declare_type(
    "sig",
    Func({ params: [{ desc: (None, I64), info: loc_at(0, 1) }], results: [] }),
    0,
  )
  declare_type("k", Cont(id("sig")), 2)
  @typing.declare_local(
    ctx,
    id("c"),
    Ref({ nullable: true, typ: Type(id("k")) }),
  )
  let checker = @typing.Checker::new(ctx, @typing.Operands::new())
  // `resume k (1, c)` -- the 1 is a bare literal, and only the continuation's
  // signature says how wide it is.
  let c = checker.statement(
    instr(
      Resume(id("k", at=10), [], [
        instr(Int("1"), 20),
        instr(Get(id("c", at=22)), 22),
      ]),
      10,
    ),
  )
  inspect(
    (match c.desc {
      Resume(_, _, args) =>
        @infer.to_string(@typing.expression_type(ctx, args[0].info))
      _ => "?"
    }) +
    " | " +
    ctx.diagnostics
    .collected()
    .map(d => @message.to_plain_string(d.message))
    .join(" / "),
    content="i64 | ",
  )
}

///|
/// The unused-declaration lint asks about REACHABILITY, not the presence of a
/// reference. Two functions that only call each other reference one another, so
/// a presence check finds both used -- yet neither can ever run.
test "a dead cycle of functions is still dead" {
  fn run(exported : Bool) -> String {
    let ctx = @typing_env.ModuleContext::new(
      @diagnostic.collector(),
      @type_store.TypeStore::new(),
      @feature.default(),
      warn_unused=true,
    )
    fn func(
      n : String,
      calls : String,
      at : Int,
      export_ : Bool,
    ) -> @basic.Annotated[@ast.ModuleField[@basic.Location], @basic.Location] {
      let body : @ast.Instr[@basic.Location] = {
        desc: Call(
          {
            desc: Get(id(calls, at=at + 10)),
            info: loc_at(at + 10, at + 11),
            hints: { branch: None, freq: None, targets: None },
            expected: None,
          },
          [],
        ),
        info: loc_at(at + 10, at + 11),
        hints: { branch: None, freq: None, targets: None },
        expected: None,
      }
      {
        desc: Func(
          name=id(n, at~),
          typ=None,
          sign=Some({ params: [], results: [] }),
          body=(None, [body]),
          attributes=if export_ {
            [
              {
                attr_name: "export",
                attr_value: None,
                attr_guard: None,
                attr_span: loc_at(at, at + 1),
              },
            ]
          } else {
            []
          },
        ),
        info: loc_at(at, at + 1),
      }
    }

    // `a` calls `b`, `b` calls `a`, and nothing else calls either.
    let fields = [func("a", "b", 0, exported), func("b", "a", 40, false)]
    let _ = @typing.check_module(
      ctx.diagnostics,
      @type_store.TypeStore::new(),
      @feature.default(),
      fields,
      warn_unused=true,
    )
    ctx.diagnostics
    .collected()
    .map(d => @message.to_plain_string(d.message))
    .join(" / ")
  }

  // Neither can run, so both are reported -- a presence check would find both
  // used and say nothing.
  inspect(
    run(false),
    content="The function 'a' is never used. / The function 'b' is never used.",
  )
  // Export one and the cycle comes alive: the export reaches `a`, and `a`
  // reaches `b`.
  inspect(run(true), content="")
}

///|
/// `is_effectless` decides whether computing a value and throwing it away is
/// pointless, and it is conservative in the one direction that matters: anything
/// it does not recognise is assumed to have an effect, so the lint never calls a
/// computation useless when it might trap, write, or call.
test "an expression is effectless only when nothing it does can be observed" {
  fn instr(d : @ast.InstrDesc[@basic.Location]) -> @ast.Instr[@basic.Location] {
    {
      desc: d,
      info: loc_at(0, 1),
      hints: { branch: None, freq: None, targets: None },
      expected: None,
    }
  }

  fn pure(d : @ast.InstrDesc[@basic.Location]) -> Bool {
    @typing.is_effectless(instr(d))
  }

  let one = instr(Int("1"))
  let two = instr(Int("2"))
  let op = (b : @ast.BinOp) => {
    (
      { desc: b, info: loc_at(0, 1) } :
      @basic.Annotated[@ast.BinOp, @basic.Location])
  }
  // A literal, a read, and arithmetic over them.
  inspect(pure(Int("1")), content="true")
  inspect(pure(Get(id("x"))), content="true")
  inspect(pure(BinOpI(op(Add), one, two)), content="true")
  // Division and remainder trap on a zero divisor, so they are not.
  inspect(pure(BinOpI(op(Div(Some(Signed))), one, two)), content="false")
  inspect(pure(BinOpI(op(Rem(Signed)), one, two)), content="false")
  // A numeric cast is total; a SATURATING float-to-int is too, but the strict
  // form lowers to `trunc` and traps out of range.
  inspect(pure(Cast(one, Value(I64))), content="true")
  inspect(
    pure(Cast(one, Signed(typ=I32, signage=Signed, strict=false))),
    content="true",
  )
  inspect(
    pure(Cast(one, Signed(typ=I32, signage=Signed, strict=true))),
    content="false",
  )
  // A reference cast may trap.
  inspect(
    pure(Cast(one, Value(Ref({ nullable: false, typ: Any })))),
    content="false",
  )
  // Except a typed NULL, which is `ref.null` -- a constant.
  inspect(
    pure(Cast(instr(Null), Value(Ref({ nullable: true, typ: Any })))),
    content="true",
  )
  // A pure instruction method is; a call is not.
  inspect(pure(Call(instr(StructGet(one, id("sqrt"))), [])), content="true")
  inspect(pure(Call(instr(Get(id("f"))), [])), content="false")
}
