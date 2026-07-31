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
/// shifted. The reference's generator (`stele`) works from a richer set -- the
/// acceptable *symbols*, nonterminals included, so it says "an expression"
/// where we can only enumerate what an expression may start with -- but the
/// rendering of the list itself is reproduced here: the class collapse, then
/// sort-and-dedupe on the rendered text, then the Oxford-comma join.
///
/// Two pieces of the reference's rendering are deliberately absent:
///
///   * its `<=5` cap, which degrades a longer list to a bare "Syntax error".
///     Without nonterminal names our lists routinely exceed 5 -- a set the
///     reference renders as "an expression" reaches us as its 31-token FIRST
///     set -- so applying the cap would erase almost every message we have.
///     It belongs with the nonterminal names, not before them.
///   * the `Assuming that the X is complete` subject, which needs the error
///     state's item set. See task 4 of implementation-plan.md.
fn expecting_message(expected : Array[TokenKind]) -> String {
  if expected.is_empty() {
    return "Syntax error."
  }
  // A class collapses only when >=2 of its members are legal here, so count
  // before rendering. Counting distinct SPELLINGS, since the collapse is about
  // how many entries the list would otherwise carry.
  let counts : Map[String, Int] = Map([])
  let seen_spellings = []
  for k in expected {
    let spelling = k.to_expect_string()
    if seen_spellings.contains(spelling) {
      continue
    }
    seen_spellings.push(spelling)
    match k.expect_class() {
      Some(c) => counts[c] = counts.get(c).unwrap_or(0) + 1
      None => ()
    }
  }
  let names = []
  for k in expected {
    let name = match k.expect_class() {
      Some(c) if counts.get(c).unwrap_or(0) >= 2 => c
      _ => k.to_expect_string()
    }
    if !names.contains(name) {
      names.push(name)
    }
  }
  // Sorted by the RENDERED text, as the reference does: quoted spellings sort
  // ahead of readable phrases because `'` precedes every letter.
  //
  // NOT `sort()`: MoonBit's `Compare` for String is SHORTLEX -- it orders by
  // length first -- which would put `'{'` before `'do'`. OCaml's
  // `String.compare`, which the reference sorts with, is plain lexicographic,
  // and that is `lexical_compare` here.
  names.sort_by((a, b) => a.lexical_compare(b))
  "Expecting \{human_list(names)}."
}

///|
/// Join as English, with the Oxford comma: `a`, `a, or b`, `a, b, or c`.
///
/// Mirrors `format_human_list` in the reference's generator, including the
/// comma before `or` in the two-item case.
fn human_list(items : Array[String]) -> String {
  match items {
    [] => ""
    [x] => x
    [.. rest, last] => rest.join(", ") + ", or " + last
  }
}
