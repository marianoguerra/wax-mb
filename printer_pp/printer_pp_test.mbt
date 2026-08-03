// The same cases `printer/printer_test.mbt` pins, laid out by the alternative
// engine.
//
// Case for case, so the two files can be diffed. Where the expected output
// differs the test says so and says why, and README.md carries the general
// statement of that difference. Everything else agrees exactly.

///|
fn lay(width : Int, f : (@printer.Printer) -> Unit) -> String {
  @printer_pp.run_string(f, width~)
}

///|
/// The reference engine's answer, for the cases where the two disagree.
fn ref_lay(width : Int, f : (@printer.Printer) -> Unit) -> String {
  @printer.run_string(f, width~)
}

///|
test "text and flat separators" {
  inspect(lay(80, p => p.string("hello")), content="hello")
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
test "indentation is NOT capped -- the one deliberate omission" {
  // The reference engine caps every indent at width - 10, so deep nesting does
  // not march off the right margin. A `@pp.Doc` indents by writing spaces after
  // a break, and the column those land in is not known until the document is
  // rendered, so there is nothing to clamp at build time. See README.
  let build = fn(p : @printer.Printer) {
    p.vbox(indent=8, () => {
      p.string("aa")
      p.space()
      p.string("bb")
    })
  }
  inspect(
    lay(12, build),
    content=(
      #|aa
      #|        bb
    ),
  )
  inspect(
    ref_lay(12, build),
    content=(
      #|aa
      #|  bb
    ),
  )
}

///|
test "a group indents from the column it opens at, not the outer nesting" {
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
test "width is UTF-16 units, so wide characters wrap LATER" {
  // The reference engine measures display width: six CJK characters occupy
  // twelve columns, so at width 14 the pair does not fit. `@pp` measures the
  // string, and cannot be told otherwise, so it counts six. See README.
  let build = fn(p : @printer.Printer) {
    p.hvbox(() => {
      p.string("世界世界世界")
      p.space()
      p.string("!!")
    })
  }
  inspect(lay(80, build), content="世界世界世界 !!")
  inspect(lay(14, build), content="世界世界世界 !!")
  inspect(
    ref_lay(14, build),
    content=(
      #|世界世界世界
      #|!!
    ),
  )
}

///|
test "a fit decision ignores what follows the group" {
  // The reference engine's scan runs PAST the end of the group, to the next
  // break that would end the line, so the trailing `))` counts against the
  // hvbox. `if_flat` weighs the group alone, so here it just fits. See README.
  let build = fn(p : @printer.Printer) {
    p.hvbox(() => {
      p.string("f(")
      p.hvbox(() => {
        p.string("aaaa")
        p.space()
        p.string("bbbb")
      })
      p.string("))")
    })
  }
  inspect(lay(12, build), content="f(aaaa bbbb))")
  inspect(
    ref_lay(12, build),
    content=(
      #|f(aaaa
      #|  bbbb))
    ),
  )
}

///|
test "run_string is a drop-in for the reference's" {
  // Same callback type, same width argument: switching engines is a one-line
  // change at the call site, which is what `tools/ppdiff` relies on.
  let build = fn(p : @printer.Printer) {
    p.hvbox(indent=4, () => {
      p.string("fn f() {")
      p.space()
      p.string("nop;")
      p.space()
      p.string("}")
    })
  }
  inspect(lay(100, build), content="fn f() { nop; }")
  assert_eq(lay(100, build), ref_lay(100, build))
}
