// Lexical errors.
//
// Unlike the parser's messages -- which the reference derives from its LR
// automaton via a generator we have no counterpart for, and which are therefore
// not gated yet -- every message here is a hand-written string in
// wax/src/lib-wax/lexer.ml. There is nothing stopping us matching them exactly,
// so they are reproduced verbatim, trailing newline included, and are gated
// from day one.

///|
pub(all) enum LexError {
  /// A character that cannot begin any token. Carries the offending text so the
  /// message can quote it, exactly as the reference does.
  UnexpectedChar(String)
  /// A `/*` block comment that reached end of input unclosed.
  MalformedComment
  /// A string literal containing a raw control character, or an unrecognised
  /// escape, or reaching end of input unterminated.
  MalformedString
  /// A `\u{...}` escape whose hex digits are not a Unicode scalar value.
  MalformedUnicodeEscape
  /// A `'\xNN'` character escape above 0x7F. Byte escapes in a CHARACTER
  /// literal are limited to ASCII, because the value denotes a code point and
  /// `\x80`-`\xFF` would be an incomplete UTF-8 sequence rather than a
  /// character. (In a STRING they are legal: there they denote raw bytes.)
  InvalidUnicodeChar
} derive(Eq, Debug)

///|
/// The reference's message text for this error, byte for byte.
///
/// The reference builds these with `Printf.sprintf "...\n"`, but the trailing
/// newline never reaches output -- both its JSON and human renderers drop it.
/// Verified against the pinned binary: `--error-format json` yields exactly
/// `"Unexpected character '\\'."`. So the newline is omitted here rather than
/// added and then stripped again at every rendering site.
pub fn LexError::message(self : LexError) -> String {
  match self {
    UnexpectedChar(s) => "Unexpected character '\{s}'."
    MalformedComment => "Malformed comment."
    MalformedString => "Malformed string."
    MalformedUnicodeEscape => "Malformed Unicode escape."
    InvalidUnicodeChar => "Invalid Unicode character."
  }
}

///|
/// The prose hint the reference attaches, if any.
pub fn LexError::hint(self : LexError) -> String? {
  match self {
    MalformedComment => Some("A block comment must be closed with '*/'.")
    MalformedUnicodeEscape =>
      Some(
        "A Unicode escape has the form '\\u{XXXX}', where 'XXXX' is the hexadecimal code of a Unicode scalar value.",
      )
    _ => None
  }
}

///|
/// Package a lexical error as a diagnostic spanning `loc`.
pub fn LexError::to_report(self : LexError, loc : Location) -> Report {
  {
    loc,
    severity: Error,
    message: self.message(),
    warning: None,
    hint: self.hint(),
    edit: None,
    related: [],
  }
}
