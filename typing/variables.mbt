// Resolving a bare name, and knowing whether a local holds a value yet.
//
// Ported from wax/src/lib-wax/typing.ml.

///|
/// What a bare name turned out to be.
pub(all) enum ResolvedVar {
  Local(@infer.InferredValType?, @basic.Location)
  Global(Bool, @infer.InferredValType?)
  FuncRef(@type_store.Id, String, Bool)
  /// A function whose signature failed to resolve. It is BOUND -- already
  /// reported at its definition -- so it reads as an error with nothing further
  /// said, rather than as an unbound name.
  Poisoned
  Unbound
}

///|
/// Resolve a bare name.
///
/// The order is the language's: a local shadows everything. Globals, functions,
/// memories and tables share one namespace, so a local is the only thing that
/// can collide with them -- which is why every receiver test below has to defer
/// to a local in the same way.
pub fn resolve_variable(
  ctx : @typing_env.ModuleContext,
  idx : @ast.Ident,
) -> ResolvedVar {
  match ctx.locals.get(idx.name) {
    Some((ty, def)) => {
      @typing_env.record_reference(
        ctx.resolve_links,
        idx.loc,
        [def],
        hover=ty.map(v => @typing_env.HoverTarget::ValueType(v)),
      )
      Local(ty, def)
    }
    None =>
      match ctx.globals.resolve(idx.name, idx.loc) {
        Some((mut_, ty)) => Global(mut_, ty)
        None =>
          match ctx.functions.resolve(idx.name, idx.loc) {
            Some(Some((ty, name, exact))) => FuncRef(ty, name, exact)
            Some(None) => Poisoned
            None => Unbound
          }
      }
  }
}

///|
/// Is this name a memory usable as a receiver -- `mem.load(..)`?
///
/// A local of the same name shadows it, exactly as it shadows a `Get`.
pub fn memory_receiver(
  ctx : @typing_env.ModuleContext,
  name : @ast.Ident,
) -> Bool {
  !ctx.locals.contains(name.name) && !ctx.memories.visible(name.name).is_empty()
}

///|
/// Likewise for a table used as `tab[..]` or `tab.size()`.
pub fn table_receiver(
  ctx : @typing_env.ModuleContext,
  name : @ast.Ident,
) -> Bool {
  !ctx.locals.contains(name.name) && !ctx.tables.visible(name.name).is_empty()
}

///|
/// Likewise for a data or element segment named by `seg.drop()`.
pub fn segment_receiver(
  ctx : @typing_env.ModuleContext,
  name : @ast.Ident,
) -> Bool {
  !ctx.locals.contains(name.name) &&
  (
    !ctx.datas.visible(name.name).is_empty() ||
    !ctx.elems.visible(name.name).is_empty()
  )
}

// ============================================================
// Initialization
// ============================================================

///|
/// Does this type have a zero value?
///
/// Everything but a non-nullable reference does. A local of such a type has
/// nothing to start as, so it must be assigned before it is read -- which is
/// the whole reason the checker tracks initialization at all.
pub fn is_defaultable(ty : @wasm_types.ValType[@ast.Ident]) -> Bool {
  match ty {
    Ref(r) => r.nullable
    _ => true
  }
}

///|
pub fn mark_initialized(ctx : @typing_env.ModuleContext, name : String) -> Unit {
  let one : Map[String, Unit] = Map([])
  one[name] = ()
  ctx.merge_initialized(one)
}

///|
/// Report a read of a local that does not hold a value yet -- or, while a
/// trailing operand is being checked out of emission order, defer it.
///
/// Both the ordinary read and a deferred read's re-check come through here, so
/// a re-check that still fails under an OUTER deferral re-defers rather than
/// reporting.
pub fn report_uninitialized(
  ctx : @typing_env.ModuleContext,
  idx : @ast.Ident,
) -> Unit {
  match ctx.current_deferral() {
    Some(collector) => collector.push(idx)
    None => uninitialized_local(ctx.diagnostics, idx.loc, idx.name)
  }
}

///|
/// Check an operand that is written before the values it follows but EMITTED
/// after them, and return a thunk to run at its real slot.
///
/// The initialized-locals analysis threads in emission order, so checking such
/// an operand early sees a state that is a SUBSET of the true one. Three things
/// follow, and each is what makes the analysis sound rather than merely
/// plausible:
///
///   * A read that succeeds now would also succeed later, so it is fine.
///   * A read that FAILS now might succeed later, once an earlier operand has
///     assigned the local -- so it is deferred, not reported.
///   * The operand's own writes are withheld, because an earlier operand runs
///     first and must not see them.
///
/// The returned thunk re-checks the deferred reads against the state that
/// actually holds at the emission slot, then applies the withheld writes.
pub fn[A] type_trailing_operand(
  ctx : @typing_env.ModuleContext,
  run : () -> A,
) -> (A, () -> Unit) {
  let saved = ctx.snapshot_initialized()
  let collector = ctx.push_deferral()
  let result = run()
  ctx.pop_deferral()
  // What this operand initialized, which is withheld until its real slot.
  let delta = ctx.snapshot_initialized()
  ctx.restore_initialized(saved)
  let replay = () => {
    for idx in collector {
      if !ctx.initialized_locals.contains(idx.name) {
        report_uninitialized(ctx, idx)
      }
    }
    ctx.merge_initialized(delta)
  }
  (result, replay)
}
