// Type expressions.
//
// wap's types are the reason its operators have one spelling each: `<` on a
// `u32` is `i32.lt_u` and on an `i32` is `i32.lt_s`, decided here rather than
// by the programmer picking `<` or `<$` the way was has to.

///|
/// A cursor over the terms of one group.
priv struct Cursor {
  ts : Array[@sh.Node]
  mut i : Int
  src : @er.SourceId
}

///|
fn Cursor::new(ts : Array[@sh.Node], src : @er.SourceId) -> Cursor {
  { ts, i: 0, src, }
}

///|
fn Cursor::done(self : Cursor) -> Bool {
  self.i >= self.ts.length()
}

///|
fn Cursor::peek(self : Cursor) -> @sh.Node? {
  if self.done() {
    None
  } else {
    Some(self.ts[self.i])
  }
}

///|
fn Cursor::next(self : Cursor) -> @sh.Node? {
  match self.peek() {
    Some(n) => {
      self.i += 1
      Some(n)
    }
    None => None
  }
}

///|
fn Cursor::rest_span(self : Cursor) -> @wap.Span {
  if self.ts.length() == 0 {
    @wap.nowhere
  } else if self.done() {
    node_span(self.ts[self.ts.length() - 1])
  } else {
    node_span(self.ts[self.i])
  }
}

///|
/// The scalar a name denotes, if it denotes one.
pub fn builtin_type(name : String) -> @wap.Type? {
  match name {
    "i8" => Some(I8)
    "i16" => Some(I16)
    "i32" => Some(I32)
    "i64" => Some(I64)
    "u8" => Some(U8)
    "u16" => Some(U16)
    "u32" => Some(U32)
    "u64" => Some(U64)
    "f32" => Some(F32)
    "f64" => Some(F64)
    "bool" => Some(Bool)
    "char" => Some(Char)
    "any" => Some(Any)
    "eq" => Some(Eq)
    "i31" => Some(I31)
    _ => None
  }
}

///|
/// Parse one type from the cursor, consuming as much as the type needs.
fn parse_type(c : Cursor) -> @wap.Type raise ParseError {
  let mut t = parse_type_primary(c)
  // postfix `?`
  while c.peek() is Some(n) && is_op(n, "?") {
    c.i += 1
    t = Nullable(t)
  }
  t
}

///|
fn parse_type_primary(c : Cursor) -> @wap.Type raise ParseError {
  let here = c.rest_span()
  match c.next() {
    None => fail_at("expected a type", here, source=c.src)
    Some(n) =>
      match n.it {
        Id("fn") => {
          // fn(a, b) -> c
          let params = []
          match c.peek() {
            Some(p) =>
              match p.it {
                Parens(gs) => {
                  c.i += 1
                  for g in gs {
                    params.push(parse_type(Cursor::new(children(g), c.src)))
                  }
                }
                _ =>
                  fail_at(
                    "expected a parameter list after `fn`",
                    node_span(p),
                    source=c.src,
                  )
              }
            None =>
              fail_at(
                "expected a parameter list after `fn`",
                node_span(n),
                source=c.src,
              )
          }
          let results = parse_results(c)
          Func(params~, results~)
        }
        Id(name) =>
          match builtin_type(name) {
            Some(t) => t
            None => Named(name)
          }
        Brackets(gs) => {
          if gs.length() != 1 {
            fail_at(
              "an array type takes exactly one element type",
              node_span(n),
              source=c.src,
            )
          }
          ArrayOf(parse_type(Cursor::new(children(gs[0]), c.src)))
        }
        Parens(gs) => {
          let items = []
          for g in gs {
            items.push(parse_type(Cursor::new(children(g), c.src)))
          }
          if items.length() == 1 {
            items[0]
          } else {
            Tuple(items)
          }
        }
        _ => fail_at("expected a type", node_span(n), source=c.src)
      }
  }
}

///|
/// An optional `-> t` or `-> (a, b)` result list.
fn parse_results(c : Cursor) -> Array[@wap.Type] raise ParseError {
  match c.peek() {
    Some(n) =>
      if is_op(n, "->") {
        c.i += 1
        let here = c.rest_span()
        match c.peek() {
          None =>
            fail_at("expected a result type after `->`", here, source=c.src)
          Some(r) =>
            match r.it {
              Parens(gs) => {
                c.i += 1
                let out = []
                for g in gs {
                  out.push(parse_type(Cursor::new(children(g), c.src)))
                }
                out
              }
              _ => [parse_type(c)]
            }
        }
      } else {
        []
      }
    None => []
  }
}
