// The type section: which types are emitted, and at which indices.
//
// Ported from the type-field conversion of wax/src/lib-conversion/to_wasm.ml
// together with the index assignment of wax/src/lib-wasm/text_to_binary.ml.
//
// The store is NOT the section. The store interns -- two declarations of the
// same shape share one entry, which is the canonicalisation wasm's own type
// equivalence performs, and the checker needs it to answer subtyping. The
// section does not intern: `type sig = fn();` and `type elems = fn();` are two
// entries at two indices, and `&?elems` means the second one.
//
// So the section is built from the SOURCE's declarations -- one entry per name,
// in the order they were written -- and the store is consulted only for what
// each name means. Types the store holds that no declaration names are the
// synthesized ones, and they follow.
//
// The store index and the emitted index are therefore different numbers, and
// every reference has to be translated between them. The translation is
// installed per module in a mutable cell rather than threaded, exactly as the
// reference does and for the same reason: it is read from the leaf functions
// that turn an annotation into a value type, and threading it there would put a
// parameter on every one of their callers to no purpose.

///|
/// Store index to emitted index, for the module being lowered.
///
/// Empty means the identity, which is what the unit tests want: they build a
/// module without a source to lay out.
let type_remap : Ref[Map[Int32, Int32]] = { val: Map([]), }

///|
/// The emitted index a store index became.
fn emitted_type_index(store_index : Int32) -> Int32 {
  // Several declarations of one shape under different conditions: the one
  // visible from where the reference stands.
  if current_layout.val is Some(layout) &&
    layout.visible_slot(store_index) is Some(i) {
    return i
  }
  match type_remap.val.get(store_index) {
    Some(i) => i
    None => store_index
  }
}

///|
/// Emitted index back to store index, the inverse of `type_remap`.
let store_remap : Ref[Array[Int32]] = { val: [], }

///|
/// The store index behind an emitted one.
fn store_type_index(emitted : Int32) -> Int32 {
  let m = store_remap.val
  if emitted >= 0 && emitted < m.length() {
    m[emitted]
  } else {
    emitted
  }
}

///|
/// The layout of the module being lowered, for the leaf functions that resolve
/// a reference by name. Companion to `type_remap`, and installed with it.
let current_layout : Ref[TypeLayout?] = { val: None, }

///|
/// The emitted index a type NAME means.
///
/// A declared name has its own entry. A SYNTHESIZED one -- `<func:f>`, the
/// type a `ref.func` gives its function -- has none until something refers to
/// it, and then it gets one of its own rather than borrowing the like-shaped
/// declaration it interned with: the reference materialises it too, and the
/// index is observable.
fn emitted_named_index(name : String, store_index : Int32) -> Int32 {
  guard current_layout.val is Some(layout) else {
    return emitted_type_index(store_index)
  }
  let at = named_index(layout, name, store_index)
  layout.referenced[at] = true
  // Its OWN entry, not a declared type it was found equal to.
  if is_synthetic(name) &&
    layout.by_name.get(name) == Some(at) &&
    !layout.declared_slots.contains(at) &&
    !layout.extras_seen.contains(name) {
    layout.extras_seen.push(name)
  }
  at
}

///|
fn named_index(
  layout : TypeLayout,
  name : String,
  store_index : Int32,
) -> Int32 {
  if layout.resolve_name(name, layout.site) is Some(i) {
    return i
  }
  if layout.aliases.get(name) is Some(i) {
    return i
  }
  if !is_synthetic(name) {
    return emitted_type_index(store_index)
  }
  // A synthesized type REUSES a declared one of the same definition rather
  // than being materialised beside it. The comparison is on the whole written
  // subtype -- finality and supertype included -- not on the interned entry:
  // interning normalises exactly the differences that decide this, so two
  // names can share a store entry and still be two types here.
  // An entry no DECLARATION put there is simply this type's own: interning
  // did not merge it with anything that has a definition of its own, so there
  // is nothing for it to be confused with.
  if layout.by_store.get(store_index) is Some(existing) {
    // An entry placed FOR this name is this name's, and carries it: the
    // reference materialises a defined function's signature under its own
    // name once something refers to it. An entry this name merely reaches --
    // `<string>`, or an import's inline signature -- is an alias, and stays
    // unnamed.
    if layout.slot_names.get(existing) is Some(owner) && owner == name {
      layout.by_name[name] = existing
      return existing
    }
  }
  guard layout.written.get(name) is Some(mine) else {
    return emitted_type_index(store_index)
  }
  for entry in layout.declared {
    if same_written(entry.0, mine) && layout.slot_visible(entry.1) {
      // Remembered only when no conditional makes the answer depend on where
      // the reference stands.
      if layout.conds.is_empty() {
        layout.by_name[name] = entry.1
      }
      return entry.1
    }
  }
  let emitted = layout.types.length()
  layout.by_name[name] = emitted
  layout.store_of.push(store_index)
  layout.types.push(layout.pending[store_index])
  layout.groups.push({ start: emitted, len: 1, explicit: false, })
  emitted
}

///|
/// The emitted indices that share a rec group with another type.
fn in_shared_groups(layout : TypeLayout) -> Map[Int32, Unit] {
  let out : Map[Int32, Unit] = Map([])
  for g in layout.groups {
    if g.len > 1 {
      for k in g.start..<(g.start + g.len) {
        out[k] = ()
      }
    }
  }
  out
}

///|
/// The emitted index of a store entry no NAME refers to here, materialising an
/// unnamed one if the section holds none.
///
/// A string literal's byte array is such a reference: the reference writes the
/// literal as an `@string` annotation, which takes the first array type of
/// that shape the section holds -- one the source declared, or one a name
/// materialised -- and otherwise appends an unnamed one where the literal is.
/// Referring to it by its synthesized name instead would make it a field.
fn emitted_store_index(store_index : Int32) -> Int32 {
  guard current_layout.val is Some(layout) else {
    return emitted_type_index(store_index)
  }
  match layout.by_store.get(store_index) {
    Some(e) => layout.visible_slot(store_index).unwrap_or(e)
    None => {
      let emitted = layout.types.length()
      layout.by_store[store_index] = emitted
      layout.store_of.push(store_index)
      layout.types.push(layout.pending[store_index])
      layout.groups.push({ start: emitted, len: 1, explicit: false, })
      emitted
    }
  }
}

///|
/// The emitted index of a function SHAPE, materialising one if the section
/// holds none.
///
/// A block written with parameters -- `do (i32, i32) -> i32 { .. }` -- names
/// its signature by shape rather than by name, and nothing may have interned
/// that shape: it is not a declaration, and no function has it. The entry it
/// then needs is a real type in the section, appended like any other.
fn emitted_shape_index(
  params : Array[@wasm_types.ValType[Int32]],
  results : Array[@wasm_types.ValType[Int32]],
) -> Int32? {
  guard current_layout.val is Some(layout) else { return None }
  let grouped = in_shared_groups(layout)
  for emitted, sub in layout.types {
    if sub.composite is Func(ft) &&
      sub.final_ &&
      sub.supertypes.is_empty() &&
      !grouped.contains(emitted) &&
      ft.params == params &&
      ft.results == results {
      return Some(emitted)
    }
  }
  let emitted = layout.types.length()
  layout.store_of.push(-1)
  layout.types.push({
    final_: true,
    supertypes: [],
    descriptor: None,
    describes: None,
    composite: Func({ params, results, }),
  })
  layout.groups.push({ start: emitted, len: 1, explicit: false, })
  Some(emitted)
}

///|
/// Where each type name lands in the emitted section.
priv struct TypeLayout {
  /// Emitted index for a declared name: its FIRST declaration, when branches
  /// of a conditional declare it more than once (see `decls`).
  by_name : Map[String, Int32]
  /// Every declaration of a name, with where it was written and the emitted
  /// index it took. Two branches of a conditional may each declare a name, and
  /// the text form writes both, each at an index of its own.
  decls : Map[String, Array[(Int32, @basic.Location)]]
  /// What each declaration's slot holds, as its own branch defined it.
  decl_written : Map[Int32, @ast.SubType]
  /// The conditional groups the source wrote, for the site a reference stands
  /// at to pick the declaration it can see.
  conds : Array[@wasm_bin.CondGroup]
  /// Where the reference being resolved stands: the field being lowered.
  mut site : @basic.Location?
  /// Emitted index for a store index: the FIRST declaration of that shape,
  /// which is the one a reference carrying only an interned id must mean.
  by_store : Map[Int32, Int32]
  /// The store index behind each emitted one, for the reads that go back to
  /// the store for a definition.
  store_of : Array[Int32]
  types : Array[@wasm_bin.SubType]
  groups : Array[@wasm_bin.RecGroup]
  /// Every store entry already lowered, so a synthesized type materialised
  /// mid-lowering costs a lookup rather than a re-resolution.
  pending : Array[@wasm_bin.SubType]
  /// The subtype each name was WRITTEN as, before interning normalised it.
  written : Map[String, @ast.SubType]
  /// The declared subtypes, with the index each landed at, for the reuse test.
  declared : Array[(@ast.SubType, Int32)]
  /// The name a store-tier entry was placed FOR, when it was placed for one.
  slot_names : Map[Int32, String]
  /// The synthesized names that came to own an entry of their own, in the
  /// order they were first referred to: the reference's extra types, which
  /// it writes after the declared ones (see `type_layout`'s `extras`).
  extras_seen : Array[String]
  /// Names that resolve to an entry they do not own: the entry was interned
  /// for its own reasons and this name merely reaches it. Kept apart from
  /// `by_name` because the name section emits the latter and not this.
  aliases : Map[String, Int32]
  /// Which emitted entries a DECLARATION put there. A synthesized type sharing
  /// one of those is a different type that merely interned with it; sharing an
  /// entry nothing declared is just itself.
  declared_slots : Map[Int32, Bool]
  /// The entries something referred to BY NAME while lowering.
  ///
  /// A type materialised for a name is written as a field only when something
  /// names it: `(ref $<func:f>)` in a global's type makes the entry a field,
  /// and an entry nothing reaches is spelled inline wherever it is used.
  referenced : Map[Int32, Bool]
}

///|
/// Lay out the type section from the source's declarations, then the rest.
fn type_layout(
  ctx : @typing_env.ModuleContext,
  source : @ast.Module[@basic.Location],
  store : @type_store.TypeStore,
  extras~ : Array[String] = [],
  conds~ : Array[@wasm_bin.CondGroup] = [],
) -> TypeLayout {
  let by_name : Map[String, Int32] = Map([])
  let decls : Map[String, Array[(Int32, @basic.Location)]] = Map([])
  let decl_written : Map[Int32, @ast.SubType] = Map([])
  let by_store : Map[Int32, Int32] = Map([])
  let store_of : Array[Int32] = []
  let groups : Array[@wasm_bin.RecGroup] = []
  fn place(name : @ast.Ident, store_index : Int32, def : @ast.SubType) -> Unit {
    let emitted = store_of.length()
    if !by_name.contains(name.name) {
      by_name[name.name] = emitted
    }
    match decls.get(name.name) {
      Some(l) => l.push((emitted, name.loc))
      None => decls[name.name] = [(emitted, name.loc)]
    }
    decl_written[emitted] = def
    if !by_store.contains(store_index) {
      by_store[store_index] = emitted
    }
    store_of.push(store_index)
  }

  // The declarations, in source order, one rec group per `type` field.
  @typing.walk_fields(ctx, source, field => {
    guard field.desc is Type(rectype) else { return }
    let start = store_of.length()
    for entry in rectype {
      let (name, _) = entry.desc
      // Under the branch's own assumption (`walk_fields` sets it), so a name
      // two branches declare reads as this branch's declaration.
      guard ctx.type_context.types.find_no_mark(name.name) is Some((idx, def)) else {
        continue
      }
      guard idx is Def(id) else { continue }
      place(name, id.to_int_for_tests_only(), def)
    }
    // Pushed even when EMPTY: `rec {}` is a rec group of no types, and it is
    // WRITTEN -- a group the author declared and the format can spell, not an
    // absence.
    let len = store_of.length() - start
    groups.push({ start, len, explicit: len != 1, })
  })
  // Then the synthesized types that own an entry of their own -- the
  // reference's extra types, which it writes after every declared one and
  // before anything it interns from a signature, in its hash table's order
  // (`extras`, worked out by a first lowering). An inline signature of the
  // same shape then reuses one of them, as the reference's does. Kept out of
  // `by_name` until the declared types have been read off it below.
  let extra_slots : Array[(String, Int32)] = []
  for name in extras {
    guard ctx.type_context.types.find_no_mark(name) is Some((Def(id), _)) else {
      continue
    }
    let si = id.to_int_for_tests_only()
    let emitted = store_of.length()
    if !by_store.contains(si) {
      by_store[si] = emitted
    }
    store_of.push(si)
    groups.push({ start: emitted, len: 1, explicit: false, })
    extra_slots.push((name, emitted))
  }
  // Then the types the LOWERING interns rather than the checker, in the order
  // the sections that need them are written -- which is binary section order,
  // not source order: imports, then functions, then tags. A module whose tags
  // are declared first still emits its function types first, because the
  // function section is written first.
  //
  // These are placed by STORE ENTRY, not by name: a signature with no name of
  // its own is interned structurally, so two functions of one shape share an
  // index rather than taking two.
  fn place_store(store_index : Int32) -> Unit {
    if by_store.contains(store_index) {
      return
    }
    let start = store_of.length()
    by_store[store_index] = start
    store_of.push(store_index)
    groups.push({ start, len: 1, explicit: false, })
  }

  // The name a store-tier entry was placed FOR. Its written form is what gets
  // lowered: a signature's inner references mean the names the signature
  // wrote, and interning has already merged those names with any like-shaped
  // siblings -- so reading the entry back from the store would resolve them to
  // whichever sibling happened to be declared first.
  let slot_names : Map[Int32, String] = Map([])
  // What each of those was written as, read under the assumption it was
  // placed under: two branches may mint one synthesized name for two
  // signatures -- an import in one, a definition in the other.
  let slot_written : Map[Int32, @ast.SubType] = Map([])
  fn place_named(name : String) -> Unit {
    guard ctx.type_context.types.find_no_mark(name) is Some((Def(id), def)) else {
      return
    }
    let before = store_of.length()
    place_store(id.to_int_for_tests_only())
    if store_of.length() > before {
      slot_names[before] = name
      slot_written[before] = def
    }
  }

  fn place_import_signature(decl : @ast.ImportDecl) -> Unit {
    match decl.kind {
      Func(..) => place_named("<func:" + decl.id.name + ">")
      Tag(..) => place_named("<functype:" + decl.id.name + ">")
      _ => ()
    }
  }

  @typing.walk_fields(ctx, source, field => {
    match field.desc {
      // An IMPORT's signature is a module-level reference and is interned when
      // the import is registered, so it comes before anything a body needs --
      // and a tag import's signature comes with it, at its written position,
      // rather than with the defined tags much later.
      Import(decl~, ..) => place_import_signature(decl.desc)
      ImportGroup(decls~, ..) =>
        for d in decls {
          place_import_signature(d.desc)
        }
      _ => ()
    }
  })
  @typing.walk_fields(ctx, source, field => {
    match field.desc {
      Func(name~, ..) => place_named("<func:" + name.name + ">")
      _ => ()
    }
  })
  // A defined tag's inline signature is NOT placed here: the reference interns
  // it after every body's block types, so the lowering resolves it once the
  // code is lowered. An entry only a tag uses is left for then.
  let tag_only : Map[Int32, Unit] = Map([])
  @typing.walk_fields(ctx, source, field => {
    match field.desc {
      Tag(name~, typ=None, ..) =>
        match
          ctx.type_context.types.find_no_mark("<functype:" + name.name + ">") {
          Some((Def(id), _)) if !by_store.contains(id.to_int_for_tests_only()) =>
            tag_only[id.to_int_for_tests_only()] = ()
          _ => ()
        }
      _ => ()
    }
  })
  // Then everything the store holds that nothing above reached, in the order
  // it was interned.
  let mut store_index = 0
  for group in store.get_all_rectypes() {
    let start = store_of.length()
    let mut added = 0
    for _ in group {
      if !by_store.contains(store_index) && !tag_only.contains(store_index) {
        by_store[store_index] = store_of.length()
        store_of.push(store_index)
        added = added + 1
      }
      store_index = store_index + 1
    }
    if added > 0 {
      groups.push({ start, len: added, explicit: added != 1, })
    }
  }
  type_remap.val = by_store
  store_remap.val = store_of
  let info = store.subtyping_info()
  let types : Array[@wasm_bin.SubType] = []
  let pending : Array[@wasm_bin.SubType] = []
  let written : Map[String, @ast.SubType] = Map([])
  let declared : Array[(@ast.SubType, Int32)] = []
  let aliases : Map[String, Int32] = Map([])
  let declared_slots : Map[Int32, Bool] = Map([])
  let referenced : Map[Int32, Bool] = Map([])
  for _, i in by_name {
    declared_slots[i] = true
  }
  for i, _ in decl_written {
    declared_slots[i] = true
  }
  // As WRITTEN, aliases included: a signature written with an alias is not
  // the one written with what the alias stands for, and a synthesized type
  // reuses only a declaration written the same.
  for entry in ctx.type_context.types.iter_entries() {
    let (name, (_, sub)) = entry
    written[name] = ctx.type_context.written_form(name, sub)
  }
  for name, i in by_name {
    if written.get(name) is Some(sub) {
      declared.push((sub, i))
    }
  }
  for e in extra_slots {
    by_name[e.0] = e.1
    slot_names[e.1] = e.0
  }
  let layout = {
    by_name,
    decls,
    decl_written,
    conds,
    site: None,
    by_store,
    store_of,
    types,
    groups,
    pending,
    written,
    declared,
    declared_slots,
    referenced,
    aliases,
    slot_names,
    extras_seen: [],
  }
  current_layout.val = Some(layout)
  for si in 0..<store.last_index() {
    pending.push(lower_subtype(info.get_subtype(@type_store.Id::of_index(si))))
  }
  for emitted, si in store_of {
    // A DECLARED type is lowered from what the source wrote, so that an inner
    // `&t2` means `t2` and not the like-shaped `t1` it interned with. Reading
    // it back from the store would resolve every such reference to whichever
    // declaration came first, which is the same collapse this whole layout
    // exists to undo.
    let written_form = match declared_at(ctx, layout, emitted) {
      Some(sub) => Some(sub)
      None =>
        match slot_written.get(emitted) {
          Some(sub) => Some(sub)
          None =>
            match slot_names.get(emitted) {
              Some(name) => layout.written.get(name)
              None => None
            }
        }
    }
    // A declaration's inner references are read from where it was written:
    // under a conditional, a name the branch declares means its own.
    layout.site = layout.decl_site(emitted)
    match written_form {
      Some(sub) => types.push(layout.source_subtype(ctx, sub))
      None =>
        types.push(
          lower_subtype(info.get_subtype(@type_store.Id::of_index(si))),
        )
    }
  }
  layout.site = None
  layout
}

///|
/// The declared slot of a store entry visible from the current site, when
/// declarations under different conditions share the entry and the first of
/// them is not visible from there. `None` leaves the answer to `type_remap`.
fn TypeLayout::visible_slot(self : TypeLayout, store_index : Int32) -> Int32? {
  guard self.site is Some(_) else { return None }
  guard self.by_store.get(store_index) is Some(first) else { return None }
  if self.slot_visible(first) {
    return None
  }
  for slot, si in self.store_of {
    if si == store_index &&
      self.decl_written.contains(slot) &&
      self.slot_visible(slot) {
      return Some(slot)
    }
  }
  None
}

///|
/// Whether the declaration at a slot can be seen from the current site: its
/// conditional guards are a prefix of the site's. A slot no declaration put
/// there, or a reference with no site, sees everything.
fn TypeLayout::slot_visible(self : TypeLayout, slot : Int32) -> Bool {
  guard self.site is Some(site) else { return true }
  match self.decl_site(slot) {
    None => true
    Some(d) => {
      let g = guards_at(self.conds, d)
      let here = guards_at(self.conds, site)
      g.length() <= here.length() &&
      g.iter().zip(here.iter()).all(p => p.0 == p.1)
    }
  }
}

///|
/// Where the declaration at an emitted index was written, if one put it there.
fn TypeLayout::decl_site(
  self : TypeLayout,
  emitted : Int32,
) -> @basic.Location? {
  for _, l in self.decls {
    for e in l {
      if e.0 == emitted {
        return Some(e.1)
      }
    }
  }
  None
}

///|
/// The emitted index of the declaration of `name` a reference at `at` can see:
/// the one whose conditional guards are the longest prefix of the site's, as
/// for every other index space (see `Space::resolve`). The first declaration
/// when there is no site, or only one declaration.
fn TypeLayout::resolve_name(
  self : TypeLayout,
  name : String,
  at : @basic.Location?,
) -> Int32? {
  guard self.decls.get(name) is Some(l) && l.length() > 1 && at is Some(at) else {
    return self.by_name.get(name)
  }
  let here = guards_at(self.conds, at)
  let mut best : Int32? = None
  let mut best_len = -1
  for entry in l {
    let g = guards_at(self.conds, entry.1)
    guard g.length() <= here.length() else { continue }
    let mut ok = true
    for k in 0..<g.length() {
      if g[k] != here[k] {
        ok = false
        break
      }
    }
    if ok && g.length() > best_len {
      best_len = g.length()
      best = Some(entry.0)
    }
  }
  match best {
    Some(_) => best
    None => self.by_name.get(name)
  }
}

///|
/// The source declaration at an emitted index, if a declaration put it there.
fn declared_at(
  ctx : @typing_env.ModuleContext,
  layout : TypeLayout,
  emitted : Int32,
) -> @ast.SubType? {
  if layout.decl_written.get(emitted) is Some(sub) {
    return Some(sub)
  }
  for name, i in layout.by_name {
    if i == emitted {
      if ctx.type_context.types.find_no_mark(name) is Some((_, sub)) {
        return Some(sub)
      }
    }
  }
  None
}

///|
/// A declared type, lowered from what the source wrote.
fn TypeLayout::source_subtype(
  self : TypeLayout,
  ctx : @typing_env.ModuleContext,
  s : @ast.SubType,
) -> @wasm_bin.SubType {
  fn idx(n : @ast.Ident) -> Int32 {
    match self.resolve_name(n.name, self.site) {
      Some(i) => i
      None =>
        match ctx.type_context.types.find_no_mark(n.name) {
          Some((Def(id), _)) => emitted_type_index(id.to_int_for_tests_only())
          _ => 0
        }
    }
  }

  {
    final_: s.final_,
    supertypes: match s.supertype {
      Some(n) => [idx(n)]
      None => []
    },
    descriptor: s.descriptor.map(n => idx(n)),
    describes: s.describes.map(n => idx(n)),
    composite: match s.typ {
      Func(ft) =>
        Func({
          params: ft.params.map(p => self.source_valtype(ctx, p.desc.1)),
          results: ft.results.map(r => self.source_valtype(ctx, r)),
        })
      Struct(fields) =>
        Struct({
          fields: fields.map(f => {
            (
              {
                mut_: f.desc.1.mut_,
                typ: self.source_storagetype(ctx, f.desc.1.typ),
              } : @wasm_types.MutType[@wasm_types.StorageType[Int32]])
          }),
        })
      Array(f) =>
        Array({
          element: { mut_: f.mut_, typ: self.source_storagetype(ctx, f.typ), },
        })
      Cont(n) => Cont(idx(n))
    },
  }
}

///|
fn TypeLayout::source_storagetype(
  self : TypeLayout,
  ctx : @typing_env.ModuleContext,
  s : @wasm_types.StorageType[@ast.Ident],
) -> @wasm_types.StorageType[Int32] {
  match s {
    Value(v) => Value(self.source_valtype(ctx, v))
    Packed(p) => Packed(p)
  }
}

///|
fn TypeLayout::source_valtype(
  self : TypeLayout,
  ctx : @typing_env.ModuleContext,
  v : @wasm_types.ValType[@ast.Ident],
) -> @wasm_types.ValType[Int32] {
  match v {
    I32 => I32
    I64 => I64
    F32 => F32
    F64 => F64
    V128 => V128
    // Expanded here: the binary format has no aliases. One that stands for no
    // type was reported, and the module is never lowered.
    Alias(_) =>
      match ctx.type_context.unalias(v) {
        Alias(a) => abort("unresolved type alias " + a.name)
        t => self.source_valtype(ctx, t)
      }
    Ref(r) => {
      fn idx(n : @ast.Ident) -> Int32 {
        match self.resolve_name(n.name, self.site) {
          Some(i) => i
          None =>
            match ctx.type_context.types.find_no_mark(n.name) {
              Some((Def(id), _)) =>
                emitted_type_index(id.to_int_for_tests_only())
              _ => 0
            }
        }
      }

      Ref({
        nullable: r.nullable,
        typ: match r.typ {
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
          Type(n) => Type(idx(n))
          Exact(n) => Exact(idx(n))
        },
      })
    }
  }
}

///|
/// One stored type, with its `Id` indices flattened to plain integers.
fn lower_subtype(s : @type_store.SubType[@type_store.Id]) -> @wasm_bin.SubType {
  {
    final_: s.final_,
    supertypes: match s.supertype {
      Some(i) => [emitted_type_index(i.to_int_for_tests_only())]
      None => []
    },
    descriptor: s.descriptor.map(i => {
      emitted_type_index(i.to_int_for_tests_only())
    }),
    describes: s.describes.map(i => {
      emitted_type_index(i.to_int_for_tests_only())
    }),
    composite: lower_comptype(s.typ),
  }
}

///|
fn lower_comptype(
  c : @type_store.CompType[@type_store.Id],
) -> @wasm_bin.CompositeType {
  match c {
    Func(ft) =>
      Func({
        params: ft.params.map(v => lower_valtype(v)),
        results: ft.results.map(v => lower_valtype(v)),
      })
    Struct(fields) =>
      Struct({
        fields: fields.map(f => {
          (
            { mut_: f.mut_, typ: lower_storagetype(f.typ), } :
            @wasm_types.MutType[@wasm_types.StorageType[Int32]])
        }),
      })
    Array(f) =>
      Array({ element: { mut_: f.mut_, typ: lower_storagetype(f.typ), }, })
    Cont(i) => Cont(emitted_type_index(i.to_int_for_tests_only()))
  }
}

///|
/// A value type with its type references flattened to indices.
fn lower_valtype(
  v : @wasm_types.ValType[@type_store.Id],
) -> @wasm_types.ValType[Int32] {
  match v {
    I32 => I32
    I64 => I64
    F32 => F32
    F64 => F64
    V128 => V128
    Ref(r) => Ref(lower_reftype(r))
    // The store never holds an alias: it interns what one stands for.
    Alias(_) => abort("a type alias reached the type store")
  }
}

///|
fn lower_reftype(
  r : @wasm_types.RefType[@type_store.Id],
) -> @wasm_types.RefType[Int32] {
  { nullable: r.nullable, typ: lower_heaptype(r.typ), }
}

///|
fn lower_heaptype(
  h : @wasm_types.HeapType[@type_store.Id],
) -> @wasm_types.HeapType[Int32] {
  match h {
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
    Type(i) => Type(emitted_type_index(i.to_int_for_tests_only()))
    Exact(i) => Exact(emitted_type_index(i.to_int_for_tests_only()))
  }
}

///|
fn lower_storagetype(
  s : @wasm_types.StorageType[@type_store.Id],
) -> @wasm_types.StorageType[Int32] {
  match s {
    Value(v) => Value(lower_valtype(v))
    Packed(p) => Packed(p)
  }
}

///|
/// Whether two definitions were written the same: an alias is the same alias
/// wherever its name was written, so its location does not take part.
fn same_written(a : @ast.SubType, b : @ast.SubType) -> Bool {
  fn v(t : @wasm_types.ValType[@ast.Ident]) -> @wasm_types.ValType[@ast.Ident] {
    match t {
      Alias(n) => Alias({ name: n.name, loc: @basic.dummy_loc, })
      _ => t
    }
  }

  fn storage(
    t : @wasm_types.StorageType[@ast.Ident],
  ) -> @wasm_types.StorageType[@ast.Ident] {
    match t {
      Value(x) => Value(v(x))
      Packed(_) => t
    }
  }

  fn norm(st : @ast.SubType) -> @ast.SubType {
    let typ : @ast.CompType = match st.typ {
      Func(ft) =>
        Func({
          params: ft.params.map(p => { ..p, desc: (p.desc.0, v(p.desc.1)), }),
          results: ft.results.map(v),
        })
      Struct(fields) =>
        Struct(
          fields.map(f => {
            ..f,
            desc: (f.desc.0, { ..f.desc.1, typ: storage(f.desc.1.typ), }),
          }),
        )
      Array(f) => Array({ ..f, typ: storage(f.typ), })
      Cont(_) => st.typ
    }
    { ..st, typ, }
  }

  norm(a) == norm(b)
}
