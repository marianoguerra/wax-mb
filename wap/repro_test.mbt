///|
fn try_wat(src : String) -> String raise @compile.CompileError {
  match @wap.compile_string_to_wat(src, fname="t.wap") {
    Ok(w) => w
    Err(d) => {
      let sb = StringBuilder()
      let sink = @diagnostic.buffer_sink(sb)
      let theme = @diagnostic.get_theme(is_tty=false)
      for r in d.wap {
        sb.write_string("WAP: " + r.message + "\n")
      }
      for r in d.wax {
        @diagnostic.output_error(sink, theme, Human, Some(src), r)
      }
      "FAILED\n" + sb.to_string()
    }
  }
}

///|
test "repro: impl with an override" {
  let src =
    #|module m
    #|type shape = { kind :: i32 }
    #|type circle :: shape = { r :: f64 }
    #|impl shape:
    #|  fn area(self) -> f64:
    #|    0.0
    #|impl circle:
    #|  fn area(self) -> f64:
    #|    self.r
  assert_false(try_wat(src).contains("FAILED"))
}

///|
test "repro: impl with no override (no dispatcher)" {
  let src =
    #|module m
    #|type shape = { kind :: i32 }
    #|impl shape:
    #|  fn area(self) -> f64:
    #|    0.0
  assert_false(try_wat(src).contains("FAILED"))
}

///|
test "repro: plain fn returning f64" {
  let src =
    #|module m
    #|type shape = { kind :: i32 }
    #|fn area(s :: shape) -> f64:
    #|  0.0
  assert_false(try_wat(src).contains("FAILED"))
}

///|
test "repro: type match as a value" {
  let src =
    #|module m
    #|type shape = { kind :: i32 }
    #|type circle :: shape = { r :: f64 }
    #|fn area(v :: shape) -> f64:
    #|  match v
    #|  | c :: circle: c.r
    #|  | _: 0.0
  assert_false(try_wat(src).contains("FAILED"))
}

///|
test "repro: type match with returns" {
  let src =
    #|module m
    #|type shape = { kind :: i32 }
    #|type circle :: shape = { r :: f64 }
    #|fn area(v :: shape) -> f64:
    #|  match v
    #|  | c :: circle: return c.r
    #|  | _: return 0.0
  assert_false(try_wat(src).contains("FAILED"))
}

///|
test "repro: a bare loop repeats" {
  let src =
    #|module m
    #|export "run" fn run(n :: i32) -> i32:
    #|  var i = 0
    #|  loop:
    #|    i += 1
    #|    if i >= n:
    #|      break
    #|  i
  let w = try_wat(src)
  assert_false(w.contains("FAILED"))
  // Without the generated `br`, a wasm loop runs its body once.
  assert_true(w.contains("(br $loop__1)"))
}
