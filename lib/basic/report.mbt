///|
/// How serious a diagnostic is. Mirrors the reference's `Diagnostic.severity`.
///
/// `Suggestion` is never produced by the front end — it belongs to the type
/// checker's machine-applicable fixes — but it is declared here so the
/// diagnostic renderers can be written once, against the complete set.
pub(all) enum Severity {
  Error
  Warning
  Suggestion
} derive(Eq, Debug)

///|
/// The word the reference's human renderer prints as a diagnostic header.
pub fn Severity::header(self : Severity) -> String {
  match self {
    Error => "Error"
    Warning => "Warning"
    Suggestion => "Suggestion"
  }
}

///|
/// The string the reference's JSON and short renderers use.
pub fn Severity::to_str(self : Severity) -> String {
  match self {
    Error => "error"
    Warning => "warning"
    Suggestion => "suggestion"
  }
}

///|
/// A machine-applicable rewrite: replace the source spanned by `loc` with
/// `new_text`. An empty span denotes an insertion. Mirrors `Diagnostic.edit`.
pub(all) struct Edit {
  loc : Location
  new_text : String
} derive(Eq, Debug)

///|
/// A secondary span attached to a diagnostic, e.g. "This '(' opens the
/// enclosing construct." Mirrors `Diagnostic.label`.
pub(all) struct Label {
  loc : Location
  message : String
} derive(Eq, Debug)

///|
/// A diagnostic, in the accumulate-don't-raise style `moonbitlang/parser` uses.
///
/// `message` is a plain `String` here rather than the reference's structured
/// `Message.t`. That is deliberate for now: the front end only needs to render,
/// not to restyle. When the type checker lands it will want the combinator form
/// (so types can be coloured inside a sentence), at which point this field
/// becomes a `Message` — every other field stays as-is.
pub(all) struct Report {
  loc : Location
  severity : Severity
  message : String
  /// The `-W` name, for a named warning; `None` for everything else.
  warning : String?
  hint : String?
  edit : Edit?
  related : Array[Label]
} derive(Eq, Debug)

///|
/// An error `Report` with no warning name, hint, edit or related labels — the
/// shape every syntax and lexical error takes.
pub fn Report::error(loc : Location, message : String) -> Report {
  {
    loc,
    severity: Error,
    message,
    warning: None,
    hint: None,
    edit: None,
    related: [],
  }
}
