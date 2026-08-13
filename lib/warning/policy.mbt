// Levels, groups, and the -W policy.

///|
/// What to do with a warning when it is reported.
pub(all) enum Level {
  /// Suppress it entirely.
  Hidden
  /// Report it as a warning. The usual default.
  Displayed
  /// Promote it to an error, failing the run.
  ErrorLevel
} derive(Eq, Debug)

///|
/// Group name to members.
///
/// The special group `all` is handled by `set` and so is not listed. Note that
/// `correctness` deliberately overlaps `unused`: a field or label nobody uses
/// is both an unused binding and a correctness signal.
let group_table : Array[(String, Array[Warning])] = [
  ("unused", [UnusedLocal, UnusedField, UnusedImport, UnusedLabel]),
  (
    "correctness",
    [
      ShiftOverflow,
      ConstantTrap,
      TautologicalComparison,
      ConstantCondition,
      UnusedResult,
      DeadCode,
      CastAlwaysFails,
      EagerSelect,
      Precedence,
      UnusedField,
      UnusedImport,
      UnusedLabel,
      ConfusableUnicode,
    ],
  ),
  ("redundant", [RedundantOperation, UnnecessaryMut]),
  ("naming", [NamingConflict, ReservedWordRename, GeneratedName]),
  ("suggestion", [CompoundAssignment, FieldPunning, RedundantAnnotation]),
]

///|
/// The group names, for help text. Excludes the special `all`.
pub fn groups() -> Array[String] {
  group_table.map(g => g.0)
}

///|
/// A mapping from each warning to its level.
///
/// A function rather than a table, so `set` returns an updated closure and
/// later assignments naturally override earlier ones.
pub(all) struct Policy {
  level : (Warning) -> Level
}

///|
/// The level each warning has when nothing has configured it.
///
/// The from-wasm renaming warnings are noisy round-trip notices, and
/// redundant-operation and the suggestion group are optimisation and style
/// hints common in generated code -- all hidden unless `-W` asks for them.
/// Everything else is shown.
pub let default_policy : Policy = {
  level: w => {
    match w {
      NamingConflict
      | ReservedWordRename
      | GeneratedName
      | RedundantOperation
      | CompoundAssignment
      | FieldPunning
      | RedundantAnnotation => Hidden
      _ => Displayed
    }
  },
}

///|
pub fn Policy::resolve(self : Policy, w : Warning) -> Level {
  (self.level)(w)
}

///|
/// The warnings a name refers to: the special group `all`, one warning by
/// name, or a named group.
fn targets(target : String) -> Array[Warning]? {
  if target == "all" {
    return Some(all)
  }
  for w in all {
    if w.name() == target {
      return Some([w])
    }
  }
  for g in group_table {
    if g.0 == target {
      return Some(g.1)
    }
  }
  None
}

///|
/// `policy` updated so `target` -- a warning name, a group, or `all` -- has
/// `level`. Later calls override earlier ones.
pub fn Policy::set(
  self : Policy,
  target : String,
  level : Level,
) -> Result[Policy, String] {
  match targets(target) {
    Some(ws) =>
      Ok({
        level: w => {
          if ws.iter().any(x => x == w) {
            level
          } else {
            self.resolve(w)
          }
        },
      })
    None => {
      let known = all.map(w => w.name())
      known.append(groups())
      known.push("all")
      Err(
        "Unknown warning or group '\{target}'. Known names: \{known.join(", ")}.",
      )
    }
  }
}

///|
fn level_of_string(s : String) -> Level? {
  match s {
    "hidden" => Some(Hidden)
    "warning" => Some(Displayed)
    "error" => Some(ErrorLevel)
    _ => None
  }
}

///|
/// Parse a `-W` argument, `NAME=LEVEL`.
pub fn parse_spec(s : String) -> Result[(String, Level), String] {
  match s.find("=") {
    None =>
      Err(
        "Malformed warning spec '\{s}'; expected NAME=LEVEL (LEVEL is hidden, warning, or error).",
      )
    Some(i) => {
      let name = s.view(end_offset=i).to_owned()
      let level = s.view(start_offset=i + 1).to_owned()
      match level_of_string(level) {
        Some(l) => Ok((name, l))
        None =>
          Err(
            "Unknown warning level '\{level}'; expected hidden, warning, or error.",
          )
      }
    }
  }
}
