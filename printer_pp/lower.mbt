// Lowering the document tree to a `@pp.Doc`.
//
// The two models differ in what they make explicit, and every awkwardness below
// is one of those differences:
//
//   * INDENTATION. `@pp` has no indent operator. Indentation comes from `horz`,
//     which re-indents its right operand to the column the left one ended at,
//     and from `vert`, which returns to the ambient indent. So a group is
//     joined to its left sibling with `horz` -- that is what rebases it to the
//     column it opens at, the engine's `eff_col` -- while everything else is
//     joined with `concat`, which leaves the ambient indent alone. A `TNest`
//     then has to be paid for in literal spaces after each break inside it.
//
//   * MODE. The engine carries a live frame mode; here the mode is a lowering
//     PARAMETER, chosen once per group by kind. `GHv` is the exception: its
//     mode is a fit decision, so it lowers to an `if_flat` of both modes.
//
//   * FITTING. `if_flat` compares a precomputed flat width against the space
//     left on the line. The engine instead scans the buffered stream, past the
//     end of the group, to the next break that would end the line. That is the
//     difference the corpus divergence is mostly made of; see README.

///|
/// A node of a group's body, with its `Nest`s already resolved into a relative
/// indent and its `IfBroken`s already resolved by the frame mode.
///
/// Flattening those two away is what lets a body be treated as a plain sequence
/// of segments separated by breaks, which is the shape `@pp`'s combinators want.
priv enum Atom {
  ATxt(String)
  /// Strength, and the indent breaking here returns to -- relative to the
  /// enclosing group's base column.
  ABrk(@printer.BreakStrength, Int)
  AGrp(@printer.GKind, Array[Node])
}

///|
/// Flatten a group body into atoms, resolving nesting and if-broken content.
///
/// `IfBroken` survives exactly when the frame mode is a breaking one, which is
/// the engine's rule (`TIfBroken` is skipped unless `cur().fmode` is `Brkm`).
/// So a fill box drops its trailing comma, and so does an h-box.
fn atoms(
  items : Array[Node],
  ind : Int,
  mode : @printer.Mode,
  out : Array[Atom],
) -> Unit {
  for n in items {
    match n {
      Nop => ()
      Text(s) => out.push(ATxt(s))
      Brk(s) => out.push(ABrk(s, ind))
      Nest(n, body) => atoms(body, ind + n, mode, out)
      IfBroken(body) => if mode is Brkm { atoms(body, ind, mode, out) }
      Group(k, body) => out.push(AGrp(k, body))
    }
  }
}

///|
fn spaces(n : Int) -> String {
  " ".repeat(n)
}

///|
/// Text that may contain newlines, as a block comment's content does.
///
/// `@pp.txt` rejects them outright; `txt_lines` splits and stacks, which
/// re-indents the continuation lines. See README, "Multi-line literals".
fn txt_of(s : String) -> @pp.Doc {
  if s.contains("\n") {
    @pp.txt_lines(s)
  } else {
    @pp.txt(s)
  }
}

///|
/// A line ending, returning to the ambient indent plus `ind`.
///
/// `vert` newlines to the AMBIENT indent -- the group's base column -- so the
/// relative indent is written out as spaces on the new line.
fn line_break(ind : Int, blank : Bool) -> @pp.Doc {
  if blank {
    @pp.vert([@pp.empty, @pp.empty, @pp.txt(spaces(ind))])
  } else {
    @pp.vert([@pp.empty, @pp.txt(spaces(ind))])
  }
}

///|
/// Lay a group body out in the given mode.
fn lay(items : Array[Node], mode : @printer.Mode) -> @pp.Doc {
  let ats : Array[Atom] = []
  atoms(items, 0, mode, ats)
  // Split at the body's own breaks: the segments between them are what a fill
  // box measures one at a time, and what every other mode simply joins.
  let segs : Array[Array[Atom]] = [[]]
  let brks : Array[(@printer.BreakStrength, Int)] = []
  for a in ats {
    match a {
      ABrk(s, ind) => {
        brks.push((s, ind))
        segs.push([])
      }
      _ => segs[segs.length() - 1].push(a)
    }
  }
  let mut acc = seg_doc(segs[0])
  for i, brk in brks {
    let (str, ind) = brk
    let next = segs[i + 1]
    acc = match (str, mode) {
      // Hard breaks end the line in every mode, h-boxes included.
      (Newline, _) => @pp.concat([acc, line_break(ind, false), seg_doc(next)])
      (BlankLine, _) => @pp.concat([acc, line_break(ind, true), seg_doc(next)])
      (Space, Flat) => @pp.concat([acc, @pp.txt(" "), seg_doc(next)])
      (Cut, Flat) => @pp.concat([acc, seg_doc(next)])
      (_, Brkm) => @pp.concat([acc, line_break(ind, false), seg_doc(next)])
      // Fill: this separator alone decides, on whether the NEXT segment fits.
      // The engine decides the same question by scanning to the next break.
      (_, Fill) =>
        match flat_doc(next) {
          Some(flat) => {
            let sep = if str is Space { " " } else { "" }
            @pp.concat([
              acc,
              @pp.if_flat(
                @pp.horz([@pp.txt(sep), flat]),
                @pp.vert([
                  @pp.empty,
                  @pp.horz([@pp.txt(spaces(ind)), seg_doc(next)]),
                ]),
              ),
            ])
          }
          // Unflattenable: nothing to weigh, so the separator breaks.
          None => @pp.concat([acc, line_break(ind, false), seg_doc(next)])
        }
    }
  }
  acc
}

///|
/// A break-free run of atoms.
///
/// Nested groups are joined with `horz` so each rebases to the column it opens
/// at; text is joined with `concat`, which leaves the ambient indent -- the
/// indent this body's own breaks return to -- alone.
fn seg_doc(seg : Array[Atom]) -> @pp.Doc {
  let mut d = @pp.empty
  for a in seg {
    d = match a {
      ATxt(s) => @pp.concat([d, txt_of(s)])
      AGrp(k, body) => @pp.horz([d, group_doc(k, body)])
      ABrk(_, _) => d
    }
  }
  d
}

///|
/// The all-flat rendering of a body, or None if it has none.
///
/// A hard break makes a body unflattenable, and so does a multi-line literal --
/// the engine would keep both on one logical line, but neither can be given a
/// flat width here.
fn flat_doc(ats : Array[Atom]) -> @pp.Doc? {
  let mut d = @pp.empty
  for a in ats {
    match a {
      ATxt(s) => {
        guard !s.contains("\n") else { return None }
        d = @pp.concat([d, @pp.txt(s)])
      }
      ABrk(str, _) =>
        match str {
          Space => d = @pp.concat([d, @pp.txt(" ")])
          Cut => ()
          Newline | BlankLine => return None
        }
      AGrp(_, body) =>
        match group_flat(body) {
          Some(g) => d = @pp.concat([d, g])
          None => return None
        }
    }
  }
  Some(d)
}

///|
/// A group's body, flat. The mode is `Flat`, so its if-broken content is
/// dropped -- the same rule the engine applies to a group it decided to keep on
/// one line.
fn group_flat(body : Array[Node]) -> @pp.Doc? {
  let ats : Array[Atom] = []
  atoms(body, 0, Flat, ats)
  flat_doc(ats)
}

///|
/// A group, laid out by its kind.
fn group_doc(kind : @printer.GKind, body : Array[Node]) -> @pp.Doc {
  match kind {
    GH => lay(body, Flat)
    GV => lay(body, Brkm)
    GBox | GHov => lay(body, Fill)
    // The only kind whose mode is a decision rather than a constant.
    GHv =>
      match group_flat(body) {
        Some(flat) => @pp.if_flat(flat, lay(body, Brkm))
        None => lay(body, Brkm)
      }
  }
}

///|
/// Lay a token stream out as a `@pp.Doc`.
///
/// The outermost frame is a breaking one at indent 0, as in the engine, so a
/// document that opens no box is stacked rather than run together.
pub fn to_doc(tokens : Array[@printer.Token]) -> @pp.Doc {
  let root = tree(tokens)
  prune(root)
  lay(root, Brkm)
}

///|
/// Lay a token stream out as text.
///
/// Blank lines are cleaned of the indentation `@pp` pads every line with: the
/// engine writes a bare newline pair, and a line of nothing but spaces is
/// something it can never produce.
pub fn render_tokens(
  tokens : Array[@printer.Token],
  width? : Int = 78,
) -> String {
  let lines = to_doc(tokens).display(width~)
  for i, line in lines {
    if line != "" && line.iter().all(c => c == ' ') {
      lines[i] = ""
    }
  }
  lines.join("\n")
}

///|
/// Lay `f` out and return the text.
///
/// A drop-in for `@printer.run_string`: same callback, same width, different
/// engine.
pub fn run_string(f : (@printer.Printer) -> Unit, width? : Int = 78) -> String {
  render_tokens(@printer.run_tokens(f, width~), width~)
}
