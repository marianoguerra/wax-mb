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
  /// Whether an unresolved `#[if(..)]` may be lowered rather than refused.
  /// Only the TEXT form may: the binary has nowhere to put one.
  keep_conditionals? : Bool = false,
) -> @wasm_bin.Module raise LowerError {
  // A module with an UNRESOLVED conditional cannot be emitted at all, and the
  // check belongs here rather than at the first one reached: the reference
  // rejects the module, not the field, and stumbling further in produces a
  // downstream complaint about whatever the conditional left inconsistent.
  for field in source {
    ignore(field)
  }
  // A module with an unresolved conditional cannot be EMITTED at all, and the
  // check belongs here rather than at the first one reached: the reference
  // rejects the module, not the field, and stumbling further in produces a
  // downstream complaint about whatever the conditional left inconsistent.
  if !keep_conditionals {
    for field in source {
      if field.desc is Conditional(..) {
        raise Unemittable("conditional annotations", field.info)
      }
      // A GUARDED attribute is a conditional too, and the reference refuses a
      // module for one just the same: `#[start, if(debug)]` says the start is
      // conditional, and a binary has one start or none.
      for a in field_attributes(field.desc) {
        if a.attr_guard is Some(_) {
          raise Unemittable("conditional annotations", field.info)
        }
      }
    }
  }
  let indices = assign_indices(ctx, source)
  // The layout FIRST: it installs the store-to-emitted translation that every
  // type reference below is read through, including the ones inside the
  // annotations the checker left.
  let layout = type_layout(ctx, source, store)
  let m = @wasm_bin.Module::empty()
  let low : Lowering = {
    ctx,
    store,
    indices,
    layout,
    locals: Map([]),
    local_types: [],
    entry_locs: Map([]),
    keep_conditionals,
    body_conditionals: [],
    pending_start: None,
    spans: [],
    nested_spans: [],
    binding_slots: Map([]),
    claimed: Map([]),
    local_names: Map([]),
    label_names: Map([]),
    label_counter: 0,
    pending_handlers: [],
    func_refs_in_body: [],
    func_refs_outside: [],
    in_body: false,
    labels: [],
    source_types: source_type_index(ctx, layout),
    functypes: functype_index(store, layout),
  }
  // Imports come from the SOURCE, because the checker resolves them into its
  // tables and drops them from the typed output -- and they are exactly what
  // cannot be skipped, since each one starts an index space. Emitted first, in
  // written order, which is the order their indices were assigned in.
  // Where each recorded field stood in the SOURCE, so the two walks below --
  // imports first, then everything else -- can be put back into one order.
  // The walks cannot be merged: an import starts an index space and has to be
  // lowered before anything that refers to it.
  let order_at : Array[@basic.Location] = []
  // The declared features lead the fields, wherever the attributes stood.
  for f in source {
    if f.desc is ModuleAnnotation(attrs) {
      for a in attrs {
        if a.attr_name == "feature" &&
          a.attr_value is Some({ desc: Str(_, b), .. }) {
          m.text.field_order.push(FFeature(b))
          order_at.push(f.info)
        }
      }
    }
  }
  let mut failure : LowerError? = None
  @typing.walk_fields(ctx, source, field => {
    if failure is Some(_) {
      return
    }
    try {
      match field.desc {
        Import(module_~, decl~) => {
          low.import_(m, module_.desc, decl.desc, field.info)
          m.text.field_order.push(FImport(m.imports.length() - 1))
          order_at.push(field.info)
          low.flush_start(m, order_at, field.info)
        }
        ImportGroup(module_~, decls~) => {
          // The order is recorded AFTER the group is compacted, because
          // compacting replaces the run of entries with one that stands for
          // all of them -- so the indices to record only exist once it has run.
          let before = m.imports.length()
          let before_exports = m.exports.length()
          for d in decls {
            low.import_(m, module_.desc, d.desc, field.info)
          }
          low.compact_group(m, decls.length(), field.info)
          for k in before..<m.imports.length() {
            m.text.field_order.push(FImport(k))
            order_at.push(field.info)
          }
          // A COMPACTED group writes one name per item and one descriptor for
          // all of them, so an item has no form of its own for an export
          // clause to hang off. Those exports become fields.
          if m.imports.length() - before < decls.length() {
            for e in before_exports..<m.exports.length() {
              m.text.standalone_exports[e] = true
              m.text.field_order.push(FExport(e))
              order_at.push(field.info)
            }
          }
          low.flush_start(m, order_at, field.info)
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
    let before = m.text.field_order.length()
    low.field(m, field)
    for k in before..<m.text.field_order.length() {
      // Most entries stand where their field does. A guarded export stands
      // where its ATTRIBUTE does, because that is what the condition wraps.
      order_at.push(low.entry_locs.get(k).unwrap_or(field.info))
    }
  }
  reorder_fields(m, order_at)
  low.declare_func_refs(m, source)
  // The type section LAST: a synthesized type is materialised when something
  // refers to it, so the section is not complete until everything has been
  // lowered. Its declared prefix was fixed before any of that, which is what
  // lets the indices be handed out along the way.
  for t in layout.types {
    m.types.push(t)
  }
  for g in layout.groups {
    m.rec_groups.push(g)
  }
  // The name section last: it is a view over every index space, so it wants
  // them all assigned.
  low.type_names(m)
  low.module_name(m, source)
  low.target_features(m, source)
  // The conditionals LAST, because they are read back against the field
  // positions above: the checker flattens a conditional away, so the fields of
  // both branches are already in the module and only where they stood says
  // which branch each came from.
  note_conditionals(m, source)
  m
}

///|
/// Write the `(start ..)` an import named, after the import itself.
///
/// An import is written before the start it names, and `import_` cannot push
/// the field entry itself: the import's own entry is pushed by its caller,
/// once the index it took is known.
fn Lowering::flush_start(
  self : Lowering,
  m : @wasm_bin.Module,
  order_at : Array[@basic.Location],
  loc : @basic.Location,
) -> Unit {
  guard self.pending_start is Some((fi, a)) else { return }
  self.pending_start = None
  if a.attr_guard is Some(g) {
    m.text.conditionals.push({
      cond: wat_cond(g.desc),
      loc: a.attr_span,
      then_: a.attr_span,
      else_: None,
    })
    m.text.field_order.push(FStart(fi))
    order_at.push(a.attr_span)
    return
  }
  m.text.field_order.push(FStart(fi))
  order_at.push(loc)
}

///|
/// Whether an emitted function type has the shape this signature wrote.
///
/// Only the ARITY is compared: that is what tells two conditional branches'
/// declarations apart, and a deeper comparison would have to re-resolve every
/// written type through the layout to say anything more.
fn Lowering::functype_matches(
  self : Lowering,
  emitted : Int,
  sign : @ast.FuncType,
) -> Bool {
  guard self.layout.types.get(emitted) is Some(t) else { return true }
  guard t.composite is Func(ft) else { return true }
  ft.params.length() == sign.params.length() &&
  ft.results.length() == sign.results.length()
}

///|
/// How many imports of this kind are already there, which is the index the
/// next one takes.
fn imports_so_far(m : @wasm_bin.Module, want : Int) -> Int {
  let mut n = 0
  for i in m.imports {
    // A COMPACT group is one entry standing for a run of imports, so the count
    // advances by what the entry stands for rather than by one.
    match i.group {
      None => if import_kind(i.desc) == want { n = n + 1 }
      Some(Heterogeneous(items)) =>
        for it in items {
          if import_kind(it.1) == want {
            n = n + 1
          }
        }
      Some(Homogeneous(names)) =>
        if import_kind(i.desc) == want {
          n = n + names.length()
        }
    }
  }
  n
}

///|
/// Which index space an import takes a slot in.
fn import_kind(d : @wasm_bin.ImportDesc) -> Int {
  match d {
    Func(_, _) => 0
    Table(_) => 1
    Memory(_) => 2
    Global(_) => 3
    Tag(_) => 4
  }
}

///|
/// The attributes a field carries, wherever it carries them.
fn field_attributes(
  f : @ast.ModuleField[@basic.Location],
) -> Array[@ast.Attribute] {
  match f {
    Func(attributes~, ..)
    | Global(attributes~, ..)
    | Memory(attributes~, ..)
    | Table(attributes~, ..)
    | Tag(attributes~, ..)
    | Elem(attributes~, ..)
    | Data(attributes~, ..) => attributes
    Import(decl~, ..) => decl.desc.attributes
    ImportGroup(decls~, ..) => {
      let out : Array[@ast.Attribute] = []
      for d in decls {
        for a in d.desc.attributes {
          out.push(a)
        }
      }
      out
    }
    _ => []
  }
}

///|
/// Record the conditional groups the source wrote, with the extent of each
/// branch, so the text form can put its fields back under them.
fn note_conditionals(
  m : @wasm_bin.Module,
  fields : @ast.Module[@basic.Location],
) -> Unit {
  for field in fields {
    guard field.desc is Conditional(cond~, then_fields~, else_fields~) else {
      continue
    }
    m.text.conditionals.push({
      cond: wat_cond(cond),
      loc: field.info,
      then_: then_fields.info,
      else_: else_fields.map(e => e.info),
    })
    note_conditionals(m, then_fields.desc)
    if else_fields is Some(e) {
      note_conditionals(m, e.desc)
    }
  }
}

///|
/// A condition as the WEBASSEMBLY TEXT format writes one.
///
/// Not the Wax spelling: wax says `all(a, b)` and the text format says
/// `(and a b)`. Rendered to a string because a condition never wraps -- it is
/// an annotation payload, and the layout has nothing to decide inside it.
fn wat_cond(c : @wasm_types.Cond) -> String {
  match c {
    Var(v) => "$" + v.desc
    Str(s) => quoted_bytes(s.desc)
    Version(a, b, c2) => "(\{a} \{b} \{c2})"
    And(l) => "(and" + cond_list(l) + ")"
    Or(l) => "(or" + cond_list(l) + ")"
    Not(c2) => "(not " + wat_cond(c2) + ")"
    Cmp(op, a, b) =>
      "(" + wat_cmp(op) + " " + wat_cond(a) + " " + wat_cond(b) + ")"
  }
}

///|
fn cond_list(l : Array[@wasm_types.Cond]) -> String {
  let out = StringBuilder::new()
  for c in l {
    out.write_string(" " + wat_cond(c))
  }
  out.to_string()
}

///|
fn wat_cmp(op : @wasm_types.CmpOp) -> String {
  match op {
    Eq => "="
    Ne => "<>"
    Lt => "<"
    Gt => ">"
    Le => "<="
    Ge => ">="
  }
}

///|
/// A byte string as an annotation payload writes one. Printable ASCII stands
/// for itself; anything else takes a hex escape.
fn quoted_bytes(b : Bytes) -> String {
  let digits = [
    "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f",
  ]
  let out = StringBuilder::new()
  out.write_char('"')
  for k in 0..<b.length() {
    let c = b[k].to_int()
    if c >= 0x20 && c < 0x7F && c != 0x22 && c != 0x5C {
      out.write_char(Int::unsafe_to_char(c))
    } else {
      out.write_string("\\" + digits[c / 16] + digits[c % 16])
    }
  }
  out.write_char('"')
  out.to_string()
}

///|
/// Put the recorded fields back into source order.
///
/// The imports were lowered first because each starts an index space, so the
/// order they were RECORDED in is not the order they were written in. Sorting
/// by where each field started restores that, and the sort is stable so the
/// fields one source field produced keep their relative order.
fn reorder_fields(m : @wasm_bin.Module, at : Array[@basic.Location]) -> Unit {
  guard at.length() == m.text.field_order.length() else { return }
  let order = Array::makei(at.length(), k => k)
  order.sort_by((a, b) => {
    if at[a].start.cnum != at[b].start.cnum {
      at[a].start.cnum - at[b].start.cnum
    } else {
      a - b
    }
  })
  let sorted = order.map(k => m.text.field_order[k])
  let locs = order.map(k => at[k])
  m.text.field_order.clear()
  for f in sorted {
    m.text.field_order.push(f)
  }
  for l in locs {
    m.text.field_locs.push(l)
  }
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
    Func(name~, typ~, sign~, body~, attributes~) => {
      // The function's TYPE index comes from the checker, which interned the
      // signature when it declared the function -- so the type section and the
      // function section agree by construction rather than by a second lookup.
      guard self.ctx.functions.find_no_mark(name.name) is Some(Some(entry)) else {
        raise Unresolved("function signature", loc)
      }
      // A function that NAMES its type means that declaration, not whichever
      // like-shaped one interned first.
      m.funcs.push(
        match typ {
          Some(n) => self.type_index_of(n, loc)
          // No name: the signature is matched against the emitted section, the
          // same way a block's is, because that is where the difference between
          // two like-interned declarations survives.
          None =>
            match sign {
              Some(s) => self.functype_of(s, loc)
              None => emitted_type_index(entry.0.to_int_for_tests_only())
            }
        },
      )
      // The index this definition TAKES, not the one its name resolves to.
      // Under conditional compilation two branches may declare one name, and
      // the name table has a single answer for both -- so the second would go
      // unnamed and the first would be named twice. A definition's index is
      // its position after the imports, which is what it always was; asking
      // the table for it was a longer way to the same number everywhere else.
      let fi = imports_so_far(m, 0) + m.funcs.length() - 1
      note_name(m.names.functions, fi, name.name)
      note_typeuse(m, OwnerFunc(fi), typ, sign)
      let code = self.function_body(entry.0, sign, body.0, body.1, loc)
      m.codes.push({ ..code, priority: function_priority(attributes) })
      m.text.field_order.push(FFunc(m.codes.length() - 1))
      // The local names belong to the function that just closed over them.
      if !self.local_names.is_empty() {
        m.names.locals[fi] = self.local_names
      }
      if !self.label_names.is_empty() {
        m.names.labels[fi] = self.label_names
      }
      self.export_of(m, attributes, Func(fi), name)
      // `#[start]` names the function that runs at instantiation. A module has
      // at most one, which the attribute pass has already checked.
      for a in attributes {
        if a.attr_name == "start" {
          m.start = Some(fi)
          // A GUARDED start stands where its attribute does, under its
          // condition -- the same shape a guarded export takes, and for the
          // same reason: the condition is on the start, not on the function.
          if a.attr_guard is Some(g) {
            self.entry_locs[m.text.field_order.length()] = a.attr_span
            m.text.conditionals.push({
              cond: wat_cond(g.desc),
              loc: a.attr_span,
              then_: a.attr_span,
              else_: None,
            })
          }
          m.text.field_order.push(FStart(fi))
        }
      }
    }
    Global(name~, mut_~, typ~, def~, attributes~) => {
      // The WRITTEN type when there is one. A global's initialiser may have a
      // narrower type than the global itself -- `let g: &?func = f;` holds a
      // funcref, not the type of `f` -- and the declaration is what the module
      // states.
      let ty = match typ {
        Some(t) => self.valtype_index(t, loc)
        None =>
          match node_valtype(def) {
            Some(t) => t
            None => raise Unresolved("global type", loc)
          }
      }
      let (init, init_spans) = self.const_expr(def)
      let gi = imports_so_far(m, 3) + m.globals.length()
      note_name(m.names.globals, gi, name.name)
      m.globals.push({ type_: { mut_, typ: ty }, init, init_spans })
      m.text.field_order.push(FGlobal(m.globals.length() - 1))
      self.export_of(m, attributes, Global(gi), name)
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
      // Unwritten limits are DERIVED from the inline data: the memory has to be
      // big enough to hold what is put in it, and at least one page even when
      // nothing is -- a zero-page memory is legal but is not what "size derived
      // from the data" means, and instantiating against it traps.
      let (mi, ma) = match limits {
        Some(l) => l
        None => (self.derived_pages(data, page_size_log2, loc), None)
      }
      m.memories.push({
        limits: { mi, ma, address_type, page_size_log2, shared },
      })
      m.text.field_order.push(FMemory(m.memories.length() - 1))
      let mem = self.memory_index(name, loc)
      note_name(m.names.memories, mem, name.name)
      // An inline data segment is an ACTIVE segment of this memory, written
      // where the memory is rather than beside it.
      for d in data {
        let (offset, offset_spans) = self.const_expr(d.offset)
        // An inline segment may still be NAMED, and the name belongs to the
        // index it is about to take.
        if d.data_name is Some(n) {
          note_name(m.names.data, m.datas.length(), n.name)
        }
        // An inline segment is still a `(data ..)` FIELD in the text, written
        // after the memory it was written inside.
        m.text.field_order.push(FData(m.datas.length()))
        m.datas.push({
          mode: Active(mem, offset),
          init: data_bytes(d.init, loc),
          spelling: data_spelling(d.init),
          offset_spans,
        })
      }
      self.export_of(m, attributes, Memory(mem), name)
    }
    Table(name~, address_type~, reftype~, limits~, init~, attributes~) => {
      let (mi, ma) = limits.unwrap_or((0UL, None))
      let elem_type = self.reftype_index(reftype, loc)
      let init_ = match init {
        Some(e) => Some(self.const_expr(e))
        None => None
      }
      let (init_body, init_spans) = match init_ {
        Some((b, sp)) => (Some(b), sp)
        None => (None, [])
      }
      note_name(m.names.tables, self.table_index(name, loc), name.name)
      m.text.field_order.push(FTable(m.tables.length()))
      m.tables.push({
        type_: {
          elem_type,
          limits: { mi, ma, address_type, page_size_log2: None, shared: false },
        },
        init: init_body,
        init_spans,
      })
      self.export_of(m, attributes, Table(self.table_index(name, loc)), name)
    }
    Tag(name~, typ~, sign~, attributes~) => {
      note_name(m.names.tags, self.tag_index(name, loc), name.name)
      note_typeuse(m, OwnerTag(self.tag_index(name, loc)), typ, sign)
      note_param_names(m, OwnerTag(self.tag_index(name, loc)), sign)
      // A tag that NAMES its type means that declaration, not whichever
      // like-shaped one the signature search happens to reach first.
      m.text.field_order.push(FTag(m.tags.length()))
      m.tags.push({
        type_idx: match typ {
          Some(n) => self.type_index_of(n, loc)
          None => self.tag_type_index(name, loc)
        },
      })
      self.export_of(m, attributes, Tag(self.tag_index(name, loc)), name)
    }
    Elem(name~, reftype~, mode~, init~, ..) => {
      let mut offset_spans : Array[@wasm_bin.Span] = []
      let mode_ = match mode {
        EPassive => @wasm_bin.ElemMode::Passive
        EActive(tab, offset) => {
          let (out, spans) = self.const_expr(offset)
          offset_spans = spans
          Active(self.table_index(tab, loc), out)
        }
      }
      // Each element is its own constant expression, which is what lets a
      // segment mix `ref.func` and `ref.null`.
      let inits : Array[Array[@wasm_bin.Instruction]] = []
      let init_spans : Array[Array[@wasm_bin.Span]] = []
      for e in init {
        let (out, spans) = self.const_expr(e)
        inits.push(out)
        init_spans.push(spans)
      }
      note_name(m.names.elem, m.elems.length(), name.name)
      m.text.field_order.push(FElem(m.elems.length()))
      m.elems.push({
        mode: mode_,
        type_: self.reftype_index(reftype, loc),
        init: inits,
        init_spans,
        offset_spans,
      })
    }
    Data(name~, mode~, init~, ..) => {
      let mut offset_spans : Array[@wasm_bin.Span] = []
      let mode_ = match mode {
        Passive => @wasm_bin.DataMode::Passive
        Active(mem, offset) => {
          let (out, spans) = self.const_expr(offset)
          offset_spans = spans
          Active(self.memory_index(mem, loc), out)
        }
      }
      // A data segment's name belongs to the index it is about to take, which
      // is the length before the push -- the same reasoning the element
      // segments use, and the reason both are recorded here rather than in the
      // declaration pass: a segment has no declaration of its own.
      if name is Some(n) {
        note_name(m.names.data, m.datas.length(), n.name)
      }
      m.text.field_order.push(FData(m.datas.length()))
      m.datas.push({
        mode: mode_,
        init: data_bytes(init, loc),
        spelling: data_spelling(init),
        offset_spans,
      })
    }
    // Nothing to EMIT: the type section comes from the STORE, which interned
    // every declaration as it was made, so a `type` field has already had its
    // effect by the time the lowering runs. Its POSITION is still recorded,
    // because the text format writes the field where the source put it and the
    // section says nothing about that.
    Type(decls) => {
      let placed : Array[Int] = []
      for d in decls {
        let ti = self.type_index_of(d.desc.0, d.info)
        placed.push(ti)
        // A declared function type may NAME its parameters, and the type
        // section has nowhere to put a name.
        if d.desc.1.typ is Func(ft) {
          note_param_names(m, OwnerType(ti), Some(ft))
        }
      }
      m.text.field_order.push(FTypes(placed))
    }
    // A module annotation carries feature and name metadata the checker
    // consumed, not code -- except for the declared features, which the text
    // format keeps. They are collected before the walk, not here, because the
    // reference writes them ALL first rather than where they stood.
    ModuleAnnotation(_) => ()
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
  self.spans = []
  // A FRESH array, not a cleared one: the code built for the previous function
  // holds the array itself, so emptying it in place empties that function's
  // record too -- and every function ended up with the last one's.
  self.nested_spans = []
  self.binding_slots = Map([])
  self.claimed = Map([])
  self.local_names = Map([])
  self.label_names = Map([])
  self.label_counter = 0
  self.labels = []
  self.body_conditionals = []
  self.in_body = true
  // A function that WROTE its parameters has them right there, and that is the
  // only answer that is certainly this function's. The checker's table is
  // keyed by name alone, so under conditional compilation -- where two
  // branches may declare one name with different signatures -- the store can
  // hand back the other branch's.
  //
  // Only a function that named a type instead of writing a signature has to
  // ask the store, and then there are no names to bind anyway.
  guard sign is Some(sign) else {
    let sub = self.store.subtyping_info().get_subtype(type_id)
    guard sub.typ is Func(ft) else { raise Unresolved("function type", loc) }
    if ft.params.length() > 0 {
      raise Unresolved("parameter names", loc)
    }
    return {
      locals: [],
      body: self.lower_body(label, instrs),
      spans: self.spans,
      nested_spans: self.nested_spans,
      conditionals: self.body_conditionals,
      priority: None,
    }
  }
  for k, p in sign.params {
    if p.desc.0 is Some(name) {
      self.locals[name.name] = k
      note_name(self.local_names, k, self.claim_name(name.name))
    }
  }
  // Then the declared locals, numbered after the parameters in the order they
  // are written -- which is how wasm numbers them, so no arithmetic is needed
  // at any `local.get`.
  self.collect_locals(instrs, sign.params.length())
  let body = self.lower_body(label, instrs)
  self.in_body = false
  {
    locals: self.local_types,
    body,
    spans: self.spans,
    nested_spans: self.nested_spans,
    conditionals: self.body_conditionals,
    priority: None,
  }
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
      // Numbered in the order the `local.set`s HAPPEN, which is right to left:
      // the values are on the stack with the last on top, so the last binding
      // is written first and takes the lower slot. Numbering them as written
      // would name the same locals in the other order.
      for j in 0..<bindings.length() {
        let k = bindings.length() - 1 - j
        let b = bindings[k]
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
        // The slot is recorded against the BINDING, not the name: a shadowing
        // `let` must not be in scope for its own initializer, and only the
        // lowering knows when that moment has passed.
        self.binding_slots[name.loc.start.cnum] = next
        note_name(self.local_names, next, self.claim_name(name.name))
        self.local_types.push(ty)
        next = next + 1
      }
    }
    // A `match` arm BINDS the value it matched, and the binding is written in
    // the pattern rather than as a `let` -- so the generic walk below never
    // sees it. Its slot has to be assigned where the arm's own lowering puts
    // the store: before the arm's body, and after the previous arm's.
    if i.desc is Match(arms~, default~, scrutinee~) {
      // The arms' blocks NEST, the last one outermost, so the store for the
      // last arm's binding is the first one reached -- and slots are numbered
      // in the order the stores happen. Walking the arms forwards would number
      // them the other way round and name every local wrong.
      for k = arms.length() - 1; k >= 0; k = k - 1 {
        if arms[k].0 is MatchCast(Some(bind), rt) {
          let ty = self.valtype_index(Ref(rt), i.info.1)
          self.binding_slots[bind.loc.start.cnum] = next
          note_name(self.local_names, next, self.claim_name(bind.name))
          self.local_types.push(ty)
          next = next + 1
        }
      }
      // The scrutinee sits at the BOTTOM of the test chain, inside the
      // innermost block, so anything it binds comes after every arm's binding.
      visit(scrutinee)
      for arm in arms {
        for s in arm.1.desc {
          visit(s)
        }
      }
      for s in default.desc {
        visit(s)
      }
      return
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
/// Lower a constant expression, keeping its spans to itself.
///
/// A const expression is its own body with its own indices, so its spans
/// cannot go in the enclosing list -- the function being lowered, or the last
/// one lowered before this field. They did, and an element segment's four
/// initialisers left four spans behind that the preceding function's operands
/// then matched against, folding two of them into each other.
fn Lowering::const_expr(
  self : Lowering,
  e : @ast.Instr[@typing_env.InferredAnnotation],
) -> (Array[@wasm_bin.Instruction], Array[@wasm_bin.Span]) raise LowerError {
  let outer = self.spans
  self.spans = []
  let out : Array[@wasm_bin.Instruction] = []
  self.instr(out, e)
  let spans = self.spans
  self.spans = outer
  (out, spans)
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
    let at = m.exports.length()
    m.exports.push({ name, desc })
    // A GUARDED export is a field of its own under its condition. A clause on
    // the thing exported has nowhere to put one.
    if a.attr_guard is Some(g) {
      m.text.standalone_exports[at] = true
      self.entry_locs[m.text.field_order.length()] = a.attr_span
      m.text.field_order.push(FExport(at))
      m.text.conditionals.push({
        cond: wat_cond(g.desc),
        loc: a.attr_span,
        then_: a.attr_span,
        else_: None,
      })
    }
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
    Func(exact~, sign~, ..) => {
      guard self.ctx.functions.find_no_mark(decl.id.name) is Some(Some(entry)) else {
        raise Unresolved("imported function signature", loc)
      }
      let interned = emitted_type_index(entry.0.to_int_for_tests_only())
      // The checker's table is keyed by NAME alone, so two branches of a
      // conditional that import one name share an entry and one of them gets
      // the other's signature. Only then is the written one preferred: taking
      // it always changes which imports a compact group can share a descriptor
      // with, and that is encoded.
      let ti = match sign {
        Some(fsig) if !self.functype_matches(interned, fsig) =>
          self.functype_of(fsig, loc)
        _ => interned
      }
      Func(ti, exact)
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
    // An imported tag that NAMES its type means that declaration, exactly as a
    // defined one does.
    Tag(typ~, ..) =>
      Tag(
        match typ {
          Some(n) => self.type_index_of(n, loc)
          None => self.tag_type_index(decl.id, loc)
        },
      )
  }
  // The index this import TAKES, which is its position among the imports of
  // its own kind. Not what its name resolves to: two branches of a conditional
  // may import one name, and the name table has a single answer for both.
  let at = imports_so_far(m, import_kind(desc))
  m.imports.push({ mod_name: module_, name, desc, group: None })
  match decl.kind {
    Func(typ~, sign~, ..) => {
      note_name(m.names.functions, at, decl.id.name)
      note_param_names(m, OwnerFunc(at), sign)
      note_typeuse(m, OwnerFunc(at), typ, sign)
    }
    Global(..) => note_name(m.names.globals, at, decl.id.name)
    Memory(..) => note_name(m.names.memories, at, decl.id.name)
    Table(..) => note_name(m.names.tables, at, decl.id.name)
    Tag(typ~, sign~) => {
      note_name(m.names.tags, at, decl.id.name)
      note_typeuse(m, OwnerTag(at), typ, sign)
      note_param_names(m, OwnerTag(at), sign)
    }
  }
  // An import may be re-exported, and then it is exported under the name THIS
  // module gave it rather than the one it was imported as.
  let export_desc : @wasm_bin.ExportDesc = match decl.kind {
    Func(..) => Func(at)
    Global(..) => Global(at)
    Memory(..) => Memory(at)
    Table(..) => Table(at)
    Tag(..) => Tag(self.tag_index(decl.id, loc))
  }
  self.export_of(m, decl.attributes, export_desc, decl.id)
  // An IMPORTED function can be the start function too: `#[start]` names the
  // function that runs at instantiation, and nothing says it has to be one this
  // module defines.
  if decl.kind is Func(..) {
    for a in decl.attributes {
      if a.attr_name == "start" {
        let fi = self.func_index(decl.id, loc)
        m.start = Some(fi)
        // The FIELD entry is pushed by the caller, after the import's own --
        // an import is written before the start it names.
        self.pending_start = Some((fi, a))
      }
    }
  }
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
      let i = self.type_index_of(n, loc)
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
      // A numeric run writes each value at the width its element type fixes,
      // LITTLE-endian, which is the only endianness wasm memory has.
      Run(ty, items) => {
        let width = match ty {
          Packed(I8) => 1
          Packed(I16) => 2
          Value(I32) | Value(F32) => 4
          Value(I64) | Value(F64) => 8
          _ => raise NotLowered("data run element type", loc)
        }
        for item in items {
          let bits = match ty {
            Value(F32) =>
              parse_f32(item.desc, loc).reinterpret_as_int().to_int64() &
              0xFFFFFFFFL
            Value(F64) =>
              parse_float_bits(item.desc, true, loc).reinterpret_as_int64()
            _ => parse_i64(item.desc, loc)
          }
          for b in 0..<width {
            out.push(
              ((bits.reinterpret_as_uint64() >> (b * 8)).to_int() & 0xFF).to_byte(),
            )
          }
        }
      }
      // A vector run is the same, sixteen bytes at a time, and each element
      // carries its own shape: `[v128: i32x4(..), f64x2(..)]` is one segment
      // of two vectors written two different ways.
      V128Run(vs) =>
        for v in vs {
          let shape = match v.desc.shape {
            I8x16 => @simd.Shape::I8x16
            I16x8 => @simd.Shape::I16x8
            I32x4 => @simd.Shape::I32x4
            I64x2 => @simd.Shape::I64x2
            F32x4 => @simd.Shape::F32x4
            F64x2 => @simd.Shape::F64x2
          }
          let bytes = vector_bytes(shape, v.desc.components, loc)
          for k in 0..<bytes.length() {
            out.push(bytes[k])
          }
        }
    }
  }
  Bytes::from_array(out)
}

///|
/// How the source wrote a data segment, piece by piece.
///
/// Recorded beside the bytes rather than recovered from them: the bytes are
/// what the binary holds, and no reading of them says whether they were a
/// string, a run of `i16`s, or a pair of vectors.
fn data_spelling(init : Array[@ast.DataElem]) -> Array[@wasm_bin.DataPiece] {
  let out : Array[@wasm_bin.DataPiece] = []
  for e in init {
    match e {
      Str(b) => out.push(PieceStr(b))
      Run(ty, items) => {
        let kw = match ty {
          Packed(I8) => "i8"
          Packed(I16) => "i16"
          Value(I32) => "i32"
          Value(I64) => "i64"
          Value(F32) => "f32"
          Value(F64) => "f64"
          _ => "i8"
        }
        out.push(PieceRun(kw, items.map(i => i.desc)))
      }
      V128Run(vs) => {
        let items : Array[String] = []
        for v in vs {
          items.push(
            match v.desc.shape {
              I8x16 => "i8x16"
              I16x8 => "i16x8"
              I32x4 => "i32x4"
              I64x2 => "i64x2"
              F32x4 => "f32x4"
              F64x2 => "f64x2"
            },
          )
          for c in v.desc.components {
            items.push(c)
          }
        }
        out.push(PieceRun("v128", items))
      }
    }
  }
  out
}

///|
/// Note which of the two type clauses a declaration wrote. Both are optional
/// and independent, and the index the binary keeps says nothing about either.
fn note_typeuse(
  m : @wasm_bin.Module,
  owner : @wasm_bin.ParamOwner,
  typ : @ast.Ident?,
  sign : @ast.FuncType?,
) -> Unit {
  m.text.decl_typeuse[owner] = {
    named: typ is Some(_),
    spelled: sign is Some(_),
  }
}

///|
/// Note the parameter names a declaration wrote, when it wrote any.
///
/// Only the declarations whose names the binary drops: a defined function's
/// parameters are locals and the name section carries them already.
fn note_param_names(
  m : @wasm_bin.Module,
  owner : @wasm_bin.ParamOwner,
  sign : @ast.FuncType?,
) -> Unit {
  guard sign is Some(ft) else { return }
  let names : Map[Int, Bytes] = Map([])
  for k, p in ft.params {
    if p.desc.0 is Some(id) {
      names[k] = utf8_of(id.name)
    }
  }
  if !names.is_empty() {
    m.text.decl_param_names[owner] = names
  }
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

///|
/// The declarative element segment that makes the module's funcrefs valid.
///
/// `ref.func` is only accepted on a function the module has DECLARED. A
/// reference in a global initializer or an element segment already declares
/// it; one inside a body declares nothing, so those are gathered into a single
/// segment emitted once at module level.
///
/// A module with `#[if]` fields gets none. A referenced function may itself be
/// conditionally defined, so the segment would name an index that is absent
/// under some configuration -- and a segment that is wrong under one
/// configuration is worse than none, since the conditional output is wax-only
/// text anyway and `-D` resolves it before this ever matters.
fn Lowering::declare_func_refs(
  self : Lowering,
  m : @wasm_bin.Module,
  source : @ast.Module[@basic.Location],
) -> Unit {
  for field in source {
    if field.desc is Conditional(..) {
      return
    }
  }
  // LAST reference first, which matches the reference on more modules than
  // first-seen does (83 failures against 86) but not on all of them: its own
  // order is a hash table's iteration order, which is neither. Reproducing
  // that exactly would mean reimplementing OCaml's string hashing and bucket
  // layout, and the segment's order is observable, so a handful of modules
  // stay different for that reason alone.
  let init : Array[Array[@wasm_bin.Instruction]] = []
  for k = self.func_refs_in_body.length() - 1; k >= 0; k = k - 1 {
    let name = self.func_refs_in_body[k]
    if self.func_refs_outside.contains(name) {
      continue
    }
    guard self.indices.funcs.get(name) is Some(f) else { continue }
    init.push([RefFunc(f)])
  }
  if !init.is_empty() {
    m.elems.push({
      mode: Declarative,
      type_: { nullable: false, typ: Func },
      init,
      // One `ref.func` each, so each folds to itself.
      init_spans: init.map(_ => {
        [{ start: 0, head: 0, end: 1, loc: @basic.dummy_loc }]
      }),
      offset_spans: [],
    })
  }
}

///|
/// Claim a wasm-level name for this function, renaming on a collision.
///
/// Wasm gives a function one flat namespace, and wax lets a `let` shadow. The
/// second `x` therefore becomes `x_2`, the third `x_3`, and the count is kept
/// against the BASE so the numbering continues rather than restarting -- which
/// is what stops `x_2` itself from colliding with a written `x_2`.
fn Lowering::claim_name(self : Lowering, base : String) -> String {
  match self.claimed.get(base) {
    None => {
      self.claimed[base] = 1
      base
    }
    Some(n) => {
      let mut k = n + 1
      while self.claimed.contains(base + "_" + k.to_string()) {
        k = k + 1
      }
      let name = base + "_" + k.to_string()
      self.claimed[name] = 1
      self.claimed[base] = k
      name
    }
  }
}

///|
/// The minimum page count an inline data list forces.
///
/// The extent is the highest `offset + length` over the ACTIVE segments, and
/// the count is that divided by the page size, rounded up -- with a floor of
/// one page, which is what a memory whose size is "derived from its data"
/// means even when it has none.
fn Lowering::derived_pages(
  self : Lowering,
  data : Array[@ast.MemData[@typing_env.InferredAnnotation]],
  page_size_log2 : Int?,
  loc : @basic.Location,
) -> UInt64 raise LowerError {
  ignore(self)
  let page_size = 1UL << page_size_log2.unwrap_or(16)
  let mut extent = 0UL
  for d in data {
    guard d.offset.desc is Int(s) else { continue }
    let off = parse_i64(s, loc).reinterpret_as_uint64()
    let len = data_bytes(d.init, loc).length().to_uint64()
    let end = off + len
    // Running past the end of the address space is not a small memory: the
    // wrap would underestimate it, so treat it as maximal.
    let end = if end < off { 0xFFFFFFFFFFFFFFFFUL } else { end }
    if end > extent {
      extent = end
    }
  }
  let pages = extent / page_size +
    (if extent % page_size == 0UL { 0UL } else { 1UL })
  if pages < 1UL {
    1UL
  } else {
    pages
  }
}

///|
/// Fold the last `n` imports into one compact group entry.
///
/// `import "m" { .. }` is one block in the source and, under the
/// compact-import-section feature, one entry in the binary: the module name is
/// written once. Each item still claims its own index, so the entries are built
/// individually first and collapsed here -- which also means a module without
/// the feature simply skips this step and keeps them.
///
/// The homogeneous form shares a single descriptor and lists only names. It is
/// available exactly when every item's descriptor is EQUAL, so sharing loses
/// nothing -- not merely when they are the same kind, which would drop the
/// differences.
fn Lowering::compact_group(
  self : Lowering,
  m : @wasm_bin.Module,
  n : Int,
  loc : @basic.Location,
) -> Unit {
  ignore(loc)
  guard n >= 2 else { return }
  guard self.ctx.type_context.features.is_enabled(CompactImportSection) else {
    return
  }
  let start = m.imports.length() - n
  guard start >= 0 else { return }
  let items = m.imports[start:].to_owned()
  let head = items[0]
  let homogeneous = items.iter().all(i => i.desc == head.desc)
  let group : @wasm_bin.ImportGroup = if homogeneous {
    Homogeneous(items.map(i => i.name))
  } else {
    Heterogeneous(items.map(i => (i.name, i.desc)))
  }
  for _ in 0..<n {
    let _ = m.imports.pop()
  }
  m.imports.push({ ..head, group: Some(group) })
}
