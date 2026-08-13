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

///|
/// Names close enough to be worth suggesting for an unbound READ.
///
/// Everything a bare name could have meant: locals, globals, functions.
pub fn get_suggestions(
  ctx : @typing_env.ModuleContext,
  name : String,
) -> Array[String] {
  let candidates : Array[String] = []
  for k, _ in ctx.locals {
    candidates.push(k)
  }
  for k in ctx.globals.names() {
    candidates.push(k)
  }
  for k in ctx.functions.names() {
    candidates.push(k)
  }
  @spell.suggest(candidates.iter(), name)
}

///|
/// Names worth suggesting for an unbound ASSIGNMENT.
///
/// A narrower set than for a read: only a MUTABLE global can be assigned, so
/// suggesting an immutable one would send the reader somewhere that cannot
/// work.
pub fn set_suggestions(
  ctx : @typing_env.ModuleContext,
  name : String,
) -> Array[String] {
  let candidates : Array[String] = []
  for k, _ in ctx.locals {
    candidates.push(k)
  }
  for k in ctx.globals.names() {
    for g in ctx.globals.visible(k) {
      if g.0 {
        candidates.push(k)
        break
      }
    }
  }
  @spell.suggest(candidates.iter(), name)
}

///|
/// The composite type an anonymous reference names.
///
/// A synthesized reference type -- a string's byte array, an inline function
/// type used as a cast target -- has a generated name beginning with `<`. The
/// name keeps lookups working, but a diagnostic renders the structure instead,
/// because the name means nothing to the reader.
pub fn inline_comptype(
  ctx : @typing_env.ModuleContext,
  name : @ast.Ident,
) -> @ast.CompType? {
  if name.name.has_prefix("<") {
    ctx.type_context.types.resolve(name.name, name.loc).map(r => r.1.typ)
  } else {
    None
  }
}

///|
/// Type a read of a bare name.
///
/// Every failure recovers as an error value rather than stopping, and each does
/// so for a slightly different reason: an unbound name has just been reported,
/// a poisoned function was reported at its definition, and a poison local's
/// initializer was reported where it failed. In all three the point is the
/// same -- one mistake should produce one diagnostic.
pub fn type_get(
  ctx : @typing_env.ModuleContext,
  idx : @ast.Ident,
) -> @infer.Cell[@infer.InferredType] {
  match resolve_variable(ctx, idx) {
    Local(ty, def) => {
      // Keyed by the BINDING's offset rather than the name, so a shadowing
      // inner local does not mask an outer one as read.
      ctx.read_locals.push(def.start.cnum)
      if !ctx.initialized_locals.contains(idx.name) {
        report_uninitialized(ctx, idx)
      }
      cell_of(ty)
    }
    Global(_, ty) => cell_of(ty)
    FuncRef(id, type_name, exact) => {
      let name : @ast.Ident = { name: type_name, loc: @basic.dummy_loc }
      let typ : @wasm_types.HeapType[@ast.Ident] = if exact {
        Exact(name)
      } else {
        Type(name)
      }
      let internal : @wasm_types.HeapType[@type_store.Id] = if exact {
        Exact(id)
      } else {
        Type(id)
      }
      @infer.Cell::make(
        Valtype({
          typ: Ref({ nullable: false, typ }),
          internal: Ref({ nullable: false, typ: internal }),
          anon_comptype: inline_comptype(ctx, name),
        }),
      )
    }
    // Already reported at the definition; the poison keeps the use quiet.
    Poisoned => @infer.Cell::make(Error)
    Unbound => {
      unbound_name(
        ctx.diagnostics,
        idx.loc,
        "variable",
        idx.name,
        suggestions=get_suggestions(ctx, idx.name),
      )
      @infer.Cell::make(Error)
    }
  }
}

///|
/// A resolved type, or the poison of one that failed to resolve.
fn cell_of(ty : @infer.InferredValType?) -> @infer.Cell[@infer.InferredType] {
  match ty {
    Some(v) => @infer.Cell::make(Valtype(v))
    None => @infer.Cell::make(Error)
  }
}

///|
/// Names worth suggesting for an unbound TEE target.
///
/// Narrower again than an assignment's: only a local can be tee'd, because the
/// value has to stay on the stack afterwards and only a local supports that.
pub fn local_suggestions(
  ctx : @typing_env.ModuleContext,
  name : String,
) -> Array[String] {
  let candidates : Array[String] = []
  for k, _ in ctx.locals {
    candidates.push(k)
  }
  @spell.suggest(candidates.iter(), name)
}

///|
/// Record and report what an assignment target turned out to be.
///
/// Called AFTER the value has been checked, which matters: the local is marked
/// initialized only then, so `x = x + 1` still sees `x`'s pre-assignment state
/// while its right-hand side is being checked.
///
/// `compound` says the source wrote `x op= e`. That form desugars to `x = x op
/// e`, and the desugared READ already reported an unbound name at this very
/// span -- so reporting the write as well would say the same thing twice.
pub fn assign_target(
  ctx : @typing_env.ModuleContext,
  idx : @ast.Ident,
  resolved : ResolvedVar,
  compound? : Bool = false,
) -> Unit {
  match resolved {
    Local(_, _) => mark_initialized(ctx, idx.name)
    Global(mut_, _) =>
      if !mut_ {
        immutable(ctx.diagnostics, idx.loc, "global")
      } else {
        // The only place a global is written, so also the only place a mutable
        // one can be recorded as actually assigned -- which is what the
        // unnecessary-mut warning reads.
        ctx.assigned_globals[idx.name] = ()
      }
    FuncRef(_, _, _) => not_assignable(ctx.diagnostics, idx.loc, idx.name)
    // Already reported at the definition.
    Poisoned => ()
    Unbound =>
      if !compound {
        unbound_name(
          ctx.diagnostics,
          idx.loc,
          "variable",
          idx.name,
          suggestions=set_suggestions(ctx, idx.name),
        )
      }
  }
}

///|
/// The type a tee delivers, and the reporting that goes with it.
///
/// Only a local is tee-able. Everything else recovers with the OPERAND's own
/// type rather than an unknown, because an unknown cannot be checked against
/// anything and would turn one error into a second one downstream.
pub fn tee_target(
  ctx : @typing_env.ModuleContext,
  idx : @ast.Ident,
  resolved : ResolvedVar,
  operand : @infer.Cell[@infer.InferredType],
) -> @infer.Cell[@infer.InferredType] {
  match resolved {
    Local(Some(ity), _) => {
      mark_initialized(ctx, idx.name)
      @infer.valtype_cell(ity)
    }
    // A poison local: no check to make, but it does now hold a value.
    Local(None, _) => {
      mark_initialized(ctx, idx.name)
      operand
    }
    Global(_, _) | FuncRef(_, _, _) => {
      not_assignable(ctx.diagnostics, idx.loc, idx.name)
      operand
    }
    Poisoned => operand
    Unbound => {
      unbound_name(
        ctx.diagnostics,
        idx.loc,
        "variable",
        idx.name,
        suggestions=local_suggestions(ctx, idx.name),
      )
      operand
    }
  }
}

///|
/// Introduce a local with a known type.
///
/// Used for a binding that has an initializer: the value has just been checked
/// against the type, so the local holds one.
pub fn bind_local(
  ctx : @typing_env.ModuleContext,
  name : @ast.Ident,
  ty : @infer.InferredValType?,
) -> Unit {
  ctx.locals[name.name] = (ty, name.loc)
  ctx.local_decls.push(name)
  mark_initialized(ctx, name.name)
}

///|
/// Introduce a local declared without an initializer -- `let x: t;`.
///
/// Whether it starts holding a value is decided by the type, and this is the
/// only place that decision is made: a defaultable type has a zero value to
/// start at, and a non-nullable reference does not, so it stays uninitialized
/// until something assigns it. That is what makes a later read of it an error
/// rather than a read of nothing.
///
/// An unannotated name has no type to take and declares nothing at all.
pub fn declare_local(
  ctx : @typing_env.ModuleContext,
  name : @ast.Ident,
  typ : @wasm_types.ValType[@ast.Ident],
) -> Unit {
  guard internalize_valtype(ctx.type_context, ctx.diagnostics, typ) is Some(ity) else {
    return
  }
  ctx.locals[name.name] = (Some(ity), name.loc)
  ctx.local_decls.push(name)
  if is_defaultable(typ) {
    mark_initialized(ctx, name.name)
  }
}

///|
/// The type a local takes from an initializer with no annotation.
///
/// An `Error` initializer has no determinable type, so the local is recorded as
/// POISON (`None`) rather than defaulting to i32 -- a wrong type here would
/// cascade into every use of the local. An `Unknown` one is additionally
/// reported: unlike `Error` it has not been complained about yet, and a binding
/// whose type nobody can name is worth saying out loud.
pub fn bound_value_type(
  ctx : @typing_env.ModuleContext,
  location : @basic.Location,
  result_ty : @infer.Cell[@infer.InferredType],
) -> @infer.InferredValType? {
  match result_ty.get() {
    Error => None
    Unknown => {
      unknown_operand_type(ctx.diagnostics, location)
      None
    }
    _ => resolve_omitted_valtype(ctx.type_context, ctx.diagnostics, result_ty)
  }
}

///|
/// Whether a method receiver names a value whose type is a REFERENCE.
///
/// This decides between two readings of the same spelling. `x.min(y)` is the
/// scalar intrinsic when `x` is a number, and an indirect call through a
/// function-pointer field when `x` is a struct reference -- so the receiver's
/// type disambiguates, not the argument count.
///
/// Pure: it reads the name's type out of the locals and globals and records
/// nothing, because it runs as a GUARD, before anything has been typed.
pub fn receiver_is_ref(
  ctx : @typing_env.ModuleContext,
  recv : @ast.Instr[@basic.Location],
) -> Bool {
  fn is_ref(t : @infer.InferredValType?) -> Bool {
    t is Some({ typ: Ref(_), .. })
  }

  guard recv.desc is Get(name) else { return false }
  match ctx.locals.get(name.name) {
    Some((ity, _)) => is_ref(ity)
    None =>
      match ctx.globals.visible(name.name) {
        [(_, ity), ..] => is_ref(ity)
        [] => false
      }
  }
}

///|
/// Whether a method receiver names a value whose type is a reference to an ARRAY
/// type.
///
/// Pure like `receiver_is_ref`, and for the same reason: it gates a bulk-method
/// call before anything has been typed, so a struct with a field named `fill` or
/// `copy` is left to the indirect-call path.
pub fn receiver_is_array_ref(
  ctx : @typing_env.ModuleContext,
  recv : @ast.Instr[@basic.Location],
) -> Bool {
  fn ref_name(t : @infer.InferredValType?) -> @ast.Ident? {
    match t {
      Some({ typ: Ref({ typ: Type(n) | Exact(n), .. }), .. }) => Some(n)
      _ => None
    }
  }

  guard recv.desc is Get(name) else { return false }
  let named = match ctx.locals.get(name.name) {
    Some((ity, _)) => ref_name(ity)
    None =>
      match ctx.globals.visible(name.name) {
        [(_, ity), ..] => ref_name(ity)
        [] => None
      }
  }
  guard named is Some(n) else { return false }
  match ctx.types.find_no_mark(n.name) {
    Some((_, sub)) => sub.typ is Array(_)
    None => false
  }
}

///|
/// Record that an instruction NAMED this memory, table or segment.
///
/// These are resolved with `find_no_mark`, because the lookup is a shape
/// question the guard already answered and reporting it again would say the same
/// thing twice. But naming a memory in `m.load(..)` really is using it, and the
/// unused-declaration lint has no other way to know -- so the use is recorded
/// here, separately from the resolution.
pub fn[A] note_use(
  ctx : @typing_env.ModuleContext,
  tbl : @typing_env.Tbl[A],
  name : @ast.Ident,
) -> Unit {
  tbl.mark_reference(name.name, ctx.origin.val)
}

///|
/// The width of an atomic NARROW load, when that is what this expression is.
///
/// `W32` is not narrow enough to matter here: an `i64` reading 32 bits is the
/// only case, and it has the same absent sign-extending form, but the reference
/// asks only about the 8- and 16-bit ones.
pub fn atomic_narrow_load_width(
  ctx : @typing_env.ModuleContext,
  e : @ast.Instr[@basic.Location],
) -> @atomics.Width? {
  guard e.desc is Call(callee, _) else { return None }
  guard callee.desc is StructGet(recv, meth) else { return None }
  guard recv.desc is Get(memname) else { return None }
  guard memory_receiver(ctx, memname) else { return None }
  match @atomics.of_method_name(meth.name) {
    Some(Load(W8)) => Some(W8)
    Some(Load(W16)) => Some(W16)
    _ => None
  }
}
