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
/// Resolve every attribute guard.
///
/// A guard gates the presence of just this attribute, so it partitions the
/// space exactly as an `#[if]` block does. The guard itself is dropped: in each
/// explored configuration the export is present or absent outright.
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
          _ => [{ ..a, attr_guard: None }],
          _ => [],
        )
        for k in kept {
          out.push(k)
        }
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
    IfAnnotation(cond~, then_body~, else_body~) =>
      self.choose(under, cond, i.info, u => self.instrs(u, then_body.desc), u => {
        match else_body {
          Some(e) => self.instrs(u, e.desc)
          None => []
        }
      })
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
  ({ ..d, desc: { ..d.desc, attributes, } }, under)
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
      ([{ ..f, desc: Tag(name~, typ~, sign~, attributes~) }], under)
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
      ([{ ..f, desc: Import(module_~, decl~) }], under)
    }
    ImportGroup(module_~, decls~) => {
      let out = []
      let mut under = under
      for d in decls {
        let (d2, next) = self.decl(under, d)
        out.push(d2)
        under = next
      }
      ([{ ..f, desc: ImportGroup(module_~, decls=out) }], under)
    }
    ModuleAnnotation(a) => {
      let (a, under) = self.attrs(under, a)
      ([{ ..f, desc: ModuleAnnotation(a) }], under)
    }
    Type(_) | Data(..) | Elem(..) => ([f], under)
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
  ({ env, diagnostics, enqueue, record } : Configuring).fields(
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
/// An attribute GUARD does not count, though the specializer resolves one. A
/// guard gates a single export, not a program: the module compiles to the same
/// code either way, and treating it as a configuration would only hide the
/// checks on the guard itself -- the specializer strips a guard once it has
/// chosen, so a guard written where it is not allowed would go unreported.
fn module_has_conditional(fields : @ast.Module[@basic.Location]) -> Bool {
  fn in_instr(i : @ast.Instr[@basic.Location]) -> Bool {
    if i.desc is IfAnnotation(..) {
      return true
    }
    i.sub_instrs().iter().any(in_instr)
  }

  fn in_field(
    f : @basic.Annotated[@ast.ModuleField[@basic.Location], @basic.Location],
  ) -> Bool {
    match f.desc {
      Conditional(..) => true
      Func(body~, ..) => body.1.iter().any(in_instr)
      Global(def~, ..) => in_instr(def)
      _ => false
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
  simplify? : Bool = false,
  warn_unused? : Bool = false,
) -> Unit {
  ignore(store)
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
      )
      declare_fields(ctx, cfg)
      check_attributes(ctx, cfg)
      ignore(check_fields(ctx, Operands::new(), cfg))
      warn_unused_fields(ctx, cfg)
    },
    truncation_location=match fields {
      [hd, ..] => Some(hd.info)
      [] => None
    },
    explain=Some((env, c) => env.explain(c, style=Wax)),
  )
}
