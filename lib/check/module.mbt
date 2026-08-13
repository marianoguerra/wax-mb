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
  // table initializer may see. Copied rather than re-declared: a snapshot is not
  // a second declaration, and adding the names again would report every one that
  // is visible under more than one configuration as already bound.
  ctx.globals.copy_entries_into(ctx.import_globals)
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
    check_constant_instruction(ctx, def_)
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
      // The labels this body declares, collected up front: the unused-label
      // lint needs the whole SET, and the checker only ever sees them one scope
      // at a time.
      let returns = enter_function_scope(
        ctx,
        name,
        sign,
        attributes,
        label_decls=collect_labels(instrs),
      )
      // The source-shape lints read what was WRITTEN, so they run over the
      // original body -- and BEFORE it is typed, because the typing reports as
      // it goes (dead code, chiefly) and the two streams interleave by the order
      // they are produced, not by span.
      if ctx.warn_unused {
        for s in instrs {
          lint_source(ctx, s)
        }
      }
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
      // Before leaving the scope, while the locals and labels this function
      // declared are still the current ones -- and here rather than at the end
      // of the module, so the diagnostics stay in source order among the rest.
      // The lints that had to wait for their cells to be pinned: run here, in
      // this function, so their diagnostics stay in source order among the rest
      // rather than all landing at the end of the module.
      flush_deferred_lints(ctx)
      warn_unused_in_function(ctx)
      leave_function_scope(ctx)
      Some(Func(name~, typ~, sign~, body=(label, checked), attributes~))
    }
    Table(name~, address_type~, reftype~, limits~, init~, attributes~) => {
      check_limits(ctx, field.info, "table", address_type, limits)
      // Without an initializer a table is filled with its element type's
      // default value, which a non-nullable reference does not have.
      if init is None && !reftype.nullable {
        non_nullable_table(ctx.diagnostics, field.info)
      }
      let init_ = match init {
        Some(e) =>
          Some(
            ctx.with_import_globals(() => {
              let checked = match
                internalize(ctx.type_context, ctx.diagnostics, Ref(reftype)) {
                Some(elt) => checker.check(elt, e)
                None => checker.expression(e)
              }
              check_constant_instruction(ctx, checked)
              checked
            }),
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
        let c = match elt {
          Some(t) => checker.check(t, e)
          None => checker.expression(e)
        }
        check_constant_instruction(ctx, c)
        c
      })
      // An ACTIVE segment names a table and an offset into it; a passive one is
      // only a list of values until something uses it.
      let mode_ = match mode {
        EPassive => @ast.ElemMode::EPassive
        EActive(tab, offset) => {
          // An active segment NAMES its table -- a use of it, and a place the
          // name can be wrong, so the lookup both marks and reports.
          let resolved = find(ctx.tables, ctx.diagnostics, tab)
          let o = checker.statement(offset)
          let at = match resolved {
            Some((a, _)) => address_cell(a)
            None => i32c()
          }
          want(offset, o, at, field.info)
          check_constant_instruction(ctx, o)
          EActive(tab, o)
        }
      }
      Some(Elem(name~, reftype~, mode=mode_, init=checked, attributes~))
    }
    Data(name~, mode~, init~, attributes~) => {
      let mode_ = match mode {
        Passive => @ast.DataMode::Passive
        Active(mem, offset) => {
          let resolved = find(ctx.memories, ctx.diagnostics, mem)
          let o = checker.statement(offset)
          let at = match resolved {
            Some((_, a)) => address_cell(a)
            None => i32c()
          }
          want(offset, o, at, field.info)
          check_constant_instruction(ctx, o)
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
      check_limits(
        ctx,
        field.info,
        "memory",
        address_type,
        limits,
        page_size_log2~,
        shared~,
      )
      // An inline data segment's offset indexes THIS memory, so it takes its
      // address type rather than a default.
      let at = address_cell(address_type)
      let data_ = data.map(d => {
        let o = checker.statement(d.offset)
        want(d.offset, o, at, field.info)
        check_constant_instruction(ctx, o)
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
  // Before anything asks whether a feature is enabled: what the module declares
  // is part of its configuration, not a fact about one of its fields.
  apply_declared_features(diagnostics, features, fields)
  // Before anything else: a bidirectional control character is invisible, so it
  // has no shape for a later pass to notice -- only a walk over every place a
  // string can hide will find one. It is a fact about the SOURCE, so it is
  // asked once whatever the configuration.
  if warn_unused {
    lint_confusable(diagnostics, fields)
  }
  // A module with `#[if]` in it is a FAMILY of programs, and most of what the
  // checker asks -- whether a value is left on the stack, whether a local is
  // ever read -- has a different answer in each. So its diagnostics come from
  // checking every reachable configuration on its own, and the tree built below
  // (which the printer and the lowering consume, conditionals and all) is built
  // with its diagnostics DISCARDED: they would be the answers to questions
  // asked of a program that is not any of the ones being compiled.
  let conditional = module_has_conditional(fields)
  if conditional {
    check_let_bindings(diagnostics, fields)
    check_configurations(
      diagnostics,
      store,
      features,
      fields,
      simplify~,
      warn_unused~,
    )
  }
  let build_diagnostics = if conditional {
    @diagnostic.collector(parent=Some(diagnostics))
  } else {
    diagnostics
  }
  let ctx = @typing_env.ModuleContext::new(
    build_diagnostics,
    store,
    features,
    simplify~,
    warn_unused~,
  )
  declare_fields(ctx, fields)
  // The module-wide attribute constraints -- one export per name, one start,
  // one module name -- which no single field can answer on its own.
  check_attributes(ctx, fields)
  let typed = check_fields(ctx, Operands::new(), fields)
  // Last: what counts as a USE of a module field is what reached it while every
  // body was checked, so this cannot be answered until they all have been.
  warn_unused_fields(ctx, fields)
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
