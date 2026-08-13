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
