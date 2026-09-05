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

///|
/// A module with two declared types used to put both in one `rec` group, and
/// Wax will not coerce a function's name to a function type declared inside
/// one -- the reference implementation refuses it too. So `each(xs, callback)`
/// compiled in a module with one type and stopped compiling when a second was
/// added, which is how the standard library ports found it.
///
/// The cast that suggests itself, `callback as visit`, is worse than the error:
/// it compiles, and traps at run time with `illegal cast`, because the two
/// function types are in different recursion groups and so are not the same
/// wasm type.
test "repro: a callback type survives a second type declaration" {
  let src =
    #|module m
    #|type visit = fn(eq?, eq?)
    #|type holder = { x :: i32 }
    #|fn note(context :: eq?, value :: eq?):
    #|  ()
    #|fn each(context :: eq?, seen :: visit):
    #|  seen(context, null)
    #|export "run" fn run():
    #|  each(null, note)
  let w = try_wat(src)
  assert_false(w.contains("FAILED"))
  // The reference must be handed over as-is. A `ref.cast` here would mean the
  // callback type went back into the group.
  assert_false(w.contains("ref.cast"))
}

///|
/// The other half of the rule. A function type only has to share a group when
/// it is genuinely in a cycle with what it names -- here the record holds the
/// callback and the callback takes the record. Wax's refusal then stands, and
/// that is upstream's behaviour rather than this port's; the test records it so
/// that a future change to the grouping has to decide about it deliberately.
test "repro: a callback type in a cycle stays in the group" {
  let src =
    #|module m
    #|type item = { cb :: visit }
    #|type visit = fn(item)
    #|fn note(it :: item):
    #|  ()
    #|fn each(seen :: visit):
    #|  seen(item{cb: seen})
    #|export "run" fn run():
    #|  each(note)
  assert_true(try_wat(src).contains("FAILED"))
}

///|
/// And a chain is not a cycle: `holder` names `visit` and `visit` names `item`,
/// but nothing names `holder`, so all three are separate groups and the
/// callback is passed by name.
test "repro: a callback type over a declared type is not a cycle" {
  let src =
    #|module m
    #|type item = { x :: i32 }
    #|type visit = fn(item)
    #|type holder = { cb :: visit }
    #|fn note(it :: item):
    #|  ()
    #|fn each(h :: holder):
    #|  h.cb(item{x: 1})
    #|export "run" fn run():
    #|  each(holder{cb: note})
  let w = try_wat(src)
  assert_false(w.contains("FAILED"))
  assert_false(w.contains("ref.cast"))
}
