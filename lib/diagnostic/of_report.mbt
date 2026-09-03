// The bridge from a front-end report to a renderable diagnostic.

///|
/// Turn a lexer or parser report into a diagnostic.
///
/// The front end produces plain strings; a diagnostic body is a `Message`, and
/// `text` is the right constructor for these: they are prose, and prose is what
/// reflows to the terminal width.
///
/// The `warning` field comes back `None` however the report named itself: the
/// front end names no warnings, because every report it makes is unconditional
/// and there is nothing for a `-W` to switch off.
pub fn of_report(r : @basic.Report) -> Diagnostic {
  {
    loc: r.loc,
    severity: match r.severity {
      Error => Error
      Warning => Warning
      Suggestion => Suggestion
    },
    warning: None,
    message: @message.text(r.message),
    hint: r.hint.map(h => @message.text(h)),
    edit: r.edit.map(e => ({ loc: e.loc, new_text: e.new_text, } : Edit)),
    related: r.related.map(l => {
      ({ loc: l.loc, message: @message.text(l.message), } : Label)
    }),
    universal: false,
  }
}
