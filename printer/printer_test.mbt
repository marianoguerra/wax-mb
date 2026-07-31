// Layout-engine behaviour.
//
// Everything the formatter produces goes through here, so a bug in a break
// decision shows up as thousands of reprint mismatches with no obvious cause.
// These pin the decisions individually.

///|
fn lay(width : Int, f : (@printer.Printer) -> Unit) -> String {
  @printer.run_string(f, width~)
}

///|
test "text and flat separators" {
  inspect(lay(80, p => p.string("hello")), content="hello")
  // Inside a box that fits, a space is a space and a cut is nothing.
  inspect(
    lay(80, p => {
      p.box(() => {
        p.string("a")
        p.space()
        p.string("b")
      })
    }),
    content="a b",
  )
  inspect(
    lay(80, p => {
      p.box(() => {
        p.string("a")
        p.cut()
        p.string("b")
      })
    }),
    content="ab",
  )
}

///|
test "outside every box, a soft break always breaks" {
  // The initial frame is a breaking one, so top-level content is laid out
  // vertically. Real printing always opens a box; this pins the default.
  inspect(
    lay(80, p => {
      p.string("a")
      p.space()
      p.string("b")
    }),
    content=(
      #|a
      #|b
    ),
  )
}

///|
test "a leading break emits nothing" {
  // Nothing has been printed yet, so there is no line to end.
  inspect(
    lay(80, p => {
      p.newline()
      p.string("x")
    }),
    content="x",
  )
  inspect(
    lay(80, p => {
      p.space()
      p.string("x")
    }),
    content="x",
  )
}

///|
test "adjacent breaks coalesce into the stronger" {
  // A space then a newline is one newline, not a trailing space then a break.
  inspect(
    lay(80, p => {
      p.string("a")
      p.space()
      p.newline()
      p.string("b")
    }),
    content=(
      #|a
      #|b
    ),
  )
  // A newline then a blank line is a blank line.
  inspect(
    lay(80, p => {
      p.string("a")
      p.newline()
      p.blank_line()
      p.string("b")
    }),
    content=(
      #|a
      #|
      #|b
    ),
  )
}

///|
test "a trailing break leaves no trailing whitespace" {
  inspect(
    lay(80, p => {
      p.string("x")
      p.newline()
    }),
    content="x",
  )
  inspect(
    lay(80, p => {
      p.string("x")
      p.space()
    }),
    content="x",
  )
}

///|
test "an hvbox is all-or-nothing" {
  // Fits: every break stays flat.
  let build = fn(p : @printer.Printer) {
    p.hvbox(indent=2, () => {
      p.string("f(")
      p.string("aaaaaaaa")
      p.space()
      p.string("bbbbbbbb")
      p.string(")")
    })
  }
  inspect(lay(80, build), content="f(aaaaaaaa bbbbbbbb)")
  // Does not fit: EVERY break wraps, not just the ones that must.
  inspect(
    lay(16, build),
    content=(
      #|f(aaaaaaaa
      #|  bbbbbbbb)
    ),
  )
}

///|
test "a box fills, wrapping only the breaks that must" {
  let build = fn(p : @printer.Printer) {
    p.box(indent=0, () => {
      p.string("aaaaaa")
      p.space()
      p.string("bbbbbb")
      p.space()
      p.string("cccccc")
    })
  }
  inspect(lay(80, build), content="aaaaaa bbbbbb cccccc")
  // Width 16 fits two per line: a fill wraps independently, where an hvbox
  // would have broken all three.
  inspect(
    lay(16, build),
    content=(
      #|aaaaaa bbbbbb
      #|cccccc
    ),
  )
}

///|
test "a vbox always breaks, an hbox never does" {
  let body = fn(p : @printer.Printer) {
    p.string("a")
    p.space()
    p.string("b")
  }
  inspect(
    lay(80, p => p.vbox(() => body(p))),
    content=(
      #|a
      #|b
    ),
  )
  // An hbox keeps soft breaks flat even when far past the width.
  inspect(lay(11, p => p.hbox(() => body(p))), content="a b")
}

///|
test "a hard break still breaks inside an hbox" {
  inspect(
    lay(80, p => {
      p.hbox(() => {
        p.string("a")
        p.newline()
        p.string("b")
      })
    }),
    content=(
      #|a
      #|b
    ),
  )
}

///|
test "indent applies to breaks inside it" {
  inspect(
    lay(40, p => {
      p.vbox(indent=4, () => {
        p.string("aa")
        p.space()
        p.string("bb")
      })
    }),
    content=(
      #|aa
      #|    bb
    ),
  )
}

///|
test "indentation is capped, so deep nesting does not march off the margin" {
  // max_indent is width - 10. At width 12 nothing may indent past column 2,
  // however deeply nested it is -- the analogue of Format's max_indent.
  inspect(
    lay(12, p => {
      p.vbox(indent=8, () => {
        p.string("aa")
        p.space()
        p.string("bb")
      })
    }),
    content=(
      #|aa
      #|  bb
    ),
  )
}

///|
test "a group indents from the column it opens at, not the outer nesting" {
  // Format semantics: a group starting mid-line rebases to that column. The
  // two differ exactly when a construct opens after other text on the line.
  inspect(
    lay(40, p => {
      p.string("xx")
      p.vbox(indent=1, () => {
        p.string("(")
        p.space()
        p.string("y")
      })
    }),
    content=(
      #|xx(
      #|   y
    ),
  )
}

///|
test "if_broken content appears only when the group wraps" {
  // The trailing comma of a list that wraps: present when broken, absent when
  // flat, and never counted toward the fit decision either way.
  let build = fn(p : @printer.Printer) {
    p.hvbox(indent=2, () => {
      p.string("[")
      p.string("aaaaaaa")
      p.string(",")
      p.space()
      p.string("bbbbbbb")
      p.if_broken(() => p.string(","))
      p.string("]")
    })
  }
  inspect(lay(80, build), content="[aaaaaaa, bbbbbbb]")
  inspect(
    lay(15, build),
    content=(
      #|[aaaaaaa,
      #|  bbbbbbb,]
    ),
  )
}

///|
test "a deferred comment is emitted at the end of its line" {
  inspect(
    lay(80, p => {
      p.string("foo")
      p.defer_eol(() => p.string(" // why"))
      p.string("bar")
    }),
    content=(
      #|foo // why
      #|bar
    ),
  )
}

///|
test "with_held_eol lets a separator precede the comment" {
  // Without holding, the comma would be pushed onto the next line, moving the
  // comment off the element it belongs to.
  inspect(
    lay(80, p => {
      p.string("a")
      p.defer_eol(() => p.string(" // one"))
      p.with_held_eol(() => p.string(","))
      p.string("b")
    }),
    content=(
      #|a, // one
      #|b
    ),
  )
}

///|
test "has_pending_eol reports a deferred comment" {
  let p = @printer.Printer::new()
  assert_false(p.has_pending_eol())
  p.string("x")
  p.defer_eol(() => p.string(" // c"))
  assert_true(p.has_pending_eol())
  p.string("y")
  assert_false(p.has_pending_eol())
}

///|
test "width is DISPLAY width, so wide characters wrap sooner" {
  // Six CJK characters occupy twelve columns, not six. At width 14 the pair
  // does not fit, though by character count it easily would.
  let build = fn(p : @printer.Printer) {
    p.hvbox(() => {
      p.string("世界世界世界")
      p.space()
      p.string("!!")
    })
  }
  inspect(lay(80, build), content="世界世界世界 !!")
  inspect(
    lay(14, build),
    content=(
      #|世界世界世界
      #|!!
    ),
  )
}

///|
test "run_discard produces nothing but still runs the callback" {
  // The dry pass: the formatter runs to record which spans it looks up,
  // without paying to lay out a document that is thrown away.
  let mut ran = false
  @printer.run_discard(p => {
    ran = true
    p.string("ignored")
  })
  assert_true(ran)
}
