///|
test "compile a pure function" {
  let artifact = @wisp.compile("export fn run(): 40 + 2")
  assert_true(artifact.wasm().length() > 8)
  assert_false(artifact.wat().contains("(global "))
  assert_false(artifact.wat().contains("(start "))
}

///|
test "reject module values" {
  for source in ["let x = 1", "const x = 1", "var x = 1", "print(1)"] {
    try @wisp.compile(source) catch {
      _ => ()
    } noraise {
      _ => fail("accepted module value")
    }
  }
}
