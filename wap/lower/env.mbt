// The lowering environment: names, spans, and what is known about each of them.

///|
/// Everything the lowering needs to know that is not in the expression it is
/// looking at.
priv struct Lowering {
  module_name : String
  fname : String
  line_starts : Array[Int]
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
  src : @er.SourceId
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
fn Lowering::new(
  module_name : String,
  fname~ : String,
  text~ : String,
  src~ : @er.SourceId,
) -> Lowering {
  let line_starts = [0]
  let cs = text.to_array()
  for i, c in cs {
    if c == '\n' {
      line_starts.push(i + 1)
    }
  }
  {
    module_name,
    fname,
    line_starts,
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
    src,
    counter: 0,
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
    r = r.with_label(@er.Label::primary(self.src, span))
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
  if !@wap.has_source(span) {
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
  let mut hi = self.line_starts.length() - 1
  while lo < hi {
    let mid = (lo + hi + 1) / 2
    if self.line_starts[mid] <= offset {
      lo = mid
    } else {
      hi = mid - 1
    }
  }
  { fname: self.fname, lnum: lo + 1, bol: self.line_starts[lo], cnum: offset, }
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
/// The name the emitted module uses for a wap name.
///
/// This is the `pv_`/`pvt_` convention in `stdlib/collections/persistent_vector.wax`
/// done by the compiler instead of by hand.
fn Lowering::mangle(self : Lowering, name : String) -> String {
  if self.foreign.contains(name) || self.module_name == "" {
    name
  } else {
    self.module_name + "__" + name
  }
}

///|
/// The emitted name of a method.
fn Lowering::mangle_method(
  self : Lowering,
  typ : String,
  name : String,
) -> String {
  self.mangle(typ + "__" + name)
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
