// Parse-time state and node construction.
//
// The reference makes its grammar a Menhir FUNCTOR over the trivia context, so
// every semantic action can register the span of the node it builds:
//
//     %parameter <Context : sig ... val context : Trivia.context end>
//
// MoonBit has no functors and MoonYacc has no equivalent, so the context lives
// in a package-level Ref that `parse` sets on entry. The consequence is that
// PARSING IS NOT REENTRANT -- one parse at a time per process. That is fine for
// a CLI; if this ever backs a language server, the fix is to thread a state
// record through the actions instead.

///|
/// The trivia context the running parse is registering spans with.
///
/// Reset by `set_context` at the start of every parse, so a previous parse's
/// leftovers can never leak into the next one.
let context : Ref[@trivia.Context] = @ref.new(@trivia.Context::new())

///|
pub fn set_context(ctx : @trivia.Context) -> Unit {
  context.val = ctx
  parenthesized.clear()
  semantic_error.val = None
}

///|
/// Byte spans of expressions that were written inside parentheses.
///
/// Needed only to enforce the non-associativity of the comparison operators.
/// The reference declares that precedence level `%nonassoc`, which makes
/// `1 < 2 < 3` a syntax error while `1 < (2 < 3)` is accepted -- but MoonYacc
/// panics when a %nonassoc conflict actually arises (see the note in
/// parser.mbty), so the level is `%left` and the rule is enforced here instead.
///
/// The distinction is one the GRAMMAR knows and the AST does not: the
/// parenthesized production returns its inner instruction unchanged, so the two
/// forms are indistinguishable afterwards. Rather than add a paren node to the
/// AST -- which the reference does not have, and which the printer would then
/// have to ignore -- the parenthesized spans are recorded here, outside the
/// tree, and consulted only by `reject_chained_comparison`.
let parenthesized : Set[(Int, Int)] = Set([], capacity=64)

///|
/// Record that `i` was written inside parentheses.
fn mark_parenthesized(i : Instr[Location]) -> Instr[Location] {
  parenthesized.add((i.info.start.cnum, i.info.end.cnum))
  i
}

///|
/// Whether this operator is one of the comparison operators, which together
/// form a single non-associative precedence level.
fn is_comparison(op : @ast.BinOp) -> Bool {
  match op {
    Eq | Ne | Lt(_) | Gt(_) | Le(_) | Ge(_) => true
    _ => false
  }
}

///|
/// Reject a chained comparison such as `1 < 2 < 3`.
///
/// Raised at the span of the SECOND operator, which is where the reference's
/// parser stops: verified against the pinned binary, which reports
/// startOffset/endOffset covering exactly that token.
///
/// A parenthesized operand is fine -- `1 < (2 < 3)` and `(1 < 2) < 3` are both
/// accepted by the reference -- which is what the `parenthesized` set is for.
fn reject_chained_comparison(
  oploc : (Position, Position),
  op : @ast.BinOp,
  i : Instr[Location],
) -> Unit {
  if !is_comparison(op) {
    return
  }
  if i.desc is BinOpI(inner, _, _) &&
    is_comparison(inner.desc) &&
    !parenthesized.contains((i.info.start.cnum, i.info.end.cnum)) {
    record_error(
      loc_of(oploc),
      "Comparison operators are non-associative; parenthesize to say which comparison was meant.",
    )
  }
}

///|
/// A syntax error raised from a semantic action.
///
/// Distinct from MoonYacc's own `ParseError`, which reports a token the
/// automaton could not shift. These are the errors the reference raises from
/// inside its actions -- "this identifier is not a value type", "a parameter
/// list is required" -- where the token stream is fine but what it says is not.
/// Their message text is hand-written in the reference, so unlike the automaton
/// messages it can be reproduced exactly.
suberror SyntaxError {
  SyntaxError(
    loc~ : Location,
    message~ : String,
    hint~ : String?,
    /// A machine-applicable repair, when the message names an exact one.
    fix~ : @basic.Edit?
  )
} derive(Debug)

///|
/// The first semantic error of the running parse, if any.
///
/// MoonYacc generates its semantic actions as
/// `(Position, ArrayView[...]) -> YYObj` -- no `raise` in the signature -- so an
/// action CANNOT propagate an error. The reference simply raises from inside
/// its actions; here the error is recorded instead, the action returns a
/// harmless placeholder, and the driver reports it and discards the tree.
///
/// First error wins, which matches the reference: it raises on the first
/// semantic error, so nothing after that is reported there either.
let semantic_error : Ref[SyntaxError?] = @ref.new(None)

///|
/// Record a syntax error and return `default` so the action can complete.
///
/// The returned value is never used for anything: the driver discards the whole
/// tree whenever an error was recorded. It exists only because the action has
/// to return something of the right type.
fn[T] fail_at(
  loc : Location,
  message : String,
  default~ : T,
  hint? : String? = None,
  fix? : @basic.Edit? = None,
) -> T {
  if semantic_error.val is None {
    semantic_error.val = Some(SyntaxError(loc~, message~, hint~, fix~))
  }
  default
}

///|
/// Record a syntax error where the action has nothing to return.
fn record_error(
  loc : Location,
  message : String,
  hint? : String? = None,
  fix? : @basic.Edit? = None,
) -> Unit {
  if semantic_error.val is None {
    semantic_error.val = Some(SyntaxError(loc~, message~, hint~, fix~))
  }
}

///|
/// The semantic error the last parse recorded, if it hit one.
fn taken_error() -> SyntaxError? {
  semantic_error.val
}

///|
/// Build a location from a MoonYacc `$loc`-style position pair.
fn loc_of(p : (Position, Position)) -> Location {
  { start: p.0, end: p.1, }
}

///|
/// Build an instruction node and register its span with the trivia context.
///
/// Registration is what lets a comment be attached to this node later, so every
/// node the printer might emit has to go through here or through `annot`.
///
/// A freshly parsed instruction carries no hints (a hint attribute fills them
/// in afterwards) and no `expected` type (that is a decompiler-only channel).
fn with_loc(
  p : (Position, Position),
  desc : InstrDesc[Location],
) -> Instr[Location] {
  let info = loc_of(p)
  context.val.record_pos(info)
  { desc, info, hints: @ast.no_hints, expected: None, }
}

///|
/// Build any other located node -- a module field, an identifier, a body -- and
/// register its span.
fn[T] annot(p : (Position, Position), desc : T) -> Annotated[T, Location] {
  let info = loc_of(p)
  context.val.record_pos(info)
  { desc, info, }
}

///|
/// Re-span an already-built annotated node.
///
/// Used where a branch of a conditional group must keep its own
/// `#[if] { ... }` span, marker included, rather than only the combined span of
/// the pair -- the editor's dead-branch dimming locates a single branch by it.
fn[T] respan(
  a : Annotated[T, Location],
  p : (Position, Position),
) -> Annotated[T, Location] {
  { desc: a.desc, info: loc_of(p), }
}

///|
/// The signature of a block that did not state one.
fn blocktype(bt : FuncType?) -> FuncType {
  match bt {
    Some(t) => t
    None => { params: [], results: [], }
  }
}

///|
/// Build a binary-operator node.
///
/// The operator gets a span of its own (`oploc`, its token) rather than only
/// the whole expression's, so a comment written between an operand and the
/// operator attaches where it was written.
fn binop(
  sloc : (Position, Position),
  oploc : (Position, Position),
  op : @ast.BinOp,
  i : Instr[Location],
  j : Instr[Location],
) -> Instr[Location] {
  reject_chained_comparison(oploc, op, i)
  with_loc(sloc, BinOpI(annot(oploc, op), i, j))
}

///|
fn unop(
  sloc : (Position, Position),
  oploc : (Position, Position),
  op : @ast.UnOp,
  i : Instr[Location],
) -> Instr[Location] {
  with_loc(sloc, UnOpI(annot(oploc, op), i))
}
