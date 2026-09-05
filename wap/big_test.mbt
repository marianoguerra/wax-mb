///|
let big : String =
  #|module sieve
  #|
  #|const limit = 4096
  #|
  #|type color = enum { red, green, blue }
  #|type palette = set[color]
  #|type flags = [bool]
  #|type buf = [u8]
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
  #|fn divmod(n :: i32, d :: i32) -> (i32, i32):
  #|  (n / d, n % d)
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
  #|
  #|fn sum_bytes(xs :: buf) -> u32:
  #|  var total = 0
  #|  for x in xs:
  #|    total += x
  #|  total
  #|
  #|fn classify(d :: i32) -> i32:
  #|  match d
  #|  | {1, 7}: 0
  #|  | 2 .. 6: 1
  #|  | _: -1
  #|
  #|fn pick(n :: i32) -> i32:
  #|  if
  #|  | n < 0: -1
  #|  | n == 0: 0
  #|  | _: 1
  #|
  #|fn total_area(v :: shape) -> f64:
  #|  v.area()
  #|
  #|fn maybe(v :: shape?) -> f64:
  #|  if v == null:
  #|    return 0.0
  #|  if v is circle:
  #|    return (v as circle).area()
  #|  v!.area()
  #|
  #|fn tuples() -> i32:
  #|  let (q, r) = divmod(17, 5)
  #|  var x = 1
  #|  var y = 2
  #|  (x, y) = (y, x)
  #|  q + r + x + y
  #|
  #|fn sets() -> palette:
  #|  var s :: palette = {red, blue}
  #|  s = s + {green}
  #|  s = s - {red}
  #|  s = s & {green, blue}
  #|  if red in s:
  #|    s = s + {blue}
  #|  s
  #|
  #|fn scan(xs :: buf, target :: u8) -> i32:
  #|  for ~outer i in 0 ..< xs.len() by 2:
  #|    if xs[i] == target:
  #|      break ~outer
  #|  0
  #|
  #|fn drain(q :: buf) -> u32:
  #|  var i = 0
  #|  var acc = 0
  #|  loop:
  #|    acc += q[i]
  #|    i += 1
  #|    if i >= q.len():
  #|      break
  #|  acc

///|
test "big sample compiles" {
  match @wap.compile_string_to_wat(big, fname="big.wap") {
    Ok(w) => {
      // The signedness the types chose, the packed reads, and the
      // temporaries multiple assignment needs.
      assert_true(w.contains("i32.lt_u"))
      assert_true(w.contains("i32.div_s"))
      assert_true(w.contains("array.get_u"))
      assert_true(w.contains("sieve__shape__area__dyn"))
      assert_true(w.contains("count_primes"))
    }
    Err(d) => {
      for r in d.wap {
        println("WAP: " + r.message)
      }
      let sb = StringBuilder()
      let sink = @diagnostic.buffer_sink(sb)
      let theme = @diagnostic.get_theme(is_tty=false)
      for r in d.wax {
        @diagnostic.output_error(sink, theme, Human, Some(big), r)
      }
      println(sb.to_string())
      fail("did not compile")
    }
  }
}
