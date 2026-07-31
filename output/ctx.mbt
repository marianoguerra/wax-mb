// The Wax formatter's printing context.
//
// Ported from wax/src/lib-wax/output.ml. The reference threads a
// Styled_printer, which carries a colour theme; Wax output to a pipe has colour
// off, and `-f wax` -- the path oracle 1 compares -- is always to a pipe or a
// file. So styling is a no-op here and the "styles" survive only as names,
// documenting what each atom IS for the day a coloured renderer wants them.

///|
/// Target line width for Wax output: the Rust Style Guide's default of 100.
///
/// The printer's own default is 78, which is the WebAssembly-text width. Every
/// Wax render must go through `run_string` below, or it silently reflows to the
/// wrong width.
pub let width : Int = 100

///|
/// The indentation step.
pub let indent_level : Int = 4

///|
/// The printing context.
///
/// `locate` extracts a source span from a node's annotation, to look up its
/// trivia. It returns None when printing a typed AST for a diagnostic, where
/// there are no comments to attach.
pub struct Ctx[Info] {
  p : @printer.Printer
  /// The palette styled atoms are rendered with.
  theme : @colors.Theme
  trivia : @trivia.Table
  /// The dry pass fills this instead of printing; see `associate`.
  collect : @trivia.Locations?
  locate : (Info) -> @basic.Location?
}

///|
pub fn Ctx::new(
  p : @printer.Printer,
  trivia~ : @trivia.Table,
  collect? : @trivia.Locations? = None,
  locate? : (@basic.Location) -> @basic.Location? = l => Some(l),
  theme? : @colors.Theme = @colors.no_color,
) -> Ctx[@basic.Location] {
  { p, theme, trivia, collect, locate }
}

///|
/// Emit `s` in the theme's colour for `style`.
///
/// The escape sequences go through `string_as 0`: they occupy no columns, so
/// colouring never changes a line-breaking decision. Uncoloured themes emit no
/// sequence at all rather than an empty one.
pub fn[Info] Ctx::styled(self : Ctx[Info], style : Style, s : String) -> Unit {
  let seq = self.theme.escape_sequence(style)
  if seq != "" {
    self.p.string_as(0, seq)
  }
  self.p.string(s)
  if seq != "" {
    self.p.string_as(0, self.theme.reset)
  }
}

///|
pub fn[Info] Ctx::punct(self : Ctx[Info], s : String) -> Unit {
  self.styled(Punctuation, s)
}

///|
pub fn[Info] Ctx::op(self : Ctx[Info], s : String) -> Unit {
  self.styled(Operator, s)
}

///|
pub fn[Info] Ctx::kw(self : Ctx[Info], s : String) -> Unit {
  self.styled(Keyword, s)
}

///|
pub fn[Info] Ctx::typ(self : Ctx[Info], s : String) -> Unit {
  self.styled(Type, s)
}

///|
pub fn[Info] Ctx::ident(self : Ctx[Info], s : String) -> Unit {
  self.styled(Identifier, s)
}

///|
pub fn[Info] Ctx::constant(self : Ctx[Info], s : String) -> Unit {
  self.styled(Constant, s)
}

///|
pub fn[Info] Ctx::attr(self : Ctx[Info], s : String) -> Unit {
  self.styled(Attribute, s)
}

///|
pub fn[Info] Ctx::str(self : Ctx[Info], s : String) -> Unit {
  self.styled(Str, s)
}

///|
/// A declaration terminator `;`, held past a deferred trailing comment so it
/// sits before the comment (`const x = v; // c`) rather than dangling on its
/// own line after it -- as the block-statement `;` and list `,` separators
/// already do.
pub fn[Info] Ctx::semicolon(self : Ctx[Info]) -> Unit {
  self.p.with_held_eol(() => self.punct(";"))
}

///|
pub fn[Info] Ctx::space(self : Ctx[Info]) -> Unit {
  self.p.space()
}

///|
pub fn[Info] Ctx::cut(self : Ctx[Info]) -> Unit {
  self.p.cut()
}

///|
pub fn[Info] Ctx::newline(self : Ctx[Info]) -> Unit {
  self.p.newline()
}

///|
/// Lay `f` out at the Wax width.
pub fn run_string(f : (@printer.Printer) -> Unit) -> String {
  @printer.run_string(f, width~)
}
