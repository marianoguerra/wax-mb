// The pipeline from an AST to wasm, as one object.
//
// The three stages the compiler runs -- check, lower, encode -- share four
// pieces of state: a type store the checker fills and the lowering reads, a
// feature set both consult, a diagnostic context that collects what they
// complain about, and the source text a diagnostic renders a snippet from.
// Threading those by hand is where an embedder gets it wrong; passing a fresh
// `TypeStore` to `lower_module` after checking with another one type-checks and
// produces a module whose type indices mean nothing.
//
// This lived in the CLI until it was the only copy. Now the CLI and any other
// consumer run the same code, which is the point: the pipeline is the library's
// API, not a recipe to be reproduced.

///|
/// One compilation.
///
/// A session is single-use per module. The type store it carries is filled by
/// checking, so checking a second module through the same session would build
/// on the first module's type section.
pub struct Session {
  /// The recursive-type store, filled by the checker and read by the lowering.
  store : @type_store.TypeStore
  /// Which post-MVP proposals this compilation is allowed to use.
  features : @feature.Set
  /// Everything the checker complained about, raw -- warnings are collected
  /// whether or not a policy would show them. See `reports`.
  diagnostics : @diagnostic.Context
}

///|
/// Start a compilation.
///
/// `source` is the module's text, used only to render snippets in diagnostics.
/// A generator that has no text to point at leaves it out; the diagnostics then
/// carry their locations and their messages and no excerpt.
pub fn Session::new(features? : @feature.Set, source? : String) -> Session {
  {
    store: @type_store.TypeStore::new(),
    features: match features {
      Some(f) => f
      None => @feature.default()
    },
    diagnostics: @diagnostic.collector(source~),
  }
}

///|
/// Type-check a module.
///
/// This ALWAYS returns a `Checked`, even for a module it rejected, because
/// whether a run is rejected is not decided here: a warning is hidden, shown or
/// promoted to an error by a `@warning.Policy` the caller owns. Ask `reports`
/// for the diagnostics under that policy and `rejected` whether they stop the
/// compilation, and only then lower.
///
/// `warn_unused` turns on the lints that report what a module declares and never
/// uses. It is off by default because a conversion reports what stops it
/// producing a module and a style warning does not -- the reference draws the
/// same line, and `wax f.wax -f wasm` is silent on a module `wax check`
/// comments on.
pub fn Session::check(
  self : Session,
  module_ : @ast.LocModule,
  warn_unused? : Bool,
  simplify? : Bool,
) -> Checked {
  let (context, typed) = @typing.check_module(
    self.diagnostics,
    self.store,
    self.features,
    module_,
    simplify?,
    warn_unused?,
  )
  { session: self, context, source_module: module_, typed }
}

///|
/// What the compilation reported, under `policy`.
///
/// Without a policy this is the raw collection, warnings and all. With one, a
/// hidden warning is dropped and a promoted one comes back with severity
/// `Error` -- which is what makes `-W name=error` mean something, and why a lint
/// that is off by default costs nothing to have implemented.
pub fn Session::reports(
  self : Session,
  policy? : @warning.Policy,
) -> Array[@diagnostic.Diagnostic] {
  let collected = self.diagnostics.collected()
  match policy {
    None => collected
    Some(p) => apply_policy(p, collected)
  }
}

///|
/// Resolve every named warning in `collected` against `policy`.
///
/// The collector buffers diagnostics RAW: the policy belongs to whoever finally
/// re-reports them. Order is preserved, hidden warnings are dropped, and a
/// warning promoted to an error comes back with its severity replaced rather
/// than duplicated.
pub fn apply_policy(
  policy : @warning.Policy,
  collected : Array[@diagnostic.Diagnostic],
) -> Array[@diagnostic.Diagnostic] {
  let out = []
  for d in collected {
    let severity = match (d.severity, d.warning) {
      (Warning, Some(w)) | (Suggestion, Some(w)) =>
        match policy.resolve(w) {
          Hidden => None
          Displayed => Some(d.severity)
          ErrorLevel => Some(@diagnostic.Severity::Error)
        }
      _ => Some(d.severity)
    }
    guard severity is Some(severity) else { continue }
    out.push({ ..d, severity, })
  }
  out
}

///|
/// Whether any of these diagnostics rejects the module.
///
/// Apply the policy first: a warning promoted to an error rejects, and one
/// hidden by the policy does not.
pub fn rejected(diagnostics : Array[@diagnostic.Diagnostic]) -> Bool {
  for d in diagnostics {
    if d.severity is Error {
      return true
    }
  }
  false
}
