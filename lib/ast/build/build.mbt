// Building a module field without writing the constructor out.
//
// EVERY function here takes `at~`, and defaults it to `@basic.dummy_loc`. That
// default is a convenience, not the intended use: a generator that maps its own
// source spans into `at~` gets type errors that point at ITS syntax, and the
// whole diagnostic renderer -- the snippet, the caret, the related labels, the
// quick fixes -- starts working for it for free. A builder that hardcoded
// `dummy_loc` would throw that away permanently, which is why the parameter is
// on every one of them rather than on the few that seemed to need it.

///|
/// A name, with the span it was written at.
pub fn ident(
  name : String,
  at? : @basic.Location = @basic.dummy_loc,
) -> @ast.Ident {
  { name, loc: at }
}

///|
/// Attach a span to a module field, giving the `@ast.LocModule` element.
///
/// A module is just an array of these, so `[func(...), global(...)]` is a
/// module and there is no separate constructor for one.
pub fn field(
  f : @ast.ModuleField[@basic.Location],
  at? : @basic.Location = @basic.dummy_loc,
) -> @basic.Annotated[@ast.ModuleField[@basic.Location], @basic.Location] {
  { desc: f, info: at }
}

///|
/// A function signature.
///
/// A parameter's name is optional because wasm's is: `(param i32)` is a
/// positional parameter, and only a named one can be referred to by name in the
/// body.
pub fn func_type(
  params? : Array[(String?, @wasm_types.ValType[@ast.Ident])] = [],
  results? : Array[@wasm_types.ValType[@ast.Ident]] = [],
  at? : @basic.Location = @basic.dummy_loc,
) -> @ast.FuncType {
  {
    params: params.map(p => {
      let (name, typ) = p
      (
        { desc: (name.map(n => ident(n, at~)), typ), info: at } :
        @basic.Annotated[
          (@ast.Ident?, @wasm_types.ValType[@ast.Ident]),
          @basic.Location,
        ])
    }),
    results,
  }
}

///|
/// A function definition.
///
/// `label` names the function's implicit outermost block, which is what a
/// `br` in the body targets to return early. It is separate from `name`
/// because the two are separate in the syntax.
pub fn func(
  name : String,
  params? : Array[(String?, @wasm_types.ValType[@ast.Ident])] = [],
  results? : Array[@wasm_types.ValType[@ast.Ident]] = [],
  body? : Array[@ast.Instr[@basic.Location]] = [],
  label? : String? = None,
  attributes? : Array[@ast.Attribute] = [],
  at? : @basic.Location = @basic.dummy_loc,
) -> @basic.Annotated[@ast.ModuleField[@basic.Location], @basic.Location] {
  field(
    Func(
      name=ident(name, at~),
      typ=None,
      sign=Some(func_type(params~, results~, at~)),
      body=(label.map(l => ident(l, at~)), body),
      attributes~,
    ),
    at~,
  )
}

///|
/// A global definition. `def` is its initializer.
pub fn global(
  name : String,
  typ? : @wasm_types.ValType[@ast.Ident]? = None,
  mut_? : Bool = false,
  def~ : @ast.Instr[@basic.Location],
  attributes? : Array[@ast.Attribute] = [],
  at? : @basic.Location = @basic.dummy_loc,
) -> @basic.Annotated[@ast.ModuleField[@basic.Location], @basic.Location] {
  field(Global(name=ident(name, at~), mut_~, typ~, def~, attributes~), at~)
}

///|
/// A recursive type group.
///
/// One group, however many types are in it, because that is the unit wasm
/// gives subtyping and equality: two types in the same group can refer to each
/// other, and two in different groups cannot.
pub fn rec_group(
  types : Array[(String, @ast.SubType)],
  at? : @basic.Location = @basic.dummy_loc,
) -> @basic.Annotated[@ast.ModuleField[@basic.Location], @basic.Location] {
  field(
    Type(
      types.map(t => {
        let (name, sub) = t
        (
          { desc: (ident(name, at~), sub), info: at } :
          @basic.Annotated[(@ast.Ident, @ast.SubType), @basic.Location])
      }),
    ),
    at~,
  )
}

///|
/// An imported function.
///
/// `module_` and `name` are the two halves of the import's wasm name. `as_` is
/// what this module calls it internally; leaving it out means the two are the
/// same, which is the common case. When they differ, the external name is
/// carried by an `#[import]` attribute -- an import's declared identifier is
/// the internal one, and the wasm name defaults to it.
pub fn import_func(
  module_ : String,
  name : String,
  as_? : String? = None,
  params? : Array[(String?, @wasm_types.ValType[@ast.Ident])] = [],
  results? : Array[@wasm_types.ValType[@ast.Ident]] = [],
  exact? : Bool = false,
  attributes? : Array[@ast.Attribute] = [],
  at? : @basic.Location = @basic.dummy_loc,
) -> @basic.Annotated[@ast.ModuleField[@basic.Location], @basic.Location] {
  let attributes = match as_ {
    Some(internal) if internal != name => [import_as(name, at~), ..attributes]
    _ => attributes
  }
  let decl : @ast.ImportDecl = {
    id: ident(as_.unwrap_or(name), at~),
    kind: Func(typ=None, sign=Some(func_type(params~, results~, at~)), exact~),
    attributes,
  }
  field(
    Import(module_={ desc: @utf8.encode(module_), info: at }, decl={
      desc: decl,
      info: at,
    }),
    at~,
  )
}

///|
/// The `#[import = "name"]` attribute: the wasm name to import under, when it
/// differs from the identifier the module uses for it.
pub fn import_as(
  name : String,
  at? : @basic.Location = @basic.dummy_loc,
) -> @ast.Attribute {
  {
    attr_name: "import",
    attr_value: Some(@ast.build(Str(None, @utf8.encode(name)), at)),
    attr_guard: None,
    attr_span: at,
  }
}

///|
/// The `#[export]` attribute. (`export` itself is a reserved word.)
///
/// Bare -- `name` left out -- exports the entity under its own name, which is
/// what writing it bare means in the syntax. Passing `name` is
/// `#[export = "name"]`.
pub fn exported(
  name? : String,
  at? : @basic.Location = @basic.dummy_loc,
) -> @ast.Attribute {
  {
    attr_name: "export",
    attr_value: name.map(n => @ast.build(Str(None, @utf8.encode(n)), at)),
    attr_guard: None,
    attr_span: at,
  }
}
