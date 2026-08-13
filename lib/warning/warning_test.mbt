// The policy machinery: name resolution, group membership, override order.

///|
test "every warning has a distinct name" {
  let seen : Array[String] = []
  for w in @warning.all {
    let n = w.name()
    assert_false(seen.contains(n))
    seen.push(n)
  }
  assert_eq(@warning.all.length(), 23)
  // The one name that does not track its constructor.
  assert_eq((ShiftOverflow : @warning.Warning).name(), "shift-count-overflow")
}

///|
test "default policy hides the noisy groups and shows the rest" {
  let p = @warning.default_policy
  assert_eq(p.resolve(UnusedLocal), Displayed)
  assert_eq(p.resolve(DeadCode), Displayed)
  // Round-trip renaming notices and style suggestions stay quiet until asked
  // for.
  assert_eq(p.resolve(NamingConflict), Hidden)
  assert_eq(p.resolve(RedundantOperation), Hidden)
  assert_eq(p.resolve(FieldPunning), Hidden)
}

///|
test "a group sets all its members, and 'all' sets everything" {
  let p = @warning.default_policy.set("unused", Hidden).unwrap()
  assert_eq(p.resolve(UnusedLocal), Hidden)
  assert_eq(p.resolve(UnusedLabel), Hidden)
  // Untouched by the 'unused' group.
  assert_eq(p.resolve(DeadCode), Displayed)
  let q = @warning.default_policy.set("all", ErrorLevel).unwrap()
  for w in @warning.all {
    assert_eq(q.resolve(w), ErrorLevel)
  }
}

///|
/// Later assignments override earlier ones, which is what makes a sequence of
/// `-W` flags read left to right.
test "later -W flags override earlier ones" {
  let p = @warning.default_policy
    .set("all", Hidden)
    .unwrap()
    .set("unused-local", ErrorLevel)
    .unwrap()
  assert_eq(p.resolve(UnusedLocal), ErrorLevel)
  assert_eq(p.resolve(UnusedField), Hidden)
}

///|
test "unknown names are rejected, and the message lists what is known" {
  match @warning.default_policy.set("no-such-thing", Hidden) {
    Ok(_) => abort("expected an error")
    Err(msg) => {
      assert_true(msg.contains("Unknown warning or group 'no-such-thing'"))
      assert_true(msg.contains("unused-local"))
      assert_true(msg.contains("suggestion"))
    }
  }
}

///|
test "-W specs parse as NAME=LEVEL" {
  assert_eq(
    @warning.parse_spec("dead-code=error"),
    Ok(("dead-code", ErrorLevel)),
  )
  assert_eq(@warning.parse_spec("unused=hidden"), Ok(("unused", Hidden)))
  assert_eq(@warning.parse_spec("all=warning"), Ok(("all", Displayed)))
  assert_true(@warning.parse_spec("dead-code") is Err(_))
  assert_true(@warning.parse_spec("dead-code=loud") is Err(_))
}

///|
test "the faded set is the removable-with-no-effect one" {
  for w in @warning.all {
    let expect = match w {
      UnusedLocal | UnusedField | UnusedImport | UnusedLabel | DeadCode => true
      _ => false
    }
    assert_eq(w.is_unnecessary(), expect)
  }
}
