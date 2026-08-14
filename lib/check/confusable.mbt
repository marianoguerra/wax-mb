// The bidirectional-control-character lint.
//
// Ported from `lint_confusable` in wax/src/lib-wax/typing.ml.
//
// A whole-module walk over every STRING, wherever one can appear: an instruction
// literal, a data segment, an import's module name, a conditional's operand, an
// attribute's value. The point of the lint is that these characters are
// invisible, so there is no shape to look for -- only every place a string can
// hide.

///|
/// Report the first bidirectional control character in a byte string.
fn check_bytes(
  diagnostics : @diagnostic.Context,
  location : @basic.Location,
  b : Bytes,
) -> Unit {
  if @unicode.first_confusable(b) is Some(cp) {
    confusable_unicode(diagnostics, location, cp)
  }
}

///|
/// Likewise for a conditional's string operands, however deeply nested.
fn check_cond(diagnostics : @diagnostic.Context, c : @wasm_types.Cond) -> Unit {
  match c {
    Str(s) => check_bytes(diagnostics, s.info, s.desc)
    Var(_) | Version(_, _, _) => ()
    And(l) | Or(l) =>
      for x in l {
        check_cond(diagnostics, x)
      }
    Not(x) => check_cond(diagnostics, x)
    Cmp(_, a, b) => {
      check_cond(diagnostics, a)
      check_cond(diagnostics, b)
    }
  }
}

///|
/// Every string inside one instruction and everything under it.
fn check_instrs(
  diagnostics : @diagnostic.Context,
  instrs : Array[@ast.Instr[@basic.Location]],
) -> Unit {
  for i in instrs {
    i.iter_instr(node => {
      match node.desc {
        Str(_, s) => check_bytes(diagnostics, node.info, s)
        IfAnnotation(cond~, ..) => check_cond(diagnostics, cond)
        _ => ()
      }
    })
  }
}

///|
/// An attribute's value and its guard both hold source the reader sees.
fn check_attrs(
  diagnostics : @diagnostic.Context,
  attrs : Array[@ast.Attribute],
) -> Unit {
  for a in attrs {
    if a.attr_value is Some(v) {
      check_instrs(diagnostics, [v])
    }
    if a.attr_guard is Some(g) {
      check_cond(diagnostics, g.desc)
    }
  }
}

///|
/// A data segment's contents, which are strings by construction.
fn check_data(
  diagnostics : @diagnostic.Context,
  location : @basic.Location,
  init : Array[@ast.DataElem],
) -> Unit {
  for e in init {
    match e {
      Str(s) => check_bytes(diagnostics, location, s)
      // A run's elements are numeric literals written as text, so they hold no
      // string a reader could be misled by.
      Run(_, _) => ()
      V128Run(_) => ()
    }
  }
}

///|
/// Walk a module reporting every string that hides one of these characters.
fn lint_confusable(
  diagnostics : @diagnostic.Context,
  fields : @ast.Module[@basic.Location],
) -> Unit {
  for field in fields {
    let location = field.info
    match field.desc {
      Type(_) => ()
      Func(body~, attributes~, ..) => {
        check_attrs(diagnostics, attributes)
        check_instrs(diagnostics, body.1)
      }
      Global(def~, attributes~, ..) => {
        check_attrs(diagnostics, attributes)
        check_instrs(diagnostics, [def])
      }
      Tag(attributes~, ..) => check_attrs(diagnostics, attributes)
      Memory(data~, attributes~, ..) => {
        check_attrs(diagnostics, attributes)
        for m in data {
          check_data(diagnostics, location, m.init)
        }
      }
      Data(init~, attributes~, ..) => {
        check_attrs(diagnostics, attributes)
        check_data(diagnostics, location, init)
      }
      Table(init~, attributes~, ..) => {
        check_attrs(diagnostics, attributes)
        if init is Some(x) {
          check_instrs(diagnostics, [x])
        }
      }
      Elem(init~, attributes~, ..) => {
        check_attrs(diagnostics, attributes)
        check_instrs(diagnostics, init)
      }
      Import(module_~, decl~) => {
        check_bytes(diagnostics, module_.info, module_.desc)
        check_attrs(diagnostics, decl.desc.attributes)
      }
      ImportGroup(module_~, decls~) => {
        check_bytes(diagnostics, module_.info, module_.desc)
        for d in decls {
          check_attrs(diagnostics, d.desc.attributes)
        }
      }
      ModuleAnnotation(attrs) => check_attrs(diagnostics, attrs)
      Conditional(cond~, then_fields~, else_fields~) => {
        check_cond(diagnostics, cond)
        lint_confusable(diagnostics, then_fields.desc)
        if else_fields is Some(f) {
          lint_confusable(diagnostics, f.desc)
        }
      }
    }
  }
}
