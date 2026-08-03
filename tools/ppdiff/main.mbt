///|
/// Measure `printer_pp` against `printer` over a tree of `.wax` files.
///
/// Both engines lay out the SAME document -- `@output.render_with` swaps only
/// the layout step -- so every difference reported here is a layout difference
/// and nothing else. That is what makes the number meaningful: it is not a
/// second formatter being compared to the first, it is one formatter's output
/// under two engines.
///
///     ppdiff [dir] [--show N] [--dump]
///
/// `dir` defaults to `test/corpus`. `--show N` prints the first differing line
/// of the first N mismatching files. `--dump` prints the token stream and both
/// renderings of every file, which is how a divergence gets traced back to the
/// tokens that caused it -- point it at a directory holding one file.
fn main {
  let args = @env.args()
  let mut dir = "test/corpus"
  let mut show = 0
  let mut dump = false
  let mut i = 1
  let mut positional = 0
  while i < args.length() {
    let a = args[i]
    if a == "--dump" {
      dump = true
      i += 1
    } else if a == "--show" && i + 1 < args.length() {
      show = @string.parse_int(args[i + 1]) catch { _ => 0 }
      i += 2
    } else {
      if positional == 0 {
        dir = a
      }
      positional += 1
      i += 1
    }
  }
  let files = []
  collect(dir, files)
  files.sort()
  let mut parsed = 0
  let mut same = 0
  let diffs = []
  for path in files {
    let src = @fs.read_file_to_string(path) catch { _ => continue }
    let r = @grammar.parse_string(src, fname=path)
    // Files the parser rejects have no module to lay out. They are most of what
    // the error oracles exist for, and nothing at all to do with layout.
    guard r.module_ is Some(m) else { continue }
    parsed += 1
    let a = @output.render(m, r.trivia)
    let b = @output.render_with(m, r.trivia, lay=f => {
      @printer_pp.run_string(f, width=@output.width)
    })
    if dump {
      let toks : Array[@printer.Token] = []
      ignore(
        @output.render_with(m, r.trivia, lay=f => {
          toks.append(@printer.run_tokens(f, width=@output.width))
          ""
        }),
      )
      println("=== tokens")
      for t in toks {
        println("  " + @debug.to_string(t))
      }
      println("=== printer")
      println(a)
      println("=== printer_pp")
      println(b)
    }
    if a == b {
      same += 1
    } else {
      diffs.push((path, a, b))
    }
  }
  println("files scanned:   \{files.length()}")
  println("modules parsed:  \{parsed}")
  println("identical:       \{same}")
  println("differing:       \{diffs.length()}")
  if parsed > 0 {
    println("agreement:       \{same * 100 / parsed}%")
  }
  let mut overflow = 0
  let mut indent = 0
  let mut other = 0
  for d in diffs {
    let (_, a, b) = d
    match classify(a, b) {
      Overflow => overflow += 1
      Indent => indent += 1
      Other => other += 1
    }
  }
  if diffs.length() > 0 {
    println("")
    println("  overflow (fit decision ignores trailing context): \{overflow}")
    println("  indent   (no max_indent cap):                     \{indent}")
    println("  other:                                            \{other}")
  }
  // The two engines agree on every module in the committed corpus, so a
  // divergence is news whichever direction it came from -- a change to the
  // formatter, to the lowering, or to the library.
  let n = if show < diffs.length() { show } else { diffs.length() }
  for k in 0..<n {
    let (path, a, b) = diffs[k]
    println("")
    println("--- \{path}")
    report_first_diff(a, b)
  }
  if diffs.length() > 0 {
    @sys.exit(1)
  }
}

///|
/// What kind of divergence a mismatching pair shows.
///
/// Both kinds are known consequences of the model, not bugs to be chased: see
/// `printer_pp/README.md`. Anything landing in `Other` would be news.
enum Kind {
  /// `printer_pp` left a line over the width. `if_flat` weighs a group against
  /// the space left on the line; the engine's scan runs on past the group's end
  /// to the next break that would end the line, so it sees the trailing `)`s
  /// that push the line over.
  Overflow
  /// The two agree but for leading whitespace: the engine caps indentation at
  /// `width - 10` and a `@pp.Doc` has no column to cap at.
  Indent
  Other
}

///|
fn classify(a : String, b : String) -> Kind {
  let la = a.split("\n").collect()
  let lb = b.split("\n").collect()
  let n = if la.length() < lb.length() { la.length() } else { lb.length() }
  for i in 0..<n {
    if la[i] != lb[i] {
      if lb[i].length() > @output.width && la[i].length() <= @output.width {
        return Overflow
      }
      if strip(la[i]) == strip(lb[i]) {
        return Indent
      }
      return Other
    }
  }
  Other
}

///|
fn strip(s : StringView) -> String {
  let mut i = 0
  while i < s.length() && s[i] == ' ' {
    i += 1
  }
  s[i:].to_owned()
}

///|
/// Print the first line at which two renderings part company.
fn report_first_diff(a : String, b : String) -> Unit {
  let la = a.split("\n").collect()
  let lb = b.split("\n").collect()
  let n = if la.length() < lb.length() { la.length() } else { lb.length() }
  for i in 0..<n {
    if la[i] != lb[i] {
      println("  line \{i + 1}")
      println("    printer:    \{la[i]}")
      println("    printer_pp: \{lb[i]}")
      return
    }
  }
  println("  identical for \{n} lines, then \{la.length()} vs \{lb.length()}")
}

///|
/// Every `.wax` file under `dir`, depth first.
fn collect(dir : String, out : Array[String]) -> Unit {
  let entries = @fs.read_dir(dir) catch { _ => return }
  entries.sort()
  for name in entries {
    let path = dir + "/" + name
    let isdir = @fs.is_dir(path) catch { _ => false }
    if isdir {
      collect(path, out)
    } else if name.has_suffix(".wax") {
      out.push(path)
    }
  }
}
