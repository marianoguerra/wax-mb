// Reading a shrubbery tree: spans, group shapes, and term predicates.

///|
/// A shrubbery span as an error-report span.
///
/// `idx` is the UTF-16 index shrubbery keeps for exactly this purpose; `line`
/// and `pos` are code-point positions for humans and are not used here.
pub fn to_span(s : @shbasic.Span) -> @wap.Span {
  { start: s.start.idx, len: s.end.idx - s.start.idx, }
}

///|
/// The span of a shrubbery node.
pub fn node_span(n : @sh.Node) -> @wap.Span {
  to_span(n.span)
}

///|
/// The span covering a run of terms, or `nowhere` if there are none.
pub fn terms_span(ts : ArrayView[@sh.Node]) -> @wap.Span {
  if ts.length() == 0 {
    @wap.nowhere
  } else {
    let a = node_span(ts[0])
    let b = node_span(ts[ts.length() - 1])
    { start: a.start, len: b.start + b.len - a.start, }
  }
}

///|
/// A group split into the three parts shrubbery guarantees it can have: the
/// terms, then at most one block, then at most one run of alternatives.
///
/// This shape is not a convention of wap's, it is the shrubbery grammar --
/// "a block list appears only at the end of a group list or just before an
/// alts list that is at the end of the group list".
pub(all) struct Parts {
  head : Array[@sh.Node]
  block : Array[@sh.Node]?
  alts : Array[Array[@sh.Node]]?
  span : @wap.Span
}

///|
/// The children of a node that holds a sequence, or a single-element array.
fn children(n : @sh.Node) -> Array[@sh.Node] {
  match n.it {
    Group(xs)
    | Block(xs)
    | Alts(xs)
    | Parens(xs)
    | Brackets(xs)
    | Braces(xs)
    | Quotes(xs)
    | Multi(xs) => xs
    _ => [n]
  }
}

///|
/// Split a group into head terms, block and alternatives.
pub fn split(n : @sh.Node) -> Parts {
  let all = children(n)
  let head = []
  let mut block = None
  let mut alts = None
  for t in all {
    match t.it {
      Block(gs) => block = Some(gs)
      Alts(bs) => {
        let arms = []
        for b in bs {
          arms.push(children(b))
        }
        alts = Some(arms)
      }
      _ => head.push(t)
    }
  }
  { head, block, alts, span: node_span(n), }
}

///|
/// The identifier a term is, if it is one.
pub fn as_id(n : @sh.Node) -> String? {
  match n.it {
    Id(s) => Some(s)
    _ => None
  }
}

///|
/// The operator a term is, if it is one.
pub fn as_op(n : @sh.Node) -> String? {
  match n.it {
    Op(s) => Some(s)
    _ => None
  }
}

///|
/// The keyword a term is, if it is one. Keywords are wap's labels: `~outer`.
pub fn as_kw(n : @sh.Node) -> String? {
  match n.it {
    Kw(s) => Some(s)
    _ => None
  }
}

///|
/// True when the term is exactly this identifier.
pub fn is_id(n : @sh.Node, name : String) -> Bool {
  as_id(n) is Some(s) && s == name
}

///|
/// True when the term is exactly this operator.
pub fn is_op(n : @sh.Node, name : String) -> Bool {
  as_op(n) is Some(s) && s == name
}

///|
/// The string a literal term is, if it is a string.
pub fn as_str(n : @sh.Node) -> String? {
  match n.it {
    Lit(Str(s)) => Some(s)
    _ => None
  }
}

///|
/// The source text of a term, which is how numeric literals keep the spelling
/// they were written with. Shrubbery parses `0xFF` to 255; Wax needs the digits
/// back, because the checker's flexible-literal typing and the printer both
/// depend on them.
pub fn raw_text(n : @sh.Node) -> String {
  // `to_source` replays the node's metadata, which includes the whitespace it
  // was written after. A literal's spelling is what is wanted here, not its
  // layout.
  n.to_source().trim().to_owned()
}
