// The one-line renderer, for editors with a line-based error parser.

///|
/// Flatten a message onto one physical line.
fn one_line(m : @message.Message) -> String {
  let s = @message.to_plain_string(m)
  let out = StringBuilder::new()
  for c in s {
    out.write_char(if c == '\n' { ' ' } else { c })
  }
  out.to_string().trim().to_owned()
}

///|
/// Emit one `file:line:col: severity: message [name]` line, gcc/rustc style.
///
/// The column is 1-BASED here, matching the human format's location line and
/// against the JSON format's 0-based one. A named warning's name is appended in
/// brackets, as clang and eslint do.
fn output_short(sink : Sink, d : Diagnostic) -> Unit {
  let suffix = match d.warning {
    Some(w) => " [" + w.name() + "]"
    None => ""
  }
  let sev = d.severity.to_str()
  let p = d.loc.start
  if p.is_dummy() {
    line(sink, "\{sev}: \{one_line(d.message)}\{suffix}")
  } else {
    line(
      sink,
      "\{p.fname}:\{p.lnum}:\{p.column1()}: \{sev}: \{one_line(d.message)}\{suffix}",
    )
  }
}
