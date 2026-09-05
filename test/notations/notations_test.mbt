// `wap -f was`: rule one, made executable.
//
// wap's first rule is that every construct becomes Wax AST and nothing else,
// and the artifact that describes it calls the printed was expansion "the
// specification". That is only worth saying if the expansion can be printed
// AND read back, so this compiles a wap program twice -- once directly, and
// once through was source -- and requires the same bytes.
//
// Neither published module depends on the other. wap produces a Wax AST and
// was prints one; the composition lives here, in the harness, which is what
// the harness is for.

///|
fn report_message(r : @er.Report) -> String {
  r.message
}

///|
fn wap_via_was(name : String, src : String) -> Unit raise {
  let direct = match @wap.compile_string(src, fname=name + ".wap") {
    Ok(b) => b
    Err(d) => {
      for r in d.wap {
        println(name + " WAP: " + report_message(r))
      }
      fail(name + ": the wap source did not compile")
      return
    }
  }
  let module_ = match @wap.to_wax(src, fname=name + ".wap") {
    Ok(m) => m
    Err(_) => {
      fail(name + ": could not lower")
      return
    }
  }
  let printed = @print.module_(module_.fields())
  match @was.compile_string(printed, fname=name + ".was") {
    Ok(b) =>
      if b != direct {
        println(printed)
        fail(name + ": going through was changed the module")
      }
    Err(d) => {
      println("--- printed as was ---")
      println(printed)
      for r in d.was {
        println(name + " WAS: " + report_message(r))
      }
      let sb = StringBuilder()
      let sink = @diagnostic.buffer_sink(sb)
      let theme = @diagnostic.get_theme(is_tty=false)
      for r in d.wax {
        @diagnostic.output_error(sink, theme, Human, Some(printed), r)
      }
      println(sb.to_string())
      fail(name + ": the printed was did not compile")
    }
  }
}

///|
let sieve : String =
  #|module sieve
  #|
  #|type flags = [bool]
  #|
  #|export "count_primes" fn count(n :: u32) -> u32:
  #|  if n < 2:
  #|    return 0
  #|  var marked = flags[false ** (n + 1)]
  #|  var total = 0
  #|  for i in 2 .. n:
  #|    if marked[i]:
  #|      continue
  #|    total += 1
  #|    var j = i * i
  #|    while j <= n:
  #|      marked[j] = true
  #|      j += i
  #|  total

///|
let shapes : String =
  #|module shapes
  #|
  #|type shape = { kind :: i32 }
  #|type circle :: shape = { r :: f64 }
  #|
  #|impl shape:
  #|  fn area(self) -> f64:
  #|    0.0
  #|
  #|impl circle:
  #|  fn area(self) -> f64:
  #|    3.14159 * self.r * self.r
  #|
  #|export "total" fn total(v :: shape) -> f64:
  #|  v.area()
  #|
  #|fn divmod(n :: i32, d :: i32) -> (i32, i32):
  #|  (n / d, n % d)
  #|
  #|export "swap_sum" fn swap_sum() -> i32:
  #|  let (q, r) = divmod(17, 5)
  #|  var x = 1
  #|  var y = 2
  #|  (x, y) = (y, x)
  #|  q + r + x + y

///|
let sets : String =
  #|module palette
  #|
  #|type color = enum { red, green, blue }
  #|type shades = set[color]
  #|
  #|export "mix" fn mix() -> shades:
  #|  var s :: shades = {red, blue}
  #|  s = s + {green}
  #|  s = s - {red}
  #|  s = s & {green, blue}
  #|  if red in s:
  #|    s = s + {blue}
  #|  s
  #|
  #|export "classify" fn classify(d :: i32) -> i32:
  #|  match d
  #|  | {1, 7}: 0
  #|  | 2 .. 6: 1
  #|  | _: -1

///|
test "wap -f was: the sieve" {
  wap_via_was("sieve", sieve)
}

///|
test "wap -f was: records, methods and tuples" {
  wap_via_was("shapes", shapes)
}

///|
test "wap -f was: enumerations, sets and a value match" {
  wap_via_was("palette", sets)
}

///|
/// What the expansion actually looks like, which is the part rule one is for.
test "the printed expansion is readable was" {
  let module_ = match @wap.to_wax(sets, fname="palette.wap") {
    Ok(m) => m
    Err(_) => fail("could not lower")
  }
  let printed = @print.module_(module_.fields())
  // The set constructors folded to masks before they reached was.
  assert_true(printed.contains("i32 = 5"))
  assert_true(printed.contains("|| 2"))
  // And the value match became the comparison chain it lowers to, not a
  // dispatch table.
  assert_true(printed.contains("if "))
}
