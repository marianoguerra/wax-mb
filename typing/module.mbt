// Checking a module, field by field.
//
// Ported from `type_configuration` in wax/src/lib-wax/typing.ml.
//
// The declaration pass has already registered every name; this is the second
// walk, which checks what each field actually contains. The two are separate
// because a function may call one defined below it -- but the ORDER within this
// pass still matters, and for a different reason: a global initializer may read
// the globals declared before it and not those after, so globals are registered
// here, as they are checked, rather than up front.

///|
/// Check every field of a module, returning the typed form.
///
/// Ordering, and why each part of it is where it is:
///
///   * The imported globals are snapshotted first. A table initializer sees
///     only those -- it runs before the module's own globals exist.
///   * Globals are checked and registered one at a time, so an initializer
///     sees exactly what precedes it.
///   * Everything else follows, by which point every global is in scope.
pub fn check_fields(
  ctx : @typing_env.ModuleContext,
  ops : Operands,
  fields : @ast.Module[@basic.Location],
) -> Array[
  @basic.Annotated[
    @ast.ModuleField[@typing_env.InferredAnnotation],
    @basic.Location,
  ],
] {
  // Only the imports are registered at this point, so this IS the scope a
  // table initializer may see.
  for name in ctx.globals.names() {
    for g in ctx.globals.visible(name) {
      ctx.import_globals.add(ctx.diagnostics, name, @basic.dummy_loc, g)
    }
  }
  let checker = Checker::new(ctx, ops)
  // Collected by POSITION, not by pass: the two phases below visit the fields
  // in the same order, so a counter in each lines them up -- and the typed
  // module comes out in SOURCE order, which the printer and the lowering both
  // depend on.
  let typed : Map[Int, @ast.ModuleField[@typing_env.InferredAnnotation]] = Map([])
  let spans : Map[Int, @basic.Location] = Map([])
  let mut at = 0
  // Globals first, in order, each visible to the next.
  walk_fields(ctx, fields, field => {
    let here = at
    at = at + 1
    spans[here] = field.info
    guard field.desc is Global(name~, mut_~, typ~, def~, attributes~) else {
      return
    }
    let declared = match typ {
      Some(t) => internalize_valtype(ctx.type_context, ctx.diagnostics, t)
      None => None
    }
    // An annotated global checks its initializer against the annotation, so a
    // construction there can take the global's type as its own.
    let def_ = match declared {
      Some(v) => checker.check(@infer.valtype_cell(v), def)
      None => checker.expression(def)
    }
    // An unannotated global takes its initializer's type, resolved to a width
    // -- there is no later context to pin it, so it has to commit here.
    let entry = match declared {
      Some(v) => Some(v)
      None => bound_value_type(ctx, def.info, expression_type(ctx, def_.info))
    }
    ctx.globals.add(ctx.diagnostics, name.name, name.loc, (mut_, entry))
    typed[here] = Global(name~, mut_~, typ~, def=def_, attributes~)
  })
  let total = at
  // Then everything else, with every global now in scope.
  at = 0
  walk_fields(ctx, fields, field => {
    let here = at
    at = at + 1
    if check_field(ctx, checker, field) is Some(c) {
      typed[here] = c
    }
  })
  let out : Array[
    @basic.Annotated[
      @ast.ModuleField[@typing_env.InferredAnnotation],
      @basic.Location,
    ],
  ] = []
  for k in 0..<total {
    if typed.get(k) is Some(desc) && spans.get(k) is Some(info) {
      out.push({ desc, info })
    }
  }
  out
}

///|
/// Check one non-global field.
///
/// `None` for a global, which the first pass already handled, and for the
/// fields that declare without containing anything to check.
fn check_field(
  ctx : @typing_env.ModuleContext,
  checker : Checker,
  field : @basic.Annotated[@ast.ModuleField[@basic.Location], @basic.Location],
) -> @ast.ModuleField[@typing_env.InferredAnnotation]? {
  let i32c = () => @infer.valtype_cell(@infer.i32_valtype)
  fn want(
    e : @ast.Instr[@basic.Location],
    checked : @ast.Instr[@typing_env.InferredAnnotation],
    cell : @infer.Cell[@infer.InferredType],
    location : @basic.Location,
  ) -> Unit {
    ignore(e)
    check_subtype(
      ctx.type_context.subtyping_info(),
      ctx.diagnostics,
      location,
      expression_type(ctx, checked.info),
      cell,
    )
  }

  match field.desc {
    Global(..) => None
    Func(name~, typ~, sign~, body~, attributes~) => {
      let (label, instrs) = body
      let returns = enter_function_scope(ctx, name, sign, attributes)
      // The body runs on its own empty stack and must leave exactly the
      // function's results -- the same rule as any block, with the function's
      // own frame as the target.
      let checked = checker.body(
        field.info,
        label,
        [],
        returns,
        returns,
        instrs,
      )
      leave_function_scope(ctx)
      Some(Func(name~, typ~, sign~, body=(label, checked), attributes~))
    }
    Table(name~, address_type~, reftype~, limits~, init~, attributes~) => {
      let init_ = match init {
        Some(e) =>
          Some(
            match internalize(ctx.type_context, ctx.diagnostics, Ref(reftype)) {
              Some(elt) => checker.check(elt, e)
              None => checker.expression(e)
            },
          )
        None => None
      }
      ignore(name)
      Some(
        Table(name~, address_type~, reftype~, limits~, init=init_, attributes~),
      )
    }
    Elem(name~, reftype~, mode~, init~, attributes~) => {
      let elt = internalize(ctx.type_context, ctx.diagnostics, Ref(reftype))
      let checked = init.map(e => {
        match elt {
          Some(t) => checker.check(t, e)
          None => checker.expression(e)
        }
      })
      // An ACTIVE segment names a table and an offset into it; a passive one is
      // only a list of values until something uses it.
      let mode_ = match mode {
        EPassive => @ast.ElemMode::EPassive
        EActive(tab, offset) => {
          let o = checker.statement(offset)
          let at = match ctx.tables.find_no_mark(tab.name) {
            Some((a, _)) => address_cell(a)
            None => i32c()
          }
          want(offset, o, at, field.info)
          EActive(tab, o)
        }
      }
      Some(Elem(name~, reftype~, mode=mode_, init=checked, attributes~))
    }
    Data(name~, mode~, init~, attributes~) => {
      let mode_ = match mode {
        Passive => @ast.DataMode::Passive
        Active(mem, offset) => {
          let o = checker.statement(offset)
          let at = match ctx.memories.find_no_mark(mem.name) {
            Some((_, a)) => address_cell(a)
            None => i32c()
          }
          want(offset, o, at, field.info)
          Active(mem, o)
        }
      }
      Some(Data(name~, mode=mode_, init~, attributes~))
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
      // An inline data segment's offset indexes THIS memory, so it takes its
      // address type rather than a default.
      let at = address_cell(address_type)
      let data_ = data.map(d => {
        let o = checker.statement(d.offset)
        want(d.offset, o, at, field.info)
        (
          { data_name: d.data_name, offset: o, init: d.init } :
          @ast.MemData[@typing_env.InferredAnnotation])
      })
      Some(
        Memory(
          name~,
          address_type~,
          limits~,
          page_size_log2~,
          shared~,
          data=data_,
          attributes~,
        ),
      )
    }
    // Nothing to check: these declare and contain no instructions.
    Type(g) => Some(Type(g))
    Tag(name~, typ~, sign~, attributes~) =>
      Some(Tag(name~, typ~, sign~, attributes~))
    ModuleAnnotation(a) => Some(ModuleAnnotation(a))
    // The walker resolves these before the callback sees them.
    Import(..) | ImportGroup(..) | Conditional(..) => None
  }
}

///|
/// Check one configuration of one module: declare every name, then check every
/// field.
///
/// The two passes are the whole shape of the checker. Nothing can be checked
/// until every name exists, because a function may call one defined below it;
/// and the names cannot be given types until the types are registered, which is
/// why the declaration pass has its own internal order.
pub fn check_module(
  diagnostics : @diagnostic.Context,
  store : @type_store.TypeStore,
  features : @feature.Set,
  fields : @ast.Module[@basic.Location],
  simplify? : Bool = false,
  warn_unused? : Bool = false,
) -> (
  @typing_env.ModuleContext,
  Array[
    @basic.Annotated[
      @ast.ModuleField[@typing_env.InferredAnnotation],
      @basic.Location,
    ],
  ],
) {
  let ctx = @typing_env.ModuleContext::new(
    diagnostics,
    store,
    features,
    simplify~,
    warn_unused~,
  )
  // Before anything asks whether a feature is enabled: what the module declares
  // is part of its configuration, not a fact about one of its fields.
  apply_declared_features(diagnostics, features, fields)
  declare_fields(ctx, fields)
  let typed = check_fields(ctx, Operands::new(), fields)
  (ctx, typed)
}

///|
/// Turn on every feature the module DECLARES, before anything asks whether one
/// is enabled.
///
/// A `#![feature = "..."]` states a fact about the whole module, so only a
/// top-level annotation counts and one inside a conditional is a misplacement
/// rather than a guarded declaration -- it is resolved before any branch is
/// specialized, so a guarded one would leave every construct it gates erroring
/// whichever way the branch went.
///
/// A feature the command line explicitly turned off is a conflict, reported once
/// here -- and then enabled anyway, because the alternative is to report it
/// again at every construct that needed it.
pub fn apply_declared_features(
  diagnostics : @diagnostic.Context,
  features : @feature.Set,
  fields : @ast.Module[@basic.Location],
) -> Unit {
  fn reject(
    fs : Array[
      @basic.Annotated[@ast.ModuleField[@basic.Location], @basic.Location],
    ],
  ) -> Unit {
    for f in fs {
      match f.desc {
        ModuleAnnotation(attrs) =>
          for a in attrs {
            if a.attr_name == "feature" {
              feature_declaration_in_conditional(diagnostics, a.attr_span)
            } else if a.attr_name == "module" {
              module_name_in_conditional(diagnostics, a.attr_span)
            }
          }
        Conditional(then_fields~, else_fields~, ..) => {
          reject(then_fields.desc)
          if else_fields is Some(e) {
            reject(e.desc)
          }
        }
        _ => ()
      }
    }
  }

  for field in fields {
    match field.desc {
      ModuleAnnotation(attrs) =>
        for a in attrs {
          guard a.attr_name == "feature" else { continue }
          guard a.attr_value is Some(v) else { continue }
          guard v.desc is Str(_, bytes) else { continue }
          guard @unicode.utf8_text(bytes) is Some(name) else { continue }
          match @feature.of_name(name) {
            None => unknown_feature(diagnostics, v.info, name)
            Some(f) => {
              if features.explicitly_disabled(f) {
                feature_conflict(diagnostics, v.info, f)
              }
              features.declare_feature(f)
            }
          }
        }
      Conditional(then_fields~, else_fields~, ..) => {
        reject(then_fields.desc)
        if else_fields is Some(e) {
          reject(e.desc)
        }
      }
      _ => ()
    }
  }
}
