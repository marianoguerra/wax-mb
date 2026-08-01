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
    // The reference's parser PULLS tokens, so a syntax error earlier in the
    // file is reported before its lexer ever reaches the bad character. This
    // one lexes the whole file first, which would otherwise let a stray `…` on
    // line 2 hide the real error on line 1. Parse what did lex and prefer an
    // error that comes first in the file.
    let errors = match earlier_syntax_error(lexed.tokens, lexed.errors[0]) {
      Some(report) => [report]
      None => lexed.errors
    }
    return { module_: None, errors, trivia: ctx }
  }
  let module_ = parse(lexed.tokens) catch {
    e => {
      // A semantic error recorded EARLIER in the file wins, for the same
      // reason the lexical case above does. The reference raises from the
      // action and stops right there; MoonYacc's actions cannot raise
      // (test/UPSTREAM-FINDINGS.md finding 3), so the parse runs on and can
      // reach a later syntax error that would otherwise be reported instead.
      let syntax = report_of_parse_error(e, lexed.tokens)
      let report : @basic.Report = match taken_error() {
        Some(SyntaxError(loc~, message~, hint~, fix~)) =>
          if loc.start.cnum < syntax.loc.start.cnum {
            { ..@basic.Report::error(loc, message), hint, edit: fix }
          } else {
            syntax
          }
        None => syntax
      }
      return { module_: None, errors: [report], trivia: ctx }
    }
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
/// A parse error strictly before where the scan stopped, if there is one.
///
/// The tokens that did lex are a real prefix of the file, so parsing them says
/// what a lazy lexer's parser would have hit first. Only an error at a token
/// BEFORE the lexical one counts: running out of tokens is an artifact of the
/// truncation, not something the reference would report.
fn earlier_syntax_error(
  tokens : Array[(Token, Position, Position)],
  lexical : @basic.Report,
) -> @basic.Report? {
  let cut = lexical.loc.start
  // The scan stops without emitting EOF, and the automaton needs one to make
  // any decision at the end of the prefix.
  let prefix = tokens.copy()
  prefix.push((EOF, cut, cut))
  let found : @basic.Report? = try {
    parse(prefix) |> ignore
    (None : @basic.Report?)
  } catch {
    UnexpectedToken(_, (start, _), _) as e =>
      if start.cnum < cut.cnum {
        Some(report_of_parse_error(e, prefix))
      } else {
        None
      }
    // Out of tokens: the file was cut short by the scan, so this says nothing.
    UnexpectedEndOfInput(_) => None
  } noraise {
    _ => None
  }
  // A grammar action may have recorded a semantic error along the way; it is
  // reported on the same first-in-the-file terms. Draining it either way keeps
  // it from surfacing on the next parse.
  match (found, taken_error()) {
    (Some(_), _) => found
    (None, Some(SyntaxError(loc~, message~, hint~, fix~))) =>
      if loc.start.cnum < cut.cnum {
        Some({
          loc,
          severity: Error,
          message,
          warning: None,
          hint,
          edit: fix,
          related: [],
        })
      } else {
        None
      }
    (None, None) => None
  }
}

///|
/// Turn the automaton's own error into a diagnostic.
fn report_of_parse_error(
  e : ParseError,
  tokens : Array[(Token, Position, Position)],
) -> @basic.Report {
  let (loc, expected) : (@basic.Location, Array[TokenKind]) = match e {
    UnexpectedToken(_, (start, end), expected) => ({ start, end }, expected)
    UnexpectedEndOfInput(pos, expected) => ({ start: pos, end: pos }, expected)
  }
  // The state comes from replaying the parse, so it is only trusted when the
  // replay stopped where the parse did -- a disagreement means the replay no
  // longer mirrors the engine, and a message keyed on the wrong state would be
  // worse than no message at all.
  guard error_state(tokens) is Some(st) else {
    return @basic.Report::error(loc, expecting_message(expected))
  }
  let agrees = match e {
    UnexpectedToken(_, (start, end), _) =>
      st.token_index < tokens.length() &&
      tokens[st.token_index].1 == start &&
      tokens[st.token_index].2 == end
    UnexpectedEndOfInput(_) => st.token_index >= tokens.length()
  }
  guard agrees else {
    return @basic.Report::error(loc, expecting_message(expected))
  }
  syntax_report(st, tokens, loc, expected)
}

///|
/// The diagnostic for a failure the parser has already located.
///
/// The message is the reference's own where the state it failed in is one the
/// reference has a message for -- that is what `parser_messages.mbt` is, and it
/// is the only way to reach the "Assuming that the X is complete" subject,
/// which names a grammar symbol nothing in MoonYacc's error value identifies.
/// Otherwise it is the locally rendered acceptable-token list: less specific,
/// never wrong.
///
/// Shared with recovery (`recover.mbt`), which reaches the same situation
/// without an exception to catch: it holds the stack already.
fn syntax_report(
  st : ErrorState,
  tokens : Array[(Token, Position, Position)],
  loc : @basic.Location,
  expected : Array[TokenKind],
) -> @basic.Report {
  match reference_message(st.stack[:], expected_signature(expected)) {
    None => @basic.Report::error(loc, expecting_message(expected))
    Some(m) => {
      let report = @basic.Report::error(loc, m.text)
      // Emission order, as the reference's runtime resolves them: the subject
      // first, the delimiter hint second.
      if m.subject != "" && st.subject_span() is Some((start, end)) {
        report.related.push({ loc: { start, end }, message: m.subject })
      }
      if m.opener != "" &&
        enclosing_opener(tokens, st.token_index) is Some((start, end)) {
        report.related.push({ loc: { start, end }, message: m.opener })
      }
      report
    }
  }
}

///|
/// A signature of the acceptable-token set, for the message table.
///
/// A stack suffix alone is not enough to borrow the reference's message: the
/// same top frames occur in contexts whose continuations differ (a `type`
/// definition inside a `rec { … }` group accepts `'}'`, the same construct at
/// the top level does not), and a message from the wrong one claims a token is
/// legal when it is not. The acceptable set IS that difference, so the table
/// records it and the lookup checks it.
///
/// Deliberately the raw spellings rather than the rendered message: the
/// rendering has opinions (class collapse, ordering) that may change, and this
/// wants to change only when the automaton does.
pub fn expected_signature(expected : Array[TokenKind]) -> String {
  let names = []
  for k in expected {
    names.push(k.to_expect_string())
  }
  names.sort_by((a, b) => a.lexical_compare(b))
  names.join(" ")
}

///|
/// Does this borrowed message claim only tokens this state really accepts?
///
/// The second half of the message-table lookup. A recorded signature that
/// matches is proof the context is the same one; this is the weaker evidence
/// used when it does not, and it is what the reader would check: every token
/// the message NAMES must be legal here. It lets a message through when the
/// recorded context differed in a token the message never mentions (the
/// function-type state reached with `->` still ahead of it, say), and keeps out
/// the one that matters -- a message from elsewhere in the grammar, offering a
/// `'}'` that would close nothing.
///
/// Says nothing about a message with no quoted token in it ("Expecting an
/// expression."), which is then borrowed on the stack key alone.
fn message_fits(message : String, signature : String) -> Bool {
  let padded = " " + signature + " "
  let chars = message.to_array()
  let mut i = 0
  while i < chars.length() {
    if chars[i] != '\'' {
      i += 1
      continue
    }
    // `'''` is the QUOTE token, whose spelling is a quote between quotes.
    let (spelling, next) = if i + 2 < chars.length() &&
      chars[i + 1] == '\'' &&
      chars[i + 2] == '\'' {
      ("'''", i + 3)
    } else {
      let mut j = i + 1
      while j < chars.length() && chars[j] != '\'' {
        j += 1
      }
      if j >= chars.length() {
        return true // an unpaired quote is prose, not a token
      }
      (String::from_array(chars[i:j + 1].to_owned()), j + 1)
    }
    if !padded.contains(" " + spelling + " ") {
      return false
    }
    i = next
  }
  true
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
