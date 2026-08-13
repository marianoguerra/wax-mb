// Rendering a message: the same value, three ways.

///|
/// Emit prose.
///
/// Lines are separated by hard breaks and, within a line, words by soft breaks
/// so an enclosing fill box reflows them. Runs of spaces -- including leading
/// and trailing ones -- collapse to a single soft break, which is what lets
/// fragments joined with `seq` carry their own separating space. A trailing
/// newline is dropped rather than emitting a dangling blank line.
fn render_words(p : @printer.Printer, s : String) -> Unit {
  let lines = s.split("\n").map(v => v.to_owned()).collect()
  // Drop ONLY a trailing empty line, not every empty one: a blank line in the
  // middle of a message is a deliberate paragraph break.
  if lines.length() > 1 && lines[lines.length() - 1] == "" {
    lines.pop() |> ignore
  }
  for li, line in lines {
    if li > 0 {
      p.newline()
    }
    let mut first = true
    for tok in line.split(" ") {
      if !first {
        p.space()
      }
      first = false
      if tok.length() > 0 {
        p.string(tok.to_owned())
      }
    }
  }
}

///|
fn render_doc(p : @printer.Printer, theme : @colors.Theme, d : Message) -> Unit {
  match d {
    Empty => ()
    Words(s) => render_words(p, s)
    Atom(style, quote, s) =>
      // The emphasis rule: quote only when this style has no colour to carry
      // the emphasis. So the same atom is coloured on a terminal and quoted in
      // JSON, and never both.
      if quote && theme.escape_sequence(style) == "" {
        p.string("'" + s + "'")
      } else {
        print_styled(p, theme, style, s)
      }
    Raw(f) => f(p, theme)
    Seq(a, b) => {
      render_doc(p, theme, a)
      render_doc(p, theme, b)
    }
    Sep(a, b) => {
      render_doc(p, theme, a)
      p.space()
      render_doc(p, theme, b)
    }
    Group(inner) => p.box(indent=2, () => render_doc(p, theme, inner))
  }
}

///|
/// Emit `s` in the theme's colour for `style`, counting only its display width.
///
/// The escape sequences go through `string_as 0` so they occupy no columns, and
/// the text itself is measured by TERMINAL width rather than character count --
/// a wide glyph takes two columns.
pub fn print_styled(
  p : @printer.Printer,
  theme : @colors.Theme,
  style : @colors.Style,
  s : String,
) -> Unit {
  let seq = theme.escape_sequence(style)
  if seq != "" {
    p.string_as(0, seq)
  }
  p.string_as(@unicode.terminal_width(s), s)
  if seq != "" {
    p.string_as(0, theme.reset)
  }
}

///|
/// Emit `m` into `p` as a greedy fill box, so prose reflows at the enclosing
/// layout's width.
pub fn render(p : @printer.Printer, theme : @colors.Theme, m : Message) -> Unit {
  p.hovbox(() => render_doc(p, theme, m))
}

///|
/// A margin wide enough that a hard-broken message still emits one physical
/// line per break. A stray break is harmless: JSON escapes it, so one object
/// still occupies one physical line.
const FLAT_MARGIN : Int = 1_000_000

///|
/// Render flat and ANSI-free, for the JSON and short output formats.
pub fn to_plain_string(m : Message) -> String {
  @printer.run_string(width=FLAT_MARGIN, p => render(p, @colors.no_color, m))
}
