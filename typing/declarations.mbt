// The module-level declaration pass.
//
// Ported from `type_configuration` in wax/src/lib-wax/typing.ml.
//
// Every name a module binds is registered here, before any function body is
// checked. That is what makes forward references work: a function can call one
// defined below it because both were declared before either was looked at.
//
// The walk is conditional-aware. A `#[if]` field's declarations are registered
// under the branch's assumption, so two declarations of one name in mutually
// exclusive branches are not a duplicate -- see `Namespace::register`.

///|
/// Run `f` under a conditional branch's assumption, restoring the enclosing one
/// afterwards.
///
/// `positive` picks the `#[if]` branch; its negation is the `#[else]`.
pub fn[A] with_cond(
  ctx : @typing_env.ModuleContext,
  location : @basic.Location,
  cond : @wasm_types.Cond,
  positive : Bool,
  f : () -> A,
) -> A {
  let saved = ctx.cond.val
  let c = ctx.cond_env.of_cond(ctx.diagnostics, location, cond)
  ctx.cond.val = @cond.and_(saved, if positive { c } else { @cond.not_(c) })
  let r = f()
  ctx.cond.val = saved
  r
}

///|
/// Apply `f` to every module field, descending into conditionals under the
/// assumption of the branch each field appears in.
///
/// `f` therefore never sees a `Conditional`: by the time a field reaches it,
/// the assumption it was written under is already in `ctx.cond`, which is what
/// every table this pass writes to reads.
pub fn[Info] walk_fields(
  ctx : @typing_env.ModuleContext,
  fields : Array[@basic.Annotated[@ast.ModuleField[Info], @basic.Location]],
  f : (@basic.Annotated[@ast.ModuleField[Info], @basic.Location]) -> Unit,
) -> Unit {
  for field in fields {
    match field.desc {
      Conditional(cond~, then_fields~, else_fields~) => {
        with_cond(ctx, field.info, cond, true, () => {
          walk_fields(ctx, then_fields.desc, f)
        })
        if else_fields is Some(e) {
          with_cond(ctx, field.info, cond, false, () => {
            walk_fields(ctx, e.desc, f)
          })
        }
      }
      _ => f(field)
    }
  }
}

///|
/// A function type in the store's internal form, for comparing two of them.
fn internal_functype(
  ctx : @typing_env.TypeContext,
  diagnostics : @diagnostic.Context,
  ft : @ast.FuncType,
) -> @type_store.FuncType[@type_store.Id]? {
  let params : Array[@wasm_types.ValType[@type_store.Id]] = []
  for p in ft.params {
    guard internalize_valtype(ctx, diagnostics, p.desc.1) is Some(v) else {
      return None
    }
    params.push(v.internal)
  }
  let results : Array[@wasm_types.ValType[@type_store.Id]] = []
  for r in ft.results {
    guard internalize_valtype(ctx, diagnostics, r) is Some(v) else {
      return None
    }
    results.push(v.internal)
  }
  Some({ params, results })
}

///|
/// A declaration may give both a type reference and an inline signature, as in
/// `fn f: T (i32) -> i32`. When it does, they must agree.
///
/// Compared in the store's internal form, so two spellings of one type -- a
/// name and its definition -- compare equal.
pub fn check_inline_type(
  ctx : @typing_env.TypeContext,
  diagnostics : @diagnostic.Context,
  location : @basic.Location,
  referenced : @ast.FuncType,
  sign : @ast.FuncType?,
) -> Unit {
  guard sign is Some(sign) else { return }
  let a = internal_functype(ctx, diagnostics, referenced)
  let b = internal_functype(ctx, diagnostics, sign)
  // Either failing to resolve was already reported; comparing then would be a
  // second complaint about the same mistake.
  if a is Some(a) && b is Some(b) && a != b {
    inline_function_type_mismatch(diagnostics, location)
  }
}

///|
/// Resolve a function or tag declaration's type: a named reference, or an
/// inline signature that gets one minted for it.
///
/// Returns the interned index and the name to record it under. The minted
/// name is `<func:f>` -- the angle brackets are not writable, so it cannot
/// collide with anything the author declared.
fn fundecl_typ(
  ctx : @typing_env.ModuleContext,
  name : @ast.Ident,
  typ : @ast.Ident?,
  sign : @ast.FuncType?,
) -> (@type_store.Id, String)? {
  match typ {
    Some(typ) => {
      guard find(ctx.types, ctx.diagnostics, typ) is Some((idx, def)) else {
        return None
      }
      guard def.typ is Func(ft) else {
        expected_func_type(ctx.diagnostics, typ.loc)
        return None
      }
      check_inline_type(ctx.type_context, ctx.diagnostics, typ.loc, ft, sign)
      guard idx is Def(id) else { return None }
      Some((id, typ.name))
    }
    None => {
      guard sign is Some(sign) else { return None }
      let minted = "<func:" + name.name + ">"
      // `add_type` runs the function-type converter, which already checks
      // parameter-name uniqueness, so no separate pass here -- that would
      // report a duplicate twice.
      let id = add_type(ctx.type_context, ctx.diagnostics, [
        {
          desc: (
            { name: minted, loc: name.loc },
            {
              typ: Func(sign),
              supertype: None,
              final_: true,
              descriptor: None,
              describes: None,
            },
          ),
          info: name.loc,
        },
      ])
      id.map(i => (i, minted))
    }
  }
}

///|
/// Register a function, defined or imported.
///
/// A signature that fails to resolve still CLAIMS the name, as a poison entry
/// (`None`): its uses then resolve quietly to `Error` instead of cascading into
/// unbound-name reports, and the body is still checked. This is the Wax mirror
/// of the validator's poisoned index entries.
///
/// A duplicate registers nothing -- the first entry stands, and `exists` has
/// already reported the clash.
pub fn register_function(
  ctx : @typing_env.ModuleContext,
  name : @ast.Ident,
  typ : @ast.Ident?,
  sign : @ast.FuncType?,
  exact~ : Bool,
  import_~ : Bool,
) -> Unit {
  if ctx.functions.exists(ctx.diagnostics, name.name, name.loc) {
    return
  }
  // A DEFINED function's signature is a reference it makes, so the types it
  // names are attributed to it -- otherwise a dead function's type would look
  // externally referenced. An IMPORT has no body, so its signature is a
  // module-level reference and therefore a root.
  let outer = ctx.origin.val
  if !import_ && !(outer is Ignored) {
    ctx.origin.val = FromFunction(name.name)
  }
  let entry = fundecl_typ(ctx, name, typ, sign).map(r => (r.0, r.1, exact))
  ctx.origin.val = outer
  ctx.functions.add(ctx.diagnostics, name.name, name.loc, entry)
}

///|
/// Register a tag, defined or imported.
///
/// Unlike a function, a tag keeps its SOURCE function type rather than an
/// interned index: a `throw` checks its operands against the written parameter
/// types, and the diagnostic wants to name them as written.
pub fn register_tag(
  ctx : @typing_env.ModuleContext,
  name : @ast.Ident,
  typ : @ast.Ident?,
  sign : @ast.FuncType?,
) -> Unit {
  let ft = match typ {
    Some(typ) =>
      match find(ctx.types, ctx.diagnostics, typ) {
        None => None
        Some((_, def)) =>
          match def.typ {
            Func(ft) => {
              check_inline_type(
                ctx.type_context,
                ctx.diagnostics,
                typ.loc,
                ft,
                sign,
              )
              Some(ft)
            }
            _ => {
              expected_func_type(ctx.diagnostics, typ.loc)
              None
            }
          }
      }
    None =>
      match sign {
        Some(sign) => {
          check_unique_param_names(ctx.diagnostics, sign.params)
          // Interned like any other function type. A tag's signature is a type
          // the binary format refers to BY INDEX, so leaving it out of the
          // store would leave the code generator with a tag it cannot name --
          // and interning is idempotent, so a signature that matches an
          // existing type simply reuses it rather than adding one.
          intern_functype(ctx, name, sign)
          Some(sign)
        }
        None => None
      }
  }
  if ft is Some(ft) {
    ctx.tags.add(ctx.diagnostics, name.name, name.loc, ft)
  }
}

///|
/// Resolve a table's element type, for its two side effects.
///
/// The type itself is stored as written. Resolving it here means an unbound
/// type name is reported by the checker rather than only later by the lowering,
/// and a type named only as a table's element type counts as used -- as it does
/// in the validator.
fn resolve_table_reftype(
  ctx : @typing_env.ModuleContext,
  rt : @wasm_types.RefType[@ast.Ident],
) -> Unit {
  let _ = internalize_valtype(ctx.type_context, ctx.diagnostics, Ref(rt))
}

///|
/// The state one declaration pass carries: the memory index, which counts up
/// across imported and defined memories alike.
priv struct DeclareState {
  mut memory_index : Int
}

///|
/// Register an imported entity under its Wax name.
fn register_import(
  ctx : @typing_env.ModuleContext,
  state : DeclareState,
  decl : @ast.ImportDecl,
) -> Unit {
  match decl.kind {
    Func(typ~, sign~, exact~) =>
      register_function(ctx, decl.id, typ, sign, exact~, import_=true)
    Global(mut_~, typ~) =>
      if internalize_valtype(ctx.type_context, ctx.diagnostics, typ) is Some(t) {
        ctx.globals.add(
          ctx.diagnostics,
          decl.id.name,
          decl.id.loc,
          (mut_, Some(t)),
        )
      }
    Tag(typ~, sign~) => register_tag(ctx, decl.id, typ, sign)
    Memory(address_type~, ..) => {
      let i = state.memory_index
      state.memory_index += 1
      ctx.memories.add(
        ctx.diagnostics,
        decl.id.name,
        decl.id.loc,
        (i, address_type),
      )
    }
    Table(address_type~, reftype~, ..) => {
      resolve_table_reftype(ctx, reftype)
      ctx.tables.add(
        ctx.diagnostics,
        decl.id.name,
        decl.id.loc,
        (address_type, reftype),
      )
    }
  }
}

///|
/// Register every name a module binds, before any body is checked.
///
/// Types go first and separately: a function's declared type has to resolve
/// while the function is being registered, so every type in the module must
/// already be in the store -- including one declared after the function that
/// names it.
pub fn[Info] declare_fields(
  ctx : @typing_env.ModuleContext,
  fields : Array[@basic.Annotated[@ast.ModuleField[Info], @basic.Location]],
) -> Unit {
  walk_fields(ctx, fields, field => {
    if field.desc is Type(group) {
      let _ = add_type(ctx.type_context, ctx.diagnostics, group)
    }
  })
  // The canonical byte array a string literal builds. Registered AFTER the
  // source types, so a user type with the same shape is what it dedups ONTO
  // rather than the other way round -- which is how a string literal comes to
  // count as a use of that user type.
  index_structs_by_fields(ctx)
  let state = { memory_index: 0 }
  walk_fields(ctx, fields, field => {
    match field.desc {
      Memory(name~, address_type~, data~, ..) => {
        let i = state.memory_index
        state.memory_index += 1
        ctx.memories.add(
          ctx.diagnostics,
          name.name,
          name.loc,
          (i, address_type),
        )
        // An inline data segment may be named, and that name lives in the data
        // segment space like any other.
        for d in data {
          if d.data_name is Some(n) {
            ctx.datas.add(ctx.diagnostics, n.name, n.loc, ())
          }
        }
      }
      Import(decl~, ..) => register_import(ctx, state, decl.desc)
      ImportGroup(decls~, ..) =>
        for d in decls {
          register_import(ctx, state, d.desc)
        }
      Func(name~, typ~, sign~, ..) =>
        // A module-defined function has exactly its declared type, so a reference
        // to it is exact -- but exact reference types are part of
        // custom-descriptors. Without the proposal it is the plain inexact
        // reference, as before it existed.
        register_function(
          ctx,
          name,
          typ,
          sign,
          exact=ctx.type_context.features.is_enabled(CustomDescriptors),
          import_=false,
        )
      Tag(name~, typ~, sign~, ..) => register_tag(ctx, name, typ, sign)
      Data(name~, ..) =>
        if name is Some(n) {
          ctx.datas.add(ctx.diagnostics, n.name, n.loc, ())
        }
      Table(name~, address_type~, reftype~, ..) => {
        resolve_table_reftype(ctx, reftype)
        ctx.tables.add(
          ctx.diagnostics,
          name.name,
          name.loc,
          (address_type, reftype),
        )
      }
      Elem(name~, reftype~, ..) =>
        ctx.elems.add(ctx.diagnostics, name.name, name.loc, reftype)
      // Globals are registered as they are checked, in order, so an initializer
      // sees the globals declared before it and not those after.
      Conditional(..) | Type(_) | Global(..) | ModuleAnnotation(_) => ()
    }
  })
}

///|
/// A canonical key for a set of field names, so two structs with the same
/// fields in any order get the same key.
///
/// Identifiers never contain a comma, so joining on one cannot make two
/// different sets collide.
pub fn field_set_key(names : Array[String]) -> String {
  let sorted = names.copy()
  sorted.sort()
  let out : Array[String] = []
  for n in sorted {
    if out.is_empty() || out[out.length() - 1] != n {
      out.push(n)
    }
  }
  out.join(",")
}

///|
/// Index the struct types by their field set, so a literal that omits the type
/// name can be resolved from its fields alone.
///
/// Every type is registered before this runs, so the index is complete. A key
/// shared by two DIFFERENT names is marked ambiguous (`None`) and such a
/// literal must name its type; the same name appearing twice under different
/// conditional branches is one type, not two, and does not.
pub fn index_structs_by_fields(ctx : @typing_env.ModuleContext) -> Unit {
  for entry in ctx.types.iter_entries() {
    let (name, (_, st)) = entry
    guard st.typ is Struct(fields) else { continue }
    let key = field_set_key(fields.map(f => f.desc.0.name))
    match ctx.structs_by_fields.get(key) {
      None => ctx.structs_by_fields[key] = Some({ name, loc: @basic.dummy_loc })
      Some(Some(n)) => if n.name != name { ctx.structs_by_fields[key] = None }
      Some(None) => ()
    }
  }
}

///|
/// The type name a string literal builds by default: a mutable byte array.
///
/// Unwritable, so it cannot collide with a source name; canonical, so a user
/// type declared as `array(mut i8)` interns to the same index and a string
/// literal is a genuine use of it.
pub let string_type_name : String = "<string>"

///|
/// Whether any instruction in the module is a string literal.
///
/// The canonical byte array is registered only when something builds one. An
/// unconditional registration would put a type in the store that nothing names,
/// and the store IS the type section -- so the module would carry a type it
/// never uses and every index after it would shift.
pub fn[Info] uses_string_literal(fields : @ast.Module[Info]) -> Bool {
  let mut found = false
  fn scan(instrs : Array[@ast.Instr[Info]]) -> Unit {
    for i in instrs {
      i.iter_instr(node => if node.desc is Str(_, _) { found = true })
    }
  }

  fn walk(
    fs : Array[@basic.Annotated[@ast.ModuleField[Info], @basic.Location]],
  ) -> Unit {
    for f in fs {
      match f.desc {
        Func(body~, ..) => scan(body.1)
        Global(def~, ..) => scan([def])
        Table(init~, ..) => if init is Some(e) { scan([e]) }
        Elem(init~, ..) => scan(init)
        Memory(data~, ..) =>
          for d in data {
            scan([d.offset])
          }
        Data(mode~, ..) => if mode is Active(_, off) { scan([off]) }
        Conditional(then_fields~, else_fields~, ..) => {
          walk(then_fields.desc)
          if else_fields is Some(e) {
            walk(e.desc)
          }
        }
        _ => ()
      }
    }
  }

  walk(fields)
  found
}

///|
/// Intern an inline function signature, so it has an index to be named by.
///
/// The generated name is unwritable, so it collides with nothing; what matters
/// is the TYPE it interns to, which a structurally identical declaration
/// elsewhere shares.
pub fn intern_functype(
  ctx : @typing_env.ModuleContext,
  owner : @ast.Ident,
  sign : @ast.FuncType,
) -> Unit {
  // Named after the declaration that needed it. A store index would not do:
  // two signatures that intern to the SAME existing type leave the index
  // unmoved, and the second would collide with the first.
  let name : @ast.Ident = {
    name: "<functype:" + owner.name + ">",
    loc: @basic.dummy_loc,
  }
  let _ = add_type(ctx.type_context, ctx.diagnostics, [
    {
      desc: (
        name,
        {
          typ: Func(sign),
          supertype: None,
          final_: true,
          descriptor: None,
          describes: None,
        },
      ),
      info: @basic.dummy_loc,
    },
  ])
}

///|
/// Register the canonical `mut i8` array that a bare string literal builds.
pub fn register_string_type(ctx : @typing_env.ModuleContext) -> Unit {
  // Once per module. Called on demand, from every nameless literal, so without
  // this the second one would report the name as already bound -- which is a
  // true statement about a declaration nobody wrote.
  guard ctx.type_context.types.find_no_mark(string_type_name) is None else {
    return
  }
  let name : @ast.Ident = { name: string_type_name, loc: @basic.dummy_loc }
  let _ = add_type(ctx.type_context, ctx.diagnostics, [
    {
      desc: (
        name,
        {
          typ: Array({ mut_: true, typ: Packed(I8) }),
          supertype: None,
          final_: true,
          descriptor: None,
          describes: None,
        },
      ),
      info: @basic.dummy_loc,
    },
  ])
}
