// The module, as the text format writes it.
//
// No `(module ...)` wrapper unless the module is named: the reference lays an
// unnamed one out as its FIELDS, one per line, because that is what a wax
// module converts to -- a list of them, not a nested document.

///|
/// Print a module's text form.
pub fn print_module(m : @wasm_bin.Module) -> String raise WatError {
  let fields : Array[Sexp] = []
  for f in m.field_order {
    fields.push(field(m, f))
  }
  // A type nothing declared is NOT written. The section holds every signature
  // the lowering interned -- a block's, an import's, a `call_indirect`'s --
  // and the text format spells all of those inline where they are used. Only a
  // type the source wrote down is a field.
  //
  // The element segments minted to declare function references are different:
  // there is nowhere else to put a declarative segment, so it follows the
  // fields that were written.
  let placed_elems : Map[Int, Bool] = Map([])
  for f in m.field_order {
    if f is FElem(k) {
      placed_elems[k] = true
    }
  }
  for k in 0..<m.elems.length() {
    if !placed_elems.contains(k) {
      fields.push(elem_field(m, k))
    }
  }
  if m.start is Some(f) {
    fields.push(List([Atom("start"), Atom(name_or(m.names.functions, f))]))
  }
  // A NAMED module keeps its wrapper, and then its fields are one level deeper
  // -- which is what makes them pack rather than each claim its own block.
  match m.names.module_ {
    Some(n) => {
      let l : Array[Sexp] = [
        Block([Atom("module"), Atom("$" + text_of(n))], KBox, true),
      ]
      for f in fields {
        l.push(f)
      }
      render(List(l), top_depth=0) + "\n"
    }
    None => render(VBlock(fields)) + "\n"
  }
}

///|
/// One module field, written where the source put it.
fn field(m : @wasm_bin.Module, f : @wasm_bin.FieldRef) -> Sexp raise WatError {
  match f {
    // A `rec` group is one field holding several definitions; a lone type is
    // written bare, because a singleton `rec` is a DIFFERENT type and the
    // source said which it wrote.
    FTypes([k]) => subtype_field(m, k)
    FTypes(ks) => {
      let l : Array[Sexp] = [Atom("rec")]
      for k in ks {
        l.push(subtype_field(m, k))
      }
      List(l)
    }
    FFeature(name) => List([Atom("@feature"), Atom(quoted(name))])
    FImport(k) => import_field(m, k)
    FFunc(k) => function_field(m, k, m.codes[k])
    FTable(k) => table_field(m, k)
    FMemory(k) => memory_field(m, k)
    FGlobal(k) => global_field(m, k)
    FTag(k) => tag_field(m, k)
    FElem(k) => elem_field(m, k)
    FData(k) => data_field(m, k)
  }
}

///|
/// One function: its name, its inline signature, its locals, its body.
///
/// The signature is written INLINE -- `(param $x i32) (result i32)` -- rather
/// than as a type reference, which is what the reference does and what keeps
/// the text readable without the type section beside it.
fn function_field(
  m : @wasm_bin.Module,
  k : Int,
  code : @wasm_bin.FunctionCode,
) -> Sexp raise WatError {
  let index = k + imported_count(m, "func")
  let locals = m.names.locals.get(index).unwrap_or(Map([]))
  let ft = match m.types[m.funcs[k]].composite {
    Func(ft) => ft
    _ => raise NotPrinted("a function whose type is not a function type")
  }
  // The head -- name, exports, signature -- breaks as one group, so a long
  // signature wraps under the name rather than each clause taking a line.
  let head : Array[Sexp] = [
    Atom("func"),
    Atom(name_or(m.names.functions, index)),
  ]
  for e in export_clauses(m, Func(index)) {
    head.push(e)
  }
  for p, ty in ft.params {
    head.push(
      List(
        named_type(local_name(locals, p), "param", valtype(ty, m.names.types)),
      ),
    )
  }
  if !ft.results.is_empty() {
    let r : Array[Sexp] = [Atom("result")]
    for ty in ft.results {
      r.push(Atom(valtype(ty, m.names.types)))
    }
    head.push(List(r))
  }
  let out : Array[Sexp] = [block(head)]
  // The DECLARED locals follow the parameters in the same index space, so
  // their names are looked up past the parameter count. They pack onto as few
  // lines as they fit on, which is what `hov` means.
  if !code.locals.is_empty() {
    let l : Array[Sexp] = []
    for j, ty in code.locals {
      l.push(
        List(
          named_type(
            local_name(locals, ft.params.length() + j),
            "local",
            valtype(ty, m.names.types),
          ),
        ),
      )
    }
    out.push(Block(l, KHov, false))
  }
  let ctx = {
    m,
    locals,
    labels: m.names.labels.get(index).unwrap_or(Map([])),
    opened: 0,
    scope: [],
  }
  for node in fold(code.body, code.spans, nested=code.nested_spans) {
    out.push(folded(node, ctx))
  }
  List(out)
}

///|
/// `(param $x i32)`, or `(param i32)` when nothing named it.
fn named_type(name : String, kind : String, ty : String) -> Array[Sexp] {
  if name == "" {
    [Atom(kind), Atom(ty)]
  } else {
    [Atom(kind), Atom(name), Atom(ty)]
  }
}

///|
/// A local's name, or nothing.
fn local_name(locals : Map[Int, Bytes], k : Int) -> String {
  match locals.get(k) {
    Some(b) => "$" + text_of(b)
    None => ""
  }
}

///|
/// What printing one function body needs to know beyond the tree.
///
/// `opened` counts the blocks in the order they OPEN, which is the order the
/// name section numbers their labels in; `scope` is the same blocks stacked
/// innermost-last, which is what a branch depth counts against. The two differ
/// -- a name belongs to its block, a depth to where the branch stands -- so
/// both are carried.
priv struct Ctx {
  m : @wasm_bin.Module
  locals : Map[Int, Bytes]
  labels : Map[Int, Bytes]
  mut opened : Int
  scope : Array[String?]
}

///|
/// One folded instruction: `(head operand operand)`, or just `(head)` when it
/// takes none.
///
/// A structural instruction is written the same way, except that what follows
/// the head is the code it guards rather than values it consumes.
fn folded(node : Node, ctx : Ctx) -> Sexp raise WatError {
  if !node.bodies.is_empty() ||
    node.head is (Block(_, _) | Loop(_, _) | If(_, _, _)) {
    return structural(node, ctx)
  }
  let head = mnemonic(node.head, ctx.m.names, ctx.locals, scope=ctx.scope)
  let l : Array[Sexp] = [head]
  for operand in node.operands {
    l.push(folded(operand, ctx))
  }
  List(l)
}

///|
/// `(block $l (result T) body...)`, and the two that shape their bodies
/// differently: `if`, whose operand comes before two named clauses.
fn structural(node : Node, ctx : Ctx) -> Sexp raise WatError {
  // The label is claimed BEFORE the body is printed, because that is the order
  // the blocks open in and so the order the names are numbered in.
  let opened = ctx.opened
  ctx.opened = opened + 1
  let name = match ctx.labels.get(opened) {
    Some(b) => Some(text_of(b))
    None => None
  }
  let (word, bt) = match node.head {
    Block(bt, _) => ("block", bt)
    Loop(bt, _) => ("loop", bt)
    If(bt, _, _) => ("if", bt)
    _ => raise NotPrinted(constructor_of(node.head))
  }
  let head : Array[Sexp] = [Atom(word)]
  if name is Some(n) {
    head.push(Atom("$" + n))
  }
  for t in blocktype(bt, ctx.m) {
    head.push(t)
  }
  let l : Array[Sexp] = [block(head)]
  // The `if` condition is an operand, and it is written before the clauses.
  for operand in node.operands {
    l.push(folded(operand, ctx))
  }
  ctx.scope.push(name)
  let clauses = if word == "if" { ["then", "else"] } else { [] }
  for j, body in node.bodies {
    let inner : Array[Sexp] = []
    for child in body {
      inner.push(folded(child, ctx))
    }
    if j < clauses.length() {
      let c : Array[Sexp] = [Atom(clauses[j])]
      for x in inner {
        c.push(x)
      }
      l.push(List(c))
    } else {
      for x in inner {
        l.push(x)
      }
    }
  }
  let _ = ctx.scope.pop()
  List(l)
}

///|
/// What a block produces, when it produces anything.
fn blocktype(
  bt : @wasm_bin.BlockType,
  m : @wasm_bin.Module,
) -> Array[Sexp] raise WatError {
  match bt {
    Empty => []
    Value(t) => [List([Atom("result"), Atom(valtype(t, m.names.types))])]
    MultiValue(ts) | InlineType([], ts) => {
      let out : Array[Sexp] = []
      for t in ts {
        out.push(List([Atom("result"), Atom(valtype(t, m.names.types))]))
      }
      out
    }
    // A block that CONSUMES values is spelled as a reference to the signature
    // that describes it, because the inline form has no room for parameters.
    TypeIndex(k) => [List([Atom("type"), Atom(name_or(m.names.types, k))])]
    InlineType(_, _) => raise NotPrinted("a block type with parameters")
  }
}
