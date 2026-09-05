// The lowering environment: names, spans, and what is known about each of them.

///|
/// Everything the lowering needs to know that is not in the expression it is
/// looking at.

///|
/// Where a module's text came from, so that a Wax type error found later can
/// name the right file and line.
///
/// A generator that built the AST rather than parsing it passes an empty
/// `text`, and every node in that module gets a fresh synthetic location
/// instead.
pub(all) struct ModuleSource {
  fname : String
  text : String
  src : @er.SourceId
}

///|
/// A module and where it came from: what `lower_program` compiles.
pub(all) struct Input {
  module_ : @wap.Module
  source : ModuleSource
}

///|
/// The line offsets of one file, for turning a span into a line and column.
priv struct LineMap {
  fname : String
  starts : Array[Int]
  src : @er.SourceId
  /// True when the module has no source text, so every node in it needs a
  /// synthetic location instead of a mapped one.
  text_empty : Bool
}

///|
fn LineMap::of(s : ModuleSource) -> LineMap {
  let starts = [0]
  let cs = s.text.to_array()
  for i, c in cs {
    if c == '\n' {
      starts.push(i + 1)
    }
  }
  { fname: s.fname, starts, src: s.src, text_empty: s.text.length() == 0, }
}

///|
priv struct Lowering {
  /// The module being lowered. Every table here is keyed by QUALIFIED name --
  /// `"hashing.mix_i32"` -- and this says which module a bare name belongs to.
  mut current : String
  /// Every module in the program, so that `hashing.f` can be told from a
  /// field access on a local called `hashing`.
  modules : Map[String, Unit]
  /// Which modules each module may name, by the importing module.
  imports : Map[String, Map[String, Unit]]
  /// Names another module is allowed to reach.
  visible : Map[String, Unit]
  /// One per module, keyed by module name.
  line_maps : Map[String, LineMap]
  mut here : LineMap
  spans : @build.Spans
  /// Declared types, by their wap name.
  types : Map[String, @wap.TypeDef]
  /// For an enumeration, the ordinal of each of its members.
  enum_members : Map[String, Map[String, Int]]
  /// Which enumeration a bare member name belongs to. A name in two
  /// enumerations is ambiguous and has to be qualified.
  member_owner : Map[String, String]
  /// Function signatures, for typing a call.
  funcs : Map[String, FnSig]
  /// Method signatures, keyed `type.method`.
  methods : Map[String, FnSig]
  /// Which types have methods of a given name, for the dispatcher.
  method_owners : Map[String, Array[String]]
  /// Global constants.
  globals : Map[String, @wap.Type]
  /// Names that came from `import was` or `import "host"` and are therefore
  /// already spelled the way the emitted module spells them.
  foreign : Map[String, Unit]
  /// Structurally-keyed generated types: inline arrays and function types.
  anon : Map[String, String]
  /// Type declarations the lowering had to invent.
  extra_types : Array[
    @basic.Annotated[(@ast.Ident, @ast.SubType), @basic.Location],
  ]
  /// Locals in scope, innermost last.
  scopes : Array[Map[String, @wap.Type]]
  /// The loops enclosing the expression being lowered, innermost last.
  loops : Array[LoopFrame]
  diagnostics : Array[@er.Report]
  mut counter : Int
}

///|
/// A function's shape, as the lowering needs it.
priv struct FnSig {
  params : Array[@wap.Type]
  results : Array[@wap.Type]
  /// The name the emitted module uses.
  emitted : String
}

///|
/// One enclosing loop: the labels `break` and `continue` resolve to.
priv struct LoopFrame {
  name : String?
  /// The label a `continue` branches to -- the loop's own.
  continue_label : String
  /// The label a `break` branches to, if one has been generated.
  mut break_label : String?
  /// Whether anything actually used the break label, so an unused block
  /// wrapper is not emitted.
  mut break_used : Bool
  /// Whether a `continue` branched to the loop's own label.
  mut continue_used : Bool
}

///|
/// A fresh lowering for one module.
fn Lowering::new(module_name : String, entry~ : ModuleSource) -> Lowering {
  {
    current: module_name,
    modules: Map([]),
    imports: Map([]),
    visible: Map([]),
    line_maps: Map([]),
    here: LineMap::of(entry),
    spans: @build.Spans::new(fname="<wap>"),
    types: Map([]),
    enum_members: Map([]),
    member_owner: Map([]),
    funcs: Map([]),
    methods: Map([]),
    method_owners: Map([]),
    globals: Map([]),
    foreign: Map([]),
    anon: Map([]),
    extra_types: [],
    scopes: [Map([])],
    loops: [],
    diagnostics: [],
    counter: 0,
  }
}

///|
/// Point the span mapper at a module's file.
fn Lowering::enter(self : Lowering, name : String) -> Unit {
  self.current = name
  match self.line_maps.get(name) {
    Some(m) => self.here = m
    None => ()
  }
}

///|
/// Report a problem and keep going, so one mistake does not hide the rest.
fn Lowering::error(
  self : Lowering,
  msg : String,
  span : @wap.Span,
  help? : String,
) -> Unit {
  let mut r = @er.Report::error(msg)
  if @wap.has_source(span) {
    r = r.with_label(@er.Label::primary(self.here.src, span))
  }
  match help {
    Some(h) => r = r.with_help(h)
    None => ()
  }
  self.diagnostics.push(r)
}

///|
/// A wap span as a Wax source location.
///
/// Mapping real offsets rather than handing everything a synthetic span is what
/// makes a Wax type error point into the .wap file the programmer wrote. A node
/// with no source -- one the lowering invented, or one a code generator built
/// without source text -- gets a fresh synthetic location instead, because two
/// bindings in one function may never share a span.
fn Lowering::loc(self : Lowering, span : @wap.Span) -> @basic.Location {
  if !@wap.has_source(span) || self.here.text_empty {
    return self.spans.fresh()
  }
  let start = self.position(span.start)
  let end = self.position(span.start + span.len)
  { start, end, }
}

///|
fn Lowering::position(self : Lowering, offset : Int) -> @basic.Position {
  // The last line start at or before `offset`.
  let mut lo = 0
  let starts = self.here.starts
  let mut hi = starts.length() - 1
  while lo < hi {
    let mid = (lo + hi + 1) / 2
    if starts[mid] <= offset {
      lo = mid
    } else {
      hi = mid - 1
    }
  }
  { fname: self.here.fname, lnum: lo + 1, bol: starts[lo], cnum: offset, }
}

///|
/// A location that is distinct from every other, for a node the lowering
/// invented.
fn Lowering::fresh_loc(self : Lowering) -> @basic.Location {
  self.spans.fresh()
}

///|
/// A generated name, unique within the module.
fn Lowering::gensym(self : Lowering, stem : String) -> String {
  self.counter += 1
  stem + "__" + self.counter.to_string()
}

///|
/// A bare name, resolved to the module that owns it.
///
/// A name written with a dot already says which module it means. A bare one
/// belongs to the module being lowered -- there is no implicit import, so a
/// name from elsewhere is always written `module.name`.
fn Lowering::qualify(self : Lowering, name : String) -> String {
  if self.foreign.contains(name) || self.current == "" {
    return name
  }
  if name.contains(".") {
    return name
  }
  self.current + "." + name
}

///|
/// The name the emitted module uses for a qualified wap name.
///
/// This is the `pv_`/`pvt_` convention in `stdlib/collections/persistent_vector.wax`
/// done by the compiler instead of by hand. One wasm module comes out, with one
/// flat namespace, exactly as before -- the prefixes are just no longer typed.
fn Lowering::mangle_qualified(self : Lowering, qualified : String) -> String {
  if self.foreign.contains(qualified) {
    return qualified
  }
  qualified.replace_all(old=".", new="__")
}

///|
/// Qualify and mangle in one step, for a name as it was written.
fn Lowering::mangle(self : Lowering, name : String) -> String {
  self.mangle_qualified(self.qualify(name))
}

///|
/// The emitted name of a method.
fn Lowering::mangle_method(
  self : Lowering,
  typ : String,
  name : String,
) -> String {
  self.mangle_qualified(self.qualify(typ) + "__" + name)
}

///|
/// An identifier at a span.
fn Lowering::ident(
  self : Lowering,
  name : String,
  span : @wap.Span,
) -> @ast.Ident {
  { name, loc: self.loc(span), }
}

// ------------------------------------------------------------------ scopes

///|
/// The qualified name a `module.thing` reference means, when that is what it
/// is.
///
/// A dot is a field access on a value and a qualifier on a module, and the two
/// are told apart the only way they can be: a local wins, and what is left has
/// to be a module the current one imported.
fn Lowering::module_ref(
  self : Lowering,
  recv : @wap.Node,
  name : String,
) -> String? {
  match recv.it {
    Var(m) =>
      if self.local_type(m) is Some(_) {
        None
      } else if self.modules.contains(m) {
        Some(m + "." + name)
      } else {
        None
      }
    _ => None
  }
}

///|
/// Refuse a reference to something another module did not mark `pub`.
fn Lowering::check_visible(
  self : Lowering,
  qualified : String,
  span : @wap.Span,
) -> Unit {
  if !qualified.contains(".") {
    return
  }
  let owner = qualified.split(".").collect()[0].to_owned()
  if owner == self.current || !self.modules.contains(owner) {
    return
  }
  if !self.imports.get(self.current).map_or(false, s => s.contains(owner)) {
    self.error(
      "`" + self.current + "` does not import `" + owner + "`",
      span,
      help="add `import " + owner + "` at the top of the module",
    )
    return
  }
  if !self.visible.contains(qualified) {
    self.error(
      "`" + qualified + "` is not `pub`",
      span,
      help="a declaration is private to its module unless it is written `pub`",
    )
  }
}

///|
/// Enter a nested scope.
fn Lowering::push_scope(self : Lowering) -> Unit {
  self.scopes.push(Map([]))
}

///|
/// Leave the innermost scope.
fn Lowering::pop_scope(self : Lowering) -> Unit {
  let _ = self.scopes.pop()
}

///|
/// Record a local's type.
fn Lowering::bind(self : Lowering, name : String, typ : @wap.Type) -> Unit {
  self.scopes[self.scopes.length() - 1][name] = typ
}

///|
/// The declared type of a local, if it is one.
fn Lowering::local_type(self : Lowering, name : String) -> @wap.Type? {
  for i = self.scopes.length() - 1; i >= 0; i = i - 1 {
    match self.scopes[i].get(name) {
      Some(t) => return Some(t)
      None => ()
    }
  }
  None
}
