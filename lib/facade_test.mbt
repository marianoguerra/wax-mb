// The three entry paths, exactly as README.md documents them.
//
// The examples in a published readme are the first code anyone runs, so they
// are kept here and compiled rather than only written down. `moon test` is what
// says the readme is still true.

///|
test "source in, wasm out" {
  let src =
    #|#[export]
    #|fn add(x: i32, y: i32) -> i32 { x + y; }
    #|
  let bytes = match @wax.compile_string(src) {
    Ok(b) => b
    Err(_) => abort("expected it to compile")
  }
  // The wasm preamble: a NUL, then "asm".
  assert_eq(bytes[0], b'\x00')
  assert_eq(bytes[1], b'a')
  assert_eq(bytes[2], b's')
  assert_eq(bytes[3], b'm')
}

///|
test "the same module, as text" {
  let src = "fn one() -> i32 { 1; }"
  let text = match @wax.compile_string_to_wat(src) {
    Ok(t) => t
    Err(_) => abort("expected it to compile")
  }
  assert_true(text.contains("i32.const 1"))
}

///|
test "source in, source out" {
  let src = "fn f()->i32{1;}"
  let out = match @wax.format_string(src) {
    Ok(t) => t
    Err(_) => abort("expected it to parse")
  }
  assert_eq(
    out,
    (
      #|fn f() -> i32 {
      #|    1;
      #|}
    ),
  )
}

///|
test "a syntax error is reported, not raised" {
  match @wax.format_string("fn f( {") {
    Ok(_) => abort("expected it to be rejected")
    Err(diagnostics) => {
      assert_true(diagnostics.length() > 0)
      assert_true(diagnostics[0].severity is Error)
    }
  }
}

///|
test "ast in, wasm out" {
  let i32_ : @wasm_types.ValType[@ast.Ident] = I32
  let m : @ast.LocModule = [
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
  let session = @compile.Session::new()
  let checked = session.check(m)
  // Nothing to report, so nothing rejects it.
  assert_false(@compile.rejected(session.reports()))
  assert_true(checked.to_bytes().length() > 8)
}

///|
test "a rejected module reports rather than emits" {
  // Declared to return an i32 and returning nothing.
  let m : @ast.LocModule = [@build.func("wrong", results=[I32])]
  let session = @compile.Session::new()
  let _ = session.check(m)
  assert_true(@compile.rejected(session.reports()))
}
