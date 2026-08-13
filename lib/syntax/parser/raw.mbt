// Conditional-compilation groups, `#[if(c)] { ... } #[else] { ... }`.
//
// THE ONE THING THE GRAMMAR CANNOT DO ITSELF. Pairing an `#[if]` with a
// following `#[else]` is the dangling-else problem, and since `#[else]` is not
// a single token it is not LALR(1). So each brace group parses into a MARKER,
// and a post-pass pairs adjacent markers, leaving everything else untouched.
//
// This mirrors the reference's `raw_stmt`/`process_stmts` and
// `raw_field`/`lower_fields` exactly, including the wrinkle about `;`.

///|
/// A statement as parsed, before conditional groups are paired.
pub(all) enum RawStmt {
  Plain(Instr[Location])
  /// An empty `;` statement.
  ///
  /// Kept in the raw list rather than dropped at the `;` production, because
  /// the statement-level hint production inspects the raw tail and must be able
  /// to insist on being ADJACENT to its instruction: `#[likely] ; f()` is
  /// rejected rather than the hint silently reaching `f()` across the `;`.
  /// `process_stmts` strips these before pairing, so an `#[if]`/`#[else]` pair
  /// separated by a stray `;` still pairs.
  Semi
  If((Position, Position), Cond, Body[Location])
  Else((Position, Position), Body[Location])
}

///|
/// Pair adjacent `#[if]`/`#[else]` markers into `IfAnnotation` nodes.
fn pair_stmts(l : ArrayView[RawStmt]) -> Array[Instr[Location]] {
  let out : Array[Instr[Location]] = []
  let mut i = 0
  while i < l.length() {
    match l[i] {
      Plain(instr) => {
        out.push(instr)
        i += 1
      }
      Semi => i += 1 // filtered by process_stmts; belt and braces
      If(p, cond, then_body) =>
        // Each branch keeps its OWN `#[if]`/`#[else] { ... }` span, marker
        // included, on its located body -- not just the combined span on the
        // node -- so a consumer such as the editor's dead-branch dimming can
        // locate a single branch.
        if i + 1 < l.length() && l[i + 1] is Else(ep, else_body) {
          out.push(
            with_loc(
              (p.0, ep.1),
              IfAnnotation(
                cond~,
                then_body=respan(then_body, p),
                else_body=Some(respan(else_body, ep)),
              ),
            ),
          )
          i += 2
        } else {
          out.push(
            with_loc(
              p,
              IfAnnotation(
                cond~,
                then_body=respan(then_body, p),
                else_body=None,
              ),
            ),
          )
          i += 1
        }
      Else(p, _) => {
        record_error(
          loc_of(p),
          "An '#[else]' must directly follow an '#[if(...)]' group.",
        )
        i += 1
      }
    }
  }
  out
}

///|
/// Strip empty statements, then pair.
pub fn process_stmts(l : Array[RawStmt]) -> Array[Instr[Location]] {
  let kept : Array[RawStmt] = []
  for s in l {
    if !(s is Semi) {
      kept.push(s)
    }
  }
  pair_stmts(kept[:])
}

///|
/// A located list of module fields, the payload of a module-level conditional.
pub type LocatedFields = Annotated[
  Array[Annotated[ModuleField[Location], Location]],
  Location,
]

///|
/// A module field as parsed, before conditional groups are paired.
///
/// Braces are mandatory here, so nesting is expressed by the braces -- a nested
/// `#[if]` lives inside a branch's field list -- and pairing is plain
/// adjacency, with no dangling-else search.
pub(all) enum RawField {
  FPlain(Annotated[ModuleField[Location], Location])
  FIf((Position, Position), Cond, LocatedFields)
  FElse((Position, Position), LocatedFields)
}

///|
/// Pair adjacent `#[if]`/`#[else]` field markers into `Conditional` fields.
pub fn lower_fields(
  l : Array[RawField],
) -> Array[Annotated[ModuleField[Location], Location]] {
  let out : Array[Annotated[ModuleField[Location], Location]] = []
  let mut i = 0
  while i < l.length() {
    match l[i] {
      FPlain(f) => {
        out.push(f)
        i += 1
      }
      FIf(p, cond, then_fields) =>
        if i + 1 < l.length() && l[i + 1] is FElse(ep, else_fields) {
          out.push(
            annot(
              (p.0, ep.1),
              ModuleField::Conditional(
                cond~,
                then_fields=respan(then_fields, p),
                else_fields=Some(respan(else_fields, ep)),
              ),
            ),
          )
          i += 2
        } else {
          out.push(
            annot(
              p,
              ModuleField::Conditional(
                cond~,
                then_fields=respan(then_fields, p),
                else_fields=None,
              ),
            ),
          )
          i += 1
        }
      FElse(p, _) => {
        record_error(
          loc_of(p),
          "An '#[else]' must directly follow an '#[if(...)]' field.",
        )
        i += 1
      }
    }
  }
  out
}

///|
/// Apply a module field's leading attributes.
///
/// When there are attributes the field's span is WIDENED to cover them, so
/// comments and blank lines written before the attributes attach to the field
/// rather than to an attribute's inner expression.
pub fn attributed(
  p : (Position, Position),
  attributes : Attributes,
  build : (Attributes) -> Annotated[ModuleField[Location], Location],
) -> Annotated[ModuleField[Location], Location] {
  let f = build(attributes)
  if attributes.is_empty() {
    f
  } else {
    annot(p, f.desc)
  }
}
