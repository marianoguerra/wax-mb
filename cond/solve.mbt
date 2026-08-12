// The decision procedure.
//
// DPLL over the atoms, with a theory check on the assignment. Since no atom
// relates two variables, theory consistency decomposes per variable, and each
// variable's check is a few comparisons.

///|
/// Every distinct atom in a formula, in first-seen order.
fn collect_atoms(n : Node, out : Array[Atom], seen : Map[Atom, Unit]) -> Unit {
  match n {
    True | False => ()
    Lit(a, _) =>
      if !seen.contains(a) {
        seen[a] = ()
        out.push(a)
      }
    And(xs) | Or(xs) =>
      for x in xs {
        collect_atoms(x, out, seen)
      }
  }
}

///|
/// Three-valued evaluation under a partial assignment, so the search can prune
/// a branch before every atom is decided.
///
/// `None` means "not yet determined".
fn eval(n : Node, assign : Map[Atom, Bool]) -> Bool? {
  match n {
    True => Some(true)
    False => Some(false)
    Lit(a, want) =>
      match assign.get(a) {
        None => None
        Some(v) => Some(v == want)
      }
    And(xs) => {
      let mut unknown = false
      for x in xs {
        match eval(x, assign) {
          Some(false) => return Some(false)
          Some(true) => ()
          None => unknown = true
        }
      }
      if unknown {
        None
      } else {
        Some(true)
      }
    }
    Or(xs) => {
      let mut unknown = false
      for x in xs {
        match eval(x, assign) {
          Some(true) => return Some(true)
          Some(false) => ()
          None => unknown = true
        }
      }
      if unknown {
        None
      } else {
        Some(false)
      }
    }
  }
}

///|
/// Is this assignment consistent with the theories?
///
/// Per variable, because no atom relates two variables:
///
///   * a boolean variable constrains nothing -- the atom IS the variable;
///   * a version variable accumulates an interval, and is consistent while the
///     interval is non-empty. The order is treated as DENSE, which is what a
///     total-order theory over an arbitrary compared type must do: it cannot
///     know that `(1,0,0)` has a successor, and neither does the reference's;
///   * a string variable may be equal to at most one constant, and not to a
///     constant it is also required to differ from.
fn theory_consistent(assign : Map[Atom, Bool]) -> Bool {
  // Version variables: the tightest bounds seen so far.
  let upper : Map[Int, (Version, Bool)] = Map([])
  let lower : Map[Int, (Version, Bool)] = Map([])
  // String variables: what they must and must not equal.
  let eq : Map[Int, Bytes] = Map([])
  let ne : Map[Int, Array[Bytes]] = Map([])
  for entry in assign {
    let (atom, value) = entry
    match atom {
      Bool(_) => ()
      Bound(vid, limit, inclusive) =>
        if value {
          // vid <= limit, or vid < limit
          let tighter = match upper.get(vid) {
            None => true
            Some((cur, cur_inc)) => {
              let c = limit.compare_to(cur)
              c < 0 || (c == 0 && cur_inc && !inclusive)
            }
          }
          if tighter {
            upper[vid] = (limit, inclusive)
          }
        } else {
          // not (vid <= limit) is vid > limit; not (vid < limit) is vid >= limit
          let strict = inclusive
          let tighter = match lower.get(vid) {
            None => true
            Some((cur, cur_strict)) => {
              let c = limit.compare_to(cur)
              c > 0 || (c == 0 && !cur_strict && strict)
            }
          }
          if tighter {
            lower[vid] = (limit, strict)
          }
        }
      Const(vid, s) =>
        if value {
          match eq.get(vid) {
            Some(existing) => if existing != s { return false }
            None => eq[vid] = s
          }
        } else {
          match ne.get(vid) {
            Some(l) => l.push(s)
            None => ne[vid] = [s]
          }
        }
    }
  }
  // A version variable's interval must be non-empty.
  for vid, hi in upper {
    if lower.get(vid) is Some((lo, lo_strict)) {
      let (hi_v, hi_inclusive) = hi
      let c = lo.compare_to(hi_v)
      if c > 0 {
        return false
      }
      // Equal endpoints leave only the point itself, and only when both sides
      // admit it.
      if c == 0 && (lo_strict || !hi_inclusive) {
        return false
      }
    }
  }
  // A string variable cannot equal what it must differ from.
  for vid, s in eq {
    if ne.get(vid) is Some(l) && l.contains(s) {
      return false
    }
  }
  true
}

///|
/// Search for a satisfying assignment, returning it.
///
/// Straight DPLL: pick the next undecided atom, try it both ways, prune as soon
/// as the formula evaluates false or the assignment becomes theory-inconsistent.
/// Wax conditions run to a handful of atoms, so nothing cleverer earns its
/// keep -- and the pruning is what keeps a formula with many independent
/// variables from being enumerated.
fn search(
  node : Node,
  atoms : Array[Atom],
  i : Int,
  assign : Map[Atom, Bool],
) -> Map[Atom, Bool]? {
  match eval(node, assign) {
    Some(false) => return None
    Some(true) => if theory_consistent(assign) { return Some(assign) }
    None => ()
  }
  if i >= atoms.length() {
    // Every atom decided; `eval` is no longer None, so this is the false case.
    return None
  }
  let atom = atoms[i]
  for value in [true, false] {
    assign[atom] = value
    if theory_consistent(assign) {
      if search(node, atoms, i + 1, assign) is Some(found) {
        return Some(found)
      }
    }
    assign.remove(atom)
  }
  None
}

///|
fn solve(f : T) -> Map[Atom, Bool]? {
  match f.node {
    True => Some(Map([]))
    False => None
    _ => {
      let atoms : Array[Atom] = []
      collect_atoms(f.node, atoms, Map([]))
      search(f.node, atoms, 0, Map([]))
    }
  }
}

///|
/// Does the formula have a satisfying assignment?
///
/// Theory-aware, so contradictory version bounds are unsatisfiable rather than
/// merely unlikely.
pub fn is_satisfiable(f : T) -> Bool {
  solve(f) is Some(_)
}

///|
/// Does `a` entail `b`?
pub fn logical_implies(a : T, b : T) -> Bool {
  !is_satisfiable(and_(a, not_(b)))
}

///|
/// Are the two formulas equivalent?
///
/// Semantic, matching the reference, where equality is BDD identity and BDDs
/// are canonical. Here it is two satisfiability queries instead.
pub fn equal(a : T, b : T) -> Bool {
  !is_satisfiable(xor(a, b))
}

///|
/// A hash consistent with `equal`.
///
/// Semantically equal formulas must hash alike, and without a canonical form
/// there is nothing cheap to hash that respects that -- so this is a constant.
/// Correct, and degenerate: a hash table keyed on formulas degrades to a list.
/// Nothing in the checker keys on one; if something ever does, that is the
/// moment to canonicalize rather than to weaken this.
pub fn hash(_ : T) -> Int {
  0
}
