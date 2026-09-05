///|
/// Compile a was source, or return the rendered reason it did not.
fn try_wat(src : String) -> String raise @compile.CompileError {
  match @was.compile_string_to_wat(src, fname="t.was") {
    Ok(w) => w
    Err(d) => {
      let sb = StringBuilder()
      let sink = @diagnostic.buffer_sink(sb)
      let theme = @diagnostic.get_theme(is_tty=false)
      for r in d.was {
        sb.write_string("WAS: " + r.message + "\n")
      }
      for r in d.wax {
        @diagnostic.output_error(sink, theme, Human, Some(src), r)
      }
      "FAILED\n" + sb.to_string()
    }
  }
}

///|
test "the smallest module" {
  let src =
    #|export "add" fn add(x :: i32, y :: i32) -> i32:
    #|  x + y
  let w = try_wat(src)
  assert_false(w.contains("FAILED"))
  assert_true(w.contains("i32.add"))
  assert_true(w.contains("\"add\""))
}

///|
/// The claim was makes: the same program, in two notations, is one module.
test "a was file and its .wax original produce the same wasm" {
  let wax_src =
    #|type ints = [mut i32];
    #|
    #|#[export = "sum"]
    #|fn sum(arr: &ints) -> i32 {
    #|    let total: i32 = 0;
    #|    let i: i32 = 0;
    #|    while i <s arr.length() {
    #|        total += arr[i];
    #|        i += 1;
    #|    }
    #|    total;
    #|}
  let was_src =
    #|type ints = [mut i32]
    #|
    #|export "sum" fn sum(arr :: &ints) -> i32:
    #|  let total :: i32 = 0
    #|  let i :: i32 = 0
    #|  while i <~ arr.length():
    #|    total += arr[i]
    #|    i += 1
    #|  total
  let from_wax = match @wax.compile_string(wax_src, fname="a.wax") {
    Ok(b) => b
    Err(_) => fail("the .wax original should compile")
  }
  let from_was = match @was.compile_string(was_src, fname="a.was") {
    Ok(b) => b
    Err(d) => {
      for r in d.was {
        println("WAS: " + r.message)
      }
      fail("the .was version should compile")
    }
  }
  assert_eq(from_was, from_wax)
}
