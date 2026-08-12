// Checking an instruction AGAINST a type the context already knows.
//
// Ported from `check_instruction` / `check_toplevel` in
// wax/src/lib-wax/typing.ml.
//
// The third and last position. Statement position takes whatever an instruction
// leaves; expression position asks it what it produces; check position tells it
// what is wanted, and that is the only one of the three under which a
// construction literal can be written without naming its type:
//
//     let xs : &bytes = [| 0; 0; 0 |];
//
// Nothing in `[| .. |]` says what it constructs. The annotation does, and only a
// position that carries the annotation INTO the literal can use it -- which is
// why an unnamed construction reported "Cannot infer the array type here" no
// matter how plainly the surrounding code said so.
//
// The mechanism is deliberately small: pin the omitted name from the expected
// type, type the literal as if it had been written that way, then put the source
// spelling back. Everything the named form already does -- resolving the element
// type before the values, checking each field, producing an exact reference --
// then applies unchanged, because it IS the named form.

///|
/// Does this cell actually pin a type?
///
/// `Unknown` is the sentinel for "no context"; a `Collecting` cell is a block
/// result still being inferred, and checking a value against it would discard
/// the value rather than constrain it. Neither is an expectation.
pub fn has_expectation(expected : @infer.Cell[@infer.InferredType]) -> Bool {
  match expected.get() {
    Unknown | Collecting(_) => false
    _ => true
  }
}

///|
/// The user type an expected reference names, if it names one.
///
/// This is the whole input to name inference: a construction can only take its
/// type from the context when the context pins a NAMED type. An abstract
/// reference (`&any`, `&struct`) names nothing to construct.
pub fn exact_named_type(
  expected : @infer.Cell[@infer.InferredType],
) -> @ast.Ident? {
  match expected.get() {
    Valtype({ typ: Ref({ typ: Type(n) | Exact(n), .. }), .. }) => Some(n)
    _ => None
  }
}

///|
/// The same construction with an omitted type name filled in from the context.
///
/// `None` when there is nothing to do -- the source named the type, or the node
/// is not a construction at all. Only an OMITTED name is filled: a written one
/// is what the author meant, and the context is not entitled to overrule it.
fn pin_construction_name(
  name : @ast.Ident,
  desc : @ast.InstrDesc[@basic.Location],
) -> @ast.InstrDesc[@basic.Location]? {
  match desc {
    Struct(None, fields) => Some(Struct(Some(name), fields))
    StructDefault(None) => Some(StructDefault(Some(name)))
    Array(None, init, size) => Some(Array(Some(name), init, size))
    ArrayDefault(None, n) => Some(ArrayDefault(Some(name), n))
    ArrayFixed(None, elems) => Some(ArrayFixed(Some(name), elems))
    ArraySegment(None, seg, off, len) =>
      Some(ArraySegment(Some(name), seg, off, len))
    Str(None, s) => Some(Str(Some(name), s))
    _ => None
  }
}

///|
/// Put the source's omitted name back on a typed construction.
///
/// The name was borrowed to type the node, not adopted: what the source wrote is
/// what the printer must print, and an omitted name stays omitted. (Dropping a
/// name that the context makes redundant is the opposite rewrite, and belongs to
/// `simplify`, which converts from wasm and is not wired yet.)
fn unpin_construction_name(
  desc : @ast.InstrDesc[@typing_env.InferredAnnotation],
) -> @ast.InstrDesc[@typing_env.InferredAnnotation] {
  match desc {
    Struct(_, fields) => Struct(None, fields)
    StructDefault(_) => StructDefault(None)
    Array(_, init, size) => Array(None, init, size)
    ArrayDefault(_, n) => ArrayDefault(None, n)
    ArrayFixed(_, elems) => ArrayFixed(None, elems)
    ArraySegment(_, seg, off, len) => ArraySegment(None, seg, off, len)
    Str(_, s) => Str(None, s)
    _ => desc
  }
}

///|
/// Check one instruction against a type the context already knows.
///
/// A construction whose name the expectation can supply is typed as though the
/// name had been written, and the spelling is restored afterwards. Everything
/// else is synthesized and then checked, which is what the call sites did by
/// hand before this existed.
pub fn Checker::check(
  self : Checker,
  expected : @infer.Cell[@infer.InferredType],
  i : @ast.Instr[@basic.Location],
) -> @ast.Instr[@typing_env.InferredAnnotation] {
  let pinned = if has_expectation(expected) &&
    exact_named_type(expected) is Some(n) {
    pin_construction_name(n, i.desc)
  } else {
    None
  }
  match pinned {
    Some(d) => {
      let c = self.expression({ ..i, desc: d })
      self.want(expected, i.info, c)
      { ..c, desc: unpin_construction_name(c.desc) }
    }
    None => {
      let c = self.expression(i)
      self.want(expected, i.info, c)
      c
    }
  }
}

///|
/// Check a typed node's value against the expectation, when there is one.
fn Checker::want(
  self : Checker,
  expected : @infer.Cell[@infer.InferredType],
  location : @basic.Location,
  c : @ast.Instr[@typing_env.InferredAnnotation],
) -> Unit {
  guard has_expectation(expected) else { return }
  check_subtype(
    self.ctx.type_context.subtyping_info(),
    self.ctx.diagnostics,
    location,
    expression_type(self.ctx, c.info),
    expected,
  )
}

///|
/// Check a value carried to a known destination -- a `br`'s target, a `return`'s
/// results -- against what that destination takes.
///
/// One expected value is checked against, so a construction delivered there can
/// take its type from the target. Several, or none, are synthesized and compared
/// as a tuple: there is no single type to hand down.
///
/// A target still being INFERRED is the exception, and it inverts: the value is
/// synthesized and then recorded against the cell, because that recording is
/// what the target's type will be made of. Checking against it would discard the
/// value instead.
pub fn Checker::check_against(
  self : Checker,
  expected : Array[@infer.Cell[@infer.InferredType]],
  e : @ast.Instr[@basic.Location],
) -> @ast.Instr[@typing_env.InferredAnnotation] {
  if expected.length() == 1 && !is_inferring(expected[0]) {
    return self.check(expected[0], e)
  }
  let c = self.expression(e)
  check_subtypes(
    self.ctx.type_context.subtyping_info(),
    self.ctx.diagnostics,
    e.info,
    c.info.0,
    expected,
  )
  c
}
