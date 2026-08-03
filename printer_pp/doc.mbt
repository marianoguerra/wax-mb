// An ALTERNATIVE layout engine for the same documents `printer` lays out.
//
// `printer` is a streaming engine with bounded lookahead, ported from the
// reference OCaml. This package answers a different question: what does the
// same document look like laid out by a general-purpose library instead --
// marianoguerra/pretty-fast-pretty-printer, the MoonBit port of Brown PLT's
// pretty-fast-pretty-printer?
//
// The two share their FRONT END. `@printer.Printer` -- the imperative builder,
// with its break coalescing, its deferred end-of-line comments and its
// skip_space -- is engine-independent: width never reaches it. So this package
// takes the builder's token stream (`@printer.run_tokens`) and lays it out by
// building a `@pp.Doc` instead of by streaming. Anything that prints through a
// `(Printer) -> Unit` callback can therefore be rendered either way with no
// change to the printing code, which is what makes the two comparable at all.
//
// The output is NOT identical. `printer_pp/README.md` says where and why, and
// `tools/ppdiff` measures it over the corpus.
//
// The pipeline is three passes over the token stream:
//
//   1. `tree` -- rebuild the bracketed structure the flat stream encodes.
//   2. `prune` -- collapse runs of breaks the way the streaming engine's
//      pending-break state does implicitly.
//   3. `lay`   -- lower to a `@pp.Doc` and render it.

///|
/// The document tree a token stream encodes.
///
/// This is the token stream with its `TEnd`s resolved into nesting: a tree is
/// what the `@pp` combinators need, and rebuilding it is the only thing the
/// streaming engine never has to do.
priv enum Node {
  /// A literal, at the display width the builder measured it at. The width is
  /// carried rather than recomputed because it is not the string's length: a
  /// colour escape occupies no columns, and a CJK character occupies two.
  Text(Int, String)
  Brk(@printer.BreakStrength)
  /// A group: its kind, an identity, and its body. The identity is what lets
  /// the lowering memoise a group it reaches twice -- which it does whenever an
  /// enclosing group has to be built both flat and broken.
  Group(@printer.GKind, Int, Array[Node])
  /// Break-indentation, relative to the enclosing group's base column.
  Nest(Int, Array[Node])
  /// Body emitted only when the enclosing group is laid out broken.
  IfBroken(Array[Node])
  /// A break `prune` removed. A hole rather than a deletion, so pruning can
  /// rewrite the tree in place without renumbering it.
  Nop
}

///|
/// One open scope while rebuilding the tree.
priv struct Level {
  scope : Scope
  items : Array[Node]
}

///|
priv enum Scope {
  SRoot
  SGroup(@printer.GKind)
  SNest(Int)
  SIfBroken
}

///|
/// Rebuild the tree a flat token stream encodes.
///
/// An unmatched `TEnd` is ignored rather than fatal, matching the engine, whose
/// `TEnd` handler refuses to pop the outermost frame.
fn tree(tokens : Array[@printer.Token]) -> Array[Node] {
  let stack : Array[Level] = [{ scope: SRoot, items: [] }]
  let mut next_id = 0
  fn top() {
    stack[stack.length() - 1]
  }

  fn open(s : Scope) {
    stack.push({ scope: s, items: [] })
  }

  fn close() {
    if stack.length() <= 1 {
      return
    }
    let lv = stack.unsafe_pop()
    let node = match lv.scope {
      SGroup(k) => {
        next_id += 1
        Group(k, next_id, lv.items)
      }
      SNest(n) => Nest(n, lv.items)
      SIfBroken => IfBroken(lv.items)
      SRoot => Nop
    }
    top().items.push(node)
  }

  for tok in tokens {
    match tok {
      TText(w, s) => top().items.push(Text(w, s))
      TBreak(s) => top().items.push(Brk(s))
      TBegin(k) => open(SGroup(k))
      TNest(n) => open(SNest(n))
      TIfBroken => open(SIfBroken)
      TEnd => close()
    }
  }
  // A document that ends mid-group still has to render; close what is open.
  while stack.length() > 1 {
    close()
  }
  stack[0].items
}

///|
/// Collapse each run of consecutive breaks into a single one.
///
/// The streaming engine does this without meaning to: a break only sets
/// `pend_line`/`pend_flat`, and nothing is written until the next TEXT flushes
/// it. Two breaks with no text between them -- even in different groups, since
/// group tokens write nothing -- therefore produce ONE line ending, and a run
/// with no text before or after it produces none at all.
///
/// A tree of `@pp.Doc`s has no such state, so the collapse has to be done
/// explicitly, before lowering. WHICH break of the run survives decides the
/// indent the line lands at, and it is not a free choice; see
/// `Pruner::settle`.
fn prune(root : Array[Node]) -> Unit {
  let pr = {
    run: [],
    strength: @printer.Cut,
    seen_text: false,
    fb: 0,
    nd: 0,
    pend: 0,
    origin: 0,
    delta: 0,
    opened: false,
    saw_group: false,
  }
  pr.walk(root)
  // A trailing run has no text to flush it: it is dropped entirely, which is
  // what keeps a document from ending in whitespace.
  pr.seen_text = false
  pr.settle()
}

///|
/// The pruning walk's state.
///
/// Beyond the run itself, this tracks where each break of the run would INDENT
/// to, because the engine's answer is not any one break's indent: the line ends
/// at the indent of the LAST break, while a group opened part-way through the
/// run bases itself on the indent pending at that moment -- `TBegin` takes its
/// base from `eff_col`, which reports the pending line's indent.
///
/// Indents are tracked as offsets from the run's first break, since that is the
/// only fixed point available: the absolute columns frames are based at are
/// exactly what a `@pp.Doc` decides at render time and cannot be asked for
/// here.
priv struct Pruner {
  run : Array[(Array[Node], Int)]
  mut strength : @printer.BreakStrength
  mut seen_text : Bool
  /// The current frame's base, as an offset.
  mut fb : Int
  /// Nesting accumulated within the current frame.
  mut nd : Int
  /// The indent the pending line would land at: the last break's `fb + nd`.
  mut pend : Int
  /// `pend` at the run's first break -- the origin the offsets are from.
  mut origin : Int
  /// How much further right the run's last break indents than its first.
  mut delta : Int
  /// Whether a group opened between the run's FIRST and LAST break, which is
  /// what makes the choice of surviving break more than a formality. A group
  /// opening after the last break does not count: nothing indents to it.
  mut opened : Bool
  /// Whether a group has opened since the run began, not yet known to sit
  /// between two of its breaks.
  mut saw_group : Bool
}

///|
fn Pruner::walk(self : Pruner, items : Array[Node]) -> Unit {
  for i, n in items {
    match n {
      Text(_, _) => {
        self.settle()
        self.seen_text = true
      }
      Brk(s) => {
        self.pend = self.fb + self.nd
        if self.run.length() == 0 {
          self.strength = s
          self.origin = self.pend
          self.saw_group = false
        } else if s.strength() > self.strength.strength() {
          self.strength = s
        }
        self.opened = self.saw_group
        self.delta = self.pend - self.origin
        self.run.push((items, i))
      }
      Nest(n, body) => {
        self.nd += n
        self.walk(body)
        self.nd -= n
      }
      Group(_, _, body) => {
        let (fb, nd) = (self.fb, self.nd)
        if self.run.length() > 0 {
          // Opened mid-run: the engine bases it on the pending indent, not on
          // the column the previous text ended at.
          self.saw_group = true
          self.fb = self.pend
        } else {
          self.fb = 0
        }
        self.nd = 0
        self.walk(body)
        self.fb = fb
        self.nd = nd
      }
      IfBroken(body) => self.walk(body)
      Nop => ()
    }
  }
}

///|
/// Resolve the open run into a single break.
///
/// With no text before it the whole run goes: there is no line to end.
/// Otherwise one break survives, and which one is decided by whether a group
/// opened during the run:
///
///   * NO GROUP OPENED -- keep the LAST. Every frame still open was opened
///     before the run began, so its base column is the same one `@pp` will
///     render it at, and the last break's indent is the engine's answer
///     exactly.
///   * A GROUP OPENED -- keep the FIRST, and pay the indent difference in
///     spaces where the last break was. The group must base itself on the
///     indent the pending line would have landed at, and the only way to put
///     `@pp` at that column is to actually break there first.
///
/// The second case is exact only when the run indents rightward (`delta >= 0`),
/// which is what it does when the last break is inside the group that opened.
/// A run that opens a group and leaves it again can indent leftward, and there
/// are no negative spaces; that falls back to keeping the last.
fn Pruner::settle(self : Pruner) -> Unit {
  let last = self.run.length() - 1
  let keep_first = self.opened && self.delta >= 0
  for j, pos in self.run {
    let (items, i) = pos
    items[i] = if !self.seen_text {
      Nop
    } else if keep_first {
      if j == 0 {
        Brk(self.strength)
      } else if j == last && self.delta > 0 {
        Text(self.delta, spaces(self.delta))
      } else {
        Nop
      }
    } else if j == last {
      Brk(self.strength)
    } else {
      Nop
    }
  }
  self.run.clear()
}
