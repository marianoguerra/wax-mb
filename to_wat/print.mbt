// The text format.
//
// Ported from the WAT half of wax/src/lib-wasm/output.ml.
//
// The text form is the binary's tree written down: same module, same
// instructions, folded rather than flat and named rather than numbered. Both
// come from one lowering, so the two outputs cannot drift -- which is the
// whole reason the fold is recorded rather than re-derived.

///|
/// An identifier, as the text format spells one: `$name`, or the index when
/// nothing named it.
fn name_or(names : Map[Int, Bytes], i : Int) -> String {
  match names.get(i) {
    Some(b) => ident(b)
    None => i.to_string()
  }
}

///|
/// An identifier as the format spells one: `$x` when every character may
/// appear in a bare identifier, and the quoted `$"..."` form otherwise --
/// which is the only way to write a name that is empty or holds a space.
pub fn ident(b : Bytes) -> String {
  let text = text_of(b)
  if is_bare_identifier(text) {
    "$" + text
  } else {
    "$" + quoted(b)
  }
}

///|
fn is_bare_identifier(s : String) -> Bool {
  if s.is_empty() {
    return false
  }
  for c in s {
    let ok = (c >= '0' && c <= '9') ||
      (c >= 'A' && c <= 'Z') ||
      (c >= 'a' && c <= 'z') ||
      "!#$%&'*+-./:<=>?@\\^_`|~".contains(c.to_string())
    if !ok {
      return false
    }
  }
  true
}

///|
/// A name-section entry as a string. The section stores UTF-8 bytes; the
/// printer wants characters.
fn text_of(b : Bytes) -> String {
  let out = StringBuilder::new()
  let mut k = 0
  while k < b.length() {
    let c = b[k].to_int()
    if c < 0x80 {
      out.write_char(Int::unsafe_to_char(c))
      k = k + 1
    } else if c < 0xE0 && k + 1 < b.length() {
      out.write_char(
        Int::unsafe_to_char(((c & 0x1F) << 6) | (b[k + 1].to_int() & 0x3F)),
      )
      k = k + 2
    } else if c < 0xF0 && k + 2 < b.length() {
      out.write_char(
        Int::unsafe_to_char(
          ((c & 0x0F) << 12) |
          ((b[k + 1].to_int() & 0x3F) << 6) |
          (b[k + 2].to_int() & 0x3F),
        ),
      )
      k = k + 3
    } else if k + 3 < b.length() {
      out.write_char(
        Int::unsafe_to_char(
          ((c & 0x07) << 18) |
          ((b[k + 1].to_int() & 0x3F) << 12) |
          ((b[k + 2].to_int() & 0x3F) << 6) |
          (b[k + 3].to_int() & 0x3F),
        ),
      )
      k = k + 4
    } else {
      k = k + 1
    }
  }
  out.to_string()
}

///|
/// A value type, as the text format spells it.
pub fn valtype(v : @wasm_types.ValType[Int], names : Map[Int, Bytes]) -> String {
  match v {
    I32 => "i32"
    I64 => "i64"
    F32 => "f32"
    F64 => "f64"
    V128 => "v128"
    Ref(r) => reftype(r, names)
  }
}

///|
/// A reference type. The nullable abstract ones have one-word spellings --
/// `funcref` rather than `(ref null func)` -- and the format prefers them.
pub fn reftype(r : @wasm_types.RefType[Int], names : Map[Int, Bytes]) -> String {
  if r.nullable {
    match r.typ {
      Func => return "funcref"
      Extern => return "externref"
      Any => return "anyref"
      Eq => return "eqref"
      I31 => return "i31ref"
      Struct => return "structref"
      Array => return "arrayref"
      Exn => return "exnref"
      Cont => return "contref"
      None_ => return "nullref"
      NoFunc => return "nullfuncref"
      NoExtern => return "nullexternref"
      NoExn => return "nullexnref"
      NoCont => return "nullcontref"
      _ => ()
    }
  }
  let inner = heaptype(r.typ, names)
  if r.nullable {
    "(ref null " + inner + ")"
  } else {
    "(ref " + inner + ")"
  }
}

///|
/// A heap type.
pub fn heaptype(
  h : @wasm_types.HeapType[Int],
  names : Map[Int, Bytes],
) -> String {
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
    Type(i) => name_or(names, i)
    Exact(i) => "(exact " + name_or(names, i) + ")"
  }
}
