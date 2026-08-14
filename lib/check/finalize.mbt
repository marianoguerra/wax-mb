// Deciding what an inferred block's result annotation should say.
//
// Ported from wax/src/lib-wax/typing.ml.
//
// Two different jobs share this file because they are two halves of one
// question. When the source OMITTED the annotation, inference has to supply
// one -- and a flexible type has to commit to a width, because the written
// output cannot say "number". When the source HAS one and `simplify` is
// converting from wasm, inference has to decide whether it is redundant.
//
// The second is the harder one, and every condition below is there because
// dropping the annotation has to leave text that RE-INFERS to the same type.
// It is not enough that the annotation agrees with what we inferred; the
// annotation must be recoverable from what remains.

///|
/// Commit a cell to the type it would have if nothing further constrained it.
///
/// This MUTATES, and deliberately: the cell is the block's result, and once the
/// annotation is written the type is decided for everyone still holding it.
///
/// The defaults are the language's, not arbitrary: an unconstrained integer is
/// an i32, one too large for that an i64, a float an f64. `Unknown` and `Error`
/// take i32 as well -- there is nothing to go on, and i32 is what the reader
/// will expect to see.
fn resolve_omitted_valtype(
  ctx : @typing_env.TypeContext,
  diagnostics : @diagnostic.Context,
  ty : @infer.Cell[@infer.InferredType],
) -> @infer.InferredValType? {
  match ty.get() {
    Valtype(v) => Some(v)
    LargeInt => {
      ty.set(Valtype(@infer.i64_valtype))
      Some(@infer.i64_valtype)
    }
    Int | Number | Int8 | Int16 | Unknown | Error | Collecting(_) => {
      ty.set(Valtype(@infer.i32_valtype))
      Some(@infer.i32_valtype)
    }
    Float => {
      ty.set(Valtype(@infer.f64_valtype))
      Some(@infer.f64_valtype)
    }
    Null =>
      internalize_valtype(ctx, diagnostics, Ref({ nullable: true, typ: None_ })).map(v => {
          ty.set(Valtype(v))
          v
        },
      )
    // The bottom reference concretizes to the NON-NULL `&none`, which is the
    // type `null!` produced before `UnknownRef` existed.
    UnknownRef =>
      internalize_valtype(
        ctx,
        diagnostics,
        Ref({ nullable: false, typ: None_ }),
      ).map(v => {
        ty.set(Valtype(v))
        v
      })
  }
}

///|
/// The width a flexible type would take on its own, with nothing to constrain
/// it. `None` for anything already committed.
fn flexible_default_internal(
  ty : @infer.InferredType,
) -> @wasm_types.ValType[@type_store.Id]? {
  match ty {
    Int | Number | Int8 | Int16 => Some(@infer.i32_valtype.internal)
    LargeInt => Some(@infer.i64_valtype.internal)
    Float => Some(@infer.f64_valtype.internal)
    _ => None
  }
}

///|
/// Whether any exit would re-default to a width other than the inferred result.
///
/// This is the annotation earning its keep. A block whose exits are flexible
/// literals infers, say, i64 only because something in the surrounding text
/// pinned them -- delete the annotation and a re-parse defaults them to i32,
/// and the block's type changes. The annotation is then load-bearing and stays.
fn natural_width_forces_annotation(
  natural : Array[@infer.InferredType],
  inferred : @infer.Cell[@infer.InferredType]?,
) -> Bool {
  guard inferred is Some(c) && c.get() is Valtype(rv) else { return false }
  natural
  .iter()
  .any(ty => {
    match flexible_default_internal(ty) {
      Some(def) => def != rv.internal
      None => false
    }
  })
}

///|
/// What a pass-through value's type would be on a re-parse.
///
/// The packed and unknown cases resolve to i32 there; everything else keeps
/// whatever standalone type it has.
fn exact_reparse_internal(
  ty : @infer.Cell[@infer.InferredType],
) -> @wasm_types.ValType[@type_store.Id]? {
  match ty.get() {
    Int8 | Int16 | Unknown => Some(@infer.i32_valtype.internal)
    _ => @typing_env.standalone_valtype(ty).map(v => v.internal)
  }
}

///|
/// Whether a pass-through value would still match the result after a re-parse.
///
/// A value with no re-parse type at all cannot contradict anything, so it
/// answers yes.
fn exact_reparse_matches(
  result : @wasm_types.ValType[@type_store.Id],
  ty : @infer.Cell[@infer.InferredType],
) -> Bool {
  match exact_reparse_internal(ty) {
    None => true
    Some(e) => e == result
  }
}

///|
/// The natural types of everything that reached a block's exit, snapshotted.
fn collected_natural(
  collected : Array[(@basic.Location?, @infer.Cell[@infer.InferredType])],
) -> Array[@infer.InferredType] {
  collected.map(e => e.1.get())
}

///|
/// Settle an inferred block's result: the cells its exits are checked against,
/// and the annotation to write back.
///
/// Two cases, which are the two reasons to be here at all.
///
/// The source OMITTED the annotation. Then inference supplies it, and the
/// result must commit to a width -- the written output cannot say "number".
/// Since the commitment pins every flexible exit to the same type, only a
/// CONCRETE pass-through value of a different type can still disagree, and with
/// no annotation there is nothing to make it match, so it is reported.
///
/// The source HAS an annotation and `simplify` is converting from wasm. Then
/// the question is whether it is redundant, and the bar is higher than
/// agreement: dropping it must leave text that RE-INFERS to the same type.
/// Hence the conditions, each guarding a way that could fail.
pub fn finalize_inferred(
  ctx : @typing_env.ModuleContext,
  typ : @ast.FuncType,
  inferred : @infer.Cell[@infer.InferredType]?,
  needed? : Bool = false,
  exacts? : Array[(@basic.Location?, @infer.Cell[@infer.InferredType])] = [],
  natural? : Array[@infer.InferredType] = [],
  location? : @basic.Location? = None,
) -> (Array[@infer.Cell[@infer.InferredType]], @ast.FuncType) {
  if typ.results.is_empty() {
    guard inferred.bind(c => {
        resolve_omitted_valtype(ctx.type_context, ctx.diagnostics, c)
      })
      is Some(iv) else {
      return ([], typ)
    }
    if location is Some(location) {
      report_exact_mismatches(
        ctx.diagnostics,
        location,
        @infer.valtype_cell(iv),
        exacts,
      )
    }
    return ([@infer.valtype_cell(iv)], { ..typ, results: [iv.typ] })
  }
  let result_cells : Array[@infer.Cell[@infer.InferredType]] = []
  for r in typ.results {
    match internalize(ctx.type_context, ctx.diagnostics, r) {
      Some(c) => result_cells.push(c)
      None => {
        result_cells.clear()
        break
      }
    }
  }
  let drop = ctx.simplify &&
    !needed &&
    result_cells.length() == 1 &&
    // Keep it if any exit would re-default to a different width on re-parse.
    !natural_width_forces_annotation(natural, inferred) &&
    // Keep it unless every pass-through exit re-defaults to exactly the
    // result; otherwise a re-parse infers a different result and the
    // pass-through value no longer matches it.
    (match @typing_env.standalone_valtype(result_cells[0]) {
      Some(t) => exacts.iter().all(e => exact_reparse_matches(t.internal, e.1))
      None => exacts.is_empty()
    }) &&
    // And, finally, what we inferred must actually fit the annotation. This is
    // the ordinary agreement check, and it is last because it is the one that
    // says least: the conditions above are what make dropping SAFE.
    (match
      (
        inferred.bind(c => @typing_env.standalone_valtype(c)),
        @typing_env.standalone_valtype(result_cells[0]),
      ) {
      (Some(v), Some(t)) =>
        @type_store.val_subtype(
          ctx.type_context.subtyping_info(),
          v.internal,
          t.internal,
        )
      _ => false
    })
  (result_cells, if drop { { ..typ, results: [] } } else { typ })
}
