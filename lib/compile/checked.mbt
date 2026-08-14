// What a checked module can be turned into.

///|
/// What can stop a checked module from becoming output.
///
/// Three packages sit on this path and each raises its own error: the lowering
/// to the wasm module model, the binary encoder, and the text printer. A caller
/// handed the open `Error` type can only print what it catches; naming the
/// three lets it match on them, and says up front that there is no fourth.
///
/// None of these are a rejected module. A module the checker rejected is
/// reported through `Session::reports` and `rejected` before anything is
/// lowered -- these are the lowering's own gaps, and reaching one on a module
/// that checked clean is a bug in this port rather than in the input. The one
/// exception is `LowerError::AmbiguousBinding`, which only a generated tree can
/// reach and which names what the generator has to fix.
pub suberror CompileError {
  /// The Wax module would not lower: a construct not handled yet, a name the
  /// checker accepted that did not survive, or one the binary format cannot
  /// hold at all.
  Lower(@to_wasm.LowerError)
  /// The lowered module would not encode.
  Encode(@wasm_bin.EncodeError)
  /// The lowered module would not print as WebAssembly text.
  Wat(@to_wat.WatError)
}

///|
/// Delegated to the wrapped error, which already renders with its own span:
/// the wrapper says which stage, and the stage's own message is the answer.
pub impl Show for CompileError with fn output(self, logger) {
  match self {
    Lower(e) => Show::output(e, logger)
    Encode(e) => Show::output(e, logger)
    Wat(e) => Show::output(e, logger)
  }
}

///|
/// A module that has been through the type checker.
///
/// It holds the four things the lowering needs and that a caller would
/// otherwise have to keep together by hand: the session (for its type store),
/// the module context the checker built, the source AST, and the per-node
/// inferred types the checker left alongside it. The lowering reads the types
/// off `typed`, which is the entire interface between the two stages.
///
/// Holding a `Checked` is NOT a claim that the module is valid -- see
/// `Session::check`. Lowering one the checker rejected raises, or produces a
/// module derived from something known to be wrong.
pub struct Checked {
  /// The session it was checked in; its `store` is what numbers the types.
  session : Session
  /// Names and signatures, as the checker resolved them.
  context : @typing_env.ModuleContext
  /// The module as written.
  source_module : @ast.LocModule
  /// The same module with an inferred type on every node.
  typed : Array[
    @basic.Annotated[
      @ast.ModuleField[
        (Array[@infer.Cell[@infer.InferredType]], @basic.Location),
      ],
      @basic.Location,
    ],
  ]
}

///|
/// Lower to the wasm module model, shared by both output forms.
///
/// `keep_conditionals` retains the conditional sections rather than resolving
/// them, which only the text form wants: a module with an unresolved
/// conditional has no single binary form, and that is what a conditional is
/// for.
pub fn Checked::to_module(
  self : Checked,
  keep_conditionals? : Bool,
) -> @wasm_bin.Module raise @to_wasm.LowerError {
  @to_wasm.lower_module(
    self.context,
    self.session.store,
    self.source_module,
    self.typed,
    keep_conditionals?,
  )
}

///|
/// Encode to a `.wasm` binary.
pub fn Checked::to_bytes(self : Checked) -> Bytes raise CompileError {
  let m = self.to_module() catch { e => raise Lower(e) }
  @wasm_bin.encode(m) catch {
    e => raise Encode(e)
  }
}

///|
/// Print in the WebAssembly text format.
///
/// The same lowered module the binary form comes from, printed rather than
/// encoded, so the two cannot drift. `trivia` carries the source comments; they
/// were written against Wax source and come out as WAT comments, with the same
/// text and different delimiters.
pub fn Checked::to_wat(
  self : Checked,
  trivia? : @trivia.Context,
) -> String raise CompileError {
  let m = self.to_module(keep_conditionals=true) catch { e => raise Lower(e) }
  @to_wat.print_module(m, trivia~) catch {
    e => raise Wat(e)
  }
}
