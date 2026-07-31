// Rendering a whole module: the two-pass entry point.

///|
/// Format a parsed module as Wax source.
///
/// TWO PASSES, and they are not optional. The first runs the printer with
/// output discarded, purely to record which spans it looks up; `associate` then
/// restricts comment attachment to exactly those. Attaching first and printing
/// second would let a comment land on a node the printer skips, and vanish.
pub fn render(m : @ast.LocModule, trivia_ctx : @trivia.Context) -> String {
  let (table, tail) = @trivia.associate(trivia_ctx, only => {
    @printer.run_discard(p => {
      let dry = Ctx::new(p, trivia=@trivia.Table::empty(), collect=Some(only))
      dry.module_(m, [])
    })
  })
  run_string(p => {
    let ctx = Ctx::new(p, trivia=table)
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
  self.p.vbox(() => {
    for f in m {
      self.modulefield(f)
      self.newline()
    }
    // Trailing comments belong to no field; without this they would be lost.
    self.print_trivia(@trivia.drop_trailing_blank_lines(tail))
  })
}
