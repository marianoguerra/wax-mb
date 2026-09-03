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
/// One declaration of a name: what kind of thing it declared, where, and under
/// what assumption.
///
/// `kind` is the declaring table's kind -- "function", "global", "memory" --
/// and not the name, which is the key this is stored under. It is here because
/// a clash reports what the name is already taken BY, and the two declarations
/// need not be of the same kind: memories and tables share one name space.
struct Declaration {
  kind : String
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
  { cond, entries: Map([]), links, }
}

///|
/// The declaration of `name` that this one would clash with, if any.
///
/// A clash needs both assumptions to be able to hold AT ONCE: two declarations
/// in mutually exclusive `#[if]` branches are not two declarations of anything,
/// since no configuration has both.
///
/// Searched newest first, so the one reported as "previously bound here" is the
/// nearest -- the one the reader most likely just wrote past.
fn Namespace::conflict(self : Namespace, name : String) -> Declaration? {
  let here = self.cond.val
  guard self.entries.get(name) is Some(l) else { return None }
  for i = l.length() - 1; i >= 0; i = i - 1 {
    if @cond.is_satisfiable(@cond.and_(here, l[i].cond)) {
      return Some(l[i])
    }
  }
  None
}

///|
/// Record a declaration, reporting a clash with an existing one.
///
/// The declaration is recorded EITHER WAY. Dropping it would leave every later
/// use of the name reading as unbound, turning one duplicate into a report per
/// use -- the same cascade the poison entries elsewhere exist to prevent.
fn Namespace::register(
  self : Namespace,
  diagnostics : @diagnostic.Context,
  kind : String,
  name : String,
  loc : @basic.Location,
) -> Unit {
  if self.conflict(name) is Some(prev) {
    name_already_bound(diagnostics, loc, prev.loc, prev.kind, name)
  }
  let entry = { kind, loc, cond: self.cond.val, }
  match self.entries.get(name) {
    Some(l) => l.push(entry)
    None => self.entries[name] = [entry]
  }
}

///|
/// Whether `name` is already taken here, reporting it if so.
///
/// The question and the report are one operation because every caller asks in
/// order to skip a second registration, and a caller that skipped silently
/// would drop the declaration without saying why.
pub fn Namespace::exists(
  self : Namespace,
  diagnostics : @diagnostic.Context,
  name : String,
  loc : @basic.Location,
) -> Bool {
  match self.conflict(name) {
    Some(prev) => {
      name_already_bound(diagnostics, loc, prev.loc, prev.kind, name)
      true
    }
    None => false
  }
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
  ///
  /// Mutable so a snapshot table can SHARE this one: a name resolved through
  /// the snapshot has been referenced, and the lint that asks reads the table
  /// the name was declared in.
  mut used : Map[String, Array[Origin]]
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
  { kind, names, entries: Map([]), used: Map([]), current, hover, }
}

///|
/// Copy this table's ENTRIES into another, without re-declaring anything.
///
/// A snapshot, not a second declaration: nothing is registered in the name
/// space, so no clash is reported and the entries keep their own conditions.
/// Re-adding them instead would say "already bound" for every name that is
/// visible under more than one configuration -- and there is nothing wrong with
/// those; that is what conditional compilation is for.
///
/// The record of what has been REFERENCED is shared, not copied. A snapshot is
/// a second view of the same declarations, so a name resolved through it is a
/// name that was used -- and the unused lint asks the table the name was
/// declared in, which is this one.
pub fn[A] Tbl::copy_entries_into(self : Tbl[A], dst : Tbl[A]) -> Unit {
  for name, l in self.entries {
    dst.entries[name] = l.copy()
  }
  dst.used = self.used
}

///|
/// Declare a name under the current assumption, reporting a clash.
///
/// Entries accumulate rather than replace, and the LAST is the most recent --
/// which is the one `resolve`, `override` and `remove` all mean by "the
/// current declaration".
pub fn[A] Tbl::add(
  self : Tbl[A],
  diagnostics : @diagnostic.Context,
  name : String,
  loc : @basic.Location,
  value : A,
) -> Unit {
  self.names.register(diagnostics, self.kind, name, loc)
  let cond = self.names.cond.val
  match self.entries.get(name) {
    Some(l) => l.push((cond, value))
    None => self.entries[name] = [(cond, value)]
  }
}

///|
/// Whether this name is already bound in the shared name space, reporting it.
pub fn[A] Tbl::exists(
  self : Tbl[A],
  diagnostics : @diagnostic.Context,
  name : String,
  loc : @basic.Location,
) -> Bool {
  self.names.exists(diagnostics, name, loc)
}

///|
/// Replace the value of the most recent declaration of `name`.
///
/// For the two-step registration a recursion group needs: its members are
/// declared with placeholder indices so that they can refer to each other, then
/// given their real ones once the group is interned. The name space is
/// untouched -- the declaration is the same one, only its value has settled.
pub fn[A] Tbl::override_(self : Tbl[A], name : String, value : A) -> Unit {
  let cond = self.names.cond.val
  match self.entries.get(name) {
    Some(l) if !l.is_empty() => l[l.length() - 1] = (cond, value)
    _ => self.entries[name] = [(cond, value)]
  }
}

///|
/// Drop the most recent declaration of `name`, keeping any older one.
///
/// The other half of the two-step registration: a group that fails to resolve
/// takes its placeholder names back out, so they do not resolve to a type that
/// was never interned.
///
/// The NAME SPACE keeps its entry, deliberately: the name was still written
/// here, so a second declaration of it is still a duplicate and still says so.
pub fn[A] Tbl::remove(self : Tbl[A], name : String) -> Unit {
  match self.entries.get(name) {
    Some(l) if l.length() > 1 => {
      let _ = l.pop()
    }
    Some(_) => self.entries.remove(name)
    None => ()
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
/// The declaration of `name` in force here, without recording anything.
///
/// Prefers one whose assumption the current one ENTAILS -- that is the branch
/// actually being checked -- then any merely consistent with it, which keeps a
/// name declared in a sibling branch from reading as unbound. Failing both it
/// takes the most recent, so a name that was written somewhere resolves to
/// something rather than to nothing.
///
/// Each search runs newest first: a later declaration shadows an earlier one.
fn[A] Tbl::select(self : Tbl[A], name : String) -> A? {
  let here = self.names.cond.val
  guard self.entries.get(name) is Some(l) else { return None }
  guard !l.is_empty() else { return None }
  fn pick(p : (@cond.T) -> Bool) -> A? {
    for i = l.length() - 1; i >= 0; i = i - 1 {
      if p(l[i].0) {
        return Some(l[i].1)
      }
    }
    None
  }

  match pick(c => @cond.logical_implies(here, c)) {
    Some(v) => Some(v)
    None =>
      match pick(c => @cond.is_satisfiable(@cond.and_(here, c))) {
        Some(v) => Some(v)
        None => Some(l[l.length() - 1].1)
      }
  }
}

///|
/// Look up a name for a use, marking it referenced and linking it to its
/// definitions.
///
/// Only ever called for a REFERENCE; a declaration goes through `add`. That is
/// what lets the mark be trusted by the unused-declaration lint.
pub fn[A] Tbl::resolve(
  self : Tbl[A],
  name : String,
  use_ : @basic.Location,
) -> A? {
  guard self.select(name) is Some(value) else { return None }
  self.mark_used(name)
  let here = self.names.cond.val
  // Every definition the name could mean here, newest first. Several only ever
  // across conditional branches, where the editor cannot pick between them and
  // offering both is the honest answer.
  let definitions : Array[@basic.Location] = []
  if self.names.entries.get(name) is Some(decls) {
    for i = decls.length() - 1; i >= 0; i = i - 1 {
      if @cond.is_satisfiable(@cond.and_(here, decls[i].cond)) {
        definitions.push(decls[i].loc)
      }
    }
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
/// Look up a name WITHOUT counting it as a reference.
///
/// For the checker's own internal lookups -- a function resolving its own
/// declared type while being checked -- which are not references anyone wrote.
/// Counting them would keep every declaration alive and silence the
/// unused-declaration lint entirely.
pub fn[A] Tbl::find_no_mark(self : Tbl[A], name : String) -> A? {
  self.select(name)
}

///|
/// Record a reference to `name` from `origin`, for a use that names no
/// declaration syntactically.
///
/// A string literal builds the canonical `mut i8` array without writing a type
/// name, yet every source definition that deduplicated onto that array really
/// is used by it.
pub fn[A] Tbl::mark_reference(
  self : Tbl[A],
  name : String,
  origin : Origin,
) -> Unit {
  if origin is Ignored {
    return
  }
  match self.used.get(name) {
    Some(l) => if !l.contains(origin) { l.push(origin) }
    None => self.used[name] = [origin]
  }
}

///|
/// Every declaration in this table, name and value, in no particular order.
pub fn[A] Tbl::iter_entries(self : Tbl[A]) -> Array[(String, A)] {
  let out : Array[(String, A)] = []
  for name, l in self.entries {
    for e in l {
      out.push((name, e.1))
    }
  }
  out
}

///|
/// Note that a name was looked up, and from where.
fn[A] Tbl::mark_used(self : Tbl[A], name : String) -> Unit {
  self.mark_reference(name, self.current.val)
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
