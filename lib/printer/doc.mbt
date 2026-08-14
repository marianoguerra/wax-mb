// A streaming pretty-printer.
//
// Ported from wax/src/lib-utils/printer.ml. The imperative builder API
// (string, space, box, ...) emits a FLAT TOKEN STREAM straight into a layout
// engine; nothing is ever materialised as a document tree. That is what gives
// genuine hard breaks, column awareness and break coalescing under our own
// control, with bounded memory -- the engine buffers only the ~width of
// lookahead a break decision actually needs.
//
// Ported rather than replaced by moonbit-community/prettyprinter: byte-exact
// output is the whole point here, and an engine with its own opinions about
// grouping and fitting would drift from the reference in ways no amount of
// tuning would close.

///|
/// How strongly a break wants to end the line.
///
/// Cut and Space are SOFT: they flatten inside a group that fits. Newline and
/// BlankLine always break. Two adjacent breaks coalesce into the stronger.
pub(all) enum BreakStrength {
  Cut
  Space
  Newline
  BlankLine
} derive(Eq, Debug)

///|
pub fn BreakStrength::strength(self : BreakStrength) -> Int {
  match self {
    Cut => 0
    Space => 1
    Newline => 2
    BlankLine => 3
  }
}

///|
/// How a group lays its soft breaks out.
pub(all) enum GKind {
  /// Fill: each soft break wraps independently, as needed.
  GBox
  /// Same fill semantics; kept distinct for parity with OCaml's Format.
  GHov
  /// All-or-nothing: the whole group flat, or every soft break wraps.
  GHv
  /// Every soft break wraps.
  GV
  /// Soft breaks never wrap; hard ones still do.
  GH
} derive(Eq, Debug)

///|
/// One token of the flat stream the builder feeds the engine.
///
/// A group, nest or if-broken opens with its own token and closes with a
/// matching `TEnd`.
pub(all) enum Token {
  /// Display width, then the payload. The width is carried rather than
  /// recomputed because it is not the string's length: see unicode/.
  TText(Int, String)
  TBreak(BreakStrength)
  TBegin(GKind)
  TNest(Int)
  /// Content emitted only when the enclosing group is laid out BROKEN -- the
  /// trailing comma after the last element of a list that wraps. It never
  /// counts toward the fit decision.
  TIfBroken
  TEnd
} derive(Eq, Debug)

///|
/// A live layout mode.
pub(all) enum Mode {
  Flat
  Brkm
  Fill
} derive(Eq, Debug)

///|
/// A live layout frame: where breaks indent to, and how they behave.
struct Frame {
  findent : Int
  fmode : Mode
} derive(Eq, Debug)

///|
/// The outcome of a fit scan.
///
/// `Susp` means the scan ran out of buffered input and parked its state, to be
/// resumed on the next fed token -- so each buffered token is scanned once
/// rather than re-scanned from scratch.
enum ScanResult {
  Fits
  Nofit
  Susp
} derive(Eq, Debug)
