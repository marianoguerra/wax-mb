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

///|
/// Values left on the stack, each with a caret on it.
///
/// A caret per value rather than one on the enclosing construct, which may be
/// the whole function: the reader needs to know WHICH values, and a span around
/// all of them says nothing.
pub fn leftover_values(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  related : Array[@diagnostic.Label],
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text(
      if related.is_empty() {
        "This value remains on the stack."
      } else {
        "These values remain on the stack."
      },
    ),
    related~,
  )
}

///|
/// Values left on the stack, none of which can be pointed at.
///
/// They are still real values -- they just carry an error-recovery placeholder
/// location rather than a source span -- so name the construct and list what is
/// there instead of saying nothing.
pub fn non_empty_stack(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  rendered : String,
) -> Unit {
  ctx.report(
    { start: location.end, end: location.end },
    Error,
    @message.text("Some values remain on the stack:")
    .seq(@message.text(rendered))
    .seq(@message.text(".")),
  )
}

///|
/// A local read before it holds a value.
///
/// Only a non-nullable reference can be in this state: everything else has a
/// zero value to start as.
pub fn uninitialized_local(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  name : String,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("The local variable")
    .sep(@message.ident(name))
    .sep(@message.text("has not been initialized.")),
  )
}

///|
/// The "did you mean" hint, or nothing when there is nothing close enough.
fn did_you_mean(suggestions : Array[String]) -> @message.Message? {
  if suggestions.is_empty() {
    return None
  }
  Some(
    @message.text("Did you mean")
    .sep(@message.enumerate(suggestions.map(@message.ident), conj="or"))
    .seq(@message.text("?")),
  )
}

///|
/// A name nothing binds.
///
/// Suppressed in error-recovery mode. Checking a best-effort AST past syntax
/// errors, a name is often unbound only because the construct that would bind
/// it was dropped at a sync boundary -- recovery drops spans rather than
/// leaving a placeholder -- so the report is a cascade from a syntax error the
/// caller has already told the reader about. The use still recovers as an
/// error, so nothing downstream cascades either.
pub fn unbound_name(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  kind : String,
  name : String,
  suggestions? : Array[String] = [],
) -> Unit {
  if ctx.in_recovery() {
    return
  }
  ctx.report(
    location,
    Error,
    @message.text("The")
    .sep(@message.text(kind))
    .sep(@message.ident(name))
    .sep(@message.text("is not bound.")),
    hint=did_you_mean(suggestions),
  )
}

///|
/// A write to something that cannot be written.
pub fn immutable(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  what : String,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("This")
    .sep(@message.text(what))
    .sep(@message.text("is immutable and cannot be assigned.")),
  )
}

///|
/// A write to something that is not a variable at all -- a function, say.
pub fn not_assignable(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  name : String,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.ident(name).sep(@message.text("cannot be assigned.")),
  )
}

///|
/// An operator applied to operands it has no meaning for.
pub fn binop_type_mismatch(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  ty1 : @infer.Cell[@infer.InferredType],
  ty2 : @infer.Cell[@infer.InferredType],
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("This operator cannot be applied to operands of types")
    .sep(@message.type_(@infer.to_string(ty1)))
    .sep(@message.text("and"))
    .sep(@message.type_(@infer.to_string(ty2)))
    .seq(@message.text(".")),
  )
}

///|
/// An instruction given the wrong number of operands.
pub fn operand_count_mismatch(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  expected~ : Int,
  provided~ : Int,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("This instruction expects")
    .sep(@message.int(expected))
    .sep(@message.text("operand(s) but"))
    .sep(@message.int(provided))
    .sep(@message.text("was/were provided.")),
  )
}

///|
/// An instruction that leaves the wrong number of values.
///
/// The counterpart of `operand_count_mismatch` on the other side: that one is
/// about what an instruction was GIVEN, this about what it PRODUCED.
pub fn value_count_mismatch(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  expected~ : Int,
  provided~ : Int,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("This instruction provides")
    .sep(@message.int(provided))
    .sep(@message.text("value(s) but"))
    .sep(@message.int(expected))
    .sep(@message.text("was/were expected.")),
  )
}

///|
/// A related label naming a value's type at its own span.
///
/// Used where two values disagree and the reader needs to see both -- the
/// message says what went wrong, and each label says what that particular value
/// was.
pub fn typed_branch_label(
  location : @basic.Location,
  ty : @infer.Cell[@infer.InferredType],
) -> @diagnostic.Label {
  { loc: location, message: @message.type_(@infer.to_string(ty)) }
}

///|
/// Values reaching one block exit that have no common type.
pub fn block_exit_type_mismatch(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  loc1 : @basic.Location,
  loc2 : @basic.Location,
  ty1 : @infer.Cell[@infer.InferredType],
  ty2 : @infer.Cell[@infer.InferredType],
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text(
      "The values reaching this block's exit have no common supertype, so its result type cannot be inferred.",
    ),
    related=[typed_branch_label(loc1, ty1), typed_branch_label(loc2, ty2)],
  )
}

///|
/// A type declaration taking one of the built-in names.
///
/// `T::` extends to declared types, so the `::` left-hand side is one namespace
/// shared by the intrinsics and user types -- and the built-ins have to stay
/// unambiguous there.
pub fn reserved_type_name(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  name : String,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.ident(name).sep(@message.text("is a reserved built-in type name.")),
  )
}

///|
/// A `..` splice in a struct that inherits from nothing.
pub fn splice_without_supertype(
  ctx : @diagnostic.Context,
  location : @basic.Location,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.code("..")
    .sep(@message.text(" requires a supertype to inherit fields from (write "))
    .sep(@message.code("type t: super = { .., ... }"))
    .sep(@message.text(").")),
  )
}

///|
/// A `..` splice whose supertype is not a struct, so there are no fields to
/// inherit.
pub fn splice_non_struct(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  name : String,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.code("..")
    .sep(@message.text(" can only inherit fields from a struct supertype;"))
    .sep(@message.ident(name))
    .sep(@message.text("is not a struct.")),
  )
}

///|
/// A `descriptor` or `describes` clause naming a type outside the group.
///
/// The two types have to name each other, and a reference out of the group
/// cannot be reciprocated -- the type it names was already closed.
pub fn descriptor_outside_rec_group(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  described~ : Bool,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("The")
    .sep(@message.text(if described { "described" } else { "descriptor" }))
    .sep(@message.text("type must be in the same recursion group.")),
  )
}

///|
/// One half of a descriptor pair without the other.
pub fn descriptor_not_reciprocal(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  described~ : Bool,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text(
      if described {
        "This descriptor does not describe the type it is attached to."
      } else {
        "The descriptor of this type does not describe it back."
      },
    ),
  )
}

///|
/// A descriptor declared before the type it describes.
pub fn forward_use_of_described(
  ctx : @diagnostic.Context,
  location : @basic.Location,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("A described type must be declared before its descriptor."),
  )
}

///|
/// A descriptor clause on something that is not a struct.
pub fn descriptor_not_struct(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  described~ : Bool,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("A")
    .sep(@message.text(if described { "described" } else { "descriptor" }))
    .sep(@message.text("type must be a struct type.")),
  )
}

///|
/// A declaration naming a type that is not a function type.
pub fn expected_func_type(
  ctx : @diagnostic.Context,
  location : @basic.Location,
) -> Unit {
  ctx.report(location, Error, @message.text("Expected function type."))
}

///|
/// A declaration giving both a type name and an inline signature that disagree.
pub fn inline_function_type_mismatch(
  ctx : @diagnostic.Context,
  location : @basic.Location,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text(
      "The inline function type does not match the type definition.",
    ),
  )
}
