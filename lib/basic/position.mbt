// A source position, mirroring OCaml's `Lexing.position` field for field.
//
// The Wax reference implementation threads `Lexing.position` through its lexer,
// parser and diagnostics, and both its JSON and human diagnostic renderers
// derive their columns arithmetically from `pos_cnum`/`pos_bol`. Reproducing the
// record exactly is what lets the MoonBit port match those renderers byte for
// byte, so the field names are kept as-is rather than renamed.

///|
/// A position in a source file.
///
/// * `fname` — the file name (`""` when reading from stdin).
/// * `lnum`  — the line number, 1-based.
/// * `bol`   — the byte offset of the beginning of the current line.
/// * `cnum`  — the absolute byte offset of the position itself.
///
/// The column is not stored; it is `cnum - bol`. Use `column0` or `column1`
/// depending on the convention the caller needs — see their documentation.
pub(all) struct Position {
  fname : String
  lnum : Int
  bol : Int
  cnum : Int
} derive(Debug, Hash, ToJson)

///|
/// The 0-based column: the raw `cnum - bol`.
///
/// This is the convention the reference's **JSON** diagnostic renderer uses for
/// `startColumn`/`endColumn`.
pub fn Position::column0(self : Position) -> Int {
  self.cnum - self.bol
}

///|
/// The 1-based column, `cnum - bol + 1`.
///
/// This is the convention the reference's **human** and **short** diagnostic
/// renderers use.
pub fn Position::column1(self : Position) -> Int {
  self.cnum - self.bol + 1
}

///|
/// The position OCaml's `Lexing.dummy_pos` denotes, for synthesized nodes that
/// have no source span.
///
/// Note `cnum` is `-1`, not `0`: the reference's `output_error_no_source` path
/// tests for exactly this to decide whether it can print a `File "…", line …`
/// header at all, so the sentinel value has to match.
pub let dummy_pos : Position = { fname: "", lnum: 0, bol: 0, cnum: -1, }

///|
pub fn Position::is_dummy(self : Position) -> Bool {
  self.cnum == -1
}

///|
/// Equality on `fname` and `cnum` only: `lnum`/`bol` are derived from the same
/// scan and cannot disagree for a given `(fname, cnum)`.
pub impl Eq for Position with fn equal(self, other) {
  self.fname == other.fname && self.cnum == other.cnum
}

///|
pub impl Compare for Position with fn compare(self, other) {
  match self.fname.compare(other.fname) {
    0 => self.cnum.compare(other.cnum)
    r => r
  }
}

///|
pub impl Show for Position with fn output(self, logger) {
  if self.fname != "" {
    logger..write_string(self.fname).write_char(':')
  }
  logger
  ..write_string(self.lnum.to_string())
  ..write_char(':')
  .write_string(self.column1().to_string())
}
