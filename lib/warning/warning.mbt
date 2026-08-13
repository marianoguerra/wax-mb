// Named, groupable warnings whose reporting level is configurable.
//
// Each warning has a stable hyphenated name and may belong to one or more
// groups; a policy maps each to a level, so the same warning can be silenced,
// shown, or made fatal depending on the invocation. See `-W`.
//
// Ported in FULL even though the front end emits none of these: the type
// checker is what generates warnings, and rebuilding this layer later would
// mean re-verifying every byte-exact renderer a second time.

///|
/// A named warning.
pub(all) enum Warning {
  /// A local that is declared but never read.
  UnusedLocal
  /// A module field nothing reachable references. Liveness is reachability
  /// from the roots, so a dead CYCLE of mutually recursive functions is
  /// reported too.
  UnusedField
  /// An imported field nothing reachable references.
  UnusedImport
  /// A block label that is declared but never branched to.
  UnusedLabel
  /// A global declared mutable but never assigned. Only a module-defined,
  /// non-exported global: an import's mutability is fixed by the linking
  /// contract, and an exported one can be assigned by the host.
  UnnecessaryMut
  /// A shift by a constant count at least the operand's bit width. Wasm masks
  /// the count modulo the width, so this is almost certainly not what was
  /// meant.
  ShiftOverflow
  /// An operation that always traps on a constant operand.
  ConstantTrap
  /// A comparison whose result does not depend on its variable operand.
  TautologicalComparison
  /// A branch, loop, or select condition that is constant.
  ConstantCondition
  /// A side-effect-free result computed and then discarded.
  UnusedResult
  /// A statement following an unconditional branch, return, or unreachable.
  DeadCode
  /// A cast or test whose operand can never have the target type.
  CastAlwaysFails
  /// A trapping or effectful operation inside a branch of `?:`, which compiles
  /// to a `select` and so evaluates BOTH branches.
  EagerSelect
  /// Operators whose relative precedence is easy to misremember, mixed without
  /// parentheses. The code is correct; a reader may misread the grouping.
  Precedence
  /// An operation with no effect on its result.
  RedundantOperation
  /// Path-sensitive validation gave up after too many configurations.
  TruncatedCoverage
  /// Converting from wasm, a name collided and was renamed.
  NamingConflict
  /// Converting from wasm, a name is a Wax reserved word and was renamed.
  ReservedWordRename
  /// Converting from wasm, an unnamed but referenced parameter was given a
  /// generated name.
  GeneratedName
  /// `x = x op e` could read as `x op= e`.
  CompoundAssignment
  /// `{x: x}` could use the punning shorthand `{x}`.
  FieldPunning
  /// A `let` annotation the inferred type already makes redundant.
  RedundantAnnotation
  /// A string holds a bidirectional control character that can make the source
  /// read differently than it runs -- a "Trojan Source" character.
  ConfusableUnicode
} derive(Eq, Debug)

///|
/// Every named warning.
pub let all : Array[Warning] = [
  UnusedLocal,
  UnusedField,
  UnusedImport,
  UnusedLabel,
  UnnecessaryMut,
  ShiftOverflow,
  ConstantTrap,
  TautologicalComparison,
  ConstantCondition,
  UnusedResult,
  DeadCode,
  CastAlwaysFails,
  EagerSelect,
  Precedence,
  RedundantOperation,
  TruncatedCoverage,
  NamingConflict,
  ReservedWordRename,
  GeneratedName,
  CompoundAssignment,
  FieldPunning,
  RedundantAnnotation,
  ConfusableUnicode,
]

///|
/// The stable, hyphenated name.
pub fn Warning::name(self : Warning) -> String {
  match self {
    UnusedLocal => "unused-local"
    UnusedField => "unused-field"
    UnusedImport => "unused-import"
    UnusedLabel => "unused-label"
    UnnecessaryMut => "unnecessary-mut"
    // The name does NOT track the constructor here.
    ShiftOverflow => "shift-count-overflow"
    ConstantTrap => "constant-trap"
    TautologicalComparison => "tautological-comparison"
    ConstantCondition => "constant-condition"
    UnusedResult => "unused-result"
    DeadCode => "dead-code"
    CastAlwaysFails => "cast-always-fails"
    EagerSelect => "eager-select"
    Precedence => "precedence"
    RedundantOperation => "redundant-operation"
    TruncatedCoverage => "truncated-coverage"
    NamingConflict => "naming-conflict"
    ReservedWordRename => "reserved-word-rename"
    GeneratedName => "generated-name"
    CompoundAssignment => "compound-assignment"
    FieldPunning => "field-punning"
    RedundantAnnotation => "redundant-annotation"
    ConfusableUnicode => "confusable-unicode"
  }
}

///|
/// A one-line description, for help text.
pub fn Warning::description(self : Warning) -> String {
  match self {
    UnusedLocal => "A local that is declared but never read."
    UnusedField => "A module field that is defined but never used."
    UnusedImport => "An imported module field that is never used."
    UnusedLabel => "A block label that is declared but never branched to."
    UnnecessaryMut =>
      "A mutable global that is never assigned, so it could be immutable."
    ShiftOverflow =>
      "A constant shift count is at least the operand's bit width (Wasm masks it)."
    ConstantTrap =>
      "An operation always traps on a constant operand (integer division by zero, or an out-of-range trapping conversion)."
    TautologicalComparison =>
      "A comparison whose result is constant (an unsigned comparison against zero, or identical operands)."
    ConstantCondition =>
      "A branch, loop, or select condition that is a constant."
    UnusedResult =>
      "The result of a side-effect-free expression is computed and then discarded."
    DeadCode =>
      "A statement is unreachable: it follows an unconditional branch, return, or unreachable."
    CastAlwaysFails =>
      "A reference cast or test whose operand can never have the target type, so it always traps (or is always false)."
    EagerSelect =>
      "A trapping or effectful operation in a branch of a '?:' (which compiles to a 'select', evaluating both branches unconditionally)."
    Precedence =>
      "Operators whose relative precedence is easy to misread are mixed without parentheses (a shift with arithmetic, or a comparison with a bitwise operator)."
    RedundantOperation =>
      "An operation with no effect on its result (an arithmetic identity, an absorbing operand, identical operands, a self-assignment, or a superfluous cast)."
    TruncatedCoverage =>
      "Path-sensitive validation gave up after too many configurations."
    NamingConflict => "A Wasm name collided with another and was renamed."
    ReservedWordRename => "A Wasm name is a reserved word and was renamed."
    GeneratedName => "An unnamed but used parameter was given a generated name."
    CompoundAssignment =>
      "A plain assignment 'x = x op e' could use the compound form 'x op= e'."
    FieldPunning => "A struct field 'x: x' could use the punning shorthand 'x'."
    RedundantAnnotation =>
      "A 'let' type annotation the inferred type already makes redundant."
    ConfusableUnicode =>
      "A string contains a bidirectional control character that can make the source read differently than it runs (a \"Trojan Source\" character)."
  }
}

///|
/// Whether this flags code removable with no change in behaviour.
///
/// An editor renders such a diagnostic faded -- LSP's
/// `DiagnosticTag.Unnecessary`. Kept beside the definitions so every consumer
/// classifies from one source.
pub fn Warning::is_unnecessary(self : Warning) -> Bool {
  match self {
    UnusedLocal | UnusedField | UnusedImport | UnusedLabel | DeadCode => true
    _ => false
  }
}
