// Command-line parsing.

///|
/// What the tool was asked to do.
pub(all) enum Command {
  /// Read a file and write it out in the requested format. The default.
  Convert
  /// Reformat files IN PLACE, or with `--check` merely list the ones that
  /// would change.
  Format
  /// Report diagnostics and produce no output.
  Check
} derive(Eq, Debug)

///|
/// Exit statuses, shared by every command.
///
/// The distinction is HOW YOU USED THE TOOL (123/124) against THE INPUT IS BAD
/// (128), so a CI gate can tell a broken invocation from a rejected file.
pub(all) enum Status {
  /// Every file passed.
  Ok
  /// An invalid combination of flags, or a `--check` run that found files
  /// needing formatting.
  Usage
  /// An unknown flag or a bad option value.
  BadArgs
  /// An uncaught internal error.
  Internal
  /// The input was rejected by a diagnostic.
  Rejected
} derive(Eq, Debug)

///|
/// The name this program was invoked as, for the `NAME: message` prefix its
/// own errors carry.
///
/// Taken from argv[0] rather than fixed: the reference's own cram tests run it
/// as `wax`, and a program that calls itself something other than what the
/// user typed is reporting about a program the user did not run.
let prog_name : Ref[String] = @ref.new("wax-mb")

///|
/// Set the name from argv[0]. Anything without a path is used as it stands.
pub fn set_prog_name(argv0 : String) -> Unit {
  let cut = match argv0.rev_find("/") {
    Some(i) => argv0[i + 1:].to_owned()
    None => argv0
  }
  if cut != "" {
    prog_name.val = cut
  }
}

///|
/// `NAME: ` -- the prefix this program's own errors carry.
pub fn prog() -> String {
  prog_name.val + ": "
}

///|
pub fn Status::code(self : Status) -> Int {
  match self {
    Ok => 0
    Usage => 123
    BadArgs => 124
    Internal => 125
    Rejected => 128
  }
}

///|
/// A parsed command line.
pub(all) struct Options {
  command : Command
  files : Array[String]
  /// The OUTPUT format (`-f`). Only `wax` is implemented.
  output_format : String
  /// The INPUT format (`-i`). Only `wax` is implemented.
  input_format : String
  output_path : String?
  error_format : @diagnostic.OutputFormat
  color : @colors.Flag
  /// `format --check`: list what would change, write nothing.
  check_only : Bool
  /// `check --all-errors`: report every syntax error, not just the first.
  ///
  /// Off by default, matching the reference: the default path stops at the
  /// first, and recovery's later reports are guesses about what the user meant.
  all_errors : Bool
  /// `format --inplace`: rewrite each input file.
  ///
  /// OFF by default. `format` writes to stdout unless asked to rewrite, which
  /// is worth getting right: the opposite default silently edits the user's
  /// files.
  inplace : Bool
  policy : @warning.Policy
}

///|
/// Parse `argv`, or explain why it could not be.
///
/// Flags are accepted anywhere, before or after the file names, since that is
/// what the reference's parser does and what scripts assume.
pub fn parse_args(argv : Array[String]) -> Result[Options, (Status, String)] {
  let mut command = Convert
  let files = []
  let mut output_format = "wax"
  let mut input_format = "wax"
  let mut output_path : String? = None
  let mut error_format : @diagnostic.OutputFormat = Human
  let mut color : @colors.Flag = Auto
  let mut check_only = false
  let mut all_errors = false
  let mut inplace = false
  // The defaults, then WAX_WARN, then the `-W` flags -- each left to right, so
  // later settings win. The environment is read directly rather than as a
  // fallback for the flag: a `-W` refines the environment's policy instead of
  // replacing it, which is what lets a suite hide a whole group and a single
  // test re-enable the one warning it is about.
  let mut policy = env_policy()
  let mut i = 0
  // The first non-flag word is the command, but only when it names one --
  // `wax-mb f.wax` converts, exactly as `wax f.wax` does.
  if argv.length() > 0 {
    match argv[0] {
      "convert" => {
        command = Convert
        i = 1
      }
      "format" => {
        command = Format
        i = 1
      }
      "check" => {
        command = Check
        i = 1
      }
      _ => ()
    }
  }
  fn need_value(flag : String, at : Int) -> Result[String, (Status, String)] {
    if at + 1 < argv.length() {
      Ok(argv[at + 1])
    } else {
      Err((BadArgs, "option '\{flag}' needs a value"))
    }
  }

  while i < argv.length() {
    let a = argv[i]
    // `--flag=value` and `--flag value` are both accepted.
    let (name, inline_value) = match a.find("=") {
      Some(k) if a.has_prefix("--") =>
        (
          a.view(end_offset=k).to_owned(),
          Some(a.view(start_offset=k + 1).to_owned()),
        )
      _ => (a, None)
    }
    fn value(at : Int) -> Result[String, (Status, String)] {
      match inline_value {
        Some(v) => Ok(v)
        None => need_value(name, at)
      }
    }

    let consumed_inline = inline_value is Some(_)
    match name {
      // `-f` and `-i` mean DIFFERENT things per command, and the reference is
      // the authority: for `convert`, `-f` is the output format and `-i` the
      // input format; for `format`, `-f` is the INPUT format and `-i` is the
      // boolean `--inplace`.
      "-f" | "--output-format" | "--format" | "--input-format" =>
        match value(i) {
          Ok(v) => {
            if name == "--input-format" || (name == "-f" && command is Format) {
              input_format = v
            } else {
              output_format = v
            }
            i = i + (if consumed_inline { 1 } else { 2 })
          }
          Err(e) => return Err(e)
        }
      "-i" if command is Format => {
        inplace = true
        i = i + 1
      }
      "--inplace" => {
        inplace = true
        i = i + 1
      }
      "-i" =>
        match value(i) {
          Ok(v) => {
            input_format = v
            i = i + (if consumed_inline { 1 } else { 2 })
          }
          Err(e) => return Err(e)
        }
      "-o" | "--output" =>
        match value(i) {
          Ok(v) => {
            output_path = Some(v)
            i = i + (if consumed_inline { 1 } else { 2 })
          }
          Err(e) => return Err(e)
        }
      "--error-format" =>
        match value(i) {
          Ok(v) => {
            match v {
              "human" => error_format = Human
              "json" => error_format = Json
              "short" => error_format = Short
              _ =>
                return Err(
                  (
                    BadArgs,
                    "unknown error format '\{v}'; expected human, json, or short",
                  ),
                )
            }
            i = i + (if consumed_inline { 1 } else { 2 })
          }
          Err(e) => return Err(e)
        }
      "--color" =>
        match value(i) {
          Ok(v) => {
            match v {
              "always" => color = Always
              "never" => color = Never
              "auto" => color = Auto
              _ =>
                return Err(
                  (
                    BadArgs,
                    "unknown color mode '\{v}'; expected always, never, or auto",
                  ),
                )
            }
            i = i + (if consumed_inline { 1 } else { 2 })
          }
          Err(e) => return Err(e)
        }
      "-W" | "--warn" =>
        match value(i) {
          Ok(v) =>
            match @warning.parse_spec(v) {
              Err(msg) => return Err((BadArgs, msg))
              Ok((target, level)) =>
                match policy.set(target, level) {
                  Err(msg) => return Err((BadArgs, msg))
                  Ok(p) => {
                    policy = p
                    i = i + (if consumed_inline { 1 } else { 2 })
                  }
                }
            }
          Err(e) => return Err(e)
        }
      "-c" | "--check" => {
        check_only = true
        i = i + 1
      }
      "--all-errors" => {
        all_errors = true
        i = i + 1
      }
      _ =>
        if a.has_prefix("-") && a != "-" {
          return Err((BadArgs, "unknown option '\{a}'"))
        } else {
          files.push(a)
          i = i + 1
        }
    }
  }
  Ok({
    command,
    files,
    output_format,
    input_format,
    output_path,
    error_format,
    color,
    check_only,
    all_errors,
    inplace,
    policy,
  })
}

///|
/// The warning policy `WAX_WARN` asks for.
///
/// A list of `NAME=LEVEL` specs separated by commas or whitespace. A malformed
/// or unknown entry is reported and skipped, so a stray value in an
/// environment never aborts a run that had nothing to do with it.
fn env_policy() -> @warning.Policy {
  let mut policy = @warning.default_policy
  guard @env.get_env_var("WAX_WARN") is Some(raw) else { return policy }
  let specs : Array[String] = []
  for part in raw.split(",") {
    for word in part.to_owned().split(" ") {
      for token in word.to_owned().split("\t") {
        let t = token.to_owned()
        if t != "" {
          specs.push(t)
        }
      }
    }
  }
  for spec in specs {
    match @warning.parse_spec(spec) {
      Err(msg) => @io.eprintln(prog() + "WAX_WARN: " + msg)
      Ok((target, level)) =>
        match policy.set(target, level) {
          Err(msg) => @io.eprintln(prog() + "WAX_WARN: " + msg)
          Ok(p) => policy = p
        }
    }
  }
  policy
}
