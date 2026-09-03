// The diagnostics the name tables raise.
//
// Ported from the `Error` module at the head of wax/src/lib-wax/typing.ml.
// Only the ones a table itself emits live here; the rest are in
// marianoguerra/wax/check, which cannot be imported from this side of the
// dependency.

///|
/// A name declared twice under assumptions that can hold together.
///
/// The kind named is the PREVIOUS declaration's, not this one's: what matters
/// is what the name is already taken by. The two need not agree -- a `memory m`
/// and a `table m` share one name space -- and hearing "a memory named 'm' is
/// already bound" at the table is the whole answer.
fn name_already_bound(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  prev_loc : @basic.Location,
  kind : String,
  name : String,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("A")
    .sep(@message.text(kind))
    .sep(@message.text("named"))
    .sep(@message.ident(name))
    .sep(@message.text("is already bound.")),
    related=[
      { loc: prev_loc, message: @message.text("previously bound here"), },
    ],
  )
}
