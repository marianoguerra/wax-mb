// Walking the tree, and the surface-form desugarings.
//
// Ported from wax/src/lib-wax/ast_utils.ml. Two things live here:
//
//   * ONE structural rebuild of `InstrDesc`, from which the map and the two
//     iterations derive. The reference writes the giant match twice (`map_desc`
//     and `sub_instrs`); deriving the visitor from the rebuild costs one shallow
//     desc allocation per node visited -- linear, not quadratic -- and leaves
//     one place to update when a constructor is added.
//   * The LOWERINGS: `match`, `while`, `dispatch` and `try`/`catch` written out
//     in the core forms a type checker and a code generator understand. The AST
//     keeps the surface constructors faithfully (a Phase 2 commitment, so the
//     printer can put back what was written), so these are additive: nothing
//     reads them yet, and the tree they produce is discarded after it has been
//     checked.
//
// Not ported: the reference's `smart_map`/`smart_opt` sharing (it returns the
// input list physically when nothing changed, so an untouched subtree allocates
// nothing). That is an allocation optimisation resting on OCaml's `==`, and it
// belongs with the rewrite pass that needs it, not ahead of it.

///|
/// Rebuild a desc, rewriting every nested operand and every nested body.
///
/// The one exhaustive match over `InstrDesc`. Changing the type breaks this and
/// nothing else, which is the point.
pub fn[A, B] InstrDesc::map_desc(
  self : InstrDesc[A],
  instr~ : (Instr[A]) -> Instr[B],
  block~ : (Array[Instr[A]]) -> Array[Instr[B]],
) -> InstrDesc[B] {
  fn body(b : Body[A]) -> Body[B] {
    { desc: block(b.desc), info: b.info }
  }

  fn opt(i : Instr[A]?) -> Instr[B]? {
    match i {
      Some(x) => Some(instr(x))
      None => None
    }
  }

  fn many(xs : Array[Instr[A]]) -> Array[Instr[B]] {
    xs.map(instr)
  }

  match self {
    Block(label~, typ~, block~) => Block(label~, typ~, block=body(block))
    Loop(label~, typ~, block~) => Loop(label~, typ~, block=body(block))
    While(label~, cond~, step~, block~) =>
      While(label~, cond=instr(cond), step=opt(step), block=body(block))
    If(label~, typ~, cond~, if_block~, else_block~) =>
      If(
        label~,
        typ~,
        cond=instr(cond),
        if_block=body(if_block),
        else_block=match else_block {
          Some(b) => Some(body(b))
          None => None
        },
      )
    TryTable(label~, typ~, catches~, block~) =>
      TryTable(label~, typ~, catches~, block=body(block))
    Try(label~, typ~, block~, catches~, catch_all~) =>
      Try(
        label~,
        typ~,
        block=body(block),
        catches=catches.map(c => (c.0, body(c.1))),
        catch_all=match catch_all {
          Some(b) => Some(body(b))
          None => None
        },
      )
    TryCatch(label~, typ~, block~, arms~) =>
      TryCatch(
        label~,
        typ~,
        block=body(block),
        arms=arms.map(a => {
          arm_tag: a.arm_tag,
          arm_ref: a.arm_ref,
          arm_types: a.arm_types,
          arm_body: body(a.arm_body),
        }),
      )
    Unreachable => Unreachable
    Nop => Nop
    Hole => Hole
    Null => Null
    Get(id) => Get(id)
    Path(a, b) => Path(a, b)
    Set(id, op, i) => Set(id, op, instr(i))
    Tee(id, i) => Tee(id, instr(i))
    Call(f, args) => Call(instr(f), many(args))
    TailCall(f, args) => TailCall(instr(f), many(args))
    Labelled(id, i) => Labelled(id, instr(i))
    Char(c) => Char(c)
    Str(t, b) => Str(t, b)
    Int(s) => Int(s)
    Float(s) => Float(s)
    Cast(i, t) => Cast(instr(i), t)
    CastDesc(i, exact, d) => CastDesc(instr(i), exact, instr(d))
    Test(i, t) => Test(instr(i), t)
    NonNull(i) => NonNull(instr(i))
    Struct(t, fields) => Struct(t, fields.map(f => (f.0, opt(f.1))))
    StructDefault(t) => StructDefault(t)
    StructDesc(d, fields) =>
      StructDesc(instr(d), fields.map(f => (f.0, opt(f.1))))
    StructDefaultDesc(d) => StructDefaultDesc(instr(d))
    StructGet(i, f) => StructGet(instr(i), f)
    GetDescriptor(i) => GetDescriptor(instr(i))
    StructSet(o, f, v) => StructSet(instr(o), f, instr(v))
    Array(t, init, n) => Array(t, instr(init), instr(n))
    ArrayDefault(t, n) => ArrayDefault(t, instr(n))
    ArrayFixed(t, xs) => ArrayFixed(t, many(xs))
    ArraySegment(t, seg, off, n) => ArraySegment(t, seg, instr(off), instr(n))
    ArrayGet(a, i) => ArrayGet(instr(a), instr(i))
    ArraySet(a, i, v) => ArraySet(instr(a), instr(i), instr(v))
    BinOpI(op, l, r) => BinOpI(op, instr(l), instr(r))
    UnOpI(op, i) => UnOpI(op, instr(i))
    Let(binds, i) => Let(binds, opt(i))
    Br(l, i) => Br(l, opt(i))
    BrIf(l, i) => BrIf(l, instr(i))
    BrTable(ls, i) => BrTable(ls, instr(i))
    Dispatch(index~, cases~, default~, arms~) =>
      Dispatch(
        index=instr(index),
        cases~,
        default~,
        arms=arms.map(a => (a.0, body(a.1))),
      )
    Match(scrutinee~, arms~, default~) =>
      Match(
        scrutinee=instr(scrutinee),
        arms=arms.map(a => (a.0, body(a.1))),
        default=body(default),
      )
    BrOnNull(l, i) => BrOnNull(l, instr(i))
    BrOnNonNull(l, i) => BrOnNonNull(l, instr(i))
    BrOnCast(l, t, i) => BrOnCast(l, t, instr(i))
    BrOnCastFail(l, t, i) => BrOnCastFail(l, t, instr(i))
    BrOnCastDescEq(l, exact, i, d) =>
      BrOnCastDescEq(l, exact, instr(i), instr(d))
    BrOnCastDescEqFail(l, exact, i, d) =>
      BrOnCastDescEqFail(l, exact, instr(i), instr(d))
    Throw(tag, args) => Throw(tag, many(args))
    ThrowRef(i) => ThrowRef(instr(i))
    ContNew(t, i) => ContNew(t, instr(i))
    ContBind(a, b, args) => ContBind(a, b, many(args))
    Suspend(tag, args) => Suspend(tag, many(args))
    Resume(t, on, args) => Resume(t, on, many(args))
    ResumeThrow(t, tag, on, args) => ResumeThrow(t, tag, on, many(args))
    ResumeThrowRef(t, on, args) => ResumeThrowRef(t, on, many(args))
    Switch(t, tag, args) => Switch(t, tag, many(args))
    On(i, clauses) => On(instr(i), clauses)
    Return(i) => Return(opt(i))
    Sequence(xs) => Sequence(many(xs))
    Select(c, a, b) => Select(instr(c), instr(a), instr(b))
    IfAnnotation(cond~, then_body~, else_body~) =>
      IfAnnotation(
        cond~,
        then_body=body(then_body),
        else_body=match else_body {
          Some(b) => Some(body(b))
          None => None
        },
      )
  }
}

///|
/// Re-annotate every node, keeping the shape.
///
/// The type checker's move: the parser builds `Instr[Location]` and typing
/// rebuilds the same tree carrying inferred types.
pub fn[A, B] Instr::map_info(self : Instr[A], f : (A) -> B) -> Instr[B] {
  {
    desc: self.desc.map_desc(instr=i => i.map_info(f), block=b => {
      b.map(i => i.map_info(f))
    }),
    info: f(self.info),
    hints: self.hints,
    expected: self.expected,
  }
}

///|
/// The instructions immediately nested within this one, in no particular order.
pub fn[I] Instr::sub_instrs(self : Instr[I]) -> Array[Instr[I]] {
  let out = []
  self.desc.map_desc(
    instr=i => {
      out.push(i)
      i
    },
    block=b => {
      for i in b {
        out.push(i)
      }
      b
    },
  )
  |> ignore
  out
}

///|
/// Apply `f` to this instruction and, recursively, to everything within it.
///
/// Unlike `map_info`, `f` sees the whole node, so it can look at the `desc`.
pub fn[I] Instr::iter_instr(self : Instr[I], f : (Instr[I]) -> Unit) -> Unit {
  f(self)
  for sub in self.sub_instrs() {
    sub.iter_instr(f)
  }
}

// --------------------------------------------------------------------------
// The surface-form lowerings
// --------------------------------------------------------------------------
//
// Each is the exact inverse of one of the reference's `recover_*` passes, so a
// decompiled module re-lowers to the blocks it came from. That is what makes
// them worth reproducing exactly rather than merely equivalently.

///|
/// The label of the `loop` a label-less `while` lowers to.
///
/// `#` is not a Wax identifier character, so this can never clash with a source
/// label nor be the target of a user `br`. It only ever labels the lowering the
/// type checker discards -- conversion to wasm picks a readable name instead,
/// and that is what reaches emitted wat.
pub let synthetic_loop_label : String = "#loop"

///|
/// `{ params: [], results: [] }` -- the type of a block that leaves nothing.
fn void_type() -> FuncType {
  { params: [], results: [] }
}

///|
/// Lower a `dispatch` to a `br_table` inside nested case blocks.
///
/// One void block per case, the `br_table` innermost, each case body just after
/// its own block. Branching to case `c` exits `c`'s block, runs `c`'s body, and
/// falls through into the enclosing cases -- so the arms are listed in
/// fall-through order, which is the REVERSE of the block nesting. The last arm
/// is therefore outermost and its body trails the whole structure, which is why
/// this returns a list rather than one instruction.
pub fn[I] lower_dispatch(
  block_info : I,
  index~ : Instr[I],
  cases~ : Array[Label],
  default~ : Label,
  arms~ : Array[(Label, Body[I])],
) -> Array[Instr[I]] {
  fn mk(desc : InstrDesc[I]) -> Instr[I] {
    { desc, info: block_info, hints: no_hints, expected: None }
  }

  let targets = cases.copy()
  targets.push(default)
  let br = mk(BrTable(targets, index))
  if arms.length() == 0 {
    return [br]
  }
  // Build from the last arm inward: `build(i)` is the block for arm `i`,
  // holding the block for arm `i - 1` followed by arm `i - 1`'s body.
  fn build(i : Int) -> Instr[I] {
    if i == 0 {
      mk(
        Block(label=Some(arms[0].0), typ=void_type(), block=@basic.no_loc([br])),
      )
    } else {
      let inner = [build(i - 1)]
      for x in arms[i - 1].1.desc {
        inner.push(x)
      }
      mk(
        Block(
          label=Some(arms[i].0),
          typ=void_type(),
          block=@basic.no_loc(inner),
        ),
      )
    }
  }

  let out = [build(arms.length() - 1)]
  for x in arms[arms.length() - 1].1.desc {
    out.push(x)
  }
  out
}

///|
/// Lower a leading-test `while C { B }` to `'L: loop { if C { B; br 'L; } }`.
///
/// A continue-expression `step` has to run at the end of EVERY iteration,
/// including one reached by `continue` (a branch to the loop label). When the
/// loop is labelled -- so a `continue` can target it -- the body is wrapped in a
/// block carrying the user's label, and the back-edge uses `fresh_loop`: `br 'L`
/// then exits that block, runs the step, and takes the back-edge. An unlabelled
/// stepped loop cannot be continued, so the step is simply appended to the body.
pub fn[I] lower_while(
  block_info : I,
  fresh_loop~ : Label,
  label~ : Label?,
  cond~ : Instr[I],
  step~ : Instr[I]?,
  block~ : Array[Instr[I]],
) -> Array[Instr[I]] {
  fn mk(desc : InstrDesc[I]) -> Instr[I] {
    { desc, info: block_info, hints: no_hints, expected: None }
  }

  fn if_(c : Instr[I], body : Array[Instr[I]]) -> Instr[I] {
    mk(
      If(
        label=None,
        typ=void_type(),
        cond=c,
        if_block=@basic.no_loc(body),
        else_block=None,
      ),
    )
  }

  match (step, label) {
    (Some(s), Some(blk_l)) => {
      let body_block = mk(
        Block(label=Some(blk_l), typ=void_type(), block=@basic.no_loc(block)),
      )
      [
        mk(
          Loop(
            label=Some(fresh_loop),
            typ=void_type(),
            block=@basic.no_loc([
              if_(cond, [body_block, s, mk(Br(fresh_loop, None))]),
            ]),
          ),
        ),
      ]
    }
    _ => {
      let l = label.unwrap_or(fresh_loop)
      let body = block.copy()
      match step {
        Some(s) => body.push(s)
        None => ()
      }
      body.push(mk(Br(l, None)))
      [
        mk(
          Loop(
            label=Some(l),
            typ=void_type(),
            block=@basic.no_loc([if_(cond, body)]),
          ),
        ),
      ]
    }
  }
}

///|
/// Lower a `match` to the nested type-test ladder.
///
/// The scrutinee is evaluated ONCE and threaded through a chain of
/// `br_on_cast` (or `br_on_null` for a `null` arm) in the innermost block: each
/// test, on success, branches out to its arm's block carrying the narrowed
/// value; on failure it leaves the progressively narrowed value for the next
/// test. The first arm is innermost, so arm `i`'s body sits in arm `i + 1`'s
/// block and the last arm's body sits in the `escape` block. After every test
/// fails the innermost block drops the value and branches to `escape`, past all
/// the arm bodies, and the default follows the (void) escape block as trailing
/// code.
///
/// `labels` supplies n + 1 fresh labels: one per arm in order, then `escape`.
pub fn[I] lower_match(
  block_info : I,
  labels~ : Array[Label],
  scrutinee~ : Instr[I],
  arms~ : Array[(MatchPattern, Body[I])],
  default~ : Body[I],
) -> Array[Instr[I]] {
  fn mk(desc : InstrDesc[I]) -> Instr[I] {
    { desc, info: block_info, hints: no_hints, expected: None }
  }

  fn res(p : MatchPattern) -> FuncType {
    match p {
      MatchCast(_, rt) => { params: [], results: [Ref(rt)] }
      MatchNull => void_type()
    }
  }

  // Consume a wrapped block's result for `pat`, then run `body`.
  fn consume(
    blk : Instr[I],
    pat : MatchPattern,
    body : Array[Instr[I]],
  ) -> Array[Instr[I]] {
    let out = match pat {
      MatchCast(Some(bind), rt) =>
        [mk(Let([(Some(bind), Some(Ref(rt)))], Some(blk)))]
      MatchCast(None, _) => [mk(Let([(None, None)], Some(blk)))]
      MatchNull => [blk]
    }
    for x in body {
      out.push(x)
    }
    out
  }

  if arms.length() == 0 {
    return default.desc
  }
  let escape = labels[labels.length() - 1]
  let arm_labels = labels[:labels.length() - 1].to_owned()
  // The threaded test chain, first test innermost, scrutinee at the bottom.
  let mut chain = scrutinee
  for i, lbl in arm_labels {
    chain = match arms[i].0 {
      MatchCast(_, rt) => mk(BrOnCast(lbl, rt, chain))
      MatchNull => mk(BrOnNull(lbl, chain))
    }
  }
  let inner = [mk(Let([(None, None)], Some(chain))), mk(Br(escape, None))]
  let mut prev = mk(
    Block(
      label=Some(arm_labels[0]),
      typ=res(arms[0].0),
      block=@basic.no_loc(inner),
    ),
  )
  let mut prev_pat = arms[0].0
  let mut prev_body = arms[0].1.desc
  // Wrap outward: each block holds the previous block -- its result consumed
  // for the previous arm -- followed by that arm's body.
  for i in 1..<arms.length() {
    prev = mk(
      Block(
        label=Some(arm_labels[i]),
        typ=res(arms[i].0),
        block=@basic.no_loc(consume(prev, prev_pat, prev_body)),
      ),
    )
    prev_pat = arms[i].0
    prev_body = arms[i].1.desc
  }
  let out = [
    mk(
      Block(
        label=Some(escape),
        typ=void_type(),
        block=@basic.no_loc(consume(prev, prev_pat, prev_body)),
      ),
    ),
  ]
  for x in default.desc {
    out.push(x)
  }
  out
}

///|
/// Lower a structured `try`/`catch` to `try_table` plus a block ladder.
///
/// One block per arm (the first innermost) inside the `join` block, the
/// `try_table` innermost with one catch clause per arm, and each arm body as
/// trailing code just after its block -- so an arm's completion falls into the
/// next arm and the last arm's falls out of the join as the try's value. The
/// body's normal completion escapes past all arms with the one implicit branch
/// to `join`, carrying the value.
///
/// `arm_labels` supplies one fresh label per arm; `join` is the try's own label
/// when it has one. Each arm block's result type is the arm's entry stack
/// (`arm_types`, which the typer fills).
pub fn[I] lower_trycatch(
  block_info : I,
  join~ : Label,
  arm_labels~ : Array[Label],
  typ~ : FuncType,
  block~ : Body[I],
  arms~ : Array[TryCatchArm[I]],
) -> Instr[I] {
  fn mk(desc : InstrDesc[I]) -> Instr[I] {
    { desc, info: block_info, hints: no_hints, expected: None }
  }

  let catches = []
  for i, arm in arms {
    let l = arm_labels[i]
    catches.push(
      match (arm.arm_tag, arm.arm_ref) {
        (Some(t), false) => Catch(t, l)
        (Some(t), true) => CatchRef(t, l)
        (None, false) => CatchAll(l)
        (None, true) => CatchAllRef(l)
      },
    )
  }
  let trytable = mk(TryTable(label=None, typ~, catches~, block~))
  let mut inner = if typ.results.length() == 0 {
    [trytable, mk(Br(join, None))]
  } else {
    [mk(Br(join, Some(trytable)))]
  }
  for i, arm in arms {
    let blk = mk(
      Block(
        label=Some(arm_labels[i]),
        typ={ params: [], results: arm.arm_types },
        block=@basic.no_loc(inner),
      ),
    )
    let next = [blk]
    for x in arm.arm_body.desc {
      next.push(x)
    }
    inner = next
  }
  mk(Block(label=Some(join), typ~, block=@basic.no_loc(inner)))
}

///|
/// The name an imported entity is bound to in wasm.
///
/// The name-only `#[import = "name"]` override if there is one, else the Wax
/// name.
///
/// BYTES, where the reference has a string: a wasm import name is a byte
/// string, and this port keeps a string literal as the bytes the lexer decoded
/// rather than re-encoding at every use. The Wax name is encoded here, which is
/// lossless -- an identifier is UTF-8 by construction.
pub fn import_name(decl : ImportDecl) -> Annotated[Bytes, Location] {
  for a in decl.attributes {
    if a.attr_name == "import" {
      match a.attr_value {
        Some({ desc: Str(_, bytes), info, .. }) => return { desc: bytes, info }
        _ => ()
      }
    }
  }
  { desc: @utf8.encode(decl.id.name), info: decl.id.loc }
}
