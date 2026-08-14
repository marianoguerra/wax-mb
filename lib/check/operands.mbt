// Checking a construct's operands against the types it wants.
//
// Ported from wax/src/lib-wax/typing.ml. Shared by everything that takes
// several operands -- a call, a `throw`, a struct literal, a table write --
// because they all face the same problem, and it is not the obvious one.
//
// ONE ARGUMENT IS NOT ONE VALUE. An argument that is itself a multi-result call
// supplies several, so `f(g())` where `g` returns two is a two-argument call
// written with one argument. Counting arguments would reject it; counting
// VALUES accepts it, which is why everything here flattens first.

///|
/// One value an operand supplies, with the span to report it at.
///
/// The span is the whole argument's, not the value's, because a value inside a
/// multi-result call has no span of its own -- and pointing at the argument is
/// what the reader can act on anyway.
type Supplied = (@infer.Cell[@infer.InferredType], @basic.Location)

///|
/// Every value a list of operands supplies, in order.
fn flatten_operands(
  args : Array[(Array[@infer.Cell[@infer.InferredType]], @basic.Location)],
) -> Array[Supplied] {
  let out : Array[Supplied] = []
  for a in args {
    let (cells, loc) = a
    for c in cells {
      out.push((c, loc))
    }
  }
  out
}

///|
/// Check one value against the type expected of it.
///
/// `location` is passed through to `subtype` as well as used for the report,
/// because when the expected type is a block result still being inferred the
/// value is RECORDED there with its own branch site -- so a later join failure
/// can point at the branch that delivered the wrong thing rather than at the
/// join.
fn check_subtype(
  info : @type_store.SubtypingInfo,
  diagnostics : @diagnostic.Context,
  location : @basic.Location,
  provided : @infer.Cell[@infer.InferredType],
  expected : @infer.Cell[@infer.InferredType],
  pin? : Bool = true,
  expected_at? : @basic.Location? = None,
) -> Unit {
  if !subtype(info, provided, expected, location=Some(location), pin~) {
    expression_type_mismatch(
      diagnostics,
      location,
      provided,
      expected,
      expected_at~,
    )
  }
}

///|
/// Check a run of values against a run of expected types.
///
/// A count mismatch is reported once and the values are not then checked
/// individually: with the wrong number of them, pairing them up would produce a
/// second, misleading complaint about whichever ones happened to line up.
pub fn check_subtypes(
  info : @type_store.SubtypingInfo,
  diagnostics : @diagnostic.Context,
  location : @basic.Location,
  provided : Array[@infer.Cell[@infer.InferredType]],
  expected : Array[@infer.Cell[@infer.InferredType]],
  pin? : Bool = true,
) -> Unit {
  if provided.length() != expected.length() {
    value_count_mismatch(
      diagnostics,
      location,
      expected=expected.length(),
      provided=provided.length(),
    )
    return
  }
  for i in 0..<provided.length() {
    check_subtype(info, diagnostics, location, provided[i], expected[i], pin~)
  }
}

///|
/// Check a construct's operands against the parameter types it wants.
///
/// Each value is reported at ITS OWN argument's span rather than at the
/// construct's, so a wrong third argument points at the third argument.
pub fn check_operands(
  info : @type_store.SubtypingInfo,
  diagnostics : @diagnostic.Context,
  location : @basic.Location,
  args : Array[(Array[@infer.Cell[@infer.InferredType]], @basic.Location)],
  expected : Array[@infer.Cell[@infer.InferredType]],
) -> Unit {
  let supplied = flatten_operands(args)
  if supplied.length() != expected.length() {
    operand_count_mismatch(
      diagnostics,
      location,
      expected=expected.length(),
      provided=supplied.length(),
    )
    return
  }
  for i in 0..<supplied.length() {
    let (ty, at) = supplied[i]
    check_subtype(info, diagnostics, at, ty, expected[i])
  }
}
