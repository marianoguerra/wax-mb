// List and trivia helpers.

///|
/// Look up the trivia attached to a span, and record the lookup during a dry
/// pass.
///
/// The dry pass is what tells `associate` which spans the printer will actually
/// look up, so every lookup has to go through here -- one that bypasses it
/// would let a comment attach to a node that is never printed, and vanish.
pub fn[Info] Ctx::get_trivia(
  self : Ctx[Info],
  loc : @basic.Location?,
) -> @trivia.Associated {
  match (self.collect, loc) {
    (Some(set), Some(l)) => {
      set.mark(l)
      @trivia.empty_assoc
    }
    _ => self.trivia.get(loc)
  }
}

///|
/// Print a run of trivia entries.
///
/// A line comment on its own line stays on its own line; one trailing a token
/// is deferred to the end of the current line, so a following separator can
/// still be printed ahead of it.
pub fn[Info] Ctx::print_trivia(
  self : Ctx[Info],
  entries : Array[@trivia.Entry],
) -> Unit {
  for e in entries {
    match (e.trivia, e.position) {
      (Item(content~, kind=BlockComment, ..), _) => {
        self.space()
        self.styled(Punctuation, content)
        self.space()
      }
      (Item(content~, kind=LineComment, ..), Inline) =>
        // Trailing: defer past a following separator so the separator stays on
        // this line, ahead of the comment.
        self.p.defer_eol(() => {
          self.p.string(" ")
          self.styled(Punctuation, content.trim_space().to_string())
        })
      (Item(content~, kind=LineComment, ..), LineStart) => {
        self.newline()
        self.styled(Punctuation, content.trim_space().to_string())
        self.newline()
      }
      (Item(content~, kind=Annotation, ..), _) => {
        self.space()
        self.styled(Attribute, content)
        self.space()
      }
      (BlankLine, _) => self.p.blank_line()
    }
  }
}

///|
/// Print a node that owns a span: its leading trivia, then the node, then its
/// trailing trivia.
pub fn[Info] Ctx::atomic_node(
  self : Ctx[Info],
  loc : @basic.Location?,
  f : () -> Unit,
) -> Unit {
  let t = self.get_trivia(loc)
  self.print_trivia(t.before)
  f()
  self.print_trivia(t.within)
  self.print_trivia(t.after)
}

///|
/// Print `l` separated by `sep`.
pub fn[Info, T] Ctx::list(
  self : Ctx[Info],
  l : Array[T],
  f : (T) -> Unit,
  sep? : () -> Unit = () => (),
) -> Unit {
  let mut first = true
  for x in l {
    if !first {
      sep()
    }
    first = false
    f(x)
  }
}

///|
/// Comma-separated.
///
/// The comma is held past any deferred trailing comment, so it prints on the
/// comment's line ahead of it rather than being pushed to the next line.
pub fn[Info, T] Ctx::list_commasep(
  self : Ctx[Info],
  l : Array[T],
  f : (T) -> Unit,
) -> Unit {
  self.list(l, f, sep=() => {
    self.p.with_held_eol(() => self.punct(","))
    self.space()
  })
}

///|
/// A trailing comma after the last element, emitted only when the enclosing box
/// wraps (rustfmt style).
///
/// Skipped when the last element carries a trailing comment: a comma there
/// would push the comment off the element and change where it re-attaches on a
/// reparse, breaking idempotence.
pub fn[Info, T] Ctx::trailing_comma(self : Ctx[Info], l : Array[T]) -> Unit {
  if l.length() > 0 && !self.p.has_pending_eol() {
    self.p.if_broken(() => self.punct(","))
  }
}

///|
pub fn[Info, T] Ctx::list_commasep_trailing(
  self : Ctx[Info],
  l : Array[T],
  f : (T) -> Unit,
) -> Unit {
  self.list_commasep(l, f)
  self.trailing_comma(l)
}

///|
pub fn[Info, T] Ctx::paren_list(
  self : Ctx[Info],
  l : Array[T],
  f : (T) -> Unit,
) -> Unit {
  self.punct("(")
  self.p.box(() => self.list_commasep(l, f))
  self.punct(")")
}

///|
/// A Rust-style parenthesised list.
///
/// It stays on one line if it fits; otherwise `(` keeps the preceding token
/// company and the elements break one per line, indented one level, with `)`
/// back at the opening column -- never the Lisp-like `(` on its own line. The
/// caller's enclosing hvbox is what makes the choice all-or-nothing.
pub fn[Info, T] Ctx::arg_list(
  self : Ctx[Info],
  l : Array[T],
  f : (T) -> Unit,
) -> Unit {
  self.punct("(")
  if l.length() > 0 {
    self.p.indent(indent_level, () => {
      self.cut()
      self.list_commasep_trailing(l, f)
    })
    self.cut()
  }
  self.punct(")")
}
