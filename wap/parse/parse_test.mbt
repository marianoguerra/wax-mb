///|
/// A representative program, exercising every declaration form.
let sample : String =
  #|module sieve
  #|
  #|import collections.hashing
  #|
  #|import was "bits.was":
  #|  fn popcount(x :: u32) -> u32
  #|
  #|import "env":
  #|  fn log(v :: i32)
  #|  const base :: i32
  #|
  #|const limit = 4096
  #|
  #|type color = enum { red, green, blue }
  #|type palette = set[color]
  #|type day = 1 .. 31
  #|type flags = [bool]
  #|type shape = { kind :: i32 }
  #|type circle :: shape = { r :: f64 }
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
  #|fn classify(d :: day) -> i32:
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
  #|fn shapes(v :: shape?) -> f64:
  #|  if v == null:
  #|    return 0.0
  #|  if v is circle:
  #|    return (v as circle).area()
  #|  v!.area()
  #|
  #|fn tuples(xs :: [i32]):
  #|  let (q, r) = divmod(17, 5)
  #|  var (x, y) = (1, 2)
  #|  (x, y) = (y, x)
  #|  let (lo, _) = divmod(1, 2)
  #|  _ = q + r + x + y + lo
  #|
  #|fn sets() -> palette:
  #|  var s :: palette = {red, blue}
  #|  s = s + {green}
  #|  s = s - {red}
  #|  s = s & {green, blue}
  #|  if red in s && !(green in s):
  #|    log(1)
  #|  s

///|
test "the sample parses, and its declarations come out in order" {
  let unit = @parse.parse_module(sample, fname="sieve.wap")
  let m = unit.module_()
  assert_eq(m.name, "sieve")
  let kinds = []
  for d in m.decls {
    kinds.push(
      match d {
        ModuleName(_) => "module"
        Import(_) => "import"
        ImportWas(..) => "import-was"
        ImportHost(..) => "import-host"
        Const(_) => "const"
        TypeD(..) => "type"
        Fn(_) => "fn"
        Impl(..) => "impl"
      },
    )
  }
  assert_eq(
    kinds.join(" "),
    "module import import-was import-host const type type type type type type impl fn fn fn fn fn fn fn",
  )
}

///|
test "a record type keeps its parent and its fields" {
  let unit = @parse.parse_module(sample)
  for d in unit.module_().decls {
    if d is TypeD(name="circle", def~, ..) {
      match def {
        Record(parent~, fields~) => {
          assert_eq(parent, Some("shape"))
          assert_eq(fields.length(), 1)
          assert_eq(fields[0].name, "r")
          assert_eq(fields[0].typ, F64)
          assert_false(fields[0].mut_)
        }
        _ => fail("circle should be a record")
      }
    }
  }
}

///|
test "a grouping error is reported by shrubbery, not paraphrased" {
  let bad =
    #|fn f():
    #|  let x = 1
    #|   let y = 2
  let msg = try {
    let _ = @parse.parse_module(bad)
    "no error"
  } catch {
    @parse.ParseError(r) => r.message
  }
  assert_true(msg.contains("indented"))
}
