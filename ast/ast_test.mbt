// The AST is data, so these tests target the design decisions rather than the
// constructors: the Info parameter must genuinely support re-annotation, the
// fields this port never populates must still exist, and the shapes that carry
// their own span must keep it.

///|
fn loc(a : Int, b : Int) -> @basic.Location {
  {
    start: { fname: "t.wax", lnum: 1, bol: 0, cnum: a },
    end: { fname: "t.wax", lnum: 1, bol: 0, cnum: b },
  }
}

///|
fn id(name : String) -> @ast.Ident {
  { name, loc: loc(0, name.length()) }
}

///|
fn body(xs : Array[@ast.Instr[@basic.Location]]) -> @ast.Body[@basic.Location] {
  { desc: xs, info: loc(0, 1) }
}

///|
test "a parsed instruction carries no hints and no expected type" {
  // Both fields exist for the typer and the decompiler; a parse must leave them
  // empty, and a later phase filling them must be a deliberate act.
  let i = @ast.build(Nop, loc(0, 3))
  assert_true(i.hints.is_empty())
  assert_eq(i.expected, None)
}

///|
test "the tree can be re-annotated, which is why Info is a parameter" {
  // Sketch of what the type checker does: rebuild the same shape with a
  // different annotation type. If this stopped compiling, the parameter would
  // be decoration and porting the typer would mean rewriting the AST.
  let inner = @ast.build(Int("1"), loc(0, 1))
  let outer = @ast.build(
    BinOpI({ desc: Add, info: loc(1, 2) }, inner, inner),
    loc(0, 3),
  )
  fn retype(i : @ast.Instr[@basic.Location]) -> @ast.Instr[String] {
    let desc : @ast.InstrDesc[String] = match i.desc {
      Int(s) => Int(s)
      BinOpI(op, l, r) => BinOpI(op, retype(l), retype(r))
      _ => Nop
    }
    { desc, info: "i32", hints: i.hints, expected: i.expected }
  }

  let typed = retype(outer)
  assert_eq(typed.info, "i32")
  match typed.desc {
    BinOpI(_, l, _) => assert_eq(l.info, "i32")
    _ => fail("shape changed")
  }
}

///|
test "a block body carries its own braces span" {
  // The trivia layer needs it: a comment inside an otherwise-empty block has no
  // instruction to attach to, only the block's own braces.
  let b : @ast.Body[@basic.Location] = { desc: [], info: loc(9, 11) }
  let blk = @ast.build(
    Block(label=None, typ={ params: [], results: [] }, block=b),
    loc(0, 12),
  )
  match blk.desc {
    Block(block~, ..) => {
      assert_eq(block.desc.length(), 0)
      assert_eq(block.info.start.cnum, 9) // the `{`, not the whole block
    }
    _ => fail("shape changed")
  }
}

///|
test "numeric literals are stored as raw text" {
  // Round-tripping depends on it, and so will the typer's flexible literals.
  let i = @ast.build(Int("0x1_0"), loc(0, 5))
  match i.desc {
    Int(s) => assert_eq(s, "0x1_0") // not normalised to "16"
    _ => fail("shape changed")
  }
}

///|
test "struct field punning is distinguishable from an explicit value" {
  // `{x}` and `{x: x}` mean the same thing but must print back differently.
  let punned = @ast.build(Struct(None, [(id("x"), None)]), loc(0, 3))
  let explicit = @ast.build(
    Struct(None, [(id("x"), Some(@ast.build(Get(id("x")), loc(4, 5))))]),
    loc(0, 8),
  )
  assert_not_eq(punned, explicit)
}

///|
test "compound assignment keeps its operator" {
  // `x += e` must not be normalised to `x = x + e`; both spellings round-trip.
  let plain = @ast.build(
    Set(id("x"), None, @ast.build(Int("1"), loc(4, 5))),
    loc(0, 5),
  )
  let compound = @ast.build(
    Set(
      id("x"),
      Some({ desc: Add, info: loc(2, 4) }),
      @ast.build(Int("1"), loc(5, 6)),
    ),
    loc(0, 6),
  )
  assert_not_eq(plain, compound)
}

///|
test "a try-catch arm's entry stack is empty as parsed" {
  // The typer fills arm_types and the wasm lowering reads it; the parser must
  // not guess.
  let arm : @ast.TryCatchArm[@basic.Location] = {
    arm_tag: Some(id("exc")),
    arm_ref: false,
    arm_types: [],
    arm_body: body([]),
  }
  assert_eq(arm.arm_types.length(), 0)
}

///|
test "the splice sentinel cannot collide with a real field" {
  // `..` is not a valid identifier, which is the whole point of the choice.
  let s = @ast.splice_field(loc(0, 2))
  assert_true(@ast.is_splice_field(s))
  assert_eq(@ast.splice_field_name, "..")
  let real : @basic.Annotated[
    (@ast.Ident, @wasm_types.FieldType[@ast.Ident]),
    @basic.Location,
  ] = { desc: (id("value"), { mut_: false, typ: Value(I32) }), info: loc(0, 5) }
  assert_false(@ast.is_splice_field(real))
}

///|
test "signed cast types render as the reference spells them" {
  assert_eq(@ast.format_signed_type(I32, Signed, false), "i32_s")
  assert_eq(@ast.format_signed_type(I64, Unsigned, true), "i64_u_strict")
}

///|
test "an operator that admits floats leaves signedness open" {
  // `/` on floats has no signedness; `%` always does. `None` records that the
  // spelling did not commit, for the typer to resolve.
  let float_div : @ast.BinOp = Div(None)
  let int_div : @ast.BinOp = Div(Some(Signed))
  assert_not_eq(float_div, int_div)
  let rem : @ast.BinOp = Rem(Unsigned)
  assert_eq(rem, Rem(Unsigned))
}

///|
test "a module is just a list of spanned fields" {
  let m : @ast.LocModule = [
    {
      desc: Func(
        name=id("f"),
        typ=None,
        sign=Some({ params: [], results: [] }),
        body=(None, []),
        attributes=[],
      ),
      info: loc(0, 12),
    },
  ]
  assert_eq(m.length(), 1)
}
