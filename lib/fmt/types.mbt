// Printing the type layer.

///|
pub fn[Info] Ctx::heaptype(self : Ctx[Info], t : @ast.HeapType) -> Unit {
  match t.keyword() {
    Some(kw) => self.typ(kw)
    None =>
      match t {
        Type(s) | Exact(s) => self.typ(s.name)
        _ => ()
      }
  }
}

///|
fn[Info] Ctx::reftype(self : Ctx[Info], t : @ast.RefType) -> Unit {
  // The `!` exact marker sits between the `&`/`&?` sigil and the type name.
  self.punct(
    match (t.nullable, t.typ) {
      (true, Exact(_)) => "&?!"
      (false, Exact(_)) => "&!"
      (true, _) => "&?"
      (false, _) => "&"
    },
  )
  self.heaptype(t.typ)
}

///|
pub fn[Info] Ctx::valtype(self : Ctx[Info], t : @ast.ValType) -> Unit {
  match t {
    I32 => self.typ("i32")
    I64 => self.typ("i64")
    F32 => self.typ("f32")
    F64 => self.typ("f64")
    V128 => self.typ("v128")
    Ref(r) => self.reftype(r)
  }
}

///|
/// A result type: a bare type when there is exactly one and parentheses are not
/// forced, otherwise a parenthesised list.
fn[Info] Ctx::tuple(
  self : Ctx[Info],
  always_paren : Bool,
  l : Array[@ast.ValType],
) -> Unit {
  if l.length() == 1 && !always_paren {
    self.valtype(l[0])
  } else {
    self.paren_list(l, t => self.valtype(t))
  }
}

///|
fn[Info] Ctx::simple_pat(self : Ctx[Info], p : @ast.Ident?) -> Unit {
  match p {
    // Anchored at the identifier's own span, so a comment trailing the name --
    // before a parameter's `: type` -- attaches to it.
    Some(x) => self.atomic_node(Some(x.loc), () => self.ident(x.name))
    None => self.op("_")
  }
}

///|
fn[Info, T] Ctx::key_value(
  self : Ctx[Info],
  key : String,
  value : T,
  print : (T) -> Unit,
) -> Unit {
  self.p.box(indent=indent_level, () => {
    self.ident(key)
    self.punct(":")
    self.space()
    print(value)
  })
}

///|
fn[Info] Ctx::typed_pat(
  self : Ctx[Info],
  pat : @ast.Ident?,
  opt_typ : @ast.ValType?,
) -> Unit {
  self.p.box(indent=indent_level, () => {
    self.simple_pat(pat)
    match opt_typ {
      Some(t) => {
        self.punct(":")
        self.space()
        self.valtype(t)
      }
      None => ()
    }
  })
}

///|
/// A function signature's parameters and results, without the `fn`.
fn[Info] Ctx::raw_functype(self : Ctx[Info], ty : @ast.FuncType) -> Unit {
  self.arg_list(ty.params, p => {
    let (id, t) = p.desc
    // Anchored at the whole parameter, so a trailing comment attaches to it
    // whether or not the parameter is named.
    self.atomic_node(Some(p.info), () => {
      match id {
        None => self.valtype(t)
        Some(_) => self.typed_pat(id, Some(t))
      }
    })
  })
  if ty.results.length() > 0 {
    // `-> Ret` stays glued to the closing `)`, so the parameter list is what
    // breaks when the signature overflows, never the arrow.
    self.p.hbox(() => {
      self.space()
      self.op("->")
      self.space()
      self.tuple(false, ty.results)
    })
  }
}

///|
fn[Info] Ctx::functype(self : Ctx[Info], ty : @ast.FuncType) -> Unit {
  self.p.box(indent=indent_level, () => {
    self.kw("fn")
    self.raw_functype(ty)
  })
}

///|
fn[Info] Ctx::blocktype(self : Ctx[Info], ty : @ast.FuncType) -> Unit {
  if ty.params.length() == 0 && ty.results.length() == 1 {
    self.valtype(ty.results[0])
  } else {
    self.p.box(indent=indent_level, () => self.raw_functype(ty))
  }
}

///|
fn[Info] Ctx::packedtype(self : Ctx[Info], t : @wasm_types.PackedType) -> Unit {
  self.typ(
    match t {
      I8 => "i8"
      I16 => "i16"
    },
  )
}

///|
fn[Info] Ctx::storagetype(self : Ctx[Info], t : @ast.StorageType) -> Unit {
  match t {
    Value(v) => self.valtype(v)
    Packed(p) => self.packedtype(p)
  }
}

///|
/// The bare name of a numeric-literal type suffix: `1i32` -> `"i32"`.
fn suffix_string(t : @ast.StorageType) -> String {
  match t {
    Packed(I8) => "i8"
    Packed(I16) => "i16"
    Value(I32) => "i32"
    Value(I64) => "i64"
    Value(F32) => "f32"
    Value(F64) => "f64"
    // v128 and reference types have no literal suffix; the grammar cannot
    // produce one here.
    _ => ""
  }
}

///|
fn[Info] Ctx::fieldtype(self : Ctx[Info], f : @ast.FieldType) -> Unit {
  if f.mut_ {
    self.p.box(indent=indent_level, () => {
      self.kw("mut")
      self.space()
      self.storagetype(f.typ)
    })
  } else {
    self.storagetype(f.typ)
  }
}

///|
pub fn[Info] Ctx::comptype(self : Ctx[Info], t : @ast.CompType) -> Unit {
  match t {
    Func(ft) => self.functype(ft)
    Struct(l) => {
      // The opening brace is printed by `subtype`.
      self.p.indent(indent_level, () => {
        self.space()
        self.list_commasep(l, field => {
          // A leading `..` inherits the supertype's fields; the parser puts it
          // first, so it prints as the first comma-separated item.
          if @ast.is_splice_field(field) {
            self.punct("..")
          } else {
            let (nm, ft) = field.desc
            // Looked up by the field's own span, so a trailing comment attaches
            // to the whole field.
            self.atomic_node(Some(field.info), () => {
              self.key_value(nm.name, ft, x => self.fieldtype(x))
            })
          }
        })
      })
      self.space()
      self.punct("}")
    }
    Array(ft) => {
      self.punct("[")
      self.p.box(() => self.fieldtype(ft))
      self.punct("]")
    }
    Cont(s) => {
      self.typ("cont")
      self.space()
      self.typ(s.name)
    }
  }
}
