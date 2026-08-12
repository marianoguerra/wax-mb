// Turning Wax's named types into the store's numbered ones.
//
// Ported from the type-resolution section of wax/src/lib-wax/typing.ml.
//
// THIS IS THE SEAM AGAIN, from the checker's side. A Wax type names what it
// refers to (`&$node`); the store numbers it. Both are instances of the one
// `wasm_types` family, so resolution is a fold that replaces the index type and
// changes nothing else -- which is why each of these functions is a
// constructor-for-constructor walk with exactly two interesting arms.
//
// Everything returns an option rather than raising. A type that fails to
// resolve has already been reported, and returning `None` lets the caller drop
// that one declaration and keep checking the rest, instead of the first bad
// type ending the run.

///|
/// The type-resolution context: the names in scope, the store they resolve
/// into, and the proposals that are enabled.
pub struct TypeContext {
  /// The interned store the resolved indices point into.
  store : @type_store.TypeStore
  /// Name to (index, definition), under the current branch assumption.
  types : @typing_env.Tbl[(@type_store.RefIndex, @ast.SubType)]
  features : @feature.Set
  /// Subtyping info for `store`, computed on demand and dropped whenever a type
  /// is added -- including a function type minted mid-check for an inline
  /// `&fn(..)` cast target -- so a query always sees the current type space.
  mut subtyping_cache : @type_store.SubtypingInfo?
}

///|
pub fn TypeContext::new(
  store : @type_store.TypeStore,
  types : @typing_env.Tbl[(@type_store.RefIndex, @ast.SubType)],
  features : @feature.Set,
) -> TypeContext {
  { store, types, features, subtyping_cache: None }
}

///|
/// Subtyping info for the current type space.
pub fn TypeContext::subtyping_info(
  self : TypeContext,
) -> @type_store.SubtypingInfo {
  match self.subtyping_cache {
    Some(i) => i
    None => {
      let i = self.store.subtyping_info()
      self.subtyping_cache = Some(i)
      i
    }
  }
}

///|
/// Note that the type space changed, so the next query recomputes.
pub fn TypeContext::invalidate(self : TypeContext) -> Unit {
  self.subtyping_cache = None
}

///|
/// The definition a name refers to, if it resolves.
///
/// One of the two things the code generator needs from the checker; the other
/// is the annotation itself.
pub fn get_type_definition(
  ctx : TypeContext,
  name : @ast.Ident,
) -> @ast.SubType? {
  ctx.types.resolve(name.name, name.loc).map(r => r.1)
}

///|
/// How a source reference appears inside a rec group being registered: a `Def`
/// for a type already in the store, a `Rec` for one this very group defines.
pub fn resolve_type_ref(
  ctx : TypeContext,
  name : @ast.Ident,
) -> @type_store.RefIndex? {
  ctx.types.resolve(name.name, name.loc).map(r => r.0)
}

///|
/// The canonical index of an already-defined referenced type.
///
/// A `Rec` here would mean a group still under construction, which the callers
/// of this -- as opposed to `resolve_type_ref` -- never look up.
pub fn resolve_type_name(
  ctx : TypeContext,
  name : @ast.Ident,
) -> @type_store.Id? {
  match resolve_type_ref(ctx, name) {
    Some(Def(id)) => Some(id)
    _ => None
  }
}

///|
/// Note that a proposal is used, and complain if it is not enabled.
///
/// Checking continues either way, so one disabled feature does not swallow
/// every error after it.
pub fn require_feature(
  ctx : TypeContext,
  diagnostics : @diagnostic.Context,
  location : @basic.Location,
  feature : @feature.Feature,
) -> Unit {
  ctx.features.mark_used(feature)
  if !ctx.features.is_enabled(feature) {
    feature_disabled(diagnostics, location, feature)
  }
}

// ============================================================
// Into the resolved form, whose references are canonical indices
// ============================================================

///|
pub fn heaptype(
  ctx : TypeContext,
  diagnostics : @diagnostic.Context,
  h : @wasm_types.HeapType[@ast.Ident],
) -> @wasm_types.HeapType[@type_store.Id]? {
  match h {
    Func => Some(Func)
    NoFunc => Some(NoFunc)
    Exn => Some(Exn)
    NoExn => Some(NoExn)
    Cont => Some(Cont)
    NoCont => Some(NoCont)
    Extern => Some(Extern)
    NoExtern => Some(NoExtern)
    Any => Some(Any)
    Eq => Some(Eq)
    I31 => Some(I31)
    Struct => Some(Struct)
    Array => Some(Array)
    None_ => Some(None_)
    Type(idx) =>
      resolve_type_name(ctx, idx).map(t => @wasm_types.HeapType::Type(t))
    Exact(idx) => {
      // `exact` is the custom-descriptors proposal, and is gated even when the
      // name resolves.
      require_feature(ctx, diagnostics, idx.loc, CustomDescriptors)
      resolve_type_name(ctx, idx).map(t => @wasm_types.HeapType::Exact(t))
    }
  }
}

///|
pub fn reftype(
  ctx : TypeContext,
  diagnostics : @diagnostic.Context,
  r : @wasm_types.RefType[@ast.Ident],
) -> @wasm_types.RefType[@type_store.Id]? {
  heaptype(ctx, diagnostics, r.typ).map(typ => {
    ({ nullable: r.nullable, typ } : @wasm_types.RefType[@type_store.Id])
  })
}

///|
pub fn valtype(
  ctx : TypeContext,
  diagnostics : @diagnostic.Context,
  ty : @wasm_types.ValType[@ast.Ident],
) -> @wasm_types.ValType[@type_store.Id]? {
  match ty {
    I32 => Some(I32)
    I64 => Some(I64)
    F32 => Some(F32)
    F64 => Some(F64)
    V128 => Some(V128)
    Ref(r) => reftype(ctx, diagnostics, r).map(t => @wasm_types.ValType::Ref(t))
  }
}

// ============================================================
// Into the normalized form, whose references may name the group being built
// ============================================================

///|
/// As `heaptype`, but a reference may also be to a member of the rec group
/// currently being registered -- which is what lets a group of mutually
/// recursive types be built at all, and what lets it dedup wherever it lands.
pub fn n_heaptype(
  ctx : TypeContext,
  diagnostics : @diagnostic.Context,
  h : @wasm_types.HeapType[@ast.Ident],
) -> @wasm_types.HeapType[@type_store.RefIndex]? {
  match h {
    Func => Some(Func)
    NoFunc => Some(NoFunc)
    Exn => Some(Exn)
    NoExn => Some(NoExn)
    Cont => Some(Cont)
    NoCont => Some(NoCont)
    Extern => Some(Extern)
    NoExtern => Some(NoExtern)
    Any => Some(Any)
    Eq => Some(Eq)
    I31 => Some(I31)
    Struct => Some(Struct)
    Array => Some(Array)
    None_ => Some(None_)
    Type(idx) =>
      resolve_type_ref(ctx, idx).map(r => @wasm_types.HeapType::Type(r))
    Exact(idx) => {
      require_feature(ctx, diagnostics, idx.loc, CustomDescriptors)
      resolve_type_ref(ctx, idx).map(r => @wasm_types.HeapType::Exact(r))
    }
  }
}

///|
pub fn n_reftype(
  ctx : TypeContext,
  diagnostics : @diagnostic.Context,
  r : @wasm_types.RefType[@ast.Ident],
) -> @wasm_types.RefType[@type_store.RefIndex]? {
  n_heaptype(ctx, diagnostics, r.typ).map(typ => {
    ({ nullable: r.nullable, typ } : @wasm_types.RefType[@type_store.RefIndex])
  })
}

///|
pub fn n_valtype(
  ctx : TypeContext,
  diagnostics : @diagnostic.Context,
  ty : @wasm_types.ValType[@ast.Ident],
) -> @wasm_types.ValType[@type_store.RefIndex]? {
  match ty {
    I32 => Some(I32)
    I64 => Some(I64)
    F32 => Some(F32)
    F64 => Some(F64)
    V128 => Some(V128)
    Ref(r) =>
      n_reftype(ctx, diagnostics, r).map(t => @wasm_types.ValType::Ref(t))
  }
}

///|
pub fn n_storagetype(
  ctx : TypeContext,
  diagnostics : @diagnostic.Context,
  ty : @wasm_types.StorageType[@ast.Ident],
) -> @wasm_types.StorageType[@type_store.RefIndex]? {
  match ty {
    Value(v) =>
      n_valtype(ctx, diagnostics, v).map(t => @wasm_types.StorageType::Value(t))
    Packed(p) => Some(Packed(p))
  }
}

///|
pub fn n_fieldtype(
  ctx : TypeContext,
  diagnostics : @diagnostic.Context,
  ty : @wasm_types.FieldType[@ast.Ident],
) -> @wasm_types.FieldType[@type_store.RefIndex]? {
  n_storagetype(ctx, diagnostics, ty.typ).map(typ => {
    ({ mut_: ty.mut_, typ } : @wasm_types.FieldType[@type_store.RefIndex])
  })
}

///|
/// Map every element, giving up as soon as one fails.
///
/// A single unresolvable component makes the whole type unresolvable, and the
/// component has already reported why.
fn[A, B] map_all(xs : Array[A], f : (A) -> B?) -> Array[B]? {
  let out : Array[B] = []
  for x in xs {
    match f(x) {
      None => return None
      Some(y) => out.push(y)
    }
  }
  Some(out)
}

///|
/// A function type, with the duplicate-parameter check.
///
/// The check runs even when a parameter's type fails to resolve, because a
/// duplicate name is worth reporting whether or not the types are sound.
pub fn n_functype(
  ctx : TypeContext,
  diagnostics : @diagnostic.Context,
  ft : @ast.FuncType,
) -> @type_store.FuncType[@type_store.RefIndex]? {
  check_unique_param_names(diagnostics, ft.params)
  guard map_all(ft.params, p => n_valtype(ctx, diagnostics, p.desc.1))
    is Some(params) else {
    return None
  }
  guard map_all(ft.results, r => n_valtype(ctx, diagnostics, r))
    is Some(results) else {
    return None
  }
  Some({ params, results })
}

///|
/// Report any parameter name used twice, at its second occurrence.
fn check_unique_param_names(
  diagnostics : @diagnostic.Context,
  params : Array[
    @basic.Annotated[
      (@ast.Ident?, @wasm_types.ValType[@ast.Ident]),
      @basic.Location,
    ],
  ],
) -> Unit {
  let seen : Map[String, @basic.Location] = Map([])
  for p in params {
    if p.desc.0 is Some(name) {
      match seen.get(name.name) {
        Some(prev) =>
          duplicated_parameter(diagnostics, name.loc, prev, name.name)
        None => seen[name.name] = name.loc
      }
    }
  }
}

///|
/// What a defined type defines.
pub fn comptype(
  ctx : TypeContext,
  diagnostics : @diagnostic.Context,
  ty : @ast.CompType,
) -> @type_store.CompType[@type_store.RefIndex]? {
  match ty {
    Func(ft) =>
      n_functype(ctx, diagnostics, ft).map(f => @type_store.CompType::Func(f))
    Struct(fields) => {
      check_unique_field_names(diagnostics, fields)
      map_all(fields, f => n_fieldtype(ctx, diagnostics, f.desc.1)).map(fs => {
        @type_store.CompType::Struct(fs)
      })
    }
    Array(field) =>
      n_fieldtype(ctx, diagnostics, field).map(f => {
        @type_store.CompType::Array(f)
      })
    Cont(idx) =>
      resolve_type_ref(ctx, idx).map(r => @type_store.CompType::Cont(r))
  }
}

///|
/// Report any field name used twice, at its second occurrence.
fn check_unique_field_names(
  diagnostics : @diagnostic.Context,
  fields : Array[
    @basic.Annotated[
      (@ast.Ident, @wasm_types.MutType[@wasm_types.StorageType[@ast.Ident]]),
      @basic.Location,
    ],
  ],
) -> Unit {
  let seen : Map[String, @basic.Location] = Map([])
  for f in fields {
    let name = f.desc.0
    match seen.get(name.name) {
      Some(prev) => duplicated_field(diagnostics, name.loc, prev, name.name)
      None => seen[name.name] = name.loc
    }
  }
}
