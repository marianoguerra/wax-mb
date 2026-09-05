///|
let adder : String =
  #|module math
  #|
  #|export "add" fn add(x :: i32, y :: i32) -> i32:
  #|  x + y

///|
test "wap source compiles to wasm" {
  let bytes = match @wap.compile_string(adder, fname="math.wap") {
    Ok(b) => b
    Err(d) => {
      for r in d.wap {
        println("wap: " + r.message)
      }
      for r in d.wax {
        println("wax: " + r.loc.to_string())
      }
      fail("should have compiled")
    }
  }
  // The wasm preamble: \0asm plus version 1.
  assert_eq(bytes[0], b'\x00')
  assert_eq(bytes[1], b'a')
  assert_eq(bytes[2], b's')
  assert_eq(bytes[3], b'm')
  assert_true(bytes.length() > 8)
}

///|
test "names are mangled with the module, and exports are not" {
  let wat = match @wap.compile_string_to_wat(adder, fname="math.wap") {
    Ok(w) => w
    Err(d) => {
      for r in d.wax {
        println("wax: " + r.loc.to_string())
      }
      fail("should have compiled")
    }
  }
  assert_true(wat.contains("math__add"))
  assert_true(wat.contains("\"add\""))
}

///|
/// The point of a public AST: a generator hands over values, never text.
test "a module built as an AST compiles without any source" {
  let x : @wapast.Node = { it: Var("x"), span: @wapast.nowhere, }
  let y : @wapast.Node = { it: Var("y"), span: @wapast.nowhere, }
  let sum : @wapast.Node = { it: Bin(Mul, x, y), span: @wapast.nowhere, }
  let f : @wapast.FnDecl = {
    name: "mul",
    receiver: None,
    params: [
      { name: "x", typ: I32, span: @wapast.nowhere, },
      { name: "y", typ: I32, span: @wapast.nowhere, },
    ],
    results: [I32],
    body: Some([sum]),
    export_name: Some("mul"),
    import_name: None,
    is_start: false,
    is_pub: true,
    span: @wapast.nowhere,
  }
  let m : @wapast.Module = { name: "gen", decls: [Fn(f)], }
  let lowered = @lower.lower_module(m)
  assert_eq(lowered.diagnostics().length(), 0)
  let session = @compile.Session::new()
  let checked = session.check(lowered.fields())
  assert_false(@compile.rejected(session.reports()))
  let wat = checked.to_wat()
  assert_true(wat.contains("gen__mul"))
  assert_true(wat.contains("i32.mul"))
}
