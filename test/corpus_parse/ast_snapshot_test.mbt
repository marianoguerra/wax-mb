// AST shape snapshots.
//
// Accept/reject says nothing about whether the parser built the RIGHT tree.
// Until the printer lands and oracle 1 can grade that end to end, these pin the
// shape of constructs where a plausible parse could still be wrong -- operator
// nesting, punning, compound assignment, conditional groups.
//
// Spans are hidden: these are about structure, and showing them would make
// every snapshot churn on an unrelated edit.

///|
/// Navigate into a Json value: "0" indexes an array, anything else a field.
///
/// Json has no indexing operator, and a whole-module snapshot for every case
/// would bury the one node each test is actually about.
fn dig(j : Json, path : Array[String]) -> Json {
  let mut cur = j
  for step in path {
    cur = match cur {
      Array(xs) => xs[@string.parse_int(step) catch { _ => 0 }]
      Object(m) => m.get(step).unwrap_or(Json::null())
      _ => Json::null()
    }
  }
  cur
}

///|
fn shape(src : String) -> Json {
  let r = @grammar.parse_string(src)
  match r.module_ {
    Some(m) => @ast.module_to_json(m)
    None => { "PARSE FAILED": Json::string(r.errors[0].message) }
  }
}

///|
test "operator precedence nests as declared" {
  // `*` binds tighter than `+`, and `+` is left-associative.
  @basic.show_loc.protect(Hidden, () => {
    json_inspect(shape("fn f() -> i32 { 1 + 2 * 3; }"), content=[
      {
        "kind": "fn",
        "children": {
          "name": "f",
          "attrs": [],
          "label": null,
          "body": [
            {
              "kind": "binop",
              "children": {
                "op": "+",
                "lhs": { "kind": "int", "children": { "raw": "1" } },
                "rhs": {
                  "kind": "binop",
                  "children": {
                    "op": "*",
                    "lhs": { "kind": "int", "children": { "raw": "2" } },
                    "rhs": { "kind": "int", "children": { "raw": "3" } },
                  },
                },
              },
            },
          ],
        },
      },
    ])
  })
}

///|
test "subtraction is left-associative" {
  // `1 - 2 - 3` must be `(1 - 2) - 3`, not `1 - (2 - 3)`.
  @basic.show_loc.protect(Hidden, () => {
    json_inspect(shape("fn f() -> i32 { 1 - 2 - 3; }"), content=[
      {
        "kind": "fn",
        "children": {
          "name": "f",
          "attrs": [],
          "label": null,
          "body": [
            {
              "kind": "binop",
              "children": {
                "op": "-",
                "lhs": {
                  "kind": "binop",
                  "children": {
                    "op": "-",
                    "lhs": { "kind": "int", "children": { "raw": "1" } },
                    "rhs": { "kind": "int", "children": { "raw": "2" } },
                  },
                },
                "rhs": { "kind": "int", "children": { "raw": "3" } },
              },
            },
          ],
        },
      },
    ])
  })
}

///|
test "signed operators keep their signedness" {
  @basic.show_loc.protect(Hidden, () => {
    json_inspect(
      dig(shape("fn f() -> i32 { 1 /s 2; }"), [
        "0", "children", "body", "0", "children", "op",
      ]),
      content="/s",
    )
  })
}

///|
test "compound assignment keeps its operator" {
  @basic.show_loc.protect(Hidden, () => {
    json_inspect(
      dig(shape("fn f() { let x: i32 = 0; x += 1; }"), [
        "0", "children", "body", "1",
      ]),
      content={
        "kind": "set",
        "children": {
          "name": "x",
          "op": "+",
          "value": { "kind": "int", "children": { "raw": "1" } },
        },
      },
    )
  })
}

///|
test "struct field punning is distinguishable from an explicit value" {
  // `{x}` carries no value; `{x: x}` does. Both must round-trip as written.
  @basic.show_loc.protect(Hidden, () => {
    json_inspect(
      dig(
        shape(
          "type t = { x: i32 };\nfn f(x: i32) { let a = {t| x}; let b = {t| x: x}; }",
        ),
        ["1", "children", "body"],
      ),
      content=[
        {
          "kind": "let",
          "children": {
            "bindings": [{ "name": "a", "type": null }],
            "init": {
              "kind": "struct",
              "children": {
                "type": "t",
                "fields": [{ "name": "x", "value": null }],
              },
            },
          },
        },
        {
          "kind": "let",
          "children": {
            "bindings": [{ "name": "b", "type": null }],
            "init": {
              "kind": "struct",
              "children": {
                "type": "t",
                "fields": [
                  {
                    "name": "x",
                    "value": { "kind": "get", "children": { "name": "x" } },
                  },
                ],
              },
            },
          },
        },
      ],
    )
  })
}

///|
test "numeric literals keep their raw spelling" {
  @basic.show_loc.protect(Hidden, () => {
    json_inspect(
      dig(shape("fn f() -> i32 { 0x1_0; }"), [
        "0", "children", "body", "0", "children", "raw",
      ]),
      content="0x1_0",
    )
  })
}

///|
test "a conditional group pairs its else branch" {
  // The dangling-else post-pass: two brace groups become ONE field.
  @basic.show_loc.protect(Hidden, () => {
    json_inspect(
      shape("#[if(portable)] { fn a() {} }\n#[else] { fn b() {} }"),
      content=[
        {
          "kind": "conditional",
          "children": {
            "then": [
              {
                "kind": "fn",
                "children": {
                  "name": "a",
                  "attrs": [],
                  "label": null,
                  "body": [],
                },
              },
            ],
            "else": [
              {
                "kind": "fn",
                "children": {
                  "name": "b",
                  "attrs": [],
                  "label": null,
                  "body": [],
                },
              },
            ],
          },
        },
      ],
    )
  })
}

///|
test "an unpaired if group has no else" {
  @basic.show_loc.protect(Hidden, () => {
    json_inspect(
      dig(shape("#[if(portable)] { fn a() {} }"), ["0", "children", "else"]),
      content=Json::null(),
    )
  })
}

///|
test "attributes reach the field they decorate" {
  @basic.show_loc.protect(Hidden, () => {
    json_inspect(
      dig(shape("#[export = \"add\"]\nfn add(x: i32) -> i32 { x; }"), [
        "0", "children", "attrs",
      ]),
      content=["export"],
    )
  })
}

///|
/// The %nonassoc workaround (see test/UPSTREAM-FINDINGS.md).
///
/// MoonYacc panics on a %nonassoc conflict, so the comparison level is declared
/// %left and non-associativity is enforced in the action. These pin the
/// behaviour that workaround has to reproduce, including the SPAN, which oracle
/// 3 gates.
test "a chained comparison is rejected, a parenthesized one is not" {
  let chained = @grammar.parse_string("fn f() -> i32 { 1 < 2 < 3; }")
  inspect(chained.errors.length(), content="1")
  // The reference reports this at the SECOND operator. `<` is one byte, at
  // offset 22 in this source.
  inspect(chained.errors[0].loc.start.cnum, content="22")
  inspect(chained.errors[0].loc.end.cnum, content="23")

  // Both parenthesizations are accepted, matching the reference.
  inspect(
    @grammar.parse_string("fn f() -> i32 { 1 < (2 < 3); }").errors.length(),
    content="0",
  )
  inspect(
    @grammar.parse_string("fn f() -> i32 { (1 < 2) < 3; }").errors.length(),
    content="0",
  )
  // Mixed operators at the same precedence level chain too.
  inspect(
    @grammar.parse_string("fn f() -> i32 { 1 < 2 == 3; }").errors.length(),
    content="1",
  )
}
