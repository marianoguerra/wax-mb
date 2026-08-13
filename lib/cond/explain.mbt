// Rendering an assumption that makes a formula reachable, for diagnostics.

///|
/// Which surface syntax to render in.
///
/// The two spell conditions differently: WAT uses `$`-prefixed variables,
/// dotted versions and `<>`; Wax uses bare names, version tuples and `!=`.
pub(all) enum Style {
  Wat
  Wax
} derive(Eq, Debug)

///|
fn Env::render_atom(
  self : Env,
  style : Style,
  atom : Atom,
  value : Bool,
) -> String {
  let prefix = match style {
    Wat => "$"
    Wax => ""
  }
  let name = id => self.names.get(id).unwrap_or("?")
  match atom {
    Bool(v) => if value { prefix + name(v) } else { "not " + prefix + name(v) }
    Bound(v, limit, inclusive) => {
      let op = match (inclusive, value) {
        (true, true) => "<="
        (true, false) => ">"
        (false, true) => "<"
        (false, false) => ">="
      }
      let ver = match style {
        Wat => limit.to_string()
        Wax => "(\{limit.major}, \{limit.minor}, \{limit.patch})"
      }
      "\{prefix}\{name(v)} \{op} \{ver}"
    }
    Const(v, s) => {
      let op = match (value, style) {
        (true, _) => "="
        (false, Wat) => "<>"
        (false, Wax) => "!="
      }
      // Condition strings are UTF-8, as the format specifies; a lossy decode
      // keeps a malformed one renderable rather than failing a diagnostic.
      let text = @utf8.decode_lossy(s[:])
      "\{prefix}\{name(v)} \{op} \"\{text}\""
    }
  }
}

///|
/// A minimal assumption under which the formula holds -- e.g.
/// `$oxcaml and not $debug`.
///
/// `None` when the formula is a tautology (always reachable, so there is
/// nothing to assume) or unsatisfiable (no assumption would do).
///
/// The reference asks its BDD for a shortest satisfying cube. Here a satisfying
/// assignment is found first and then minimized greedily: a literal whose
/// removal still leaves the remaining conjunction entailing the formula was not
/// carrying its weight. Greedy gives a minimal cube, not necessarily the
/// globally shortest one -- for a handful of atoms the two coincide, and this
/// is diagnostic text rather than a decision.
pub fn Env::explain(self : Env, f : T, style? : Style = Wat) -> String? {
  if !is_satisfiable(f) {
    return None
  }
  if logical_implies(true_, f) {
    // A tautology: reachable under any assumption.
    return None
  }
  guard solve(f) is Some(assign) else { return None }
  let lits : Array[(Atom, Bool)] = []
  for entry in assign {
    lits.push(entry)
  }
  // Drop any literal the rest does not need.
  let kept : Array[(Atom, Bool)] = []
  for i in 0..<lits.length() {
    let candidate : Array[(Atom, Bool)] = []
    for j in 0..<lits.length() {
      if j != i && !kept.contains(lits[j]) {
        candidate.push(lits[j])
      }
    }
    for k in kept {
      candidate.push(k)
    }
    if !logical_implies(cube(candidate), f) {
      kept.push(lits[i])
    }
  }
  if kept.is_empty() {
    return None
  }
  let parts = kept.map(l => {
    let (atom, value) = l
    self.render_atom(style, atom, value)
  })
  Some(parts.join(" and "))
}

///|
/// The conjunction of a set of literals.
fn cube(lits : Array[(Atom, Bool)]) -> T {
  let mut f = true_
  for l in lits {
    let (atom, value) = l
    f = and_(f, { node: Lit(atom, value) })
  }
  f
}
