// Lookup tables and small helpers used by the grammar's semantic actions.
//
// Wax spells types as ordinary identifiers rather than keywords -- `i32` is an
// IDENT, not a token -- so the grammar accepts any identifier in a type
// position and classifies it here. That is why "not a value type" is a semantic
// error raised from an action rather than a parse error: the token stream is
// fine, the name is not.

///|
/// Absolute heap types: the ones spelled as a bare keyword-like identifier.
/// Anything else in a heap-type position names a defined type.
let absheaptype_tbl : Map[String, @wasm_types.HeapType[Ident]] = {
  "func": Func,
  "nofunc": NoFunc,
  "exn": Exn,
  "noexn": NoExn,
  "nocont": NoCont,
  "extern": Extern,
  "noextern": NoExtern,
  "any": Any,
  "eq": Eq,
  "i31": I31,
  "struct": Struct,
  "array": Array,
  "none": None_,
}

///|
let valtype_tbl : Map[String, @wasm_types.ValType[Ident]] = {
  "i32": I32,
  "i64": I64,
  "f32": F32,
  "f64": F64,
  "v128": V128,
}

///|
/// Cast types that state a signedness, e.g. `i32_s`, `f64_u`, `i64_s_strict`.
///
/// Built from the same `format_signed_type` the printer uses, so the accepted
/// spellings and the emitted ones cannot drift apart. `strict` (the trapping
/// form) exists only for the integer targets: a float target never traps.
let casttype_tbl : Map[String, @ast.CastType] = build_casttype_tbl()

///|
fn build_casttype_tbl() -> Map[String, @ast.CastType] {
  let m : Map[String, @ast.CastType] = Map([])
  fn add(t : @ast.NumType, s : @wasm_types.Signage, strict : Bool) -> Unit {
    m[@ast.format_signed_type(t, s, strict)] = Signed(typ=t, signage=s, strict~)
  }

  add(I32, Signed, false)
  add(I32, Signed, true)
  add(I32, Unsigned, false)
  add(I32, Unsigned, true)
  add(I64, Signed, false)
  add(I64, Signed, true)
  add(I64, Unsigned, false)
  add(I64, Unsigned, true)
  add(F32, Signed, false)
  add(F32, Unsigned, false)
  add(F64, Signed, false)
  add(F64, Unsigned, false)
  m
}

///|
let storagetype_tbl : Map[String, @wasm_types.StorageType[Ident]] = {
  "i8": Packed(I8),
  "i16": Packed(I16),
  "i32": Value(I32),
  "i64": Value(I64),
  "f32": Value(F32),
  "f64": Value(F64),
  "v128": Value(V128),
}

///|
pub fn heap_type_of(t : Ident) -> @wasm_types.HeapType[Ident] {
  match absheaptype_tbl.get(t.name) {
    Some(h) => h
    None => Type(t)
  }
}

///|
pub fn value_type_of(
  p : (Position, Position),
  t : String,
) -> @wasm_types.ValType[Ident] raise SyntaxError {
  match valtype_tbl.get(t) {
    Some(v) => v
    None => fail_at(loc_of(p), "Identifier '\{t}' is not a value type.")
  }
}

///|
pub fn cast_type_of(
  p : (Position, Position),
  t : String,
) -> @ast.CastType raise SyntaxError {
  match valtype_tbl.get(t) {
    Some(v) => Value(v)
    None =>
      match casttype_tbl.get(t) {
        Some(c) => c
        None => fail_at(loc_of(p), "Identifier '\{t}' is not a cast type.")
      }
  }
}

///|
pub fn storage_type_of(
  p : (Position, Position),
  t : String,
) -> @wasm_types.StorageType[Ident] raise SyntaxError {
  match storagetype_tbl.get(t) {
    Some(s) => s
    None => fail_at(loc_of(p), "Identifier '\{t}' is not a storage type.")
  }
}

///|
/// Apply the `!` exactness marker to a heap type.
///
/// Only a concrete named type can be exact: `&!any` is meaningless, since the
/// abstract types are not describable.
pub fn make_exact(
  p : (Position, Position),
  typ : @wasm_types.HeapType[Ident],
) -> @wasm_types.HeapType[Ident] raise SyntaxError {
  match typ {
    Type(t) => Exact(t)
    _ => fail_at(loc_of(p), "Only a concrete type can be exact.")
  }
}

///|
/// The scalar storage type named by a data-segment numeric run, `[f32: ...]`.
pub fn scalar_storagetype(
  p : (Position, Position),
  t : Ident,
) -> @wasm_types.StorageType[Ident] raise SyntaxError {
  match t.name {
    "i8" => Packed(I8)
    "i16" => Packed(I16)
    "i32" => Value(I32)
    "i64" => Value(I64)
    "f32" => Value(F32)
    "f64" => Value(F64)
    _ =>
      fail_at(
        loc_of(p),
        "A data numeric run needs a scalar element type ('i8', 'i16', 'i32', 'i64', 'f32', or 'f64').",
      )
  }
}

///|
/// The vector shape named by a v128 run element, `i32x4(...)`.
pub fn vec_shape(
  p : (Position, Position),
  s : Ident,
) -> @wasm_types.V128Shape raise SyntaxError {
  match s.name {
    "i8x16" => I8x16
    "i16x8" => I16x8
    "i32x4" => I32x4
    "i64x2" => I64x2
    "f32x4" => F32x4
    "f64x2" => F64x2
    _ =>
      fail_at(
        loc_of(p),
        "A v128 run element is a lane group like i32x4(1, 2, 3, 4).",
      )
  }
}

///|
/// A function or tag is declared with either a type reference (`: name`) or a
/// parenthesized signature; one is required.
///
/// A bare `tag stop;` or `fn f { ... }` is rejected -- write `()` for an empty
/// signature. The message names the exact repair, so a quick fix is derived
/// from it: a zero-width insertion of `()` right after the name or type
/// reference, which is where an empty parameter list belongs.
pub fn decl_sign(
  p : (Position, Position),
  t : Ident?,
  sign : FuncType?,
) -> FuncType? raise SyntaxError {
  if t is None && sign is None {
    let caret = p.1
    fail_at(
      loc_of(p),
      "A parameter list is required.",
      fix=Some({ loc: { start: caret, end: caret }, new_text: "()" }),
    )
  }
  sign
}
