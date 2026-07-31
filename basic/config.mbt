///|
/// How a `Location` renders in JSON.
///
/// AST snapshot tests are far more readable — and far less churn-prone — when
/// spans are hidden or abbreviated, but the differential harness needs the full
/// form. Rather than thread a formatting flag through every `to_json`, the
/// reference's own tests set a process-wide knob; `moonbitlang/parser` does the
/// same in `lexer/basic/config.mbt`, and this follows suit.
pub(all) enum LocStyle {
  /// Render every span as `null`.
  Hidden
  /// Render the full `{ file, start: { line, column }, end: … }` object.
  Json
  /// Render the abbreviated `"1:5-1:9"` string, without the file name.
  Str
}

///|
/// The active `Location` JSON style. Scope a change with `show_loc.protect`
/// rather than assigning to it directly, so a failing test cannot leak the
/// setting into the next one.
pub let show_loc : Ref[LocStyle] = @ref.new(Hidden)
