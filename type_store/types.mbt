// The interned type store: what the type checker reasons about.
//
// Ported from wax/src/lib-wasm/types.ml. This is the module 71 of the typer's
// references go through, and the one `module_context` cannot even be typed
// without -- see implementation-plan.md task 8b.
//
// TWO MORE INSTANCES OF THE SPINE. `wasm_types` is generic over `Idx` so that
// the type family exists once and is instantiated per form. Wax names its types
// (`Idx = @ast.Ident`), the binary form numbers them (`Idx = Int`), and this
// module adds the two the checker needs: `Idx = Id`, a canonical index into
// this store, and `Idx = RefIndex`, which can additionally name a member of the
// rec group currently being registered.
//
// The reference needs a functor for each instance, applied three times, because
// OCaml's `Make_types` also parameterises the ARRAY WRAPPERS -- the Wax form
// annotates its arrays with spans and the internal form does not. Both
// instances here use plain arrays, so the wrapper-carrying types are simply
// generic in `Idx` and defined once. That is four functor applications and two
// module aliases that this port does not need.

///|
/// The canonical index of a type: what `add_rectype` returns and `get_subtype`
/// requires.
///
/// Deliberately opaque -- no `of_int`, no `to_int` -- so that outside this
/// module an `Id` can only come from the store, and can never be fabricated
/// from, or confused with, a source-level or wire-level integer. The reference
/// makes exactly the same choice, and for exactly the same reason: the
/// source-versus-canonical index confusion is the bug class this prevents.
pub struct Id {
  index : Int
} derive(Eq, Hash, Debug)

///|
/// The canonical index `n` positions after this one -- e.g. the `n`-th member
/// of a rec group whose first member is this.
pub fn Id::add(self : Id, n : Int) -> Id {
  { index: self.index + n }
}

///|
/// The underlying integer, for tests that render an index. Not for production
/// code, which must treat `Id` as opaque.
pub fn Id::to_int_for_tests_only(self : Id) -> Int {
  self.index
}

///|
/// A reference inside a rec group being registered.
///
/// `Def` denotes an already-defined type by its canonical index; `Rec` denotes
/// the group's own `pos`-th member. Two constructors rather than one integer
/// space with a sign bit, so the two cannot be confused and an `Id` is only ever
/// a genuine store index.
pub(all) enum RefIndex {
  Def(Id)
  Rec(Int)
} derive(Eq, Hash, Debug)

///|
/// A function type.
pub(all) struct FuncType[Idx] {
  params : Array[@wasm_types.ValType[Idx]]
  results : Array[@wasm_types.ValType[Idx]]
} derive(Eq, Hash, Debug)

///|
/// What a defined type defines.
pub(all) enum CompType[Idx] {
  Func(FuncType[Idx])
  Struct(Array[@wasm_types.FieldType[Idx]])
  Array(@wasm_types.FieldType[Idx])
  Cont(Idx)
} derive(Eq, Hash, Debug)

///|
/// A defined type: what it defines, whether it may be subtyped further, and the
/// one supertype it declares.
///
/// `descriptor` and `describes` are the custom-descriptors proposal's two
/// clauses -- the type of this struct's runtime descriptor, and the struct this
/// one is the descriptor of. They are part of the type's IDENTITY, so they are
/// here and not alongside: two structs with the same fields but different
/// descriptors are different types, and interning has to see the difference.
///
/// The reference DIVERGES here, and knowingly: its `subtype_eq` discards both
/// clauses, so two otherwise identical structs dedup whatever their descriptors
/// -- but its hash is a truncated structural one that may still separate them,
/// which leaves the outcome depending on where the truncation falls. Rather
/// than reproduce a hash-dependent answer we take the proposal's, which is also
/// the one the two clauses are for. If a corpus file ever turns this into a
/// byte difference it will show as a type-section drift, and this is the note
/// that explains it.
pub(all) struct SubType[Idx] {
  final_ : Bool
  supertype : Idx?
  descriptor : Idx?
  describes : Idx?
  typ : CompType[Idx]
} derive(Eq, Hash, Debug)

///|
/// A rec group: the types defined together, which may therefore refer to each
/// other.
pub type RecType[Idx] = Array[SubType[Idx]]

///|
/// The internal, fully resolved form: every reference is a canonical index.
pub type Internal = SubType[Id]

///|
/// The form `add_rectype` takes: like `Internal`, but a reference may also name
/// a member of the group being registered, by position. That is what lets a
/// group dedup regardless of where it lands in the store.
pub type Normalized = SubType[RefIndex]

// ============================================================
// Mapping between the two
// ============================================================

///|
fn[A, B] map_heaptype(
  ht : @wasm_types.HeapType[A],
  f : (A) -> B,
) -> @wasm_types.HeapType[B] {
  match ht {
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
    Type(i) => Type(f(i))
    Exact(i) => Exact(f(i))
  }
}

///|
fn[A, B] map_valtype(
  vt : @wasm_types.ValType[A],
  f : (A) -> B,
) -> @wasm_types.ValType[B] {
  match vt {
    I32 => I32
    I64 => I64
    F32 => F32
    F64 => F64
    V128 => V128
    Ref({ nullable, typ }) => Ref({ nullable, typ: map_heaptype(typ, f) })
  }
}

///|
fn[A, B] map_fieldtype(
  ft : @wasm_types.FieldType[A],
  f : (A) -> B,
) -> @wasm_types.FieldType[B] {
  let typ = match ft.typ {
    Value(vt) => @wasm_types.StorageType::Value(map_valtype(vt, f))
    Packed(pt) => Packed(pt)
  }
  { mut_: ft.mut_, typ }
}

///|
/// Map every type reference in a defined type. The reference needs a functor
/// application for this; here it is a function.
pub fn[A, B] SubType::map(self : SubType[A], f : (A) -> B) -> SubType[B] {
  let typ = match self.typ {
    Func({ params, results }) =>
      CompType::Func({
        params: params.map(v => map_valtype(v, f)),
        results: results.map(v => map_valtype(v, f)),
      })
    Struct(fields) => Struct(fields.map(ft => map_fieldtype(ft, f)))
    Array(ft) => Array(map_fieldtype(ft, f))
    Cont(i) => Cont(f(i))
  }
  {
    final_: self.final_,
    supertype: self.supertype.map(f),
    descriptor: self.descriptor.map(f),
    describes: self.describes.map(f),
    typ,
  }
}
