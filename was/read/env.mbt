// The reader's state: where it is, and what has gone wrong.
//
// There is no environment in the usual sense. Was is a notation for Wax rather
// than a language above it, so nothing here resolves a name, infers a type or
// invents an instruction -- the reader knows only how to turn a group into the
// node it names.

///|
priv struct Reader {
  fname : String
  line_starts : Array[Int]
  src : @er.SourceId
  diagnostics : Array[@er.Report]
  /// The type names this file declares.
  ///
  /// The reader needs them for exactly one thing: `ints[0]` is a one-element
  /// array literal when `ints` is a type and an index when it is a value, and
  /// unlike Wax -- which puts the type inside the brackets, `[ints| 0]` -- was
  /// has nowhere to put a marker that shrubbery keeps. A trailing comma does
  /// not survive the reader, and `|` is the alternatives marker.
  type_names : Map[String, Unit]
  mut counter : Int
}

///|
fn Reader::new(fname~ : String, text~ : String, src~ : @er.SourceId) -> Reader {
  let line_starts = [0]
  let cs = text.to_array()
  for i, c in cs {
    if c == '\n' {
      line_starts.push(i + 1)
    }
  }
  { fname, line_starts, src, diagnostics: [], type_names: Map([]), counter: 0, }
}

///|
/// Report and keep reading, so one mistake does not hide the rest.
fn Reader::error(
  self : Reader,
  msg : String,
  span : Span,
  help? : String,
) -> Unit {
  let mut r = @er.Report::error(msg)
  if has_source(span) {
    r = r.with_label(@er.Label::primary(self.src, span))
  }
  match help {
    Some(h) => r = r.with_help(h)
    None => ()
  }
  self.diagnostics.push(r)
}

///|
/// A was span as a Wax source location, so that a Wax type error lands on the
/// .was line that caused it.
fn Reader::loc(self : Reader, span : Span) -> @basic.Location {
  if !has_source(span) {
    return self.fresh_loc()
  }
  {
    start: self.position(span.start),
    end: self.position(span.start + span.len),
  }
}

///|
fn Reader::position(self : Reader, offset : Int) -> @basic.Position {
  let mut lo = 0
  let mut hi = self.line_starts.length() - 1
  while lo < hi {
    let mid = (lo + hi + 1) / 2
    if self.line_starts[mid] <= offset {
      lo = mid
    } else {
      hi = mid - 1
    }
  }
  { fname: self.fname, lnum: lo + 1, bol: self.line_starts[lo], cnum: offset, }
}

///|
/// A location distinct from every other, for a node with no source.
fn Reader::fresh_loc(self : Reader) -> @basic.Location {
  let k = self.counter
  self.counter = k + 1
  let start : @basic.Position = {
    fname: "<was>",
    lnum: k + 1,
    bol: k,
    cnum: k,
  }
  { start, end: { ..start, cnum: k + 1, }, }
}

///|
fn Reader::ident(self : Reader, name : String, span : Span) -> @ast.Ident {
  { name, loc: self.loc(span), }
}

///|
fn Reader::instr(
  self : Reader,
  d : @ast.InstrDesc[@basic.Location],
  span : Span,
) -> @ast.Instr[@basic.Location] {
  @ast.build(d, self.loc(span))
}

///|
/// A block of instructions with the span they came from.
fn Reader::blk(
  self : Reader,
  body : Array[@ast.Instr[@basic.Location]],
  span : Span,
) -> @basic.Annotated[Array[@ast.Instr[@basic.Location]], @basic.Location] {
  { desc: body, info: self.loc(span), }
}

///|
/// A cursor over the terms of one group.
priv struct Cursor {
  ts : Array[@sh.Node]
  mut i : Int
  r : Reader
}

///|
fn Cursor::new(ts : Array[@sh.Node], r : Reader) -> Cursor {
  { ts, i: 0, r, }
}

///|
fn Cursor::done(self : Cursor) -> Bool {
  self.i >= self.ts.length()
}

///|
fn Cursor::peek(self : Cursor) -> @sh.Node? {
  if self.done() {
    None
  } else {
    Some(self.ts[self.i])
  }
}

///|
fn Cursor::next(self : Cursor) -> @sh.Node? {
  match self.peek() {
    Some(n) => {
      self.i += 1
      Some(n)
    }
    None => None
  }
}

///|
fn Cursor::here(self : Cursor) -> Span {
  if self.ts.length() == 0 {
    nowhere
  } else if self.done() {
    node_span(self.ts[self.ts.length() - 1])
  } else {
    node_span(self.ts[self.i])
  }
}

///|
/// Consume a term when it is this operator.
fn Cursor::eat_op(self : Cursor, name : String) -> Bool {
  match self.peek() {
    Some(n) if is_op(n, name) => {
      self.i += 1
      true
    }
    _ => false
  }
}

///|
/// Consume a term when it is this identifier.
fn Cursor::eat_id(self : Cursor, name : String) -> Bool {
  match self.peek() {
    Some(n) if is_id(n, name) => {
      self.i += 1
      true
    }
    _ => false
  }
}
