// Module-level attribute validation.
//
// Ported from `check_attributes` in wax/src/lib-wax/typing.ml.
//
// These are the questions no single field can answer, because they are about the
// module as a whole: is this export name already taken, is there already a start
// function, is there already a module name. Each is decided per CONFIGURATION --
// two exports of the same name in mutually exclusive branches are not a clash,
// because only one of them is ever there.

///|
/// One remembered occurrence: the condition it was seen under, and where.
priv struct Occurrence {
  /// Not `guard`: that is a MoonBit keyword.
  when_ : @cond.T
  loc : @basic.Location
}

///|
/// The condition an attribute is actually present under.
///
/// The field's own branch assumption, narrowed by the attribute's optional
/// `if <cond>` guard -- only `export` and `start` carry one.
fn attribute_cond(
  ctx : @typing_env.ModuleContext,
  a : @ast.Attribute,
) -> @cond.T {
  match a.attr_guard {
    None => ctx.cond.val
    Some(g) =>
      @cond.and_(
        ctx.cond.val,
        ctx.cond_env.of_cond(ctx.diagnostics, g.info, g.desc),
      )
  }
}

///|
/// The first remembered occurrence whose condition can hold at the same time as
/// `cond`, if any.
fn clashes(seen : Array[Occurrence], cond : @cond.T) -> @basic.Location? {
  for o in seen {
    if @cond.is_satisfiable(@cond.and_(o.when_, cond)) {
      return Some(o.loc)
    }
  }
  None
}

///|
/// Check the module-wide attribute constraints.
///
/// `walk_fields` descends into conditionals under each branch's assumption, so
/// `ctx.cond` already says what configuration a field belongs to by the time it
/// is seen -- which is exactly what makes "same name, different branches" fine.
/// Reject unknown annotations, and check the value shape and the placement of
/// the ones that are allowed.
///
/// `import_ok` is set for the declarations inside an `import "m" { .. }` block,
/// where a name-only `#[import = "nm"]` overrides the imported name;
/// `priority_ok` for a DEFINED function, the only thing a compilation hint can
/// attach to -- an imported one has no code-section entry to key an offset-0
/// hint in.
fn check_attribute_list(
  ctx : @typing_env.ModuleContext,
  attributes : Array[@ast.Attribute],
  export_ok~ : Bool,
  start_ok~ : Bool,
  module_ok~ : Bool,
  import_ok~ : Bool,
  priority_ok? : Bool = false,
) -> Unit {
  let d = ctx.diagnostics
  fn is_string(v : @ast.Instr[@basic.Location]?) -> Bool {
    v is Some({ desc: Str(_, _), .. })
  }

  for a in attributes {
    // The whole `#[...]`. A valueless attribute has no value span to fall back
    // on, and the field's span would underline the entire definition.
    let location = a.attr_span
    // A guard is only meaningful on `export` and `start`; blame its own `if`.
    if a.attr_guard is Some(g) &&
      a.attr_name != "export" &&
      a.attr_name != "start" {
      guard_not_allowed(d, g.info, a.attr_name)
    }
    match a.attr_name {
      // A bare `#[export]` reuses the entity's Wax name; an explicit one must
      // be a string.
      "export" => {
        if !(a.attr_value is None) && !is_string(a.attr_value) {
          annotation_value_mismatch(d, location, "export", "a string")
        }
        if !export_ok {
          annotation_not_allowed(d, location, "export")
        }
      }
      "start" => {
        if a.attr_value is Some(_) {
          annotation_value_mismatch(d, location, "start", "no value")
        }
        if !start_ok {
          annotation_not_allowed(d, location, "start")
        }
      }
      "module" => {
        if !is_string(a.attr_value) {
          annotation_value_mismatch(d, location, "module", "a string")
        }
        if !module_ok {
          annotation_not_allowed(d, location, "module")
        }
      }
      // Allowed exactly where `module` is: as an inner attribute.
      "feature" => {
        if !is_string(a.attr_value) {
          annotation_value_mismatch(d, location, "feature", "a string")
        }
        if !module_ok {
          annotation_not_allowed(d, location, "feature")
        }
      }
      "import" => {
        if !is_string(a.attr_value) {
          annotation_value_mismatch(d, location, "import", "a string")
        }
        if !import_ok {
          annotation_not_allowed(d, location, "import")
        }
      }
      // IN RANGE as well as an integer: the section stores the priority as a
      // ULEB, and an over-long literal would otherwise reach the lowering's
      // parse and take it down.
      "priority" | "optimization" => {
        let ok = match a.attr_value {
          Some(v) =>
            match int_literal_u64(v.desc) {
              Some(n) => n < 0x1_0000_0000UL
              None => false
            }
          None => false
        }
        if !ok {
          annotation_value_mismatch(
            d,
            location,
            a.attr_name,
            "an integer in the u32 range",
          )
        }
        if !priority_ok {
          annotation_not_allowed(d, location, a.attr_name)
        }
      }
      "run_once" => {
        if a.attr_value is Some(_) {
          annotation_value_mismatch(d, location, "run_once", "no value")
        }
        if !priority_ok {
          annotation_not_allowed(d, location, "run_once")
        }
      }
      other => unknown_annotation(d, location, other)
    }
  }
  // The section states an optimization priority only alongside a compilation
  // one, and `run_once` is a spelling of a particular optimization value -- so
  // either without `#[priority]` would have nowhere to go. Rejected rather than
  // given a compilation priority the author did not choose.
  guard priority_ok else { return }
  fn find(k : String) -> @ast.Attribute? {
    for a in attributes {
      if a.attr_name == k {
        return Some(a)
      }
    }
    None
  }

  if find("priority") is None {
    for k in ["optimization", "run_once"] {
      if find(k) is Some(a) {
        priority_required(d, a.attr_span, k)
      }
    }
  }
  if find("optimization") is Some(a) && find("run_once") is Some(b) {
    conflicting_optimization(d, a.attr_span, b.attr_span)
  }
}

///|
pub fn check_attributes(
  ctx : @typing_env.ModuleContext,
  fields : @ast.Module[@basic.Location],
) -> Unit {
  let exports : Map[String, Array[Occurrence]] = Map([])
  let starts : Array[Occurrence] = []
  let mut module_seen : @basic.Location? = None
  fn visit(attrs : Array[@ast.Attribute], default_name : @ast.Ident?) -> Unit {
    for a in attrs {
      let cond = attribute_cond(ctx, a)
      match a.attr_name {
        "export" => {
          // The name and the span to blame: the explicit string for
          // `#[export = "nm"]`, the entity's own name for a bare `#[export]`.
          let entry = match a.attr_value {
            Some(v) =>
              match v.desc {
                Str(_, bytes) =>
                  match @unicode.utf8_text(bytes) {
                    Some(name) => Some((name, v.info))
                    None => None
                  }
                _ => None
              }
            None =>
              match default_name {
                Some(id) => Some((id.name, id.loc))
                None => None
              }
          }
          guard entry is Some((name, location)) else { continue }
          let seen = exports.get(name).unwrap_or([])
          if clashes(seen, cond) is Some(prev) {
            duplicated_export(ctx.diagnostics, location, prev, name)
          }
          seen.push({ when_: cond, loc: location })
          exports[name] = seen
        }
        "start" => {
          if clashes(starts, cond) is Some(prev) {
            multiple_start(ctx.diagnostics, a.attr_span, prev)
          }
          starts.push({ when_: cond, loc: a.attr_span })
        }
        // A module name is not guarded -- it states a fact about the whole
        // module, like a feature -- so one is simply one too many.
        "module" =>
          match module_seen {
            Some(prev) => multiple_module(ctx.diagnostics, a.attr_span, prev)
            None => module_seen = Some(a.attr_span)
          }
        _ => ()
      }
    }
  }

  // Where each annotation is meaningful. A compilation hint needs a body to
  // attach to, so only a DEFINED function may carry one.
  fn per_field(
    attributes : Array[@ast.Attribute],
    export_ok : Bool,
    start_ok : Bool,
    module_ok : Bool,
    priority_ok : Bool,
  ) -> Unit {
    check_attribute_list(
      ctx,
      attributes,
      export_ok~,
      start_ok~,
      module_ok~,
      import_ok=false,
      priority_ok~,
    )
  }

  walk_fields(ctx, fields, field => {
    match field.desc {
      Func(attributes~, ..) => per_field(attributes, true, true, false, true)
      Global(attributes~, ..)
      | Memory(attributes~, ..)
      | Table(attributes~, ..)
      | Tag(attributes~, ..) => per_field(attributes, true, false, false, false)
      ModuleAnnotation(attrs) => per_field(attrs, false, false, true, false)
      Data(attributes~, ..) | Elem(attributes~, ..) =>
        per_field(attributes, false, false, false, false)
      // An import's attributes hang off each declaration, and `#[import]` is
      // allowed only there.
      Import(decl~, ..) =>
        check_attribute_list(
          ctx,
          decl.desc.attributes,
          export_ok=true,
          start_ok=true,
          module_ok=false,
          import_ok=true,
        )
      ImportGroup(decls~, ..) =>
        for dd in decls {
          check_attribute_list(
            ctx,
            dd.desc.attributes,
            export_ok=true,
            start_ok=true,
            module_ok=false,
            import_ok=true,
          )
        }
      Type(_) | Conditional(..) => ()
    }
  })
  walk_fields(ctx, fields, field => {
    match field.desc {
      Func(name~, attributes~, ..) => visit(attributes, Some(name))
      Global(name~, attributes~, ..) => visit(attributes, Some(name))
      Tag(name~, attributes~, ..) => visit(attributes, Some(name))
      Memory(name~, attributes~, ..) => visit(attributes, Some(name))
      Table(name~, attributes~, ..) => visit(attributes, Some(name))
      Data(name~, attributes~, ..) => visit(attributes, name)
      Elem(name~, attributes~, ..) => visit(attributes, Some(name))
      ModuleAnnotation(attrs) => visit(attrs, None)
      Import(decl~, ..) => visit(decl.desc.attributes, Some(decl.desc.id))
      ImportGroup(decls~, ..) =>
        for d in decls {
          visit(d.desc.attributes, Some(d.desc.id))
        }
      Type(_) | Conditional(..) => ()
    }
  })
}
