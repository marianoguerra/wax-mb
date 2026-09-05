// The claim, tested: a .was file and the .wax file it translates are the same
// module.
//
// Every pair below is a file from `test/corpus/docs/` and its was translation.
// Byte equality of the emitted wasm is the assertion, which is stronger than
// comparing trees: it fails on a wrong signedness, a wrong field order, a
// wrong label, or an instruction in the wrong place.

///|
/// Compile both and require the same bytes.
fn same(name : String, wax_src : String, was_src : String) -> Unit raise {
  let from_wax = match @wax.compile_string(wax_src, fname=name + ".wax") {
    Ok(b) => b
    Err(_) => {
      fail(name + ": the .wax original did not compile")
      return
    }
  }
  let from_was = match @was.compile_string(was_src, fname=name + ".was") {
    Ok(b) => b
    Err(d) => {
      for r in d.was {
        println(name + " WAS: " + r.message)
      }
      let sb = StringBuilder()
      let sink = @diagnostic.buffer_sink(sb)
      let theme = @diagnostic.get_theme(is_tty=false)
      for r in d.wax {
        @diagnostic.output_error(sink, theme, Human, Some(was_src), r)
      }
      println(sb.to_string())
      fail(name + ": the .was translation did not compile")
      return
    }
  }
  if from_was != from_wax {
    fail(name + ": the two notations produced different wasm")
  }
}

///|
test "factorial: if with a result type" {
  same(
    "factorial",
    (
      #|#[export = "factorial"]
      #|fn factorial(n: i32) -> i32 {
      #|    if n <=s 1 => i32 {
      #|        1;
      #|    } else {
      #|        n * factorial(n - 1);
      #|    }
      #|}
    ),
    (
      #|export "factorial" fn factorial(n :: i32) -> i32:
      #|  if n <=~ 1 -> i32:
      #|    1
      #|  | n * factorial(n - 1)
    ),
  )
}

///|
test "find_first_zero: an array, a labelled loop and a branch" {
  same(
    "find_first_zero",
    (
      #|type ints = [i32];
      #|
      #|#[export = "find_first_zero"]
      #|fn find_first_zero(arr: &ints) -> i32 {
      #|    let len = arr.length();
      #|    let i = 0;
      #|    'search: loop {
      #|        if i >=s len {
      #|            return -1;
      #|        }
      #|        if arr[i] == 0 {
      #|            return i;
      #|        }
      #|        i += 1;
      #|        br 'search;
      #|    }
      #|    unreachable;
      #|}
    ),
    (
      #|type ints = [i32]
      #|
      #|export "find_first_zero" fn find_first_zero(arr :: &ints) -> i32:
      #|  let len = arr.length()
      #|  let i = 0
      #|  loop ~search:
      #|    if i >=~ len:
      #|      return -1
      #|    if arr[i] == 0:
      #|      return i
      #|    i += 1
      #|    br ~search
      #|  unreachable
    ),
  )
}

///|
test "rgb_channel: a dispatch table" {
  same(
    "rgb_channel",
    (
      #|#[export = "rgb_channel"]
      #|fn rgb_channel(color: i32, value: i32) -> i32 {
      #|    dispatch color ['red, 'green, 'blue, else 'bad] {
      #|        'bad:   { return -1; }
      #|        'blue:  { return value & 255; }
      #|        'green: { return (value & 255) << 8; }
      #|        'red:   { return (value & 255) << 16; }
      #|    }
      #|}
    ),
    (
      #|export "rgb_channel" fn rgb_channel(color :: i32, value :: i32) -> i32:
      #|  dispatch color [~red, ~green, ~blue, else ~bad]
      #|  | ~bad: return -1
      #|  | ~blue: return value & 255
      #|  | ~green: return (value & 255) << 8
      #|  | ~red: return (value & 255) << 16
    ),
  )
}

///|
test "sum_list: records, a type match and a cast" {
  same(
    "sum_list",
    (
      #|type cell = { value: i32 };
      #|type cons = { head: &eq, tail: &?eq };
      #|
      #|#[export = "sum_list"]
      #|fn sum_list(v: &?eq) -> i32 {
      #|    match v {
      #|        c: &cons => { return (c.head as &cell).value + sum_list(c.tail); }
      #|        x: &cell => { return x.value; }
      #|        _ => { return 0; }
      #|    }
      #|}
    ),
    (
      #|type cell = { value :: i32 }
      #|type cons = { head :: &eq, tail :: &?eq }
      #|
      #|export "sum_list" fn sum_list(v :: &?eq) -> i32:
      #|  match v
      #|  | c :: &cons: return (c.head as &cell).value + sum_list(c.tail)
      #|  | x :: &cell: return x.value
      #|  | _: return 0
    ),
  )
}

///|
test "make_point: a struct literal with punned fields" {
  same(
    "make_point",
    (
      #|type point = { x: i32, y: i32 };
      #|
      #|#[export = "make_point"]
      #|fn make_point(x: i32, y: i32) -> &point {
      #|    {point| x, y};
      #|}
      #|
      #|#[export = "distance_squared"]
      #|fn distance_squared(p1: &point, p2: &point) -> i32 {
      #|    let dx = p1.x - p2.x;
      #|    let dy = p1.y - p2.y;
      #|    dx * dx + dy * dy;
      #|}
    ),
    (
      #|type point = { x :: i32, y :: i32 }
      #|
      #|export "make_point" fn make_point(x :: i32, y :: i32) -> &point:
      #|  point{x, y}
      #|
      #|export "distance_squared" fn distance_squared(p1 :: &point, p2 :: &point) -> i32:
      #|  let dx = p1.x - p2.x
      #|  let dy = p1.y - p2.y
      #|  dx * dx + dy * dy
    ),
  )
}

///|
test "try_divide: tags, throw and a catch arm" {
  same(
    "try_divide",
    (
      #|tag divide_by_zero();
      #|tag overflow();
      #|
      #|#[export = "safe_divide"]
      #|fn safe_divide(a: i32, b: i32) -> i32 {
      #|    if b == 0 {
      #|        throw divide_by_zero();
      #|    }
      #|    a /s b;
      #|}
      #|
      #|#[export = "try_divide"]
      #|fn try_divide(a: i32, b: i32) -> i32 {
      #|    try i32 {
      #|        safe_divide(a, b);
      #|    } catch {
      #|        divide_by_zero => { 0; }
      #|    }
      #|}
    ),
    (
      #|tag divide_by_zero()
      #|tag overflow()
      #|
      #|export "safe_divide" fn safe_divide(a :: i32, b :: i32) -> i32:
      #|  if b == 0:
      #|    throw divide_by_zero()
      #|  a /~ b
      #|
      #|export "try_divide" fn try_divide(a :: i32, b :: i32) -> i32:
      #|  try -> i32:
      #|    safe_divide(a, b)
      #|  | divide_by_zero: 0
    ),
  )
}

///|
test "compute_and_log: an import group" {
  same(
    "compute_and_log",
    (
      #|import "env" {
      #|    fn log(value: i32);
      #|    const base_value: i32;
      #|}
      #|
      #|#[export = "compute_and_log"]
      #|fn compute_and_log(x: i32) -> i32 {
      #|    let result = x + base_value;
      #|    log(result);
      #|    result;
      #|}
    ),
    (
      #|import "env":
      #|  fn log(value :: i32)
      #|  const base_value :: i32
      #|
      #|export "compute_and_log" fn compute_and_log(x :: i32) -> i32:
      #|  let result = x + base_value
      #|  log(result)
      #|  result
    ),
  )
}

///|
test "sum_bytes: linear memory and an unsigned comparison" {
  same(
    "sum_bytes",
    (
      #|memory mem: i32 [1];
      #|
      #|#[export = "sum_bytes"]
      #|fn sum_bytes(start: i32, end: i32) -> i32 {
      #|    let total: i32 = 0;
      #|    let p: i32 = start;
      #|    while p <u end {
      #|        total += mem.load8(p) as i32_u;
      #|        p += 1;
      #|    }
      #|    total;
      #|}
    ),
    (
      #|memory mem :: i32 [1]
      #|
      #|export "sum_bytes" fn sum_bytes(start :: i32, end :: i32) -> i32:
      #|  let total :: i32 = 0
      #|  let p :: i32 = start
      #|  while p <$ end:
      #|    total += mem.load8(p) as i32_u
      #|    p += 1
      #|  total
    ),
  )
}

///|
test "counter: a mutable field and a struct set" {
  same(
    "counter",
    (
      #|type counter = { value: mut i32 };
      #|
      #|#[export = "new_counter"]
      #|fn new_counter() -> &counter {
      #|    {counter| value: 0};
      #|}
      #|
      #|#[export = "increment"]
      #|fn increment(c: &counter) {
      #|    c.value = c.value + 1;
      #|}
      #|
      #|#[export = "get_value"]
      #|fn get_value(c: &counter) -> i32 {
      #|    c.value;
      #|}
    ),
    (
      #|type counter = { value :: mut i32 }
      #|
      #|export "new_counter" fn new_counter() -> &counter:
      #|  counter{value: 0}
      #|
      #|export "increment" fn increment(c :: &counter):
      #|  c.value = c.value + 1
      #|
      #|export "get_value" fn get_value(c :: &counter) -> i32:
      #|  c.value
    ),
  )
}

///|
test "inference: literals that take their type from the context" {
  same(
    "inference",
    (
      #|type point = { x: i32, y: i32 };
      #|type ints = [mut i32];
      #|
      #|#[export = "origin"]
      #|fn origin() -> &point {
      #|    let p: &point = {x: 0, y: 0};
      #|    p;
      #|}
      #|
      #|#[export = "zeros"]
      #|fn zeros() -> &ints {
      #|    let a: &ints = [0; 16];
      #|    a;
      #|}
    ),
    (
      #|type point = { x :: i32, y :: i32 }
      #|type ints = [mut i32]
      #|
      #|export "origin" fn origin() -> &point:
      #|  let p :: &point = {x: 0, y: 0}
      #|  p
      #|
      #|export "zeros" fn zeros() -> &ints:
      #|  let a :: &ints = ints[0 ** 16]
      #|  a
    ),
  )
}
