// The whole pipeline, in one call each.
//
// Everything here is a composition of packages that can also be used directly:
// `@grammar.parse_string`, `@output.render`, `@compile.Session`. Reach for
// those when you need a stage's intermediate value -- the AST, the trivia
// table, the lowered wasm module. Reach for these when you want the answer.

///|
/// The front end, re-exported.
///
/// `parse_string` stops at the first syntax error; `parse_recover` reports
/// every error it can resynchronize past, at the price of a tree that is partly
/// a guess about what the author meant. Both return a `ParseResult` whose
/// `module_` is `None` only when nothing could be recovered.
pub using @grammar {parse_string, parse_recover, type ParseResult}

///|
/// The formatter, re-exported. Takes the AST and the trivia table `parse_string`
/// returned, and gives back Wax source.
pub using @output {render}

///|
/// The AST-first pipeline, re-exported from `marianoguerra/wax/compile`.
///
/// These names are the reason that package exists separately: a code generator
/// imports it directly and never pays for the parser.
pub using @compile {type Session, type Checked, apply_policy, rejected}

///|
/// Parse, check and compile Wax source to a `.wasm` binary.
///
/// `Err` carries the diagnostics that stopped it -- syntax errors, or whatever
/// the type checker rejected under `policy`. Nothing is returned alongside
/// them: a compile that reports an error produces no bytes at all, rather than
/// bytes derived from a module known to be wrong.
///
/// Warnings never reach the caller here, because a compile reports what stops
/// it producing a module and a style warning does not. Use `Session` directly,
/// or the `check` command's `warn_unused`, to see those.
pub fn compile_string(
  src : String,
  fname? : String,
  features? : @feature.Set,
  policy? : @warning.Policy,
) -> Result[Bytes, Array[@diagnostic.Diagnostic]] raise {
  match checked(src, fname?, features?, policy?) {
    Err(diagnostics) => Err(diagnostics)
    Ok(c) => Ok(c.to_bytes())
  }
}

///|
/// Parse, check and print Wax source in the WebAssembly text format.
///
/// The same lowering `compile_string` encodes, printed instead of encoded, so
/// the two forms describe the same module by construction. Comments survive:
/// they come from the parse's trivia table and are re-delimited as WAT
/// comments.
pub fn compile_string_to_wat(
  src : String,
  fname? : String,
  features? : @feature.Set,
  policy? : @warning.Policy,
) -> Result[String, Array[@diagnostic.Diagnostic]] raise {
  let r = parse(src, fname?)
  match checked_of(r, src, features?, policy?) {
    Err(diagnostics) => Err(diagnostics)
    Ok(c) => Ok(c.to_wat(trivia=r.trivia))
  }
}

///|
/// Reformat Wax source.
///
/// The type checker does not run: reformatting is a front-end operation, and a
/// module that does not type-check still has a canonical layout. `Err` therefore
/// only ever holds syntax errors.
pub fn format_string(
  src : String,
  fname? : String,
  theme? : @colors.Theme,
) -> Result[String, Array[@diagnostic.Diagnostic]] {
  let r = parse(src, fname?)
  guard syntax_errors(r).is_empty() else { return Err(syntax_errors(r)) }
  guard r.module_ is Some(m) else { return Err(syntax_errors(r)) }
  Ok(@output.render(m, r.trivia, theme?))
}

///|
/// Parse without recovery, which is what every function here wants: a recovered
/// tree is a guess, and checking or printing a guess reports on instructions
/// nobody wrote.
fn parse(src : String, fname? : String) -> ParseResult {
  @grammar.parse_string(src, fname?)
}

///|
/// The parse's errors, as diagnostics. Warnings and suggestions are dropped:
/// the callers here report only what stopped them.
fn syntax_errors(r : ParseResult) -> Array[@diagnostic.Diagnostic] {
  let out = []
  for e in r.errors {
    if e.severity is Error {
      out.push(@diagnostic.of_report(e))
    }
  }
  out
}

///|
/// Parse and check, or report why not.
fn checked(
  src : String,
  fname? : String,
  features? : @feature.Set,
  policy? : @warning.Policy,
) -> Result[Checked, Array[@diagnostic.Diagnostic]] {
  checked_of(parse(src, fname?), src, features?, policy?)
}

///|
/// Check an already-parsed module, or report why not.
///
/// `src` is passed alongside because a parse does not keep the text it read,
/// and a diagnostic needs it to print the snippet under the caret.
fn checked_of(
  r : ParseResult,
  src : String,
  features? : @feature.Set,
  policy? : @warning.Policy,
) -> Result[Checked, Array[@diagnostic.Diagnostic]] {
  let errors = syntax_errors(r)
  guard errors.is_empty() else { return Err(errors) }
  guard r.module_ is Some(m) else { return Err(errors) }
  let session = Session::new(features?, source=src)
  let c = session.check(m)
  let reports = session.reports(policy?)
  if rejected(reports) {
    Err(reports)
  } else {
    Ok(c)
  }
}
