// Typing a function body that holds `#[if]` groups, for the lowering.
//
// Ported from the body half of `Cond_plan` and `stitch` in
// wax/src/lib-wax/typing.ml.
//
// A body-level `#[if]` is not a block: its branch's instructions run on the
// enclosing stack, as if written in place, and the names its branch reads --
// a parameter's conditional alias, say -- mean what they mean in that branch.
// No single typing gets every branch right, so the body is typed once per RUN:
// each run selects one side of every `#[if]` it reaches, types the selected
// instructions in line under the assumption the selection makes, and leaves the
// other side to the run that selects it. The runs' trees are then STITCHED --
// the first run's, each branch it did not select taken from its owner's.
//
// The module-level conditionals need none of this: `walk_fields` already types
// a field under its own branch's assumption.

///|
/// A body-level `#[if]`, by span.
type IfKey = (Int32, Int32)

///|
fn if_key(loc : @basic.Location) -> IfKey {
  (loc.start.cnum, loc.end.cnum)
}

///|
/// Whether a body holds an `#[if]` anywhere.
fn has_if_annotation(instrs : Array[@ast.Instr[@basic.Location]]) -> Bool {
  fn go(i : @ast.Instr[@basic.Location]) -> Bool {
    i.desc is IfAnnotation(..) || i.sub_instrs().iter().any(go)
  }

  instrs.iter().any(go)
}

///|
/// One run: the side it selects of every `#[if]` it reaches, and the
/// assumption the selection makes.
priv struct BodyRun {
  select : Map[IfKey, Bool]
  assumption : @cond.T
}

///|
/// Choose the sides of every `#[if]` a run reaches, preferring `then` where it
/// can hold -- what the reference's primary run selects -- and forcing the
/// ones on the way to `target`, when there is one.
fn choose_run(
  ctx : @typing_env.ModuleContext,
  instrs : Array[@ast.Instr[@basic.Location]],
  base : @cond.T,
  target : (IfKey, Bool)?,
) -> BodyRun {
  let select : Map[IfKey, Bool] = Map([])
  let mut assumption = base
  fn contains(l : Array[@ast.Instr[@basic.Location]], key : IfKey) -> Bool {
    fn go(i : @ast.Instr[@basic.Location]) -> Bool {
      (i.desc is IfAnnotation(..) && if_key(i.info) == key) ||
      i.sub_instrs().iter().any(go)
    }

    l.iter().any(go)
  }

  fn visit(l : Array[@ast.Instr[@basic.Location]]) -> Unit {
    for i in l {
      match i.desc {
        IfAnnotation(cond~, then_body~, else_body~) => {
          let key = if_key(i.info)
          let c = ctx.cond_env.of_cond(ctx.diagnostics, i.info, cond)
          let else_desc = match else_body {
            Some(b) => b.desc
            None => []
          }
          let side = match target {
            Some((k, s)) if k == key => s
            Some((k, _)) if contains(then_body.desc, k) => true
            Some((k, _)) if contains(else_desc, k) => false
            _ => @cond.is_satisfiable(@cond.and_(assumption, c))
          }
          select[key] = side
          assumption = @cond.and_(
            assumption,
            if side {
              c
            } else {
              @cond.not_(c)
            },
          )
          visit(if side { then_body.desc } else { else_desc })
        }
        _ => visit(i.sub_instrs())
      }
    }
  }

  visit(instrs)
  { select, assumption, }
}

///|
/// The runs a body needs: the primary, then one for each side no earlier run
/// selected, as long as its assumption can hold. A side no configuration
/// reaches keeps its placeholder.
fn plan_body_runs(
  ctx : @typing_env.ModuleContext,
  instrs : Array[@ast.Instr[@basic.Location]],
) -> Array[BodyRun] {
  let base = ctx.cond.val
  let runs = [choose_run(ctx, instrs, base, None)]
  let covered : Set[(IfKey, Bool)] = Set([])
  for k, s in runs[0].select {
    covered.add((k, s))
  }
  let sides : Array[(IfKey, Bool)] = []
  fn collect(l : Array[@ast.Instr[@basic.Location]]) -> Unit {
    for i in l {
      match i.desc {
        IfAnnotation(then_body~, else_body~, ..) => {
          sides.push((if_key(i.info), true))
          sides.push((if_key(i.info), false))
          collect(then_body.desc)
          if else_body is Some(b) {
            collect(b.desc)
          }
        }
        _ => collect(i.sub_instrs())
      }
    }
  }

  collect(instrs)
  for side in sides {
    if covered.contains(side) || runs.length() >= MAX_BODY_RUNS {
      continue
    }
    let run = choose_run(ctx, instrs, base, Some(side))
    guard @cond.is_satisfiable(run.assumption) else { continue }
    for k, s in run.select {
      covered.add((k, s))
    }
    runs.push(run)
  }
  runs
}

///|
/// A bound on the runs one body takes. Each is a full typing of the body, and
/// a body this conditional is better served by `-D` than by a long wait.
const MAX_BODY_RUNS : Int32 = 64

///|
/// Stitch the runs' typed bodies into one: the first run's, each `#[if]` side
/// it did not select taken from the run that did.
fn stitch_body_runs(
  runs : Array[BodyRun],
  typed : Array[Array[@ast.Instr[@typing_env.InferredAnnotation]]],
) -> Array[@ast.Instr[@typing_env.InferredAnnotation]] {
  let fills : Map[
    (IfKey, Bool),
    Array[@ast.Instr[@typing_env.InferredAnnotation]],
  ] = Map([])
  fn own(
    run : BodyRun,
    l : Array[@ast.Instr[@typing_env.InferredAnnotation]],
  ) -> Unit {
    for i in l {
      match i.desc {
        IfAnnotation(then_body~, else_body~, ..) => {
          let key = if_key(i.info.1)
          guard run.select.get(key) is Some(side) else { continue }
          let body = if side {
            then_body.desc
          } else {
            match else_body {
              Some(b) => b.desc
              None => []
            }
          }
          if !fills.contains((key, side)) {
            fills[(key, side)] = body
          }
          own(run, body)
        }
        _ => own(run, i.sub_instrs())
      }
    }
  }

  for k, run in runs {
    own(run, typed[k])
  }
  fn fill(
    i : @ast.Instr[@typing_env.InferredAnnotation],
  ) -> @ast.Instr[@typing_env.InferredAnnotation] {
    match i.desc {
      IfAnnotation(cond~, then_body~, else_body~) => {
        let key = if_key(i.info.1)
        let then_ = fills.get((key, true)).unwrap_or(then_body.desc)
        let else_ = else_body.map(b => {
          ..b,
          desc: fills.get((key, false)).unwrap_or(b.desc).map(fill),
        })
        {
          ..i,
          desc: IfAnnotation(
            cond~,
            then_body={ ..then_body, desc: then_.map(fill), },
            else_body=else_,
          ),
        }
      }
      _ => { ..i, desc: i.desc.map_desc(instr=fill, block=l => l.map(fill)), }
    }
  }

  typed[0].map(fill)
}

///|
/// What one instruction of a list became once the selected sides of its
/// `#[if]`s were laid out in line: itself, or the selected side of an `#[if]`.
priv enum InlineShape {
  Plain
  Selected(@ast.Instr[@basic.Location], Bool, Array[InlineShape])
}

///|
/// Lay the selected side of each `#[if]` of `instrs` out in line, recursively,
/// for a run that selects them.
fn inline_selected(
  select : Map[IfKey, Bool],
  instrs : Array[@ast.Instr[@basic.Location]],
  flat : Array[@ast.Instr[@basic.Location]],
) -> Array[InlineShape] {
  let shapes : Array[InlineShape] = []
  for i in instrs {
    match i.desc {
      IfAnnotation(then_body~, else_body~, ..) if select.get(if_key(i.info))
        is Some(side) => {
        let body = if side {
          then_body.desc
        } else {
          match else_body {
            Some(b) => b.desc
            None => []
          }
        }
        shapes.push(Selected(i, side, inline_selected(select, body, flat)))
      }
      _ => {
        flat.push(i)
        shapes.push(Plain)
      }
    }
  }
  shapes
}

///|
/// Put the `#[if]`s back around the instructions typed in line, each with its
/// side typed and the other a placeholder the stitching replaces.
fn Checker::regroup_selected(
  self : Checker,
  shapes : Array[InlineShape],
  typed : Array[@ast.Instr[@typing_env.InferredAnnotation]],
  next : Ref[Int32],
) -> Array[@ast.Instr[@typing_env.InferredAnnotation]] {
  let out = []
  for shape in shapes {
    match shape {
      Plain => {
        out.push(typed[next.val])
        next.val = next.val + 1
      }
      Selected(i, side, inner) => {
        let mine = self.regroup_selected(inner, typed, next)
        guard i.desc is IfAnnotation(cond~, then_body~, else_body~) else {
          continue
        }
        // The other side as a placeholder: typed on its own, as a block,
        // which is what a run that never selects it would leave.
        let placeholder = (b : @ast.Body[@basic.Location], positive : Bool) => {
          with_cond(self.ctx, i.info, cond, positive, () => {
            self.body(i.info, None, [], [], [], b.desc)
          })
        }
        let then_ = if side { mine } else { placeholder(then_body, true) }
        let else_ = else_body.map(b => {
          (
            {
              desc: if side {
                placeholder(b, false)
              } else {
                mine
              },
              info: b.info,
            } :
            @basic.Annotated[
              Array[@ast.Instr[@typing_env.InferredAnnotation]],
              @basic.Location,
            ])
        })
        out.push({
          desc: IfAnnotation(
            cond~,
            then_body={ desc: then_, info: then_body.info, },
            else_body=else_,
          ),
          info: annotate([], i.info),
          hints: i.hints,
          expected: i.expected,
        })
      }
    }
  }
  out
}
