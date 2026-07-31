// A structured diagnostic message.
//
// The tree carries the message's STRUCTURE; the theme and the width arrive only
// at render time. One value therefore renders three ways -- to a themed
// terminal, and flattened for the JSON and short formats -- with no branching
// at construction.

///|
/// A diagnostic message.
pub(all) enum Message {
  Empty
  /// Prose, reflowed on spaces and hard-broken on newlines.
  Words(String)
  /// One atom: its style, whether to quote it when the theme is uncoloured,
  /// and its text.
  ///
  /// The quoting flag is the whole emphasis mechanism. An emphasized atom is
  /// shown in its colour when there is colour and wrapped in `'...'` when there
  /// is not -- so JSON and short output, which are never coloured, are always
  /// quoted, and an interactive terminal is coloured and unquoted.
  Atom(@colors.Style, Bool, String)
  /// The escape hatch: run a callback against the render-time printer.
  ///
  /// This is how a type or an instruction gets rendered through the shared
  /// pretty-printer without this package having to know about the AST.
  Raw((@printer.Printer, @colors.Theme) -> Unit)
  /// Juxtapose with no space.
  Seq(Message, Message)
  /// Juxtapose with a soft space, which is a wrap point.
  Sep(Message, Message)
  /// Lay out as a keep-together box, indented when broken.
  Group(Message)
}

///|
/// Prose.
///
/// Splits on spaces into words joined by soft breaks, so it reflows at the
/// render width; an embedded newline is a hard break.
pub fn text(s : String) -> Message {
  Words(s)
}

///|
/// An emphasized source identifier.
pub fn ident(s : String) -> Message {
  Atom(Identifier, true, s)
}

///|
/// An emphasized inline code token -- an instruction, an operator, a literal.
pub fn code(s : String) -> Message {
  Atom(Keyword, true, s)
}

///|
/// An emphasized type name given as a string.
pub fn type_(s : String) -> Message {
  Atom(Type, true, s)
}

///|
/// One unbreakable styled atom, never quoted.
pub fn styled(style : @colors.Style, s : String) -> Message {
  Atom(style, false, s)
}

///|
pub fn int(n : Int) -> Message {
  Atom(Constant, false, n.to_string())
}

///|
pub fn int64(n : Int64) -> Message {
  Atom(Constant, false, n.to_string())
}

///|
/// `n` as an UNSIGNED 64-bit integer, so a value with the high bit set prints
/// as its magnitude rather than as a negative number.
pub fn uint64(n : Int64) -> Message {
  Atom(Constant, false, n.reinterpret_as_uint64().to_string())
}

///|
pub fn bool_(b : Bool) -> Message {
  Atom(Constant, false, b.to_string())
}

///|
/// Run an imperative callback against the render-time printer and theme.
pub fn raw(f : (@printer.Printer, @colors.Theme) -> Unit) -> Message {
  Raw(f)
}

///|
/// Juxtapose with no space between.
pub fn Message::seq(self : Message, b : Message) -> Message {
  Seq(self, b)
}

///|
/// Juxtapose with a soft (wrap-point) space between.
pub fn Message::sep(self : Message, b : Message) -> Message {
  Sep(self, b)
}

///|
pub fn concat(l : Array[Message]) -> Message {
  let mut acc : Message = Empty
  for m in l {
    acc = Seq(acc, m)
  }
  acc
}

///|
/// Lay out as a keep-together box.
///
/// Used to wrap a rendered type so it does not reflow word by word.
pub fn group(m : Message) -> Message {
  Group(m)
}

///|
/// `"a, b or c"` -- commas, with `conj` before the last item.
pub fn enumerate(items : Array[Message], conj? : String = "or") -> Message {
  match items.length() {
    0 => Empty
    1 => items[0]
    n => {
      let mut commad = items[0]
      for i in 1..<(n - 1) {
        commad = Seq(commad, Sep(text(","), items[i]))
      }
      Sep(Sep(commad, text(conj)), items[n - 1])
    }
  }
}
