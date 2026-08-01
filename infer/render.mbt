// Rendering an inferred type for a diagnostic.
//
// Ported from `output_inferred_type_styled` / `inferred_type_string` in
// wax/src/lib-wax/infer.ml. The formatter already knows how to print a value
// type; what is here is the rest of the lattice, which has no source syntax:
// the flexible literal families print by FAMILY (`number`, `int`, `large
// number`, `float`), so a diagnostic distinguishes them from each other and
// from a concrete width.

///|
/// Render an inferred type through the formatter's context, so it picks up the
/// diagnostic's colour theme and width.
pub fn[Info] render(ctx : @output.Ctx[Info], cell : Cell[InferredType]) -> Unit {
  match cell.get() {
    // A block result still under inference renders as the annotation being
    // tested -- the type a mismatched reader was checked against -- not `any`.
    Collecting({ declared: Some(d), .. }) => render(ctx, d)
    Unknown | Error | Collecting(_) => ctx.typ("any")
    UnknownRef => ctx.typ("&_")
    Null => ctx.typ("null")
    Number => ctx.typ("number")
    Int => ctx.typ("int")
    LargeInt => ctx.typ("large number")
    Int16 => ctx.typ("i16")
    Int8 => ctx.typ("i8")
    Float => ctx.typ("float")
    // A synthesized reference type has a name that would mean nothing to the
    // reader, so what is printed is the composite type it stands for.
    Valtype({ anon_comptype: Some(c), .. }) => ctx.comptype(c)
    Valtype(v) => ctx.valtype(v.typ)
  }
}

///|
/// Render an inferred type as plain text.
///
/// For a hover string or a debug dump. A diagnostic uses `render` instead, so
/// that it shares the message's theme.
pub fn to_string(cell : Cell[InferredType]) -> String {
  @output.run_string(p => {
    let ctx = @output.Ctx::new(p, trivia=@trivia.Table::empty())
    render(ctx, cell)
  })
}
