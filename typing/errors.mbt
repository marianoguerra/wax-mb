// The checker's diagnostics.
//
// Ported from the `Error` module at the head of wax/src/lib-wax/typing.ml,
// which is a thousand lines of them. They are gathered in one place there and
// here for the same reason: oracle 3 compares the wording, so a message written
// twice is a message that can differ from itself.
//
// This grows as the checker does; only what has a caller is here.

///|
/// A construct whose proposal is not enabled.
///
/// Reported rather than fatal: checking continues, so one disabled feature does
/// not hide every error after it.
pub fn feature_disabled(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  feature : @feature.Feature,
) -> Unit {
  let n = feature.name()
  ctx.report(
    location,
    Error,
    @message.text("This uses the")
    .sep(@message.text(n))
    .sep(@message.text("feature, which is not enabled; pass --feature"))
    .sep(@message.text(n))
    .seq(@message.text(".")),
  )
}

///|
/// Two fields of one struct sharing a name.
///
/// Carries the other one as a related label, because "which other one" is the
/// first thing anyone asks.
pub fn duplicated_field(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  prev_loc : @basic.Location,
  name : String,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("Several fields have the same name")
    .sep(@message.ident(name))
    .seq(@message.text(".")),
    related=[{ loc: prev_loc, message: @message.text("other field here") }],
  )
}

///|
/// Two parameters of one function sharing a name.
pub fn duplicated_parameter(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  prev_loc : @basic.Location,
  name : String,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("Several parameters have the same name")
    .sep(@message.ident(name))
    .seq(@message.text(".")),
    related=[{ loc: prev_loc, message: @message.text("other parameter here") }],
  )
}
