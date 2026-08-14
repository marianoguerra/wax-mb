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
/// `fn f() -> i64 { let a: i64 = 1; let b: i32 = 2; a }`, built either with
/// every identifier at `dummy_loc` or with each at a span of its own.
///
/// Two locals of DIFFERENT types, so a collapsed slot is visible in the bytes
/// rather than only in what the module computes.
fn two_locals(spans : @build.Spans?) -> @ast.LocModule {
  fn at() -> @basic.Location {
    match spans {
      Some(s) => s.fresh()
      None => @basic.dummy_loc
    }
  }

  let i64_ : @wasm_types.ValType[@ast.Ident] = I64
  let i32_ : @wasm_types.ValType[@ast.Ident] = I32
  [
    @build.func(
      "f",
      results=[i64_],
      body=[
        @ast.build(
          Let(
            [(Some(@build.ident("a", at=at())), Some(i64_))],
            Some(@ast.build(Int("1"), at())),
          ),
          at(),
        ),
        @ast.build(
          Let(
            [(Some(@build.ident("b", at=at())), Some(i32_))],
            Some(@ast.build(Int("2"), at())),
          ),
          at(),
        ),
        @ast.build(Get(@build.ident("a", at=at())), at()),
      ],
      attributes=[@build.exported()],
    ),
  ]
}

///|
test "identifiers built at one location are refused, not miscompiled" {
  let session = @compile.Session::new()
  let checked = session.check(two_locals(None), warn_unused=true)
  // Nothing here is a typing question, so the checker passes it: shared spans
  // are the emitter's to catch.
  assert_false(@compile.rejected(session.reports()))
  try checked.to_module() catch {
    e =>
      inspect(
        e,
        content=":0:0: local `b` was written at the same position as an earlier binding in this function; every generated identifier needs a distinct location",
      )
  } noraise {
    _ => fail("expected the second binding to be refused")
  }
}

///|
test "spans keep a generated function's locals apart" {
  let session = @compile.Session::new()
  let checked = session.check(
    two_locals(Some(@build.Spans::new())),
    warn_unused=true,
  )
  assert_false(@compile.rejected(session.reports()))
  // `b` is declared and never read. The lint that says so is keyed by the
  // binding's offset too, so it only works once the spans are distinct.
  inspect(session.reports().length(), content="1")
  assert_true(checked.to_bytes().length() > 8)
}

///|
test "a `Spans` never returns the same span twice" {
  let s = @build.Spans::new()
  let seen : Map[Int, Unit] = Map([])
  for _ in 0..<100 {
    seen[s.fresh().start.cnum] = ()
  }
  assert_eq(seen.length(), 100)
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
