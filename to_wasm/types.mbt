// The type section: which types are emitted, and at which indices.
//
// Ported from the type-field conversion of wax/src/lib-conversion/to_wasm.ml
// together with the index assignment of wax/src/lib-wasm/text_to_binary.ml.
//
// The store is NOT the section. The store interns -- two declarations of the
// same shape share one entry, which is the canonicalisation wasm's own type
// equivalence performs, and the checker needs it to answer subtyping. The
// section does not intern: `type sig = fn();` and `type elems = fn();` are two
// entries at two indices, and `&?elems` means the second one.
//
// So the section is built from the SOURCE's declarations -- one entry per name,
// in the order they were written -- and the store is consulted only for what
// each name means. Types the store holds that no declaration names are the
// synthesized ones, and they follow.
//
// The store index and the emitted index are therefore different numbers, and
// every reference has to be translated between them. The translation is
// installed per module in a mutable cell rather than threaded, exactly as the
// reference does and for the same reason: it is read from the leaf functions
// that turn an annotation into a value type, and threading it there would put a
// parameter on every one of their callers to no purpose.

///|
/// Store index to emitted index, for the module being lowered.
///
/// Empty means the identity, which is what the unit tests want: they build a
/// module without a source to lay out.
let type_remap : Ref[Map[Int, Int]] = { val: Map([]) }

///|
/// The emitted index a store index became.
pub fn emitted_type_index(store_index : Int) -> Int {
  match type_remap.val.get(store_index) {
    Some(i) => i
    None => store_index
  }
}

///|
/// Emitted index back to store index, the inverse of `type_remap`.
let store_remap : Ref[Array[Int]] = { val: [] }

///|
/// The store index behind an emitted one.
pub fn store_type_index(emitted : Int) -> Int {
  let m = store_remap.val
  if emitted >= 0 && emitted < m.length() {
    m[emitted]
  } else {
    emitted
  }
}

///|
/// Where each type name lands in the emitted section.
pub struct TypeLayout {
  /// Emitted index for a declared name.
  by_name : Map[String, Int]
  /// Emitted index for a store index: the FIRST declaration of that shape,
  /// which is the one a reference carrying only an interned id must mean.
  by_store : Map[Int, Int]
  /// The store index behind each emitted one, for the reads that go back to
  /// the store for a definition.
  store_of : Array[Int]
  types : Array[@wasm_bin.SubType]
  groups : Array[@wasm_bin.RecGroup]
}

///|
/// Lay out the type section from the source's declarations, then the rest.
pub fn type_layout(
  ctx : @typing_env.ModuleContext,
  source : @ast.Module[@basic.Location],
  store : @type_store.TypeStore,
) -> TypeLayout {
  let by_name : Map[String, Int] = Map([])
  let by_store : Map[Int, Int] = Map([])
  let store_of : Array[Int] = []
  let groups : Array[@wasm_bin.RecGroup] = []
  fn place(name : String, store_index : Int) -> Unit {
    let emitted = store_of.length()
    by_name[name] = emitted
    if !by_store.contains(store_index) {
      by_store[store_index] = emitted
    }
    store_of.push(store_index)
  }

  // The declarations, in source order, one rec group per `type` field.
  @typing.walk_fields(ctx, source, field => {
    guard field.desc is Type(rectype) else { return }
    let start = store_of.length()
    for entry in rectype {
      let (name, _) = entry.desc
      guard ctx.type_context.types.find_no_mark(name.name) is Some((idx, _)) else {
        continue
      }
      guard idx is Def(id) else { continue }
      place(name.name, id.to_int_for_tests_only())
    }
    let len = store_of.length() - start
    if len > 0 {
      groups.push({ start, len, explicit: len != 1 })
    }
  })
  // Then everything the store holds that no declaration named: the synthesized
  // types, in the order they were interned.
  let mut store_index = 0
  for group in store.get_all_rectypes() {
    let start = store_of.length()
    let mut added = 0
    for _ in group {
      if !by_store.contains(store_index) {
        by_store[store_index] = store_of.length()
        store_of.push(store_index)
        added = added + 1
      }
      store_index = store_index + 1
    }
    if added > 0 {
      groups.push({ start, len: added, explicit: added != 1 })
    }
  }
  // With the mapping known, the subtypes can be read out -- their own inner
  // references are store indices too, and go through the same translation.
  type_remap.val = by_store
  store_remap.val = store_of
  let info = store.subtyping_info()
  let types : Array[@wasm_bin.SubType] = []
  for si in store_of {
    types.push(lower_subtype(info.get_subtype(@type_store.Id::of_index(si))))
  }
  { by_name, by_store, store_of, types, groups }
}

///|
/// One stored type, with its `Id` indices flattened to plain integers.
fn lower_subtype(s : @type_store.SubType[@type_store.Id]) -> @wasm_bin.SubType {
  {
    final_: s.final_,
    supertypes: match s.supertype {
      Some(i) => [emitted_type_index(i.to_int_for_tests_only())]
      None => []
    },
    descriptor: s.descriptor.map(i => {
      emitted_type_index(i.to_int_for_tests_only())
    }),
    describes: s.describes.map(i => {
      emitted_type_index(i.to_int_for_tests_only())
    }),
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
    Cont(i) => Cont(emitted_type_index(i.to_int_for_tests_only()))
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
    Type(i) => Type(emitted_type_index(i.to_int_for_tests_only()))
    Exact(i) => Exact(emitted_type_index(i.to_int_for_tests_only()))
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
