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

///|
/// Not enough values on the stack.
///
/// Suppressed in error-recovery mode. An underflow while checking a best-effort
/// AST is usually a cascade from a value-producing construct that recovery
/// dropped at a sync boundary, not a real mistake -- and the callers recover
/// with `Error`, so nothing downstream cascades either way. A genuine underflow
/// in intact code still surfaces on a clean re-check once the syntax errors are
/// fixed.
pub fn short_stack(
  ctx : @diagnostic.Context,
  kind : StackKind,
  location : @basic.Location,
  actual : Int,
  expected : Int,
) -> Unit {
  if ctx.in_recovery() {
    return
  }
  let values = match kind {
    Input => "argument(s)"
    Output => "returned value(s)"
    Holes => "value(s)"
  }
  ctx.report(
    location,
    Error,
    @message.text("Expecting ")
    .seq(@message.int(expected))
    .sep(@message.text(values))
    .sep(@message.text("from the stack, but there are"))
    .sep(@message.int(actual))
    .seq(@message.text(".")),
  )
}

///|
/// An argument of the wrong type, reported against the instruction because the
/// value itself has no span worth pointing at.
pub fn type_mismatch(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  current : Int,
  provided : @infer.Cell[@infer.InferredType],
  expected : @infer.Cell[@infer.InferredType],
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("Argument")
    .sep(@message.int(current))
    .sep(@message.text("should have type"))
    .sep(@message.type_(@infer.to_string(expected)))
    .sep(@message.text("but has type"))
    .sep(@message.type_(@infer.to_string(provided)))
    .seq(@message.text(".")),
  )
}

///|
/// A value of the wrong type, reported at the value -- which is where the
/// reader can do something about it.
pub fn expression_type_mismatch(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  provided : @infer.Cell[@infer.InferredType],
  expected : @infer.Cell[@infer.InferredType],
  expected_at? : @basic.Location? = None,
) -> Unit {
  let related = match expected_at {
    None => []
    Some(loc) =>
      [({ loc, message: @message.text("expected here") } : @diagnostic.Label)]
  }
  ctx.report(
    location,
    Error,
    @message.text("This expression has type")
    .sep(@message.type_(@infer.to_string(provided)))
    .sep(@message.text("but is expected to have type"))
    .sep(@message.type_(@infer.to_string(expected)))
    .seq(@message.text(".")),
    related~,
  )
}
