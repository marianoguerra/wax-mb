// Attaching collected comments to AST spans.
//
// The second half of wax/src/lib-utils/trivia.ml, deferred from phase 1
// because nothing could exercise it until the printer existed.
//
// The lexer collected comments keyed by the byte offset of the preceding token
// (see trivia.mbt). This decides which AST node each one belongs to, and
// whether it renders BEFORE the node, WITHIN it, or AFTER its closing
// delimiter. Getting that wrong does not crash -- it moves a comment somewhere
// else in the output, which is exactly what oracle 1 catches.

///|
/// Where a comment sits relative to the node that owns it.
pub(all) struct Associated {
  /// Anchored before the node starts.
  before : Array[Entry]
  /// Between the node's children and its own end: rendered inside it.
  within : Array[Entry]
  /// Trailing, up to the next sibling: rendered past the closing delimiter.
  after : Array[Entry]
} derive(Eq, Debug)

///|
pub let empty_assoc : Associated = { before: [], within: [], after: [] }

///|
/// A location-keyed trivia table.
pub struct Table {
  entries : Map[SpanKey, Associated]
  /// Spans already handed out, so a span recorded by more than one node yields
  /// its trivia only once.
  seen : Set[SpanKey]
}

///|
/// A span reduced to its byte offsets.
///
/// Keying on offsets alone is deliberate: it is cheap to hash and compare, and
/// the filename is the same for every span in one parse.
struct SpanKey {
  start : Int
  end : Int
} derive(Eq, Hash, Compare, Debug)

///|
fn key_of(loc : @basic.Location) -> SpanKey {
  { start: loc.start.cnum, end: loc.end.cnum }
}

///|
pub fn Table::empty() -> Table {
  { entries: Map([]), seen: Set([], capacity=16) }
}

///|
/// The trivia attached to `loc`, or nothing.
///
/// A span yields its trivia ONCE: several nodes can record the same range (a
/// `Get` instruction and the identifier it wraps span the same name), the
/// printer looks each up, and only the first may carry the comments.
pub fn Table::get(self : Table, loc : @basic.Location?) -> Associated {
  match loc {
    None => empty_assoc
    Some(l) => {
      let k = key_of(l)
      match self.entries.get(k) {
        None => empty_assoc
        Some(a) =>
          if self.seen.contains(k) {
            empty_assoc
          } else {
            self.seen.add(k)
            a
          }
      }
    }
  }
}

///|
/// The set of spans the printer actually looks up.
///
/// Filled by a dry printing pass; see `associate`.
pub struct Locations {
  marked : Set[SpanKey]
}

///|
pub fn Locations::new() -> Locations {
  { marked: Set([], capacity=64) }
}

///|
pub fn Locations::mark(self : Locations, loc : @basic.Location) -> Unit {
  self.marked.add(key_of(loc))
}

///|
pub fn Locations::contains(self : Locations, loc : @basic.Location) -> Bool {
  self.marked.contains(key_of(loc))
}

///|
/// Associate collected trivia with the spans the printer will look up.
///
/// `collect` is a dry printing pass that records those spans. Association runs
/// over the spans that are BOTH a parse node and looked up by the printer --
/// the two sets clip each other in opposite directions and neither alone will
/// do:
///
///   * dropping a parse node the printer skips keeps its comments from being
///     silently lost; they bubble up to an enclosing node that does print.
///   * dropping a looked-up span that no parse node owns keeps a comment from
///     landing somewhere that is not a source construct. The printer stamps
///     some output with the span of a mere TOKEN, and such a span can outrank
///     the real nodes and steal the file's leading comments.
///
/// Returns the table and the leftovers no location owns -- trailing comments
/// past the last node, or the whole file when there are no nodes at all. The
/// caller prints those as tail trivia.
pub fn associate(
  ctx : Context,
  collect : (Locations) -> Unit,
) -> (Table, Array[Entry]) {
  let only = Locations::new()
  collect(only)
  let locs = []
  for l in ctx.locations() {
    if only.contains(l) {
      locs.push(key_of(l))
    }
  }
  // Preorder: start ascending, and on a tie end DESCENDING, so an enclosing
  // node precedes the nodes it contains.
  locs.sort_by((a, b) => {
    if a.start != b.start {
      a.start - b.start
    } else {
      b.end - a.end
    }
  })

  // Collapse identical spans. One source range is often recorded by several
  // nodes; two same-range entries would make one look like the other's child,
  // and the steal-the-last-child's-trailing-comments path would then hand the
  // parent an empty `after` instead of computing the gap to the next sibling --
  // silently dropping a comment anchored just past the span.
  let arr : Array[SpanKey] = []
  for k in locs {
    if arr.is_empty() || arr[arr.length() - 1] != k {
      arr.push(k)
    }
  }
  let n = arr.length()

  // Rebuild the nesting from the flat preorder list in one linear pass.
  //
  // subtree_end[i] is the last index contained in arr[i]: the maximal run right
  // after i whose end does not exceed arr[i]'s. A monotonic stack of still-open
  // ancestors yields it in O(n) -- a node's subtree ends at i-1 the moment an i
  // appears whose end EXCEEDS it. Equal ends keep it open, since an equal-end
  // node with a later start nests inside.
  let subtree_end = Array::make(if n > 0 { n } else { 1 }, 0)
  let stack : Array[Int] = []
  for i in 0..<n {
    while stack.length() > 0 && arr[stack[stack.length() - 1]].end < arr[i].end {
      let t = stack.unsafe_pop()
      subtree_end[t] = i - 1
    }
    stack.push(i)
  }
  for t in stack {
    subtree_end[t] = n - 1
  }
  let tbl = Table::empty()
  let comments = ctx.entries().to_owned()
  let consumed = process_range(
    tbl,
    arr,
    subtree_end,
    None,
    0,
    n - 1,
    comments,
    0,
  )
  (tbl, comments[consumed:].to_owned())
}

///|
/// Comments anchored before `threshold`, and the rest.
fn split_before(
  comments : Array[Entry],
  from : Int,
  threshold : Int,
) -> (Array[Entry], Int) {
  let taken = []
  let mut i = from
  while i < comments.length() && comments[i].anchor < threshold {
    taken.push(comments[i])
    i += 1
  }
  (taken, i)
}

///|
/// A node's trailing comments: those anchored in [parent_end, upto).
///
/// `upto` is the next sibling's start, so a comment separated from the node by
/// a punctuation token -- a list comma -- still trails it rather than leading
/// the next sibling.
///
/// An INLINE line comment ends the node's line and is its trailing comment; a
/// line-start comment or a blank line begins the next sibling and is left in
/// place.
fn get_after(
  comments : Array[Entry],
  from : Int,
  parent_end : Int,
  upto : Int,
) -> (Array[Entry], Int) {
  let taken = []
  let mut i = from
  while i < comments.length() {
    let c = comments[i]
    let in_gap = c.anchor >= parent_end && c.anchor < upto
    if !in_gap {
      break
    }
    match (c.trivia, c.position) {
      (Item(kind=LineComment, ..), Inline) => {
        // Ends the node's line: claimed, and nothing after it can be.
        taken.push(c)
        i += 1
        break
      }
      (Item(kind=LineComment, ..), LineStart) =>
        // Begins the next sibling: left in place.
        break
      (Item(_), _) => {
        taken.push(c)
        i += 1
      }
      (BlankLine, _) =>
        // Separates the node from what follows: left in place.
        break
    }
  }
  (taken, i)
}

///|
/// Partition the comments over the nesting tree, left to right.
///
/// `last_upto` is the `upto` the range's LAST node uses -- how far it may still
/// claim trailing comments. For a child range it is the enclosing parent's end,
/// so the last child reaches across its separator (a block's `;`) to grab the
/// comment trailing the last statement, and a comment after a stack of
/// co-terminating closers bubbles out to the outermost of them. At the top
/// level there is no enclosing node, so a module-tail comment stays in the
/// leftovers.
/// Returns the index of the first comment it did NOT consume.
fn process_range(
  tbl : Table,
  arr : Array[SpanKey],
  subtree_end : Array[Int],
  last_upto : Int?,
  lo_in : Int,
  hi : Int,
  comments : Array[Entry],
  from_in : Int,
) -> Int {
  let mut lo = lo_in
  let mut from = from_in
  while lo <= hi {
    let child_lo = lo + 1
    let child_hi = subtree_end[lo]
    let next_sib = child_hi + 1
    let upto = if next_sib <= hi {
      arr[next_sib].start
    } else {
      match last_upto {
        Some(u) => u
        None => arr[lo].end + 1
      }
    }
    let (before, r1) = split_before(comments, from, arr[lo].start)
    let r2 = process_range(
      tbl,
      arr,
      subtree_end,
      Some(arr[lo].end),
      child_lo,
      child_hi,
      comments,
      r1,
    )
    // Own-line comments still inside the node render inside it; an inline
    // trailing comment was already claimed by the last child as its `after`.
    let (within, r3) = split_before(comments, r2, arr[lo].end)
    let mut final_after : Array[Entry] = []
    let mut r4 = r3
    let co_terminating = child_hi >= child_lo &&
      arr[child_hi].end == arr[lo].end
    if co_terminating {
      match tbl.entries.get(arr[child_hi]) {
        Some(assoc) => {
          let stolen = assoc.after
          tbl.entries[arr[child_hi]] = { ..assoc, after: [] }
          // The co-terminating child's own window collapsed to empty, since its
          // upto reached only to this node's end. Scan on to this node's upto so
          // its real trailing comments are not dropped; whatever the child did
          // drain is already consumed, so this cannot double-count.
          let (extra, r) = get_after(comments, r3, arr[lo].end, upto)
          final_after = stolen
          for e in extra {
            final_after.push(e)
          }
          r4 = r
        }
        None => {
          let (a, r) = get_after(comments, r3, arr[lo].end, upto)
          final_after = a
          r4 = r
        }
      }
    } else {
      let (a, r) = get_after(comments, r3, arr[lo].end, upto)
      final_after = a
      r4 = r
    }
    tbl.entries[arr[lo]] = { before, within, after: final_after }
    lo = next_sib
    from = r4
  }
  from
}

///|
/// Drop trailing blank lines from a run of trivia.
pub fn drop_trailing_blank_lines(entries : Array[Entry]) -> Array[Entry] {
  let mut last = entries.length()
  while last > 0 && entries[last - 1].trivia is BlankLine {
    last -= 1
  }
  entries[:last].to_owned()
}
