// Rewriting the legacy `try_legacy` into the structured `try`.
//
// Ported from wax/src/lib-wax/legacy_eh.ml.
//
// The two differ only in where a handler's completion goes: a legacy handler
// exits the whole construct, a structured arm falls into the next arm. So every
// arm but the last gets a trailing `br` to the try's label carrying the try's
// result -- one `_` hole per value -- unless it already ends by diverging. A
// try that needs such a branch and has no label gets a fresh one, distinct from
// every label of its function so that no branch is captured by it.

///|
/// Rewrite every `try_legacy` of `m` into the structured `try`, which lowers to
/// the standard `try_table` (`--try-table` on a Wax-to-Wax conversion).
///
/// `typed` is `m` as the checker typed it: an unannotated try takes its result
/// type from its context, and the typed tree says how many values each one
/// yields, which is how many holes its arms' exits carry.
pub fn rewrite_legacy_try(
  diagnostics : @diagnostic.Context,
  typed : Array[
    @basic.Annotated[
      @ast.ModuleField[@typing_env.InferredAnnotation],
      @basic.Location,
    ],
  ],
  m : @ast.Module[@basic.Location],
) -> @ast.Module[@basic.Location] {
  let arities : Map[(Int32, Int32), Int32] = Map([])
  fn record(i : @ast.Instr[@typing_env.InferredAnnotation]) -> Unit {
    if i.desc is Try(..) {
      arities[(i.info.1.start.cnum, i.info.1.end.cnum)] = i.info.0.length()
    }
    for x in i.sub_instrs() {
      record(x)
    }
  }

  fn record_fields(
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
            record(x)
          }
        Conditional(then_fields~, else_fields~, ..) => {
          record_fields(then_fields.desc)
          if else_fields is Some(e) {
            record_fields(e.desc)
          }
        }
        _ => ()
      }
    }
  }

  record_fields(typed)
  fn field(
    f : @basic.Annotated[@ast.ModuleField[@basic.Location], @basic.Location],
  ) -> @basic.Annotated[@ast.ModuleField[@basic.Location], @basic.Location] {
    match f.desc {
      Func(name~, typ~, sign~, body~, attributes~) => {
        let used = defined_labels(body)
        let instrs = body.1.map(i => rewrite_try(diagnostics, arities, used, i))
        {
          ..f,
          desc: Func(name~, typ~, sign~, body=(body.0, instrs), attributes~),
        }
      }
      Conditional(cond~, then_fields~, else_fields~) =>
        {
          ..f,
          desc: Conditional(
            cond~,
            then_fields={ ..then_fields, desc: then_fields.desc.map(field), },
            else_fields=else_fields.map(e => { ..e, desc: e.desc.map(field), }),
          ),
        }
      // A legacy try in an initializer is invalid (not constant) anyway.
      _ => f
    }
  }

  m.map(field)
}

///|
/// The labels a function defines, its body's own included. A fresh label
/// distinct from all of them can neither shadow an enclosing label nor be
/// shadowed by a nested one.
fn defined_labels(
  body : (@ast.Ident?, Array[@ast.Instr[@basic.Location]]),
) -> Array[String] {
  let acc : Array[String] = []
  if body.0 is Some(l) {
    acc.push(l.name)
  }
  fn go(i : @ast.Instr[@basic.Location]) -> Unit {
    match i.desc {
      Block(label~, ..)
      | Loop(label~, ..)
      | While(label~, ..)
      | If(label~, ..)
      | TryTable(label~, ..)
      | Try(label~, ..)
      | TryCatch(label~, ..) => if label is Some(l) { acc.push(l.name) }
      Dispatch(arms~, ..) =>
        for a in arms {
          acc.push(a.0.name)
        }
      _ => ()
    }
    for x in i.sub_instrs() {
      go(x)
    }
  }

  for i in body.1 {
    go(i)
  }
  acc
}

///|
/// A label no other in the function uses: `join`, else `join1`, `join2`, ...
fn fresh_join(used : Array[String]) -> String {
  let mut k = 0
  while true {
    let name = if k == 0 { "join" } else { "join" + k.to_string() }
    if !used.contains(name) {
      used.push(name)
      return name
    }
    k = k + 1
  }
  "join"
}

///|
/// Whether a handler body certainly ends by diverging, so that nothing follows
/// it. A conservative syntactic check: an arm it misses only gets a dead `br`.
fn handler_diverges(body : Array[@ast.Instr[@basic.Location]]) -> Bool {
  match body.last() {
    Some(
      {
        desc: Unreachable
        | Br(_, _)
        | BrTable(_, _)
        | Return(_)
        | TailCall(_, _)
        | Throw(_, _)
        | ThrowRef(_),
        ..
      }
    ) => true
    _ => false
  }
}

///|
/// Rewrite the legacy tries in `i`, bottom-up, so a nested one is rewritten
/// before the one around it.
fn rewrite_try(
  diagnostics : @diagnostic.Context,
  arities : Map[(Int32, Int32), Int32],
  used : Array[String],
  i : @ast.Instr[@basic.Location],
) -> @ast.Instr[@basic.Location] {
  let desc = i.desc.map_desc(
    instr=x => rewrite_try(diagnostics, arities, used, x),
    block=l => l.map(x => rewrite_try(diagnostics, arities, used, x)),
  )
  let i = { ..i, desc, }
  guard i.desc is Try(label~, typ~, block~, catches~, catch_all~) else {
    return i
  }
  // The structured try takes no parameters, nor could its handler ladder
  // pass them through.
  if !typ.params.is_empty() {
    diagnostics.report(
      i.info,
      Error,
      @message.text(
        "This legacy try takes parameters, which a structured try cannot take.",
      ),
      hint=Some(
        @message.text("Pass the values to its body through locals instead."),
      ),
    )
    return i
  }
  let arity = arities
    .get((i.info.start.cnum, i.info.end.cnum))
    .unwrap_or(typ.results.length())
  let handlers : Array[(@ast.Ident?, @ast.Body[@basic.Location])] = catches.map(c => {
      (Some(c.0), c.1)
    },
  )
  if catch_all is Some(b) {
    handlers.push((None, b))
  }
  // Every handler but the last exits the construct explicitly.
  let exits = handlers.mapi((k, h) => {
    k < handlers.length() - 1 && !handler_diverges(h.1.desc)
  })
  let label = match label {
    Some(_) => label
    None if exits.contains(true) =>
      Some({ name: fresh_join(used), loc: @basic.dummy_loc, })
    None => None
  }
  fn hole() -> @ast.Instr[@basic.Location] {
    @ast.build(Hole, @basic.dummy_loc)
  }

  fn br() -> @ast.Instr[@basic.Location] {
    let value = match arity {
      0 => None
      1 => Some(hole())
      n =>
        Some(
          @ast.build(Sequence(Array::makei(n, _ => hole())), @basic.dummy_loc),
        )
    }
    @ast.build(Br(label.unwrap(), value), @basic.dummy_loc)
  }

  // A trailing statement of bare holes (`_;`, `(_, _);`) only leaves the
  // values on the stack, which the `br`'s own holes then take: it goes.
  fn with_exit(
    l : Array[@ast.Instr[@basic.Location]],
  ) -> Array[@ast.Instr[@basic.Location]] {
    let rest = if l.is_empty() { [] } else { l[:l.length() - 1].to_owned() }
    match l.last() {
      Some({ desc: Hole, .. }) if arity == 1 => [..rest, br()]
      Some({ desc: Sequence(s), .. }) if arity > 1 &&
        s.length() == arity &&
        s.iter().all(x => x.desc is Hole) => [..rest, br()]
      _ => [..l, br()]
    }
  }

  let arms = handlers.mapi((k, h) => {
    let arm_body = if exits[k] {
      { ..h.1, desc: with_exit(h.1.desc), }
    } else {
      h.1
    }
    (
      { arm_tag: h.0, arm_ref: false, arm_types: [], arm_body, } :
      @ast.TryCatchArm[@basic.Location])
  })
  { ..i, desc: TryCatch(label~, typ~, block~, arms~), }
}
