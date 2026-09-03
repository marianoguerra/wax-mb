// Reasoning over conditional-compilation conditions.
//
// `#[if(...)]` conditions decide which declarations exist, so name resolution is
// path-sensitive: two declarations of one name are a conflict only when their
// conditions can hold together. Everything the checker asks reduces to one
// question -- is this formula satisfiable? -- and `logical_implies` is that
// question about `a and not b`.
//
// NOT A PORT OF THE REFERENCE'S SOLVER. `cond_solver.ml` is 240 lines on top of
// `vendor/theo`, a 1545-line BDD engine with generic theory combination. The
// theory Wax's condition language actually needs is far narrower than that
// engine's generality: every atom constrains ONE variable against a CONSTANT,
// and variables are of three kinds -- boolean, a version triple under a total
// order, and a string under equality. No atom relates two variables, so
// satisfiability decomposes per variable, and a DPLL search over the atoms with
// a per-variable theory check decides it completely.
//
// Complete and sound is the bar, because that is what makes the answers the
// same as the reference's -- and oracle 3 over the 449 corpus files that use
// `#[if]` is what checks that claim.

///|
/// A version triple, ordered lexicographically.
pub(all) struct Version {
  major : Int
  minor : Int
  patch : Int
} derive(Eq, Hash, Debug)

///|
pub fn Version::compare_to(self : Version, other : Version) -> Int {
  if self.major != other.major {
    return self.major - other.major
  }
  if self.minor != other.minor {
    return self.minor - other.minor
  }
  self.patch - other.patch
}

///|
pub impl Show for Version with fn output(self, logger) {
  logger.write_string("\{self.major}.\{self.minor}.\{self.patch}")
}

///|
/// An atom: one variable against one constant.
///
/// The order theory is normalized the way a total-order theory has to be, and
/// the way the reference's `Leq` does: an atom is always an upper bound, and
/// the lower bounds are its negations. `vid > v` is `not (vid <= v)`, and
/// `vid = v` is `vid <= v and not (vid < v)`. That is what keeps the atom set
/// small enough for the search to be trivial.
enum Atom {
  /// A boolean variable, which is its own atom.
  Bool(Int)
  /// `vid <= limit`, or `vid < limit` when not inclusive.
  Bound(Int, Version, Bool)
  /// `vid == constant`.
  Const(Int, Bytes)
} derive(Eq, Hash, Debug)

///|
/// A boolean formula over atoms.
enum Node {
  True
  False
  Lit(Atom, Bool)
  And(Array[Node])
  Or(Array[Node])
} derive(Eq, Debug)

///|
/// A formula over condition variables.
pub struct T {
  node : Node
}

///|
pub let true_ : T = { node: True, }

///|
pub let false_ : T = { node: False, }

///|
/// Negation, pushed to the literals so that a formula is always in negation
/// normal form. Which means the search never has to interpret a `not`, and the
/// theory check sees literals directly.
fn negate(n : Node) -> Node {
  match n {
    True => False
    False => True
    Lit(a, v) => Lit(a, !v)
    And(xs) => Or(xs.map(negate))
    Or(xs) => And(xs.map(negate))
  }
}

///|
pub fn not_(f : T) -> T {
  { node: negate(f.node), }
}

///|
/// Conjunction, with the constant folding that keeps formulas small.
pub fn and_(a : T, b : T) -> T {
  match (a.node, b.node) {
    (False, _) | (_, False) => false_
    (True, _) => b
    (_, True) => a
    _ => { node: And([a.node, b.node]), }
  }
}

///|
pub fn or_(a : T, b : T) -> T {
  match (a.node, b.node) {
    (True, _) | (_, True) => true_
    (False, _) => b
    (_, False) => a
    _ => { node: Or([a.node, b.node]), }
  }
}

///|
fn and_list(l : Array[T]) -> T {
  l.fold(init=true_, (acc, f) => and_(acc, f))
}

///|
fn or_list(l : Array[T]) -> T {
  l.fold(init=false_, (acc, f) => or_(acc, f))
}

///|
/// `a` and `b` agree.
fn iff(a : T, b : T) -> T {
  or_(and_(a, b), and_(not_(a), not_(b)))
}

///|
/// `a` and `b` disagree.
fn xor(a : T, b : T) -> T {
  not_(iff(a, b))
}
