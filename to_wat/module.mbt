// The module, as the text format writes it.
//
// No `(module ...)` wrapper: the reference prints the FIELDS, one per line,
// because that is what a wax module converts to -- a list of them, not a
// nested document.

///|
/// Print a module's text form.
pub fn print_module(m : @wasm_bin.Module) -> String raise WatError {
  let out = StringBuilder::new()
  for f in m.field_order {
    out.write_string(field(m, f))
    out.write_char('\n')
  }
  // Whatever the source did not place: the types a lowering materialised for
  // itself, and the element segments minted to declare function references.
  // They belong to no written field, so they follow the ones that do.
  let placed_types : Map[Int, Bool] = Map([])
  let placed_elems : Map[Int, Bool] = Map([])
  for f in m.field_order {
    match f {
      FTypes(ks) =>
        for k in ks {
          placed_types[k] = true
        }
      FElem(k) => placed_elems[k] = true
      _ => ()
    }
  }
  for k in 0..<m.types.length() {
    if !placed_types.contains(k) {
      out.write_string(subtype_field(m, k))
      out.write_char('\n')
    }
  }
  for k in 0..<m.elems.length() {
    if !placed_elems.contains(k) {
      out.write_string(elem_field(m, k))
      out.write_char('\n')
    }
  }
  if m.start is Some(f) {
    out.write_string("(start " + name_or(m.names.functions, f) + ")\n")
  }
  out.to_string()
}

///|
/// One module field, written where the source put it.
fn field(m : @wasm_bin.Module, f : @wasm_bin.FieldRef) -> String raise WatError {
  match f {
    // A `rec` group is one field holding several definitions; a lone type is
    // written bare, because a singleton `rec` is a DIFFERENT type and the
    // source said which it wrote.
    FTypes([k]) => subtype_field(m, k)
    FTypes(ks) => {
      let out = StringBuilder::new()
      out.write_string("(rec")
      for k in ks {
        out.write_string(" " + subtype_field(m, k))
      }
      out.write_string(")")
      out.to_string()
    }
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
) -> String raise WatError {
  let imported = m.imports.length() - m.codes.length()
  let index = (if imported > 0 { imported } else { 0 }) + k
  let out = StringBuilder::new()
  out.write_string(
    "(func " +
    name_or(m.names.functions, index) +
    export_clauses(m, Func(index)),
  )
  let locals = m.names.locals.get(index).unwrap_or(Map([]))
  let ft = match m.types[m.funcs[k]].composite {
    Func(ft) => ft
    _ => raise NotPrinted("a function whose type is not a function type")
  }
  for p, ty in ft.params {
    out.write_string(
      " (param " + local_name(locals, p) + valtype(ty, m.names.types) + ")",
    )
  }
  for ty in ft.results {
    out.write_string(" (result " + valtype(ty, m.names.types) + ")")
  }
  // The DECLARED locals follow the parameters in the same index space, so
  // their names are looked up past the parameter count.
  for j, ty in code.locals {
    out.write_string(
      "\n  (local " +
      local_name(locals, ft.params.length() + j) +
      valtype(ty, m.names.types) +
      ")",
    )
  }
  // One line when the whole function fits, and one statement per line when it
  // does not -- which is what the reference's layout comes to for a body whose
  // statements are each a single folded group.
  let statements : Array[String] = []
  let ctx = {
    m,
    locals,
    labels: m.names.labels.get(index).unwrap_or(Map([])),
    opened: 0,
    scope: [],
  }
  for node in fold(code.body, code.spans, nested=code.nested_spans) {
    statements.push(folded(node, ctx))
  }
  let head = out.to_string()
  let flat = head + join_with(statements, " ", before=" ") + ")"
  if flat.length() <= 80 && !flat.contains("\n") {
    return flat
  }
  head + join_with(statements, "\n  ", before="\n  ") + ")"
}

///|
/// A local's name, with the trailing space the caller needs, or nothing.
fn local_name(locals : Map[Int, Bytes], k : Int) -> String {
  match locals.get(k) {
    Some(b) => "$" + text_of(b) + " "
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
/// One folded instruction: `(head operand operand)`, or just `head` when it
/// takes none.
///
/// A structural instruction is written the same way, except that what follows
/// the head is the code it guards rather than values it consumes.
fn folded(node : Node, ctx : Ctx) -> String raise WatError {
  if !node.bodies.is_empty() ||
    node.head is (Block(_, _) | Loop(_, _) | If(_, _, _)) {
    return structural(node, ctx)
  }
  let head = mnemonic(node.head, ctx.m.names, ctx.locals, scope=ctx.scope)
  if node.operands.is_empty() {
    return "(" + head + ")"
  }
  let out = StringBuilder::new()
  out.write_string("(" + head)
  for operand in node.operands {
    out.write_char(' ')
    out.write_string(folded(operand, ctx))
  }
  out.write_string(")")
  out.to_string()
}

///|
/// `(block $l (result T) body...)`, and the two that shape their bodies
/// differently: `if`, whose operand comes before two named clauses.
fn structural(node : Node, ctx : Ctx) -> String raise WatError {
  // The label is claimed BEFORE the body is printed, because that is the order
  // the blocks open in and so the order the names are numbered in.
  let opened = ctx.opened
  ctx.opened = opened + 1
  let name = match ctx.labels.get(opened) {
    Some(b) => Some(text_of(b))
    None => None
  }
  let id = match name {
    Some(n) => " $" + n
    None => ""
  }
  let (word, bt) = match node.head {
    Block(bt, _) => ("block", bt)
    Loop(bt, _) => ("loop", bt)
    If(bt, _, _) => ("if", bt)
    _ => raise NotPrinted(constructor_of(node.head))
  }
  let out = StringBuilder::new()
  out.write_string("(" + word + id + blocktype(bt, ctx.m))
  // The `if` condition is an operand, and it is written before the clauses.
  for operand in node.operands {
    out.write_char(' ')
    out.write_string(folded(operand, ctx))
  }
  ctx.scope.push(name)
  let clauses = if word == "if" { ["then", "else"] } else { [] }
  for j, body in node.bodies {
    let inner : Array[String] = []
    for child in body {
      inner.push(folded(child, ctx))
    }
    if j < clauses.length() {
      out.write_string(
        " (" + clauses[j] + join_with(inner, " ", before=" ") + ")",
      )
    } else {
      out.write_string(join_with(inner, " ", before=" "))
    }
  }
  let _ = ctx.scope.pop()
  out.write_string(")")
  out.to_string()
}

///|
/// What a block produces, when it produces anything.
fn blocktype(
  bt : @wasm_bin.BlockType,
  m : @wasm_bin.Module,
) -> String raise WatError {
  match bt {
    Empty => ""
    Value(t) => " (result " + valtype(t, m.names.types) + ")"
    MultiValue(ts) | InlineType([], ts) => {
      let out = StringBuilder::new()
      for t in ts {
        out.write_string(" (result " + valtype(t, m.names.types) + ")")
      }
      out.to_string()
    }
    // A block that CONSUMES values is spelled as a reference to the signature
    // that describes it, because the inline form has no room for parameters.
    TypeIndex(k) => " (type " + name_or(m.names.types, k) + ")"
    InlineType(_, _) => raise NotPrinted("a block type with parameters")
  }
}

///|
/// Join with a separator, prefixed when there is anything to join.
fn join_with(parts : Array[String], sep : String, before~ : String) -> String {
  if parts.is_empty() {
    return ""
  }
  let out = StringBuilder::new()
  for k, p in parts {
    out.write_string(if k == 0 { before } else { sep })
    out.write_string(p)
  }
  out.to_string()
}
