// The module fields, as the text format writes them.
//
// Ported from `modulefield` in wax/src/lib-wasm/output.ml.
//
// Exports are written INLINE on the thing exported -- `(func $f (export "f")
// ...)` -- not as fields of their own. The binary has an export section
// instead, so the inline form is recovered by asking which exports point at
// this item: the two spellings hold the same information, and the reference
// emits no standalone `(export ...)` field for anything a wax module can say.

///|
/// The export clauses attached to one item, in section order.
fn export_clauses(m : @wasm_bin.Module, of_ : @wasm_bin.ExportDesc) -> String {
  let out = StringBuilder::new()
  for e in m.exports {
    if e.desc == of_ {
      out.write_string(" (export " + quoted(e.name) + ")")
    }
  }
  out.to_string()
}

///|
/// A string literal, escaped the way the format escapes one.
fn quoted(b : Bytes) -> String {
  let out = StringBuilder::new()
  out.write_char('"')
  for k in 0..<b.length() {
    let c = b[k].to_int()
    match c {
      0x22 => out.write_string("\\\"")
      0x5C => out.write_string("\\\\")
      0x0A => out.write_string("\\n")
      0x09 => out.write_string("\\t")
      0x0D => out.write_string("\\r")
      // Everything printable goes through as itself; anything else in the
      // two-digit hex form, which is what keeps the output byte-exact for
      // names that are not text at all.
      _ =>
        if c >= 0x20 && c < 0x7F {
          out.write_char(Int::unsafe_to_char(c))
        } else {
          out.write_string("\\" + hex2(c))
        }
    }
  }
  out.write_char('"')
  out.to_string()
}

///|
fn hex2(c : Int) -> String {
  let digits = "0123456789abcdef"
  digits[c / 16].to_string() + digits[c % 16].to_string()
}

///|
/// A defined type: `(type $n (struct ...))`, or the `sub` form when it is not
/// final or has a supertype.
fn subtype_field(m : @wasm_bin.Module, k : Int) -> String {
  let t = m.types[k]
  let head = "(type " + name_or(m.names.types, k)
  let body = comptype(m, k, t.composite)
  let clauses = describes_clauses(m, t)
  if t.final_ && t.supertypes.is_empty() {
    head + clauses + " " + body + ")"
  } else {
    let sub = StringBuilder::new()
    sub.write_string("(sub")
    if t.final_ {
      sub.write_string(" final")
    }
    for s in t.supertypes {
      sub.write_string(" " + name_or(m.names.types, s))
    }
    sub.write_string(clauses + " " + body + ")")
    head + " " + sub.to_string() + ")"
  }
}

///|
/// The custom-descriptors clauses, which precede the composite type.
fn describes_clauses(m : @wasm_bin.Module, t : @wasm_bin.SubType) -> String {
  let out = StringBuilder::new()
  if t.describes is Some(i) {
    out.write_string(" (describes " + name_or(m.names.types, i) + ")")
  }
  if t.descriptor is Some(i) {
    out.write_string(" (descriptor " + name_or(m.names.types, i) + ")")
  }
  out.to_string()
}

///|
/// What a defined type defines. `of_` is the type's own index, which is where
/// the field names live.
fn comptype(
  m : @wasm_bin.Module,
  of_ : Int,
  c : @wasm_bin.CompositeType,
) -> String {
  match c {
    Func(ft) => "(func" + functype(m, ft) + ")"
    Array(at) => "(array " + fieldtype(m, at.element) + ")"
    Cont(i) => "(cont " + name_or(m.names.types, i) + ")"
    Struct(st) => {
      let out = StringBuilder::new()
      out.write_string("(struct")
      let field_names = m.names.fields.get(of_).unwrap_or(Map([]))
      for j, f in st.fields {
        out.write_string(" (field ")
        if field_names.get(j) is Some(n) {
          out.write_string("$" + text_of(n) + " ")
        }
        out.write_string(fieldtype(m, f) + ")")
      }
      out.write_string(")")
      out.to_string()
    }
  }
}

///|
/// A function type's parameters and results, each group written once.
fn functype(m : @wasm_bin.Module, ft : @wasm_bin.FuncType) -> String {
  let out = StringBuilder::new()
  if !ft.params.is_empty() {
    out.write_string(" (param")
    for t in ft.params {
      out.write_string(" " + valtype(t, m.names.types))
    }
    out.write_string(")")
  }
  if !ft.results.is_empty() {
    out.write_string(" (result")
    for t in ft.results {
      out.write_string(" " + valtype(t, m.names.types))
    }
    out.write_string(")")
  }
  out.to_string()
}

///|
fn fieldtype(m : @wasm_bin.Module, f : @wasm_bin.FieldType) -> String {
  let t = match f.typ {
    Value(v) => valtype(v, m.names.types)
    Packed(I8) => "i8"
    Packed(I16) => "i16"
  }
  if f.mut_ {
    "(mut " + t + ")"
  } else {
    t
  }
}

///|
fn globaltype(m : @wasm_bin.Module, g : @wasm_bin.GlobalType) -> String {
  let t = valtype(g.typ, m.names.types)
  if g.mut_ {
    "(mut " + t + ")"
  } else {
    t
  }
}

///|
/// A memory's or table's size bounds, and what else the limits carry.
fn limits(l : @wasm_types.Limits) -> String {
  let out = StringBuilder::new()
  if l.address_type is I64 {
    out.write_string(" i64")
  }
  out.write_string(" " + l.mi.to_string())
  if l.ma is Some(x) {
    out.write_string(" " + x.to_string())
  }
  if l.shared {
    out.write_string(" shared")
  }
  if l.page_size_log2 is Some(p) {
    out.write_string(" (pagesize " + (1UL << p).to_string() + ")")
  }
  out.to_string()
}

///|
fn tabletype(m : @wasm_bin.Module, t : @wasm_bin.TableType) -> String {
  limits(t.limits) + " " + reftype(t.elem_type, m.names.types)
}

///|
/// The type of an imported or defined function or tag, written inline.
fn typeuse(m : @wasm_bin.Module, k : Int) -> String {
  match m.types[k].composite {
    Func(ft) => functype(m, ft)
    // Anything else at a function's type index is not a function type, and
    // there is no inline spelling for it -- so name it.
    _ => " (type " + name_or(m.names.types, k) + ")"
  }
}

///|
/// An import. With no exports it is written the way the binary reads --
/// `(import "m" "n" (func $f ...))`; with exports the inline form is the only
/// one that has room for them, so the two clauses swap places.
///
/// A COMPACT group is one entry standing for a run of imports from the same
/// module, and it is written as one field with an `item` per name.
fn import_field(m : @wasm_bin.Module, k : Int) -> String {
  let i = m.imports[k]
  let at = import_slots(m, k)
  match i.group {
    Some(g) => compact_import(m, i, g, at)
    None => {
      let (kind, id, typ, desc) = import_parts(m, i.desc, at)
      let e = export_clauses(m, desc)
      let names = quoted(i.mod_name) + " " + quoted(i.name)
      if e == "" {
        "(import " + names + " (" + kind + id + typ + "))"
      } else {
        "(" + kind + id + e + " (import " + names + ")" + typ + ")"
      }
    }
  }
}

///|
/// `(import "m" (item "n" (func ...)) ...)`, or -- when every item shares one
/// descriptor -- `(import "m" (item $id "n") ... (func ...))`.
fn compact_import(
  m : @wasm_bin.Module,
  i : @wasm_bin.Import,
  g : @wasm_bin.ImportGroup,
  at : Map[String, Int],
) -> String {
  let out = StringBuilder::new()
  out.write_string("(import " + quoted(i.mod_name))
  match g {
    Heterogeneous(items) =>
      for it in items {
        let (kind, id, typ, _) = import_parts(m, it.1, at)
        out.write_string(
          " (item " + quoted(it.0) + " (" + kind + id + typ + "))",
        )
        bump(at, kind)
      }
    Homogeneous(names) => {
      let (kind, _, typ, _) = import_parts(m, i.desc, at)
      for n in names {
        let (_, id, _, _) = import_parts(m, i.desc, at)
        out.write_string(" (item" + id + " " + quoted(n) + ")")
        bump(at, kind)
      }
      out.write_string(" (" + kind + typ + ")")
    }
  }
  out.write_string(")")
  out.to_string()
}

///|
/// Which index space an import takes a slot in.
fn kind_of(d : @wasm_bin.ImportDesc) -> String {
  match d {
    Func(_, _) => "func"
    Table(_) => "table"
    Memory(_) => "memory"
    Global(_) => "global"
    Tag(_) => "tag"
  }
}

///|
fn bump(at : Map[String, Int], kind : String) -> Unit {
  at[kind] = at.get(kind).unwrap_or(0) + 1
}

///|
/// The index each space stands at when the import at `k` is reached.
///
/// A compact group holds several imports in one entry, so the count advances
/// by what the entry stands for rather than by one.
fn import_slots(m : @wasm_bin.Module, k : Int) -> Map[String, Int] {
  let at : Map[String, Int] = Map([])
  for j in 0..<k {
    match m.imports[j].group {
      None => bump(at, kind_of(m.imports[j].desc))
      Some(Heterogeneous(items)) =>
        for it in items {
          bump(at, kind_of(it.1))
        }
      Some(Homogeneous(names)) =>
        for _ in names {
          bump(at, kind_of(m.imports[j].desc))
        }
    }
  }
  at
}

///|
/// What an import brings in: its keyword, its name, its type, and where in the
/// export section it would be pointed at.
fn import_parts(
  m : @wasm_bin.Module,
  d : @wasm_bin.ImportDesc,
  at : Map[String, Int],
) -> (String, String, String, @wasm_bin.ExportDesc) {
  let k = kind_of(d)
  let n = at.get(k).unwrap_or(0)
  match d {
    Func(t, exact) => {
      let typ = if exact {
        " (exact" + typeuse(m, t) + ")"
      } else {
        typeuse(m, t)
      }
      ("func", " " + name_or(m.names.functions, n), typ, Func(n))
    }
    Global(g) =>
      (
        "global",
        " " + name_or(m.names.globals, n),
        " " + globaltype(m, g),
        Global(n),
      )
    Tag(t) => ("tag", " " + name_or(m.names.tags, n), typeuse(m, t), Tag(n))
    Memory(mt) =>
      (
        "memory",
        " " + name_or(m.names.memories, n),
        limits(mt.limits),
        Memory(n),
      )
    Table(tt) =>
      (
        "table",
        " " + name_or(m.names.tables, n),
        " " + tabletype(m, tt),
        Table(n),
      )
  }
}

///|
/// A global: its type, then the constant expression that initialises it.
fn global_field(m : @wasm_bin.Module, k : Int) -> String raise WatError {
  let g = m.globals[k]
  let at = k + imported_count(m, "global")
  let head = "(global " +
    name_or(m.names.globals, at) +
    export_clauses(m, Global(at)) +
    " " +
    globaltype(m, g.type_)
  head + const_expr(m, g.init) + ")"
}

///|
fn tag_field(m : @wasm_bin.Module, k : Int) -> String {
  let at = k + imported_count(m, "tag")
  "(tag " +
  name_or(m.names.tags, at) +
  export_clauses(m, Tag(at)) +
  typeuse(m, m.tags[k].type_idx) +
  ")"
}

///|
/// A memory, with the data segments written inline where the source wrote
/// them -- which is what a wax `memory m: i32 [1] = "..."` becomes.
fn memory_field(m : @wasm_bin.Module, k : Int) -> String {
  let at = k + imported_count(m, "memory")
  "(memory " +
  name_or(m.names.memories, at) +
  export_clauses(m, Memory(at)) +
  limits(m.memories[k].limits) +
  ")"
}

///|
fn table_field(m : @wasm_bin.Module, k : Int) -> String raise WatError {
  let t = m.tables[k]
  let at = k + imported_count(m, "table")
  let head = "(table " +
    name_or(m.names.tables, at) +
    export_clauses(m, Table(at)) +
    " " +
    tabletype(m, t.type_)
  match t.init {
    Some(e) => head + const_expr(m, e) + ")"
    None => head + ")"
  }
}

///|
fn elem_field(m : @wasm_bin.Module, k : Int) -> String raise WatError {
  let e = m.elems[k]
  let out = StringBuilder::new()
  out.write_string("(elem " + name_or(m.names.elem, k))
  match e.mode {
    Passive => ()
    Declarative => out.write_string(" declare")
    Active(tab, offset) => {
      if tab != 0 {
        out.write_string(" (table " + name_or(m.names.tables, tab) + ")")
      }
      out.write_string(" (offset" + const_expr(m, offset) + ")")
    }
  }
  out.write_string(" " + reftype(e.type_, m.names.types))
  for item in e.init {
    out.write_string(" (item" + const_expr(m, item) + ")")
  }
  out.write_string(")")
  out.to_string()
}

///|
fn data_field(m : @wasm_bin.Module, k : Int) -> String raise WatError {
  let d = m.datas[k]
  let out = StringBuilder::new()
  out.write_string("(data " + name_or(m.names.data, k))
  if d.mode is Active(mem, offset) {
    if mem != 0 {
      out.write_string(" (memory " + name_or(m.names.memories, mem) + ")")
    }
    out.write_string(" (offset" + const_expr(m, offset) + ")")
  }
  out.write_string(" " + quoted(d.init) + ")")
  out.to_string()
}

///|
/// How many items of a kind the imports took before the defined ones start.
fn imported_count(m : @wasm_bin.Module, of_ : String) -> Int {
  let at = import_slots(m, m.imports.length())
  at.get(of_).unwrap_or(0)
}

///|
/// A constant expression, folded like any other body. It carries no spans --
/// an initialiser is a single instruction tree the lowering emitted in one go
/// -- so the fold falls back to reading the last instruction as the head.
fn const_expr(
  m : @wasm_bin.Module,
  body : Array[@wasm_bin.Instruction],
) -> String raise WatError {
  if body.is_empty() {
    return ""
  }
  let ctx = { m, locals: Map([]), labels: Map([]), opened: 0, scope: [] }
  let out = StringBuilder::new()
  for node in fold(body, []) {
    out.write_char(' ')
    out.write_string(folded(node, ctx))
  }
  out.to_string()
}
