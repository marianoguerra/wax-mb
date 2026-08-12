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
    { final_: true, supertype: None, typ: Func({ params: [], results: [] }) },
  ])
}

///|
/// A bare name resolves in the language's order, and a local shadows
/// everything. Globals, functions, memories and tables share one namespace, so
/// a local is the only thing that can collide with them.
test "a local shadows everything" {
  let ctx = module_ctx()
  ctx.globals.add("x", loc_at(0, 1), (false, None))
  ctx.functions.add("f", loc_at(2, 3), Some((some_id(), "t", false)))
  ctx.memories.add("m", loc_at(4, 5), (0, I32))
  ctx.tables.add("t", loc_at(6, 7), (I32, { nullable: true, typ: Func }))
  ctx.datas.add("d", loc_at(8, 9), ())
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
  ctx.functions.add("broken", loc_at(0, 1), None)
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
  ctx.globals.add("g", loc_at(4, 5), (false, Some(@infer.f64_valtype)))
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
  ctx.globals.add("threshold", loc_at(4, 5), (false, None))
  ctx.functions.add("compute", loc_at(6, 7), None)
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
  ctx.globals.add("total", loc_at(0, 1), (true, None))
  ctx.globals.add("limit", loc_at(2, 3), (false, None))
  ctx.functions.add("compute", loc_at(4, 5), None)
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
    attempt(ctx => ctx.globals.add("g", loc_at(0, 1), (true, None)), "g"),
    content="",
  )
  // An immutable one: not.
  inspect(
    attempt(ctx => ctx.globals.add("g", loc_at(0, 1), (false, None)), "g"),
    content="This global is immutable and cannot be assigned.",
  )
  // A function is not a variable.
  let real_id = some_id()
  inspect(
    attempt(
      ctx => ctx.functions.add("f", loc_at(0, 1), Some((real_id, "t", false))),
      "f",
    ),
    content="'f' cannot be assigned.",
  )
  // A function whose signature failed to resolve is POISONED rather than a
  // function reference, and says nothing further -- it was reported at its
  // definition.
  inspect(
    attempt(ctx => ctx.functions.add("f", loc_at(0, 1), None), "f"),
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
  ctx.globals.add("used", loc_at(0, 1), (true, None))
  ctx.globals.add("never", loc_at(2, 3), (true, None))
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
    tee(ctx => ctx.globals.add("g", loc_at(0, 1), (true, None)), "g"),
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
    { final_: true, supertype: None, typ: Func({ params: [], results: [] }) },
  ])
  let empty : @ast.SubType = {
    typ: Func({ params: [], results: [] }),
    supertype: None,
    final_: true,
    descriptor: None,
    describes: None,
  }
  ctx.types.add("node", loc_at(0, 4), (Def(store_id), empty))
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
