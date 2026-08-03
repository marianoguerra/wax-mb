// Rendering a whole module: the two-pass entry point.

///|
/// Format a parsed module as Wax source.
///
/// TWO PASSES, and they are not optional. The first runs the printer with
/// output discarded, purely to record which spans it looks up; `associate` then
/// restricts comment attachment to exactly those. Attaching first and printing
/// second would let a comment land on a node the printer skips, and vanish.
/// The dry pass takes no theme: it emits nothing, so colouring it would only
/// cost work. Width is irrelevant there too -- the traversal looks up the same
/// spans however the lines break.
pub fn render(
  m : @ast.LocModule,
  trivia_ctx : @trivia.Context,
  theme? : @colors.Theme = @colors.no_color,
) -> String {
  render_with(m, trivia_ctx, theme~, lay=run_string)
}

///|
/// As `render`, but laid out by `lay` rather than by `@printer`'s own engine.
///
/// Only the LAYOUT is swappable: the two passes, the trivia association and
/// every printing decision above are the formatter's and stay put. That is the
/// whole point -- an alternative engine has to be judged on the same document,
/// not on a re-derived one. `tools/ppdiff` uses this to hold `printer_pp` up
/// against `printer` over the corpus.
pub fn render_with(
  m : @ast.LocModule,
  trivia_ctx : @trivia.Context,
  theme? : @colors.Theme = @colors.no_color,
  lay~ : ((@printer.Printer) -> Unit) -> String,
) -> String {
  let (table, tail) = @trivia.associate(trivia_ctx, only => {
    @printer.run_discard(p => {
      let dry = Ctx::new(p, trivia=@trivia.Table::empty(), collect=Some(only))
      dry.module_(m, [])
    })
  })
  lay(p => {
    let ctx = Ctx::new(p, trivia=table, theme~)
    ctx.module_(m, tail)
  })
}

///|
/// Print a module's fields, then any trailing trivia no field owned.
pub fn Ctx::module_(
  self : Ctx[@basic.Location],
  m : @ast.LocModule,
  tail : Array[@trivia.Entry],
) -> Unit {
  // An hvbox with SOFT separators, not a vbox with hard newlines: a module
  // short enough to fit the width stays on one line, exactly as the reference
  // prints it. Being all-or-nothing, anything longer puts every field on its
  // own line.
  self.p.hvbox(() => {
    self.list(m, f => self.modulefield(f), sep=() => self.space())
  })
  // Trailing comments belong to no field; without this they would be lost.
  self.print_trivia(@trivia.drop_trailing_blank_lines(tail))
}
