// The two column conventions are the single most error-prone detail in the
// whole diagnostic layer: the reference emits 0-based columns in JSON and
// 1-based columns in its human and short renderers, from the same position
// record. Pin both here so a later refactor cannot quietly unify them.

///|
test "column0 is JSON's convention, column1 is human's" {
  // `fn h() -> i32 { 1.0; }` — the `1.0` starts at byte offset 16 on line 1.
  let p : @basic.Position = { fname: "bad.wax", lnum: 1, bol: 0, cnum: 16, }
  assert_eq(p.column0(), 16)
  assert_eq(p.column1(), 17)
}

///|
test "columns are measured from the start of the line, not the file" {
  // Third line of a file, whose line starts at byte 40; the position is 4 bytes
  // in. Column must not leak the file-absolute offset.
  let p : @basic.Position = { fname: "m.wax", lnum: 3, bol: 40, cnum: 44, }
  assert_eq(p.column0(), 4)
  assert_eq(p.column1(), 5)
}

///|
test "dummy_pos matches OCaml's Lexing.dummy_pos" {
  // cnum = -1 is the sentinel the reference's no-source error path tests for;
  // 0 would be a legitimate offset (the first byte of a file).
  assert_eq(@basic.dummy_pos.cnum, -1)
  assert_true(@basic.dummy_pos.is_dummy())
  assert_true(@basic.dummy_loc.is_dummy())
  let real : @basic.Position = { fname: "m.wax", lnum: 1, bol: 0, cnum: 0, }
  assert_false(real.is_dummy())
}

///|
test "positions compare by offset within a file" {
  let a : @basic.Position = { fname: "m.wax", lnum: 1, bol: 0, cnum: 4, }
  let b : @basic.Position = { fname: "m.wax", lnum: 2, bol: 10, cnum: 12, }
  assert_true(a < b)
  assert_eq(a.compare(a), 0)
}

///|
test "merge spans the union of both locations" {
  let p = c => @basic.Position::{ fname: "m.wax", lnum: 1, bol: 0, cnum: c, }
  let left : @basic.Location = { start: p(2), end: p(5), }
  let right : @basic.Location = { start: p(9), end: p(14), }
  let merged = left.merge(right)
  assert_eq(merged.start.cnum, 2)
  assert_eq(merged.end.cnum, 14)
  // merge is commutative
  assert_eq(right.merge(left), merged)
}

///|
test "collapse_start and collapse_end give insertion points" {
  let p = c => @basic.Position::{ fname: "m.wax", lnum: 1, bol: 0, cnum: c, }
  let loc : @basic.Location = { start: p(3), end: p(8), }
  let at_start = loc.collapse_start()
  assert_eq(at_start.start, at_start.end)
  assert_eq(at_start.start.cnum, 3)
  let at_end = loc.collapse_end()
  assert_eq(at_end.start, at_end.end)
  assert_eq(at_end.start.cnum, 8)
}

///|
test "location JSON style is switchable for snapshot tests" {
  let p = (l, b, c) => @basic.Position::{
    fname: "m.wax",
    lnum: l,
    bol: b,
    cnum: c,
  }
  let loc : @basic.Location = { start: p(1, 0, 4), end: p(1, 0, 9), }
  @basic.show_loc.protect(Hidden, () => {
    json_inspect(loc.to_json(), content=Json::null())
  })
  @basic.show_loc.protect(Str, () => {
    json_inspect(loc.to_json(), content="1:5-1:10")
  })
  // JSON carries 0-based columns, matching the reference's --error-format=json
  @basic.show_loc.protect(Json, () => {
    json_inspect(loc.to_json(), content={
      "file": "m.wax",
      "start": { "line": 1, "column": 4 },
      "end": { "line": 1, "column": 9 },
    })
  })
}
