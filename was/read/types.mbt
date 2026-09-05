// Type expressions.
//
// Was keeps Wax's spelling everywhere it can: `&t`, `&?t`, `&!t` and `&?!t` are
// the same four operators, `mut` is the same modifier, and the heap types have
// the same names. The only change is `::` where Wax writes `:`, which is forced
// -- a `:` opens a block in shrubbery and can appear only once, at the end of a
// group.

///|
/// The abstract heap type a name denotes.
fn abstract_heap(name : String) -> @wasm_types.HeapType[@ast.Ident]? {
  match name {
    "func" => Some(Func)
    "nofunc" => Some(NoFunc)
    "exn" => Some(Exn)
    "noexn" => Some(NoExn)
    "cont" => Some(Cont)
    "nocont" => Some(NoCont)
    "extern" => Some(Extern)
    "noextern" => Some(NoExtern)
    "any" => Some(Any)
    "eq" => Some(Eq)
    "i31" => Some(I31)
    "struct" => Some(Struct)
    "array" => Some(Array)
    "none" => Some(None_)
    _ => None
  }
}

///|
/// The reference-type prefix an operator is: nullable, exact, or neither.
fn ref_prefix(name : String) -> (Bool, Bool)? {
  match name {
    "&" => Some((false, false))
    "&?" => Some((true, false))
    "&!" => Some((false, true))
    "&?!" => Some((true, true))
    _ => None
  }
}

///|
/// One value type.
fn Cursor::valtype(
  self : Cursor,
) -> @wasm_types.ValType[@ast.Ident] raise ReadError {
  let here = self.here()
  match self.peek() {
    None => fail_at("expected a type", here, source=self.r.src)
    Some(n) =>
      match n.it {
        Id("i32") => {
          self.i += 1
          I32
        }
        Id("i64") => {
          self.i += 1
          I64
        }
        Id("f32") => {
          self.i += 1
          F32
        }
        Id("f64") => {
          self.i += 1
          F64
        }
        Id("v128") => {
          self.i += 1
          V128
        }
        _ => Ref(self.reftype())
      }
  }
}

///|
/// One reference type: a prefix operator and a heap type.
fn Cursor::reftype(
  self : Cursor,
) -> @wasm_types.RefType[@ast.Ident] raise ReadError {
  let here = self.here()
  let n = match self.next() {
    Some(n) => n
    None => fail_at("expected a reference type", here, source=self.r.src)
  }
  let (nullable, exact) = match as_op(n) {
    Some(op) =>
      match ref_prefix(op) {
        Some(p) => p
        None =>
          fail_at(
            "expected `&`, `&?`, `&!` or `&?!`",
            node_span(n),
            source=self.r.src,
          )
      }
    None => fail_at("expected a type", node_span(n), source=self.r.src)
  }
  let typ = self.heaptype(exact)
  { nullable, typ, }
}

///|
fn Cursor::heaptype(
  self : Cursor,
  exact : Bool,
) -> @wasm_types.HeapType[@ast.Ident] raise ReadError {
  let here = self.here()
  let n = match self.next() {
    Some(n) => n
    None => fail_at("expected a heap type", here, source=self.r.src)
  }
  match as_id(n) {
    Some(name) =>
      match abstract_heap(name) {
        Some(h) =>
          if exact {
            fail_at(
              "an abstract heap type is never exact",
              node_span(n),
              source=self.r.src,
            )
          } else {
            h
          }
        None =>
          if exact {
            Exact(self.r.ident(name, node_span(n)))
          } else {
            Type(self.r.ident(name, node_span(n)))
          }
      }
    None => fail_at("expected a heap type", node_span(n), source=self.r.src)
  }
}

///|
/// A field or element type: `i8`/`i16` stay packed, everything else is a value.
fn Cursor::storagetype(
  self : Cursor,
) -> @wasm_types.StorageType[@ast.Ident] raise ReadError {
  match self.peek() {
    Some(n) if is_id(n, "i8") => {
      self.i += 1
      Packed(I8)
    }
    Some(n) if is_id(n, "i16") => {
      self.i += 1
      Packed(I16)
    }
    _ => Value(self.valtype())
  }
}

///|
/// A storage type with an optional `mut`.
fn Cursor::muttype(
  self : Cursor,
) -> @wasm_types.MutType[@wasm_types.StorageType[@ast.Ident]] raise ReadError {
  let mut_ = self.eat_id("mut")
  { mut_, typ: self.storagetype(), }
}

///|
/// An optional `-> t` or `-> (a, b)` result list.
fn Cursor::results(
  self : Cursor,
) -> Array[@wasm_types.ValType[@ast.Ident]] raise ReadError {
  if !self.eat_op("->") {
    return []
  }
  let here = self.here()
  match self.peek() {
    None =>
      fail_at("expected a result type after `->`", here, source=self.r.src)
    Some(n) =>
      match n.it {
        Parens(gs) => {
          self.i += 1
          let out = []
          for g in gs {
            out.push(Cursor::new(children(g), self.r).valtype())
          }
          out
        }
        _ => [self.valtype()]
      }
  }
}

///|
/// A parameter list: `(i32, x :: i32)`, where a name is optional because
/// wasm's is.
fn Reader::params(
  self : Reader,
  gs : Array[@sh.Node],
) -> Array[
  @basic.Annotated[
    (@ast.Ident?, @wasm_types.ValType[@ast.Ident]),
    @basic.Location,
  ],
] raise ReadError {
  let out : Array[
    @basic.Annotated[
      (@ast.Ident?, @wasm_types.ValType[@ast.Ident]),
      @basic.Location,
    ],
  ] = []
  for g in gs {
    let ts = children(g)
    let at = self.loc(terms_span(ts[:]))
    if ts.length() >= 2 && as_id(ts[0]) is Some(name) && is_op(ts[1], "::") {
      let typ = Cursor::new(ts[2:].to_owned(), self).valtype()
      out.push({
        desc: (Some(self.ident(name, node_span(ts[0]))), typ),
        info: at,
      })
    } else {
      let typ = Cursor::new(ts, self).valtype()
      out.push({ desc: (None, typ), info: at, })
    }
  }
  out
}

///|
/// A whole function signature: the parameter list and the results.
fn Reader::signature(
  self : Reader,
  params : @sh.Node,
  c : Cursor,
) -> @ast.FuncType raise ReadError {
  let ps = match params.it {
    Parens(gs) => self.params(gs)
    _ =>
      fail_at("expected a parameter list", node_span(params), source=self.src)
  }
  { params: ps, results: c.results(), }
}
