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
/// Look a name up in a table, REPORTING it if nothing binds it.
///
/// The reporting is the point. Resolving silently let an unbound type name
/// through, so a construction literal naming a type that does not exist was
/// accepted here and only noticed by the lowering -- which is the thing
/// checking exists to happen before.
///
/// Suggestions come from every name the table knows, not only those visible
/// under the current assumption: a name declared in another `#[if]` branch is
/// still a plausible thing the author meant.
pub fn[A] find(
  tbl : @typing_env.Tbl[A],
  diagnostics : @diagnostic.Context,
  name : @ast.Ident,
) -> A? {
  match tbl.resolve(name.name, name.loc) {
    Some(v) => Some(v)
    None => {
      unbound_name(
        diagnostics,
        name.loc,
        tbl.kind,
        name.name,
        suggestions=@spell.suggest(tbl.names().iter(), name.name),
      )
      None
    }
  }
}

///|
/// The definition a name refers to, if it resolves.
///
/// One of the two things the code generator needs from the checker; the other
/// is the annotation itself.
pub fn get_type_definition(
  ctx : @typing_env.TypeContext,
  diagnostics : @diagnostic.Context,
  name : @ast.Ident,
) -> @ast.SubType? {
  find(ctx.types, diagnostics, name).map(r => r.1)
}

///|
/// How a source reference appears inside a rec group being registered: a `Def`
/// for a type already in the store, a `Rec` for one this very group defines.
pub fn resolve_type_ref(
  ctx : @typing_env.TypeContext,
  diagnostics : @diagnostic.Context,
  name : @ast.Ident,
) -> @type_store.RefIndex? {
  find(ctx.types, diagnostics, name).map(r => r.0)
}

///|
/// The canonical index of an already-defined referenced type.
///
/// A `Rec` here would mean a group still under construction, which the callers
/// of this -- as opposed to `resolve_type_ref` -- never look up.
pub fn resolve_type_name(
  ctx : @typing_env.TypeContext,
  diagnostics : @diagnostic.Context,
  name : @ast.Ident,
) -> @type_store.Id? {
  match resolve_type_ref(ctx, diagnostics, name) {
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
  ctx : @typing_env.TypeContext,
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
  ctx : @typing_env.TypeContext,
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
      resolve_type_name(ctx, diagnostics, idx).map(t => {
        @wasm_types.HeapType::Type(t)
      })
    Exact(idx) => {
      // `exact` is the custom-descriptors proposal, and is gated even when the
      // name resolves.
      require_feature(ctx, diagnostics, idx.loc, CustomDescriptors)
      resolve_type_name(ctx, diagnostics, idx).map(t => {
        @wasm_types.HeapType::Exact(t)
      })
    }
  }
}

///|
pub fn reftype(
  ctx : @typing_env.TypeContext,
  diagnostics : @diagnostic.Context,
  r : @wasm_types.RefType[@ast.Ident],
) -> @wasm_types.RefType[@type_store.Id]? {
  heaptype(ctx, diagnostics, r.typ).map(typ => {
    ({ nullable: r.nullable, typ } : @wasm_types.RefType[@type_store.Id])
  })
}

///|
pub fn valtype(
  ctx : @typing_env.TypeContext,
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
  ctx : @typing_env.TypeContext,
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
      resolve_type_ref(ctx, diagnostics, idx).map(r => {
        @wasm_types.HeapType::Type(r)
      })
    Exact(idx) => {
      require_feature(ctx, diagnostics, idx.loc, CustomDescriptors)
      resolve_type_ref(ctx, diagnostics, idx).map(r => {
        @wasm_types.HeapType::Exact(r)
      })
    }
  }
}

///|
pub fn n_reftype(
  ctx : @typing_env.TypeContext,
  diagnostics : @diagnostic.Context,
  r : @wasm_types.RefType[@ast.Ident],
) -> @wasm_types.RefType[@type_store.RefIndex]? {
  n_heaptype(ctx, diagnostics, r.typ).map(typ => {
    ({ nullable: r.nullable, typ } : @wasm_types.RefType[@type_store.RefIndex])
  })
}

///|
pub fn n_valtype(
  ctx : @typing_env.TypeContext,
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
  ctx : @typing_env.TypeContext,
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
  ctx : @typing_env.TypeContext,
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
  ctx : @typing_env.TypeContext,
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
pub fn check_unique_param_names(
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
  ctx : @typing_env.TypeContext,
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
    // A continuation is a continuation OF a function type: `cont ct` where
    // `ct` is itself a continuation names nothing to run.
    Cont(idx) => {
      if ctx.types.find_no_mark(idx.name) is Some((_, def)) &&
        !(def.typ is Func(_)) {
        expected_func_type(diagnostics, idx.loc)
      }
      resolve_type_ref(ctx, diagnostics, idx).map(r => {
        @type_store.CompType::Cont(r)
      })
    }
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

///|
/// A source value type together with its resolved form.
///
/// The pair is what the checker works in: `typ` keeps the name, so a diagnostic
/// can print what the author wrote, and `internal` carries the store index, so
/// subtyping can be decided. Resolution can fail, and then there is no pair.
pub fn internalize_valtype(
  ctx : @typing_env.TypeContext,
  diagnostics : @diagnostic.Context,
  typ : @wasm_types.ValType[@ast.Ident],
) -> @infer.InferredValType? {
  valtype(ctx, diagnostics, typ).map(internal => {
    ({ typ, internal, anon_comptype: None } : @infer.InferredValType)
  })
}

///|
/// As `internalize_valtype`, but as a cell ready to go on the stack.
///
/// `inline` carries the composite type of a synthesized reference -- a string's
/// byte array, an inline function type -- so a diagnostic renders the structure
/// rather than a generated name that means nothing to the reader.
pub fn internalize(
  ctx : @typing_env.TypeContext,
  diagnostics : @diagnostic.Context,
  typ : @wasm_types.ValType[@ast.Ident],
  inline? : @ast.CompType? = None,
) -> @infer.Cell[@infer.InferredType]? {
  valtype(ctx, diagnostics, typ).map(internal => {
    @infer.valtype_cell({ typ, internal, anon_comptype: inline })
  })
}
