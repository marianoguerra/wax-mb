// Lowering a module's fields.
//
// Ported from `module_` in wax/src/lib-conversion/to_wasm.ml.
//
// The sections come out in the order the format requires, which is not the order
// a wax module is written in -- so this collects each kind as it walks and
// assembles at the end. The index spaces were already assigned, so a function
// written last can be called by one written first without a second pass.

///|
/// Lower a checked module to the binary form.
pub fn lower_module(
  ctx : @typing_env.ModuleContext,
  store : @type_store.TypeStore,
  source : @ast.Module[@basic.Location],
  typed : Array[
    @basic.Annotated[
      @ast.ModuleField[@typing_env.InferredAnnotation],
      @basic.Location,
    ],
  ],
) -> @wasm_bin.Module raise LowerError {
  let indices = assign_indices(ctx, source)
  let (types, rec_groups) = type_section(store)
  let m = @wasm_bin.Module::empty()
  for t in types {
    m.types.push(t)
  }
  for g in rec_groups {
    m.rec_groups.push(g)
  }
  let low : Lowering = {
    ctx,
    store,
    indices,
    locals: Map([]),
    local_types: [],
    local_names: Map([]),
    label_names: Map([]),
    label_counter: 0,
    labels: [],
    source_types: source_type_index(ctx),
    functypes: functype_index(store),
  }
  // Imports come from the SOURCE, because the checker resolves them into its
  // tables and drops them from the typed output -- and they are exactly what
  // cannot be skipped, since each one starts an index space. Emitted first, in
  // written order, which is the order their indices were assigned in.
  let mut failure : LowerError? = None
  @typing.walk_fields(ctx, source, field => {
    if failure is Some(_) {
      return
    }
    try {
      match field.desc {
        Import(module_~, decl~) =>
          low.import_(m, module_.desc, decl.desc, field.info)
        ImportGroup(module_~, decls~) =>
          for d in decls {
            low.import_(m, module_.desc, d.desc, field.info)
          }
        _ => ()
      }
    } catch {
      e => failure = Some(e)
    }
  })
  if failure is Some(e) {
    raise e
  }
  for field in typed {
    low.field(m, field)
  }
  // The name section last: it is a view over every index space, so it wants
  // them all assigned.
  low.type_names(m)
  low.module_name(m, source)
  low.target_features(m, source)
  m
}

///|
/// Lower one module field into the module being built.
fn Lowering::field(
  self : Lowering,
  m : @wasm_bin.Module,
  field : @basic.Annotated[
    @ast.ModuleField[@typing_env.InferredAnnotation],
    @basic.Location,
  ],
) -> Unit raise LowerError {
  let loc = field.info
  match field.desc {
    Func(name~, sign~, body~, attributes~, ..) => {
      // The function's TYPE index comes from the checker, which interned the
      // signature when it declared the function -- so the type section and the
      // function section agree by construction rather than by a second lookup.
      guard self.ctx.functions.find_no_mark(name.name) is Some(Some(entry)) else {
        raise Unresolved("function signature", loc)
      }
      m.funcs.push(entry.0.to_int_for_tests_only())
      let fi = self.func_index(name, loc)
      note_name(m.names.functions, fi, name.name)
      let code = self.function_body(entry.0, sign, body.0, body.1, loc)
      m.codes.push({ ..code, priority: function_priority(attributes) })
      // The local names belong to the function that just closed over them.
      if !self.local_names.is_empty() {
        m.names.locals[fi] = self.local_names
      }
      if !self.label_names.is_empty() {
        m.names.labels[fi] = self.label_names
      }
      self.export_of(m, attributes, Func(self.func_index(name, loc)), name)
    }
    Global(name~, mut_~, def~, attributes~, ..) => {
      guard node_valtype(def) is Some(ty) else {
        raise Unresolved("global type", loc)
      }
      let init : Array[@wasm_bin.Instruction] = []
      self.instr(init, def)
      note_name(m.names.globals, self.global_index(name, loc), name.name)
      m.globals.push({ type_: { mut_, typ: ty }, init })
      self.export_of(m, attributes, Global(self.global_index(name, loc)), name)
    }
    Memory(
      name~,
      address_type~,
      limits~,
      page_size_log2~,
      shared~,
      data~,
      attributes~
    ) => {
      let (mi, ma) = limits.unwrap_or((0UL, None))
      m.memories.push({
        limits: { mi, ma, address_type, page_size_log2, shared },
      })
      let mem = self.memory_index(name, loc)
      note_name(m.names.memories, mem, name.name)
      // An inline data segment is an ACTIVE segment of this memory, written
      // where the memory is rather than beside it.
      for d in data {
        let offset : Array[@wasm_bin.Instruction] = []
        self.instr(offset, d.offset)
        m.datas.push({
          mode: Active(mem, offset),
          init: data_bytes(d.init, loc),
        })
      }
      self.export_of(m, attributes, Memory(mem), name)
    }
    Table(name~, address_type~, reftype~, limits~, init~, attributes~) => {
      let (mi, ma) = limits.unwrap_or((0UL, None))
      let elem_type = self.reftype_index(reftype, loc)
      let init_ = match init {
        Some(e) => {
          let out : Array[@wasm_bin.Instruction] = []
          self.instr(out, e)
          Some(out)
        }
        None => None
      }
      note_name(m.names.tables, self.table_index(name, loc), name.name)
      m.tables.push({
        type_: {
          elem_type,
          limits: { mi, ma, address_type, page_size_log2: None, shared: false },
        },
        init: init_,
      })
      self.export_of(m, attributes, Table(self.table_index(name, loc)), name)
    }
    Tag(name~, attributes~, ..) => {
      note_name(m.names.tags, self.tag_index(name, loc), name.name)
      m.tags.push({ type_idx: self.tag_type_index(name, loc) })
      self.export_of(m, attributes, Tag(self.tag_index(name, loc)), name)
    }
    Elem(name~, reftype~, mode~, init~, ..) => {
      let mode_ = match mode {
        EPassive => @wasm_bin.ElemMode::Passive
        EActive(tab, offset) => {
          let out : Array[@wasm_bin.Instruction] = []
          self.instr(out, offset)
          Active(self.table_index(tab, loc), out)
        }
      }
      // Each element is its own constant expression, which is what lets a
      // segment mix `ref.func` and `ref.null`.
      let inits : Array[Array[@wasm_bin.Instruction]] = []
      for e in init {
        let out : Array[@wasm_bin.Instruction] = []
        self.instr(out, e)
        inits.push(out)
      }
      note_name(m.names.elem, m.elems.length(), name.name)
      m.elems.push({
        mode: mode_,
        type_: self.reftype_index(reftype, loc),
        init: inits,
      })
    }
    Data(mode~, init~, ..) => {
      let mode_ = match mode {
        Passive => @wasm_bin.DataMode::Passive
        Active(mem, offset) => {
          let out : Array[@wasm_bin.Instruction] = []
          self.instr(out, offset)
          Active(self.memory_index(mem, loc), out)
        }
      }
      m.datas.push({ mode: mode_, init: data_bytes(init, loc) })
    }
    // Nothing to emit: the type section comes from the STORE, which interned
    // every declaration as it was made, so a `type` field has already had its
    // effect by the time the lowering runs. A module annotation carries feature
    // and name metadata the checker consumed, not code.
    Type(_) | ModuleAnnotation(_) => ()
    _ => raise NotLowered(field_name(field.desc), loc)
  }
}

///|
/// One function's locals and body.
///
/// Wasm numbers locals with the PARAMETERS first, then the declared ones in
/// order -- so the map is built by walking the same way, and a `local.get` needs
/// no arithmetic to find its slot.
fn Lowering::function_body(
  self : Lowering,
  type_id : @type_store.Id,
  sign : @ast.FuncType?,
  label : @ast.Ident?,
  instrs : Array[@ast.Instr[@typing_env.InferredAnnotation]],
  loc : @basic.Location,
) -> @wasm_bin.FunctionCode raise LowerError {
  self.locals = Map([])
  self.local_types = []
  self.local_names = Map([])
  self.label_names = Map([])
  self.label_counter = 0
  self.labels = []
  let sub = self.store.subtyping_info().get_subtype(type_id)
  guard sub.typ is Func(ft) else { raise Unresolved("function type", loc) }
  // The parameter TYPES come from the store, already in index form and already
  // deduplicated; the NAMES come from the written signature. They are the same
  // list in the same order, which is what lets the two be zipped rather than
  // re-derived.
  guard sign is Some(sign) else {
    if ft.params.length() > 0 {
      raise Unresolved("parameter names", loc)
    } else {
      { locals: [], body: self.lower_body(label, instrs), priority: None }
    }
  }
  guard sign.params.length() == ft.params.length() else {
    raise Unresolved("parameter count", loc)
  }
  for k, p in sign.params {
    if p.desc.0 is Some(name) {
      self.locals[name.name] = k
      note_name(self.local_names, k, name.name)
    }
  }
  // Then the declared locals, numbered after the parameters in the order they
  // are written -- which is how wasm numbers them, so no arithmetic is needed
  // at any `local.get`.
  self.collect_locals(instrs, ft.params.length())
  let body = self.lower_body(label, instrs)
  { locals: self.local_types, body, priority: None }
}

///|
/// Assign a slot to every `let` binding in a body, in source order.
fn Lowering::collect_locals(
  self : Lowering,
  instrs : Array[@ast.Instr[@typing_env.InferredAnnotation]],
  start : Int,
) -> Unit raise LowerError {
  let mut next = start
  fn visit(
    i : @ast.Instr[@typing_env.InferredAnnotation],
  ) -> Unit raise LowerError {
    if i.desc is Let(bindings, init) {
      for k, b in bindings {
        guard b.0 is Some(name) else { continue }
        // The slot's type: the WRITTEN annotation when there is one -- a bare
        // `let p: &point;` declares a local with no initializer at all, and
        // then the annotation is the only thing that says what it holds.
        // Otherwise what the initializer produced at that position, which the
        // checker has already made agree with any annotation.
        let ty = match b.1 {
          Some(written) => Some(self.valtype_index(written, i.info.1))
          None =>
            match init {
              Some(e) =>
                if e.info.0.length() > k &&
                  @typing_env.standalone_valtype(e.info.0[k]) is Some(v) {
                  Some(lower_valtype(v.internal))
                } else {
                  None
                }
              None => None
            }
        }
        guard ty is Some(ty) else { raise Unresolved("local type", i.info.1) }
        self.locals[name.name] = next
        note_name(self.local_names, next, name.name)
        self.local_types.push(ty)
        next = next + 1
      }
    }
    for sub in i.sub_instrs() {
      visit(sub)
    }
  }

  for s in instrs {
    visit(s)
  }
}

///|
/// The body's instructions, under the function's own label.
fn Lowering::lower_body(
  self : Lowering,
  label : @ast.Ident?,
  instrs : Array[@ast.Instr[@typing_env.InferredAnnotation]],
) -> Array[@wasm_bin.Instruction] raise LowerError {
  let body : Array[@wasm_bin.Instruction] = []
  // The function's own frame is pushed for DEPTH but takes no label index: the
  // name section numbers the blocks a body contains, and the body is not one of
  // them.
  self.labels.push(label.map(l => l.name))
  for s in instrs {
    self.instr(body, s)
  }
  body
}

///|
/// Record an `#[export]` on a field.
fn Lowering::export_of(
  self : Lowering,
  m : @wasm_bin.Module,
  attributes : Array[@ast.Attribute],
  desc : @wasm_bin.ExportDesc,
  own : @ast.Ident,
) -> Unit raise LowerError {
  ignore(self)
  for a in attributes {
    guard a.attr_name == "export" else { continue }
    let name = match a.attr_value {
      Some(v) =>
        match v.desc {
          Str(_, b) => b
          _ => raise NotLowered("computed export name", v.info)
        }
      // A bare `#[export]` exports under the entity's OWN name, which is the
      // whole point of writing it bare.
      None => utf8_of(own.name)
    }
    m.exports.push({ name, desc })
  }
}

///|
/// A name as the UTF-8 bytes the format stores.
fn utf8_of(s : String) -> Bytes {
  Bytes::from_array(@unicode.utf8_bytes(s).map(b => b.to_byte()))
}

///|
fn Lowering::func_index(
  self : Lowering,
  name : @ast.Ident,
  loc : @basic.Location,
) -> Int raise LowerError {
  match self.indices.funcs.get(name.name) {
    Some(i) => i
    None => raise Unresolved("function index", loc)
  }
}

///|
fn Lowering::global_index(
  self : Lowering,
  name : @ast.Ident,
  loc : @basic.Location,
) -> Int raise LowerError {
  match self.indices.globals.get(name.name) {
    Some(i) => i
    None => raise Unresolved("global index", loc)
  }
}

///|
/// One imported declaration.
///
/// The import section is where an index space STARTS, so an import that is not
/// emitted does not merely go missing -- it shifts every definition after it,
/// and a `call` compiled against the wax numbering then names the wrong
/// function. Nothing here is optional for that reason.
fn Lowering::import_(
  self : Lowering,
  m : @wasm_bin.Module,
  module_ : Bytes,
  decl : @ast.ImportDecl,
  loc : @basic.Location,
) -> Unit raise LowerError {
  // The import's own name in the other module: `#[import = "nm"]` overrides it,
  // and otherwise it is the name this module knows it by.
  let mut name = utf8_of(decl.id.name)
  for a in decl.attributes {
    if a.attr_name == "import" && a.attr_value is Some(v) && v.desc is Str(_, b) {
      name = b
    }
  }
  let desc : @wasm_bin.ImportDesc = match decl.kind {
    Func(..) => {
      guard self.ctx.functions.find_no_mark(decl.id.name) is Some(Some(entry)) else {
        raise Unresolved("imported function signature", loc)
      }
      Func(entry.0.to_int_for_tests_only())
    }
    Global(mut_~, typ~) => Global({ mut_, typ: self.valtype_index(typ, loc) })
    Memory(address_type~, limits~, page_size_log2~, shared~) => {
      let (mi, ma) = limits.unwrap_or((0UL, None))
      Memory({ limits: { mi, ma, address_type, page_size_log2, shared } })
    }
    Table(address_type~, reftype~, limits~) => {
      let (mi, ma) = limits.unwrap_or((0UL, None))
      Table({
        elem_type: self.reftype_index(reftype, loc),
        limits: { mi, ma, address_type, page_size_log2: None, shared: false },
      })
    }
    Tag(..) => Tag(self.tag_type_index(decl.id, loc))
  }
  m.imports.push({ mod_name: module_, name, desc })
  match decl.kind {
    Func(..) =>
      note_name(m.names.functions, self.func_index(decl.id, loc), decl.id.name)
    Global(..) =>
      note_name(m.names.globals, self.global_index(decl.id, loc), decl.id.name)
    Memory(..) =>
      note_name(m.names.memories, self.memory_index(decl.id, loc), decl.id.name)
    Table(..) =>
      note_name(m.names.tables, self.table_index(decl.id, loc), decl.id.name)
    Tag(..) =>
      note_name(m.names.tags, self.tag_index(decl.id, loc), decl.id.name)
  }
  // An import may be re-exported, and then it is exported under the name THIS
  // module gave it rather than the one it was imported as.
  let export_desc : @wasm_bin.ExportDesc = match decl.kind {
    Func(..) => Func(self.func_index(decl.id, loc))
    Global(..) => Global(self.global_index(decl.id, loc))
    Memory(..) => Memory(self.memory_index(decl.id, loc))
    Table(..) => Table(self.table_index(decl.id, loc))
    Tag(..) => Tag(self.tag_index(decl.id, loc))
  }
  self.export_of(m, decl.attributes, export_desc, decl.id)
}

///|
/// A source value type with its type names resolved to indices.
fn Lowering::valtype_index(
  self : Lowering,
  v : @wasm_types.ValType[@ast.Ident],
  loc : @basic.Location,
) -> @wasm_types.ValType[Int] raise LowerError {
  match v {
    I32 => I32
    I64 => I64
    F32 => F32
    F64 => F64
    V128 => V128
    Ref(r) => Ref(self.reftype_index(r, loc))
  }
}

///|
/// The type index a tag's signature interned to.
///
/// A tag names a function type, and the store interned it structurally -- so
/// the lookup is BY SHAPE, exactly as a block's is. A tag whose inline
/// signature matches nothing in the store is one the checker never interned,
/// and there is no index to name it by.
fn Lowering::tag_type_index(
  self : Lowering,
  name : @ast.Ident,
  loc : @basic.Location,
) -> Int raise LowerError {
  guard self.ctx.tags.find_no_mark(name.name) is Some(ft) else {
    raise Unresolved("tag signature", loc)
  }
  let params : Array[@wasm_types.ValType[Int]] = []
  for p in ft.params {
    params.push(self.valtype_index(p.desc.1, loc))
  }
  let results : Array[@wasm_types.ValType[Int]] = []
  for r in ft.results {
    results.push(self.valtype_index(r, loc))
  }
  guard self.functypes.get((params, results)) is Some(i) else {
    raise Unresolved("tag type", loc)
  }
  i
}

///|
fn Lowering::tag_index(
  self : Lowering,
  name : @ast.Ident,
  loc : @basic.Location,
) -> Int raise LowerError {
  match self.indices.tags.get(name.name) {
    Some(i) => i
    None => raise Unresolved("tag index", loc)
  }
}

///|
fn Lowering::memory_index(
  self : Lowering,
  name : @ast.Ident,
  loc : @basic.Location,
) -> Int raise LowerError {
  match self.indices.memories.get(name.name) {
    Some(i) => i
    None => raise Unresolved("memory index", loc)
  }
}

///|
fn Lowering::table_index(
  self : Lowering,
  name : @ast.Ident,
  loc : @basic.Location,
) -> Int raise LowerError {
  match self.indices.tables.get(name.name) {
    Some(i) => i
    None => raise Unresolved("table index", loc)
  }
}

///|
/// A source reference type with its type names resolved to indices.
fn Lowering::reftype_index(
  self : Lowering,
  r : @wasm_types.RefType[@ast.Ident],
  loc : @basic.Location,
) -> @wasm_types.RefType[Int] raise LowerError {
  let typ = match r.typ {
    Type(n) | Exact(n) => {
      guard self.ctx.type_context.types.find_no_mark(n.name) is Some((idx, _)) else {
        raise Unresolved("type name", loc)
      }
      let i = match idx {
        Def(id) => id.to_int_for_tests_only()
        Rec(_) => raise Unresolved("rec-group type reference", loc)
      }
      if r.typ is Exact(_) {
        @wasm_types.HeapType::Exact(i)
      } else {
        Type(i)
      }
    }
    Func => Func
    NoFunc => NoFunc
    Exn => Exn
    NoExn => NoExn
    Cont => Cont
    NoCont => NoCont
    Extern => Extern
    NoExtern => NoExtern
    Any => Any
    Eq => Eq
    I31 => I31
    Struct => Struct
    Array => Array
    None_ => None_
  }
  { nullable: r.nullable, typ }
}

///|
/// A data segment's contents as the bytes the format stores.
fn data_bytes(
  init : Array[@ast.DataElem],
  loc : @basic.Location,
) -> Bytes raise LowerError {
  let out : Array[Byte] = []
  for e in init {
    match e {
      Str(b) =>
        for k in 0..<b.length() {
          out.push(b[k])
        }
      // A numeric run and a vector run both need the width and endianness the
      // element type fixes; neither is lowered yet.
      Run(_, _) | V128Run(_) => raise NotLowered("data run", loc)
    }
  }
  Bytes::from_array(out)
}

///|
/// A readable name for a module field, for the "not lowered" report.
fn field_name(f : @ast.ModuleField[@typing_env.InferredAnnotation]) -> String {
  match f {
    Func(..) => "function"
    Global(..) => "global"
    Type(_) => "type"
    Tag(..) => "tag"
    Memory(..) => "memory"
    Table(..) => "table"
    Data(..) => "data segment"
    Elem(..) => "element segment"
    Import(..) | ImportGroup(..) => "import"
    ModuleAnnotation(_) => "module annotation"
    Conditional(..) => "conditional"
  }
}
