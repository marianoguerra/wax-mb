// Entering a function.
//
// Ported from `functions` in wax/src/lib-wax/typing.ml.
//
// Everything a body needs in scope before its first instruction is checked: the
// declared type resolved, the parameters bound as locals, the result types as
// cells the `return`s and the fall-through will be checked against.
//
// The one subtlety is what happens when the signature did NOT resolve. Its
// failure was already reported at registration, so re-resolving it here would
// say the same thing twice -- but the body still has to be checked, and it
// needs types to check against. So the source signature is resolved again with
// diagnostics MUTED, and whatever fails again becomes `Error` poison: a poison
// local, an `Error` result cell. The body's own mistakes still surface; the
// ones that follow from the bad signature do not.

///|
/// Run `f` on a fresh empty stack, reporting whatever is left on it, and
/// restore the enclosing stack.
///
/// The stack a function body runs on starts empty and must end empty. Same for
/// a block: `Operands::with_empty` is what keeps a block's operands from
/// leaking in or out, and this adds the report.
fn[A] with_empty_stack(
  ops : Operands,
  diagnostics : @diagnostic.Context,
  location : @basic.Location,
  f : () -> A,
) -> A {
  let (result, inner) = ops.with_empty(f)
  report_leftovers(inner, diagnostics, location, render_stack)
  result
}

///|
/// The function type a definition declares, or `None` if it did not resolve.
///
/// Looked up WITHOUT marking the function name used: a definition site is not a
/// reference to itself, so the unused-declaration lint can still flag a
/// function nothing calls. The type name it yields IS a reference, and is
/// marked as one.
fn declared_functype(
  ctx : @typing_env.ModuleContext,
  name : @ast.Ident,
) -> @ast.FuncType? {
  // A poison entry -- `Some(None)`, a signature that failed at registration --
  // yields `None` here, and the body is checked against the muted re-resolution
  // instead.
  guard ctx.functions.find_no_mark(name.name) is Some(Some((_, tname, _))) else {
    return None
  }
  guard find(ctx.types, ctx.diagnostics, { name: tname, loc: name.loc, })
    is Some((_, def)) else {
    return None
  }
  match def.typ {
    Func(ft) => Some(ft)
    _ => {
      expected_func_type(ctx.diagnostics, name.loc)
      None
    }
  }
}

///|
/// A `#[start]` function must take nothing and return nothing.
///
/// There is nowhere for an argument to come from and nowhere for a result to
/// go: the start function is called by the host on instantiation.
fn check_start_signature(
  ctx : @typing_env.ModuleContext,
  name : @ast.Ident,
  attributes : Array[@ast.Attribute],
  ft : @ast.FuncType,
) -> Unit {
  let has_start = attributes.iter().any(a => a.attr_name == "start")
  if has_start && !(ft.params.is_empty() && ft.results.is_empty()) {
    start_function_signature(ctx.diagnostics, name.loc)
  }
}

///|
/// Establish a function's scope: its origin, parameters, and result types.
///
/// Returns the result cells, which are both the function's `return` targets and
/// the types its fall-through is checked against -- the caller opens the
/// outermost control frame with them.
///
/// `label_decls` and `assigned_locals` are collected by the syntactic lints,
/// which are a later stage; they are parameters rather than gathered here so
/// that when those land the caller fills them without this changing.
pub fn enter_function_scope(
  ctx : @typing_env.ModuleContext,
  name : @ast.Ident,
  sign : @ast.FuncType?,
  attributes : Array[@ast.Attribute],
  label_decls? : Array[@ast.Ident] = [],
  assigned_locals? : Map[String, Unit] = Map([]),
) -> Array[@infer.Cell[@infer.InferredType]] {
  // Attribute everything this definition resolves -- its declared type as much
  // as its body -- to the function itself, so nothing a dead function names
  // looks externally referenced.
  ctx.origin.val = FromFunction(name.name)
  let declared = declared_functype(ctx, name)
  // Where the muting happens. The reference builds a whole shadow context for
  // this; here the resolvers take their diagnostics sink as an argument, so
  // choosing the sink is the entire difference.
  let sink = match declared {
    Some(_) => ctx.diagnostics
    None => @diagnostic.collector(parent=Some(ctx.diagnostics))
  }
  if declared is Some(ft) {
    check_start_signature(ctx, name, attributes, ft)
  }
  // The results of a type that resolved always resolve; only the muted path can
  // fail, and there a failure recovers as `Error` poison.
  let results = match declared {
    Some(ft) => ft.results
    None =>
      match sign {
        Some(s) => s.results
        None => []
      }
  }
  let return_types = results.map(t => {
    match internalize(ctx.type_context, sink, t) {
      Some(c) => c
      None => @infer.Cell::make(@infer.InferredType::Error)
    }
  })
  ctx.enter_function(return_types~, label_decls~, assigned_locals~)
  // Parameters come from the SOURCE signature, not the resolved type: only the
  // source has their names. A parameter whose type does not resolve still binds
  // its name, as a poison local read as `Error`, so the body's uses of it do
  // not cascade.
  if sign is Some(s) {
    for p in s.params {
      if p.desc.0 is Some(pname) {
        let ty = internalize_valtype(ctx.type_context, sink, p.desc.1)
        ctx.locals[pname.name] = (ty, pname.loc)
        // Parameters always hold a value.
        ctx.initialized_locals[pname.name] = ()
      }
    }
  }
  return_types
}

///|
/// Leave a function's scope.
///
/// References made after this are module-level again -- a global initializer, a
/// segment -- and so are roots.
pub fn leave_function_scope(ctx : @typing_env.ModuleContext) -> Unit {
  ctx.origin.val = Root
}
