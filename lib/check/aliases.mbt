// Value-type aliases, `type t = v;`.
//
// Ported from the alias handling in wax/src/lib-wax/typing.ml.
//
// An alias is resolved LAZILY, at each use, as if its definition were written
// there: a configuration resolves it to whatever it stands for in that
// configuration. So the errors resolution meets are reported at the use, and
// only the errors that make the definition wrong everywhere -- a cycle, a name
// no type bears -- are reported once, at the definition, which is then
// poisoned and stands for no value type.

///|
/// The definition an alias use refers to, or `None` for a name that is no
/// alias, reported here, or a poisoned alias, reported at its definition.
fn alias_definition(
  ctx : @typing_env.TypeContext,
  diagnostics : @diagnostic.Context,
  a : @ast.Ident,
) -> @typing_env.AliasDef? {
  match ctx.aliases.resolve(a.name, a.loc) {
    Some(al) if al.poisoned => None
    Some(al) => {
      al.used = true
      Some(al)
    }
    None => {
      let candidates = ["i32", "i64", "f32", "f64", "v128"]
      for n in ctx.aliases.names() {
        candidates.push(n)
      }
      unknown_value_type(
        diagnostics,
        a.loc,
        a.name,
        suggestions=@spell.suggest(candidates.iter(), a.name),
        is_type=ctx.types.find_no_mark(a.name) is Some(_),
      )
      None
    }
  }
}

///|
/// Resolve an alias use with `resolve`, reporting an error it meets at the use:
/// the definition is fine (see `check_alias_definitions`), but not where it is
/// used -- as a reference type naming a type defined after the use, say.
fn[T] resolve_alias(
  diagnostics : @diagnostic.Context,
  a : @ast.Ident,
  al : @typing_env.AliasDef,
  resolve : (@diagnostic.Context, @wasm_types.ValType[@ast.Ident]) -> T?,
) -> T? {
  let c = @diagnostic.collector(parent=Some(diagnostics))
  let r = resolve(c, al.typ)
  for e in c.collected() {
    diagnostics.replay(e, loc=Some(a.loc), related=[
      { loc: e.loc, message: @message.text("in the type alias definition"), },
    ])
  }
  r
}

///|
/// `st` with every alias use replaced by the value type it stands for, so a
/// type definition read back from the type table never carries an alias.
fn unalias_subtype(
  ctx : @typing_env.TypeContext,
  st : @ast.SubType,
) -> @ast.SubType {
  fn storage(
    t : @wasm_types.StorageType[@ast.Ident],
  ) -> @wasm_types.StorageType[@ast.Ident] {
    match t {
      Value(v) => Value(ctx.unalias(v))
      Packed(_) => t
    }
  }

  let typ : @ast.CompType = match st.typ {
    Func(ft) =>
      Func({
        params: ft.params.map(p => {
          ..p,
          desc: (p.desc.0, ctx.unalias(p.desc.1)),
        }),
        results: ft.results.map(r => ctx.unalias(r)),
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

///|
/// Register a value-type alias definition.
///
/// Aliases are registered before the types, which may use them, so a name a
/// type of `type_names` also bears is reported here, at the alias, which is
/// then not registered.
fn add_alias(
  ctx : @typing_env.TypeContext,
  diagnostics : @diagnostic.Context,
  type_names : Map[String, @basic.Location],
  conditional~ : Bool,
  name : @ast.Ident,
  typ : @wasm_types.ValType[@ast.Ident],
) -> Unit {
  if reserved_type_names.contains(name.name) {
    reserved_type_name(diagnostics, name.loc, name.name)
  }
  match type_names.get(name.name) {
    Some(prev_loc) =>
      name_already_bound(diagnostics, name.loc, prev_loc, "type", name.name)
    None =>
      ctx.aliases.add(
        diagnostics,
        name.name,
        name.loc,
        @typing_env.AliasDef::new(name, typ, conditional~),
      )
  }
}

///|
/// Report each alias whose definition names no type of `type_names`, or leads
/// back to itself: it is in error wherever it is used, so it is reported once,
/// here, and stands for no value type.
fn check_alias_definitions(
  ctx : @typing_env.TypeContext,
  diagnostics : @diagnostic.Context,
  type_names : Map[String, @basic.Location],
) -> Unit {
  let all : Array[@typing_env.AliasDef] = []
  for entry in ctx.aliases.iter_entries() {
    all.push(entry.1)
  }
  all.sort_by((a, b) => a.name.loc.start.cnum - b.name.loc.start.cnum)
  for al in all {
    match al.typ {
      Ref({ typ: Type(x) | Exact(x), .. }) if !type_names.contains(x.name) => {
        unbound_name(
          diagnostics,
          x.loc,
          "type",
          x.name,
          suggestions=@spell.suggest(type_names.keys(), x.name),
        )
        al.poisoned = true
      }
      _ => ()
    }
  }
  fn leads_back(
    name : String,
    seen : Array[String],
    ty : @wasm_types.ValType[@ast.Ident],
  ) -> Bool {
    guard ty is Alias(a) else { return false }
    if a.name == name {
      return true
    }
    if seen.contains(a.name) {
      return false
    }
    match ctx.aliases.find_no_mark(a.name) {
      Some(al) => leads_back(name, [..seen, a.name], al.typ)
      None => false
    }
  }

  let cyclic = all.filter(al => leads_back(al.name.name, [], al.typ))
  for al in cyclic {
    cyclic_alias(diagnostics, al.name.loc, al.name.name)
    al.poisoned = true
  }
  // An alias defined as a conditional one is conditional too, wherever it is
  // defined: it stands for whatever that one does.
  fn reaches_conditional(
    seen : Array[String],
    ty : @wasm_types.ValType[@ast.Ident],
  ) -> Bool {
    guard ty is Alias(a) else { return false }
    if seen.contains(a.name) {
      return false
    }
    match ctx.aliases.find_no_mark(a.name) {
      Some(al) =>
        al.conditional || reaches_conditional([..seen, a.name], al.typ)
      None => false
    }
  }

  let promoted = all.filter(al => {
    !al.conditional && reaches_conditional([al.name.name], al.typ)
  })
  for al in promoted {
    al.conditional = true
  }
}

///|
/// Check the alias definitions no use resolved, in source order, reporting
/// their errors at the definition. A reference they make is no use of what it
/// names.
fn check_unused_aliases(
  ctx : @typing_env.TypeContext,
  diagnostics : @diagnostic.Context,
) -> Unit {
  let unused : Array[@typing_env.AliasDef] = []
  for entry in ctx.aliases.iter_entries() {
    let al = entry.1
    if !(al.used || al.poisoned) {
      unused.push(al)
    }
  }
  unused.sort_by((a, b) => a.name.loc.start.cnum - b.name.loc.start.cnum)
  let saved = ctx.aliases.current.val
  ctx.aliases.current.val = Ignored
  for al in unused {
    ignore(valtype(ctx, diagnostics, al.typ))
  }
  ctx.aliases.current.val = saved
}

///|
/// Register the module's aliases, then check their definitions: before any
/// type, since a type definition may use one.
fn[Info] declare_aliases(
  ctx : @typing_env.ModuleContext,
  fields : Array[@basic.Annotated[@ast.ModuleField[Info], @basic.Location]],
) -> Unit {
  let tc = ctx.type_context
  let type_names : Map[String, @basic.Location] = Map([])
  walk_fields(ctx, fields, field => {
    if field.desc is Type(group) {
      for elt in group {
        let name = elt.desc.0
        if !type_names.contains(name.name) {
          type_names[name.name] = name.loc
        }
      }
    }
  })
  walk_fields(ctx, fields, field => {
    if field.desc is TypeAlias(name~, typ~) {
      add_alias(
        tc,
        ctx.diagnostics,
        type_names,
        conditional=!@cond.equal(ctx.cond.val, @cond.true_) ||
          ctx.conditional_alias_names.contains(name.name),
        name,
        typ,
      )
    }
  })
  check_alias_definitions(tc, ctx.diagnostics, type_names)
}

///|
/// A type definition as it was written, aliases included, for a reader that
/// only internalizes the value types in it: an alias kept there is carried by
/// the values read through it (see `InferredValType::alias`). `def` is the
/// definition the name has under the current assumption; the written form is
/// used only when it is that same definition, since `written` is keyed by name
/// alone.
fn as_written(
  ctx : @typing_env.TypeContext,
  name : String,
  def : @ast.SubType,
) -> @ast.SubType {
  ctx.written_form(name, def)
}

///|
/// Whether the alias `a` is defined under a conditional annotation: it may then
/// stand for a reference in one configuration and a number in another, and a
/// construct of its type lowers to a form that holds in every configuration.
fn conditional_alias(ctx : @typing_env.ModuleContext, a : @ast.Ident) -> Bool {
  match ctx.type_context.aliases.find_no_mark(a.name) {
    Some(al) => al.conditional
    None => false
  }
}

///|
/// A select of a conditional alias's type is ascribed it, so that it lowers to
/// a `select` of that type: a reference in one configuration may be a number
/// in another.
fn ascribe_conditional_select(
  ctx : @typing_env.ModuleContext,
  sel : @ast.Instr[@typing_env.InferredAnnotation],
) -> @ast.Instr[@typing_env.InferredAnnotation] {
  guard sel.info.0 is [ty] else { return sel }
  match ty.get() {
    Valtype({ type_alias: Some(a), .. }) if !(ctx.simplify || ctx.faithful) &&
      conditional_alias(ctx, a) =>
      { ..sel, desc: Cast(sel, Ascribed(Alias(a))), }
    _ => sel
  }
}
