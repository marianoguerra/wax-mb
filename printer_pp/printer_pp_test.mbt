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
test "width is DISPLAY width, so wide characters wrap sooner" {
  // Six CJK characters occupy twelve columns, not six. `@pp` would count UTF-16
  // units; `txt_as` states the width the BUILDER measured instead, so both
  // engines break in the same place.
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
  assert_eq(lay(14, build), ref_lay(14, build))
}

///|
test "a zero-width span does not move the margin" {
  // What `string_as` is for: a colour escape occupies no columns, so colouring
  // must never change where a line breaks. Measured by its encoded length it
  // would, and at width 12 this is exactly the difference between fitting and
  // not.
  let build = fn(p : @printer.Printer) {
    p.hvbox(() => {
      p.string_as(0, "\u{1b}[31m")
      p.string("aaaa")
      p.string_as(0, "\u{1b}[0m")
      p.space()
      p.string("bbbb")
    })
  }
  inspect(lay(12, build), content="\u{1b}[31maaaa\u{1b}[0m bbbb")
  assert_eq(lay(12, build), ref_lay(12, build))
}

///|
test "a fit decision counts what follows the group" {
  // The reference engine's scan runs PAST the end of the group, to the next
  // break that would end the line, so the trailing `))` counts against the
  // inner hvbox. `if_flat` weighs its flat branch alone; `reserve` is how the
  // trailing width is handed to it.
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
  inspect(
    lay(12, build),
    content=(
      #|f(aaaa
      #|  bbbb))
    ),
  )
  assert_eq(lay(12, build), ref_lay(12, build))
}

///|
test "a flat cut still costs a column when a group is based on it" {
  // `eff_col` adds one for ANY pending flat separator, while only `flush` looks
  // at the strength -- so a `cut` that prints nothing still moves the base of a
  // group opening right after it, both for the fit test and for the indent.
  //
  // Here that one column is the whole decision: the body plus its `)` is 18
  // wide and the line has 18 left, so without the cut's phantom column the box
  // would stay flat. `@pp.nest(1, ...)` is what reproduces it.
  let build = fn(p : @printer.Printer) {
    p.hvbox(() => {
      p.string("f(")
      p.cut()
      p.hvbox(indent=2, () => {
        p.string("aaaaaaaa")
        p.space()
        p.string("bbbbbbbb")
      })
      p.string(")")
    })
  }
  inspect(
    lay(20, build),
    content=(
      #|f(aaaaaaaa
      #|     bbbbbbbb)
    ),
  )
  assert_eq(lay(20, build), ref_lay(20, build))
  // One column wider and it fits, in both engines.
  inspect(lay(21, build), content="f(aaaaaaaa bbbbbbbb)")
  assert_eq(lay(21, build), ref_lay(21, build))
}

///|
test "a run of breaks that opens a group lands at the last break's indent" {
  // The engine collapses a run of breaks by accident: a break only sets
  // `pend_line`, so nothing is written until the next TEXT flushes it. What
  // survives is the LAST break's indent -- but the v-box between the two breaks
  // takes its base from `eff_col`, which reports the FIRST break's, so the
  // second indents four from zero rather than four from one.
  //
  // Keeping the last break alone would give five. The corpus never builds this
  // shape, which is the reason to pin it here.
  let build = fn(p : @printer.Printer) {
    p.string("a")
    p.newline()
    p.vbox(indent=4, () => {
      p.newline()
      p.string("x")
    })
  }
  inspect(
    lay(40, build),
    content=(
      #|a
      #|    x
    ),
  )
  assert_eq(lay(40, build), ref_lay(40, build))
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
