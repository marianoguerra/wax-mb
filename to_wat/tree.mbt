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
/// One folded instruction: a head, the operands folded under it, and -- for the
/// structural instructions -- the bodies they enclose, each folded too.
///
/// Operands and bodies are different things: an operand is a value the
/// instruction consumes and a body is code it guards. They are one node here
/// because the text format writes both inside the same parentheses.
pub(all) struct Node {
  head : @wasm_bin.Instruction
  operands : Array[Node]
  bodies : Array[Array[Node]]
}

///|
/// The bodies a structural instruction encloses, in written order.
fn enclosed(i : @wasm_bin.Instruction) -> Array[Array[@wasm_bin.Instruction]] {
  match i {
    Block(_, b) | Loop(_, b) | TryTable(_, _, b) => [b]
    If(_, t, e) => if e.is_empty() { [t] } else { [t, e] }
    LegacyTry(_, b, catches, all) => {
      let out = [b]
      for c in catches {
        out.push(c.1)
      }
      if all is Some(a) {
        out.push(a)
      }
      out
    }
    _ => []
  }
}

///|
/// Fold a lowered body, given the spans recorded while lowering it.
///
/// A span is one node's whole run, and it always follows its children's -- so
/// the widest span at a position is the node there, and the last instruction
/// in it is the head.
///
/// The NESTED lists arrive in completion order: deepest first, then left to
/// right, with each enclosing body after the bodies inside it. Taking them
/// from the BACK while walking each body's structural instructions right to
/// left visits them in exactly that order reversed, which is how each body
/// finds its own.
pub fn fold(
  body : Array[@wasm_bin.Instruction],
  spans : Array[(Int, Int, Int)],
  nested? : Array[Array[(Int, Int, Int)]] = [],
) -> Array[Node] {
  let cursor = @ref.new(nested.length())
  fold_body(body, spans, nested, cursor)
}

///|
/// The spans that denote a folded instruction.
///
/// A span whose head begins where it ends emitted nothing of its own: a tuple
/// is its elements and no more. Such a node is NOT a folded instruction, and
/// reading one out of it would make the last element a head that consumes the
/// rest -- `(local.get $b (local.get $a))` for what is two statements. Dropping
/// those spans leaves the children, which are what the text writes.
fn folding_spans(spans : Array[(Int, Int, Int)]) -> Array[(Int, Int, Int)] {
  let out : Array[(Int, Int, Int)] = []
  for s in spans {
    if s.1 < s.2 {
      out.push(s)
    }
  }
  out
}

///|
fn fold_body(
  body : Array[@wasm_bin.Instruction],
  all_spans : Array[(Int, Int, Int)],
  nested : Array[Array[(Int, Int, Int)]],
  cursor : Ref[Int],
) -> Array[Node] {
  let spans = folding_spans(all_spans)
  fn widest(from : Int, limit : Int) -> (Int, Int, Int)? {
    let mut best : (Int, Int, Int)? = None
    for s in spans {
      if s.0 == from && s.2 <= limit {
        best = match best {
          Some(b) => if s.2 > b.2 { Some(s) } else { Some(b) }
          None => Some(s)
        }
      }
    }
    best
  }

  // The boundaries first, left to right; the nodes are built from them right to
  // left, because that is the order the nested bodies were recorded in.
  let bounds : Array[(Int, Int, Int)] = []
  let mut at = 0
  while at < body.length() {
    let b = match widest(at, body.length()) {
      Some(s) => s
      // No span covers this instruction: one wax node lowered to several
      // without recording it, and the head is the last of them. Treating it
      // as standing alone instead was measured and is worse -- the run really
      // is one node, and the fusions are why.
      None => (at, at, body.length())
    }
    bounds.push(b)
    at = b.2
  }
  let out : Array[Node] = Array::make(bounds.length(), {
    head: @wasm_bin.Instruction::Nop,
    operands: [],
    bodies: [],
  })
  for k = bounds.length() - 1; k >= 0; k = k - 1 {
    let (start, _, end) = bounds[k]
    let head = body[end - 1]
    // The enclosed bodies are taken in reverse too, so that the LAST one
    // written is the last one recorded.
    let inner = enclosed(head)
    let bodies : Array[Array[Node]] = Array::make(inner.length(), [])
    for j = inner.length() - 1; j >= 0; j = j - 1 {
      cursor.val = cursor.val - 1
      let s = if cursor.val >= 0 && cursor.val < nested.length() {
        nested[cursor.val]
      } else {
        []
      }
      bodies[j] = fold_body(inner[j], s, nested, cursor)
    }
    out[k] = {
      head,
      operands: fold_body_range(body, all_spans, start, end - 1),
      bodies,
    }
  }
  out
}

///|
/// Fold the operands lying in `[from, limit)` of a body.
fn fold_body_range(
  body : Array[@wasm_bin.Instruction],
  spans : Array[(Int, Int, Int)],
  from : Int,
  limit : Int,
) -> Array[Node] {
  guard from < limit else { return [] }
  let slice : Array[@wasm_bin.Instruction] = []
  for k in from..<limit {
    slice.push(body[k])
  }
  let shifted : Array[(Int, Int, Int)] = []
  for s in spans {
    if s.0 >= from && s.2 <= limit {
      shifted.push((s.0 - from, s.1 - from, s.2 - from))
    }
  }
  // An operand encloses no body of its own here: a structural instruction is
  // never an operand, because it is a statement.
  fold_body(slice, shifted, [], @ref.new(0))
}
