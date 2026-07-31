// Module-level syntax: attributes, imports, segments, and the fields a module
// is a list of.

///|
/// An attribute, `#[name]` or `#[name = value]`.
pub(all) struct Attribute {
  attr_name : String
  /// `#[export = "f"]` carries one; `#[start]` does not.
  attr_value : Instr[Location]?
  /// A conditional-compilation guard, `#[export = "f", if not(portable)]`,
  /// making just this attribute conditional -- independently of whether the
  /// field it decorates is itself reachable. Only `export` may be guarded.
  /// Located at its `if` keyword.
  attr_guard : Annotated[Cond, Location]?
  /// The span of the whole `#[...]`, so a diagnostic about the attribute names
  /// the attribute rather than falling back to the value (which a valueless
  /// attribute lacks) or to the whole field.
  attr_span : Location
} derive(Eq, Debug)

///|
pub type Attributes = Array[Attribute]

///|
/// What an `import "module" { ... }` entry brings in.
///
/// Imports have no body, so these carry only type-level information.
pub(all) enum ImportKind {
  /// `exact` marks an exact function import, `fn f: !t`.
  Func(typ~ : Ident?, sign~ : FuncType?, exact~ : Bool)
  Global(mut_~ : Bool, typ~ : ValType)
  Tag(typ~ : Ident?, sign~ : FuncType?)
  Memory(
    address_type~ : AddressType,
    limits~ : (UInt64, UInt64?)?,
    page_size_log2~ : Int?,
    shared~ : Bool
  )
  Table(
    address_type~ : AddressType,
    reftype~ : RefType,
    limits~ : (UInt64, UInt64?)?
  )
} derive(Eq, Debug)

///|
/// A single imported entity.
///
/// It is imported under `id` unless a name-only `#[import = "name"]` attribute
/// overrides it. `attributes` also carries e.g. `#[export]` to re-export it.
pub(all) struct ImportDecl {
  id : Ident
  kind : ImportKind
  attributes : Attributes
} derive(Eq, Debug)

///|
/// One element of a data segment's contents.
///
/// Holds no instructions: every value is a literal. In a run the element type
/// is stated once and the values are RAW literal strings, packed
/// little-endian -- raw for the same round-tripping reason as numeric literals.
pub(all) enum DataElem {
  /// A string literal's raw bytes.
  Str(String)
  /// A scalar numeric run, `[f32: 1.5, nan, ...]`.
  Run(StorageType, Array[Annotated[String, Location]])
  /// A v128 run, `[v128: i32x4(1,2,3,4), ...]`.
  V128Run(Array[Annotated[V128, Location]])
} derive(Eq, Debug)

///|
/// A data segment attached to a memory definition.
pub(all) struct MemData[Info] {
  data_name : Ident?
  offset : Instr[Info]
  init : Array[DataElem]
} derive(Eq, Debug)

///|
/// Whether a data segment is copied in at instantiation or only on demand.
pub(all) enum DataMode[Info] {
  Passive
  Active(Ident, Instr[Info])
} derive(Eq, Debug)

///|
pub(all) enum ElemMode[Info] {
  EPassive
  EActive(Ident, Instr[Info])
} derive(Eq, Debug)

///|
/// A top-level definition.
pub(all) enum ModuleField[Info] {
  Type(RecType)
  Func(
    name~ : Ident,
    typ~ : Ident?,
    sign~ : FuncType?,
    body~ : (Label?, Array[Instr[Info]]),
    attributes~ : Attributes
  )
  Global(
    name~ : Ident,
    mut_~ : Bool,
    typ~ : ValType?,
    def~ : Instr[Info],
    attributes~ : Attributes
  )
  Tag(name~ : Ident, typ~ : Ident?, sign~ : FuncType?, attributes~ : Attributes)
  Memory(
    name~ : Ident,
    address_type~ : AddressType,
    limits~ : (UInt64, UInt64?)?,
    page_size_log2~ : Int?,
    shared~ : Bool,
    data~ : Array[MemData[Info]],
    attributes~ : Attributes
  )
  Data(
    name~ : Ident?,
    mode~ : DataMode[Info],
    init~ : Array[DataElem],
    attributes~ : Attributes
  )
  Table(
    name~ : Ident,
    address_type~ : AddressType,
    reftype~ : RefType,
    limits~ : (UInt64, UInt64?)?,
    init~ : Instr[Info]?,
    attributes~ : Attributes
  )
  Elem(
    name~ : Ident,
    reftype~ : RefType,
    mode~ : ElemMode[Info],
    init~ : Array[Instr[Info]],
    attributes~ : Attributes
  )
  /// A single import, `import "module" fn f();`.
  Import(
    module_~ : Annotated[String, Location],
    decl~ : Annotated[ImportDecl, Location]
  )
  /// A grouped import block: several imports sharing one module name. Kept
  /// distinct from a run of single imports because the text form is
  /// authoritative for import layout, and the binary encoder reproduces it.
  ImportGroup(
    module_~ : Annotated[String, Location],
    decls~ : Array[Annotated[ImportDecl, Location]]
  )
  /// A module-level inner attribute, `#![module = "name"]`. Attached to the
  /// whole module rather than to a field.
  ModuleAnnotation(Attributes)
  /// A conditional-compilation group at module level. Built by the same
  /// post-pass as the statement-level `IfAnnotation`; see parser.mbty.
  Conditional(
    cond~ : Cond,
    then_fields~ : Annotated[
      Array[Annotated[ModuleField[Info], Location]],
      Location,
    ],
    else_fields~ : Annotated[
      Array[Annotated[ModuleField[Info], Location]],
      Location,
    ]?
  )
} derive(Eq, Debug)

///|
/// A module: a list of spanned fields.
///
/// There is no wrapper node -- a Wax file IS its field list.
pub type Module[Info] = Array[Annotated[ModuleField[Info], Location]]

///|
/// The module type the parser produces, before any type checking.
pub type LocModule = Module[Location]
