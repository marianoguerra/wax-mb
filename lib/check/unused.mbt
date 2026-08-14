// The unused-declaration lints.
//
// Ported from the `warn_unused` passes in wax/src/lib-wax/typing.ml.
//
// A declaration nothing uses is worth saying, and the interesting half is what
// "uses" means. For a LOCAL or a LABEL it is a plain fact: the checker records
// every read and every branch target as it goes, so the answer is a lookup.
//
// For a module FIELD it is reachability, not the presence of a reference. Two
// functions that only call each other reference one another, so a presence check
// finds both used -- yet neither can ever run. What can run is what an export,
// the start function, or a module-level initializer reaches, and what those
// transitively call; anything else is dead however many times it is named.
//
// A leading `_` marks a declaration as deliberately unused and exempts it, which
// is also the quick fix these lints offer.

///|
/// Whether a name is marked deliberately unused.
fn intentional(name : String) -> Bool {
  name.length() > 0 && name[0] == 95
}

///|
/// Whether a field's attributes take it out of the lint's reach.
///
/// An exported field is reachable from outside the module and a `start` function
/// runs at instantiation, so neither needs a reference inside it.
fn externally_reachable(attributes : Array[@ast.Attribute]) -> Bool {
  attributes.iter().any(a => a.attr_name is ("export" | "start"))
}

///|
/// Report the locals and labels this function declared and never used.
///
/// Run after the body is typed, since that is when the reads are known, and
/// before the next function's, so the diagnostics stay in source order.
fn warn_unused_in_function(ctx : @typing_env.ModuleContext) -> Unit {
  guard ctx.warn_unused else { return }
  for name in ctx.local_decls {
    if !ctx.read_locals.contains(name.loc.start.cnum) && !intentional(name.name) {
      unused_local(ctx.diagnostics, name.loc, name.name)
    }
  }
  for name in ctx.label_decls {
    if !ctx.used_labels.contains(name.loc.start.cnum) && !intentional(name.name) {
      unused_label(ctx.diagnostics, name.loc, name.name)
    }
  }
}

///|
/// Everything reachable from `seeds` along the edges `edges_of` yields.
fn closure(
  seeds : Array[String],
  edges_of : (String) -> Array[String],
) -> Map[String, Unit] {
  let live : Map[String, Unit] = Map([])
  let stack = seeds.copy()
  while stack.pop() is Some(n) {
    if live.contains(n) {
      continue
    }
    live[n] = ()
    for e in edges_of(n) {
      stack.push(e)
    }
  }
  live
}

///|
/// The functions that can actually run.
///
/// Seeded by what is reachable from outside -- an export, the start function --
/// and by what a module-level context names (a global or table initializer, a
/// segment, all recorded as `Root`); closed over the calls those make. Taking a
/// `&f` counts as calling it, since where the reference ends up is not tracked
/// and the analysis must never report a function that might run.
fn live_functions(
  ctx : @typing_env.ModuleContext,
  fields : @ast.Module[@basic.Location],
) -> Map[String, Unit] {
  let calls : Map[String, Array[String]] = Map([])
  let seeds : Array[String] = []
  for entry in ctx.functions.iter_references() {
    let (callee, referrers) = entry
    for r in referrers {
      match r {
        FromFunction(caller) =>
          match calls.get(caller) {
            Some(l) => l.push(callee)
            None => calls[caller] = [callee]
          }
        // Only types reference types, so a type definition never names a
        // function; treat it as a root rather than losing the reference.
        Root | FromType(_) => seeds.push(callee)
        Ignored => ()
      }
    }
  }
  walk_fields(ctx, fields, field => {
    if field.desc is Func(name~, attributes~, ..) &&
      externally_reachable(attributes) {
      seeds.push(name.name)
    }
  })
  closure(seeds, n => calls.get(n).unwrap_or([]))
}

///|
/// The types anything reachable names.
///
/// Closed over the references a type definition makes through its own components
/// -- its supertype, field and element types, a descriptor clause -- so a rec
/// group nothing outside it names is dead as a whole, its mutual references
/// notwithstanding.
fn live_types(
  ctx : @typing_env.ModuleContext,
  live_fns : Map[String, Unit],
) -> Map[String, Unit] {
  let components : Map[String, Array[String]] = Map([])
  let seeds : Array[String] = []
  for entry in ctx.type_context.types.iter_references() {
    let (target, referrers) = entry
    for r in referrers {
      match r {
        FromType(src) =>
          match components.get(src) {
            Some(l) => l.push(target)
            None => components[src] = [target]
          }
        Root => seeds.push(target)
        FromFunction(f) => if live_fns.contains(f) { seeds.push(target) }
        Ignored => ()
      }
    }
  }
  closure(seeds, n => components.get(n).unwrap_or([]))
}

///|
/// Report every module field nothing that can run refers to.
fn warn_unused_fields(
  ctx : @typing_env.ModuleContext,
  fields : @ast.Module[@basic.Location],
) -> Unit {
  guard ctx.warn_unused else { return }
  // A string literal builds the canonical `mut i8` array without naming any
  // type, so its uses were recorded by INDEX. Resolve them against the
  // definitions that deduplicated onto that index before any reference graph is
  // read -- every one of those source types really is used by the literal.
  if !ctx.canonical_type_references.is_empty() {
    for entry in ctx.type_context.types.iter_entries() {
      let (name, (r, _)) = entry
      if r is Def(id) {
        for ref_ in ctx.canonical_type_references {
          if ref_.1 == id {
            ctx.type_context.types.mark_reference(name, ref_.0)
          }
        }
      }
    }
  }
  let live_fns = live_functions(ctx, fields)
  let live_ts = live_types(ctx, live_fns)
  walk_fields(ctx, fields, field => {
    // A declaration inside a conditional is never reported. Whether it is
    // PRESENT depends on a condition nobody has resolved, and so, usually, does
    // whether anything uses it -- both are guarded by the same flag. There is no
    // answer to give, so the lint gives none.
    guard @cond.equal(ctx.cond.val, @cond.true_) else { return }
    match field.desc {
      Func(name~, attributes~, ..) =>
        report_unused(
          ctx,
          live_fns,
          attributes,
          ctx.functions,
          "function",
          name,
        )
      Global(name~, mut_~, attributes~, ..) => {
        report_unused(ctx, live_fns, attributes, ctx.globals, "global", name)
        // A global nothing uses is already reported just above; a second
        // diagnostic on the same declaration says nothing new. An exported one may
        // be assigned by the host.
        if mut_ &&
          !intentional(name.name) &&
          !externally_reachable(attributes) &&
          referenced(live_fns, ctx.globals, name) &&
          !ctx.assigned_globals.contains(name.name) {
          unnecessary_mut(ctx.diagnostics, name.loc, name.name)
        }
      }
      Memory(name~, attributes~, ..) =>
        report_unused(ctx, live_fns, attributes, ctx.memories, "memory", name)
      Table(name~, attributes~, ..) =>
        report_unused(ctx, live_fns, attributes, ctx.tables, "table", name)
      Tag(name~, attributes~, ..) =>
        report_unused(ctx, live_fns, attributes, ctx.tags, "tag", name)
      // An ACTIVE segment runs at instantiation, so only a passive one can be
      // unused: it is reachable solely through `mem.init`/`tab.init` and
      // `seg.drop`.
      Data(name~, mode~, attributes~, ..) =>
        if name is Some(n) && mode is Passive {
          report_unused(ctx, live_fns, attributes, ctx.datas, "data segment", n)
        }
      Elem(name~, mode~, attributes~, ..) =>
        if mode is EPassive {
          report_unused(
            ctx,
            live_fns,
            attributes,
            ctx.elems,
            "element segment",
            name,
          )
        }
      Import(decl~, ..) => report_unused_import(ctx, live_fns, decl.desc)
      ImportGroup(decls~, ..) =>
        for d in decls {
          report_unused_import(ctx, live_fns, d.desc)
        }
      // Each member of a rec group is reported on its own; the group as a whole is
      // dead only when nothing outside it names any member.
      Type(rectype) =>
        for elt in rectype {
          let name = elt.desc.0
          if !intentional(name.name) && !live_ts.contains(name.name) {
            unused_field(ctx.diagnostics, name.loc, "type", name.name)
          }
        }
      _ => ()
    }
  })
}

///|
/// Whether a reference keeps a name alive.
///
/// A reference from DEAD code keeps nothing alive, which is the whole reason
/// this asks about reachability rather than presence.
fn live_origin(live_fns : Map[String, Unit], o : @typing_env.Origin) -> Bool {
  match o {
    Root => true
    FromFunction(f) => live_fns.contains(f)
    FromType(_) | Ignored => false
  }
}

///|
/// Whether anything that can run refers to this name.
fn[A] referenced(
  live_fns : Map[String, Unit],
  tbl : @typing_env.Tbl[A],
  name : @ast.Ident,
) -> Bool {
  tbl.referrers(name.name).iter().any(o => live_origin(live_fns, o))
}

///|
/// Report one defined field, unless it is exempt.
fn[A] report_unused(
  ctx : @typing_env.ModuleContext,
  live_fns : Map[String, Unit],
  attributes : Array[@ast.Attribute],
  tbl : @typing_env.Tbl[A],
  kind : String,
  name : @ast.Ident,
) -> Unit {
  if !externally_reachable(attributes) &&
    !intentional(name.name) &&
    !referenced(live_fns, tbl, name) {
    unused_field(ctx.diagnostics, name.loc, kind, name.name)
  }
}

///|
/// Report an import nothing references.
///
/// The same rule as a definition, and reported the same way -- an import that
/// nothing uses is dead weight in the linking contract, not merely unread.
fn report_unused_import(
  ctx : @typing_env.ModuleContext,
  live_fns : Map[String, Unit],
  decl : @ast.ImportDecl,
) -> Unit {
  guard !externally_reachable(decl.attributes) else { return }
  let name = decl.id
  // A leading `_` marks it deliberately unused, exactly as for a definition.
  guard !intentional(name.name) else { return }
  match decl.kind {
    Func(..) => import_used(ctx, live_fns, ctx.functions, "function", name)
    Global(..) => import_used(ctx, live_fns, ctx.globals, "global", name)
    Memory(..) => import_used(ctx, live_fns, ctx.memories, "memory", name)
    Table(..) => import_used(ctx, live_fns, ctx.tables, "table", name)
    Tag(..) => import_used(ctx, live_fns, ctx.tags, "tag", name)
  }
}

///|
/// Report one import against one table.
///
/// A separate function only because the table's element type differs per kind
/// and a local one cannot be generic.
fn[A] import_used(
  ctx : @typing_env.ModuleContext,
  live_fns : Map[String, Unit],
  tbl : @typing_env.Tbl[A],
  kind : String,
  name : @ast.Ident,
) -> Unit {
  if !referenced(live_fns, tbl, name) {
    unused_import(ctx.diagnostics, name.loc, kind, name.name)
  }
}
