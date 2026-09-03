// Comment attachment.
//
// This decides where every comment ends up in reprinted output, so a mistake
// here is a silent relocation rather than a crash. The cases below are the ones
// the reference's own comments call out as load-bearing.

///|
fn pos(c : Int) -> @basic.Position {
  { fname: "t.wax", lnum: 1, bol: 0, cnum: c, }
}

///|
fn span(a : Int, b : Int) -> @basic.Location {
  { start: pos(a), end: pos(b), }
}

///|
/// Build a context with the given node spans and comments.
///
/// `nodes` are recorded in the order a parser would record them; `comments` are
/// (anchor, kind, position, text).
fn build(
  nodes : Array[(Int, Int)],
  comments : Array[(Int, @trivia.TriviaKind, @trivia.TriviaPos, String)],
) -> @trivia.Context {
  let ctx = @trivia.Context::new()
  for c in comments {
    // report_item anchors at prev_token_end, so set it directly.
    ctx.report_token(c.0)
    if c.2 is LineStart {
      // A line-start comment follows a newline.
      ctx.report_newline()
    }
    ctx.report_item(c.1, span(c.0, c.0 + c.3.length()), c.3)
  }
  for nd in nodes {
    ctx.record_pos(span(nd.0, nd.1))
  }
  ctx
}

///|
/// Associate with every recorded span marked as looked-up.
fn assoc_all(ctx : @trivia.Context) -> (@trivia.Table, Array[@trivia.Entry]) {
  @trivia.associate(ctx, only => {
    for l in ctx.locations() {
      only.mark(l)
    }
  })
}

///|
fn texts(entries : Array[@trivia.Entry]) -> Array[String] {
  let out = []
  for e in entries {
    match e.trivia {
      Item(content~, ..) => out.push(content)
      BlankLine => out.push("<blank>")
    }
  }
  out
}

///|
test "a comment before a node attaches as its `before`" {
  // // hi
  // fn f() {}         <- node at [10, 20)
  let ctx = build([(10, 20)], [(0, LineComment, LineStart, "// hi")])
  let (tbl, leftover) = assoc_all(ctx)
  let a = tbl.get(Some(span(10, 20)))
  debug_inspect(
    texts(a.before),
    content=(
      #|["// hi"]
    ),
  )
  debug_inspect(
    texts(a.after),
    content=(
      #|[]
    ),
  )
  inspect(
    leftover.length(),
    content=(
      #|0
    ),
  )
}

///|
test "an inline comment trailing a node attaches as its `after`" {
  // fn f() {} // why      node [0, 9), comment anchored at 9
  let ctx = build([(0, 9)], [(9, LineComment, Inline, "// why")])
  let (tbl, _) = assoc_all(ctx)
  let a = tbl.get(Some(span(0, 9)))
  debug_inspect(
    texts(a.after),
    content=(
      #|["// why"]
    ),
  )
  debug_inspect(
    texts(a.before),
    content=(
      #|[]
    ),
  )
}

///|
test "a line-start comment after a node leads the NEXT node, not the previous" {
  // The distinction the reference draws: an inline comment ends the previous
  // node's line, a line-start one begins the next construct.
  let ctx = build([(0, 9), (20, 30)], [
    (9, LineComment, LineStart, "// heads the next"),
  ])
  let (tbl, _) = assoc_all(ctx)
  debug_inspect(
    texts(tbl.get(Some(span(0, 9))).after),
    content=(
      #|[]
    ),
  )
  debug_inspect(
    texts(tbl.get(Some(span(20, 30))).before),
    content=(
      #|["// heads the next"]
    ),
  )
}

///|
test "a blank line separates rather than trails" {
  let ctx = build([(0, 9), (20, 30)], [(9, LineComment, LineStart, "")])
  // Replace with a genuine blank-line entry.
  let ctx2 = @trivia.Context::new()
  ctx2.report_token(9)
  ctx2.report_newline() // ends the line with the token
  ctx2.report_newline() // blank
  ctx2.record_pos(span(0, 9))
  ctx2.record_pos(span(20, 30))
  ignore(ctx)
  let (tbl, _) = assoc_all(ctx2)
  // Left in place: it belongs to the gap, not to the node before it.
  debug_inspect(
    texts(tbl.get(Some(span(0, 9))).after),
    content=(
      #|[]
    ),
  )
  debug_inspect(
    texts(tbl.get(Some(span(20, 30))).before),
    content=(
      #|["<blank>"]
    ),
  )
}

///|
test "a comment after the last child trails that CHILD, not the parent" {
  // fn f() { stmt /* why */ }   outer [0, 22), child [9, 10), comment at 10.
  //
  // The last child's window reaches to the parent's end, which is what lets it
  // claim the comment trailing the last statement -- reaching across the
  // statement separator to do so. The parent gets nothing.
  let ctx = build([(0, 22), (9, 10)], [(10, BlockComment, Inline, "/* why */")])
  let (tbl, _) = assoc_all(ctx)
  debug_inspect(
    texts(tbl.get(Some(span(9, 10))).after),
    content=(
      #|["/* why */"]
    ),
  )
  debug_inspect(
    texts(tbl.get(Some(span(0, 22))).within),
    content=(
      #|[]
    ),
  )
}

///|
test "a comment past every child but inside the parent is `within`" {
  // Same shape, but the comment is anchored beyond the last child's window --
  // past the parent's end it would be `after`, before it it is `within`.
  let ctx = build([(0, 40)], [(10, BlockComment, Inline, "/* mid */")])
  let (tbl, _) = assoc_all(ctx)
  debug_inspect(
    texts(tbl.get(Some(span(0, 40))).within),
    content=(
      #|["/* mid */"]
    ),
  )
}

///|
test "a span recorded twice yields its trivia only once" {
  // A Get instruction and the identifier it wraps span the same range; the
  // printer looks both up, and only the first may carry the comment.
  let ctx = build([(10, 20)], [(0, LineComment, LineStart, "// once")])
  let (tbl, _) = assoc_all(ctx)
  debug_inspect(
    texts(tbl.get(Some(span(10, 20))).before),
    content=(
      #|["// once"]
    ),
  )
  debug_inspect(
    texts(tbl.get(Some(span(10, 20))).before),
    content=(
      #|[]
    ),
  )
}

///|
test "trailing comments past every node are left over" {
  // The module-tail comment: no node owns it, so the caller prints it as tail
  // trivia rather than it being silently dropped.
  let ctx = @trivia.Context::new()
  ctx.record_pos(span(0, 9))
  ctx.report_token(9)
  ctx.report_newline()
  ctx.report_item(LineComment, span(10, 20), "// tail")
  let (_, leftover) = assoc_all(ctx)
  debug_inspect(
    texts(leftover),
    content=(
      #|["// tail"]
    ),
  )
}

///|
test "with no nodes at all, every comment is left over" {
  // An empty module: nothing to attach to, so the whole file is tail trivia.
  let ctx = @trivia.Context::new()
  ctx.report_item(LineComment, span(0, 8), "// alone")
  let (_, leftover) = assoc_all(ctx)
  debug_inspect(
    texts(leftover),
    content=(
      #|["// alone"]
    ),
  )
}

///|
test "a span the printer never looks up does not swallow comments" {
  // Association runs over spans that are BOTH parse nodes and looked up. Here
  // the inner node is not looked up, so its comment bubbles to the outer node
  // that does print, instead of being attached somewhere never emitted.
  let ctx = build([(10, 30), (15, 20)], [(0, LineComment, LineStart, "// lead")])
  let (tbl, _) = @trivia.associate(ctx, only => only.mark(span(10, 30)))
  debug_inspect(
    texts(tbl.get(Some(span(10, 30))).before),
    content=(
      #|["// lead"]
    ),
  )
}

///|
test "drop_trailing_blank_lines trims only the tail" {
  let ctx = @trivia.Context::new()
  ctx.report_token(0)
  ctx.report_newline()
  ctx.report_newline() // blank
  ctx.report_item(LineComment, span(5, 10), "// c")
  ctx.report_newline()
  ctx.report_newline() // trailing blank
  let all = ctx.entries().to_owned()
  debug_inspect(
    texts(all),
    content=(
      #|["<blank>", "// c", "<blank>", "<blank>"]
    ),
  )
  debug_inspect(
    texts(@trivia.drop_trailing_blank_lines(all)),
    content=(
      #|["<blank>", "// c"]
    ),
  )
}
