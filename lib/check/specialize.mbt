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
) -> FormTable? {
  ignore(store)
  if warn_unused {
    report_dead_branches(diagnostics, fields)
  }
  // Each configuration is checked on its own; what holds in each but not as
  // one module -- the form a construct takes differing between them -- is the
  // lowering's to report, once.
  let forms : FormTable? = if lowering && !simplify {
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
      let ops = Operands::new()
      let typed = check_fields(ctx, ops, cfg)
      if forms is Some(tbl) {
        record_configuration_forms(ctx, tbl, typed, ops.polymorphic_values)
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
  forms
}

///|
/// What a construct lowers to in each configuration checked, for one whose
/// form may depend on the configuration: a literal or null (its type, printed,
/// with the conditional alias it takes, if any), a cast to a conditional alias
/// (its target type), a struct field access (the receiver's struct type and
/// the field's position), an operation whose instruction its operands' types
/// pick (those types, with the conditional alias of one, if any), an inferred
/// declaration (the type it is declared with), an instruction whose type
/// immediate the lowering takes from a type the code does not write (that
/// immediate), and the receiver of a struct or array access (its type, with
/// that type's supertypes).
priv enum ConfigurationForm {
  LiteralForm(@ast.Ident?, Array[String])
  CastForm(@ast.Ident, Array[String])
  FieldForm(@ast.Ident, Array[(String, Int32)])
  OperationForm(@ast.Ident?, Array[String])
  DeclarationForm(Declaration, Array[(String, DeclaredRef?)])
  ImmediateForm(Immediate, Array[String])
  ReceiverForm(Array[(String, Array[String])])
}

///|
/// A declaration whose type the lowering takes from the one it is inferred
/// with: an omitted block result, unannotated locals or global, the result of
/// a `select` of references.
priv enum Declaration {
  BlockResult
  Locals(Array[@ast.Ident])
  GlobalType(@ast.Ident)
  SelectResult
}

///|
/// Where an immediate comes from: the operand a continuation instruction or a
/// call through a reference applies to, or the type a struct, array or string
/// value is inferred with.
priv enum Immediate {
  Access
  CallRef
  Construction
}

///|
/// The reference type a declaration takes in a configuration, for
/// `declaration_choice`: its heap type, with the names of that type and its
/// supertypes (`ancestors`), its hierarchy, and whether it is that hierarchy's
/// bottom, a subtype of every type in it.
priv struct DeclaredRef {
  nullable : Bool
  heap : @wasm_types.HeapType[@ast.Ident]
  ancestors : Array[String]
  hierarchy : String
  bottom : Bool
}

///|
/// The forms recorded so far, keyed by a kind that tells two forms of one
/// construct apart and by span; each with where it is reported.
type FormTable = Map[
  (String, Int32, Int32),
  (@basic.Location, ConfigurationForm),
]

///|
/// A type printed for comparison: without locations, so two spellings of one
/// type are one key.
fn valtype_key(t : @wasm_types.ValType[@ast.Ident]) -> String {
  @output.run_string(p => {
    @output.Ctx::new(p, trivia=@trivia.Table::empty()).valtype(t)
  })
}

///|
/// `l` with `v` added, unless it is already there.
fn[T : Eq] union(v : T, l : Array[T]) -> Array[T] {
  if l.contains(v) {
    l
  } else {
    [..l, v]
  }
}

///|
/// The name of the type `name` and of its declared supertypes, transitively.
fn type_ancestors(
  ctx : @typing_env.ModuleContext,
  name : String,
) -> Array[String] {
  let seen : Array[String] = []
  let mut n = name
  while !seen.contains(n) {
    seen.push(n)
    match ctx.type_context.types.find_no_mark(n) {
      Some((_, { supertype: Some(s), .. })) => n = s.name
      _ => break
    }
  }
  seen
}

///|
/// Record in `tbl`, by span, the form each such construct of `typed` takes in
/// this configuration.
///
/// A module lowered as one for every configuration takes each form from one
/// run, so `report_configuration_forms` rejects a construct the configurations
/// disagree on. Recorded by the checking runs, one per configuration, rather
/// than by the build, which only covers each branch once. `polymorphic` is the
/// cells of the values this run took off the polymorphic stack of unreachable
/// code (`Operands::pop_any`).
fn record_configuration_forms(
  ctx : @typing_env.ModuleContext,
  tbl : FormTable,
  typed : Array[
    @basic.Annotated[
      @ast.ModuleField[@typing_env.InferredAnnotation],
      @basic.Location,
    ],
  ],
  polymorphic : Array[@infer.Cell[@infer.InferredType]],
) -> Unit {
  let tc = ctx.type_context
  // Keyed by `l` and `kind`, reported at `at`: a negative literal is reported
  // whole.
  fn add(
    l : @basic.Location,
    at : @basic.Location?,
    kind : String,
    form : (ConfigurationForm?) -> ConfigurationForm,
  ) -> Unit {
    let key = (kind, l.start.cnum, l.end.cnum)
    let at = at.unwrap_or(l)
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

  // A declaration of a single type, unaliased, records it as a reference too
  // (see `declaration_choice`).
  fn ref_entry(t : @wasm_types.ValType[@ast.Ident]) -> DeclaredRef? {
    guard t is Ref({ nullable, typ: heap, }) else { return None }
    let abstract_ = (ancestors : Array[String], hierarchy : String) => {
      Some((ancestors, hierarchy, false))
    }
    let bottom = (hierarchy : String) => Some(([], hierarchy, true))
    let entry = match heap {
      Type(n) | Exact(n) => {
        let named = (tops : Array[String], hierarchy : String) => {
          Some(([..type_ancestors(ctx, n.name), ..tops], hierarchy, false))
        }
        match tc.types.find_no_mark(n.name) {
          Some((_, { typ: Struct(_), .. })) =>
            named(["struct", "eq", "any"], "any")
          Some((_, { typ: Array(_), .. })) =>
            named(["array", "eq", "any"], "any")
          Some((_, { typ: Func(_), .. })) => named(["func"], "func")
          Some((_, { typ: Cont(_), .. })) => named(["cont"], "cont")
          None => None
        }
      }
      Any => abstract_(["any"], "any")
      Eq => abstract_(["eq", "any"], "any")
      I31 => abstract_(["i31", "eq", "any"], "any")
      Struct => abstract_(["struct", "eq", "any"], "any")
      Array => abstract_(["array", "eq", "any"], "any")
      None_ => bottom("any")
      Func => abstract_(["func"], "func")
      NoFunc => bottom("func")
      Extern => abstract_(["extern"], "extern")
      NoExtern => bottom("extern")
      Exn => abstract_(["exn"], "exn")
      NoExn => bottom("exn")
      Cont => abstract_(["cont"], "cont")
      NoCont => bottom("cont")
    }
    entry.map(e => {
      nullable,
      heap,
      ancestors: e.0,
      hierarchy: e.1,
      bottom: e.2,
    })
  }

  fn declared(
    l : @basic.Location,
    d : Declaration,
    types : Array[String],
    typ : @wasm_types.ValType[@ast.Ident]?,
  ) -> Unit {
    let t = types.join(" ")
    let entry = (t, typ.bind(ref_entry))
    add(l, None, "", prev => {
      match prev {
        Some(DeclarationForm(d_, seen)) =>
          DeclarationForm(
            d_,
            if seen.iter().any(e => e.0 == t) {
              seen
            } else {
              [..seen, entry]
            },
          )
        _ => DeclarationForm(d, [entry])
      }
    })
  }

  fn immediate(
    l : @basic.Location,
    k : Immediate,
    parts : Array[String],
  ) -> Unit {
    let t = parts.join(" ")
    add(l, None, "immediate", prev => {
      match prev {
        Some(ImmediateForm(k_, seen)) => ImmediateForm(k_, union(t, seen))
        _ => ImmediateForm(k, [t])
      }
    })
  }

  fn single(
    e : @ast.Instr[@typing_env.InferredAnnotation],
  ) -> @infer.Cell[@infer.InferredType]? {
    match e.info.0 {
      [cell] => Some(cell)
      _ => None
    }
  }

  // A value's type as a declaration of it is written: by its conditional
  // alias, which lowers to the same annotation in every configuration, or by
  // the type itself.
  fn written_form(cell : @infer.Cell[@infer.InferredType]) -> String? {
    match cell.get() {
      Valtype({ type_alias: Some(a), .. }) if conditional_alias(ctx, a) =>
        Some(a.name)
      Valtype({ typ, .. }) => Some(valtype_key(tc.unalias(typ)))
      _ => None
    }
  }

  // The type a value's reference type names, as an immediate.
  fn own_name(cell : @infer.Cell[@infer.InferredType]) -> String? {
    match cell.get() {
      Valtype({ typ, .. }) =>
        match tc.unalias(typ) {
          Ref({ typ: Type(n) | Exact(n), .. }) => Some(n.name)
          _ => None
        }
      _ => None
    }
  }

  // The receiver of a struct or array access, by its own span: the access
  // names the type the others are subtypes of (see `receiver_choice`).
  fn access(recv : @ast.Instr[@typing_env.InferredAnnotation]) -> Unit {
    match single(recv).bind(own_name) {
      Some(n) => {
        let entry = (n, type_ancestors(ctx, n))
        add(recv.info.1, None, "receiver", prev => {
          match prev {
            Some(ReceiverForm(seen)) =>
              ReceiverForm(
                if seen.iter().any(e => e.0 == entry.0) {
                  seen
                } else {
                  [..seen, entry]
                },
              )
            _ => ReceiverForm([entry])
          }
        })
      }
      None => ()
    }
  }

  // A literal's type may differ between configurations without an alias to
  // say so: one taken from a declaration written differently in each branch,
  // or from an alias whose provenance was lost on the way.
  fn typed_by(
    l : @basic.Location,
    cell : @infer.Cell[@infer.InferredType],
    at : @basic.Location?,
  ) -> Unit {
    guard cell.get() is Valtype({ type_alias, typ, .. }) else { return }
    let a = match type_alias {
      Some(a) if conditional_alias(ctx, a) => Some(a)
      _ => None
    }
    let t = valtype_key(tc.unalias(typ))
    add(l, at, "", prev => {
      match prev {
        Some(LiteralForm(a_, seen)) =>
          LiteralForm(if a_ is None { a } else { a_ }, union(t, seen))
        _ => LiteralForm(a, [t])
      }
    })
  }

  fn field(
    l : @basic.Location,
    recv : @ast.Instr[@typing_env.InferredAnnotation],
    f : @ast.Ident,
  ) -> Unit {
    guard single(recv) is Some(cell) else { return }
    guard cell.get()
      is Valtype({ typ: Ref({ typ: Type(ty) | Exact(ty), .. }), .. }) else {
      return
    }
    guard tc.types.find_no_mark(ty.name)
      is Some((_, { typ: Struct(fields), .. })) else {
      return
    }
    let mut index = -1
    for k, fd in fields {
      if index < 0 && fd.desc.0.name == f.name {
        index = k
      }
    }
    if index >= 0 {
      let v = (ty.name, index)
      add(l, None, "", prev => {
        match prev {
          Some(FieldForm(_, seen)) => FieldForm(f, union(v, seen))
          _ => FieldForm(f, [v])
        }
      })
    }
  }

  // An operand's type as the lowering sees it: a number's type, or just `ref`,
  // as no instruction picked by an operand's type tells references apart.
  // `None` when it has none (unreachable code).
  fn operand_key(e : @ast.Instr[@typing_env.InferredAnnotation]) -> String? {
    match single(e) {
      Some(cell) =>
        match cell.get() {
          Valtype({ typ, .. }) =>
            match tc.unalias(typ) {
              Ref(_) => Some("ref")
              t => Some(valtype_key(t))
            }
          _ => None
        }
      None => None
    }
  }

  fn operand_alias(
    e : @ast.Instr[@typing_env.InferredAnnotation],
  ) -> @ast.Ident? {
    match single(e) {
      Some(cell) =>
        match cell.get() {
          Valtype({ type_alias: Some(a), .. }) if conditional_alias(ctx, a) =>
            Some(a)
          _ => None
        }
      None => None
    }
  }

  // A hole holding a value of unreachable code: the operation's use defaults
  // its type, so any form would do in this configuration.
  fn is_polymorphic(e : @ast.Instr[@typing_env.InferredAnnotation]) -> Bool {
    match (e.desc, e.info.0) {
      (Hole, [cell]) => polymorphic.iter().any(c => physical_equal(c, cell))
      _ => false
    }
  }

  fn operation(
    l : @basic.Location,
    operands : Array[@ast.Instr[@typing_env.InferredAnnotation]],
  ) -> Unit {
    let keys = operands.map(operand_key)
    if !operands.is_empty() &&
      !operands.iter().all(is_polymorphic) &&
      keys.iter().all(k => k is Some(_)) {
      let shape = keys.map(k => k.unwrap()).join(" ")
      let mut a = None
      for o in operands {
        if a is None {
          a = operand_alias(o)
        }
      }
      add(l, None, "", prev => {
        match prev {
          Some(OperationForm(a_, seen)) =>
            OperationForm(if a_ is None { a } else { a_ }, union(shape, seen))
          _ => OperationForm(a, [shape])
        }
      })
    }
  }

  fn is_cont_method(
    recv : @ast.Instr[@typing_env.InferredAnnotation],
    meth : @ast.Ident,
  ) -> Bool {
    match meth.name {
      "resume" | "resume_throw" | "resume_throw_ref" | "switch" =>
        match single(recv).bind(own_name) {
          Some(n) => tc.types.find_no_mark(n) is Some((_, { typ: Cont(_), .. }))
          None => false
        }
      _ => false
    }
  }

  // The first walk: the forms of literals, casts, field accesses, inferred
  // block results and locals, and operations.
  fn first(i : @ast.Instr[@typing_env.InferredAnnotation]) -> Unit {
    let l = i.info.1
    match (i.desc, i.info.0) {
      (Int(_) | Float(_) | Null, [cell]) => typed_by(l, cell, None)
      // A negative literal is reported whole, `-1` rather than `1`.
      (
        UnOpI(
          { desc: Neg, .. },
          { desc: Int(_) | Float(_), info: (lit, ll), .. }
        ),
        _,
      ) => if lit is [cell] { typed_by(ll, cell, Some(l)) }
      (Cast(_, Value(Alias(a))), [cell]) if conditional_alias(ctx, a) =>
        if cell.get() is Valtype({ typ, .. }) {
          let t = valtype_key(typ)
          add(l, None, "", prev => {
            match prev {
              Some(CastForm(_, seen)) => CastForm(a, union(t, seen))
              _ => CastForm(a, [t])
            }
          })
        }
      (StructGet(recv, f), _) | (StructSet(recv, f, _), _) => field(l, recv, f)
      // An omitted result is filled with the inferred one, named by the alias
      // it carries, if any (`declared_form`); a written one is the same in
      // every configuration. None is filled in unreachable code.
      (
        Block(typ~, ..)
        | Loop(typ~, ..)
        | If(typ~, ..)
        | TryTable(typ~, ..)
        | Try(typ~, ..)
        | TryCatch(typ~, ..),
        _,
      ) if !typ.results.is_empty() =>
        match typ.results {
          [t] => declared(l, BlockResult, [valtype_key(t)], Some(t))
          rs => declared(l, BlockResult, rs.map(valtype_key), None)
        }
      (Let(bindings, Some(init)), _) if init.info.0.length() ==
        bindings.length() => {
        // An unannotated local is declared with the alias its initializer
        // carries (`declared_alias`), or else with the initializer's type.
        let unannotated : Array[(@ast.Ident, @wasm_types.ValType[@ast.Ident])] = []
        for k, b in bindings {
          // One whose initializer carries an alias is declared with it
          // (`declared_alias`), which the reference writes into the typed tree.
          match (b.0, b.1, init.info.0[k].get()) {
            (Some(name), None, Valtype({ typ, type_alias: None, .. })) =>
              unannotated.push((name, tc.unalias(typ)))
            _ => ()
          }
        }
        if !unannotated.is_empty() {
          let names = unannotated.map(u => u.0)
          let types = unannotated.map(u => valtype_key(u.1))
          if bindings.length() == 1 && unannotated.length() == 1 {
            declared(l, Locals(names), types, Some(unannotated[0].1))
          } else {
            declared(l, Locals(names), types, None)
          }
        }
      }
      // The operations whose instruction the lowering picks from an operand's
      // type: the operators, a compound assignment, a cast from a number, a
      // method on a value (`x.clz()`, `x.min(y)`: its receiver), and a memory
      // store or atomic access (its values, not the address).
      (BinOpI(_, a, b), _) => operation(l, [a, b])
      (UnOpI(_, a), _) | (Set(_, Some(_), a), _) => operation(l, [a])
      (Cast(a, Value(_) | Signed(..)), _) => operation(l, [a])
      (Call({ desc: StructGet(recv, meth), .. }, args), _) if !is_cont_method(
          recv, meth,
        ) =>
        match recv.info.0 {
          [_] => operation(l, [recv])
          _ =>
            if meth.name.has_prefix("store") ||
              @atomics.of_method_name(meth.name) is Some(_) {
              let values = args.filter(a => !(a.desc is Labelled(_, _)))
              if values.length() >= 1 {
                operation(l, values[1:].to_owned())
              }
            }
        }
      _ => ()
    }
    for x in i.sub_instrs() {
      first(x)
    }
  }

  fn is_array(e : @ast.Instr[@typing_env.InferredAnnotation]) -> Bool {
    match single(e).bind(own_name) {
      Some(n) => tc.types.find_no_mark(n) is Some((_, { typ: Array(_), .. }))
      None => false
    }
  }

  // The receiver of a stack-switching method (`c.resume()`, `c.switch(..)`),
  // which this port keeps as the call it was written as: the reference types
  // it to the instruction, named by the receiver's continuation type.
  fn cont_receiver(
    callee : @ast.Instr[@typing_env.InferredAnnotation],
  ) -> String? {
    guard callee.desc
      is StructGet(
        recv,
        { name: "resume" | "resume_throw" | "resume_throw_ref" | "switch", .. }
      ) else {
      return None
    }
    match single(recv).bind(own_name) {
      Some(n) =>
        match tc.types.find_no_mark(n) {
          Some((_, { typ: Cont(_), .. })) => Some(n)
          _ => None
        }
      None => None
    }
  }

  let ascribed_selects : Set[(Int32, Int32)] = Set([])
  // A call through a reference, rather than of a function by name.
  fn call_ref(f : @ast.Instr[@typing_env.InferredAnnotation]) -> String? {
    match f.desc {
      Get(name) if ctx.functions.find_no_mark(name.name) is Some(_) => None
      _ => single(f).bind(own_name)
    }
  }

  // The second walk: receivers, immediates and selects.
  fn second(i : @ast.Instr[@typing_env.InferredAnnotation]) -> Unit {
    let l = i.info.1
    match i.desc {
      // A field access has a value; a method, called, has none.
      StructGet(recv, _) if single(i) is Some(_) => access(recv)
      StructSet(recv, _, _) => access(recv)
      ArrayGet(recv, _) => access(recv)
      ArraySet(recv, _, _) => access(recv)
      Call({ desc: StructGet(a, { name: "fill" | "init", .. }), .. }, _) if is_array(
          a,
        ) => access(a)
      Call({ desc: StructGet(a1, { name: "copy", .. }), .. }, [_, a2, _, _]) if is_array(
          a1,
        ) => {
        access(a1)
        access(a2)
      }
      Call(callee, _) if cont_receiver(callee) is Some(n) =>
        immediate(l, Access, [n])
      Call(f, _) | TailCall(f, _) if single(f) is Some(_) =>
        if call_ref(f) is Some(n) {
          immediate(l, CallRef, [n])
        }
      GetDescriptor(recv) =>
        if single(recv).bind(own_name) is Some(n) {
          immediate(l, Access, [n])
        }
      Struct(None, _)
      | StructDefault(None)
      | Array(None, _, _)
      | ArrayDefault(None, _)
      | ArrayFixed(None, _)
      | ArraySegment(None, _, _, _)
      | Str(None, _)
      | StructDesc(_, _)
      | StructDefaultDesc(_) =>
        if single(i).bind(own_name) is Some(n) {
          immediate(l, Construction, [n])
        }
      Resume(ct, _, _)
      | ResumeThrow(ct, _, _, _)
      | ResumeThrowRef(ct, _, _)
      | Switch(ct, _, _)
      | ContNew(ct, _) => immediate(l, Access, [ct.name])
      ContBind(src, dst, _) => immediate(l, Access, [src.name, dst.name])
      // A select ascribed an alias is typed with it (see the lowering); the
      // walk reaches the ascription first.
      Cast({ desc: Select(_, _, _), info: (_, sl), .. }, Ascribed(Alias(_))) =>
        ascribed_selects.add((sl.start.cnum, sl.end.cnum))
      // A select choosing between two values of unreachable code takes its
      // type from its use, which may differ between configurations, but an
      // untyped select accepts them whatever the use: recorded apart, it
      // lowers untyped unless a configuration needs a reference.
      Select(_, a, b) if !ascribed_selects.contains((l.start.cnum, l.end.cnum)) &&
        is_polymorphic(a) &&
        is_polymorphic(b) =>
        add(l, None, "untyped", _ => DeclarationForm(SelectResult, []))
      // A select of references is typed with its result, one of numbers is
      // not.
      Select(_, _, _) if !ascribed_selects.contains((l.start.cnum, l.end.cnum)) =>
        match single(i) {
          Some(cell) =>
            match cell.get() {
              Valtype({ typ, type_alias, .. }) =>
                match tc.unalias(typ) {
                  Ref(_) as t => {
                    let typ = match type_alias {
                      Some(a) if conditional_alias(ctx, a) => None
                      _ => Some(t)
                    }
                    match written_form(cell) {
                      Some(w) => declared(l, SelectResult, [w], typ)
                      None => ()
                    }
                  }
                  _ => declared(l, SelectResult, ["number"], None)
                }
              _ => ()
            }
          None => ()
        }
      _ => ()
    }
    for x in i.sub_instrs() {
      second(x)
    }
  }

  fn each_instr(
    l : Array[
      @basic.Annotated[
        @ast.ModuleField[@typing_env.InferredAnnotation],
        @basic.Location,
      ],
    ],
    go : (@ast.Instr[@typing_env.InferredAnnotation]) -> Unit,
  ) -> Unit {
    for f in l {
      match f.desc {
        Func(body~, ..) =>
          for x in body.1 {
            go(x)
          }
        Global(def~, ..) => go(def)
        Conditional(then_fields~, else_fields~, ..) => {
          each_instr(then_fields.desc, go)
          if else_fields is Some(e) {
            each_instr(e.desc, go)
          }
        }
        _ => ()
      }
    }
  }

  fn globals(
    l : Array[
      @basic.Annotated[
        @ast.ModuleField[@typing_env.InferredAnnotation],
        @basic.Location,
      ],
    ],
  ) -> Unit {
    for f in l {
      match f.desc {
        // A global's type, unwritten, is its initializer's, unless that
        // carries an alias, which `declared_alias` writes.
        Global(name~, typ=None, def~, ..) =>
          match single(def) {
            Some(c) =>
              if c.get() is Valtype({ typ, type_alias: None, .. }) {
                let t = tc.unalias(typ)
                declared(f.info, GlobalType(name), [valtype_key(t)], Some(t))
              }
            None => ()
          }
        Conditional(then_fields~, else_fields~, ..) => {
          globals(then_fields.desc)
          if else_fields is Some(e) {
            globals(e.desc)
          }
        }
        _ => ()
      }
    }
  }

  each_instr(typed, first)
  each_instr(typed, second)
  globals(typed)
}

///|
/// Of the reference types `seen` an inferred declaration takes in the
/// configurations, the one the others are subtypes of, if any, made nullable
/// if one of them is, and inexact: the type to declare it with.
fn declaration_choice(
  seen : Array[(String, DeclaredRef?)],
) -> @wasm_types.ValType[@ast.Ident]? {
  guard seen.iter().all(e => e.1 is Some(_)) else { return None }
  let refs = seen.map(e => e.1.unwrap())
  fn key(h : @wasm_types.HeapType[@ast.Ident]) -> String {
    match h {
      Type(n) | Exact(n) => n.name
      Any => "any"
      Eq => "eq"
      I31 => "i31"
      Struct => "struct"
      Array => "array"
      Func => "func"
      Extern => "extern"
      Exn => "exn"
      Cont => "cont"
      None_ | NoFunc | NoExtern | NoExn | NoCont => ""
    }
  }

  for c in refs {
    if !c.bottom &&
      refs
      .iter()
      .all(e => {
        e.hierarchy == c.hierarchy &&
        (e.bottom || e.ancestors.contains(key(c.heap)))
      }) {
      return Some(
        Ref({
          nullable: refs.iter().any(e => e.nullable),
          typ: match c.heap {
            Exact(n) => Type(n)
            h => h
          },
        }),
      )
    }
  }
  None
}

///|
/// Of the types `seen` a receiver has in the configurations, with their
/// supertypes, the one the others are subtypes of, if any.
fn receiver_choice(seen : Array[(String, Array[String])]) -> String? {
  for e in seen {
    if seen.iter().all(o => o.1.contains(e.0)) {
      return Some(e.0)
    }
  }
  None
}

///|
/// Whether the configurations disagree on `form`.
fn conflicting(form : ConfigurationForm) -> Bool {
  match form {
    OperationForm(_, seen) | LiteralForm(_, seen) | CastForm(_, seen) =>
      seen.length() >= 2
    ImmediateForm(_, seen) => seen.length() >= 2
    DeclarationForm(_, seen) =>
      seen.length() >= 2 && declaration_choice(seen) is None
    FieldForm(_, seen) => field_conflict(seen)
    ReceiverForm(seen) => receiver_choice(seen) is None
  }
}

///|
/// A field is fine when it is at the same position in every type the receiver
/// has.
fn field_conflict(seen : Array[(String, Int32)]) -> Bool {
  seen.iter().any(v => seen.iter().any(w => v.0 != w.0 && v.1 != w.1))
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
  tbl : FormTable,
) -> Unit {
  let forms : Array[(@basic.Location, ConfigurationForm)] = []
  for _, e in tbl {
    forms.push(e)
  }
  forms.sort_by((a, b) => a.0.start.cnum - b.0.start.cnum)
  // An operation reported covers what it contains: the operations it is made
  // of, and a literal that takes its type from the operands.
  let operations : Array[(Int32, Int32)] = []
  for f in forms {
    if f.1 is OperationForm(_, seen) && seen.length() >= 2 {
      operations.push((f.0.start.cnum, f.0.end.cnum))
    }
  }
  fn covered(l : @basic.Location) -> Bool {
    let a = l.start.cnum
    let b = l.end.cnum
    operations.iter().any(o => o.0 <= a && b <= o.1 && o != (a, b))
  }

  // A declaration takes its type from what it contains: one of those that has
  // no single form is what to report.
  fn contains_conflict(l : @basic.Location) -> Bool {
    let a = l.start.cnum
    let b = l.end.cnum
    forms
    .iter()
    .any(f => {
      let a_ = f.0.start.cnum
      let b_ = f.0.end.cnum
      a <= a_ && b_ <= b && (a_, b_) != (a, b) && conflicting(f.1)
    })
  }

  for f in forms {
    let (location, form) = f
    let keep = match form {
      OperationForm(_, _) | LiteralForm(_, _) => !covered(location)
      DeclarationForm(_, _) => !contains_conflict(location)
      _ => true
    }
    if !keep || !conflicting(form) {
      continue
    }
    match form {
      OperationForm(a, _) =>
        configuration_dependent_operation(diagnostics, location, a)
      LiteralForm(Some(a), _) =>
        conditional_alias_literal(diagnostics, location, a.name)
      LiteralForm(None, _) =>
        configuration_dependent_literal(diagnostics, location)
      CastForm(a, _) => conditional_alias_cast(diagnostics, location, a.name)
      FieldForm(fd, _) =>
        configuration_dependent_field(diagnostics, location, fd.name)
      DeclarationForm(d, _) =>
        configuration_dependent_declaration(diagnostics, location, d)
      ImmediateForm(k, _) =>
        configuration_dependent_immediate(
          diagnostics,
          location,
          match k {
            Access => "access"
            CallRef => "call_ref"
            Construction => "construction"
          },
        )
      ReceiverForm(_) =>
        configuration_dependent_immediate(diagnostics, location, "receiver")
    }
  }
}

///|
/// The receiver types a module lowered as one for every configuration names
/// at each struct or array access, by the receiver's span (see
/// `receiver_choice`).
fn receiver_types_of(tbl : FormTable) -> Map[(Int32, Int32), String] {
  let out : Map[(Int32, Int32), String] = Map([])
  for key, e in tbl {
    if key.0 == "receiver" && e.1 is ReceiverForm(seen) {
      if receiver_choice(seen) is Some(n) {
        out[(key.1, key.2)] = n
      }
    }
  }
  out
}

///|
/// The type each inferred declaration of a module lowered as one for every
/// configuration is declared with, where the configurations infer different
/// ones and one is a supertype of the others (see `declaration_choice`) -- or,
/// for a select of numbers wherever its values are not those of unreachable
/// code, `i32`, standing for any number, for an untyped select.
fn declared_types_of(
  tbl : FormTable,
  out : Map[(Int32, Int32), @wasm_types.ValType[@ast.Ident]],
) -> Unit {
  for key, e in tbl {
    let (kind, a, b) = key
    match e.1 {
      DeclarationForm(_, seen) if kind == "" && seen.length() >= 2 =>
        if declaration_choice(seen) is Some(t) {
          out[(a, b)] = t
        }
      DeclarationForm(SelectResult, []) if kind == "untyped" =>
        match tbl.get(("", a, b)) {
          None | Some((_, DeclarationForm(_, [("number", _)]))) =>
            out[(a, b)] = I32
          Some(_) => ()
        }
      _ => ()
    }
  }
}
