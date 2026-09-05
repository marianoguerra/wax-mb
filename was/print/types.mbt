// Types, printed.

///|
/// A value type.
pub fn valtype(t : @wasm_types.ValType[@ast.Ident]) -> String {
  match t {
    I32 => "i32"
    I64 => "i64"
    F32 => "f32"
    F64 => "f64"
    V128 => "v128"
    Ref(r) => reftype(r)
  }
}

///|
/// A reference type: the prefix says nullable and exact, the rest says what.
pub fn reftype(r : @wasm_types.RefType[@ast.Ident]) -> String {
  let exact = r.typ is Exact(_)
  let prefix = match (r.nullable, exact) {
    (false, false) => "&"
    (true, false) => "&?"
    (false, true) => "&!"
    (true, true) => "&?!"
  }
  prefix + heaptype(r.typ)
}

///|
pub fn heaptype(h : @wasm_types.HeapType[@ast.Ident]) -> String {
  match h {
    Func => "func"
    NoFunc => "nofunc"
    Exn => "exn"
    NoExn => "noexn"
    Cont => "cont"
    NoCont => "nocont"
    Extern => "extern"
    NoExtern => "noextern"
    Any => "any"
    Eq => "eq"
    I31 => "i31"
    Struct => "struct"
    Array => "array"
    None_ => "none"
    Type(i) => i.name
    Exact(i) => i.name
  }
}

///|
/// A field or element type.
pub fn storagetype(t : @wasm_types.StorageType[@ast.Ident]) -> String {
  match t {
    Packed(I8) => "i8"
    Packed(I16) => "i16"
    Value(v) => valtype(v)
  }
}

///|
/// A storage type with its mutability.
pub fn muttype(
  t : @wasm_types.MutType[@wasm_types.StorageType[@ast.Ident]],
) -> String {
  if t.mut_ {
    "mut " + storagetype(t.typ)
  } else {
    storagetype(t.typ)
  }
}

///|
/// A parameter list, with the names wasm allows it to omit.
pub fn params(f : @ast.FuncType) -> String {
  let out = []
  for p in f.params {
    let (name, typ) = p.desc
    out.push(
      match name {
        Some(n) => n.name + " :: " + valtype(typ)
        None => valtype(typ)
      },
    )
  }
  "(" + out.join(", ") + ")"
}

///|
/// An optional `-> t` or `-> (a, b)`.
pub fn results(f : @ast.FuncType) -> String {
  match f.results.length() {
    0 => ""
    1 => " -> " + valtype(f.results[0])
    _ => " -> (" + f.results.map(valtype).join(", ") + ")"
  }
}

///|
/// A whole signature.
pub fn signature(f : @ast.FuncType) -> String {
  params(f) + results(f)
}

///|
/// The block-result annotation a `do`, `if` or `try` carries, or nothing when
/// it was written without one.
pub fn block_type(f : @ast.FuncType) -> String {
  if f.params.length() == 0 && f.results.length() == 0 {
    ""
  } else {
    results(f)
  }
}
