// Reading the folded tree back out of a lowered body.
//
// The text format writes instructions FOLDED -- `(i32.add (local.get $x)
// (i32.const 1))` -- and the binary writes them flat, operands first. The two
// are the same tree read in two ways, and the lowering already built it: every
// wax instruction emits its operands and then itself, which is a post-order
// flattening.
//
// So the nesting is not re-derived here from an arity table. It is READ from
// the spans the lowering recorded as it went -- a second derivation could
// disagree with the first, and then one of the two outputs would be wrong with
// nothing to say which.

///|
/// One folded instruction: a head, and the operands folded under it.
pub(all) struct Node {
  head : @wasm_bin.Instruction
  operands : Array[Node]
}

///|
/// Fold a lowered body, given the spans recorded while lowering it.
///
/// A span is one node's whole run, and it always follows its children's --
/// so the LAST span ending at a given point is the outermost node there.
pub fn fold(
  body : Array[@wasm_bin.Instruction],
  spans : Array[(Int, Int)],
) -> Array[Node] {
  // The outermost span starting at or after each position, for a linear walk.
  // Spans are recorded in completion order, so a node's own span is the last
  // one covering its range; scanning for the WIDEST span at a position finds
  // the node rather than one of its operands.
  fn widest(from : Int, limit : Int) -> (Int, Int)? {
    let mut best : (Int, Int)? = None
    for s in spans {
      if s.0 == from && s.1 <= limit {
        best = match best {
          Some(b) => if s.1 > b.1 { Some(s) } else { Some(b) }
          None => Some(s)
        }
      }
    }
    best
  }

  fn build(from : Int, limit : Int) -> Array[Node] {
    let out : Array[Node] = []
    let mut at = from
    while at < limit {
      let (start, end) = match widest(at, limit) {
        Some(s) => s
        // No span covers this instruction: it was pushed by a lowering that
        // emits several instructions for one node -- the head is the last, and
        // whatever precedes it here is its own operand run.
        None => (at, limit)
      }
      // The head is the LAST instruction of the span; everything before it in
      // the span computed its operands.
      let head = body[end - 1]
      out.push({ head, operands: build(start, end - 1) })
      at = end
    }
    out
  }

  build(0, body.length())
}
