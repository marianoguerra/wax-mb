// The operand stack.
//
// Ported from wax/src/lib-wax/typing.ml, where it is threaded through a state
// monad -- `let* x = e` reads the stack, may push and pop, and hands the new
// one to the continuation -- so that the instruction cases read top to bottom
// instead of passing it by hand.
//
// Here it is a mutable field instead. That is a deliberate simplification
// rather than a transcription: the monad exists to hide the threading, MoonBit
// hides it with a `mut`, and the instruction cases read the same either way.
// Nothing else about the design changes -- the stack itself is still the
// reference's immutable spine, so a saved stack really is a snapshot.

///|
/// The operand stack.
///
/// Three of the four cases are not "the stack is empty" in different words, and
/// keeping them apart is what stops one mistake becoming a cascade:
///
///   * `Empty` is a genuine underflow, and reports.
///   * `Unreachable` is the polymorphic stack of dead code -- after a `br`, a
///     `return`, an `unreachable`. Pops yield a fresh `Unknown` and consume
///     nothing, and the dead-code lint keys on it.
///   * `Poisoned` is what an already-reported failure leaves behind: a producer
///     that did not resolve, or an underflow. Pops yield `Error` SILENTLY,
///     because whatever went wrong has been said once already.
pub(all) enum Stack {
  Unreachable
  Empty
  Poisoned
  Cons(@basic.Location?, @infer.Cell[@infer.InferredType], Stack)
}

///|
/// One pending-value underflow: the counts to report, and whether they have
/// been.
///
/// The placeholder cell recorded alongside lets the hole that ends up consuming
/// it report at its own location, rather than the popping code needing to know
/// how the missing values are distributed.
pub(all) struct MissingBatch {
  mut hole_reported : Bool
  hole_actual : Int
  hole_expected : Int
}

///|
/// Which side of an instruction a stack complaint is about, which decides both
/// the wording and where the caret goes.
pub(all) enum StackKind {
  Input
  Output
  Holes
} derive(Eq, Debug)

///|
/// The stack, and the underflow placeholders accumulated while checking one
/// function.
pub struct Operands {
  mut stack : Stack
  /// Reset per function.
  missing_holes : Array[(@infer.Cell[@infer.InferredType], MissingBatch)]
}

///|
pub fn Operands::new() -> Operands {
  { stack: Empty, missing_holes: [] }
}

///|
/// Run `f` on a fresh empty stack, restoring what was there before.
///
/// The stack is immutable, so saving it really is a snapshot -- which is what
/// lets a block be checked without its operands leaking in or out.
pub fn[A] Operands::with_empty(self : Operands, f : () -> A) -> (A, Stack) {
  let saved = self.stack
  self.stack = Empty
  let result = f()
  let inner = self.stack
  self.stack = saved
  (result, inner)
}

///|
/// Take the top operand's type, whatever it is.
///
/// No diagnostic is emitted here. The placeholder is recorded with its counts
/// so the hole that consumes it reports at its own location, and an underflow
/// POISONS the stack -- so one missing value is tracked once rather than once
/// per subsequent pop.
pub fn Operands::pop_any(
  self : Operands,
  batch : Ref[MissingBatch?],
  current : Int,
  expected : Int,
) -> @infer.Cell[@infer.InferredType] {
  match self.stack {
    Unreachable => @infer.Cell::make(Unknown)
    Poisoned => {
      let cell = @infer.Cell::make(@infer.InferredType::Error)
      // Poisoned by this very run's underflow: this value is missing too, so
      // track it under the same batch, and the report lands on the first hole
      // without a value. A stack poisoned BEFORE this run keeps plain, silent
      // placeholders.
      if batch.val is Some(b) {
        self.missing_holes.push((cell, b))
      }
      cell
    }
    Cons(_, ty, rest) => {
      self.stack = rest
      ty
    }
    Empty => {
      let cell = @infer.Cell::make(@infer.InferredType::Error)
      let b = {
        hole_reported: false,
        hole_actual: current,
        hole_expected: expected,
      }
      batch.val = Some(b)
      self.missing_holes.push((cell, b))
      self.stack = Poisoned
      cell
    }
  }
}

///|
/// Take `count` pending values, newest last, with the underflow batch if one
/// occurred.
pub fn Operands::pop_many(
  self : Operands,
  count : Int,
) -> (Array[@infer.Cell[@infer.InferredType]], MissingBatch?) {
  let batch : Ref[MissingBatch?] = @ref.new(None)
  let out : Array[@infer.Cell[@infer.InferredType]] = []
  for n in 0..<count {
    out.push(self.pop_any(batch, n, count))
  }
  // Popped top-first, so reverse to get them in operand order.
  out.rev_in_place()
  (out, batch.val)
}

///|
/// Take the top operand, checking it against an expected type.
pub fn Operands::pop(
  self : Operands,
  info : @type_store.SubtypingInfo,
  diagnostics : @diagnostic.Context,
  kind : StackKind,
  location : @basic.Location,
  current : Int,
  expected : Int,
  ty : @infer.Cell[@infer.InferredType],
) -> Unit {
  match self.stack {
    // Dead code absorbs anything, and a poisoned stack has already complained.
    Unreachable | Poisoned => ()
    Cons(loc_opt, ty_, rest) =>
      match ty_.get() {
        Error =>
          // The top value is the poison of an already-reported error. LEAVE it
          // on the stack rather than consuming it, so it keeps suppressing
          // leftover-stack complaints in this scope. Consuming it would strip
          // the poison and let a cascade surface: a rejected instruction
          // recovers as an `Error` value where the right answer was void, and
          // popping that phantom as the block's result leaves the genuine value
          // below it reading as a bogus leftover.
          ()
        _ => {
          if !subtype(info, ty_, ty) {
            match loc_opt {
              Some(loc) => expression_type_mismatch(diagnostics, loc, ty_, ty)
              None => type_mismatch(diagnostics, location, current, ty_, ty)
            }
          }
          self.stack = rest
        }
      }
    Empty => {
      short_stack(
        diagnostics,
        kind,
        // The caret goes where the missing value should have been: before the
        // instruction for an argument, after it for a result.
        match kind {
          Input => loc_first_char(location)
          Holes => location
          Output => loc_last_char(location)
        },
        expected - current - 1,
        expected,
      )
      // As in `pop_any`: an underflow poisons, so one missing value is reported
      // once and not once per remaining pop.
      self.stack = Poisoned
    }
  }
}

///|
/// Take an instruction's arguments, rightmost first -- which is the order they
/// were pushed in.
pub fn Operands::pop_args(
  self : Operands,
  info : @type_store.SubtypingInfo,
  diagnostics : @diagnostic.Context,
  kind : StackKind,
  location : @basic.Location,
  args : Array[@infer.Cell[@infer.InferredType]],
) -> Unit {
  let len = args.length()
  for i in 0..<len {
    let pos = len - 1 - i
    self.pop(info, diagnostics, kind, location, pos, len, args[pos])
  }
}

///|
/// Push a value.
///
/// Pushing an `Error` POISONS the stack rather than stacking the error. The
/// failed producer's true arity is unknown -- a call that did not resolve may
/// have produced any number of values -- so later consumers have to absorb any
/// count silently. Reporting an underflow there would anchor a derived error
/// away from the original fault.
pub fn Operands::push(
  self : Operands,
  loc : @basic.Location?,
  ty : @infer.Cell[@infer.InferredType],
) -> Unit {
  match ty.get() {
    Error =>
      self.stack = match self.stack {
        Unreachable => Unreachable
        _ => Poisoned
      }
    _ => self.stack = Cons(loc, ty, self.stack)
  }
}

///|
/// Push an instruction's results.
///
/// A location is attached only when there is exactly one result: with several,
/// no single value is "the" thing at that span, and a mismatch on one of them
/// is better reported against the instruction.
pub fn Operands::push_results(
  self : Operands,
  loc : @basic.Location,
  results : Array[@infer.Cell[@infer.InferredType]],
) -> Unit {
  let at = if results.length() == 1 { Some(loc) } else { None }
  for r in results {
    self.push(at, r)
  }
}

///|
/// Mark everything after this point as dead code.
pub fn Operands::set_unreachable(self : Operands) -> Unit {
  self.stack = Unreachable
}

///|
/// The values still on a stack, and whether any of them is poison.
///
/// A value of type `Error` means an error has already been reported, so if any
/// leftover carries one the stack is unreliable and a leftover complaint would
/// be a cascade. The locations are of the leftovers that have one; a value with
/// only a recovery placeholder location is still a real value, just not
/// locatable.
pub fn leftovers(st : Stack) -> (Array[@basic.Location], Bool) {
  let locs : Array[@basic.Location] = []
  let mut has_error = false
  for cur = st {
    match cur {
      Cons(loc, cell, rest) => {
        if cell.get() is Error {
          has_error = true
        }
        if loc is Some(l) {
          locs.push(l)
        }
        continue rest
      }
      _ => break
    }
  }
  // Gathered top-first; report in source order.
  locs.rev_in_place()
  (locs, has_error)
}

///|
/// An empty span at the first character of `loc`.
fn loc_first_char(loc : @basic.Location) -> @basic.Location {
  { start: loc.start, end: loc.start }
}

///|
/// An empty span at the last character of `loc`.
fn loc_last_char(loc : @basic.Location) -> @basic.Location {
  { start: loc.end, end: loc.end }
}
