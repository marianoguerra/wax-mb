// The type section, taken from the store.
//
// Ported from the type-section half of wax/src/lib-wasm/text_to_binary.ml.
//
// There is almost nothing to decide here, and that is the point of having had a
// store all along: it interned every type as it was declared, deduplicating
// structurally identical ones onto a single index and keeping rec groups
// together. So the section is the store read out in order, and the indices the
// rest of the lowering uses are the ones the checker was already using.

///|
/// The type section and its rec-group table.
///
/// A group of one that was not written as a group is emitted as a bare type --
/// `explicit` is false -- because that is how the format spells it and how the
/// reference emits it, and the bytes have to match.
pub fn type_section(
  store : @type_store.TypeStore,
) -> (Array[@wasm_bin.SubType], Array[@wasm_bin.RecGroup]) {
  let types : Array[@wasm_bin.SubType] = []
  let groups : Array[@wasm_bin.RecGroup] = []
  for group in store.get_all_rectypes() {
    let start = types.length()
    for sub in group {
      types.push(lower_subtype(sub))
    }
    groups.push({ start, len: group.length(), explicit: group.length() != 1 })
  }
  (types, groups)
}

///|
/// One stored type, with its `Id` indices flattened to plain integers.
fn lower_subtype(s : @type_store.SubType[@type_store.Id]) -> @wasm_bin.SubType {
  {
    final_: s.final_,
    supertypes: match s.supertype {
      Some(i) => [i.to_int_for_tests_only()]
      None => []
    },
    descriptor: s.descriptor.map(i => i.to_int_for_tests_only()),
    describes: s.describes.map(i => i.to_int_for_tests_only()),
    composite: lower_comptype(s.typ),
  }
}

///|
fn lower_comptype(
  c : @type_store.CompType[@type_store.Id],
) -> @wasm_bin.CompositeType {
  match c {
    Func(ft) =>
      Func({
        params: ft.params.map(v => lower_valtype(v)),
        results: ft.results.map(v => lower_valtype(v)),
      })
    Struct(fields) =>
      Struct({
        fields: fields.map(f => {
          (
            { mut_: f.mut_, typ: lower_storagetype(f.typ) } :
            @wasm_types.MutType[@wasm_types.StorageType[Int]])
        }),
      })
    Array(f) =>
      Array({ element: { mut_: f.mut_, typ: lower_storagetype(f.typ) } })
    Cont(i) => Cont(i.to_int_for_tests_only())
  }
}

///|
/// A value type with its type references flattened to indices.
pub fn lower_valtype(
  v : @wasm_types.ValType[@type_store.Id],
) -> @wasm_types.ValType[Int] {
  match v {
    I32 => I32
    I64 => I64
    F32 => F32
    F64 => F64
    V128 => V128
    Ref(r) => Ref(lower_reftype(r))
  }
}

///|
pub fn lower_reftype(
  r : @wasm_types.RefType[@type_store.Id],
) -> @wasm_types.RefType[Int] {
  { nullable: r.nullable, typ: lower_heaptype(r.typ) }
}

///|
fn lower_heaptype(
  h : @wasm_types.HeapType[@type_store.Id],
) -> @wasm_types.HeapType[Int] {
  match h {
    Func => Func
    NoFunc => NoFunc
    Exn => Exn
    NoExn => NoExn
    Cont => Cont
    NoCont => NoCont
    Extern => Extern
    NoExtern => NoExtern
    Any => Any
    Eq => Eq
    I31 => I31
    Struct => Struct
    Array => Array
    None_ => None_
    Type(i) => Type(i.to_int_for_tests_only())
    Exact(i) => Exact(i.to_int_for_tests_only())
  }
}

///|
fn lower_storagetype(
  s : @wasm_types.StorageType[@type_store.Id],
) -> @wasm_types.StorageType[Int] {
  match s {
    Value(v) => Value(lower_valtype(v))
    Packed(p) => Packed(p)
  }
}
