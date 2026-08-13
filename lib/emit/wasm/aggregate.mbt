// Lowering struct and array operations.
//
// Ported from the aggregate cases of wax/src/lib-conversion/to_wasm.ml.
//
// Every one of these needs a TYPE INDEX, and the source may not have written
// one: `{ x: 1, y: 2 }` names no type, because its fields already do. So the
// index is taken from the node's own annotation rather than its spelling -- the
// checker resolved it, and what it resolved to is a fact about the node, not
// about how it was written.
//
// A PACKED field is the other thing that cannot be read off the syntax. `s.b` on
// an `i8` field is `struct.get_s` or `struct.get_u`, and which one depends on
// how the value is used -- so a bare read is the unsigned form, and a following
// sign cast fuses, exactly as a narrow memory load does.

///|
/// The defined type a node's value refers to.
///
/// `None` when the node produced no reference, or one to an abstract heap type
/// -- neither of which any of these instructions can take.
pub fn node_type_index(i : @ast.Instr[@typing_env.InferredAnnotation]) -> Int? {
  match node_valtype(i) {
    Some(Ref({ typ: Type(t) | Exact(t), .. })) => Some(t)
    _ => None
  }
}

///|
/// The fields of the struct a node's value refers to, in declared order.
pub fn Lowering::struct_fields_of(
  self : Lowering,
  i : @ast.Instr[@typing_env.InferredAnnotation],
  loc : @basic.Location,
) -> (Int, Array[@wasm_types.MutType[@wasm_types.StorageType[@type_store.Id]]]) raise LowerError {
  guard node_type_index(i) is Some(t) else {
    raise Unresolved("struct type", loc)
  }
  let sub = self.store
    .subtyping_info()
    .get_subtype(index_id(self.store, t, loc))
  guard sub.typ is Struct(fields) else {
    raise Unresolved("struct definition", loc)
  }
  (t, fields)
}

///|
/// The element type of the array a node's value refers to.
pub fn Lowering::array_element_of(
  self : Lowering,
  i : @ast.Instr[@typing_env.InferredAnnotation],
  loc : @basic.Location,
) -> (Int, @wasm_types.MutType[@wasm_types.StorageType[@type_store.Id]]) raise LowerError {
  guard node_type_index(i) is Some(t) else {
    raise Unresolved("array type", loc)
  }
  let sub = self.store
    .subtyping_info()
    .get_subtype(index_id(self.store, t, loc))
  guard sub.typ is Array(f) else { raise Unresolved("array definition", loc) }
  (t, f)
}

///|
/// The store `Id` an index names.
///
/// The two are the same number seen from two sides; `Id::of_index` is where the
/// store says so, and it says so only for a consumer that already works in
/// indices because the binary format does.
fn index_id(
  store : @type_store.TypeStore,
  i : Int,
  loc : @basic.Location,
) -> @type_store.Id raise LowerError {
  // The other direction: an EMITTED index back to the store entry it came
  // from, for the reads that want a definition rather than a number.
  let si = store_type_index(i)
  guard si >= 0 && si < store.last_index() else {
    raise Unresolved("type index", loc)
  }
  @type_store.Id::of_index(si)
}

///|
/// Whether a field is packed, and so needs a signed or unsigned read.
pub fn is_packed(
  f : @wasm_types.MutType[@wasm_types.StorageType[@type_store.Id]],
) -> Bool {
  f.typ is Packed(_)
}
