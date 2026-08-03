// Lowering the document tree to a `@pp.Doc`.
//
// The two models differ in what they make explicit, and the shape of this file
// follows from that:
//
//   * INDENTATION. `@pp` indents through `horz`, which re-indents its right
//     operand to the column the left one ended at, and `vert`, which returns to
//     the ambient indent. So a group is joined to its left sibling with `horz2`
//     -- that is what rebases it to the column it opens at, the engine's
//     `eff_col` -- while everything else is joined with `concat2`, which leaves
//     the ambient indent alone. A `TNest` is then paid for in literal spaces
//     after each break inside it, because a nest has to interleave with the
//     body's own breaks and `@pp.nest` wraps a whole document.
//
//   * MODE. The engine carries a live frame mode; here the mode is a lowering
//     PARAMETER, chosen once per group by kind. `GHv` is the exception: its
//     mode is a fit decision, so it lowers to an `if_flat` of both modes.
//
//   * FITTING. `if_flat` weighs its flat branch against the space left on the
//     line. The engine instead scans the token stream, past the end of the
//     group, to the next break that would end the line -- so what follows the
//     group counts against it. `reserve` is how that trailing context is handed
//     to `@pp`; `suffix` and `after` below are what compute it.

///|
/// A node of a group's body, with its `Nest`s already resolved into a relative
/// indent and its `IfBroken`s already resolved by the frame mode.
///
/// Flattening those two away is what lets a body be treated as a plain sequence
/// of segments separated by breaks, which is the shape `@pp`'s combinators want.
priv struct Atom {
  kind : AtomKind
  /// Whether the engine's fit scan would SKIP this.
  ///
  /// If-broken content is the only thing that is rendered but never measured:
  /// the scan drops the whole `TIfBroken` subtree, so a trailing comma that
  /// appears only when the group breaks must not be what tips the group into
  /// breaking.
  hidden : Bool
}

///|
priv enum AtomKind {
  /// Display width, then the text. The width is the one the BUILDER measured,
  /// which is why it has to be carried: `@pp` would otherwise count UTF-16
  /// units, and a colour escape occupies none of the columns it is encoded in.
  ATxt(Int, String)
  /// Strength, and the indent breaking here returns to -- relative to the
  /// enclosing group's base column.
  ABrk(@printer.BreakStrength, Int)
  AGrp(@printer.GKind, Int, Array[Node])
}

///|
/// A reserve wide enough that nothing can fit beside it.
///
/// Stands for the engine's `Nofit`: a scan that reaches a hard break while
/// inside an h-box decides against flat outright rather than by arithmetic.
/// Kept finite so reserves can be added without overflowing.
const UNFIT : Int = 1 << 20

///|
fn cap(n : Int) -> Int {
  if n > UNFIT {
    UNFIT
  } else {
    n
  }
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
  hidden? : Bool = false,
) -> Unit {
  for n in items {
    match n {
      Nop => ()
      Text(w, s) => out.push({ kind: ATxt(w, s), hidden })
      Brk(s) => out.push({ kind: ABrk(s, ind), hidden })
      Nest(n, body) => atoms(body, ind + n, mode, out, hidden~)
      IfBroken(body) =>
        if mode is Brkm {
          atoms(body, ind, mode, out, hidden=true)
        }
      Group(k, id, body) => out.push({ kind: AGrp(k, id, body), hidden })
    }
  }
}

///|
/// What has already been built, so a group reached twice is built once.
///
/// A `GHv` has to be materialised both ways -- `if_flat` holds both branches --
/// and each way rebuilds everything inside it. Without sharing, a document
/// nested `d` groups deep costs `2^d`. The key is the group's identity, the
/// mode it is being laid out in, and the reserve it was given, which together
/// determine the document completely.
priv struct Memo {
  flat : Map[Int, @pp.Doc?]
  docs : Map[(Int, Int, Int), @pp.Doc]
}

///|
fn mode_code(mode : @printer.Mode) -> Int {
  match mode {
    Flat => 0
    Brkm => 1
    Fill => 2
  }
}

///|
fn spaces(n : Int) -> String {
  " ".repeat(n)
}

///|
/// Text at the width the builder measured it at.
///
/// Text with a newline in it -- a block comment's content -- goes through
/// verbatim, which is what the engine does with it. `txt_lines` would stack the
/// lines with `vert` and re-indent the continuations.
fn txt_of(w : Int, s : String) -> @pp.Doc {
  if s.contains("\n") {
    @pp.txt_raw(s)
  } else {
    @pp.txt_as(s, w)
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
/// Lay a group body out in the given mode, keeping `reserve` columns free for
/// whatever follows the body on its last line.
fn lay(
  items : Array[Node],
  mode : @printer.Mode,
  reserve : Int,
  memo : Memo,
) -> @pp.Doc {
  let ats : Array[Atom] = []
  atoms(items, 0, mode, ats)
  // Split at the body's own breaks: the segments between them are what a fill
  // box measures one at a time, and what every other mode simply joins.
  let segs : Array[Array[Atom]] = [[]]
  let brks : Array[(@printer.BreakStrength, Int)] = []
  for a in ats {
    match a.kind {
      ABrk(s, ind) => {
        brks.push((s, ind))
        segs.push([])
      }
      _ => segs[segs.length() - 1].push(a)
    }
  }
  let n = segs.length()
  // How wide the rest of each segment is, flat: `suffix[si][j]` covers atoms
  // `j` onward. This is the near half of what the engine's scan measures.
  let suffix = []
  for seg in segs {
    let s = Array::make(seg.length() + 1, 0)
    for j = seg.length() - 1; j >= 0; j = j - 1 {
      s[j] = match atom_width(seg[j], memo) {
        Some(w) => cap(w + s[j + 1])
        None => UNFIT
      }
    }
    suffix.push(s)
  }
  // What the scan would still have to measure once it leaves each segment. In
  // a breaking mode it stops at the very next break, so the answer is nothing;
  // only the last segment inherits the reserve this body was given. An h-box
  // has no breaking break to stop at, so its scan runs on through the rest of
  // the body -- and a hard break inside it is an outright `Nofit`.
  let after = Array::make(n, reserve)
  for si = n - 2; si >= 0; si = si - 1 {
    after[si] = if mode is Flat {
      let (str, _) = brks[si]
      match str {
        Newline | BlankLine => UNFIT
        Space | Cut =>
          cap(
            (if str is Space { 1 } else { 0 }) +
            suffix[si + 1][0] +
            after[si + 1],
          )
      }
    } else {
      0
    }
  }

  // A break-free run of atoms. Nested groups are joined with `horz2` so each
  // rebases to the column it opens at; text is joined with `concat2`, which
  // leaves the ambient indent -- the indent this body's own breaks return to --
  // alone.
  fn seg_doc(si : Int) -> @pp.Doc {
    let seg = segs[si]
    // A `Cut` kept flat writes nothing, but the engine still counts it as a
    // column when it bases the next group on `eff_col`: that adds one for ANY
    // pending flat separator, and only `flush` looks at the strength. So a
    // group opening straight after one is based -- and therefore indents, and
    // is measured -- one column right of where it prints. `nest` reproduces
    // that: it moves the lines the group breaks onto without moving the line it
    // starts on.
    let bump = if si > 0 && mode is Flat && brks[si - 1].0 is Cut {
      1
    } else {
      0
    }
    let mut d = @pp.empty
    for j, a in seg {
      let extra = if j == 0 { bump } else { 0 }
      d = match a.kind {
        ATxt(w, s) => @pp.concat2(d, txt_of(w, s))
        AGrp(k, id, body) => {
          // The bump shifts THIS group's base and nothing else. It must not
          // reach the reserves of the groups inside it: the engine bases each
          // of those on the real column it prints at, so the shifts do not
          // accumulate down the nesting.
          let g = group_doc(
            k,
            id,
            body,
            cap(suffix[si][j + 1] + after[si]),
            extra,
            memo,
          )
          @pp.horz2(d, if extra > 0 { @pp.nest(extra, g) } else { g })
        }
        ABrk(_, _) => d
      }
    }
    d
  }

  let mut acc = seg_doc(0)
  for i, brk in brks {
    let (str, ind) = brk
    acc = match (str, mode) {
      // Hard breaks end the line in every mode, h-boxes included.
      (Newline, _) => @pp.concat([acc, line_break(ind, false), seg_doc(i + 1)])
      (BlankLine, _) => @pp.concat([acc, line_break(ind, true), seg_doc(i + 1)])
      (Space, Flat) => @pp.concat([acc, @pp.txt(" "), seg_doc(i + 1)])
      (Cut, Flat) => @pp.concat2(acc, seg_doc(i + 1))
      (_, Brkm) => @pp.concat([acc, line_break(ind, false), seg_doc(i + 1)])
      // Fill: this separator alone decides, on whether the NEXT segment fits
      // beside whatever already follows it.
      (_, Fill) =>
        match flat_doc(segs[i + 1], memo) {
          Some(flat) => {
            let sep = if str is Space { " " } else { "" }
            @pp.concat2(
              acc,
              @pp.if_flat(
                @pp.horz2(@pp.txt(sep), flat),
                @pp.vert([
                  @pp.empty,
                  @pp.horz2(@pp.txt(spaces(ind)), seg_doc(i + 1)),
                ]),
                reserve=after[i + 1],
              ),
            )
          }
          // Unflattenable: nothing to weigh, so the separator breaks.
          None => @pp.concat([acc, line_break(ind, false), seg_doc(i + 1)])
        }
    }
  }
  acc
}

///|
/// How wide one atom is flat, or None if it cannot be flattened at all.
fn atom_width(a : Atom, memo : Memo) -> Int? {
  // Skipped by the scan, so it contributes nothing -- not even the
  // unflattenability of whatever is inside it.
  guard !a.hidden else { return Some(0) }
  match a.kind {
    ATxt(w, s) => if s.contains("\n") { None } else { Some(w) }
    ABrk(_, _) => Some(0)
    AGrp(_, id, body) =>
      match group_flat(id, body, memo) {
        Some(d) => d.flat_width()
        None => None
      }
  }
}

///|
/// The all-flat rendering of a run of atoms, or None if it has none.
///
/// A hard break makes a body unflattenable, and so does a multi-line literal --
/// the engine would keep both on one logical line, but neither can be given a
/// flat width here.
fn flat_doc(ats : Array[Atom], memo : Memo) -> @pp.Doc? {
  let mut d = @pp.empty
  for a in ats {
    match a.kind {
      ATxt(w, s) => {
        guard !s.contains("\n") else { return None }
        d = @pp.concat2(d, @pp.txt_as(s, w))
      }
      ABrk(str, _) =>
        match str {
          Space => d = @pp.concat2(d, @pp.txt(" "))
          Cut => ()
          Newline | BlankLine => return None
        }
      AGrp(_, id, body) =>
        match group_flat(id, body, memo) {
          Some(g) => d = @pp.concat2(d, g)
          None => return None
        }
    }
  }
  Some(d)
}

///|
/// A group's body, flat.
///
/// The mode is `Flat`, so if-broken content is dropped -- the rule the engine
/// applies to a group it keeps on one line. Nested groups flatten too, whatever
/// their kind, which is what the engine's scan does: `TBegin` pushes `Flat`
/// unconditionally.
fn group_flat(id : Int, body : Array[Node], memo : Memo) -> @pp.Doc? {
  match memo.flat.get(id) {
    Some(d) => d
    None => {
      let ats : Array[Atom] = []
      atoms(body, 0, Flat, ats)
      let d = flat_doc(ats, memo)
      memo.flat[id] = d
      d
    }
  }
}

///|
/// A group, laid out by its kind, with `reserve` columns kept free for what
/// follows it on the line.
fn group_doc(
  kind : @printer.GKind,
  id : Int,
  body : Array[Node],
  reserve : Int,
  bump : Int,
  memo : Memo,
) -> @pp.Doc {
  let key = (id, mode_code_of(kind) * 2 + bump, reserve)
  match memo.docs.get(key) {
    Some(d) => d
    None => {
      let d = match kind {
        GH => lay(body, Flat, reserve, memo)
        GV => lay(body, Brkm, reserve, memo)
        GBox | GHov => lay(body, Fill, reserve, memo)
        // The only kind whose mode is a decision rather than a constant, and so
        // the only one whose own layout the reserve decides rather than merely
        // passes down.
        //
        // Its flat branch is the body in Flat MODE, not the body flattened: a
        // group the engine keeps on one line still resolves the groups inside
        // it one at a time, and one of them can still break. Materialising both
        // branches is what the memo is for.
        GHv => {
          let flat = lay(body, Flat, reserve, memo)
          match flat.flat_width() {
            Some(_) =>
              @pp.if_flat(
                flat,
                lay(body, Brkm, reserve, memo),
                reserve=cap(reserve + bump),
              )
            None => lay(body, Brkm, reserve, memo)
          }
        }
      }
      memo.docs[key] = d
      d
    }
  }
}

///|
/// The mode a group of this kind lays its body out in, as a memo key. `GHv` is
/// laid out both ways, but its two are always reached together, so one key
/// covers them.
fn mode_code_of(kind : @printer.GKind) -> Int {
  match kind {
    GH => mode_code(Flat)
    GV => mode_code(Brkm)
    GBox | GHov => mode_code(Fill)
    GHv => 3
  }
}

///|
/// Lay a token stream out as a `@pp.Doc`.
///
/// The outermost frame is a breaking one at indent 0, as in the engine, and
/// nothing follows it -- the engine's `Fits` on popping past the outermost
/// frame.
pub fn to_doc(tokens : Array[@printer.Token]) -> @pp.Doc {
  let root = tree(tokens)
  prune(root)
  lay(root, Brkm, 0, { flat: Map([]), docs: Map([]) })
}

///|
/// Lay a token stream out as text.
///
/// Lines of nothing but the spaces a `TNest` asked for are emptied: the engine
/// writes its indentation only ahead of content, so a line of pure whitespace
/// is something it can never produce.
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
