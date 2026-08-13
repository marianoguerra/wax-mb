// The wax-mb entry point: convert, format, check.
//
// What is HERE is everything that is about being a command-line tool: reading
// files, deciding whether a stream is a terminal, choosing a colour theme,
// picking an exit status. The compilation itself is `marianoguerra/wax` --
// `@wax.parse_string`, `@wax.Session`, `@wax.render` -- so that an embedder
// runs the same pipeline this binary does rather than a reconstruction of it.

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
    @wax.parse_recover(src, fname=path)
  } else {
    @wax.parse_string(src, fname=path)
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
        @diagnostic.of_report(e),
      )
      if e.severity is Error {
        failed = true
      }
    }
  }
  (r.module_, r.trivia, failed)
}

///|
/// Type-check one module and render what it reports.
///
/// `true` when anything was rejected. The diagnostics are collected rather than
/// streamed because the checker makes them out of order -- a global initializer
/// is checked before the function that reads it -- and a report that jumps
/// backwards through the file is harder to read than one that does not.
fn check(
  path : String,
  src : String,
  m : @ast.LocModule,
  opts : Options,
) -> Bool {
  let session = @wax.Session::new(source=src)
  let _ = session.check(m, warn_unused=true)
  ignore(path)
  render_diagnostics(src, opts, session.reports())
}

///|
/// Render a run's diagnostics, returning whether anything was rejected.
///
/// The collector buffers everything RAW: the policy belongs to whoever finally
/// re-reports it, which is here. `@wax.apply_policy` is what hides, keeps or
/// promotes a named warning -- so a lint that is off by default costs nothing to
/// have implemented. The policy is the one the RUN was given: the defaults,
/// refined by `WAX_WARN` and then by `-W`. Reaching for the defaults here
/// instead made both of those parse, validate, and do nothing.
fn render_diagnostics(
  src : String,
  opts : Options,
  collected : Array[@diagnostic.Diagnostic],
) -> Bool {
  let resolved = @wax.apply_policy(opts.policy, collected)
  guard !resolved.is_empty() else { return false }
  let theme = @diagnostic.get_theme(
    color=opts.color,
    palette=@colors.wax_theme,
    is_tty=@io.stderr_is_tty(),
  )
  for d in resolved {
    @diagnostic.output_error(
      stderr_sink(),
      theme,
      opts.error_format,
      Some(src),
      d,
    )
  }
  @wax.rejected(resolved)
}

///|
/// Whether an output format has no implementation.
fn not_implemented_format(f : String) -> Bool {
  !(f == "wax" || f == "wasm" || f == "wat")
}

///|
/// Check and lower one module to wasm bytes.
///
/// The diagnostics are rendered as `check` renders them, because a compile that
/// reports nothing and a check that reports nothing are the same claim about the
/// same module -- and a compile that reports an ERROR produces no bytes at all
/// rather than bytes derived from a module known to be wrong.
fn compile(
  path : String,
  src : String,
  m : @ast.LocModule,
  opts : Options,
) -> Result[Bytes, String] {
  let session = @wax.Session::new(source=src)
  // No lints on the conversion path: a compile reports what stops it producing
  // a module, and a style warning does not. The reference draws the same line --
  // `wax f.wax -f wasm` is silent on a module `wax check` would comment on.
  let checked = session.check(m)
  if render_diagnostics(src, opts, session.reports()) {
    return Err("\{path}: rejected")
  }
  Ok(checked.to_bytes()) catch {
    e => Err("\{path}: \{e}")
  }
}

///|
/// Check and print one module in the text format.
///
/// The same path the binary takes as far as the lowered module; only the last
/// step differs, which is what makes the two forms the same module.
fn compile_text(
  path : String,
  src : String,
  m : @ast.LocModule,
  opts : Options,
  trivia : @trivia.Context,
) -> Result[String, String] {
  let session = @wax.Session::new(source=src)
  let checked = session.check(m)
  if render_diagnostics(src, opts, session.reports()) {
    return Err("\{path}: rejected")
  }
  // `to_wat` keeps the conditionals rather than resolving them -- a module with
  // an unresolved conditional has no single binary form, which is what a
  // conditional is for -- and re-delimits the comments the parse collected.
  Ok(checked.to_wat(trivia~)) catch {
    e => Err("\{path}: \{e}")
  }
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
  @wax.render(m, trivia, theme~) + "\n"
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
  if opts.command is Convert && not_implemented_format(opts.output_format) {
    @io.eprintln(
      "wax-mb: output format '\{opts.output_format}' is not implemented (only 'wax' and 'wasm')",
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
      (Some(m), Check) =>
        // A recovered tree is a guess, so checking it would report on
        // instructions the author never wrote. The syntax errors are the ones
        // to fix first.
        if !failed && check(path, src, m, opts) {
          rejected = true
        }
      // The TEXT format is the same module the binary one is, written folded
      // and named rather than flat and numbered -- so it comes from the same
      // lowering, and the two cannot drift.
      (Some(m), Convert) if opts.output_format == "wat" => {
        if failed {
          return Rejected
        }
        match compile_text(path, src, m, opts, trivia) {
          Err(msg) => {
            @io.eprintln("wax-mb: " + msg)
            return Rejected
          }
          Ok(text) =>
            match opts.output_path {
              None | Some("-") => @io.print(text)
              Some(out) =>
                @fs.write_bytes_to_file(out, @utf8.encode(text)) catch {
                  _ => {
                    @io.eprintln("wax-mb: cannot write \{out}")
                    return Usage
                  }
                }
            }
        }
      }
      (Some(m), Convert) if opts.output_format == "wasm" => {
        // The checker has to run first: the lowering reads the types it left on
        // every node, which is the whole interface between the two.
        if failed {
          return Rejected
        }
        match compile(path, src, m, opts) {
          Err(msg) => {
            @io.eprintln("wax-mb: " + msg)
            return Rejected
          }
          Ok(bytes) =>
            match opts.output_path {
              // `-o -` and no `-o` both mean stdout, which for a binary is the
              // raw bytes and nothing else.
              None => @io.write_stdout_bytes(bytes)
              Some("-") => @io.write_stdout_bytes(bytes)
              Some(out) =>
                @fs.write_bytes_to_file(out, bytes) catch {
                  _ => {
                    @io.eprintln("wax-mb: cannot write \{out}")
                    return Usage
                  }
                }
            }
        }
      }
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
