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

///|
/// An integer-to-float conversion. Wax spells it `n as f64_s`, and every one of
/// the four is a real instruction -- `f64.convert_i64_s` and its siblings -- so
/// the signedness is not decoration: it names which instruction to emit.
test "repro: integer to float conversion" {
  let src =
    #|module m
    #|fn f(x :: i64) -> f64:
    #|  x as f64_s
    #|fn g(x :: i32) -> f64:
    #|  x as f64_u
    #|fn h(x :: i32) -> f32:
    #|  x as f32_s
  let wat = try_wat(src)
  assert_false(wat.contains("FAILED"))
  assert_true(wat.contains("f64.convert_i64_s"))
  assert_true(wat.contains("f64.convert_i32_u"))
  assert_true(wat.contains("f32.convert_i32_s"))
}

///|
/// The other direction already worked, because a float truncation is named by
/// the INTEGER it produces. It saturates: wap has no spelling for the trapping
/// variant, so every cast it builds is non-strict.
test "repro: float to integer truncation" {
  let src =
    #|module m
    #|fn f(x :: f64) -> i32:
    #|  x as i32_s
  assert_true(try_wat(src).contains("i32.trunc_sat_f64_s"))
}

///|
/// A signedness names an integer/float conversion, so neither pair that stays
/// inside one family is an instruction. Wax refuses both, and wap now reaches
/// that refusal rather than a different one about a cast with no signedness.
test "repro: a signed cast that crosses no family is refused" {
  let same_float =
    #|module m
    #|fn f(x :: f64) -> f32:
    #|  x as f32_s
  let same_int =
    #|module m
    #|fn f(x :: i32) -> i32:
    #|  x as i32_s
  assert_true(try_wat(same_float).contains("FAILED"))
  assert_true(try_wat(same_int).contains("FAILED"))
}
