// The human renderer: a headed message, then a source snippet with carets.

///|
/// Lay out a headed diagnostic.
///
/// The styled header is emitted at its PLAIN text's width -- the colour is
/// zero-width -- then a soft break, then the body. A body that fits joins the
/// header on one line; anything wider, or containing a hard break, puts the
/// header on its own line with the body under a 2-column hanging indent.
fn headed(
  sink : Sink,
  header_plain : String,
  header_styled : String,
  body : (@printer.Printer) -> Unit,
) -> Unit {
  let rendered = @printer.run_string(p => {
    p.hvbox(indent=2, () => {
      p.string_as(header_plain.length(), header_styled)
      p.space()
      body(p)
    })
  })
  for l in rendered.split("\n") {
    line(sink, l.to_owned())
  }
}

///|
fn render_body(
  p : @printer.Printer,
  theme : Theme,
  m : @message.Message,
) -> Unit {
  @message.render(p, theme.body, m)
}

///|
fn print_hint(sink : Sink, theme : Theme, hint : @message.Message?) -> Unit {
  match hint {
    None => ()
    Some(m) =>
      headed(sink, "Hint:", with_style(theme.hint_header, "Hint") + ":", p => {
        render_body(p, theme, m)
      })
  }
}

///|
/// Render a machine-applicable edit as a "Help:" line, in prose.
///
/// Shown only for an UNNAMED error -- that is, a syntax error, which says what
/// is wrong rather than how to repair it, so spelling out the derived fix is
/// worth a line. A warning or suggestion carrying an edit already states its
/// fix in its own message, so repeating the raw text there would be redundant;
/// that is why the guard checks for the absence of a warning name and not just
/// the severity, since `-W name=error` promotes a warning to Error while it
/// keeps its name. The machine-readable form travels in JSON regardless.
fn print_fix(
  sink : Sink,
  theme : Theme,
  severity : Severity,
  warning : @warning.Warning?,
  edit : Edit?,
) -> Unit {
  match (severity, warning, edit) {
    (Error, None, Some(e)) => {
      let action = if e.loc.start.cnum == e.loc.end.cnum {
        "insert '\{e.new_text}'"
      } else if e.new_text == "" {
        "remove this"
      } else {
        "replace with '\{e.new_text}'"
      }
      headed(sink, "Help:", with_style(theme.hint_header, "Help") + ":", p => {
        p.string(action)
      })
    }
    _ => ()
  }
}

///|
/// The header line and body, with no source snippet.
fn output_no_loc(
  sink : Sink,
  theme : Theme,
  severity : Severity,
  warning : @warning.Warning?,
  hint : @message.Message?,
  msg : @message.Message,
) -> Unit {
  // A named warning's name is appended as ` [name]`, including one promoted to
  // Error severity by `-W name=error` -- which still carries its name.
  let name_suffix = match warning {
    Some(w) => " [" + w.name() + "]"
    None => ""
  }
  let (word, color) = match severity {
    Error => ("Error", theme.error_header)
    Warning => ("Warning", theme.warning_header)
    Suggestion => ("Suggestion", theme.hint_header)
  }
  headed(
    sink,
    word + name_suffix + ":",
    with_style(color, word) + name_suffix + ":",
    p => render_body(p, theme, msg),
  )
  print_hint(sink, theme, hint)
}

///|
/// A located diagnostic when the source text is not available.
fn output_no_source(sink : Sink, theme : Theme, d : Diagnostic) -> Unit {
  let s = d.loc.start
  let e = d.loc.end
  if s.lnum == e.lnum {
    line(
      sink,
      "File \"\{s.fname}\", line \{s.lnum}, characters \{s.column0()}-\{e.column0()}:",
    )
  } else {
    line(
      sink,
      "File \"\{s.fname}\", line \{s.lnum}, character \{s.column0()} to line \{e.lnum}, character \{e.column0()}:",
    )
  }
  output_no_loc(sink, theme, d.severity, d.warning, d.hint, d.message)
}
