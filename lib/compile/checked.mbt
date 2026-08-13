// What a checked module can be turned into.

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
pub fn Checked::to_bytes(self : Checked) -> Bytes raise {
  @wasm_bin.encode(self.to_module())
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
) -> String raise {
  @to_wat.print_module(self.to_module(keep_conditionals=true), trivia~)
}
