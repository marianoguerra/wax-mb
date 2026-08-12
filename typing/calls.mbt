// What a call is a call TO.
//
// Ported from wax/src/lib-wax/typing.ml.
//
// Wax writes memory and table operations as method calls -- `mem.load32(a)`,
// `tab.grow(n)` -- so before a call can be typed it has to be classified: is
// this an intrinsic on a memory, on a table, on a segment, or an ordinary call
// through a function reference? The classification is by METHOD NAME and
// RECEIVER together, never by either alone: `size` on a memory and `size` on a
// table are different operations, and a local named `mem` shadows the memory,
// so the receiver has to resolve first.
//
// Also the structural questions a call through a reference has to answer, which
// are about types rather than names.

///|
/// The type a memory load produces, by method name.
///
/// The narrow loads produce `Int8` / `Int16` rather than i32 for the same
/// reason a packed field read does: the value IS an i32, but remembering how
/// narrow it was lets the lowering pick the signed or unsigned opcode.
pub fn mem_load_result(meth : String) -> @infer.InferredType? {
  match meth {
    "load8" => Some(Int8)
    "load16" => Some(Int16)
    "load32" => Some(Valtype(@infer.i32_valtype))
    "load64" => Some(Valtype(@infer.i64_valtype))
    "loadf32" => Some(Valtype(@infer.f32_valtype))
    "loadf64" => Some(Valtype(@infer.f64_valtype))
    _ => None
  }
}

///|
/// Whether a method name is a memory store.
pub fn mem_store_method(meth : String) -> Bool {
  match meth {
    "store8" | "store16" | "store32" | "store64" | "storef32" | "storef64" =>
      true
    _ => false
  }
}

///|
/// Whether a method name is a plain memory access -- a load or a store.
pub fn is_mem_method(meth : String) -> Bool {
  mem_load_result(meth) is Some(_) || mem_store_method(meth)
}

///|
/// Whether a method name manages a memory or a table rather than accessing it.
///
/// The same five names serve both, which is exactly why the receiver decides:
/// `size` on a memory counts pages, `size` on a table counts elements.
pub fn is_mgmt_method(meth : String) -> Bool {
  match meth {
    "size" | "grow" | "fill" | "copy" | "init" => true
    _ => false
  }
}

///|
/// Which intrinsic family a `recv.meth(..)` call belongs to, if any.
///
/// Ordered as the reference orders its guards, and the order matters where two
/// families share a name: the atomics claim theirs first, then the plain
/// accesses, then SIMD, then the management operations. A name that no family
/// claims -- or one whose receiver is not the right kind of thing -- is an
/// ordinary call.
pub fn classify_method_call(
  ctx : @typing_env.ModuleContext,
  receiver : @ast.Ident,
  meth : String,
) -> MethodCall {
  let on_memory = memory_receiver(ctx, receiver)
  if on_memory && @atomics.of_method_name(meth) is Some(f) {
    return Atomic(f)
  }
  if on_memory && is_mem_method(meth) {
    return MemAccess
  }
  if on_memory && @simd.is_mem_method(meth) {
    return SimdMemAccess
  }
  if on_memory && is_mgmt_method(meth) {
    return MemManage
  }
  if is_mgmt_method(meth) && table_receiver(ctx, receiver) {
    return TableManage
  }
  if meth == "drop" && segment_receiver(ctx, receiver) {
    return SegmentDrop
  }
  Ordinary
}

///|
/// What `recv.meth(..)` turned out to be.
pub(all) enum MethodCall {
  Atomic(@atomics.Family)
  MemAccess
  SimdMemAccess
  MemManage
  TableManage
  SegmentDrop
  /// Not an intrinsic: a call through a function reference, or a struct field
  /// holding one.
  Ordinary
} derive(Eq)

///|
/// The function type a continuation type wraps.
///
/// `(cont $ft)` is a continuation of the function type `$ft`, so answering this
/// is two hops through the store: the reference names a continuation, the
/// continuation names a function. Anything else along the way is not a
/// continuation at all.
pub fn cont_functype(
  info : @type_store.SubtypingInfo,
  h : @wasm_types.HeapType[@type_store.Id],
) -> @type_store.FuncType[@type_store.Id]? {
  guard h is (Type(ty) | Exact(ty)) else { return None }
  guard info.get_subtype(ty).typ is Cont(ft) else { return None }
  guard info.get_subtype(ft).typ is Func(f) else { return None }
  Some(f)
}

///|
/// Whether `ft` can be used where `ft'` is expected.
///
/// Contravariant in the parameters and covariant in the results, which is the
/// usual rule and the one place it is easy to write backwards: what is expected
/// must accept everything the caller may pass, and must produce something the
/// caller can use. Arities have to agree exactly -- there is no subtyping
/// between function types of different shapes.
pub fn functype_matches(
  info : @type_store.SubtypingInfo,
  ft : @type_store.FuncType[@type_store.Id],
  ft_ : @type_store.FuncType[@type_store.Id],
) -> Bool {
  guard ft.params.length() == ft_.params.length() &&
    ft.results.length() == ft_.results.length() else {
    return false
  }
  for i in 0..<ft.params.length() {
    if !@type_store.val_subtype(info, ft_.params[i], ft.params[i]) {
      return false
    }
  }
  for i in 0..<ft.results.length() {
    if !@type_store.val_subtype(info, ft.results[i], ft_.results[i]) {
      return false
    }
  }
  true
}
