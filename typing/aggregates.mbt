// Looking up what a struct or array access operates on.
//
// Ported from wax/src/lib-wax/typing.ml.
//
// A type NAME resolves to a definition of some kind, and an aggregate operation
// needs one of a particular kind. Asking for the wrong kind is a mistake worth
// naming precisely -- "expected struct type" rather than a mismatch several
// steps later -- which is why each kind gets its own lookup rather than one
// that returns the definition and leaves the caller to match on it.
//
// An unbound name is reported by the lookup itself. Returning `None` silently
// would let a literal naming a type that does not exist be accepted here and
// lowered to `unreachable`, which is exactly what checking exists to pre-empt.

///|
/// The function type a name refers to.
pub fn lookup_func_type(
  ctx : @typing_env.TypeContext,
  diagnostics : @diagnostic.Context,
  name : @ast.Ident,
  location? : @basic.Location? = None,
) -> @ast.FuncType? {
  guard find(ctx.types, diagnostics, name) is Some((_, def)) else {
    return None
  }
  match def.typ {
    Func(ft) => Some(ft)
    _ => {
      expected_func_type(diagnostics, location.unwrap_or(name.loc))
      None
    }
  }
}

///|
/// The fields a struct type declares.
pub fn lookup_struct_type(
  ctx : @typing_env.TypeContext,
  diagnostics : @diagnostic.Context,
  name : @ast.Ident,
  location? : @basic.Location? = None,
) -> Array[
  @basic.Annotated[
    (@ast.Ident, @wasm_types.MutType[@wasm_types.StorageType[@ast.Ident]]),
    @basic.Location,
  ],
]? {
  guard find(ctx.types, diagnostics, name) is Some((_, def)) else {
    return None
  }
  match def.typ {
    Struct(fields) => Some(fields)
    _ => {
      expected_struct_type(diagnostics, location.unwrap_or(name.loc))
      None
    }
  }
}

///|
/// The element type an array type declares.
pub fn lookup_array_type(
  ctx : @typing_env.TypeContext,
  diagnostics : @diagnostic.Context,
  name : @ast.Ident,
  location? : @basic.Location? = None,
) -> @wasm_types.MutType[@wasm_types.StorageType[@ast.Ident]]? {
  guard find(ctx.types, diagnostics, name) is Some((_, def)) else {
    return None
  }
  match def.typ {
    Array(field) => Some(field)
    _ => {
      expected_array_type(diagnostics, location.unwrap_or(name.loc))
      None
    }
  }
}

///|
/// The unique struct type with exactly these field names, if there is one.
///
/// This is what lets `{ x: 1, y: 2 }` be written without naming its type. The
/// index is built once, after every type is registered, so the answer is
/// complete; `None` means either no struct has that field set or several do,
/// and in both cases the literal has to name what it means.
pub fn infer_struct_by_fields(
  ctx : @typing_env.ModuleContext,
  fields : Array[@ast.Ident],
) -> @ast.Ident? {
  let key = field_set_key(fields.map(f => f.name))
  match ctx.structs_by_fields.get(key) {
    Some(Some(name)) => Some(name)
    _ => None
  }
}

///|
/// The type a field READ produces.
///
/// A packed field is not read at its stored width: `i8` and `i16` come off as
/// i32, and which sign extension applies is the reader's choice. `Int8` and
/// `Int16` carry that -- they are i32 values that remember how narrow they
/// were, so the lowering can pick `struct.get_s` against `struct.get_u`.
pub fn field_read_type(
  ctx : @typing_env.TypeContext,
  diagnostics : @diagnostic.Context,
  f : @wasm_types.MutType[@wasm_types.StorageType[@ast.Ident]],
) -> @infer.Cell[@infer.InferredType]? {
  match f.typ {
    Value(typ) => internalize(ctx, diagnostics, typ)
    Packed(I8) => Some(@infer.Cell::make(Int8))
    Packed(I16) => Some(@infer.Cell::make(Int16))
  }
}

///|
/// The value type a field is WRITTEN at.
///
/// The other half of the packed story: a write takes a plain i32 and the
/// narrowing is implicit, so unlike a read there is nothing to remember.
pub fn unpack_type(
  f : @wasm_types.MutType[@wasm_types.StorageType[@ast.Ident]],
) -> @wasm_types.ValType[@ast.Ident] {
  match f.typ {
    Value(v) => v
    Packed(_) => I32
  }
}

///|
/// Whether a field has a default value, so a `..default` construction can leave
/// it out.
///
/// Everything numeric does -- zero. A reference does only if it is nullable:
/// there is no null to default a non-null reference to, so it must be given.
pub fn field_has_default(
  ty : @wasm_types.MutType[@wasm_types.StorageType[@ast.Ident]],
) -> Bool {
  match ty.typ {
    Packed(_) => true
    Value(I32 | I64 | F32 | F64 | V128) => true
    Value(Ref(r)) => r.nullable
  }
}

///|
/// Find a field by name in a struct's declared fields, with its index.
///
/// The index is what the lowering emits; the name is what the reader wrote.
/// Returning both is why this exists rather than a plain search.
pub fn find_field(
  fields : Array[
    @basic.Annotated[
      (@ast.Ident, @wasm_types.MutType[@wasm_types.StorageType[@ast.Ident]]),
      @basic.Location,
    ],
  ],
  name : String,
) -> (Int, @wasm_types.MutType[@wasm_types.StorageType[@ast.Ident]])? {
  for i, f in fields {
    if f.desc.0.name == name {
      return Some((i, f.desc.1))
    }
  }
  None
}

///|
/// The type a concrete allocator produces: a non-null reference to what it
/// allocated.
///
/// EXACT only when custom-descriptors is enabled. At the wasm level
/// `struct.new` really does yield an exact reference -- it allocates that type
/// and no subtype -- but exact reference types are part of that proposal, so
/// without it the plain inexact reference is what can be written down.
pub fn construction_result(
  ctx : @typing_env.ModuleContext,
  name : @ast.Ident,
) -> @infer.Cell[@infer.InferredType]? {
  let exact = ctx.type_context.features.is_enabled(CustomDescriptors)
  internalize(
    ctx.type_context,
    ctx.diagnostics,
    Ref({ nullable: false, typ: if exact { Exact(name) } else { Type(name) } }),
    inline=inline_comptype(ctx, name),
  )
}

///|
/// Whether a byte string decodes as UTF-8.
///
/// Needed because an `i16` array holds code UNITS rather than bytes, so what
/// goes into it has to be text and not an arbitrary blob.
pub fn is_valid_utf8(b : Bytes) -> Bool {
  let n = b.length()
  let mut i = 0
  while i < n {
    let c = b[i].to_int()
    let extra = if c < 0x80 {
      0
    } else if c >= 0xC2 && c <= 0xDF {
      1
    } else if c >= 0xE0 && c <= 0xEF {
      2
    } else if c >= 0xF0 && c <= 0xF4 {
      3
    } else {
      return false
    }
    if i + extra >= n {
      return false
    }
    for k in 1..<=extra {
      let cc = b[i + k].to_int()
      if cc < 0x80 || cc > 0xBF {
        return false
      }
    }
    // The ranges above admit a few sequences the standard excludes -- an
    // overlong three-byte form, a surrogate, a code point past U+10FFFF -- so
    // the first continuation byte is narrowed per lead byte.
    if extra == 2 {
      let cc = b[i + 1].to_int()
      if c == 0xE0 && cc < 0xA0 {
        return false
      }
      if c == 0xED && cc > 0x9F {
        return false
      }
    }
    if extra == 3 {
      let cc = b[i + 1].to_int()
      if c == 0xF0 && cc < 0x90 {
        return false
      }
      if c == 0xF4 && cc > 0x8F {
        return false
      }
    }
    i = i + extra + 1
  }
  true
}

///|
/// Whether an element segment's type fits the array being built from it.
///
/// The segment supplies the values, so its element type must be a SUBTYPE of
/// what the array holds -- the usual direction for anything being stored.
pub fn check_elem_subtype(
  ctx : @typing_env.ModuleContext,
  location : @basic.Location,
  src : @wasm_types.RefType[@ast.Ident],
  dst : @wasm_types.RefType[@ast.Ident],
) -> Unit {
  let s = internalize_valtype(ctx.type_context, ctx.diagnostics, Ref(src))
  let d = internalize_valtype(ctx.type_context, ctx.diagnostics, Ref(dst))
  if s is Some(s) && d is Some(d) {
    if !@type_store.val_subtype(
        ctx.type_context.subtyping_info(),
        s.internal,
        d.internal,
      ) {
      incompatible_element_type(
        ctx.diagnostics,
        location,
        @infer.valtype_cell(s),
        @infer.valtype_cell(d),
      )
    }
  }
}
