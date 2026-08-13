// The module, as the text format writes it.
//
// No `(module ...)` wrapper: the reference prints the FIELDS, one per line,
// because that is what a wax module converts to -- a list of them, not a
// nested document.

///|
/// Print a module's text form.
pub fn print_module(m : @wasm_bin.Module) -> String raise WatError {
  let out = StringBuilder::new()
  let lines : Array[String] = []
  for k, code in m.codes {
    lines.push(function_field(m, k, code))
  }
  for line in lines {
    out.write_string(line)
    out.write_char('\n')
  }
  out.to_string()
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
  out.write_string("(func " + name_or(m.names.functions, index))
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
  for node in fold(code.body, code.spans) {
    statements.push(folded(node, m, locals))
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
/// One folded instruction: `(head operand operand)`, or just `head` when it
/// takes none.
fn folded(
  node : Node,
  m : @wasm_bin.Module,
  locals : Map[Int, Bytes],
) -> String raise WatError {
  let head = mnemonic(node.head, m.names, locals)
  if node.operands.is_empty() {
    return "(" + head + ")"
  }
  let out = StringBuilder::new()
  out.write_string("(" + head)
  for operand in node.operands {
    out.write_char(' ')
    out.write_string(folded(operand, m, locals))
  }
  out.write_string(")")
  out.to_string()
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
