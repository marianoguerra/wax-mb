// What type an expression has.
//
// This is not a type checker -- Wax's checker runs afterwards and is the
// authority. It is the smaller thing the lowering needs: enough to pick a
// signage for an operator, to widen a packed field on the way out, and to know
// which record a method call is on. Where it does not know, it says so, and the
// lowering falls back to what Wax would have inferred anyway.

///|
/// The type of an expression, as far as declarations make it knowable.
fn Lowering::type_of(self : Lowering, e : @wap.Node) -> @wap.Type? {
  match e.it {
    Int(_) => None
    Float(_) => Some(F64)
    BoolLit(_) => Some(Bool)
    CharLit(_) => Some(Char)
    StrLit(_) => Some(ArrayOf(U8))
    Null => None
    TupleLit(items) => {
      let ts = []
      for i in items {
        match self.type_of(i) {
          Some(t) => ts.push(t)
          None => return None
        }
      }
      Some(Tuple(ts))
    }
    SetLit(_) => None
    Var(n) =>
      match self.local_type(n) {
        Some(t) => Some(t)
        None =>
          match self.globals.get(self.qualify(n)) {
            Some(t) => Some(t)
            None =>
              match self.member_owner.get(self.qualify(n)) {
                Some(owner) => Some(Named(owner))
                None =>
                  match self.funcs.get(self.qualify(n)) {
                    Some(sig) =>
                      Some(Func(params=sig.params, results=sig.results))
                    None => None
                  }
              }
          }
      }
    Field(recv, name) => {
      // `hashing.limit` is a name in another module, not a field of a local.
      match self.module_ref(recv, name) {
        Some(q) => return self.type_of({ it: Var(q), span: e.span, })
        None => ()
      }
      match self.type_of(recv) {
        Some(t) =>
          match self.record_name(t) {
            Some(r) => self.field_type(r, name)
            None => None
          }
        None => None
      }
    }
    Index(a, _) =>
      match self.type_of(a) {
        Some(t) => self.elem_type(t)
        None => None
      }
    Call(callee, _) =>
      match callee.it {
        Var(n) =>
          match self.funcs.get(self.qualify(n)) {
            Some(sig) => one_result(sig.results)
            None => None
          }
        _ =>
          match self.type_of(callee) {
            Some(Func(results~, ..)) => one_result(results)
            _ => None
          }
      }
    MethodCall(recv, name, _) => {
      if name == "len" {
        return Some(I32)
      }
      match self.type_of(recv) {
        Some(t) =>
          match self.record_name(t) {
            Some(r) =>
              match self.lookup_method(r, name) {
                Some(sig) => one_result(sig.results)
                None => None
              }
            None => None
          }
        None => None
      }
    }
    Bin(op, a, b) =>
      match op {
        Eq | Ne | Lt | Gt | Le | Ge => Some(Bool)
        _ =>
          match self.type_of(a) {
            Some(t) => Some(t)
            None => self.type_of(b)
          }
      }
    Un(Neg, a) => self.type_of(a)
    Un(Not, _) => Some(Bool)
    AndAlso(_, _) | OrElse(_, _) | InSet(_, _) | Test(_, _) => Some(Bool)
    Cast(_, t) => Some(t)
    NonNull(inner) =>
      match self.type_of(inner) {
        Some(Nullable(t)) => Some(t)
        other => other
      }
    RecordLit(typ~, ..) | RecordDefault(typ~) =>
      match typ {
        Some(n) => Some(Named(n))
        None => None
      }
    ArrayLit(typ~, ..) | ArrayRepeat(typ~, ..) =>
      match typ {
        Some(n) => Some(Named(n))
        None => None
      }
    Block(body) => self.type_of_body(body)
    If(arms~, typ~) =>
      match typ {
        Some(t) => Some(t)
        None =>
          if arms.length() == 0 {
            None
          } else {
            self.type_of_body(arms[0].1)
          }
      }
    Match(arms~, typ~, ..) =>
      match typ {
        Some(t) => Some(t)
        None =>
          if arms.length() == 0 {
            None
          } else {
            self.type_of_body(arms[0].body)
          }
      }
    _ => None
  }
}

///|
fn one_result(results : Array[@wap.Type]) -> @wap.Type? {
  if results.length() == 1 {
    Some(results[0])
  } else {
    None
  }
}

///|
fn Lowering::type_of_body(
  self : Lowering,
  body : Array[@wap.Node],
) -> @wap.Type? {
  if body.length() == 0 {
    None
  } else {
    self.type_of(body[body.length() - 1])
  }
}

///|
/// A method on a record, searching its ancestors.
fn Lowering::lookup_method(
  self : Lowering,
  record : String,
  name : String,
) -> FnSig? {
  match self.methods.get(self.qualify(record) + "." + name) {
    Some(s) => Some(s)
    None =>
      match self.resolve(record) {
        Some(Record(parent=Some(p), ..)) => self.lookup_method(p, name)
        _ => None
      }
  }
}
