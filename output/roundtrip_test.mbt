///|
/// Parse then reprint, as `wax f.wax -f wax` does.
fn reprint(src : String) -> String {
  let r = @grammar.parse_string(src)
  match r.module_ {
    Some(m) => @output.render(m, r.trivia)
    None => "PARSE FAILED: " + r.errors[0].message
  }
}

///|
test "first end-to-end reprint" {
  inspect(
    reprint("fn f() -> i32 { 1 + 2 * 3; }\n"),
    content=(
      #|fn f() -> i32 {
      #|    1 + 2 * 3;
      #|}
    ),
  )
}
