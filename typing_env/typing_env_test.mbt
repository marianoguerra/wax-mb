// Tests for the checker's working state.
//
// The behaviour worth pinning is the part conditional compilation reshapes:
// under `#[if]`, a name declared in a sibling branch is neither in scope nor
// unbound, and which of those it is depends on a satisfiability query rather
// than on a table lookup.

///|
fn loc_at(start : Int, end_ : Int) -> @basic.Location {
  {
    start: { fname: "t.wax", lnum: 1, bol: 0, cnum: start },
    end: { fname: "t.wax", lnum: 1, bol: 0, cnum: end_ },
  }
}

///|
fn var_(name : String) -> @wasm_types.Cond {
  Var({ desc: name, info: loc_at(0, 0) })
}

///|
/// With no conditionals the tables are plain name-keyed ones, and this is what
/// says so.
test "an unconditional table" {
  let cond = @ref.new(@cond.true_)
  let ns = @typing_env.Namespace::new(cond)
  let origin = @ref.new(@typing_env.Origin::Root)
  let t : @typing_env.Tbl[Int] = @typing_env.Tbl::new("function", ns, origin)
  t.add("f", loc_at(10, 11), 1)
  t.add("g", loc_at(20, 21), 2)
  inspect(t.resolve("f", loc_at(30, 31)).unwrap_or(-1), content="1")
  inspect(t.resolve("g", loc_at(32, 33)).unwrap_or(-1), content="2")
  inspect(t.resolve("h", loc_at(34, 35)).unwrap_or(-1), content="-1")
  inspect(t.visible("f").length(), content="1")
  inspect(t.visible("h").length(), content="0")
}

///|
/// The point of the whole arrangement: a name declared under `$debug` is not
/// visible while checking the `not $debug` branch, and is visible while
/// checking the `$debug` one.
test "a name is visible only where its assumption can hold" {
  let cond = @ref.new(@cond.true_)
  let env = @cond.Env::new()
  let ctx = @diagnostic.collector()
  let debug = env.of_cond(ctx, loc_at(0, 0), var_("debug"))
  let ns = @typing_env.Namespace::new(cond)
  let origin = @ref.new(@typing_env.Origin::Root)
  let t : @typing_env.Tbl[Int] = @typing_env.Tbl::new("function", ns, origin)

  // Declared inside `#[if($debug)]`.
  cond.val = debug
  t.add("only_debug", loc_at(10, 11), 1)
  // And a second declaration of the same name in the other branch.
  cond.val = @cond.not_(debug)
  t.add("only_debug", loc_at(20, 21), 2)

  // Checking the debug branch sees the first.
  cond.val = debug
  inspect(t.resolve("only_debug", loc_at(30, 31)).unwrap_or(-1), content="1")
  // Checking the other branch sees the second.
  cond.val = @cond.not_(debug)
  inspect(t.resolve("only_debug", loc_at(32, 33)).unwrap_or(-1), content="2")
  // With no assumption at all both are consistent, so both are visible -- which
  // is what makes a duplicate-declaration check a satisfiability question
  // rather than a count.
  cond.val = @cond.true_
  inspect(t.visible("only_debug").length(), content="2")
  // Under the debug branch only one is.
  cond.val = debug
  inspect(
    t.visible("only_debug").map(v => v.to_string()).join(","),
    content="1",
  )
}

///|
/// A lookup records where it was made from, because "is this referenced?" is
/// not the same question as "does anything that can run reference it?".
test "references are attributed to their origin" {
  let cond = @ref.new(@cond.true_)
  let ns = @typing_env.Namespace::new(cond)
  let origin = @ref.new(@typing_env.Origin::Root)
  let t : @typing_env.Tbl[Int] = @typing_env.Tbl::new("function", ns, origin)
  t.add("f", loc_at(10, 11), 1)
  t.add("g", loc_at(12, 13), 2)
  origin.val = FromFunction("main")
  let _ = t.resolve("f", loc_at(20, 21))
  origin.val = FromFunction("other")
  let _ = t.resolve("f", loc_at(22, 23))
  // The same origin twice is one entry.
  let _ = t.resolve("f", loc_at(24, 25))
  fn origins(n : String) -> String {
    t
    .referrers(n)
    .map(o => {
      match o {
        Root => "root"
        FromFunction(f) => "fn:" + f
        FromType(t) => "type:" + t
        Ignored => "ignored"
      }
    })
    .join(",")
  }

  inspect(origins("f"), content="fn:main,fn:other")
  inspect(origins("g"), content="")
  // The re-check pass marks nothing used.
  origin.val = Ignored
  let _ = t.resolve("g", loc_at(26, 27))
  inspect(origins("g"), content="")
}

///|
/// Go-to-definition records a use and the definitions it binds to, but not a
/// definition's reference to itself -- which has nowhere useful to go.
test "resolved references are recorded for the editor" {
  let sink : Array[@typing_env.Reference] = []
  let cond = @ref.new(@cond.true_)
  let ns = @typing_env.Namespace::new(cond, links=Some(sink))
  let origin = @ref.new(@typing_env.Origin::Root)
  let t : @typing_env.Tbl[Int] = @typing_env.Tbl::new("function", ns, origin)
  t.add("f", loc_at(10, 11), 1)
  let _ = t.resolve("f", loc_at(30, 31))
  inspect(sink.length(), content="1")
  inspect(sink[0].use_.start.cnum, content="30")
  inspect(
    sink[0].definitions.map(d => d.start.cnum.to_string()).join(","),
    content="10",
  )
  // A name looking itself up records nothing.
  let _ = t.resolve("f", loc_at(10, 11))
  inspect(sink.length(), content="1")
  // Nor does a synthesized use, whose span carries the -1 sentinel rather
  // than 0 -- 0 is a legitimate offset.
  let _ = t.resolve("f", @basic.dummy_loc)
  inspect(sink.length(), content="1")
}

///|
/// A flexible literal has no width until something gives it one, and this is
/// the width it defaults to when nothing does.
test "a cell's standalone type" {
  fn name_of(c : @infer.Cell[@infer.InferredType]) -> String {
    match @typing_env.standalone_valtype(c) {
      None => "none"
      Some(v) => @infer.to_string(@infer.valtype_cell(v))
    }
  }

  inspect(name_of(@infer.Cell::make(Number)), content="i32")
  inspect(name_of(@infer.Cell::make(Int)), content="i32")
  inspect(name_of(@infer.Cell::make(LargeInt)), content="i64")
  inspect(name_of(@infer.Cell::make(Float)), content="f64")
  inspect(name_of(@infer.Cell::make(Null)), content="&?none")
  // The non-null bottom, which is what `null!` produced before UnknownRef
  // existed.
  inspect(name_of(@infer.Cell::make(UnknownRef)), content="&none")
  // A packed field type is not a value type, and neither is an unresolved one.
  inspect(name_of(@infer.Cell::make(Int8)), content="none")
  inspect(name_of(@infer.Cell::make(Unknown)), content="none")
  inspect(name_of(@infer.Cell::make(Error)), content="none")
}

///|
/// The source-scanning suggestions look for a delimiter to decide where a
/// rewrite goes, and one inside a comment is not syntax. Blanking rather than
/// deleting keeps every byte offset intact, so a span found in the blanked text
/// addresses the same bytes in the real one.
test "comments are blanked, not removed" {
  fn blank(s : String) -> String {
    @typing_env.blank_comments(s)
  }

  inspect(blank("a // b"), content="a     ")
  inspect(blank("a /* b */ c"), content="a         c")
  // Length and line structure survive.
  let src = "let x = 1; // : not a delimiter\nlet y = 2;"
  let out = blank(src)
  inspect(out.length() == src.length(), content="true")
  inspect(out.contains(":"), content="false")
  inspect(out.contains("\n"), content="true")
  inspect(out.has_prefix("let x = 1; "), content="true")
  // Block comments NEST, so the first `*/` does not necessarily end one.
  inspect(blank("a /* b /* c */ d */ e"), content="a                   e")
  // An unterminated comment blanks to the end rather than being ignored.
  inspect(blank("a /* b"), content="a     ")
}

///|
/// A span's source text, for the quick fixes that splice a rewrite into the
/// exact bytes a construct occupies.
test "source slices" {
  let src = Some("let x = 1;")
  fn slice(s : String?, l : @basic.Location) -> String {
    @typing_env.source_slice(s, l).unwrap_or("<none>")
  }

  inspect(slice(src, loc_at(4, 5)), content="x")
  inspect(slice(src, loc_at(0, 3)), content="let")
  // Out of range, and backwards, both decline rather than panic.
  inspect(@typing_env.source_slice(src, loc_at(0, 99)) is None, content="true")
  inspect(@typing_env.source_slice(src, loc_at(5, 4)) is None, content="true")
  inspect(
    @typing_env.source_slice(src, @basic.dummy_loc) is None,
    content="true",
  )
  inspect(@typing_env.source_slice(None, loc_at(0, 3)) is None, content="true")
}
