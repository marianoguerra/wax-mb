// Comment and blank-line collection.
//
// Comments are deliberately NOT part of the AST. The lexer diverts them into
// this side table, keyed by the byte offset of the last real token seen, and
// the printer later re-attaches them to whichever AST node owns that offset.
// That is what makes byte-exact reprinting of commented source possible without
// every grammar rule having to thread comment fields around.
//
// Ported from wax/src/lib-utils/trivia.ml. This is the COLLECTION half, which
// is all the lexer needs; the association half (`associate`, which matches
// entries to AST spans) arrives with the printer in phase 3.

///|
/// Whether a piece of trivia began a line or trailed a token on one.
///
/// The printer needs the distinction: a comment on its own line stays on its
/// own line, while one trailing `foo; // why` has to be held back and emitted
/// after the separator rather than before it.
pub(all) enum TriviaPos {
  LineStart
  Inline
} derive(Eq, Debug)

///|
pub(all) enum TriviaKind {
  LineComment
  BlockComment
  /// A `(@...)` annotation. Not produced by the Wax lexer -- Wax spells
  /// annotations as attributes, which are real syntax -- but the reference
  /// shares this table with its WAT front end, and keeping the case makes the
  /// two ports line up.
  Annotation
} derive(Eq, Debug)

///|
pub(all) enum Trivia {
  Item(content~ : String, kind~ : TriviaKind, loc~ : @basic.Location)
  /// A blank line, which the printer preserves: run-of-blank-lines structure is
  /// part of how the source reads, so dropping it would change the output.
  BlankLine
} derive(Eq, Debug)

///|
pub(all) struct Entry {
  /// Byte offset of the end of the last real token before this trivia. This is
  /// the join key the printer uses to decide which node owns the comment.
  anchor : Int
  trivia : Trivia
  position : TriviaPos
} derive(Eq, Debug)

///|
/// Collection state, threaded through lexing.
///
/// The reference makes the grammar a Menhir functor over this context so every
/// semantic action can register spans. MoonBit has no functors, so phase 2 will
/// hold it in a package-level Ref instead — see parser/parser.mbty.
pub struct Context {
  entries : Array[Entry]
  mut at_start_of_line : Bool
  mut prev_token_end : Int
  locations : Array[@basic.Location]
}

///|
pub fn Context::new() -> Context {
  { entries: [], at_start_of_line: true, prev_token_end: 0, locations: [], }
}

///|
/// Record a comment (or annotation) spanning `loc`.
///
/// A line comment runs to the end of its line, so it leaves the lexer at the
/// start of the next one; a block comment does not.
pub fn Context::report_item(
  self : Context,
  kind : TriviaKind,
  loc : @basic.Location,
  content : String,
) -> Unit {
  self.entries.push({
    anchor: self.prev_token_end,
    trivia: Item(content~, kind~, loc~),
    position: if self.at_start_of_line {
      LineStart
    } else {
      Inline
    },
  })
  self.at_start_of_line = kind is LineComment
}

///|
/// Record a newline.
///
/// A newline while already at the start of a line means the line just ended was
/// empty, which is the only way a blank line is detected.
pub fn Context::report_newline(self : Context) -> Unit {
  if self.at_start_of_line {
    self.entries.push({
      anchor: self.prev_token_end,
      trivia: BlankLine,
      position: LineStart,
    })
  }
  self.at_start_of_line = true
}

///|
/// Record that a real token ending at byte offset `pos` was consumed.
pub fn Context::report_token(self : Context, pos : Int) -> Unit {
  self.at_start_of_line = false
  self.prev_token_end = pos
}

///|
/// Record that an AST node spans `loc`, so trivia can be attached to it later.
pub fn Context::record_pos(self : Context, loc : @basic.Location) -> Unit {
  self.locations.push(loc)
}

///|
/// The collected trivia, in source order.
///
/// The reference accumulates onto the front of a list and reverses on use;
/// pushing onto an array keeps source order directly.
pub fn Context::entries(self : Context) -> ArrayView[Entry] {
  self.entries[:]
}

///|
pub fn Context::locations(self : Context) -> ArrayView[@basic.Location] {
  self.locations[:]
}
