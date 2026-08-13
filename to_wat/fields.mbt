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
fn export_clauses(
  m : @wasm_bin.Module,
  of_ : @wasm_bin.ExportDesc,
) -> Array[Sexp] {
  let out : Array[Sexp] = []
  for e in m.exports {
    if e.desc == of_ {
      out.push(List([Atom("export"), Atom(quoted(e.name))]))
    }
  }
  out
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
/// A field's identifier: what the source called it, or nothing.
///
/// Unlike an operand, where an index is a valid spelling, a FIELD written
/// `(elem 3 ...)` would name the index in the wrong space -- so an unnamed
/// field carries no identifier at all and takes its index from its position.
fn opt_id(names : Map[Int, Bytes], k : Int) -> Array[Sexp] {
  match names.get(k) {
    Some(b) => [Atom("$" + text_of(b))]
    None => []
  }
}

///|
fn hex2(c : Int) -> String {
  let digits = "0123456789abcdef"
  digits[c / 16].to_string() + digits[c % 16].to_string()
}

///|
/// A defined type: `(type $n (struct ...))`, or the `sub` form when it is not
/// final or has a supertype.
fn subtype_field(m : @wasm_bin.Module, k : Int) -> Sexp {
  let t = m.types[k]
  let head = block([Atom("type"), ..opt_id(m.names.types, k)])
  let body = comptype(m, k, t.composite)
  let clauses = describes_clauses(m, t)
  if t.final_ && t.supertypes.is_empty() {
    let l : Array[Sexp] = [head]
    for c in clauses {
      l.push(c)
    }
    l.push(block([body]))
    List(l)
  } else {
    let sub : Array[Sexp] = [Atom("sub")]
    if t.final_ {
      sub.push(Atom("final"))
    }
    for s in t.supertypes {
      sub.push(Atom(name_or(m.names.types, s)))
    }
    let inner : Array[Sexp] = [block(sub)]
    for c in clauses {
      inner.push(c)
    }
    inner.push(body)
    List([head, List([block(inner)])])
  }
}

///|
/// The custom-descriptors clauses, which precede the composite type.
fn describes_clauses(
  m : @wasm_bin.Module,
  t : @wasm_bin.SubType,
) -> Array[Sexp] {
  let out : Array[Sexp] = []
  if t.describes is Some(i) {
    out.push(List([Atom("describes"), Atom(name_or(m.names.types, i))]))
  }
  if t.descriptor is Some(i) {
    out.push(List([Atom("descriptor"), Atom(name_or(m.names.types, i))]))
  }
  out
}

///|
/// What a defined type defines. `of_` is the type's own index, which is where
/// the field names live.
fn comptype(
  m : @wasm_bin.Module,
  of_ : Int,
  c : @wasm_bin.CompositeType,
) -> Sexp {
  match c {
    Func(ft) => {
      let l : Array[Sexp] = [Atom("func")]
      for x in functype(m, ft) {
        l.push(x)
      }
      List(l)
    }
    Array(at) => List([Atom("array"), Atom(fieldtype(m, at.element))])
    Cont(i) => List([Atom("cont"), Atom(name_or(m.names.types, i))])
    Struct(st) => {
      let l : Array[Sexp] = [Atom("struct")]
      let field_names = m.names.fields.get(of_).unwrap_or(Map([]))
      for j, f in st.fields {
        let name = match field_names.get(j) {
          Some(n) => "$" + text_of(n)
          None => ""
        }
        l.push(List(named_type(name, "field", fieldtype(m, f))))
      }
      List(l)
    }
  }
}

///|
/// A function type's parameters and results, each group written once.
fn functype(m : @wasm_bin.Module, ft : @wasm_bin.FuncType) -> Array[Sexp] {
  let out : Array[Sexp] = []
  if !ft.params.is_empty() {
    let l : Array[Sexp] = [Atom("param")]
    for t in ft.params {
      l.push(Atom(valtype(t, m.names.types)))
    }
    out.push(List(l))
  }
  if !ft.results.is_empty() {
    let l : Array[Sexp] = [Atom("result")]
    for t in ft.results {
      l.push(Atom(valtype(t, m.names.types)))
    }
    out.push(List(l))
  }
  out
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
fn limits(l : @wasm_types.Limits) -> Array[Sexp] {
  let out : Array[Sexp] = []
  if l.address_type is I64 {
    out.push(Atom("i64"))
  }
  out.push(Atom(l.mi.to_string()))
  if l.ma is Some(x) {
    out.push(Atom(x.to_string()))
  }
  if l.shared {
    out.push(Atom("shared"))
  }
  if l.page_size_log2 is Some(p) {
    out.push(List([Atom("pagesize"), Atom((1UL << p).to_string())]))
  }
  out
}

///|
fn tabletype(m : @wasm_bin.Module, t : @wasm_bin.TableType) -> Array[Sexp] {
  let out = limits(t.limits)
  out.push(Atom(reftype(t.elem_type, m.names.types)))
  out
}

///|
/// The type of an imported or defined function or tag, written inline.
fn typeuse(m : @wasm_bin.Module, k : Int) -> Array[Sexp] {
  match m.types[k].composite {
    Func(ft) => functype(m, ft)
    // Anything else at a function's type index is not a function type, and
    // there is no inline spelling for it -- so name it.
    _ => [List([Atom("type"), Atom(name_or(m.names.types, k))])]
  }
}

///|
/// An import. With no exports it is written the way the binary reads --
/// `(import "m" "n" (func $f ...))`; with exports the inline form is the only
/// one that has room for them, so the two clauses swap places.
///
/// A COMPACT group is one entry standing for a run of imports from the same
/// module, and it is written as one field with an `item` per name.
fn import_field(m : @wasm_bin.Module, k : Int) -> Sexp {
  let i = m.imports[k]
  let at = import_slots(m, k)
  match i.group {
    Some(g) => compact_import(m, i, g, at)
    None => {
      let (kind, id, typ, desc) = import_parts(m, i.desc, at)
      let e = export_clauses(m, desc)
      let names : Array[Sexp] = [
        Atom("import"),
        Atom(quoted(i.mod_name)),
        Atom(quoted(i.name)),
      ]
      if e.is_empty() {
        let inner : Array[Sexp] = [Atom(kind)]
        for x in id {
          inner.push(x)
        }
        for x in typ {
          inner.push(x)
        }
        List([block(names), List([block(inner)])])
      } else {
        let head : Array[Sexp] = [Atom(kind)]
        for x in id {
          head.push(x)
        }
        for x in e {
          head.push(x)
        }
        head.push(List(names))
        let l : Array[Sexp] = [block(head)]
        for x in typ {
          l.push(x)
        }
        List(l)
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
) -> Sexp {
  let out : Array[Sexp] = [block([Atom("import"), Atom(quoted(i.mod_name))])]
  match g {
    Heterogeneous(items) =>
      for it in items {
        let (kind, id, typ, _) = import_parts(m, it.1, at)
        let inner : Array[Sexp] = [Atom(kind)]
        for x in id {
          inner.push(x)
        }
        for x in typ {
          inner.push(x)
        }
        out.push(List([Atom("item"), Atom(quoted(it.0)), List([block(inner)])]))
        bump(at, kind)
      }
    Homogeneous(names) => {
      let (kind, _, typ, _) = import_parts(m, i.desc, at)
      for n in names {
        let (_, id, _, _) = import_parts(m, i.desc, at)
        let item : Array[Sexp] = [Atom("item")]
        for x in id {
          item.push(x)
        }
        item.push(Atom(quoted(n)))
        out.push(List(item))
        bump(at, kind)
      }
      let tail : Array[Sexp] = [Atom(kind)]
      for x in typ {
        tail.push(x)
      }
      out.push(List(tail))
    }
  }
  List(out)
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
) -> (String, Array[Sexp], Array[Sexp], @wasm_bin.ExportDesc) {
  let k = kind_of(d)
  let n = at.get(k).unwrap_or(0)
  match d {
    Func(t, exact) => {
      let typ : Array[Sexp] = if exact {
        let l : Array[Sexp] = [Atom("exact")]
        for x in typeuse(m, t) {
          l.push(x)
        }
        [List(l)]
      } else {
        typeuse(m, t)
      }
      ("func", opt_id(m.names.functions, n), typ, Func(n))
    }
    Global(g) =>
      (
        "global",
        opt_id(m.names.globals, n),
        [Atom(globaltype(m, g))],
        Global(n),
      )
    Tag(t) => ("tag", opt_id(m.names.tags, n), typeuse(m, t), Tag(n))
    Memory(mt) =>
      ("memory", opt_id(m.names.memories, n), limits(mt.limits), Memory(n))
    Table(tt) =>
      ("table", opt_id(m.names.tables, n), tabletype(m, tt), Table(n))
  }
}

///|
/// A global: its type, then the constant expression that initialises it.
fn global_field(m : @wasm_bin.Module, k : Int) -> Sexp raise WatError {
  let g = m.globals[k]
  let at = k + imported_count(m, "global")
  let head : Array[Sexp] = [Atom("global")]
  for x in opt_id(m.names.globals, at) {
    head.push(x)
  }
  for e in export_clauses(m, Global(at)) {
    head.push(e)
  }
  head.push(Atom(globaltype(m, g.type_)))
  let l : Array[Sexp] = [block(head)]
  for x in const_expr(m, g.init) {
    l.push(x)
  }
  List(l)
}

///|
fn tag_field(m : @wasm_bin.Module, k : Int) -> Sexp {
  let at = k + imported_count(m, "tag")
  let head : Array[Sexp] = [Atom("tag")]
  for x in opt_id(m.names.tags, at) {
    head.push(x)
  }
  for e in export_clauses(m, Tag(at)) {
    head.push(e)
  }
  for x in typeuse(m, m.tags[k].type_idx) {
    head.push(x)
  }
  List([block(head)])
}

///|
fn memory_field(m : @wasm_bin.Module, k : Int) -> Sexp {
  let at = k + imported_count(m, "memory")
  let head : Array[Sexp] = [Atom("memory")]
  for x in opt_id(m.names.memories, at) {
    head.push(x)
  }
  for e in export_clauses(m, Memory(at)) {
    head.push(e)
  }
  for x in limits(m.memories[k].limits) {
    head.push(x)
  }
  List([block(head)])
}

///|
fn table_field(m : @wasm_bin.Module, k : Int) -> Sexp raise WatError {
  let t = m.tables[k]
  let at = k + imported_count(m, "table")
  let head : Array[Sexp] = [Atom("table")]
  for x in opt_id(m.names.tables, at) {
    head.push(x)
  }
  for e in export_clauses(m, Table(at)) {
    head.push(e)
  }
  for x in tabletype(m, t.type_) {
    head.push(x)
  }
  let l : Array[Sexp] = [block(head)]
  if t.init is Some(e) {
    for x in const_expr(m, e) {
      l.push(x)
    }
  }
  List(l)
}

///|
fn elem_field(m : @wasm_bin.Module, k : Int) -> Sexp raise WatError {
  let e = m.elems[k]
  let head : Array[Sexp] = [Atom("elem")]
  for x in opt_id(m.names.elem, k) {
    head.push(x)
  }
  match e.mode {
    Passive => ()
    Declarative => head.push(Atom("declare"))
    Active(tab, offset) => {
      if m.names.tables.get(tab) is Some(b) {
        head.push(List([Atom("table"), Atom("$" + text_of(b))]))
      } else if tab != 0 {
        head.push(List([Atom("table"), Atom(tab.to_string())]))
      }
      head.push(expr("offset", const_expr(m, offset)))
    }
  }
  // The `func` SHORTHAND: a segment of plain `ref.func`s at the non-nullable
  // `(ref func)` type writes its function names bare. It may only be used at
  // that type -- abbreviating a `funcref` segment would silently drop the
  // nullability, which is a different segment.
  let plain = if e.type_.nullable || !(e.type_.typ is Func) {
    None
  } else {
    func_indices(e.init)
  }
  let items : Array[Sexp] = []
  match plain {
    Some(fs) => {
      head.push(Atom("func"))
      for f in fs {
        items.push(Atom(name_or(m.names.functions, f)))
      }
    }
    None => {
      head.push(Atom(reftype(e.type_, m.names.types)))
      for item in e.init {
        items.push(expr("item", const_expr(m, item)))
      }
    }
  }
  List([block(head), block(items)])
}

///|
/// The functions a segment names, when every element is a bare `ref.func` and
/// nothing else.
fn func_indices(init : Array[Array[@wasm_bin.Instruction]]) -> Array[Int]? {
  let out : Array[Int] = []
  for e in init {
    guard e.length() == 1 && e[0] is RefFunc(f) else { return None }
    out.push(f)
  }
  Some(out)
}

///|
fn data_field(m : @wasm_bin.Module, k : Int) -> Sexp raise WatError {
  let d = m.datas[k]
  let head : Array[Sexp] = [Atom("data")]
  for x in opt_id(m.names.data, k) {
    head.push(x)
  }
  if d.mode is Active(mem, offset) {
    if m.names.memories.get(mem) is Some(b) {
      head.push(List([Atom("memory"), Atom("$" + text_of(b))]))
    } else if mem != 0 {
      head.push(List([Atom("memory"), Atom(mem.to_string())]))
    }
    head.push(expr("offset", const_expr(m, offset)))
  }
  List([block(head), Atom(quoted(d.init))])
}

///|
/// `(offset ...)` and the like -- except that a single FOLDED instruction
/// already reads as one expression, so the keyword is left out and the
/// instruction stands for itself. That is the abbreviation the format allows
/// and the one the reference takes.
fn expr(name : String, body : Array[Sexp]) -> Sexp {
  if body.length() == 1 {
    return body[0]
  }
  let l : Array[Sexp] = [Atom(name)]
  for x in body {
    l.push(x)
  }
  List(l)
}

///|
/// How many items of a kind the imports took before the defined ones start.
fn imported_count(m : @wasm_bin.Module, of_ : String) -> Int {
  import_slots(m, m.imports.length()).get(of_).unwrap_or(0)
}

///|
/// A constant expression, folded like any other body. It carries no spans --
/// an initialiser is a single instruction tree the lowering emitted in one go
/// -- so the fold falls back to reading the last instruction as the head.
fn const_expr(
  m : @wasm_bin.Module,
  body : Array[@wasm_bin.Instruction],
) -> Array[Sexp] raise WatError {
  let ctx = { m, locals: Map([]), labels: Map([]), opened: 0, scope: [] }
  let out : Array[Sexp] = []
  for node in fold(body, []) {
    out.push(folded(node, ctx))
  }
  out
}
