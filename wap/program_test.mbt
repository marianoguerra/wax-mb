// Multi-module programs, from sources that are not files.

///|
/// Two modules and an entry, none of which exists on disk.
let geometry : String =
  #|module geometry
  #|
  #|pub type point = { x :: i32, y :: i32 }
  #|
  #|pub const origin_x = 0
  #|
  #|pub fn make(x :: i32, y :: i32) -> point:
  #|  point{x, y}
  #|
  #|pub fn dot(a :: point, b :: point) -> i32:
  #|  a.x * b.x + a.y * b.y
  #|
  #|fn secret() -> i32:
  #|  42

///|
let shapes : String =
  #|module shapes
  #|
  #|import geometry
  #|
  #|pub type box = { lo :: geometry.point, hi :: geometry.point }
  #|
  #|pub fn area(b :: box) -> i32:
  #|  let w = b.hi.x - b.lo.x
  #|  let h = b.hi.y - b.lo.y
  #|  w * h
  #|
  #|pub fn unit() -> box:
  #|  box{lo: geometry.make(0, 0), hi: geometry.make(1, 1)}

///|
let app : String =
  #|module app
  #|
  #|import geometry
  #|import shapes
  #|
  #|export "run" fn run() -> i32:
  #|  let b = shapes.unit()
  #|  let p = geometry.make(3, 4)
  #|  shapes.area(b) + geometry.dot(p, p) + geometry.origin_x

///|
fn loader() -> @resolve.MapLoader {
  @resolve.MapLoader::new(entries=[("geometry", geometry), ("shapes", shapes)])
}

///|
test "a program is resolved from a loader, not from a filesystem" {
  let program = @resolve.resolve_source("app", app, loader())
  let names = program.units().map(u => u.module_.name)
  // Dependencies first, entry last.
  assert_eq(names.join(" "), "geometry shapes app")
  assert_eq(program.entry(), "app")
}

///|
test "three modules become one wasm module, with the names prefixed" {
  let wat = match @wap.compile_program_to_wat("app", app, loader()) {
    Ok(w) => w
    Err(d) => {
      for r in d.wap {
        println("WAP: " + r.message)
      }
      for r in d.wax {
        println("WAX@" + r.loc.to_string())
      }
      fail("the program should have compiled")
    }
  }
  assert_true(wat.contains("$geometry__make"))
  assert_true(wat.contains("$shapes__area"))
  assert_true(wat.contains("$app__run"))
  assert_true(wat.contains("$geometry__point"))
  assert_true(wat.contains("\"run\""))
}

///|
test "a module cannot reach what another did not mark pub" {
  let bad =
    #|module app
    #|
    #|import geometry
    #|
    #|export "run" fn run() -> i32:
    #|  geometry.secret()
  let msg = match @wap.compile_program_to_wat("app", bad, loader()) {
    Ok(_) => "compiled"
    Err(d) => if d.wap.length() > 0 { d.wap[0].message } else { "no wap error" }
  }
  assert_true(msg.contains("is not `pub`"))
}

///|
test "a module cannot reach one it did not import" {
  let bad =
    #|module app
    #|
    #|import shapes
    #|
    #|export "run" fn run() -> i32:
    #|  geometry.origin_x
  let msg = match @wap.compile_program_to_wat("app", bad, loader()) {
    Ok(_) => "compiled"
    Err(d) => if d.wap.length() > 0 { d.wap[0].message } else { "no wap error" }
  }
  assert_true(msg.contains("does not import"))
}

///|
test "a missing module is named, not guessed at" {
  let bad =
    #|module app
    #|
    #|import nowhere
    #|
    #|fn f() -> i32: 0
  let msg = match @wap.program_to_wax("app", bad, loader()) {
    Ok(_) => "resolved"
    Err(rs) => rs[0].message
  }
  assert_true(msg.contains("cannot find module `nowhere`"))
}

///|
test "a cycle is reported with the whole ring" {
  let l = @resolve.MapLoader::new(entries=[
    ("a", "module a\n\nimport b\n\nfn f() -> i32: 0"),
    ("b", "module b\n\nimport a\n\nfn g() -> i32: 0"),
  ])
  let msg = match
    @wap.program_to_wax("a", "module a\n\nimport b\n\nfn f() -> i32: 0", l) {
    Ok(_) => "resolved"
    Err(rs) => rs[0].message
  }
  assert_true(msg.contains("import each other"))
  assert_true(msg.contains("a -> b -> a"))
}

///|
test "a path may have several segments; the module's own name is the alias" {
  let l = @resolve.MapLoader::new(entries=[
    (
      "collections.hashing",
      (
        #|module hashing
        #|
        #|pub fn mix(x :: u32) -> u32:
        #|  x * 0x9e3779b1
      ),
    ),
  ])
  let entry =
    #|module app
    #|
    #|import collections.hashing
    #|
    #|export "h" fn h(x :: u32) -> u32:
    #|  hashing.mix(x)
  let wat = match @wap.compile_program_to_wat("app", entry, l) {
    Ok(w) => w
    Err(d) => {
      for r in d.wap {
        println("WAP: " + r.message)
      }
      fail("the program should have compiled")
    }
  }
  assert_true(wat.contains("$hashing__mix"))
  assert_true(wat.contains("$app__h"))
}
