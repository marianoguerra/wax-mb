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
  let diagnostics = @diagnostic.collector()
  let t : @typing_env.Tbl[Int] = @typing_env.Tbl::new("function", ns, origin)
  t.add(diagnostics, "f", loc_at(10, 11), 1)
  t.add(diagnostics, "g", loc_at(20, 21), 2)
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
  let diagnostics = @diagnostic.collector()
  let t : @typing_env.Tbl[Int] = @typing_env.Tbl::new("function", ns, origin)

  // Declared inside `#[if($debug)]`.
  cond.val = debug
  t.add(diagnostics, "only_debug", loc_at(10, 11), 1)
  // And a second declaration of the same name in the other branch.
  cond.val = @cond.not_(debug)
  t.add(diagnostics, "only_debug", loc_at(20, 21), 2)

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
  let diagnostics = @diagnostic.collector()
  let t : @typing_env.Tbl[Int] = @typing_env.Tbl::new("function", ns, origin)
  t.add(diagnostics, "f", loc_at(10, 11), 1)
  t.add(diagnostics, "g", loc_at(12, 13), 2)
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
  let diagnostics = @diagnostic.collector()
  let t : @typing_env.Tbl[Int] = @typing_env.Tbl::new("function", ns, origin)
  t.add(diagnostics, "f", loc_at(10, 11), 1)
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

///|
/// The module context's constructor is the only place that can guarantee every
/// table shares one branch assumption and one origin -- and that sharing is
/// what lets a fact set in one place be seen in another.
test "the tables share their refs" {
  let ctx = @typing_env.ModuleContext::new(
    @diagnostic.collector(),
    @type_store.TypeStore::new(),
    @feature.default(),
  )
  let env = @cond.Env::new()
  let debug = env.of_cond(@diagnostic.collector(), loc_at(0, 0), var_("debug"))

  // Declared under `#[if($debug)]` in one table...
  ctx.cond.val = debug
  ctx.functions.add(ctx.diagnostics, "f", loc_at(10, 11), None)
  ctx.globals.add(ctx.diagnostics, "g", loc_at(12, 13), (false, None))

  // ...and invisible from the other branch in BOTH, because they share `cond`.
  ctx.cond.val = @cond.not_(debug)
  inspect(ctx.functions.visible("f").length(), content="0")
  inspect(ctx.globals.visible("g").length(), content="0")
  ctx.cond.val = debug
  inspect(ctx.functions.visible("f").length(), content="1")
  inspect(ctx.globals.visible("g").length(), content="1")

  // And one origin attributes lookups in every table.
  ctx.origin.val = FromFunction("main")
  let _ = ctx.functions.resolve("f", loc_at(20, 21))
  let _ = ctx.globals.resolve("g", loc_at(22, 23))
  inspect(ctx.functions.referrers("f").length(), content="1")
  inspect(ctx.globals.referrers("g").length(), content="1")
}

///|
/// Per-function state is reset on entry, and the fields it clears are exactly
/// the ones documented as per-function -- which is what makes that claim
/// checkable rather than a set of promises spread through the record.
test "entering a function clears the per-function state" {
  let ctx = @typing_env.ModuleContext::new(
    @diagnostic.collector(),
    @type_store.TypeStore::new(),
    @feature.default(),
  )
  ctx.locals["x"] = (None, loc_at(0, 1))
  ctx.initialized_locals["x"] = ()
  ctx.read_locals.push(5)
  ctx.local_decls.push({ name: "x", loc: loc_at(0, 1) })
  ctx.used_labels.push(7)
  ctx.unresolved_label.val = true
  ctx.enter_function(return_types=[@infer.valtype_cell(@infer.i32_valtype)])
  inspect(ctx.locals.length(), content="0")
  inspect(ctx.initialized_locals.length(), content="0")
  inspect(ctx.read_locals.length(), content="0")
  inspect(ctx.local_decls.length(), content="0")
  inspect(ctx.used_labels.length(), content="0")
  inspect(ctx.unresolved_label.val, content="false")
  inspect(ctx.control_types.length(), content="0")
  inspect(ctx.return_types.length(), content="1")
}

///|
/// A control frame lasts exactly as long as the block that opened it, and an
/// assignment inside a block does not escape it -- the block may not run.
test "frames and initialization do not outlive their block" {
  let ctx = @typing_env.ModuleContext::new(
    @diagnostic.collector(),
    @type_store.TypeStore::new(),
    @feature.default(),
  )
  ctx.enter_function(return_types=[])
  ctx.initialized_locals["outer"] = ()
  let depth = ctx.with_frame(@typing_env.ControlFrame::new([]), () => {
    // Inside, the new frame is innermost and the outer ones are still reachable.
    ctx.initialized_locals["inner"] = ()
    ctx.control_types.length()
  })
  inspect(depth, content="1")
  inspect(ctx.control_types.length(), content="0")
  // The assignment inside did not escape: opening a frame takes the snapshot.
  inspect(ctx.initialized_locals.contains("inner"), content="false")

  // Which is the same thing asking for the snapshot directly does.
  ctx.with_initialized_snapshot(() => ctx.initialized_locals["inner"] = ())
  inspect(ctx.initialized_locals.contains("inner"), content="false")
  inspect(ctx.initialized_locals.contains("outer"), content="true")
}

///|
/// A name declared twice is reported once, and still resolves -- to the second.
///
/// Both halves matter. Dropping the second declaration would leave every later
/// use reading as unbound, turning one duplicate into a report per use; and the
/// report names what the name is already taken BY, which need not be the same
/// kind of thing.
test "a duplicate declaration is reported, and the name still resolves" {
  let cond = @ref.new(@cond.true_)
  let ns = @typing_env.Namespace::new(cond)
  let origin = @ref.new(@typing_env.Origin::Root)
  let diagnostics = @diagnostic.collector()
  let memories : @typing_env.Tbl[Int] = @typing_env.Tbl::new(
    "memory", ns, origin,
  )
  // Memories and tables share one name space, so the clash crosses tables and
  // the report has to say which kind the name is already bound to.
  let tables : @typing_env.Tbl[Int] = @typing_env.Tbl::new("table", ns, origin)
  memories.add(diagnostics, "m", loc_at(10, 11), 1)
  tables.add(diagnostics, "m", loc_at(20, 21), 2)
  inspect(diagnostics.collected().length(), content="1")
  inspect(
    @message.to_plain_string(diagnostics.collected()[0].message),
    content="A memory named 'm' is already bound.",
  )
  // Blamed at the second, pointing back at the first.
  inspect(diagnostics.collected()[0].loc.start.cnum, content="20")
  inspect(diagnostics.collected()[0].related[0].loc.start.cnum, content="10")
  // And the second declaration stands.
  inspect(tables.resolve("m", loc_at(30, 31)).unwrap_or(-1), content="2")
}

///|
/// Two declarations in mutually exclusive branches are not a duplicate: no
/// configuration has both, so there is nothing to report.
test "mutually exclusive branches do not clash" {
  let cond = @ref.new(@cond.true_)
  let env = @cond.Env::new()
  let diagnostics = @diagnostic.collector()
  let debug = env.of_cond(diagnostics, loc_at(0, 0), var_("debug"))
  let ns = @typing_env.Namespace::new(cond)
  let origin = @ref.new(@typing_env.Origin::Root)
  let t : @typing_env.Tbl[Int] = @typing_env.Tbl::new("function", ns, origin)
  cond.val = debug
  t.add(diagnostics, "f", loc_at(10, 11), 1)
  cond.val = @cond.not_(debug)
  t.add(diagnostics, "f", loc_at(20, 21), 2)
  inspect(diagnostics.collected().length(), content="0")
  // A third, under no assumption at all, can hold with either -- so it does
  // clash, and with the nearest of them.
  cond.val = @cond.true_
  t.add(diagnostics, "f", loc_at(30, 31), 3)
  inspect(diagnostics.collected().length(), content="1")
  inspect(diagnostics.collected()[0].related[0].loc.start.cnum, content="20")
}

///|
/// A recursion group registers its members with placeholder values so they can
/// name each other, then settles them -- or takes them back out if the group
/// fails to resolve.
test "a declaration can be settled or withdrawn" {
  let cond = @ref.new(@cond.true_)
  let ns = @typing_env.Namespace::new(cond)
  let origin = @ref.new(@typing_env.Origin::Root)
  let diagnostics = @diagnostic.collector()
  let t : @typing_env.Tbl[Int] = @typing_env.Tbl::new("type", ns, origin)
  t.add(diagnostics, "node", loc_at(10, 11), 1)
  t.override_("node", 99)
  inspect(t.resolve("node", loc_at(30, 31)).unwrap_or(-1), content="99")
  t.remove("node")
  inspect(t.resolve("node", loc_at(32, 33)).unwrap_or(-1), content="-1")
  // Withdrawing the value does NOT unsay the declaration: the name was still
  // written there, so declaring it again is still a duplicate.
  t.add(diagnostics, "node", loc_at(40, 41), 2)
  inspect(diagnostics.collected().length(), content="1")
  inspect(diagnostics.collected()[0].related[0].loc.start.cnum, content="10")
}

///|
/// The checker's own lookups are not references anyone wrote, and must not keep
/// a declaration alive: a function resolving its own declared type does not
/// make that type used.
test "an internal lookup is not a reference" {
  let cond = @ref.new(@cond.true_)
  let ns = @typing_env.Namespace::new(cond)
  let origin = @ref.new(@typing_env.Origin::Root)
  let diagnostics = @diagnostic.collector()
  let t : @typing_env.Tbl[Int] = @typing_env.Tbl::new("type", ns, origin)
  t.add(diagnostics, "node", loc_at(10, 11), 1)
  inspect(t.find_no_mark("node").unwrap_or(-1), content="1")
  inspect(t.referrers("node").length(), content="0")
  // A use that names no declaration syntactically -- a string literal's byte
  // array -- is still a reference, and is marked as one directly.
  t.mark_reference("node", FromFunction("main"))
  inspect(t.referrers("node").length(), content="1")
}
