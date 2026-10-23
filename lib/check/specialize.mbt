// Resolving a module's conditionals against one configuration.
//
// Ported from `specialize_fields` in wax/src/lib-wax/typing.ml.
//
// A module with `#[if]` in it is not one program but a family of them, and
// type-checking it in place would ask questions no single answer fits: whether
// a value is left on the stack depends on which branch is compiled. So each
// reachable configuration is SPECIALIZED -- every conditional resolved, the
// selected branch spliced into the enclosing list -- and checked on its own.
//
// The assumption threads left to right through siblings, so once one
// conditional forces `$wasi` a later `#[if(not wasi)]` has its then-branch
// pruned rather than explored.

///|
/// What a specializer needs to resolve one conditional, gathered so the
/// recursive walk below can pass it around as one thing.
priv struct Configuring {
  env : @cond.Env
  diagnostics : @diagnostic.Context
  /// Takes the complementary assumption of an undecided conditional -- the
  /// configuration this one does not cover.
  enqueue : (@cond.T) -> Unit
  /// Accumulates the literals this configuration commits to, so the explorer
  /// knows the full assumption every diagnostic was produced under.
  record : (@cond.T) -> Unit
}

///|
/// Resolve one conditional: the selected branch, and the assumption that holds
/// after it.
///
/// A branch is taken only if it is REACHABLE -- its conjunction with the
/// current assumption is satisfiable -- so an infeasible configuration is never
/// explored. When neither branch is forced, this one takes the `then` and hands
/// the `else` configuration back to the explorer.
fn[A] Configuring::choose(
  self : Configuring,
  under : @cond.T,
  cond : @wasm_types.Cond,
  location : @basic.Location,
  then_branch : (@cond.T) -> A,
  else_branch : (@cond.T) -> A,
) -> (A, @cond.T) {
  let c = self.env.of_cond(self.diagnostics, location, cond)
  let then_under = @cond.and_(under, c)
  let else_under = @cond.and_(under, @cond.not_(c))
  if !@cond.is_satisfiable(then_under) {
    (self.record)(@cond.not_(c))
    (else_branch(else_under), else_under)
  } else if !@cond.is_satisfiable(else_under) {
    (self.record)(c)
    (then_branch(then_under), then_under)
  } else {
    (self.enqueue)(else_under)
    (self.record)(c)
    (then_branch(then_under), then_under)
  }
}

///|
/// Decide every attribute guard.
///
/// A guard gates the presence of just this attribute, so it partitions the
/// space exactly as an `#[if]` block does -- the configurations are explored
/// on it. The attribute itself is KEPT in every one: the reference checks an
/// attribute whatever its guard selects, so what is wrong with one (a guard
/// where none is allowed, a value of the wrong shape) is wrong in every
/// configuration rather than only where it is present.
///
/// An `export` or `start`, where a guard means something, says in each
/// configuration whether it is there: present, it loses its guard; absent, it
/// keeps one that never holds, so that it clashes with nothing.
fn Configuring::attrs(
  self : Configuring,
  under : @cond.T,
  attrs : @ast.Attributes,
) -> (@ast.Attributes, @cond.T) {
  let out : @ast.Attributes = []
  let mut under = under
  for a in attrs {
    match a.attr_guard {
      None => out.push(a)
      Some(g) => {
        let (kept, next) = self.choose(
          under,
          g.desc,
          g.info,
          _ => { ..a, attr_guard: None, },
          _ => { ..a, attr_guard: Some({ ..g, desc: Or([]), }), },
        )
        out.push(
          if a.attr_name == "export" || a.attr_name == "start" {
            kept
          } else {
            a
          },
        )
        under = next
      }
    }
  }
  (out, under)
}

///|
/// A statement-position `#[if]` is spliced away, so one instruction in can be
/// any number out.
fn Configuring::instr(
  self : Configuring,
  under : @cond.T,
  i : @ast.Instr[@basic.Location],
) -> (Array[@ast.Instr[@basic.Location]], @cond.T) {
  match i.desc {
    // The conditional is still a STATEMENT of the configuration, whichever
    // branch it selects -- an absent one included -- so it is kept as a
    // no-op at its own span ahead of the branch spliced in. That is where
    // code after a divergence is found dead: at the conditional, not at
    // whatever follows it.
    IfAnnotation(cond~, then_body~, else_body~) => {
      let marker = { ..i, desc: Nop, }
      let (branch, next) = self.choose(
        under,
        cond,
        i.info,
        u => self.instrs(u, then_body.desc),
        u => {
          match else_body {
            Some(e) => self.instrs(u, e.desc)
            None => []
          }
        },
      )
      ([marker, ..branch], next)
    }
    desc =>
      (
        [
          {
            ..i,
            desc: desc.map_desc(instr=x => self.one(under, x), block=l => {
              self.instrs(under, l)
            }),
          },
        ],
        under,
      )
  }
}

///|
/// A list of statements, with the assumption threading through them.
fn Configuring::instrs(
  self : Configuring,
  under : @cond.T,
  l : Array[@ast.Instr[@basic.Location]],
) -> Array[@ast.Instr[@basic.Location]] {
  let out : Array[@ast.Instr[@basic.Location]] = []
  let mut under = under
  for i in l {
    let (got, next) = self.instr(under, i)
    for g in got {
      out.push(g)
    }
    under = next
  }
  out
}

///|
/// A single-instruction position, where a conditional cannot appear -- it is
/// statement-only, so exactly one instruction comes back.
fn Configuring::one(
  self : Configuring,
  under : @cond.T,
  i : @ast.Instr[@basic.Location],
) -> @ast.Instr[@basic.Location] {
  match self.instr(under, i).0 {
    [x] => x
    _ => i
  }
}

///|
fn Configuring::decl(
  self : Configuring,
  under : @cond.T,
  d : @basic.Annotated[@ast.ImportDecl, @basic.Location],
) -> (@basic.Annotated[@ast.ImportDecl, @basic.Location], @cond.T) {
  let (attributes, under) = self.attrs(under, d.desc.attributes)
  ({ ..d, desc: { ..d.desc, attributes, }, }, under)
}

///|
/// One module field, which a conditional group turns into any number.
fn Configuring::field(
  self : Configuring,
  under : @cond.T,
  f : @basic.Annotated[@ast.ModuleField[@basic.Location], @basic.Location],
) -> (
  Array[@basic.Annotated[@ast.ModuleField[@basic.Location], @basic.Location]],
  @cond.T,
) {
  match f.desc {
    Conditional(cond~, then_fields~, else_fields~) =>
      self.choose(under, cond, f.info, u => self.fields(u, then_fields.desc), u => {
        match else_fields {
          Some(e) => self.fields(u, e.desc)
          None => []
        }
      })
    Func(name~, typ~, sign~, body~, attributes~) => {
      let (attributes, under) = self.attrs(under, attributes)
      let (label, instrs) = body
      (
        [
          {
            ..f,
            desc: Func(
              name~,
              typ~,
              sign~,
              body=(label, self.instrs(under, instrs)),
              attributes~,
            ),
          },
        ],
        under,
      )
    }
    Global(name~, mut_~, typ~, def~, attributes~) => {
      let (attributes, under) = self.attrs(under, attributes)
      (
        [
          {
            ..f,
            desc: Global(
              name~,
              mut_~,
              typ~,
              def=self.one(under, def),
              attributes~,
            ),
          },
        ],
        under,
      )
    }
    Tag(name~, typ~, sign~, attributes~) => {
      let (attributes, under) = self.attrs(under, attributes)
      ([{ ..f, desc: Tag(name~, typ~, sign~, attributes~), }], under)
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
      let (attributes, under) = self.attrs(under, attributes)
      (
        [
          {
            ..f,
            desc: Memory(
              name~,
              address_type~,
              limits~,
              page_size_log2~,
              shared~,
              data~,
              attributes~,
            ),
          },
        ],
        under,
      )
    }
    Table(name~, address_type~, reftype~, limits~, init~, attributes~) => {
      let (attributes, under) = self.attrs(under, attributes)
      (
        [
          {
            ..f,
            desc: Table(
              name~,
              address_type~,
              reftype~,
              limits~,
              init~,
              attributes~,
            ),
          },
        ],
        under,
      )
    }
    Import(module_~, decl~) => {
      let (decl, under) = self.decl(under, decl)
      ([{ ..f, desc: Import(module_~, decl~), }], under)
    }
    ImportGroup(module_~, decls~) => {
      let out = []
      let mut under = under
      for d in decls {
        let (d2, next) = self.decl(under, d)
        out.push(d2)
        under = next
      }
      ([{ ..f, desc: ImportGroup(module_~, decls=out), }], under)
    }
    ModuleAnnotation(a) => {
      let (a, under) = self.attrs(under, a)
      ([{ ..f, desc: ModuleAnnotation(a), }], under)
    }
    Type(_) | TypeAlias(..) | Data(..) | Elem(..) => ([f], under)
  }
}

///|
/// A list of fields, with the assumption threading through them.
fn Configuring::fields(
  self : Configuring,
  under : @cond.T,
  fl : @ast.Module[@basic.Location],
) -> @ast.Module[@basic.Location] {
  let out : @ast.Module[@basic.Location] = []
  let mut under = under
  for f in fl {
    let (got, next) = self.field(under, f)
    for g in got {
      out.push(g)
    }
    under = next
  }
  out
}

///|
/// Specialize `fields` under `assumption`, producing a conditional-free module.
fn specialize_fields(
  env : @cond.Env,
  diagnostics : @diagnostic.Context,
  assumption : @cond.T,
  fields : @ast.Module[@basic.Location],
  enqueue : (@cond.T) -> Unit,
  record : (@cond.T) -> Unit,
) -> @ast.Module[@basic.Location] {
  ({ env, diagnostics, enqueue, record, } : Configuring).fields(
    assumption, fields,
  )
}

///|
/// Whether anything in this module is conditional.
///
/// Gates the whole configuration machinery: a module with no `#[if]` anywhere
/// is one program, and exploring it would be a whole-module walk to discover
/// there is nothing to explore.
///
/// An attribute GUARD counts, as it does for the reference: it partitions the
/// configurations like an `#[if]`, so an export clash or an unused definition
/// is qualified by the guard like by any conditional.
fn module_has_conditional(fields : @ast.Module[@basic.Location]) -> Bool {
  fn in_instr(i : @ast.Instr[@basic.Location]) -> Bool {
    if i.desc is IfAnnotation(..) {
      return true
    }
    i.sub_instrs().iter().any(in_instr)
  }

  fn guarded(attrs : @ast.Attributes) -> Bool {
    attrs.iter().any(a => a.attr_guard is Some(_))
  }

  fn in_field(
    f : @basic.Annotated[@ast.ModuleField[@basic.Location], @basic.Location],
  ) -> Bool {
    match f.desc {
      Conditional(..) => true
      Func(body~, attributes~, ..) =>
        guarded(attributes) || body.1.iter().any(in_instr)
      Global(def~, attributes~, ..) => guarded(attributes) || in_instr(def)
      Tag(attributes~, ..)
      | Memory(attributes~, ..)
      | Table(attributes~, ..)
      | Data(attributes~, ..)
      | Elem(attributes~, ..)
      | ModuleAnnotation(attributes) => guarded(attributes)
      Import(decl~, ..) => guarded(decl.desc.attributes)
      ImportGroup(decls~, ..) =>
        decls.iter().any(d => guarded(d.desc.attributes))
      Type(_) | TypeAlias(..) => false
    }
  }

  fields.iter().any(in_field)
}

///|
/// Report a `let` binding written inside a conditional branch.
///
/// Branches are transparent and mutually exclusive: a name bound in one would
/// leak past the conditional and clash with the other branch. An anonymous
/// `_ = e` binds nothing, so it is allowed.
fn check_let_bindings(
  diagnostics : @diagnostic.Context,
  fields : @ast.Module[@basic.Location],
) -> Unit {
  fn branch(l : Array[@ast.Instr[@basic.Location]]) -> Unit {
    for s in l {
      if s.desc is Let(bindings, _) && bindings.iter().any(b => b.0 is Some(_)) {
        let_in_conditional(diagnostics, s.info)
      }
    }
  }

  fn go(i : @ast.Instr[@basic.Location]) -> Unit {
    if i.desc is IfAnnotation(then_body~, else_body~, ..) {
      branch(then_body.desc)
      if else_body is Some(b) {
        branch(b.desc)
      }
    }
    for sub in i.sub_instrs() {
      go(sub)
    }
  }

  fn in_field(
    f : @basic.Annotated[@ast.ModuleField[@basic.Location], @basic.Location],
  ) -> Unit {
    match f.desc {
      Func(body~, ..) =>
        for s in body.1 {
          go(s)
        }
      Global(def~, ..) => go(def)
      Conditional(then_fields~, else_fields~, ..) => {
        for g in then_fields.desc {
          in_field(g)
        }
        if else_fields is Some(e) {
          for g in e.desc {
            in_field(g)
          }
        }
      }
      _ => ()
    }
  }

  for f in fields {
    in_field(f)
  }
}

///|
/// Report every conditional branch no configuration selects: one whose
/// condition cannot hold together with the conditions of the branches
/// enclosing it, or cannot hold at all.
///
/// A property of the module, not of any one configuration, so it is reported
/// directly rather than through the explorer. Only the outermost branch of a
/// dead nest is reported: a conditional inside a dead branch is never decided.
/// A per-attribute guard is a conditional with two empty sides -- present and
/// absent -- and is decided like any other.
fn report_dead_branches(
  diagnostics : @diagnostic.Context,
  fields : @ast.Module[@basic.Location],
) -> Unit {
  let env = @cond.Env::new()
  // Ill-formed conditions are reported where the configurations are explored.
  let quiet = @diagnostic.collector(parent=Some(diagnostics))
  fn decide(
    under : @cond.T,
    location : @basic.Location,
    cond : @wasm_types.Cond,
    has_else : Bool,
    then_ : (@cond.T) -> Unit,
    else_ : (@cond.T) -> Unit,
  ) -> Unit {
    let c = env.of_cond(quiet, location, cond)
    let then_under = @cond.and_(under, c)
    let else_under = @cond.and_(under, @cond.not_(c))
    if @cond.is_satisfiable(then_under) {
      then_(then_under)
    } else {
      dead_branch(diagnostics, location, side=true)
    }
    if has_else {
      if @cond.is_satisfiable(else_under) {
        else_(else_under)
      } else {
        dead_branch(diagnostics, location, side=false)
      }
    }
  }

  fn guards(under : @cond.T, attrs : @ast.Attributes) -> Unit {
    for a in attrs {
      if a.attr_guard is Some(g) {
        decide(under, g.info, g.desc, true, _ => (), _ => ())
      }
    }
  }

  fn instr(under : @cond.T, i : @ast.Instr[@basic.Location]) -> Unit {
    match i.desc {
      IfAnnotation(cond~, then_body~, else_body~) =>
        decide(
          under,
          i.info,
          cond,
          else_body is Some(_),
          u => {
            for x in then_body.desc {
              instr(u, x)
            }
          },
          u => {
            if else_body is Some(e) {
              for x in e.desc {
                instr(u, x)
              }
            }
          },
        )
      _ =>
        for x in i.sub_instrs() {
          instr(under, x)
        }
    }
  }

  fn instrs(under : @cond.T, l : Array[@ast.Instr[@basic.Location]]) -> Unit {
    for i in l {
      instr(under, i)
    }
  }

  fn go(under : @cond.T, l : @ast.Module[@basic.Location]) -> Unit {
    for f in l {
      match f.desc {
        Conditional(cond~, then_fields~, else_fields~) =>
          decide(
            under,
            f.info,
            cond,
            else_fields is Some(_),
            u => go(u, then_fields.desc),
            u => if else_fields is Some(e) { go(u, e.desc) },
          )
        Func(body~, attributes~, ..) => {
          guards(under, attributes)
          instrs(under, body.1)
        }
        Global(def~, attributes~, ..) => {
          guards(under, attributes)
          instr(under, def)
        }
        Tag(attributes~, ..)
        | Memory(attributes~, ..)
        | Table(attributes~, ..)
        | Data(attributes~, ..)
        | Elem(attributes~, ..)
        | ModuleAnnotation(attributes) => guards(under, attributes)
        Import(decl~, ..) => guards(under, decl.desc.attributes)
        ImportGroup(decls~, ..) =>
          for d in decls {
            guards(under, d.desc.attributes)
          }
        Type(_) | TypeAlias(..) => ()
      }
    }
  }

  go(@cond.true_, fields)
}

///|
/// Record the aliases defined under a conditional annotation, by name.
fn record_conditional_aliases(
  out : Set[String],
  fields : @ast.Module[@basic.Location],
  under : Bool,
) -> Unit {
  for f in fields {
    match f.desc {
      TypeAlias(name~, ..) => if under { out.add(name.name) }
      Conditional(then_fields~, else_fields~, ..) => {
        record_conditional_aliases(out, then_fields.desc, true)
        if else_fields is Some(e) {
          record_conditional_aliases(out, e.desc, true)
        }
      }
      _ => ()
    }
  }
}

///|
/// Record every function body as written, for the source-shape lints of a
/// configuration (see `ModuleContext::preserved_bodies`).
fn record_preserved_bodies(
  ctx : @typing_env.ModuleContext,
  fields : @ast.Module[@basic.Location],
) -> Unit {
  for f in fields {
    match f.desc {
      Func(body~, ..) =>
        ctx.preserved_bodies[(f.info.start.cnum, f.info.end.cnum)] = body.1
      Conditional(then_fields~, else_fields~, ..) => {
        record_preserved_bodies(ctx, then_fields.desc)
        if else_fields is Some(e) {
          record_preserved_bodies(ctx, e.desc)
        }
      }
      _ => ()
    }
  }
}

///|
/// Check every reachable configuration of a conditional module.
///
/// Each is specialized to be conditional-free and checked independently, in its
/// own collector, so a diagnostic is reported once -- annotated with the
/// assumption under which it is reachable, rather than repeated per
/// configuration that happened to produce it. Only the diagnostics matter here;
/// the typed module each configuration produces is thrown away.
///
/// A fresh type store per configuration, because a configuration declares its
/// own types: the branches may not agree on what a name means, and one
/// configuration's registrations must not be visible to the next.
fn check_configurations(
  diagnostics : @diagnostic.Context,
  store : @type_store.TypeStore,
  features : @feature.Set,
  fields : @ast.Module[@basic.Location],
  simplify~ : Bool = false,
  warn_unused~ : Bool = false,
  lowering~ : Bool = false,
  suggest~ : Bool = false,
) -> Unit {
  ignore(store)
  if warn_unused {
    report_dead_branches(diagnostics, fields)
  }
  // Each configuration is checked on its own; what holds in each but not as
  // one module -- the form a construct takes differing between them -- is the
  // lowering's to report, once.
  let forms : Map[(Int32, Int32), (@basic.Location, ConfigurationForm)]? = if lowering &&
    !simplify {
    Some(Map([]))
  } else {
    None
  }
  @cond_explore.check_all(
    diagnostics,
    specialize=(env, assumption, enqueue, record) => {
      specialize_fields(env, diagnostics, assumption, fields, enqueue, record)
    },
    check=(cctx, cfg) => {
      let ctx = @typing_env.ModuleContext::new(
        cctx,
        @type_store.TypeStore::new(),
        features,
        simplify~,
        warn_unused~,
        suggest~,
      )
      record_preserved_bodies(ctx, fields)
      record_conditional_aliases(ctx.conditional_alias_names, fields, false)
      declare_fields(ctx, cfg)
      check_attributes(ctx, cfg)
      let typed = check_fields(ctx, Operands::new(), cfg)
      if forms is Some(tbl) {
        record_configuration_forms(ctx, tbl, typed)
      }
      check_unused_aliases(ctx.type_context, ctx.diagnostics)
      warn_unused_fields(ctx, cfg)
    },
    truncation_location=match fields {
      [hd, ..] => Some(hd.info)
      [] => None
    },
    explain=Some((env, c) => env.explain(c, style=Wax)),
  )
  if forms is Some(tbl) {
    report_configuration_forms(diagnostics, tbl)
  }
}

///|
/// What a construct lowers to in one configuration, for one whose form may
/// depend on the configuration: a cast to a conditional alias (its target
/// type), and a struct field access (the receiver's struct type and the
/// field's position).
priv enum ConfigurationForm {
  LiteralForm(@ast.Ident, Array[String])
  CastForm(@ast.Ident, Array[String])
  FieldForm(@ast.Ident, Array[(String, Int32)])
}

///|
/// Record, by span, the form each such construct of `typed` takes in this
/// configuration.
///
/// A module lowered as one for every configuration takes each form from one
/// run, so `report_configuration_forms` rejects a construct the configurations
/// disagree on. Recorded by the checking runs, one per configuration, rather
/// than by the build, which only covers each branch once.
fn record_configuration_forms(
  ctx : @typing_env.ModuleContext,
  tbl : Map[(Int32, Int32), (@basic.Location, ConfigurationForm)],
  typed : Array[
    @basic.Annotated[
      @ast.ModuleField[@typing_env.InferredAnnotation],
      @basic.Location,
    ],
  ],
) -> Unit {
  // Keyed by `l`, reported at `at`: a negative literal is reported whole.
  fn add_at(
    l : @basic.Location,
    at : @basic.Location,
    form : (ConfigurationForm?) -> ConfigurationForm,
  ) -> Unit {
    let key = (l.start.cnum, l.end.cnum)
    match tbl.get(key) {
      Some((at_, prev)) =>
        tbl[key] = (
          if at_.start.cnum <= at.start.cnum {
            at_
          } else {
            at
          },
          form(Some(prev)),
        )
      None => tbl[key] = (at, form(None))
    }
  }

  fn add(
    l : @basic.Location,
    form : (ConfigurationForm?) -> ConfigurationForm,
  ) -> Unit {
    add_at(l, l, form)
  }

  fn conditional_alias(a : @ast.Ident) -> Bool {
    match ctx.type_context.aliases.find_no_mark(a.name) {
      Some(al) => al.conditional
      None => false
    }
  }

  // A literal or null typed by a conditional alias: its type, printed.
  fn typed_by(
    l : @basic.Location,
    at : @basic.Location,
    cell : @infer.Cell[@infer.InferredType],
  ) -> Unit {
    match cell.get() {
      Valtype({ type_alias: Some(a), .. }) if conditional_alias(a) => {
        let t = @infer.to_string(cell)
        add_at(l, at, prev => {
          match prev {
            Some(LiteralForm(_, seen)) =>
              LiteralForm(a, if seen.contains(t) { seen } else { [..seen, t] })
            _ => LiteralForm(a, [t])
          }
        })
      }
      _ => ()
    }
  }

  fn go(i : @ast.Instr[@typing_env.InferredAnnotation]) -> Unit {
    let l = i.info.1
    match i.desc {
      Int(_) | Float(_) | Null if i.info.0 is [cell] => typed_by(l, l, cell)
      UnOpI({ desc: Neg, .. }, { desc: Int(_) | Float(_), info: (lit, ll), .. }) if lit
        is [cell] => typed_by(ll, l, cell)
      Cast(_, Value(Alias(a))) if conditional_alias(a) =>
        match i.info.0 {
          [cell] =>
            if cell.get() is Valtype(_) {
              let t = @infer.to_string(cell)
              add(l, prev => {
                match prev {
                  Some(CastForm(_, seen)) =>
                    CastForm(
                      a,
                      if seen.contains(t) {
                        seen
                      } else {
                        [..seen, t]
                      },
                    )
                  _ => CastForm(a, [t])
                }
              })
            }
          _ => ()
        }
      StructGet(recv, f) | StructSet(recv, f, _) =>
        match recv.info.0 {
          [cell] =>
            match cell.get() {
              Valtype({ typ: Ref({ typ: Type(ty) | Exact(ty), .. }), .. }) =>
                match ctx.type_context.types.find_no_mark(ty.name) {
                  Some((_, { typ: Struct(fields), .. })) => {
                    let mut index = -1
                    for k, fd in fields {
                      if index < 0 && fd.desc.0.name == f.name {
                        index = k
                      }
                    }
                    if index >= 0 {
                      let v = (ty.name, index)
                      add(l, prev => {
                        match prev {
                          Some(FieldForm(_, seen)) =>
                            FieldForm(
                              f,
                              if seen.contains(v) {
                                seen
                              } else {
                                [..seen, v]
                              },
                            )
                          _ => FieldForm(f, [v])
                        }
                      })
                    }
                  }
                  _ => ()
                }
              _ => ()
            }
          _ => ()
        }
      _ => ()
    }
    for x in i.sub_instrs() {
      go(x)
    }
  }

  fn fields(
    l : Array[
      @basic.Annotated[
        @ast.ModuleField[@typing_env.InferredAnnotation],
        @basic.Location,
      ],
    ],
  ) -> Unit {
    for f in l {
      match f.desc {
        Func(body~, ..) =>
          for x in body.1 {
            go(x)
          }
        Global(def~, ..) => go(def)
        Conditional(then_fields~, else_fields~, ..) => {
          fields(then_fields.desc)
          if else_fields is Some(e) {
            fields(e.desc)
          }
        }
        _ => ()
      }
    }
  }

  fields(typed)
}

///|
/// Report, once, each construct with no form that holds in every
/// configuration.
///
/// A field access is fine when the field is at the same position in every
/// type the receiver has: the lowering's `struct.get` of one is then valid on
/// the others, and a type redefined per configuration is named, so its field
/// resolves in each.
fn report_configuration_forms(
  diagnostics : @diagnostic.Context,
  tbl : Map[(Int32, Int32), (@basic.Location, ConfigurationForm)],
) -> Unit {
  let entries : Array[(@basic.Location, ConfigurationForm)] = []
  for _, e in tbl {
    entries.push(e)
  }
  entries.sort_by((a, b) => a.0.start.cnum - b.0.start.cnum)
  for e in entries {
    let (location, form) = e
    match form {
      LiteralForm(a, seen) if seen.length() >= 2 =>
        conditional_alias_literal(diagnostics, location, a.name)
      CastForm(a, seen) if seen.length() >= 2 =>
        conditional_alias_cast(diagnostics, location, a.name)
      FieldForm(f, seen) if seen
        .iter()
        .any(v => seen.iter().any(w => v.0 != w.0 && v.1 != w.1)) =>
        configuration_dependent_field(diagnostics, location, f.name)
      _ => ()
    }
  }
}
