// Name resolution under conditional compilation.
//
// Every declaration carries the assumption it was declared under, and every
// lookup happens under a current assumption. Two declarations of one name are a
// conflict only when their assumptions can hold together -- which is why these
// are not plain name-keyed tables and why `cond` is threaded through them.
//
// When a module has no `#[if]` in it the assumption stays `true_` throughout,
// every conjunction is trivially satisfiable, and these behave exactly like the
// plain tables they would otherwise be.

///|
/// Where a name resolution is being made FROM, for the reachability analysis
/// behind the unused-field lint.
///
/// The distinction that motivates it: two functions that only call each other
/// reference one another, yet neither ever runs. So the lint cannot ask merely
/// whether a declaration is referenced -- it has to ask whether anything that
/// can actually run references it, and that needs to know where each reference
/// came from.
pub(all) enum Origin {
  /// Module level -- an initializer, a segment, an import -- which runs
  /// whatever the bodies do.
  Root
  FromFunction(String)
  /// A type definition's own components.
  FromType(String)
  /// Not a source reference at all: the pass that re-checks every type
  /// definition, whose lookups should not mark anything used.
  Ignored
} derive(Eq, Debug)

///|
/// One declaration of a name: what it is called internally, where it was
/// declared, and the assumption it was declared under.
pub(all) struct Declaration {
  name : String
  loc : @basic.Location
  cond : @cond.T
}

///|
/// The shared name space: the current assumption, the declarations, and where
/// references are recorded.
///
/// The assumption is a `Ref` shared by every name space and table of one
/// module's checking, and updated as the passes descend into `#[if]` and
/// `#[else]` branches -- so a lookup anywhere sees the branch it is in without
/// the branch being threaded through every call.
pub struct Namespace {
  cond : Ref[@cond.T]
  entries : Map[String, Array[Declaration]]
  /// Shared across the namespaces of one module; `None` disables recording.
  links : ResolveSink
}

///|
pub fn Namespace::new(
  cond : Ref[@cond.T],
  links? : ResolveSink = None,
) -> Namespace {
  { cond, entries: Map([]), links }
}

///|
/// A table of values keyed by name, each entry carrying the assumption it was
/// declared under.
pub struct Tbl[A] {
  /// What this table holds, for the diagnostic that says a name is unbound.
  kind : String
  names : Namespace
  entries : Map[String, Array[(@cond.T, A)]]
  /// Names looked up through this table, each paired with where the lookup was
  /// made from. One entry per distinct name and origin pair; the unused-field
  /// lint reads it.
  used : Map[String, Array[Origin]]
  /// Where references are currently being made from. Shared by every table of
  /// one module context, so a resolution can be attributed without the context
  /// being threaded into the table.
  current : Ref[Origin]
  /// A summary of a resolved value, attached to the recorded reference, for a
  /// hover on a name that is not an expression. Returning `None` leaves the
  /// reference hover-less.
  hover : (A) -> HoverTarget?
}

///|
pub fn[A] Tbl::new(
  kind : String,
  names : Namespace,
  current : Ref[Origin],
  hover? : (A) -> HoverTarget? = _ => None,
) -> Tbl[A] {
  { kind, names, entries: Map([]), used: Map([]), current, hover }
}

///|
/// Declare a name under the current assumption.
pub fn[A] Tbl::add(
  self : Tbl[A],
  name : String,
  loc : @basic.Location,
  value : A,
) -> Unit {
  let cond = self.names.cond.val
  match self.names.entries.get(name) {
    Some(l) => l.push({ name, loc, cond })
    None => self.names.entries[name] = [{ name, loc, cond }]
  }
  match self.entries.get(name) {
    Some(l) => l.push((cond, value))
    None => self.entries[name] = [(cond, value)]
  }
}

///|
/// Every declaration of this name whose assumption can hold together with the
/// current one.
///
/// Not the ones that IMPLY it: a declaration guarded by a weaker condition is
/// still in scope here. Only a declaration whose assumption is inconsistent
/// with the current one is invisible.
pub fn[A] Tbl::visible(self : Tbl[A], name : String) -> Array[A] {
  let here = self.names.cond.val
  match self.entries.get(name) {
    None => []
    Some(l) =>
      l.filter(e => @cond.is_satisfiable(@cond.and_(here, e.0))).map(e => e.1)
  }
}

///|
/// Look up a name, recording the reference and marking it used.
///
/// Prefers a declaration whose assumption the current one ENTAILS -- that is
/// the branch actually being checked -- and falls back to any declaration
/// merely consistent with it, which is what keeps a name declared in a sibling
/// branch from reading as unbound.
pub fn[A] Tbl::resolve(
  self : Tbl[A],
  name : String,
  use_ : @basic.Location,
) -> A? {
  let here = self.names.cond.val
  guard self.entries.get(name) is Some(l) else { return None }
  self.mark_used(name)
  let entailed = l.filter(e => @cond.logical_implies(here, e.0))
  let candidates = if !entailed.is_empty() {
    entailed
  } else {
    l.filter(e => @cond.is_satisfiable(@cond.and_(here, e.0)))
  }
  guard !candidates.is_empty() else { return None }
  let value = candidates[0].1
  let definitions = match self.names.entries.get(name) {
    None => []
    Some(decls) =>
      decls
      .filter(d => @cond.is_satisfiable(@cond.and_(here, d.cond)))
      .map(d => d.loc)
  }
  record_reference(
    self.names.links,
    use_,
    definitions,
    hover=(self.hover)(value),
  )
  Some(value)
}

///|
/// Note that a name was looked up, and from where.
fn[A] Tbl::mark_used(self : Tbl[A], name : String) -> Unit {
  let origin = self.current.val
  if origin is Ignored {
    return
  }
  match self.used.get(name) {
    Some(l) => if !l.contains(origin) { l.push(origin) }
    None => self.used[name] = [origin]
  }
}

///|
/// Where this name was referenced from, if anywhere.
pub fn[A] Tbl::referrers(self : Tbl[A], name : String) -> Array[Origin] {
  self.used.get(name).unwrap_or([])
}

///|
/// Every name referenced through this table, with its origins.
pub fn[A] Tbl::iter_references(self : Tbl[A]) -> Array[(String, Array[Origin])] {
  let out : Array[(String, Array[Origin])] = []
  for name, origins in self.used {
    out.push((name, origins))
  }
  out.sort_by((a, b) => if a.0 < b.0 { -1 } else if a.0 > b.0 { 1 } else { 0 })
  out
}

///|
/// Every name declared in this table, for the "did you mean" suggestions.
///
/// All of them, not only the ones visible under the current assumption: a name
/// declared in another `#[if]` branch is still a plausible thing the author
/// meant to write, and suggesting it is more useful than staying silent.
pub fn[A] Tbl::names(self : Tbl[A]) -> Array[String] {
  let out : Array[String] = []
  for name, _ in self.entries {
    out.push(name)
  }
  out.sort()
  out
}
