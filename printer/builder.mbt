// The imperative builder: what a printer actually calls.
//
// Streams tokens into an Engine. The comment machinery (defer_eol,
// with_held_eol) lives here rather than in the engine, because whether a
// trailing comment must be held back past a separator is a question about the
// DOCUMENT being built, not about how it lays out.

///|
/// A printer.
pub struct Printer {
  engine : Engine
  /// The most recent break not yet emitted.
  ///
  /// Held so a following break can coalesce with it, and so `force_eol` and
  /// `skip_space` can drop it -- a break already fed to the engine cannot be
  /// taken back.
  mut pending_break : BreakStrength?
  /// Whether anything has been emitted since the last forced end of line.
  mut has_emitted : Bool
  /// A trailing end-of-line comment, deferred until the next ordinary token.
  mut pending_eol : (() -> Unit)?
  mut holding_eol : Bool
}

///|
pub fn Printer::new(width? : Int = 78) -> Printer {
  {
    engine: Engine::new(width~),
    pending_break: None,
    has_emitted: false,
    pending_eol: None,
    holding_eol: false,
  }
}

///|
/// Emit a non-break token, flushing any pending break first.
///
/// Order matters: a break always precedes the following text or group and
/// follows the preceding group's content.
fn Printer::emit(self : Printer, tok : Token) -> Unit {
  match self.pending_break {
    Some(s) => {
      self.pending_break = None
      self.engine.feed(TBreak(s))
    }
    None => ()
  }
  self.engine.feed(tok)
}

///|
/// Record a break, coalescing with a pending one into the stronger of the two.
fn Printer::push_break(self : Printer, s : BreakStrength) -> Unit {
  self.pending_break = Some(
    match self.pending_break {
      Some(s0) => if s.strength() >= s0.strength() { s } else { s0 }
      None => s
    },
  )
}

///|
/// Drop a pending break, so a deferred end-of-line comment hugs the preceding
/// token instead of being pushed past the break.
fn Printer::drop_trailing_break(self : Printer) -> BreakStrength? {
  let b = self.pending_break
  self.pending_break = None
  b
}

///|
/// Emit a deferred end-of-line comment, if one is waiting.
pub fn Printer::force_eol(self : Printer) -> Unit {
  match self.pending_eol {
    None => ()
    Some(emit_comment) => {
      self.pending_eol = None
      let dropped = self.drop_trailing_break()
      emit_comment()
      // The comment ends the line. A dropped blank line stays a blank line.
      let next_brk : BreakStrength = match dropped {
        Some(BlankLine) => BlankLine
        _ => Newline
      }
      self.push_break(next_brk)
      self.has_emitted = false
    }
  }
}

///|
/// Record a trailing line comment, to be emitted at the end of the current
/// line.
///
/// It is flushed before the next ordinary token or group, or at end of output.
/// Emitting it ends the line.
pub fn Printer::defer_eol(self : Printer, emit_comment : () -> Unit) -> Unit {
  self.force_eol()
  self.pending_eol = Some(emit_comment)
}

///|
/// Run `f` without flushing a pending end-of-line comment first.
///
/// A list separator printed inside `f` then appears on the comment's line,
/// AHEAD of the comment -- which is where a reader expects the comma of
/// `foo, // why`.
pub fn Printer::with_held_eol(self : Printer, f : () -> Unit) -> Unit {
  let prev = self.holding_eol
  self.holding_eol = true
  f()
  self.holding_eol = prev
}

///|
/// Whether a trailing comment is currently deferred.
///
/// Lets a caller suppress a trailing comma when the last element already
/// carries a comment: adding the comma would push the comment off that element
/// and change where it re-attaches on a reparse.
pub fn Printer::has_pending_eol(self : Printer) -> Bool {
  self.pending_eol is Some(_)
}

///|
fn Printer::text(self : Printer, len : Int, s : String) -> Unit {
  if !self.holding_eol {
    self.force_eol()
  }
  self.has_emitted = true
  self.emit(TText(len, s))
}

///|
/// Print a string, measured at its DISPLAY width.
pub fn Printer::string(self : Printer, s : String) -> Unit {
  self.text(@unicode.terminal_width(s), s)
}

///|
/// Print a string with an explicitly stated display width.
///
/// For text whose printed width is not its measured width -- a coloured span,
/// where the escape sequences occupy no columns.
pub fn Printer::string_as(self : Printer, len : Int, s : String) -> Unit {
  self.text(len, s)
}

///|
/// A break that becomes a space when flat.
///
/// Suppressed at the start of a line: there is nothing to separate from.
pub fn Printer::space(self : Printer) -> Unit {
  if self.has_emitted {
    self.push_break(Space)
  }
}

///|
/// A break of zero width when flat.
pub fn Printer::cut(self : Printer) -> Unit {
  self.push_break(Cut)
}

///|
/// A break that always ends the line.
pub fn Printer::newline(self : Printer) -> Unit {
  self.push_break(Newline)
}

///|
/// A break that always leaves a blank line.
pub fn Printer::blank_line(self : Printer) -> Unit {
  self.push_break(BlankLine)
}

///|
/// Run `f` with break-indentation increased by `n`.
pub fn Printer::indent(self : Printer, n : Int, f : () -> Unit) -> Unit {
  self.emit(TNest(n))
  f()
  self.emit(TEnd)
}

///|
/// Emit `f`'s content only when the enclosing group is laid out broken.
pub fn Printer::if_broken(self : Printer, f : () -> Unit) -> Unit {
  self.emit(TIfBroken)
  f()
  self.emit(TEnd)
}

///|
fn Printer::scoped(
  self : Printer,
  kind : GKind,
  skip_space : Bool,
  indent : Int,
  f : () -> Unit,
) -> Unit {
  if !self.holding_eol {
    self.force_eol()
  }
  if skip_space {
    match self.pending_break {
      Some(Cut) | Some(Space) => self.pending_break = None
      _ => ()
    }
  }
  self.emit(TBegin(kind))
  // The group's own indent is a nest wrapping its whole body, so every break
  // inside indents from base + indent.
  if indent != 0 {
    self.emit(TNest(indent))
  }
  f()
  if indent != 0 {
    self.emit(TEnd)
  }
  self.emit(TEnd)
}

///|
/// Fill: each soft break wraps independently, as needed.
pub fn Printer::box(
  self : Printer,
  f : () -> Unit,
  skip_space? : Bool = false,
  indent? : Int = 0,
) -> Unit {
  self.scoped(GBox, skip_space, indent, f)
}

///|
/// All-or-nothing: the whole group flat, or every soft break wraps.
pub fn Printer::hvbox(
  self : Printer,
  f : () -> Unit,
  skip_space? : Bool = false,
  indent? : Int = 0,
) -> Unit {
  self.scoped(GHv, skip_space, indent, f)
}

///|
pub fn Printer::hovbox(
  self : Printer,
  f : () -> Unit,
  skip_space? : Bool = false,
  indent? : Int = 0,
) -> Unit {
  self.scoped(GHov, skip_space, indent, f)
}

///|
/// Every soft break wraps.
pub fn Printer::vbox(
  self : Printer,
  f : () -> Unit,
  skip_space? : Bool = false,
  indent? : Int = 0,
) -> Unit {
  self.scoped(GV, skip_space, indent, f)
}

///|
/// Soft breaks never wrap; hard ones still do.
pub fn Printer::hbox(
  self : Printer,
  f : () -> Unit,
  skip_space? : Bool = false,
) -> Unit {
  self.scoped(GH, skip_space, 0, f)
}

///|
/// Flush a trailing deferred comment, then drain the engine.
///
/// A trailing break is left pending and never fed, so it is dropped -- no
/// trailing whitespace.
pub fn Printer::finalize(self : Printer) -> Unit {
  self.force_eol()
  self.engine.finish_stream()
}

///|
/// Lay `f` out and return the text.
pub fn run_string(f : (Printer) -> Unit, width? : Int = 78) -> String {
  let p = Printer::new(width~)
  f(p)
  p.finalize()
  p.engine.contents()
}

///|
/// Run `f` and return the TOKEN STREAM it builds, laying nothing out.
///
/// The builder is engine-independent -- width never reaches it -- so this is
/// the whole document, in the form a layout engine consumes it. It exists so an
/// alternative engine can be fed exactly what this one is fed; see
/// `printer_pp`.
pub fn run_tokens(f : (Printer) -> Unit, width? : Int = 78) -> Array[Token] {
  let p = Printer::new(width~)
  let rec : Array[Token] = []
  p.engine.record = Some(rec)
  p.engine.discarding = true
  f(p)
  p.finalize()
  rec
}

///|
/// Run `f` producing NO output.
///
/// For the dry pass that only needs the printer's side effects -- recording
/// which source spans get looked up, so trivia can be associated to them --
/// without building and laying out a document just to discard it.
pub fn run_discard(f : (Printer) -> Unit) -> Unit {
  let p = Printer::new()
  p.engine.discarding = true
  f(p)
  p.finalize()
}
