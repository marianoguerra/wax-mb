// The diagnostic value, its theme, and where rendered output goes.

///|
pub(all) enum Severity {
  Error
  Warning
  Suggestion
} derive(Eq, Debug)

///|
pub fn Severity::to_str(self : Severity) -> String {
  match self {
    Error => "error"
    Warning => "warning"
    Suggestion => "suggestion"
  }
}

///|
/// The capitalised word heading a human-format diagnostic.
pub fn Severity::header(self : Severity) -> String {
  match self {
    Error => "Error"
    Warning => "Warning"
    Suggestion => "Suggestion"
  }
}

///|
/// A secondary span with its own note, rendered under the snippet.
pub(all) struct Label {
  loc : @basic.Location
  message : @message.Message
}

///|
/// A machine-applicable rewrite: replace the source spanned by `loc` with
/// `new_text`. The diagnostic's own message doubles as the quick-fix title.
pub(all) struct Edit {
  loc : @basic.Location
  new_text : String
}

///|
/// One diagnostic.
pub(all) struct Diagnostic {
  loc : @basic.Location
  severity : Severity
  /// The named warning this came from, so the policy can be applied when it is
  /// finally reported.
  warning : @warning.Warning?
  message : @message.Message
  hint : @message.Message?
  edit : Edit?
  related : Array[Label]
  /// Reported during path-sensitive exploration only if it holds in EVERY
  /// reachable configuration. The unused-local warning is universal: a local
  /// used in one branch is not unused merely because another configuration
  /// prunes that branch.
  universal : Bool
}

///|
/// How diagnostics are rendered.
pub(all) enum OutputFormat {
  /// Source snippets. The default.
  Human
  /// One JSON object per diagnostic per line.
  Json
  /// One `file:line:col: severity: message` line, gcc/rustc style, for editors
  /// with a line-based error parser.
  Short
} derive(Eq, Debug)

///|
/// The colours of the diagnostic frame.
pub(all) struct Theme {
  error_header : String
  warning_header : String
  hint_header : String
  error_label : String
  warning_label : String
  secondary_label : String
  line_numbers : String
  /// The palette for atoms embedded in a message body. Coloured or not in
  /// lockstep with the frame above -- both come from the one colour flag.
  body : @colors.Theme
}

///|
pub fn get_theme(
  color? : @colors.Flag = Auto,
  palette? : @colors.Theme = @colors.wax_theme,
  is_tty? : Bool = false,
) -> Theme {
  let use_color = @colors.should_use_color(color, is_tty~)
  let body = if use_color { palette } else { @colors.no_color }
  if use_color {
    {
      error_header: @colors.bold + @colors.high_red,
      warning_header: @colors.bold + @colors.high_yellow,
      hint_header: @colors.bold + @colors.cyan,
      error_label: @colors.red,
      warning_label: @colors.yellow,
      secondary_label: @colors.bold + @colors.blue,
      line_numbers: @colors.cyan,
      body,
    }
  } else {
    {
      error_header: "",
      warning_header: "",
      hint_header: "",
      error_label: "",
      warning_label: "",
      secondary_label: "",
      line_numbers: "",
      body,
    }
  }
}

///|
/// A destination for rendered diagnostics.
///
/// An indirection rather than a hard-wired stderr, because two consumers need
/// to capture: the differential harness, and the renderer's own tests.
pub(all) struct Sink {
  write : (String) -> Unit
  flush : () -> Unit
}

///|
/// A sink collecting into a growable buffer. Its flush does nothing.
pub fn buffer_sink(buf : StringBuilder) -> Sink {
  { write: s => buf.write_string(s), flush: () => (), }
}

///|
/// Emit one physical line and flush.
///
/// Flushing per LINE, not per diagnostic: it keeps stdout/stderr interleaving
/// deterministic when a cram test or a parent process captures both.
fn line(sink : Sink, s : String) -> Unit {
  (sink.write)(s + "\n")
  (sink.flush)()
}

///|
/// Wrap `s` in `color`'s escape, or return it unchanged when uncoloured.
///
/// Pure string composition: a header's colour contributes no display width,
/// since every alignment here is computed from the plain text.
fn with_style(color : String, s : String) -> String {
  if color == "" {
    s
  } else {
    color + s + @colors.reset
  }
}
