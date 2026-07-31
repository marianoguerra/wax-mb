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
pub suberror SyntaxError {
  SyntaxError(
    loc~ : Location,
    message~ : String,
    hint~ : String?,
    /// A machine-applicable repair, when the message names an exact one.
    fix~ : @basic.Edit?
  )
} derive(Debug)

///|
/// Raise a syntax error spanning `loc`.
pub fn[T] fail_at(
  loc : Location,
  message : String,
  hint? : String? = None,
  fix? : @basic.Edit? = None,
) -> T raise SyntaxError {
  raise SyntaxError(loc~, message~, hint~, fix~)
}

///|
/// Build a location from a MoonYacc `$loc`-style position pair.
pub fn loc_of(p : (Position, Position)) -> Location {
  { start: p.0, end: p.1 }
}

///|
/// Build an instruction node and register its span with the trivia context.
///
/// Registration is what lets a comment be attached to this node later, so every
/// node the printer might emit has to go through here or through `annot`.
///
/// A freshly parsed instruction carries no hints (a hint attribute fills them
/// in afterwards) and no `expected` type (that is a decompiler-only channel).
pub fn with_loc(
  p : (Position, Position),
  desc : InstrDesc[Location],
) -> Instr[Location] {
  let info = loc_of(p)
  context.val.record_pos(info)
  { desc, info, hints: @ast.no_hints, expected: None }
}

///|
/// Build any other located node -- a module field, an identifier, a body -- and
/// register its span.
pub fn[T] annot(p : (Position, Position), desc : T) -> Annotated[T, Location] {
  let info = loc_of(p)
  context.val.record_pos(info)
  { desc, info }
}

///|
/// Re-span an already-built annotated node.
///
/// Used where a branch of a conditional group must keep its own
/// `#[if] { ... }` span, marker included, rather than only the combined span of
/// the pair -- the editor's dead-branch dimming locates a single branch by it.
pub fn[T] respan(
  a : Annotated[T, Location],
  p : (Position, Position),
) -> Annotated[T, Location] {
  { desc: a.desc, info: loc_of(p) }
}

///|
/// The signature of a block that did not state one.
pub fn blocktype(bt : FuncType?) -> FuncType {
  match bt {
    Some(t) => t
    None => { params: [], results: [] }
  }
}
