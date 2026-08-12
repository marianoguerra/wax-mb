///|
/// A source span, mirroring the reference's `Wax_utils.Ast.location`
/// (`{ loc_start; loc_end }`).
pub(all) struct Location {
  start : Position
  end : Position
} derive(Eq, Compare, Hash, Debug)

///|
/// The span of a synthesized node, mirroring the reference's `dummy_loc`.
pub let dummy_loc : Location = { start: dummy_pos, end: dummy_pos }

///|
pub fn Location::is_dummy(self : Location) -> Bool {
  self.start.is_dummy()
}

///|
/// The smallest span covering both operands. Both must come from the same file:
/// a merge across files has no meaning, so it is a caller bug rather than a
/// case to handle, and `guard!` says so.
pub fn Location::merge(self : Location, other : Location) -> Location {
  guard! self.start.fname == other.start.fname
  let start = if self.start < other.start { self.start } else { other.start }
  let end = if self.end > other.end { self.end } else { other.end }
  { start, end }
}

///|
/// An empty span at the start of `self`, used for an insertion-point edit.
pub fn Location::collapse_start(self : Location) -> Location {
  { start: self.start, end: self.start }
}

///|
/// An empty span at the end of `self`, used for an insertion-point edit.
pub fn Location::collapse_end(self : Location) -> Location {
  { start: self.end, end: self.end }
}

///|
pub impl Show for Location with fn output(self, buf) {
  buf
  ..write_string(self.start.lnum.to_string())
  ..write_char(':')
  ..write_string(self.start.column1().to_string())
  ..write_char('-')
  ..write_string(self.end.lnum.to_string())
  ..write_char(':')
  .write_string(self.end.column1().to_string())
}

///|
pub impl ToJson for Location with fn to_json(self) {
  match show_loc.val {
    Hidden => Json::null()
    Json =>
      {
        "file": self.start.fname,
        "start": { "line": self.start.lnum, "column": self.start.column0() },
        "end": { "line": self.end.lnum, "column": self.end.column0() },
      }
    Str =>
      Json::string(
        "\{self.start.lnum}:\{self.start.column1()}-\{self.end.lnum}:\{self.end.column1()}",
      )
  }
}

///|
/// A value of type `D` carried together with an annotation of type `Info`.
///
/// This is the reference's `('desc, 'info) annotated`. The annotation is a type
/// parameter rather than a fixed `Location` because the type checker — which
/// will be ported later — re-annotates the tree with inferred types.
pub(all) struct Annotated[D, Info] {
  desc : D
  info : Info
} derive(Eq, Debug)

///|
/// Wrap a value with a dummy span, the counterpart of the reference's `no_loc`.
pub fn[D] no_loc(desc : D) -> Annotated[D, Location] {
  { desc, info: dummy_loc }
}
