// The Wax instruction tree.
//
// Ported from wax/src/lib-wax/ast.mli. Generic over `Info`, the annotation each
// node carries: the parser produces `Info = Location`, and the type checker --
// which will be ported later -- re-annotates the same tree with inferred types.
// See AGENTS.md for why that parameter is kept even though only one instance
// exists today.
//
// A block's body is `Annotated[Array[Instr[Info]], Location]`, not a bare
// array: the LIST carries its own `{ ... }` span, which the trivia layer needs
// in order to attach a comment written inside an otherwise-empty block.

///|
/// A statement or expression. Wax is expression-oriented, so there is no
/// separate statement type.
pub(all) enum InstrDesc[Info] {
  // -- structured control flow ---------------------------------------------
  Block(label~ : Label?, typ~ : FuncType, block~ : Body[Info])
  Loop(label~ : Label?, typ~ : FuncType, block~ : Body[Info])
  /// `step` is a Zig-style continue-expression: a statement run at the end of
  /// every iteration, INCLUDING one reached by `continue` (a branch to the loop
  /// label). Without it, a `continue` would skip the increment.
  While(
    label~ : Label?,
    cond~ : Instr[Info],
    step~ : Instr[Info]?,
    block~ : Body[Info]
  )
  If(
    label~ : Label?,
    typ~ : FuncType,
    cond~ : Instr[Info],
    if_block~ : Body[Info],
    else_block~ : Body[Info]?
  )
  TryTable(
    label~ : Label?,
    typ~ : FuncType,
    catches~ : Array[Catch],
    block~ : Body[Info]
  )
  /// The deprecated legacy exception handler (`try_legacy`), compiling to the
  /// legacy try/catch instructions.
  Try(
    label~ : Label?,
    typ~ : FuncType,
    block~ : Body[Info],
    catches~ : Array[(Ident, Body[Info])],
    catch_all~ : Body[Info]?
  )
  /// The structured `try { ... } catch { tag => { ... } ... }`, lowered to
  /// try_table plus a block ladder. Arms are honest trailing code in clause
  /// order: an arm's completion falls into the next arm, the last arm's into
  /// the join, and the body's completion escapes past all arms.
  TryCatch(
    label~ : Label?,
    typ~ : FuncType,
    block~ : Body[Info],
    arms~ : Array[TryCatchArm[Info]]
  )

  // -- leaves ---------------------------------------------------------------
  Unreachable
  Nop
  /// `_` in expression position: a hole, which the typer fills or reports.
  Hole
  Null
  Get(Ident)
  /// A qualified name `namespace::member`, the callee of a built-in intrinsic
  /// such as `i64::add128`.
  Path(Ident, Ident)

  // -- assignment -----------------------------------------------------------
  /// Assignment to a local or global. The middle field is the compound operator:
  /// `None` for `x = e`, `Some(op)` for `x op= e`. It is preserved through
  /// typing and lowering so the form round-trips in both directions rather than
  /// being normalised to a get/op/set.
  ///
  /// A discarded value (`_ = e`) is NOT a Set but an anonymous Let.
  Set(Ident, Annotated[BinOp, Location]?, Instr[Info])
  /// `x := e` -- assign and yield the value.
  Tee(Ident, Instr[Info])

  // -- calls ----------------------------------------------------------------
  Call(Instr[Info], Array[Instr[Info]])
  TailCall(Instr[Info], Array[Instr[Info]])
  /// A labelled call argument `name: expr`, used for the static
  /// `offset`/`align`/`lane` immediates of a memory access.
  Labelled(Ident, Instr[Info])

  // -- literals -------------------------------------------------------------
  Char(Char)
  /// A string literal, optionally prefixed by a type (`t#"..."`).
  Str(Ident?, String)
  /// Numeric literals stay RAW TEXT all the way through the front end. That is
  /// what lets the printer reproduce `0x1_0` as written, and what the typer's
  /// flexible-literal inference will need.
  Int(String)
  Float(String)

  // -- casts and tests ------------------------------------------------------
  Cast(Instr[Info], CastType)
  CastDesc(Instr[Info], Bool, Instr[Info])
  Test(Instr[Info], RefType[Ident])
  /// `e!` -- assert non-null.
  NonNull(Instr[Info])

  // -- aggregates -----------------------------------------------------------
  /// A field's value is `None` when written in the punning shorthand `{x}`,
  /// abbreviating `{x: x}`. The distinction is kept so the printer can put it
  /// back the way it was written.
  Struct(Ident?, Array[(Ident, Instr[Info]?)])
  StructDefault(Ident?)
  StructDesc(Instr[Info], Array[(Ident, Instr[Info]?)])
  StructDefaultDesc(Instr[Info])
  StructGet(Instr[Info], Ident)
  GetDescriptor(Instr[Info])
  StructSet(Instr[Info], Ident, Instr[Info])
  Array(Ident?, Instr[Info], Instr[Info])
  ArrayDefault(Ident?, Instr[Info])
  ArrayFixed(Ident?, Array[Instr[Info]])
  ArraySegment(Ident?, Ident, Instr[Info], Instr[Info])
  ArrayGet(Instr[Info], Instr[Info])
  ArraySet(Instr[Info], Instr[Info], Instr[Info])

  // -- operators ------------------------------------------------------------
  BinOpI(Annotated[BinOp, Location], Instr[Info], Instr[Info])
  UnOpI(Annotated[UnOp, Location], Instr[Info])

  // -- bindings -------------------------------------------------------------
  /// `let` binds several names at once (a tuple pattern). A name is `None` for
  /// a discarded binding (`_`), and the type is `None` when inferred.
  Let(Array[(Ident?, ValType[Ident]?)], Instr[Info]?)

  // -- branches -------------------------------------------------------------
  Br(Label, Instr[Info]?)
  BrIf(Label, Instr[Info])
  BrTable(Array[Label], Instr[Info])
  Dispatch(
    index~ : Instr[Info],
    cases~ : Array[Label],
    default~ : Label,
    arms~ : Array[(Label, Body[Info])]
  )
  Match(
    scrutinee~ : Instr[Info],
    arms~ : Array[(MatchPattern, Body[Info])],
    default~ : Body[Info]
  )
  BrOnNull(Label, Instr[Info])
  BrOnNonNull(Label, Instr[Info])
  BrOnCast(Label, RefType[Ident], Instr[Info])
  BrOnCastFail(Label, RefType[Ident], Instr[Info])
  BrOnCastDescEq(Label, Bool, Instr[Info], Instr[Info])
  BrOnCastDescEqFail(Label, Bool, Instr[Info], Instr[Info])

  // -- exceptions -----------------------------------------------------------
  Throw(Ident, Array[Instr[Info]])
  ThrowRef(Instr[Info])

  // -- stack switching ------------------------------------------------------
  ContNew(Ident, Instr[Info])
  ContBind(Ident, Ident, Array[Instr[Info]])
  Suspend(Ident, Array[Instr[Info]])
  Resume(Ident, Array[OnClause], Array[Instr[Info]])
  ResumeThrow(Ident, Ident, Array[OnClause], Array[Instr[Info]])
  ResumeThrowRef(Ident, Array[OnClause], Array[Instr[Info]])
  Switch(Ident, Ident, Array[Instr[Info]])
  /// The postfix handler clause `e on [t -> 'l, ...]` AS PARSED. The typer folds
  /// it into the Resume/ResumeThrow/ResumeThrowRef it wraps; the printer prints
  /// this surface form, which is why it survives in the tree.
  On(Instr[Info], Array[OnClause])

  // -- misc -----------------------------------------------------------------
  Return(Instr[Info]?)
  Sequence(Array[Instr[Info]])
  /// `c ? a : b`.
  Select(Instr[Info], Instr[Info], Instr[Info])
  /// A conditional-compilation group, `#[if(c)] { ... } #[else] { ... }`.
  ///
  /// This is not LALR-pairable (it is the dangling-else problem), so the parser
  /// produces markers for each brace group and a post-pass folds adjacent ones
  /// into this node. See parser.mbty.
  IfAnnotation(cond~ : Cond, then_body~ : Body[Info], else_body~ : Body[Info]?)
} derive(Eq, Debug)

///|
/// A braced block of instructions together with the span of its braces.
pub type Body[Info] = Annotated[Array[Instr[Info]], Location]

///|
/// An instruction node.
///
/// `hints` and `expected` are fields rather than wrapper nodes so the pervasive
/// matches on `desc` neither see them nor have to see through them.
pub(all) struct Instr[Info] {
  desc : InstrDesc[Info]
  info : Info
  /// Advisory `metadata.code.*` metadata (`#[likely]`, `#[freq = 16]`).
  hints : Hints
  /// The type this node's value MUST have, when a producer knows it
  /// independently of Wax inference.
  ///
  /// Nothing in the source language sets this and nothing user-visible reads
  /// it: only the wasm-to-Wax decompiler records the type the original opcode
  /// stated, so the typer can catch an expression it would otherwise re-infer
  /// at a different width -- silently changing the opcode on recompile. A
  /// parsed module always leaves it `None`.
  ///
  /// Kept even though this port never populates it, because omitting it would
  /// force an AST change when the typer lands.
  expected : ValType[Ident]?
} derive(Eq, Debug)

///|
/// One arm of a structured `try ... catch`.
pub(all) struct TryCatchArm[Info] {
  /// `None` for the trailing catch-all.
  arm_tag : Ident?
  /// A `&` arm, where the `&exn` is delivered above the payload.
  arm_ref : Bool
  /// The arm's entry stack: the tag's payload, plus the `&exn` for a `&` arm.
  ///
  /// EMPTY as parsed -- the typer fills it, and the lowering back to wasm reads
  /// it. Present here for the same reason as `Instr::expected`.
  arm_types : Array[ValType[Ident]]
  arm_body : Body[Info]
} derive(Eq, Debug)

///|
/// Build an instruction with a span and no hints.
pub fn build(desc : InstrDesc[Location], loc : Location) -> Instr[Location] {
  { desc, info: loc, hints: no_hints, expected: None }
}

///|
/// A synthesized instruction: no source span, no hints.
pub fn no_loc_instr(desc : InstrDesc[Location]) -> Instr[Location] {
  build(desc, @basic.dummy_loc)
}
