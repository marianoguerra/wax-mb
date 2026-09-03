// Whether an expression is one wasm can evaluate before the module runs.
//
// Ported from `check_constant_instruction` in wax/src/lib-wax/typing.ml.
//
// A global, a table, an element segment and a data-segment offset are all
// initialized by an expression the RUNTIME evaluates during instantiation, with
// no stack machine and no locals -- so only a small grammar is allowed. It is a
// shape test over the already-typed tree, not a second typing pass: the types
// are only consulted where the shape alone does not decide (whether an `Add` is
// integer, whether a `ref.i31`'s operand is the i32 it needs).

///|
/// Report every non-constant part of an initializer expression.
fn check_constant_instruction(
  ctx : @typing_env.ModuleContext,
  i : @ast.Instr[@typing_env.InferredAnnotation],
) -> Unit {
  ignore(constant_instruction(ctx, i))
}

///|
/// Whether the SUBTREE already reported.
///
/// That, rather than "is constant", is what the recursion has to return. A
/// non-constant leaf makes every enclosing construct's own shape test fail too
/// -- a nested `1 + (f() + 2)` fails at both `+` -- and one root cause deserves
/// one diagnostic, at the innermost offender.
fn constant_instruction(
  ctx : @typing_env.ModuleContext,
  i : @ast.Instr[@typing_env.InferredAnnotation],
) -> Bool {
  let location = i.info.1
  fn required() -> Bool {
    constant_expression_required(ctx.diagnostics, location)
    true
  }

  fn typ_of(
    e : @ast.Instr[@typing_env.InferredAnnotation],
  ) -> @infer.InferredType? {
    @typing_env.expression_type_opt(e.info).map(c => c.get())
  }

  // A punned field `{x}` is a `Get` of the like-named global, which has to
  // satisfy the same constant-global rule -- but there is no node to recurse
  // into, so ask the table directly.
  fn field(
    f : (@ast.Ident, @ast.Instr[@typing_env.InferredAnnotation]?),
  ) -> Bool {
    match f.1 {
      Some(v) => constant_instruction(ctx, v)
      None =>
        match ctx.globals.find_no_mark(f.0.name) {
          Some((true, _)) => {
            constant_global_required(ctx.diagnostics, f.0.loc)
            true
          }
          _ => false
        }
    }
  }

  fn all(l : Array[@ast.Instr[@typing_env.InferredAnnotation]]) -> Bool {
    let mut r = false
    for e in l {
      // Every element, not the first offender: they are siblings, and each is
      // its own root cause.
      r = constant_instruction(ctx, e) || r
    }
    r
  }

  match i.desc {
    // A mutable global has no value yet at instantiation time; an immutable one
    // does. A name that resolves to nothing here is a `ref.func`, which is
    // constant.
    Get(idx) =>
      match ctx.globals.find_no_mark(idx.name) {
        Some((true, _)) => {
          constant_global_required(ctx.diagnostics, location)
          true
        }
        _ => false
      }
    Null | StructDefault(_) | Int(_) | Float(_) | Char(_) | Str(_, _) => false
    // `array.new_default` fills with the field default, but its LENGTH is an
    // arbitrary expression that must be constant like any other.
    ArrayDefault(_, len) => constant_instruction(ctx, len)
    Struct(_, fields) => {
      let mut r = false
      for f in fields {
        r = field(f) || r
      }
      r
    }
    StructDesc(d, fields) => {
      let mut r = constant_instruction(ctx, d)
      for f in fields {
        r = field(f) || r
      }
      r
    }
    StructDefaultDesc(d) => constant_instruction(ctx, d)
    ArrayFixed(_, elts) => all(elts)
    Array(_, elt, len) => {
      let r1 = constant_instruction(ctx, elt)
      constant_instruction(ctx, len) || r1
    }
    // `cont.new` allocates from a (constant) function reference, so it is
    // constant itself. This tracks the open stack-switching spec PR; the spec
    // does not list it yet.
    ContNew(_, f) => constant_instruction(ctx, f)
    BinOpI(op, a, b) =>
      if op.desc is (Add | Sub | Mul) {
        let r1 = constant_instruction(ctx, a)
        let r2 = constant_instruction(ctx, b)
        if r1 || r2 {
          true
        } else {
          // Only INTEGER add/sub/mul are constant instructions; the float ones
          // are not. `Error` is the poison of an already-reported operand, and
          // a second report here would duplicate it.
          match typ_of(i) {
            Some(Int)
            | Some(Valtype({ internal: I32 | I64, .. }))
            | Some(Error) => false
            _ => required()
          }
        }
      } else {
        required()
      }
    // `ref.null`.
    Cast(inner, Value(Ref({ nullable: true, .. }))) if inner.desc is Null =>
      false
    // `ref.i31`, whose operand is the i32 it boxes.
    Cast(inner, Value(Ref({ typ: I31, .. }))) =>
      if constant_instruction(ctx, inner) {
        true
      } else {
        match typ_of(inner) {
          Some(Valtype({ internal: I32, .. })) | Some(Error) => false
          _ => required()
        }
      }
    // `extern.convert_any`. An i32 operand is wrapped in `ref.i31` first
    // (i32 -> i31 -> any -> extern, as the ordinary typing lowers it), and that
    // is constant too -- so accept it rather than demanding an `any` reference.
    Cast(inner, Value(Ref({ typ: Extern, nullable, }))) =>
      if constant_instruction(ctx, inner) {
        true
      } else {
        let bad = match typ_of(inner) {
          Some(Valtype({ internal: I32, .. })) => false
          Some(Valtype({ internal, .. })) =>
            !@type_store.val_subtype(
              ctx.type_context.subtyping_info(),
              internal,
              Ref({ nullable, typ: Any, }),
            )
          Some(Error) => false
          _ => true
        }
        if bad {
          required()
        } else {
          false
        }
      }
    // `any.convert_extern`.
    Cast(inner, Value(Ref({ typ: Any, nullable, }))) =>
      if constant_instruction(ctx, inner) {
        true
      } else {
        let bad = match typ_of(inner) {
          Some(Valtype({ internal, .. })) =>
            !@type_store.val_subtype(
              ctx.type_context.subtyping_info(),
              internal,
              Ref({ nullable, typ: Extern, }),
            )
          Some(Error) => false
          _ => true
        }
        if bad {
          required()
        } else {
          false
        }
      }
    UnOpI(op, inner) =>
      match (op.desc, inner.desc) {
        (Pos, _) => constant_instruction(ctx, inner)
        // A sign folded into the literal, which is what the code generator
        // emits. `-x` for anything else is a runtime subtraction.
        (Neg, Float(_) | Int(_)) => false
        _ => required()
      }
    // `v128::<shape>(..)` is a constant; its lanes are literals. The lanes are
    // NOT re-walked -- the intrinsic's own typing already rejects a non-literal
    // one with this same report, at the lane's span.
    Call(callee, _) if is_const_vector(callee) => false
    _ => required()
  }
}

///|
/// Whether a callee names a free vector constructor.
fn is_const_vector(callee : @ast.Instr[@typing_env.InferredAnnotation]) -> Bool {
  guard callee.desc is Path(ns, name) else { return false }
  ns.name == @simd.free_namespace &&
  @simd.const_shape_of_name(@simd.free_full(name.name)) is Some(_)
}
