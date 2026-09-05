// Diagnostics, on `marianoguerra/error-report` so that a wap error and a
// shrubbery error render through the same code.

///|
/// A wap parse error, carrying a ready-to-render report.
pub(all) suberror ParseError {
  ParseError(@er.Report)
}

///|
/// The report inside a parse error.
pub fn ParseError::report(self : Self) -> @er.Report {
  let ParseError(r) = self
  r
}

///|
/// Fail at a span, with a message.
pub fn[T] fail_at(
  msg : String,
  span : @wap.Span,
  source~ : @er.SourceId,
  help? : String,
) -> T raise ParseError {
  let mut report = @er.Report::error(msg).with_label(
    @er.Label::primary(source, span),
  )
  match help {
    Some(h) => report = report.with_help(h)
    None => ()
  }
  raise ParseError(report)
}
