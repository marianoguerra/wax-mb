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
/// A table whose elements have no value to start as, and nothing to fill it
/// with.
pub fn non_nullable_table(
  ctx : @diagnostic.Context,
  location : @basic.Location,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text(
      "A table with a non-nullable element type must have an initializer.",
    ),
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

///|
/// A `#[start]` function that takes or returns something.
///
/// There is nowhere for an argument to come from and nowhere for a result to
/// go: the host calls it on instantiation.
pub fn start_function_signature(
  ctx : @diagnostic.Context,
  location : @basic.Location,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("The start function must have no parameters and no results."),
  )
}

///|
/// An instruction used where a value is expected, that produces none or
/// several.
///
/// Suppressed in error-recovery mode, like `short_stack`: past a syntax error
/// the wrong number of values is usually a cascade from recovery dropping an
/// operand or auto-closing a construct at EOF. Both callers recover with
/// `Error`, so nothing downstream cascades either way, and a genuine arity
/// mistake in intact code still surfaces on a clean re-check.
pub fn not_an_expression(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  n : Int,
) -> Unit {
  if ctx.in_recovery() {
    return
  }
  ctx.report(
    location,
    Error,
    @message.text("An expression is expected here. This instruction returns")
    .sep(@message.int(n))
    .sep(@message.text("values.")),
  )
}

///|
/// An `if` that must produce a value but has no `else`.
pub fn if_without_else(
  ctx : @diagnostic.Context,
  location : @basic.Location,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("This ")
    .sep(@message.code("if"))
    .sep(@message.text(" must produce a value and so requires an "))
    .sep(@message.code("else"))
    .sep(@message.text(" branch.")),
  )
}

///|
/// A block used as an expression that declares parameters.
///
/// Expression position has no stack for them to come from.
pub fn parameterized_block_expression(
  ctx : @diagnostic.Context,
  location : @basic.Location,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text(
      "A block, loop or if used as an expression cannot take parameters.",
    ),
  )
}

///|
/// A `br_if` value that stays on the stack with a type the block's inferred
/// result does not match exactly.
pub fn br_if_result_mismatch(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  loc : @basic.Location,
  result : @infer.Cell[@infer.InferredType],
  ty : @infer.Cell[@infer.InferredType],
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("This ")
    .sep(@message.code("br_if"))
    .sep(
      @message.text(
        " value stays on the stack as the block's result, so its type must match the inferred result exactly; add a result annotation to the block.",
      ),
    ),
    related=[typed_branch_label(loc, ty), typed_branch_label(location, result)],
  )
}

///|
/// A name used where a struct type is required.
pub fn expected_struct_type(
  ctx : @diagnostic.Context,
  location : @basic.Location,
) -> Unit {
  ctx.report(location, Error, @message.text("Expected struct type."))
}

///|
/// A name used where an array type is required.
pub fn expected_array_type(
  ctx : @diagnostic.Context,
  location : @basic.Location,
) -> Unit {
  ctx.report(location, Error, @message.text("Expected array type."))
}

///|
/// A memory offset or alignment that does not fit a 64-bit unsigned integer.
pub fn memory_immediate_too_large(
  ctx : @diagnostic.Context,
  location : @basic.Location,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text(
      "This memory offset or alignment must fit a 64-bit unsigned integer.",
    ),
  )
}

///|
/// A memory offset past what the address type can reach.
pub fn memory_offset_too_large(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  max_offset : UInt64,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("The memory offset should be less than")
    .sep(
      @message.styled(
        Constant,
        "0x" + max_offset.reinterpret_as_int64().to_string(radix=16),
      ),
    )
    .seq(@message.text(".")),
  )
}

///|
/// An alignment claiming more than the access can use.
pub fn memory_align_too_large(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  natural : Int,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("The memory alignment is larger than the natural alignment")
    .sep(@message.int(natural))
    .seq(@message.text(".")),
  )
}

///|
/// An alignment that is not a power of two.
pub fn bad_memory_align(
  ctx : @diagnostic.Context,
  location : @basic.Location,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("The memory alignment should be a power of two."),
  )
}

///|
/// A lane index outside the shape's lanes.
pub fn invalid_lane_index(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  max_lane : Int,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("The lane index should be less than")
    .sep(@message.int(max_lane))
    .seq(@message.text(".")),
  )
}

///|
/// A lane index that is not a literal.
pub fn integer_literal_required(
  ctx : @diagnostic.Context,
  location : @basic.Location,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("Only integer literals are allowed here."),
  )
}

///|
/// A lane-taking memory access written without its `lane:` immediate.
pub fn missing_lane_immediate(
  ctx : @diagnostic.Context,
  location : @basic.Location,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("This memory access needs a")
    .sep(@message.code("lane:"))
    .sep(@message.text("immediate (e.g."))
    .sep(@message.code("lane: 0"))
    .seq(@message.text(").")),
  )
}

///|
/// A qualified intrinsic name used as a value rather than called.
pub fn intrinsic_not_called(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  ns : String,
  name : String,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("The qualified name")
    .sep(@message.code(ns + "::" + name))
    .sep(@message.text("can only be used as a function call.")),
  )
}

///|
/// A labelled argument outside a memory access, which is the only place they
/// mean anything.
pub fn labelled_argument_not_allowed(
  ctx : @diagnostic.Context,
  location : @basic.Location,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("Labelled arguments are only allowed for the")
    .sep(@message.code("offset").seq(@message.text(",")))
    .sep(@message.code("align"))
    .sep(@message.text("and"))
    .sep(@message.code("lane"))
    .sep(@message.text("immediates of a memory access.")),
  )
}

///|
/// A `select` whose two branches have no type in common.
pub fn select_type_mismatch(
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
      "The two branches of this select have no common supertype, so its result type cannot be inferred.",
    ),
    related=[typed_branch_label(loc1, ty1), typed_branch_label(loc2, ty2)],
  )
}

///|
/// An exception tag declared with results.
///
/// A tag describes what is thrown, and a throw does not return, so there is
/// nothing for a result to be.
pub fn tag_with_results(
  ctx : @diagnostic.Context,
  location : @basic.Location,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("An exception tag cannot have result values."),
  )
}

///|
/// A value whose type nobody can name, where one is needed.
pub fn unknown_operand_type(
  ctx : @diagnostic.Context,
  location : @basic.Location,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text(
      "Cannot determine the type of this expression, which is needed to compile this operation.",
    ),
  )
}

///|
/// A field name the receiver's struct type does not declare.
pub fn missing_field(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  name : String,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("There is no field named")
    .sep(@message.ident(name))
    .seq(@message.text(".")),
  )
}

///|
/// A field access on something that is not a struct.
pub fn expected_struct(
  ctx : @diagnostic.Context,
  location : @basic.Location,
) -> Unit {
  ctx.report(location, Error, @message.text("Expected struct."))
}

///|
/// An index into something that is not an array.
pub fn expected_array(
  ctx : @diagnostic.Context,
  location : @basic.Location,
) -> Unit {
  ctx.report(location, Error, @message.text("Expected array."))
}

///|
/// An instruction method written as a field access, without its parentheses.
///
/// `x.sqrt` is almost always `x.sqrt()` mistyped, and saying so is more useful
/// than "there is no field named sqrt".
pub fn method_needs_parentheses(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  meth : String,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.code(meth)
    .sep(
      @message.text(
        "is an instruction method and must be called with parentheses, as",
      ),
    )
    .sep(@message.code(meth + "()"))
    .seq(@message.text(".")),
  )
}

///|
/// A struct literal whose type cannot be worked out.
pub fn cannot_infer_struct_type(
  ctx : @diagnostic.Context,
  location : @basic.Location,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text(
      "Cannot infer the struct type here; add an explicit type, as in",
    )
    .sep(@message.code("{T| ..}"))
    .seq(@message.text(".")),
  )
}

///|
/// A struct literal with the wrong number of fields.
pub fn field_count_mismatch(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  expected~ : Int,
  provided~ : Int,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("This structure provides")
    .sep(@message.int(provided))
    .sep(@message.text("field(s) but"))
    .sep(@message.int(expected))
    .sep(@message.text("was/were expected.")),
  )
}

///|
/// A `..default` construction of a type not every field of which has a zero.
///
/// Reported once for the TYPE, not once per field: the construction as a whole
/// is what cannot be written, and naming every offending field would be a list
/// where one sentence does.
pub fn not_defaultable(
  ctx : @diagnostic.Context,
  location : @basic.Location,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("This type has no default value for all its fields."),
  )
}

///|
/// An array literal whose type cannot be worked out.
pub fn cannot_infer_array_type(
  ctx : @diagnostic.Context,
  location : @basic.Location,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text(
      "Cannot infer the array type here; add an explicit type, as in",
    )
    .sep(@message.code("[T| ..]"))
    .seq(@message.text(".")),
  )
}

///|
/// A cast or test that can never succeed.
///
/// Universal: it is true of the code whatever configuration is being built, so
/// it is reported once rather than per configuration.
pub fn cast_always_fails(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  is_test~ : Bool,
) -> Unit {
  ctx.report(
    location,
    Warning,
    @message.text(
      if is_test {
        "This type test is always false: the value can never have this type."
      } else {
        "This cast always traps: the value can never have this type."
      },
    ),
    warning=Some(CastAlwaysFails),
    universal=true,
  )
}

///|
/// A cast or test whose answer is already known the other way.
pub fn redundant_cast(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  is_test~ : Bool,
) -> Unit {
  ctx.report(
    location,
    Warning,
    @message.text(
      if is_test {
        "This type test is always true: the value already has this type."
      } else {
        "This cast is redundant: the value already has this type."
      },
    ),
    warning=Some(RedundantOperation),
    universal=true,
  )
}

///|
/// A non-null assertion on something that is not a reference.
pub fn expected_ref(
  ctx : @diagnostic.Context,
  location : @basic.Location,
) -> Unit {
  ctx.report(location, Error, @message.text("Expected reference."))
}

///|
/// A string building an `i16` array that is not valid Unicode.
pub fn string_not_unicode(
  ctx : @diagnostic.Context,
  location : @basic.Location,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text(
      "A string building an [i16] array must be a valid Unicode string.",
    ),
  )
}

///|
/// A string literal building an array of something other than bytes or
/// 16-bit code units.
pub fn invalid_string_element_type(
  ctx : @diagnostic.Context,
  location : @basic.Location,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("A string literal can only build an [i8] or [i16] array."),
  )
}

///|
/// A segment whose elements do not fit the array being built from it.
pub fn incompatible_element_type(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  provided : @infer.Cell[@infer.InferredType],
  expected : @infer.Cell[@infer.InferredType],
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("The element type")
    .sep(@message.type_(@infer.to_string(provided)))
    .sep(@message.text("is not compatible with the expected element type"))
    .sep(@message.type_(@infer.to_string(expected)))
    .seq(@message.text(".")),
  )
}

///|
/// A descriptor instruction on a type that declares no descriptor.
pub fn type_without_descriptor(
  ctx : @diagnostic.Context,
  location : @basic.Location,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text(
      "This descriptor instruction requires a type that has a descriptor.",
    ),
  )
}

///|
/// A catch clause whose payload does not fit the handler's branch target.
pub fn catch_target_mismatch(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  provided : @infer.Cell[@infer.InferredType],
  expected : @infer.Cell[@infer.InferredType],
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("Catching this exception provides a value of type")
    .sep(@message.type_(@infer.to_string(provided)))
    .sep(@message.text("but the handler's branch target expects"))
    .sep(@message.type_(@infer.to_string(expected)))
    .seq(@message.text(".")),
  )
}

///|
/// Two dispatch arms sharing a label.
///
/// The labels become distinct blocks in the lowering and key the arm bodies, so
/// two arms with one label would build a single block and lose the other body.
pub fn dispatch_duplicate_arm(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  prev_loc : @basic.Location,
  name : String,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("This dispatch has several cases named")
    .sep(@message.ident(name))
    .seq(@message.text(".")),
    related=[{ loc: prev_loc, message: @message.text("other arm here") }],
  )
}

///|
/// A continuation type used as a cast target.
pub fn invalid_cast_type(
  ctx : @diagnostic.Context,
  location : @basic.Location,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("Continuation types cannot be used in a cast instruction."),
  )
}

///|
/// A cast between types in different hierarchies, which share no value.
pub fn invalid_cast(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  ty : @infer.Cell[@infer.InferredType],
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("This value of type")
    .sep(@message.type_(@infer.to_string(ty)))
    .sep(@message.text("cannot be cast to the target type.")),
  )
}

///|
/// A call whose callee is not a function.
pub fn expected_func(
  ctx : @diagnostic.Context,
  location : @basic.Location,
) -> Unit {
  ctx.report(location, Error, @message.text("Expected function."))
}

///|
/// An argument label the callee does not take.
pub fn unknown_argument_label(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  name : String,
  suggestions? : Array[String] = [],
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("Unknown argument label")
    .sep(@message.ident(name))
    .seq(@message.text(".")),
    hint=did_you_mean(suggestions),
  )
}

///|
/// One argument label given twice.
pub fn duplicate_argument_label(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  prev_loc : @basic.Location,
  name : String,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("The argument label")
    .sep(@message.ident(name))
    .sep(@message.text("is given several times.")),
    related=[{ loc: prev_loc, message: @message.text("previously given here") }],
  )
}

///|
/// A memory immediate written positionally, in the syntax that predates the
/// labels.
pub fn positional_memory_immediate(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  example : String,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text(
      "The static immediates of a memory access must be labelled, e.g.",
    )
    .sep(@message.code(example))
    .seq(@message.text(".")),
  )
}

///|
/// A management call whose method and argument shape match nothing.
pub fn invalid_management_call(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  meth : String,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("Invalid arguments in call to")
    .sep(@message.code(meth))
    .seq(@message.text(".")),
  )
}

///|
/// An atomic access whose alignment is not exactly its natural one.
///
/// Unlike an ordinary access, where the alignment is a promise the engine may
/// ignore, an atomic one must be exactly aligned to be atomic at all.
pub fn atomic_alignment(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  natural : Int,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text(
      "The alignment of an atomic access must be its natural alignment",
    )
    .sep(@message.int(natural))
    .seq(@message.text(".")),
  )
}

///|
/// A stack-switching instruction whose continuation types do not line up.
pub fn stack_switching_type_mismatch(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  descr : String,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("Type mismatch in this stack switching instruction:")
    .sep(@message.text(descr))
    .seq(@message.text(".")),
  )
}

///|
/// An `on` clause attached to something other than a resume.
pub fn on_clause_context(
  ctx : @diagnostic.Context,
  location : @basic.Location,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("An")
    .sep(@message.code("on"))
    .sep(@message.text("handler clause is only allowed on a"))
    .sep(@message.code("resume").seq(@message.text(",")))
    .sep(@message.code("resume_throw"))
    .sep(@message.text("or"))
    .sep(@message.code("resume_throw_ref"))
    .sep(@message.text("call.")),
  )
}

///|
/// An instruction method called on a receiver that has no such operation.
pub fn invalid_method_receiver(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  ty : @infer.Cell[@infer.InferredType],
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("This operation cannot be applied to a value of type")
    .sep(@message.type_(@infer.to_string(ty)))
    .seq(@message.text(".")),
  )
}

///|
/// A qualified name that names no intrinsic.
pub fn unknown_intrinsic(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  ns : String,
  name : String,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("There is no")
    .sep(@message.code(ns + "::" + name))
    .sep(@message.text("intrinsic.")),
  )
}

///|
/// A vector-constant lane that does not fit the shape's width.
pub fn lane_value_out_of_range(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  bits : Int,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("The lane value does not fit in")
    .sep(@message.int(bits))
    .sep(@message.text("bits.")),
  )
}

///|
/// A vector-constant lane that is not a numeric literal.
pub fn number_literal_required(
  ctx : @diagnostic.Context,
  location : @basic.Location,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("Only number literals are allowed here."),
  )
}

///|
/// A `switch` written without its enabling tag.
///
/// Anchored at the METHOD rather than the call expression: a chained
/// `c.switch().switch()` would otherwise report both at the column the chain
/// starts in, two identical messages one on top of the other.
pub fn switch_needs_tag(
  ctx : @diagnostic.Context,
  location : @basic.Location,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("A")
    .sep(@message.code("switch"))
    .sep(@message.text("names its enabling tag as a labelled immediate, e.g."))
    .sep(@message.code("c.switch(x, tag: t)").seq(@message.text("."))),
  )
}

///|
/// A `resume_throw` written without the tag it raises.
pub fn resume_throw_needs_tag(
  ctx : @diagnostic.Context,
  location : @basic.Location,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.code("resume_throw")
    .sep(@message.text("raises a tag applied to its payload, e.g."))
    .sep(@message.code("c.resume_throw(exc(x))").seq(@message.text("."))),
  )
}

///|
/// An `array.copy` between arrays whose elements do not line up.
pub fn incompatible_array_elements(
  ctx : @diagnostic.Context,
  location : @basic.Location,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text(
      "The source and destination array element types are incompatible.",
    ),
  )
}

///|
/// A `#![feature = "..."]` naming something that is not a feature.
pub fn unknown_feature(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  name : String,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("Unknown feature")
    .sep(@message.code(name))
    .seq(@message.text(". Known features:"))
    .sep(@message.text(@feature.all.map(f => f.name()).join(", ")))
    .seq(@message.text(".")),
  )
}

///|
/// A feature the module declares and the command line turned off.
pub fn feature_conflict(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  feature : @feature.Feature,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("This module requires the")
    .sep(@message.text(feature.name()))
    .sep(
      @message.text(
        "feature, which is disabled on the command line; drop --feature",
      ),
    )
    .sep(@message.text(feature.name() + "=off"))
    .seq(@message.text(".")),
  )
}

///|
/// A feature declaration written inside a conditional.
///
/// It states a fact about the WHOLE module, resolved before any branch is
/// specialized, so a guarded one would leave every construct it gates erroring.
pub fn feature_declaration_in_conditional(
  ctx : @diagnostic.Context,
  location : @basic.Location,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("A")
    .sep(@message.code("#![feature = \"…\"]"))
    .sep(
      @message.text(
        "declaration states a fact about the whole module and must appear at the top level, not inside a conditional.",
      ),
    ),
  )
}

///|
/// Likewise for the module name.
pub fn module_name_in_conditional(
  ctx : @diagnostic.Context,
  location : @basic.Location,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("A")
    .sep(@message.code("#![module = \"…\"]"))
    .sep(
      @message.text(
        "name annotation applies to the whole module and must appear at the top level, not inside a conditional.",
      ),
    ),
  )
}

///|
/// A `become` on something that is not a call.
///
/// A stack-switching operation hands control away by its own means; a tail call
/// is a different mechanism and cannot wrap one.
pub fn become_on_stack_switching(
  ctx : @diagnostic.Context,
  location : @basic.Location,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.code("become").sep(
      @message.text("cannot apply to a stack-switching operation."),
    ),
  )
}

///|
/// A local declared by a `let` but never read.
///
/// The quick fix is a zero-width edit inserting `_` at the name's start: a
/// leading underscore is how the language says "deliberately unused", so the fix
/// and the exemption are the same convention seen from two sides.
pub fn unused_local(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  name : String,
) -> Unit {
  ctx.report(
    location,
    Warning,
    @message.text("The local variable")
    .sep(@message.ident(name))
    .sep(@message.text("is never used.")),
    warning=Some(UnusedLocal),
    universal=true,
    edit=Some({ loc: { ..location, end: location.start }, new_text: "_" }),
  )
}

///|
/// A label nothing branches to.
///
/// The quick fix DELETES the label rather than underscoring it, because a label
/// is written as a prefix -- `'l: do { .. }` -- and the whole prefix, colon and
/// following space included, is what has to go. That span can only be found by
/// reading the source, so the fix is offered only when the context carries it.
pub fn unused_label(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  name : String,
) -> Unit {
  let edit = match ctx.source {
    None => None
    Some(src) => {
      let n = src.length()
      // Compared as code units: a space, a tab and a colon are all ASCII, so
      // the unit and the character are the same thing here.
      fn is_ws(c : UInt16) -> Bool {
        c == 32 || c == 9
      }

      let mut i = location.end.cnum
      while i < n && is_ws(src[i]) {
        i = i + 1
      }
      if i < n && src[i] == 58 {
        i = i + 1
        while i < n && is_ws(src[i]) {
          i = i + 1
        }
        Some(
          (
            {
              loc: { ..location, end: { ..location.end, cnum: i } },
              new_text: "",
            } : @diagnostic.Edit),
        )
      } else {
        None
      }
    }
  }
  ctx.report(
    location,
    Warning,
    @message.text("The label")
    .sep(@message.ident(name))
    .sep(@message.text("is never used.")),
    warning=Some(UnusedLabel),
    universal=true,
    edit~,
  )
}

///|
/// A module field defined but never referenced, exported, or started.
pub fn unused_field(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  kind : String,
  name : String,
) -> Unit {
  ctx.report(
    location,
    Warning,
    @message.text("The")
    .sep(@message.text(kind))
    .sep(@message.ident(name))
    .sep(@message.text("is never used.")),
    warning=Some(UnusedField),
    universal=true,
  )
}

///|
/// An imported field never referenced, exported, or started.
pub fn unused_import(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  kind : String,
  name : String,
) -> Unit {
  ctx.report(
    location,
    Warning,
    @message.text("The imported")
    .sep(@message.text(kind))
    .sep(@message.ident(name))
    .sep(@message.text("is never used.")),
    warning=Some(UnusedImport),
    universal=true,
  )
}

///|
/// A mutable global nothing ever assigns.
pub fn unnecessary_mut(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  name : String,
) -> Unit {
  ctx.report(
    location,
    Warning,
    @message.text("The global")
    .sep(@message.ident(name))
    .sep(@message.text("is mutable but is never assigned.")),
    warning=Some(UnnecessaryMut),
    universal=true,
    hint=Some(@message.text("Declare it with 'const' instead of 'let'.")),
  )
}

///|
/// A side-effect-free expression whose result is computed and then dropped.
pub fn unused_result(
  ctx : @diagnostic.Context,
  location : @basic.Location,
) -> Unit {
  ctx.report(
    location,
    Warning,
    @message.text(
      "The result of this expression is discarded, and computing it has no effect.",
    ),
    warning=Some(UnusedResult),
    universal=true,
  )
}

///|
/// A comparison whose answer does not depend on its variable operand.
pub fn tautological_comparison(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  value : Bool,
) -> Unit {
  ctx.report(
    location,
    Warning,
    @message.text("This comparison is always")
    .sep(@message.bool_(value))
    .seq(@message.text(".")),
    warning=Some(TautologicalComparison),
    universal=true,
  )
}

///|
/// A trapping float-to-integer conversion of a constant that is out of range.
pub fn conversion_out_of_range(
  ctx : @diagnostic.Context,
  location : @basic.Location,
) -> Unit {
  ctx.report(
    location,
    Warning,
    @message.text(
      "This conversion always traps: the constant is out of the target type's range.",
    ),
    warning=Some(ConstantTrap),
    universal=true,
  )
}

///|
/// A condition whose value is decided before it is ever evaluated.
pub fn constant_condition(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  value : Bool,
) -> Unit {
  ctx.report(
    location,
    Warning,
    @message.text("This condition is always")
    .sep(@message.bool_(value))
    .seq(@message.text(".")),
    warning=Some(ConstantCondition),
    universal=true,
  )
}

///|
/// An operation that does nothing -- a variable written back to itself.
pub fn redundant_operation(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  message : @message.Message,
) -> Unit {
  ctx.report(
    location,
    Warning,
    message,
    warning=Some(RedundantOperation),
    universal=true,
  )
}

///|
/// An operation inside a `?:` branch that runs whichever branch is chosen.
///
/// A `?:` compiles to a wasm `select`, which evaluates BOTH operands and then
/// picks one -- so a trapping or effectful operation in the branch not taken
/// still happens. The primary caret is on the operation; the secondary explains
/// why it runs at all.
pub fn eager_select(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  select : @basic.Location,
) -> Unit {
  ctx.report(
    location,
    Warning,
    @message.text(
      "This operation is evaluated even when the condition selects the other branch.",
    ),
    warning=Some(EagerSelect),
    universal=true,
    related=[
      {
        loc: select,
        message: @message.text(
          "This '?:' evaluates both branches (it compiles to a 'select').",
        ),
      },
    ],
    hint=Some(
      @message.text(
        "Use an 'if' expression to evaluate only the chosen branch.",
      ),
    ),
  )
}

///|
/// A statement that can never be reached.
///
/// Anchored at the unreachable statement, with a secondary caret pointing back
/// at the instruction that took control away -- which is the one to look at.
pub fn dead_code(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  diverged_at : @basic.Location,
) -> Unit {
  ctx.report(
    location,
    Warning,
    @message.text("This code is unreachable."),
    warning=Some(DeadCode),
    universal=true,
    related=[
      {
        loc: diverged_at,
        message: @message.text("Control never returns from here."),
      },
    ],
  )
}

///|
/// A shift whose constant count is at least the operand's width.
///
/// Wasm masks the count modulo the width, so the shift silently becomes a
/// different one -- which is very unlikely to be what was meant. The hint says
/// what it actually shifts by.
pub fn shift_overflow(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  width : Int,
  count : Int64,
) -> Unit {
  ctx.report(
    location,
    Warning,
    @message.text("The shift count")
    .sep(@message.uint64(count))
    .sep(@message.text("is at least the operand width ("))
    .seq(@message.int(width))
    .seq(@message.text(" bits).")),
    warning=Some(ShiftOverflow),
    universal=true,
    hint=Some(
      @message.text("Wasm masks the count modulo")
      .sep(@message.int(width))
      .seq(@message.text(","))
      .sep(@message.text("shifting by"))
      .sep(
        @message.uint64(
          (count.reinterpret_as_uint64() % width.to_uint64()).reinterpret_as_int64(),
        ),
      )
      .sep(@message.text("instead.")),
    ),
  )
}

///|
/// An integer division or remainder by a constant zero.
pub fn division_by_zero(
  ctx : @diagnostic.Context,
  location : @basic.Location,
) -> Unit {
  ctx.report(
    location,
    Warning,
    @message.text("This integer division or remainder by zero always traps."),
    warning=Some(ConstantTrap),
    universal=true,
  )
}

///|
/// A string carrying a bidirectional control character.
///
/// These reorder how the text DISPLAYS without changing a byte of it, so what a
/// reader sees and what runs can differ -- the "Trojan Source" attack.
pub fn confusable_unicode(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  codepoint : Int,
) -> Unit {
  let hex = codepoint.to_string(radix=16).to_upper()
  let padded = if hex.length() < 4 {
    "0".repeat(4 - hex.length()) + hex
  } else {
    hex
  }
  ctx.report(
    location,
    Warning,
    @message.text(
      "This string contains a bidirectional control character (U+\{padded}) that can make the displayed text read differently than it runs.",
    ),
    warning=Some(ConfusableUnicode),
    universal=true,
  )
}

///|
/// Two operators whose relative precedence is easy to misremember, mixed
/// without parentheses.
///
/// The printer parenthesises exactly these mixes, so re-printed or decompiled
/// Wax stays quiet under the lint -- which is the property that makes it safe to
/// have at all.
pub fn precedence(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  inner : @basic.Location,
  outer_kind : String,
  inner_kind : String,
  edit? : @diagnostic.Edit? = None,
) -> Unit {
  ctx.report(
    location,
    Warning,
    @message.text("Operator precedence here is easy to misread."),
    warning=Some(Precedence),
    universal=true,
    related=[
      {
        loc: inner,
        message: @message.text("This")
        .sep(@message.text(inner_kind))
        .sep(@message.text("operator binds tighter than the"))
        .sep(@message.text(outer_kind))
        .sep(@message.text("operator.")),
      },
    ],
    hint=Some(@message.text("Add parentheses to make the grouping explicit.")),
    edit~,
  )
}

///|
/// Two exports of the same name.
pub fn duplicated_export(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  prev_loc : @basic.Location,
  name : String,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("There is already an export of name")
    .sep(@message.code(name))
    .seq(@message.text(".")),
    related=[
      { loc: prev_loc, message: @message.text("previously exported here") },
    ],
  )
}

///|
/// More than one start function in one configuration.
pub fn multiple_start(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  prev_loc : @basic.Location,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("A module can have at most one start function."),
    related=[
      { loc: prev_loc, message: @message.text("other start function here") },
    ],
  )
}

///|
/// More than one module name annotation.
pub fn multiple_module(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  prev_loc : @basic.Location,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("A module can have at most one name annotation."),
    related=[
      { loc: prev_loc, message: @message.text("other name annotation here") },
    ],
  )
}

///|
/// A memory or table whose size exceeds what its address type can index.
pub fn limit_too_large(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  kind : String,
  max : UInt64,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("The")
    .sep(@message.text(kind))
    .sep(@message.text("size is too large. It should be less than"))
    .sep(@message.styled(Constant, "0x" + hex_u64(max)))
    .seq(@message.text(".")),
  )
}

///|
/// A maximum size below the minimum.
pub fn limit_mismatch(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  kind : String,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("The")
    .sep(@message.text(kind))
    .sep(@message.text("maximum size should be larger than the minimal size.")),
  )
}

///|
/// A page size that is neither the default nor one byte.
pub fn invalid_page_size(
  ctx : @diagnostic.Context,
  location : @basic.Location,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("The custom page size must be 1 or 65536."),
  )
}

///|
/// A shared memory with no maximum.
pub fn shared_memory_without_max(
  ctx : @diagnostic.Context,
  location : @basic.Location,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("A shared memory must have a maximum size."),
  )
}

///|
/// An annotation this port does not know.
pub fn unknown_annotation(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  name : String,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("Unknown annotation")
    .sep(@message.code(name))
    .seq(@message.text(".")),
  )
}

///|
/// An annotation whose value is the wrong shape, or missing, or present when
/// it should not be.
pub fn annotation_value_mismatch(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  name : String,
  expected : String,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("The")
    .sep(@message.text(name))
    .sep(@message.text("annotation expects"))
    .sep(@message.text(expected))
    .seq(@message.text(".")),
  )
}

///|
/// An annotation on an entity it means nothing for.
pub fn annotation_not_allowed(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  name : String,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("The")
    .sep(@message.text(name))
    .sep(@message.text("annotation is not allowed here.")),
  )
}

///|
/// A conditional guard on an annotation that cannot be conditional.
pub fn guard_not_allowed(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  name : String,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text(
      "A conditional guard is only allowed on an export or start annotation, not on",
    )
    .sep(@message.text(name))
    .seq(@message.text(".")),
  )
}

///|
/// A second import-name annotation on one declaration.
pub fn multiple_import(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  prev_loc : @basic.Location,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("An import can have at most one import-name annotation."),
    related=[
      {
        loc: prev_loc,
        message: @message.text("other import-name annotation here"),
      },
    ],
  )
}

///|
/// An optimization priority with no compilation priority to sit beside.
pub fn priority_required(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  which : String,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("The")
    .sep(@message.code("#[" + which + "]"))
    .sep(@message.text("attribute needs a"))
    .sep(@message.code("#[priority = n]"))
    .seq(@message.text(".")),
  )
}

///|
/// Both spellings of an optimization priority on one function.
pub fn conflicting_optimization(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  prev_loc : @basic.Location,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("A function states at most one optimization priority:")
    .sep(@message.code("#[optimization = n]"))
    .sep(@message.text("or"))
    .sep(@message.code("#[run_once]"))
    .seq(@message.text(", not both.")),
    related=[{ loc: prev_loc, message: @message.text("the other one here") }],
  )
}

///|
/// A call-target hint on a call whose target is already known.
pub fn call_targets_direct_call(
  ctx : @diagnostic.Context,
  location : @basic.Location,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text(
      "A call-target hint may only prefix an indirect call. This callee is a function, so the call is direct and its target is already known.",
    ),
  )
}

///|
/// Call-target frequencies that add up to more than everything.
pub fn call_targets_over_100(
  ctx : @diagnostic.Context,
  location : @basic.Location,
  total : Int,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text("The call-target frequencies add up to")
    .sep(@message.text(total.to_string()))
    .seq(@message.text("%, more than 100%."))
    .sep(
      @message.text(
        "A shortfall is how the hint says other, unlisted targets take the remainder.",
      ),
    ),
  )
}

///|
/// A cast to a continuation type that is not already a no-op.
pub fn cont_cast_not_ascription(
  ctx : @diagnostic.Context,
  location : @basic.Location,
) -> Unit {
  ctx.report(
    location,
    Error,
    @message.text(
      "A cast to a continuation type is a compile-time ascription: the operand's type must already be a subtype of the target, as there is no runtime continuation cast.",
    ),
    hint=Some(
      @message.text(
        "Give the value a declared continuation type where it is introduced (a parameter, local or block-result annotation).",
      ),
    ),
  )
}
