// The type checker's working state: what a typed node carries, and the tables
// names resolve through.
//
// Ported from wax/src/lib-wax/typing_env.ml. Split out of the checker itself so
// the lints and the suggestion pass can read the same state without depending
// on the 13k lines that build it.

///|
/// What a node carries once the checker has resolved it: the storage types of
/// the values it leaves on the stack, and its span.
///
/// This is the ENTIRE interface between the checker and the code generator. The
/// lowering reads it at ~105 sites to pick opcodes -- `i32.add` against
/// `f64.add` against `i64.add` -- and nothing else about the checker's work
/// crosses that line.
pub type TypedAnnotation = (
  Array[@wasm_types.StorageType[@ast.Ident]?],
  @basic.Location,
)

///|
/// The same annotation before resolution, with the inference cells intact.
///
/// Resolution collapses distinctions the cells still hold: a flexible numeric
/// literal that has not picked a width, an unknown or unreachable type, an
/// inline anonymous composite type. The editor reads this form because a hover
/// wants to say `number` rather than the `i32` it would default to; the code
/// generator reads the resolved one because an opcode has to pick.
pub type InferredAnnotation = (
  Array[@infer.Cell[@infer.InferredType]],
  @basic.Location,
)

///|
/// What a resolved reference summarises, for a hover on a name that is not
/// itself an expression.
///
/// Kept as data rather than a rendered string: nothing is formatted until a
/// hover actually asks, so a plain check pays one boxing per reference and no
/// printing at all.
pub(all) enum HoverTarget {
  /// A variable's type.
  ValueType(@infer.InferredValType)
  /// A referenced type's definition.
  TypeDef(@ast.SubType)
}

///|
/// A resolved name or label reference: where it was used, where it was defined,
/// and what it resolves to.
///
/// There is more than one definition only under conditional compilation, where
/// a name may be declared in several mutually exclusive branches.
pub(all) struct Reference {
  use_ : @basic.Location
  definitions : Array[@basic.Location]
  hover : HoverTarget?
}

///|
/// Where references are recorded for go-to-definition, or `None` outside the
/// editor -- so an ordinary compile pays nothing for the feature.
pub type ResolveSink = Array[Reference]?

///|
/// Is this a real source span, rather than a synthesized node's?
///
/// A synthesized node -- an interned function type looked up for a call, a
/// desugared construct -- carries the dummy span, whose offset is the `-1`
/// sentinel rather than `0`. Only genuine source references are recorded.
pub fn is_source(l : @basic.Location) -> Bool {
  l.start.cnum >= 0
}

///|
pub fn same_span(a : @basic.Location, b : @basic.Location) -> Bool {
  a.start.cnum == b.start.cnum && a.end.cnum == b.end.cnum
}

///|
/// The single inference cell an instruction leaves on the stack, or `None` if
/// it leaves none or several.
///
/// The error-free counterpart of the checker's own `expression_type`, which
/// reports "an expression is expected here" and yields an error cell. A lint or
/// a suggestion reads the cell when there is exactly one and stays silent
/// otherwise, rather than emitting the diagnostic the checker already owns.
pub fn[Info] expression_type_opt(
  info : (Array[@infer.Cell[@infer.InferredType]], Info),
) -> @infer.Cell[@infer.InferredType]? {
  let (cells, _) = info
  if cells.length() == 1 {
    Some(cells[0])
  } else {
    None
  }
}

///|
/// The bottom reference type, nullable or not.
///
/// `None_` is a built-in abstract bottom heap type, so its internal form
/// carries no index into the type store and needs no context to build -- which
/// is what lets this be a plain value where the checker's own path threads one.
pub fn ref_none_valtype(nullable~ : Bool) -> @infer.InferredValType {
  {
    typ: Ref({ nullable, typ: None_ }),
    internal: Ref({ nullable, typ: None_ }),
    anon_comptype: None,
  }
}

///|
/// The concrete value type a cell stands for on its own, or `None` when it has
/// none yet.
///
/// A still-flexible literal takes its default width -- an integer or a bare
/// number becomes i32, a large one i64, a float f64. `Null` and `UnknownRef`
/// concretize to the nullable and non-nullable bottom reference respectively:
/// the latter because that is the type `null!` produced before `UnknownRef`
/// existed.
///
/// Pure and context-free, unlike the checker's own path, because the only
/// reference it can produce is the built-in bottom.
pub fn standalone_valtype(
  ty : @infer.Cell[@infer.InferredType],
) -> @infer.InferredValType? {
  match ty.get() {
    Valtype(v) => Some(v)
    Int | Number => Some(@infer.i32_valtype)
    LargeInt => Some(@infer.i64_valtype)
    Float => Some(@infer.f64_valtype)
    Null => Some(ref_none_valtype(nullable=true))
    UnknownRef => Some(ref_none_valtype(nullable=false))
    Int8 | Int16 | Unknown | Error | Collecting(_) => None
  }
}

///|
/// Record a punned struct-literal field's span -- the bare `x` standing for
/// `x: x`.
///
/// Such a span is both a field name and a variable use, so a rename has to
/// expand it (`x` becomes `x: new`) rather than replace it, and the editor
/// needs to know which spans those are.
pub fn record_pun(
  sink : Array[@basic.Location]?,
  name_info : @basic.Location,
) -> Unit {
  if sink is Some(r) && is_source(name_info) {
    r.push(name_info)
  }
}

///|
/// Record a struct field access, for member completion: the field's span --
/// possibly partial, since the cursor may be mid-word -- and what it is on.
pub fn record_members(
  sink : Array[(@basic.Location, @members.MemberReceiver)]?,
  field : @basic.Location,
  receiver : @members.MemberReceiver,
) -> Unit {
  if sink is Some(r) && is_source(field) {
    r.push((field, receiver))
  }
}

///|
/// Record a use and the definitions it binds to.
///
/// Synthesized definitions are dropped, and so is the self-reference a name's
/// own declaration makes when it looks itself up: go-to-definition on a
/// definition has nowhere useful to go.
pub fn record_reference(
  sink : ResolveSink,
  use_ : @basic.Location,
  definitions : Array[@basic.Location],
  hover? : HoverTarget? = None,
) -> Unit {
  guard sink is Some(r) && is_source(use_) else { return }
  let kept = definitions.filter(d => is_source(d) && !same_span(d, use_))
  if !kept.is_empty() {
    r.push({ use_, definitions: kept, hover })
  }
}
