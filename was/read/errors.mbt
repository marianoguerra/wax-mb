// Diagnostics, on `marianoguerra/error-report` so that a was error and a
// shrubbery error render through the same code.

///|
/// A was read error, carrying a ready-to-render report.
pub(all) suberror ReadError {
  ReadError(@er.Report)
}

///|
/// The report inside a parse error.
pub fn ReadError::report(self : Self) -> @er.Report {
  let ReadError(r) = self
  r
}

///|
/// Fail at a span, with a message.
pub fn[T] fail_at(
  msg : String,
  span : Span,
  source~ : @er.SourceId,
  help? : String,
) -> T raise ReadError {
  let mut report = @er.Report::error(msg).with_label(
    @er.Label::primary(source, span),
  )
  match help {
    Some(h) => report = report.with_help(h)
    None => ()
  }
  raise ReadError(report)
}
