// Branch-hinting and compilation-hints attributes.
//
// `#[likely]`, `#[freq = 16]`, `#[targets(f: 0.73)]` are advisory
// `metadata.code.*` metadata. The lexer has no dedicated tokens for them -- they
// are ordinary attributes -- so which hint an attribute stands for is recovered
// here, and anything else in a hint position is rejected.

///|
/// What a hint attribute asks for, before it has been checked against the
/// instruction it prefixes.
enum HintSetter {
  Branch(Bool)
  Freq(Int)
  Targets(Array[(Ident, Int)])
} derive(Debug)

///|
/// `metadata.code.instr_freq`: never optimize.
let never_opt : Int = 0

///|
/// `metadata.code.instr_freq`: always optimize.
let always_opt : Int = 127

///|
/// Encode an executions-per-call ratio as the section's offset base-2
/// logarithm, so 1.0 (once per call) becomes 32.
///
/// Clamped to [1, 64]: 0 and 127 are the reserved never/always values, which
/// have their own attributes.
fn freq_of_ratio(r : Double) -> Int {
  if r <= 0.0 {
    1
  } else {
    let l = @math.log2(r).floor().to_int() + 32
    if l < 1 {
      1
    } else if l > 64 {
      64
    } else {
      l
    }
  }
}

///|
/// A call-target frequency is written as a fraction of 1 and stored as a whole
/// percent, which is what the section holds.
fn target_percent(p : (Position, Position), n : String) -> Int {
  let f = @string.parse_double(n) catch {
    _ =>
      fail_at(
        loc_of(p),
        "A call-target frequency must be between 0 and 1.",
        default=0.0,
      )
  }
  if f < 0.0 || f > 1.0 {
    record_error(loc_of(p), "A call-target frequency must be between 0 and 1.")
  }
  (f * 100.0).round().to_int()
}

///|
/// Recover which hint an attribute stands for.
fn hint_of_attr(p : (Position, Position), a : @ast.Attribute) -> HintSetter {
  fn bad() -> HintSetter {
    fail_at(
      loc_of(p),
      "Expected a hint attribute: '#[likely]', '#[unlikely]', '#[freq = n]', '#[never_opt]' or '#[always_opt]'.",
      default=Branch(true),
    )
  }

  match (a.attr_name, a.attr_value) {
    ("likely", None) => Branch(true)
    ("unlikely", None) => Branch(false)
    ("never_opt", None) => Freq(never_opt)
    ("always_opt", None) => Freq(always_opt)
    ("freq", Some(v)) =>
      match v.desc {
        Int(n) | Float(n) =>
          Freq(
            freq_of_ratio(@string.parse_double(n) catch { _ => return bad() }),
          )
        _ => bad()
      }
    _ => bad()
  }
}

///|
/// `#[targets(f: 0.73, ...)]` takes a LIST, which neither attribute shape can
/// carry, so it has its own production. The name is an ordinary IDENT -- the
/// `(` after it is what selects that production -- so it is checked here rather
/// than by the lexer.
fn targets_of_attr(
  p : (Position, Position),
  name : String,
  l : Array[(Ident, Int)],
) -> HintSetter {
  if name != "targets" {
    record_error(
      loc_of(p),
      "Expected a hint attribute: the only one taking a list is '#[targets(f: 0.73, ...)]'.",
    )
  }
  Targets(l)
}

///|
/// Whether a branch hint may prefix this instruction.
fn is_branch_hint_target(d : InstrDesc[Location]) -> Bool {
  match d {
    If(..)
    | BrIf(_)
    | BrOnNull(_)
    | BrOnNonNull(_)
    | BrOnCast(_)
    | BrOnCastFail(_)
    | BrOnCastDescEq(_)
    | BrOnCastDescEqFail(_) => true
    _ => false
  }
}

///|
/// Whether a frequency hint may prefix this instruction.
///
/// A frequency guides inlining, loop unrolling and block deferral, so it is
/// meaningful on a call or a control instruction.
fn is_freq_target(d : InstrDesc[Location]) -> Bool {
  match d {
    Call(_)
    | TailCall(_)
    | Block(..)
    | Loop(..)
    | While(..)
    | If(..)
    | TryTable(..)
    | Try(..)
    | TryCatch(..)
    | Dispatch(..)
    | Match(..) => true
    _ => is_branch_hint_target(d)
  }
}

///|
/// Call targets need a call. Whether that call is INDIRECT -- the only kind the
/// hint means anything for -- depends on what the callee resolves to, which the
/// parser cannot know; the typer decides.
fn is_targets_target(d : InstrDesc[Location]) -> Bool {
  d is Call(_) || d is TailCall(_)
}

///|
/// Attach hints to the instruction a hint attribute prefixes.
///
/// A hint attribute takes the WHOLE expression that follows it, so the
/// instruction it lands on may be anything an expression can be. The target
/// checks below are what hold the placement rule: `#[freq = 4] f(x) + 1` lands
/// on the BinOp and is rejected.
///
/// The advice to parenthesize is only offered when the hint landed on an
/// operator form, where a tighter sub-expression exists that it could have been
/// meant for. On a block or a branch the placement is simply wrong and
/// parentheses would not change what the hint lands on.
fn hinted(
  aloc : (Position, Position),
  setters : Array[HintSetter],
  i : Instr[Location],
) -> Instr[Location] {
  let span = loc_of(aloc)
  let hint : String? = match i.desc {
    BinOpI(_)
    | UnOpI(_)
    | Cast(_)
    | CastDesc(_)
    | Test(_)
    | On(_)
    | NonNull(_)
    | StructGet(_)
    | ArrayGet(_)
    | GetDescriptor(_)
    | Select(_) =>
      Some(
        "A hint takes the whole expression that follows it. Parenthesize the part you meant.",
      )
    _ => None
  }
  let mut hints = i.hints
  for s in setters {
    match s {
      Branch(b) => {
        if !is_branch_hint_target(i.desc) {
          fail_at(
            span,
            "A branch hint may only prefix a conditional branch (if, br_if, or br_on_*).",
            default=(),
            hint~,
          )
        }
        hints = { ..hints, branch: Some({ value: b, loc: span }) }
      }
      Freq(f) => {
        if !is_freq_target(i.desc) {
          fail_at(
            span,
            "A frequency hint may only prefix a call or a control instruction.",
            default=(),
            hint~,
          )
        }
        hints = { ..hints, freq: Some({ value: f, loc: span }) }
      }
      Targets(l) => {
        if !is_targets_target(i.desc) {
          fail_at(
            span,
            "A call-target hint may only prefix a call.",
            default=(),
            hint~,
          )
        }
        hints = { ..hints, targets: Some({ value: l, loc: span }) }
      }
    }
  }
  { ..i, hints, }
}
