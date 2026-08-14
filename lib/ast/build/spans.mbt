// Distinct spans for a generator that has no source text of its own.
//
// The rest of this package defaults `at~` to `@basic.dummy_loc`, which is the
// right default for a node nobody wrote. It is the WRONG value for a binding's
// name: a local's slot is keyed by the offset its name was written at, so a
// function whose identifiers all share one span has all its locals on one slot.
// The emitter refuses that outright -- see `AmbiguousBinding` in
// `emit/wasm/lower.mbt` -- and this is what to reach for instead.

///|
/// A source of distinct spans.
///
/// Only BINDING identifiers -- the names in a `let` and in a `match` arm --
/// have to be distinct for the module to be correct. Minting every identifier
/// and node from one of these is simpler than tracking which ones those are,
/// and it also gives each node a span a diagnostic can name on its own.
///
/// A generator that has an input syntax should map ITS spans into `at~`
/// instead, and get the snippet, the caret and the quick fixes pointing at text
/// its user wrote. This is for the generator that has no such text: the spans
/// are unique and ordered, and that is all they are.
///
/// ```
/// let s = @build.Spans::new()
/// let body = [
///   s.instr(Let([(Some(s.ident("a")), Some(I32))], Some(s.instr(Int("1"))))),
///   s.instr(Get(s.ident("a"))),
/// ]
/// ```
pub struct Spans {
  fname : String
  mut next : Int
}

///|
/// `fname` is what a diagnostic will name as the file. It should not be the
/// name of a file that exists: no source text will be found for it, and the
/// renderer's job is easier when it does not go looking.
pub fn Spans::new(fname? : String = "<generated>") -> Spans {
  { fname, next: 0 }
}

///|
/// A span distinct from every one this has returned before.
///
/// Each is one column wide on a line of its own, so the line number a
/// diagnostic prints -- `File "<generated>", line 7` -- is a usable node id,
/// and the `cnum - bol` every renderer computes stays a real column.
pub fn Spans::fresh(self : Spans) -> @basic.Location {
  let k = self.next
  self.next = k + 1
  let start : @basic.Position = {
    fname: self.fname,
    lnum: k + 1,
    bol: k,
    cnum: k,
  }
  { start, end: { ..start, cnum: k + 1 } }
}

///|
/// A name at a fresh span: the generated counterpart of `ident`.
pub fn Spans::ident(self : Spans, name : String) -> @ast.Ident {
  ident(name, at=self.fresh())
}

///|
/// An instruction at a fresh span: the generated counterpart of `@ast.build`.
pub fn Spans::instr(
  self : Spans,
  desc : @ast.InstrDesc[@basic.Location],
) -> @ast.Instr[@basic.Location] {
  @ast.build(desc, self.fresh())
}
