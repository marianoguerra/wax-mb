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
  /// Where the source wrote this node, so the comments written against it can
  /// be found. Dummy for a node no span covered.
  loc : @basic.Location
}

///|
/// The bodies a structural instruction encloses, in written order.
fn enclosed(i : @wasm_bin.Instruction) -> Array[Array[@wasm_bin.Instruction]] {
  match i {
    Block(_, b) | Loop(_, b) | TryTable(_, _, b) => [b]
    // BOTH, always: the lowering records a span list for each, and an `if`
    // that sometimes has one and sometimes two shifts every list after it.
    // An empty else is dropped when it is printed, not when it is paired.
    If(_, t, e) => [t, e]
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
    // The wrappers are transparent: a hinted `if` is still an `if`, and the
    // bodies it guards are its own. Without this the hint swallowed them.
    Hinted(_, inner) | Spelled(_, inner) | FromString(_, _, inner) =>
      enclosed(inner)
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
  spans : Array[@wasm_bin.Span],
  nested? : Array[Array[@wasm_bin.Span]] = [],
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
fn folding_spans(spans : Array[@wasm_bin.Span]) -> Array[@wasm_bin.Span] {
  let out : Array[@wasm_bin.Span] = []
  for s in spans {
    if s.head < s.end {
      out.push(s)
    }
  }
  out
}

///|
fn fold_body(
  body : Array[@wasm_bin.Instruction],
  all_spans : Array[@wasm_bin.Span],
  nested : Array[Array[@wasm_bin.Span]],
  cursor : Ref[Int],
) -> Array[Node] {
  let spans = folding_spans(all_spans)
  fn widest(from : Int, limit : Int) -> @wasm_bin.Span? {
    let mut best : @wasm_bin.Span? = None
    for s in spans {
      if s.start == from && s.end <= limit {
        best = match best {
          Some(b) => if s.end > b.end { Some(s) } else { Some(b) }
          None => Some(s)
        }
      }
    }
    best
  }

  // The boundaries first, left to right; the nodes are built from them right to
  // left, because that is the order the nested bodies were recorded in.
  let bounds : Array[@wasm_bin.Span] = []
  let mut at = 0
  while at < body.length() {
    let b = match widest(at, body.length()) {
      Some(s) => s
      // No span covers this instruction: one wax node lowered to several
      // without recording it, and the head is the last of them. The run ends
      // where the next RECORDED node begins -- taking it to the end of the
      // body instead swallows every statement that follows into an operand
      // chain, and taking it as a single instruction splits a fusion.
      //
      // The run cannot END in an instruction that takes nothing: a constant
      // is not the head of anything, and `(i32.const 1 (local.get $x))` is
      // not something the format can mean. Those trailing instructions are
      // nodes of their own, reached on the next turn of this loop.
      None => {
        let mut e = next_start(spans, at, body.length())
        while e > at + 1 && takes_nothing(body[e - 1]) {
          e = e - 1
        }
        { start: at, head: at, end: e, loc: @basic.dummy_loc }
      }
    }
    bounds.push(b)
    at = b.end
  }
  let out : Array[Node] = Array::make(bounds.length(), {
    head: @wasm_bin.Instruction::Nop,
    operands: [],
    bodies: [],
    loc: @basic.dummy_loc,
  })
  for k = bounds.length() - 1; k >= 0; k = k - 1 {
    let start = bounds[k].start
    let end = bounds[k].end
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
    // A node may emit SEVERAL instructions of its own -- a cast that boxes an
    // i32 as an i31 and then converts it to an extern emits two. They are a
    // chain: each takes what the one before it left, and the text writes that
    // as nesting. The operands belong to the first of them.
    let hs = bounds[k].head
    let mut inner = fold_body_range(
      body,
      all_spans,
      start,
      if hs > start {
        hs
      } else {
        end - 1
      },
      nested,
      cursor,
    )
    if hs > start && hs < end - 1 {
      for j in hs..<(end - 1) {
        inner = [
          { head: body[j], operands: inner, bodies: [], loc: bounds[k].loc },
        ]
      }
    }
    out[k] = { head, operands: inner, bodies, loc: bounds[k].loc }
  }
  out
}

///|
/// Whether an instruction consumes no operands at all.
///
/// This is the one arity fact the printer uses, and it is used only where
/// nothing was recorded: a fallback has no information, and this keeps it
/// from inventing a nesting that cannot exist. Deliberately partial -- an
/// instruction missing from here is merely handled as before.
fn takes_nothing(i : @wasm_bin.Instruction) -> Bool {
  match i {
    I32Const(_)
    | I64Const(_)
    | F32Const(_)
    | F64Const(_)
    | V128Const(_)
    | LocalGet(_)
    | GlobalGet(_)
    | RefNull(_)
    | RefFunc(_)
    | MemorySize(_)
    | TableSize(_)
    | DataDrop(_)
    | ElemDrop(_)
    | AtomicFence
    | Nop
    | Unreachable => true
    // The wrappers are transparent: what they wrap is what runs.
    Spelled(_, inner) | Hinted(_, inner) | FromChar(_, inner) =>
      takes_nothing(inner)
    _ => false
  }
}

///|
/// Where the next recorded node begins after `at`.
fn next_start(spans : Array[@wasm_bin.Span], at : Int, limit : Int) -> Int {
  let mut best = limit
  for s in spans {
    if s.start > at && s.start < best {
      best = s.start
    }
  }
  best
}

///|
/// Fold the operands lying in `[from, limit)` of a body.
///
/// The spans are shifted to the slice's own indices; the nested bodies are
/// not, because they are matched by ORDER rather than by position.
fn fold_body_range(
  body : Array[@wasm_bin.Instruction],
  spans : Array[@wasm_bin.Span],
  from : Int,
  limit : Int,
  nested : Array[Array[@wasm_bin.Span]],
  cursor : Ref[Int],
) -> Array[Node] {
  guard from < limit else { return [] }
  let slice : Array[@wasm_bin.Instruction] = []
  for k in from..<limit {
    slice.push(body[k])
  }
  let shifted : Array[@wasm_bin.Span] = []
  for s in spans {
    if s.start >= from && s.end <= limit {
      shifted.push({
        ..s,
        start: s.start - from,
        head: s.head - from,
        end: s.end - from,
      })
    }
  }
  // An operand CAN enclose a body: `(br $l (block ...))` is one instruction
  // taking another that guards code. So the operands read from the same list
  // and the same cursor -- an operand's body was recorded like any other, and
  // skipping it shifts every list recorded before it.
  fold_body(slice, shifted, nested, cursor)
}
