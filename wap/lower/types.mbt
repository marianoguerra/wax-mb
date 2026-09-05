// wap types to Wax types.
//
// The one interesting decision here is that `u32` and `i32` are the same wasm
// type and differ only in the `Signage` they hand to an operator. Everything
// else is bookkeeping: which wap types are nominal in Wax (records, arrays,
// function types) and which are transparent (enumerations, subranges, sets, and
// aliases to scalars).

///|
/// The declaration a type name refers to.
fn Lowering::resolve(self : Lowering, name : String) -> @wap.TypeDef? {
  self.types.get(self.qualify(name))
}

///|
/// True when the name becomes a Wax type declaration of its own, rather than
/// disappearing into the scalar it stands for.
fn Lowering::nominal(self : Lowering, name : String) -> Bool {
  match self.resolve(name) {
    Some(Record(..)) => true
    Some(Alias(ArrayOf(_))) => true
    Some(Alias(Func(..))) => true
    _ => false
  }
}

///|
/// Follow aliases, enumerations, subranges and sets down to the type that
/// decides how an operator behaves.
fn Lowering::underlying(self : Lowering, t : @wap.Type) -> @wap.Type {
  match t {
    Named(n) =>
      match self.resolve(n) {
        Some(Enum(_)) => I32
        Some(Subrange(..)) => I32
        Some(SetOf(_)) => I32
        Some(Alias(inner)) =>
          if self.nominal(n) {
            t
          } else {
            self.underlying(inner)
          }
        _ => t
      }
    _ => t
  }
}

///|
/// Whether an integer type is signed, unsigned, or not an integer at all.
fn Lowering::signage(self : Lowering, t : @wap.Type?) -> @wasm_types.Signage? {
  match t {
    None => Some(Signed)
    Some(t) =>
      match self.underlying(t) {
        I8 | I16 | I32 | I64 => Some(Signed)
        U8 | U16 | U32 | U64 => Some(Unsigned)
        Bool | Char => Some(Unsigned)
        F32 | F64 => None
        _ => None
      }
  }
}

///|
/// A wap type as a Wax value type.
fn Lowering::valtype(
  self : Lowering,
  t : @wap.Type,
  span : @wap.Span,
) -> @wasm_types.ValType[@ast.Ident] {
  match t {
    I8 | I16 | I32 | U8 | U16 | U32 | Bool | Char => I32
    I64 | U64 => I64
    F32 => F32
    F64 => F64
    Any => Ref({ nullable: false, typ: Any, })
    Eq => Ref({ nullable: false, typ: Eq, })
    I31 => Ref({ nullable: false, typ: I31, })
    ArrayOf(e) =>
      Ref({
        nullable: false,
        typ: Type(self.ident(self.array_type(e, span), span)),
      })
    Func(params~, results~) =>
      Ref({
        nullable: false,
        typ: Type(self.ident(self.func_type(params, results, span), span)),
      })
    Named(n) =>
      if self.nominal(n) {
        Ref({ nullable: false, typ: Type(self.ident(self.mangle(n), span)), })
      } else {
        match self.resolve(n) {
          Some(_) => self.valtype(self.underlying(t), span)
          None => {
            self.error("`" + n + "` is not a type in this module", span)
            I32
          }
        }
      }
    Nullable(inner) => {
      let v = self.valtype(inner, span)
      match v {
        Ref(r) => Ref({ ..r, nullable: true, })
        _ => {
          self.error(
            "only a reference can be nullable",
            span,
            help="`?` applies to a record, an array, a function type or `any`",
          )
          v
        }
      }
    }
    Tuple(_) => {
      self.error(
        "a tuple cannot appear here",
        span,
        help="tuples exist on results and bindings only -- wasm has no tuple value, so storing one would mean allocating a record wap did not write down",
      )
      I32
    }
  }
}

///|
/// A wap type as the storage type of a record field or an array element.
///
/// This is where `u8` stops being an i32: in storage position it is a packed
/// byte, and every read of it therefore needs the zero-extending cast that Wax
/// makes the programmer write by hand.
fn Lowering::storage(
  self : Lowering,
  t : @wap.Type,
  span : @wap.Span,
) -> @wasm_types.StorageType[@ast.Ident] {
  match self.underlying(t) {
    I8 | U8 | Bool => Packed(I8)
    I16 | U16 => Packed(I16)
    _ => Value(self.valtype(t, span))
  }
}

///|
/// True when the type is stored packed, and so has to be widened on every read.
fn Lowering::is_packed(self : Lowering, t : @wap.Type) -> Bool {
  match self.underlying(t) {
    I8 | U8 | I16 | U16 | Bool => true
    _ => false
  }
}

///|
/// The element type of an array type, if it is one.
fn Lowering::elem_type(self : Lowering, t : @wap.Type) -> @wap.Type? {
  match t {
    ArrayOf(e) => Some(e)
    Nullable(inner) => self.elem_type(inner)
    Named(n) =>
      match self.resolve(n) {
        Some(Alias(inner)) => self.elem_type(inner)
        _ => None
      }
    _ => None
  }
}

///|
/// The record a type names, following aliases and `?`.
fn Lowering::record_name(self : Lowering, t : @wap.Type) -> String? {
  match t {
    Named(n) =>
      match self.resolve(n) {
        Some(Record(..)) => Some(self.qualify(n))
        Some(Alias(inner)) => self.record_name(inner)
        _ => None
      }
    Nullable(inner) => self.record_name(inner)
    _ => None
  }
}

///|
/// A field's type, searching the record's ancestors.
fn Lowering::field_type(
  self : Lowering,
  record : String,
  field : String,
) -> @wap.Type? {
  match self.resolve(record) {
    Some(Record(parent~, fields~)) => {
      for f in fields {
        if f.name == field {
          return Some(f.typ)
        }
      }
      match parent {
        Some(p) => self.field_type(p, field)
        None => None
      }
    }
    _ => None
  }
}

///|
/// Rewrite every name inside a type so it says which module owns it.
///
/// Doing this once, when the declaration is collected, is what keeps the rest
/// of the lowering from having to know which module a stored type came from.
fn Lowering::qualify_typ(self : Lowering, t : @wap.Type) -> @wap.Type {
  match t {
    Named(n) =>
      match builtin_or_self(n) {
        true => t
        false => Named(self.qualify(n))
      }
    Nullable(i) => Nullable(self.qualify_typ(i))
    ArrayOf(e) => ArrayOf(self.qualify_typ(e))
    Tuple(ts) => Tuple(ts.map(x => self.qualify_typ(x)))
    Func(params~, results~) =>
      Func(
        params=params.map(x => self.qualify_typ(x)),
        results=results.map(x => self.qualify_typ(x)),
      )
    _ => t
  }
}

///|
/// A name that is already qualified needs no help.
fn builtin_or_self(n : String) -> Bool {
  n.contains(".")
}

///|
/// The same, for a whole declaration.
fn Lowering::qualify_def(self : Lowering, d : @wap.TypeDef) -> @wap.TypeDef {
  match d {
    Record(parent~, fields~) =>
      Record(
        parent=match parent {
          Some(p) => Some(self.qualify(p))
          None => None
        },
        fields=fields.map(f => {
          (
            {
              name: f.name,
              mut_: f.mut_,
              typ: self.qualify_typ(f.typ),
              span: f.span,
            } : @wap.Field)
        }),
      )
    SetOf(e) => SetOf(self.qualify(e))
    Alias(t) => Alias(self.qualify_typ(t))
    _ => d
  }
}

///|
/// Every record that some other record extends, and so must stay open.
fn Lowering::parents(self : Lowering) -> Map[String, Unit] {
  let out : Map[String, Unit] = Map([])
  for _, def in self.types {
    if def is Record(parent=Some(p), ..) {
      out[p] = ()
    }
  }
  out
}

// ---------------------------------------------------- generated type names

///|
/// The Wax type name for an inline `[t]`, interning by structure so that two
/// occurrences of `[i32]` are the same wasm type.
fn Lowering::array_type(
  self : Lowering,
  elem : @wap.Type,
  span : @wap.Span,
) -> String {
  let key = "a:" + self.type_key(elem)
  match self.anon.get(key) {
    Some(n) => n
    None => {
      let name = self.mangle(
        "anon_array_" + (self.anon.length() + 1).to_string(),
      )
      self.anon[key] = name
      let at = self.loc(span)
      let st = self.storage(elem, span)
      self.extra_types.push({
        desc: (
          { name, loc: at, },
          {
            typ: Array({ mut_: true, typ: st, }),
            supertype: None,
            final_: true,
            descriptor: None,
            describes: None,
          },
        ),
        info: at,
      })
      name
    }
  }
}

///|
/// The Wax type name for an inline `fn(a) -> b`.
fn Lowering::func_type(
  self : Lowering,
  params : Array[@wap.Type],
  results : Array[@wap.Type],
  span : @wap.Span,
) -> String {
  let key = "f:" +
    params.map(t => self.type_key(t)).join(",") +
    "->" +
    results.map(t => self.type_key(t)).join(",")
  match self.anon.get(key) {
    Some(n) => n
    None => {
      let name = self.mangle("anon_fn_" + (self.anon.length() + 1).to_string())
      self.anon[key] = name
      let at = self.loc(span)
      let ps = []
      for t in params {
        ps.push(
          (
            { desc: (None, self.valtype(t, span)), info: at, } :
            @basic.Annotated[
              (@ast.Ident?, @wasm_types.ValType[@ast.Ident]),
              @basic.Location,
            ]),
        )
      }
      let rs = []
      for t in results {
        rs.push(self.valtype(t, span))
      }
      self.extra_types.push({
        desc: (
          { name, loc: at, },
          {
            typ: Func({ params: ps, results: rs, }),
            supertype: None,
            final_: true,
            descriptor: None,
            describes: None,
          },
        ),
        info: at,
      })
      name
    }
  }
}

///|
/// A structural key, so that equal types intern to one name.
fn Lowering::type_key(self : Lowering, t : @wap.Type) -> String {
  match t {
    I8 => "i8"
    I16 => "i16"
    I32 => "i32"
    I64 => "i64"
    U8 => "u8"
    U16 => "u16"
    U32 => "u32"
    U64 => "u64"
    F32 => "f32"
    F64 => "f64"
    Bool => "bool"
    Char => "char"
    Any => "any"
    Eq => "eq"
    I31 => "i31"
    Named(n) => "n:" + n
    Nullable(i) => "?" + self.type_key(i)
    ArrayOf(e) => "[" + self.type_key(e) + "]"
    Tuple(ts) => "(" + ts.map(t => self.type_key(t)).join(",") + ")"
    Func(params~, results~) =>
      "f(" +
      params.map(t => self.type_key(t)).join(",") +
      "->" +
      results.map(t => self.type_key(t)).join(",") +
      ")"
  }
}
