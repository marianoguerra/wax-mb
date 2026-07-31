// A JSON rendering of the AST, for snapshot tests.
//
// The differential harness cannot check the SHAPE of the tree until the
// printer lands: accept/reject says nothing about whether the right nodes were
// built. These snapshots stand in until then, and remain useful afterwards as
// the readable form of an intentional AST change.
//
// Spans are rendered through @basic.show_loc, so a snapshot can be taken with
// them hidden (readable, low-churn) or shown (when a span is what is under
// test).

///|
fn tagged(kind : String, children : Map[String, Json]) -> Json {
  { "kind": kind, "children": children }
}

///|
fn[T] arr(xs : Array[T], f : (T) -> Json) -> Json {
  let out = []
  for x in xs {
    out.push(f(x))
  }
  Json::array(out)
}

///|
fn[T] opt(x : T?, f : (T) -> Json) -> Json {
  match x {
    Some(v) => f(v)
    None => Json::null()
  }
}

///|
pub fn Ident::to_json(self : Ident) -> Json {
  Json::string(self.name)
}

///|
pub fn valtype_json(t : ValType) -> Json {
  match t {
    I32 => "i32"
    I64 => "i64"
    F32 => "f32"
    F64 => "f64"
    V128 => "v128"
    Ref(r) =>
      return {
        "ref": heaptype_json(r.typ),
        "nullable": Json::boolean(r.nullable),
      }
  }
}

///|
pub fn heaptype_json(h : HeapType) -> Json {
  match h.keyword() {
    Some(k) => Json::string(k)
    None =>
      match h {
        Type(t) => { "type": t.to_json() }
        Exact(t) => { "exact": t.to_json() }
        _ => Json::string("?")
      }
  }
}

///|
pub fn FuncType::to_json(self : FuncType) -> Json {
  {
    "params": arr(self.params, p => {
      "name": opt(p.desc.0, i => i.to_json()),
      "type": valtype_json(p.desc.1),
    }),
    "results": arr(self.results, t => valtype_json(t)),
  }
}

///|
/// The instruction tree.
///
/// Deliberately shallow in places -- a node's own kind and its children, not
/// every field -- because these snapshots exist to catch a wrong SHAPE, and a
/// full dump would churn on every unrelated change.
pub fn[Info] Instr::to_json(self : Instr[Info]) -> Json {
  self.desc.to_json()
}

///|
fn[Info] body_json(b : Body[Info]) -> Json {
  arr(b.desc, i => i.to_json())
}

///|
pub fn[Info] InstrDesc::to_json(self : InstrDesc[Info]) -> Json {
  match self {
    Unreachable => Json::string("unreachable")
    Nop => Json::string("nop")
    Hole => Json::string("_")
    Null => Json::string("null")
    Get(x) => tagged("get", { "name": x.to_json() })
    Path(a, b) => tagged("path", { "ns": a.to_json(), "member": b.to_json() })
    Int(s) => tagged("int", { "raw": Json::string(s) })
    Float(s) => tagged("float", { "raw": Json::string(s) })
    Char(c) => tagged("char", { "value": Json::string(c.to_string()) })
    Str(t, s) =>
      tagged("string", {
        "prefix": opt(t, i => i.to_json()),
        "value": Json::string(s),
      })
    Block(label~, block~, ..) =>
      tagged("block", {
        "label": opt(label, l => l.to_json()),
        "body": body_json(block),
      })
    Loop(label~, block~, ..) =>
      tagged("loop", {
        "label": opt(label, l => l.to_json()),
        "body": body_json(block),
      })
    While(label~, cond~, step~, block~) =>
      tagged("while", {
        "label": opt(label, l => l.to_json()),
        "cond": cond.to_json(),
        "step": opt(step, s => s.to_json()),
        "body": body_json(block),
      })
    If(label~, cond~, if_block~, else_block~, ..) =>
      tagged("if", {
        "label": opt(label, l => l.to_json()),
        "cond": cond.to_json(),
        "then": body_json(if_block),
        "else": opt(else_block, b => body_json(b)),
      })
    Let(binds, init) =>
      tagged("let", {
        "bindings": arr(binds, b => {
          "name": opt(b.0, i => i.to_json()),
          "type": opt(b.1, t => valtype_json(t)),
        }),
        "init": opt(init, i => i.to_json()),
      })
    Set(x, op, v) =>
      tagged("set", {
        "name": x.to_json(),
        "op": opt(op, o => Json::string(binop_name(o.desc))),
        "value": v.to_json(),
      })
    Tee(x, v) => tagged("tee", { "name": x.to_json(), "value": v.to_json() })
    Call(f, args) =>
      tagged("call", {
        "callee": f.to_json(),
        "args": arr(args, a => a.to_json()),
      })
    TailCall(f, args) =>
      tagged("become", {
        "callee": f.to_json(),
        "args": arr(args, a => a.to_json()),
      })
    BinOpI(op, l, r) =>
      tagged("binop", {
        "op": Json::string(binop_name(op.desc)),
        "lhs": l.to_json(),
        "rhs": r.to_json(),
      })
    UnOpI(op, v) =>
      tagged("unop", {
        "op": Json::string(
          match op.desc {
            Neg => "-"
            Pos => "+"
            Not => "!"
          },
        ),
        "operand": v.to_json(),
      })
    Return(v) => tagged("return", { "value": opt(v, i => i.to_json()) })
    Br(l, v) =>
      tagged("br", { "label": l.to_json(), "value": opt(v, i => i.to_json()) })
    BrIf(l, v) => tagged("br_if", { "label": l.to_json(), "cond": v.to_json() })
    Sequence(xs) => tagged("sequence", { "items": arr(xs, i => i.to_json()) })
    Select(c, a, b) =>
      tagged("select", {
        "cond": c.to_json(),
        "then": a.to_json(),
        "else": b.to_json(),
      })
    StructGet(e, f) =>
      tagged("struct.get", { "object": e.to_json(), "field": f.to_json() })
    Struct(t, fields) =>
      tagged("struct", {
        "type": opt(t, i => i.to_json()),
        "fields": arr(fields, f => {
          "name": f.0.to_json(),
          // None is the punning shorthand `{x}`; kept distinguishable.
          "value": opt(f.1, v => v.to_json()),
        }),
      })
    Cast(e, _) => tagged("cast", { "operand": e.to_json() })
    Test(e, _) => tagged("test", { "operand": e.to_json() })
    NonNull(e) => tagged("non_null", { "operand": e.to_json() })
    // Everything else renders as its constructor name alone: these snapshots
    // are for shape, and spelling out all 67 arms would churn without adding
    // signal.
    _ => Json::string("...")
  }
}

///|
fn binop_name(op : BinOp) -> String {
  match op {
    Add => "+"
    Sub => "-"
    Mul => "*"
    Div(None) => "/"
    Div(Some(Signed)) => "/s"
    Div(Some(Unsigned)) => "/u"
    Rem(Signed) => "%s"
    Rem(Unsigned) => "%u"
    And => "&"
    Or => "|"
    Xor => "^"
    Shl => "<<"
    Shr(Signed) => ">>s"
    Shr(Unsigned) => ">>u"
    Eq => "=="
    Ne => "!="
    Lt(None) => "<"
    Lt(Some(Signed)) => "<s"
    Lt(Some(Unsigned)) => "<u"
    Gt(None) => ">"
    Gt(Some(Signed)) => ">s"
    Gt(Some(Unsigned)) => ">u"
    Le(None) => "<="
    Le(Some(Signed)) => "<=s"
    Le(Some(Unsigned)) => "<=u"
    Ge(None) => ">="
    Ge(Some(Signed)) => ">=s"
    Ge(Some(Unsigned)) => ">=u"
  }
}

///|
pub fn[Info] ModuleField::to_json(self : ModuleField[Info]) -> Json {
  match self {
    Func(name~, body~, attributes~, ..) =>
      tagged("fn", {
        "name": name.to_json(),
        "attrs": arr(attributes, a => Json::string(a.attr_name)),
        "label": opt(body.0, l => l.to_json()),
        "body": arr(body.1, i => i.to_json()),
      })
    Global(name~, mut_~, def~, attributes~, ..) =>
      tagged("global", {
        "name": name.to_json(),
        "mut": Json::boolean(mut_),
        "attrs": arr(attributes, a => Json::string(a.attr_name)),
        "value": def.to_json(),
      })
    Type(_) => tagged("type", {})
    Tag(name~, ..) => tagged("tag", { "name": name.to_json() })
    Memory(name~, ..) => tagged("memory", { "name": name.to_json() })
    Data(name~, ..) => tagged("data", { "name": opt(name, i => i.to_json()) })
    Table(name~, ..) => tagged("table", { "name": name.to_json() })
    Elem(name~, ..) => tagged("elem", { "name": name.to_json() })
    Import(module_~, decl~) =>
      tagged("import", {
        "module": Json::string(module_.desc),
        "name": decl.desc.id.to_json(),
      })
    ImportGroup(module_~, decls~) =>
      tagged("import_group", {
        "module": Json::string(module_.desc),
        "items": arr(decls, d => d.desc.id.to_json()),
      })
    ModuleAnnotation(attrs) =>
      tagged("module_annotation", {
        "attrs": arr(attrs, a => Json::string(a.attr_name)),
      })
    Conditional(then_fields~, else_fields~, ..) =>
      tagged("conditional", {
        "then": arr(then_fields.desc, f => f.desc.to_json()),
        "else": opt(else_fields, e => arr(e.desc, f => f.desc.to_json())),
      })
  }
}

///|
/// The whole module.
pub fn[Info] module_to_json(m : Module[Info]) -> Json {
  arr(m, f => f.desc.to_json())
}
