// Registering a written type definition.
//
// Ported from wax/src/lib-wax/typing.ml.
//
// A `type` declaration -- or a `rec` group of them -- goes in here as names and
// comes out as an interned store index. The order of operations is what makes a
// group of mutually recursive types possible at all:
//
//   1. Every member's NAME is registered first, with a placeholder index, so a
//      member can refer to any other -- including one written after it.
//   2. `..` splices are expanded, which needs step 1 (the supertype resolves).
//   3. The group is resolved and interned, which yields the real indices.
//   4. The placeholders are replaced by the real ones.
//
// If step 3 fails the names are taken back out, so nothing resolves to a type
// that was never interned.

///|
/// The built-in type names a declaration may not take.
///
/// `T::` extends to declared types, making the `::` left-hand side one
/// namespace shared by the intrinsics and user types -- so the built-ins have
/// to stay unambiguous. `&i64` is the value type and `atomic::fence` the
/// intrinsic, and neither can be shadowed. These are the value types, the
/// abstract heap types, and the `atomic` intrinsic namespace; `cont` is a
/// keyword and so cannot be written as a name at all.
let reserved_type_names : Array[String] = [
  "i32", "i64", "f32", "f64", "v128", "any", "array", "eq", "exn", "extern", "func",
  "i31", "nocont", "noexn", "noextern", "nofunc", "none", "struct", "atomic",
]

///|
/// Whether a reference is to a type already defined when member `current` of
/// the group is reached: any `Def`, or a `Rec` member strictly before it.
fn defined_before(current : Int, r : @type_store.RefIndex) -> Bool {
  match r {
    Def(_) => true
    Rec(pos) => pos < current
  }
}

///|
/// Resolve one member of a rec group, `current` being its position in it.
///
/// The supertype restriction is the interesting part. A supertype must be
/// declared BEFORE -- a self or forward reference inside the group is treated
/// as unbound, as the validator does. The offending supertype is then dropped
/// rather than kept, so the subtype chain stays acyclic and every later
/// subtyping query terminates; keeping it would turn a reported error into a
/// hang.
///
/// `descriptor` and `describes` carry no such restriction: they refer mutually
/// within the group by design, which is the whole shape of a descriptor pair.
fn n_subtype(
  ctx : @typing_env.TypeContext,
  diagnostics : @diagnostic.Context,
  current : Int,
  st : @ast.SubType,
) -> @type_store.SubType[@type_store.RefIndex]? {
  guard comptype(ctx, diagnostics, st.typ) is Some(typ) else { return None }
  let supertype = match st.supertype {
    None => None
    Some(sup) =>
      match resolve_type_ref(ctx, diagnostics, sup) {
        None => return None
        Some(r) =>
          if defined_before(current, r) {
            Some(r)
          } else {
            unbound_name(diagnostics, sup.loc, "type", sup.name)
            None
          }
      }
  }
  fn clause(idx : @ast.Ident?) -> @type_store.RefIndex?? {
    match idx {
      None => Some(None)
      Some(idx) => {
        require_feature(ctx, diagnostics, idx.loc, CustomDescriptors)
        match resolve_type_ref(ctx, diagnostics, idx) {
          None => None
          Some(r) => Some(Some(r))
        }
      }
    }
  }

  guard clause(st.descriptor) is Some(descriptor) else { return None }
  guard clause(st.describes) is Some(describes) else { return None }
  Some({ final_: st.final_, supertype, descriptor, describes, typ })
}

///|
/// Resolve every member of a rec group.
///
/// Each member's components -- its supertype, its field and element types, a
/// descriptor clause -- are references made BY THAT MEMBER, so they keep their
/// targets alive only if the member itself is kept alive. A rec group nothing
/// names is dead as a whole, cycle and all, which is what stops two types that
/// only name each other from propping one another up.
fn n_rectype(
  ctx : @typing_env.TypeContext,
  diagnostics : @diagnostic.Context,
  group : Array[@basic.Annotated[(@ast.Ident, @ast.SubType), @basic.Location]],
) -> @type_store.RecType[@type_store.RefIndex]? {
  let outer = ctx.types.current.val
  let out : Array[@type_store.SubType[@type_store.RefIndex]] = []
  let mut failed = false
  for i, elt in group {
    if !(outer is Ignored) {
      ctx.types.current.val = FromType(elt.desc.0.name)
    }
    // Every member is resolved even after one fails, so a group with two bad
    // members reports both rather than only the first.
    match n_subtype(ctx, diagnostics, i, elt.desc.1) {
      Some(s) => out.push(s)
      None => failed = true
    }
  }
  ctx.types.current.val = outer
  if failed {
    None
  } else {
    Some(out)
  }
}

///|
/// Replace a leading `..` splice in each struct of the group with the
/// supertype's fields.
///
/// Runs after the group's names are registered, so an in-group supertype
/// resolves, and in source order, so an earlier member is already expanded when
/// a later one inherits from it.
///
/// Returns a fresh array: the parsed AST keeps its sentinel, because the
/// formatter and the decompiler have to write back what was written, while the
/// interned type and the name table get the expanded fields.
fn expand_splices(
  ctx : @typing_env.TypeContext,
  diagnostics : @diagnostic.Context,
  group : Array[@basic.Annotated[(@ast.Ident, @ast.SubType), @basic.Location]],
) -> Array[@basic.Annotated[(@ast.Ident, @ast.SubType), @basic.Location]] {
  let expanded = group.copy()
  for i, elt in group {
    let (name, sub) = elt.desc
    guard sub.typ is Struct(fields) else { continue }
    guard fields.length() > 0 && @ast.is_splice_field(fields[0]) else {
      continue
    }
    let delta = fields[1:].to_owned()
    let parent_fields = match sub.supertype {
      None => {
        splice_without_supertype(diagnostics, fields[0].info)
        None
      }
      Some(sup) => {
        // Consulting the supertype for its fields IS a use of it, recorded
        // separately from the lookup -- which is deliberately non-reporting,
        // since an unbound supertype is reported by `n_subtype` and saying it
        // twice would be a second complaint about one mistake.
        ctx.types.mark_reference(sup.name, ctx.types.current.val)
        match ctx.types.find_no_mark(sup.name) {
          None => None
          Some((idx, parent)) => {
            // An in-group member is a `Rec`, and takes its already-expanded
            // form. A self or forward reference is reported as unbound by
            // `n_subtype`, so it is skipped rather than reported here.
            let parent = match idx {
              Rec(j) => if j < i { Some(expanded[j].desc.1) } else { None }
              Def(_) => Some(parent)
            }
            match parent {
              Some({ typ: Struct(pf), .. }) => Some(pf)
              Some(_) => {
                splice_non_struct(diagnostics, sup.loc, sup.name)
                None
              }
              None => None
            }
          }
        }
      }
    }
    let fields_ = match parent_fields {
      Some(pf) => {
        let all = pf.copy()
        for f in delta {
          all.push(f)
        }
        all
      }
      // Without a supertype to inherit from, the splice contributes nothing and
      // the member keeps only its own fields. Reported above; recovering with
      // the written fields keeps the rest of the definition checkable.
      None => delta
    }
    expanded[i] = { ..elt, desc: (name, { ..sub, typ: Struct(fields_) }) }
  }
  expanded
}

///|
/// Register a rec group: its names, its interned types, and the link between
/// them.
///
/// Returns the index of the group's first member, or `None` if it did not
/// resolve.
///
/// The two-step name registration is what makes a mutually recursive group
/// possible. Every member is bound to a `Rec` placeholder before anything is
/// resolved, so a member written first can name one written last; only once the
/// group is interned are those placeholders replaced by real indices. A group
/// that fails to resolve has its names withdrawn, so nothing is left pointing
/// at a type that was never interned.
pub fn add_type(
  ctx : @typing_env.TypeContext,
  diagnostics : @diagnostic.Context,
  group : Array[@basic.Annotated[(@ast.Ident, @ast.SubType), @basic.Location]],
) -> @type_store.Id? {
  for i, elt in group {
    let name = elt.desc.0
    if reserved_type_names.contains(name.name) {
      reserved_type_name(diagnostics, name.loc, name.name)
    }
    ctx.types.add(diagnostics, name.name, name.loc, (Rec(i), elt.desc.1))
  }
  // Expanded before the group is resolved AND before the override below, so
  // both see the supertype's fields rather than the `..` sentinel.
  let group = expand_splices(ctx, diagnostics, group)
  guard n_rectype(ctx, diagnostics, group) is Some(resolved) else {
    for elt in group {
      ctx.types.remove(elt.desc.0.name)
    }
    return None
  }
  check_descriptors(diagnostics, group, resolved)
  // A malformed group means a reference escaped it -- a bug in normalization
  // rather than in the source -- so it withdraws the names like any other
  // failure rather than taking the run down.
  let id = try ctx.store.add_rectype(resolved) catch {
    _ => {
      for elt in group {
        ctx.types.remove(elt.desc.0.name)
      }
      return None
    }
  } noraise {
    id => id
  }
  // The type space grew, so any memoised subtyping info is stale.
  ctx.invalidate()
  for i, elt in group {
    let (name, typ) = elt.desc
    // Normalization drops a supertype the spec forbids -- a forward or self
    // reference, which is not "declared before". Drop it from the SOURCE type
    // stored here too, or the source-level walkers would follow the cyclic edge
    // and loop. The error was already reported.
    let typ = if resolved[i].supertype is None {
      { ..typ, supertype: None }
    } else {
      typ
    }
    ctx.types.override_(name.name, (Def(id.add(i)), typ))
  }
  Some(id)
}

///|
/// Well-formedness of the `descriptor` / `describes` clauses.
///
/// They must link two struct types WITHIN one recursion group, and must do so
/// reciprocally: if `$a` names `$b` as its descriptor, `$b` must name `$a` as
/// what it describes. In the resolved group a `Rec` names a member of this
/// group and a `Def` denotes a type outside it, which is what makes "in the
/// same group" a question about the index's constructor.
fn check_descriptors(
  diagnostics : @diagnostic.Context,
  group : Array[@basic.Annotated[(@ast.Ident, @ast.SubType), @basic.Location]],
  resolved : @type_store.RecType[@type_store.RefIndex],
) -> Unit {
  for i, sub in resolved {
    let location = group[i].info
    match sub.descriptor {
      None => ()
      Some(Def(_)) =>
        descriptor_outside_rec_group(diagnostics, location, described=false)
      Some(Rec(pos)) =>
        if !(resolved[pos].describes is Some(Rec(o)) && o == i) {
          descriptor_not_reciprocal(diagnostics, location, described=false)
        }
    }
    match sub.describes {
      None => ()
      Some(Def(_)) =>
        descriptor_outside_rec_group(diagnostics, location, described=true)
      Some(Rec(pos)) => {
        // A descriptor comes after what it describes, so that reading the group
        // in order never meets a descriptor before its subject.
        if pos >= i {
          forward_use_of_described(diagnostics, location)
        }
        if !(resolved[pos].descriptor is Some(Rec(dd)) && dd == i) {
          descriptor_not_reciprocal(diagnostics, location, described=true)
        }
      }
    }
    if (sub.descriptor is Some(_) || sub.describes is Some(_)) &&
      !(sub.typ is Struct(_)) {
      descriptor_not_struct(
        diagnostics,
        location,
        described=sub.describes is Some(_),
      )
    }
  }
}

///|
/// Check every declared type against the supertype it names.
///
/// This runs over the finished type table rather than at each declaration,
/// because a rec group's members may name each other: `a: b` can be written
/// before `b` exists, and the answer only settles once the whole group is
/// interned. Everything here is about the RELATIONSHIP between a type and its
/// supertype, so the supertype reference is where each report goes -- that is
/// what the author has to change.
fn check_type_definitions(ctx : @typing_env.ModuleContext) -> Unit {
  let info = ctx.type_context.subtyping_info()
  for entry in ctx.type_context.types.iter_entries() {
    let (idx, st) = entry.1
    // A rec-group back-reference has no store index of its own yet; the member
    // it stands for is visited under its own name.
    guard idx is Def(id) else { continue }
    let ty = info.get_subtype(id)
    // A continuation type wraps a FUNCTION type and nothing else. Pointed at
    // the wrapped type as the source wrote it, not at the continuation.
    if ty.typ is Cont(ft) && st.typ is Cont(src) {
      if !(info.get_subtype(ft).typ is Func(_)) {
        expected_func_type(ctx.diagnostics, src.loc)
      }
    }
    guard ty.supertype is Some(j) else { continue }
    guard st.supertype is Some(sup) else { continue }
    let sup_ty = info.get_subtype(j)
    if sup_ty.final_ {
      final_supertype(ctx.diagnostics, sup.loc, sup.name)
      continue
    }
    // A descriptor is inherited, so a subtype of a described type is described
    // too -- by a subtype of the same descriptor. It may ADD one its supertype
    // lacks, since nothing was promised about it. Being a descriptor, on the
    // other hand, is all or nothing: the two must describe types standing in
    // the same relation they do.
    let descriptor_ok = match sup_ty.descriptor {
      None => true
      Some(dp) =>
        match ty.descriptor {
          Some(ds) => @type_store.heap_subtype(info, Type(ds), Type(dp))
          None => false
        }
    }
    let describes_ok = match (ty.describes, sup_ty.describes) {
      (None, None) => true
      (Some(os), Some(op)) => @type_store.heap_subtype(info, Type(os), Type(op))
      _ => false
    }
    if !(structurally_extends(info, ty.typ, sup_ty.typ) &&
      descriptor_ok &&
      describes_ok) {
      invalid_subtype(ctx.diagnostics, sup.loc, sup.name)
    }
  }
}

///|
/// Whether one composite type stands where another does.
///
/// A struct may ADD fields but never change one; an array's element is a field
/// like any other; and a function's PARAMETERS go the other way round from its
/// results, since it is the caller who supplies them and the function that
/// hands them back. Two composites of different kinds never relate.
fn structurally_extends(
  info : @type_store.SubtypingInfo,
  ty : @type_store.CompType[@type_store.Id],
  sup : @type_store.CompType[@type_store.Id],
) -> Bool {
  match (ty, sup) {
    (Func(a), Func(b)) => {
      guard a.params.length() == b.params.length() &&
        a.results.length() == b.results.length() else {
        return false
      }
      for k, p in a.params {
        if !@type_store.val_subtype(info, b.params[k], p) {
          return false
        }
      }
      for k, r in a.results {
        if !@type_store.val_subtype(info, r, b.results[k]) {
          return false
        }
      }
      true
    }
    (Struct(fs), Struct(gs)) => {
      guard gs.length() <= fs.length() else { return false }
      for k, g in gs {
        if !field_subtype(info, fs[k], g) {
          return false
        }
      }
      true
    }
    (Array(f), Array(g)) => field_subtype(info, f, g)
    (Cont(a), Cont(b)) => @type_store.heap_subtype(info, Type(a), Type(b))
    _ => false
  }
}
