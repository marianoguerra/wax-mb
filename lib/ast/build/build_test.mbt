// The embedding path, end to end: build an AST, check it, emit wasm.
//
// This is the claim the package exists to support, so it is tested rather than
// asserted. Nothing here parses anything.

///|
/// `fn add(x: i32, y: i32) -> i32 { x + y; }`, exported.
fn adder() -> @ast.LocModule {
  let i32_ : @wasm_types.ValType[@ast.Ident] = I32
  [
    @build.func(
      "add",
      params=[(Some("x"), i32_), (Some("y"), i32_)],
      results=[i32_],
      body=[
        @ast.no_loc_instr(
          BinOpI(
            @basic.no_loc(Add),
            @ast.no_loc_instr(Get(@build.ident("x"))),
            @ast.no_loc_instr(Get(@build.ident("y"))),
          ),
        ),
      ],
      attributes=[@build.exported()],
    ),
  ]
}

///|
test "a built module type-checks and encodes" {
  let session = @compile.Session::new()
  let checked = session.check(adder())
  let reports = session.reports()
  assert_eq(reports.length(), 0)
  assert_false(@compile.rejected(reports))
  let bytes = checked.to_bytes()
  // The wasm preamble: "\0asm" and version 1.
  assert_eq(bytes[0], b'\x00')
  assert_eq(bytes[1], b'a')
  assert_eq(bytes[2], b's')
  assert_eq(bytes[3], b'm')
  assert_true(bytes.length() > 8)
}

///|
test "the same module prints as wat" {
  let session = @compile.Session::new()
  let text = session.check(adder()).to_wat()
  assert_true(text.contains("(func $add"))
  assert_true(text.contains("(export \"add\")"))
  assert_true(text.contains("i32.add"))
}

///|
test "a type error is reported, and nothing is emitted" {
  let session = @compile.Session::new()
  // Declared to return an i32 and returning nothing: the checker has to notice,
  // and the module has to produce no bytes.
  let m : @ast.LocModule = [@build.func("wrong", results=[I32])]
  let _ = session.check(m)
  let reports = session.reports()
  assert_true(reports.length() > 0)
  assert_true(@compile.rejected(reports))
}
