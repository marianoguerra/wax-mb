// The wax-mb entry point: convert, format, check.

///|
/// Bridge a front-end report into a renderable diagnostic.
///
/// The lexer and parser produce plain strings; a diagnostic body is a Message.
/// `text` is the right constructor: these are prose, and prose is what reflows.
fn diagnostic_of_report(r : @basic.Report) -> @diagnostic.Diagnostic {
  {
    loc: r.loc,
    severity: match r.severity {
      Error => Error
      Warning => Warning
      Suggestion => Suggestion
    },
    // The front end names no warnings: every report it makes is unconditional.
    warning: None,
    message: @message.text(r.message),
    hint: r.hint.map(h => @message.text(h)),
    edit: r.edit.map(e => {
      ({ loc: e.loc, new_text: e.new_text } : @diagnostic.Edit)
    }),
    related: r.related.map(l => {
      ({ loc: l.loc, message: @message.text(l.message) } : @diagnostic.Label)
    }),
    universal: false,
  }
}

///|
/// A sink writing to stderr, where every machine-readable format goes.
fn stderr_sink() -> @diagnostic.Sink {
  { write: s => @io.eprint(s), flush: () => () }
}

///|
/// Parse one file and render whatever it complains about.
///
/// Returns the module when it parsed. Diagnostics are rendered here rather
/// than returned, so each file reports as it is processed instead of the whole
/// run going quiet until the end.
fn process(
  path : String,
  src : String,
  opts : Options,
) -> (@ast.LocModule?, @trivia.Context, Bool) {
  // `--all-errors` swaps the parser for the recovering one, which reports every
  // syntax error it can resynchronize past instead of stopping at the first.
  // Only `check` offers it: a recovered tree is a guess, and printing a guess
  // back over the user's file is not a thing to do by accident.
  let r = if opts.all_errors && opts.command is Check {
    @grammar.parse_recover(src, fname=path)
  } else {
    @grammar.parse_string(src, fname=path)
  }
  let mut failed = false
  if r.errors.length() > 0 {
    // Colour is decided by the DESTINATION: diagnostics go to stderr, so it
    // is stderr's tty-ness that matters, not stdout's.
    let theme = @diagnostic.get_theme(
      color=opts.color,
      palette=@colors.wax_theme,
      is_tty=@io.stderr_is_tty(),
    )
    for e in r.errors {
      @diagnostic.output_error(
        stderr_sink(),
        theme,
        opts.error_format,
        Some(src),
        diagnostic_of_report(e),
      )
      if e.severity is Error {
        failed = true
      }
    }
  }
  (r.module_, r.trivia, failed)
}

///|
/// The formatted form of a parsed module.
///
/// Colour is decided by the OUTPUT destination, not the diagnostic stream: a
/// file redirect must never receive escape codes.
fn formatted(
  m : @ast.LocModule,
  trivia : @trivia.Context,
  opts : Options,
  to_terminal : Bool,
) -> String {
  // `to_terminal` is the destination's tty-ness, NOT stdout's: writing to a
  // file or to a pipe must never emit escape codes even when stdout is a
  // terminal.
  let theme = if @colors.should_use_color(opts.color, is_tty=to_terminal) {
    @colors.wax_theme
  } else {
    @colors.no_color
  }
  // `render` drops the trailing break; the reference ends its output with a
  // newline, so one is added here.
  @output.render(m, trivia, theme~) + "\n"
}

///|
fn run(argv : Array[String]) -> Status {
  let opts = match parse_args(argv) {
    Err((status, msg)) => {
      @io.eprintln("wax-mb: " + msg)
      return status
    }
    Ok(o) => o
  }
  if opts.files.is_empty() {
    @io.eprintln("wax-mb: no input file")
    return Usage
  }
  // Only the Wax front end exists, so anything else is a usage error rather
  // than a silent no-op that would make a differential comparison meaningless.
  if opts.input_format != "wax" {
    @io.eprintln(
      "wax-mb: input format '\{opts.input_format}' is not implemented (only 'wax')",
    )
    return Usage
  }
  if opts.command is Convert && opts.output_format != "wax" {
    @io.eprintln(
      "wax-mb: output format '\{opts.output_format}' is not implemented (only 'wax')",
    )
    return Usage
  }
  if opts.command is Convert && opts.files.length() > 1 {
    @io.eprintln("wax-mb: convert takes a single input file")
    return Usage
  }
  let mut rejected = false
  let mut needs_format = false
  for path in opts.files {
    let src = @fs.read_file_to_string(path) catch {
      _ => {
        @io.eprintln("wax-mb: cannot read \{path}")
        return Usage
      }
    }
    let (module_, trivia, failed) = process(path, src, opts)
    if failed {
      rejected = true
    }
    match (module_, opts.command) {
      (None, _) => ()
      (Some(_), Check) => ()
      (Some(m), Convert) =>
        match opts.output_path {
          // Writing to stdout, which may be a terminal.
          None => @io.print(formatted(m, trivia, opts, @io.stdout_is_tty()))
          Some(out) => {
            let text = formatted(m, trivia, opts, false)
            @fs.write_bytes_to_file(out, @utf8.encode(text)) catch {
              _ => {
                @io.eprintln("wax-mb: cannot write \{out}")
                return Usage
              }
            }
          }
        }
      (Some(m), Format) =>
        if opts.check_only {
          // A file already formatted is left alone and unreported; only the
          // ones that would change are listed.
          if formatted(m, trivia, opts, false) != src {
            @io.println(path)
            needs_format = true
          }
        } else if opts.inplace {
          let text = formatted(m, trivia, opts, false)
          if text != src {
            @fs.write_bytes_to_file(path, @utf8.encode(text)) catch {
              _ => {
                @io.eprintln("wax-mb: cannot write \{path}")
                return Usage
              }
            }
          }
        } else {
          // WITHOUT `-i`, format writes to stdout and leaves the file alone.
          // The opposite default would silently edit the user's files.
          @io.print(formatted(m, trivia, opts, @io.stdout_is_tty()))
        }
    }
  }
  if rejected {
    Rejected
  } else if needs_format {
    // `--check` found work to do: a usage-class status, not a rejected input.
    Usage
  } else {
    Ok
  }
}

///|
fn main {
  let argv = @env.args()
  // argv[0] is the program name.
  let args = if argv.length() > 1 { argv[1:].to_owned() } else { [] }
  let status = run(args)
  if status != Ok {
    @sys.exit(status.code())
  }
}
