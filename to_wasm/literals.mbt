// Reading a literal's value out of its source spelling.
//
// Ported from the constant-folding of wax/src/lib-conversion/to_wasm.ml.
//
// The literals reach here as the TEXT the author wrote, which is deliberate: a
// float's exact bit pattern survives only in its spelling, and re-deriving it
// from a parsed double would lose a NaN payload that the module may depend on.
// So the conversion happens once, here, at the point the bytes are chosen.

///|
/// A wax integer literal as an `Int64`, underscores ignored.
///
/// Read UNSIGNED on a signed-parse failure, because a hex literal past 2^63 is
/// written as a bit pattern rather than a negative number, and that pattern is
/// what the encoder emits.
pub fn parse_i64(s : String, loc : @basic.Location) -> Int64 raise LowerError {
  let cleaned = s.split("_").join("")
  @string.parse_int64(cleaned) catch {
    _ =>
      @string.parse_uint64(cleaned).reinterpret_as_int64() catch {
        _ => raise Unresolved("integer literal", loc)
      }
  }
}

///|
/// The same, truncated to the 32 bits an `i32.const` carries.
pub fn parse_i32(s : String, loc : @basic.Location) -> Int raise LowerError {
  parse_i64(s, loc).to_int()
}

///|
/// A wax float literal as a double.
pub fn parse_f64(s : String, loc : @basic.Location) -> Double raise LowerError {
  let cleaned = s.split("_").join("")
  @string.parse_double(cleaned) catch {
    _ =>
      // An integer literal in a float position, and the `nan:0x..` payload form,
      // both reach here; the first parses as an integer, the second does not
      // survive a double at all and is not lowered yet.
      @string.parse_int64(cleaned).to_double() catch {
        _ => raise NotLowered("float literal spelling", loc)
      }
  }
}

///|
/// A readable name for an instruction, for the "not lowered" report.
pub fn construct_name(
  d : @ast.InstrDesc[@typing_env.InferredAnnotation],
) -> String {
  match d {
    Block(..) | Loop(..) => "block"
    While(..) => "while"
    If(..) => "if"
    TryTable(..) => "try_table"
    Try(..) | TryCatch(..) => "try"
    Dispatch(..) => "dispatch"
    Match(..) => "match"
    Hole => "hole"
    Null => "null"
    Path(_, _) => "qualified name"
    Call(_, _) => "call"
    TailCall(_, _) => "tail call"
    Labelled(_, _) => "labelled argument"
    Str(_, _) => "string literal"
    Cast(_, _) | CastDesc(_, _, _) => "cast"
    Test(_, _) => "type test"
    NonNull(_) => "non-null assertion"
    Struct(_, _) | StructDefault(_) | StructDesc(_, _) | StructDefaultDesc(_) =>
      "struct construction"
    StructGet(_, _) | StructSet(_, _, _) | GetDescriptor(_) => "field access"
    Array(_, _, _)
    | ArrayDefault(_, _)
    | ArrayFixed(_, _)
    | ArraySegment(_, _, _, _) => "array construction"
    ArrayGet(_, _) | ArraySet(_, _, _) => "array access"
    BrTable(_, _) => "br_table"
    BrOnNull(_, _) | BrOnNonNull(_, _) => "br_on_null"
    BrOnCast(_, _, _) | BrOnCastFail(_, _, _) => "br_on_cast"
    BrOnCastDescEq(_, _, _, _) | BrOnCastDescEqFail(_, _, _, _) =>
      "br_on_cast_desc"
    Throw(_, _) | ThrowRef(_) => "throw"
    ContNew(_, _)
    | ContBind(_, _, _)
    | Suspend(_, _)
    | Resume(_, _, _)
    | ResumeThrow(_, _, _, _)
    | ResumeThrowRef(_, _, _)
    | Switch(_, _, _)
    | On(_, _) => "stack switching"
    Select(_, _, _) => "select"
    IfAnnotation(..) => "conditional annotation"
    _ => "instruction"
  }
}
