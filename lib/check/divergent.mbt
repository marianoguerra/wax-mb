// Divergent tails: a trailing construct that never completes.
//
// Ported from `fill_divergent_tails`, `fill_tails` and `fill_divergent_tail`
// in wax/src/lib-wax/typing.ml (upstream a81c8442).
//
// A `do`, `loop`, `if` or `try` whose result is omitted and that never
// completes -- every value it produces goes to an enclosing label -- delivers
// nothing at its exit. When it ends the body of a block whose own result is
// being inferred, that used to be a missing value. It is now recorded on the
// block's `Collecting` cell instead (`Checker::block_contents_flat`) and, once
// the block's result is known, given that result as it would have been given
// it by a concrete context. Its own divergent tails get the same.

///|
/// Give each of `cs`'s divergent trailing constructs the result of the
/// construct `desc` whose bodies they end: `typ`'s single result as finalized,
/// or, when `simplify` dropped it, the single cell in `results`.
fn fill_divergent_tails(
  cs : @infer.Collecting,
  typ : @ast.FuncType,
  results : Array[@infer.Cell[@infer.InferredType]],
  desc : @ast.InstrDesc[@typing_env.InferredAnnotation],
) -> @ast.InstrDesc[@typing_env.InferredAnnotation] {
  match (typ.results, results) {
    ([t], _) => fill_tails(cs, t, results, desc)
    (_, [c]) =>
      match @typing_env.standalone_valtype(c) {
        Some(iv) => fill_tails(cs, declared_form(iv), results, desc)
        None => desc
      }
    _ => desc
  }
}

///|
/// Give `cs`'s divergent trailing constructs, ending the bodies of `desc`, the
/// result `t`, whose cells are `results`.
fn fill_tails(
  cs : @infer.Collecting,
  t : @wasm_types.ValType[@ast.Ident],
  results : Array[@infer.Cell[@infer.InferredType]],
  desc : @ast.InstrDesc[@typing_env.InferredAnnotation],
) -> @ast.InstrDesc[@typing_env.InferredAnnotation] {
  if cs.divergent_tails.is_empty() {
    return desc
  }
  let tail = (b : @ast.Body[@typing_env.InferredAnnotation]) => {
    ..b,
    desc: fill_divergent_tail(cs, t, results, b.desc),
  }
  match desc {
    Block(label~, typ~, block~) => Block(label~, typ~, block=tail(block))
    Loop(label~, typ~, block~) => Loop(label~, typ~, block=tail(block))
    If(label~, typ~, cond~, if_block~, else_block~) =>
      If(
        label~,
        typ~,
        cond~,
        if_block=tail(if_block),
        else_block=else_block.map(tail),
      )
    TryTable(label~, typ~, catches~, block~) =>
      TryTable(label~, typ~, catches~, block=tail(block))
    Try(label~, typ~, block~, catches~, catch_all~) =>
      Try(
        label~,
        typ~,
        block=tail(block),
        catches=catches.map(c => (c.0, tail(c.1))),
        catch_all=catch_all.map(tail),
      )
    d => d
  }
}

///|
/// The body `l` with its last instruction given the result `t` (whose cells
/// are `results`) when it is one of `cs`'s divergent trailing constructs -- and
/// so, in turn, its own divergent trailing constructs, which never complete
/// either.
fn fill_divergent_tail(
  cs : @infer.Collecting,
  t : @wasm_types.ValType[@ast.Ident],
  results : Array[@infer.Cell[@infer.InferredType]],
  l : Array[@ast.Instr[@typing_env.InferredAnnotation]],
) -> Array[@ast.Instr[@typing_env.InferredAnnotation]] {
  guard l.last() is Some(last) else { return l }
  let loc = last.info.1
  guard cs.divergent_tails.iter().find_first(d => d.0 == loc)
    is Some((_, inner)) else {
    return l
  }
  let desc = fill_tails(
    inner,
    t,
    results,
    fill_omitted_block_result(t, last.desc),
  )
  let out = l.copy()
  out[out.length() - 1] = { ..last, desc, info: (results, loc), }
  out
}

///|
/// A typed block-like construct with `t` written in as its result, if it
/// omitted one. The reference's `annotate_omitted_block`.
fn fill_omitted_block_result(
  t : @wasm_types.ValType[@ast.Ident],
  desc : @ast.InstrDesc[@typing_env.InferredAnnotation],
) -> @ast.InstrDesc[@typing_env.InferredAnnotation] {
  let fill = (typ : @ast.FuncType) => {
    if typ.results.is_empty() {
      { ..typ, results: [t], }
    } else {
      typ
    }
  }
  match desc {
    Block(label~, typ~, block~) => Block(label~, typ=fill(typ), block~)
    Loop(label~, typ~, block~) => Loop(label~, typ=fill(typ), block~)
    TryTable(label~, typ~, catches~, block~) =>
      TryTable(label~, typ=fill(typ), catches~, block~)
    Try(label~, typ~, block~, catches~, catch_all~) =>
      Try(label~, typ=fill(typ), block~, catches~, catch_all~)
    TryCatch(label~, typ~, block~, arms~) =>
      TryCatch(label~, typ=fill(typ), block~, arms~)
    If(label~, typ~, cond~, if_block~, else_block~) =>
      If(label~, typ=fill(typ), cond~, if_block~, else_block~)
    d => d
  }
}
