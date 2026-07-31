// The Wax lexer, ported from wax/src/lib-wax/lexer.ml.
//
// The reference RAISES on the first lexical error, aborting the parse. This
// port accumulates instead, following moonbitlang/parser's convention, but
// stops scanning at the first error so the observable behaviour is the same:
// one diagnostic, at the same span. (MoonYacc has no error recovery, and the
// reference's default path reports only the first syntax error anyway, so
// there is nothing to be gained from continuing.)

///|
/// A completed lex: the tokens, any diagnostics, and the collected trivia.
pub struct LexResult {
  tokens : @tokens.Triples
  errors : Array[Report]
  trivia : @trivia.Context
}

///|
/// Tokenize `src`.
///
/// Always returns; a lexical error appears in `errors` and terminates the token
/// stream. The stream is always EOF-terminated, because MoonYacc's array input
/// mode needs a terminator to reduce on.
pub fn tokens_from_string(
  src : String,
  fname? : String = "",
  trivia_ctx? : @trivia.Context,
) -> LexResult {
  let cur = Cursor::new(src, fname~)
  let ctx = match trivia_ctx {
    Some(c) => c
    None => @trivia.Context::new()
  }
  let toks : @tokens.Triples = []
  let errors : Array[Report] = []

  fn fail(e : LexError, loc : Location) -> Unit {
    errors.push(e.to_report(loc))
  }

  while errors.is_empty() {
    // Whitespace, newlines and comments are trivia: they never reach the
    // parser, they only update the trivia context.
    if skip_trivia(cur, ctx, fail) {
      continue
    }
    let start = cur.pos()
    if cur.at_end() {
      toks.push((EOF, start, start))
      break
    }
    match scan_token(cur, fail) {
      Some(tok) => {
        let end = cur.pos()
        // The trivia table keys comments on the byte offset at which the
        // preceding real token ended, so this must run for every token.
        ctx.report_token(end.cnum)
        toks.push((tok, start, end))
      }
      None => break // an error was recorded; stop.
    }
  }
  { tokens: toks, errors, trivia: ctx }
}

///|
/// Consume one run of whitespace, a newline, or a comment. Returns whether
/// anything was consumed.
fn skip_trivia(
  cur : Cursor,
  ctx : @trivia.Context,
  fail : (LexError, Location) -> Unit,
) -> Bool {
  match cur.peek() {
    Some(' ') | Some('\t') => {
      cur.bump() |> ignore
      true
    }
    Some('\n') | Some('\r') => {
      cur.bump() |> ignore
      ctx.report_newline()
      true
    }
    Some('/') =>
      if cur.looking_at("//") {
        let start = cur.pos()
        let from = cur.idx
        while !cur.at_end() &&
              !(cur.peek() is Some('\n') || cur.peek() is Some('\r')) {
          cur.bump() |> ignore
        }
        let text = cur.slice(from, cur.idx)
        ctx.report_item(LineComment, cur.span(start), text)
        // The comment's own line break belongs to the comment: the reference's
        // rule is `"//" linechar* (newline | eof)`, so it swallows the break
        // and never reports it as a newline. Reporting it separately would be
        // a blank line -- report_item has just set at_start_of_line, so the
        // very next report_newline records one -- and every trailing comment
        // would grow a phantom blank line after it.
        //
        // The break is dropped from the stored text rather than kept, which is
        // equivalent: the printer emits line comments through `String.trim`
        // (wax/src/lib-utils/styled_printer.ml:46,52).
        if cur.peek() is Some('\n') || cur.peek() is Some('\r') {
          cur.bump() |> ignore
        }
        true
      } else if cur.looking_at("/*") {
        let start = cur.pos()
        let from = cur.idx
        if scan_block_comment(cur) {
          ctx.report_item(
            BlockComment,
            cur.span(start),
            cur.slice(from, cur.idx),
          )
        } else {
          fail(MalformedComment, cur.span(start))
        }
        true
      } else {
        false
      }
    _ => false
  }
}

///|
/// Consume a `/* ... */` comment. Returns false if input ended first.
///
/// Block comments NEST, matching the reference: `/* /* */ */` is one comment,
/// so commenting out a region that already contains a comment works.
fn scan_block_comment(cur : Cursor) -> Bool {
  cur.eat("/*")
  let mut depth = 1
  while depth > 0 {
    if cur.at_end() {
      return false
    }
    if cur.looking_at("*/") {
      cur.eat("*/")
      depth -= 1
    } else if cur.looking_at("/*") {
      cur.eat("/*")
      depth += 1
    } else {
      cur.bump() |> ignore
    }
  }
  true
}

///|
/// Scan one real token. Records an error and returns None if it cannot.
fn scan_token(cur : Cursor, fail : (LexError, Location) -> Unit) -> Token? {
  let start = cur.pos()
  let c = match cur.peek() {
    Some(c) => c
    None => return None
  }

  // Numbers before identifiers and before punctuation: `nan:0x1` is a FLOAT
  // and must beat the `nan` keyword, and `0x1f` must not be read as `0` then
  // an identifier.
  if is_digit(c) || (c == 'n' && cur.looking_at("nan:")) {
    return scan_number(cur)
  }

  // Identifiers and keywords.
  if is_ident_start(c) || c == '_' {
    return scan_ident(cur, fail)
  }
  if c == '"' {
    return scan_string(cur, fail)
  }
  if c == '\'' {
    // A quote is ambiguous: it opens a character literal, but it is also the
    // QUOTE token that introduces a label (`'loop:`). Try the character forms
    // first and fall back to QUOTE, which is what the reference's ordering of
    // the `'x'` / `'\n'` / `'\u{..}'` rules against the bare `'` rule does.
    match scan_char(cur, fail) {
      Some(t) => return Some(t)
      None => if !(cur.pos().cnum == start.cnum) { return None }
    }
  }
  for entry in operators {
    if cur.looking_at(entry.0) {
      cur.eat(entry.0)
      return Some(entry.1)
    }
  }
  // Nothing matched: report the offending character, as the reference's
  // catch-all arm does, with a span covering exactly that character.
  let from = cur.idx
  cur.bump() |> ignore
  fail(UnexpectedChar(cur.slice(from, cur.idx)), cur.span(start))
  None
}

///|
fn is_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
fn is_hex_digit(c : Char) -> Bool {
  is_digit(c) || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
}

///|
/// Whether `c` may start an identifier.
///
/// Mirrors the reference's deliberately COARSE rule: ASCII letters plus any
/// non-ASCII scalar. The strict XID check happens afterwards, in `scan_ident`.
/// The reference splits it this way to keep the large XID character classes out
/// of its lexer DFA; here it costs nothing but is kept so both implementations
/// accept and reject exactly the same inputs.
fn is_ident_start(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c.to_int() >= 0x80
}

///|
fn is_ident_cont(c : Char) -> Bool {
  is_ident_start(c) || is_digit(c) || c == '_' || c == '\''
}
