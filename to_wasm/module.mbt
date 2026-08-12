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
    labels: [],
    source_types: source_type_index(ctx),
  }
  for field in typed {
    low.field(m, field)
  }
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
      let code = self.function_body(entry.0, sign, body.0, body.1, loc)
      m.codes.push(code)
      self.export_of(m, attributes, Func(self.func_index(name, loc)), name)
    }
    Global(name~, mut_~, def~, attributes~, ..) => {
      guard node_valtype(def) is Some(ty) else {
        raise Unresolved("global type", loc)
      }
      let init : Array[@wasm_bin.Instruction] = []
      self.instr(init, def)
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
      guard self.ctx.tags.find_no_mark(name.name) is Some(_) else {
        raise Unresolved("tag signature", loc)
      }
      raise NotLowered("tag", loc)
      ignore(attributes)
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
        // The slot's type: what the initializer produced at that position. A
        // written annotation says the same thing, since the checker has already
        // made the initializer agree with it.
        let ty = match init {
          Some(e) =>
            if e.info.0.length() > k &&
              @typing_env.standalone_valtype(e.info.0[k]) is Some(v) {
              Some(lower_valtype(v.internal))
            } else {
              None
            }
          None => None
        }
        guard ty is Some(ty) else { raise Unresolved("local type", i.info.1) }
        self.locals[name.name] = next
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
