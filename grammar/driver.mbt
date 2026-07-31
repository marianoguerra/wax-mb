// The front door: source text in, AST and diagnostics out.
//
// Mirrors the reference's `Parsing.Make.parse_diagnostics`, which returns data
// and prints nothing -- the shape a differential harness needs. Errors are
// never raised out of here: the caller inspects the reports.

///|
/// The result of parsing one file.
pub struct ParseResult {
  /// The module, or None when the parse failed.
  ///
  /// There is no partial tree: MoonYacc has no error recovery, and the
  /// reference's default path likewise aborts at the first syntax error.
  module_ : @ast.LocModule?
  /// Diagnostics, in the order found. At most one, for the same reason.
  errors : Array[@basic.Report]
  /// Comments and blank lines, for the printer.
  trivia : @trivia.Context
}

///|
/// Parse `src`.
///
/// Three failure paths, all funnelled into `errors`:
///
///   * a LEXICAL error, which stops the scan (`lexer.tokens_from_string`);
///   * a SEMANTIC error raised from a grammar action -- recorded rather than
///     raised, since MoonYacc's actions cannot propagate one;
///   * a SYNTAX error from the automaton itself, `ParseError`.
pub fn parse_string(src : String, fname? : String = "") -> ParseResult {
  let ctx = @trivia.Context::new()
  set_context(ctx)
  let lexed = @lexer.tokens_from_string(src, fname~, trivia_ctx=ctx)
  if lexed.errors.length() > 0 {
    return { module_: None, errors: lexed.errors, trivia: ctx }
  }
  let module_ = parse(lexed.tokens) catch {
    e =>
      return { module_: None, errors: [report_of_parse_error(e)], trivia: ctx }
  }
  // A semantic error is recorded rather than raised, so the parse "succeeds"
  // with a tree built partly from placeholders. Discard it.
  match taken_error() {
    Some(SyntaxError(loc~, message~, hint~, fix~)) =>
      {
        module_: None,
        errors: [
          {
            loc,
            severity: Error,
            message,
            warning: None,
            hint,
            edit: fix,
            related: [],
          },
        ],
        trivia: ctx,
      }
    None => { module_: Some(module_), errors: [], trivia: ctx }
  }
}

///|
/// Turn the automaton's own error into a diagnostic.
///
/// The message is deliberately NOT an attempt to match the reference's wording.
/// The reference derives its "Expecting an expression." text from the LR
/// automaton through a generator (`stele`) that has no counterpart here, so
/// message text is the one field the differential harness does not gate. The
/// SPAN is gated, and that is reproduced exactly.
fn report_of_parse_error(e : ParseError) -> @basic.Report {
  match e {
    UnexpectedToken(_, (start, end), expected) =>
      @basic.Report::error({ start, end }, expecting_message(expected))
    UnexpectedEndOfInput(pos, expected) =>
      @basic.Report::error(
        { start: pos, end: pos },
        expecting_message(expected),
      )
  }
}

///|
/// Render the automaton's acceptable-token set.
///
/// MoonYacc hands back the exact set of token kinds that could have been
/// shifted, which is the same input the reference's message generator works
/// from -- so this is where a future push for message parity would start.
fn expecting_message(expected : Array[TokenKind]) -> String {
  if expected.is_empty() {
    return "Syntax error."
  }
  let names = []
  for k in expected {
    names.push(k.to_expect_string())
  }
  "Expecting \{names.join(", ")}."
}
