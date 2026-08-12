// Tests for the condition solver.
//
// The bar is complete and sound over Wax's condition language, because that is
// what makes these answers the same as the reference's BDD's. So the cases that
// matter are the ones where a purely propositional solver would get it wrong:
// contradictory version bounds, a string constrained two ways, and the
// interaction between the two.

///|
fn loc() -> @basic.Location {
  @basic.dummy_loc
}

///|
fn var_(name : String) -> @wasm_types.Cond {
  Var({ desc: name, info: loc() })
}

///|
fn str_(s : String) -> @wasm_types.Cond {
  Str({ desc: @utf8.encode(s), info: loc() })
}

///|
/// Translate and ask, with a context that collects rather than prints.
fn sat(c : @wasm_types.Cond) -> Bool {
  let env = @cond.Env::new()
  let ctx = @diagnostic.collector()
  @cond.is_satisfiable(env.of_cond(ctx, loc(), c))
}

///|
test "the constants" {
  inspect(@cond.is_satisfiable(@cond.true_), content="true")
  inspect(@cond.is_satisfiable(@cond.false_), content="false")
  inspect(@cond.logical_implies(@cond.false_, @cond.true_), content="true")
  inspect(@cond.logical_implies(@cond.true_, @cond.false_), content="false")
}

///|
test "propositional structure" {
  // $a
  inspect(sat(var_("a")), content="true")
  // $a and not $a
  inspect(sat(And([var_("a"), Not(var_("a"))])), content="false")
  // $a or not $a
  inspect(sat(Or([var_("a"), Not(var_("a"))])), content="true")
  // $a and $b -- independent variables, both satisfiable together
  inspect(sat(And([var_("a"), var_("b")])), content="true")
  // $a and not $b
  inspect(sat(And([var_("a"), Not(var_("b"))])), content="true")
}

///|
/// The reason a propositional solver is not enough. Nothing about the SHAPE of
/// `$v >= 2.0.0 and $v < 1.0.0` is contradictory -- two unrelated atoms, both
/// assignable to true. Only the order theory says otherwise.
test "contradictory version bounds are unsatisfiable" {
  let ge2 : @wasm_types.Cond = Cmp(Ge, var_("v"), Version(2, 0, 0))
  let lt1 : @wasm_types.Cond = Cmp(Lt, var_("v"), Version(1, 0, 0))
  inspect(sat(ge2), content="true")
  inspect(sat(lt1), content="true")
  inspect(sat(And([ge2, lt1])), content="false")
  // Compatible bounds are fine.
  inspect(
    sat(And([Cmp(Ge, var_("v"), Version(1, 0, 0)), lt1])),
    content="false",
  )
  inspect(
    sat(
      And([
        Cmp(Ge, var_("v"), Version(1, 0, 0)),
        Cmp(Lt, var_("v"), Version(2, 0, 0)),
      ]),
    ),
    content="true",
  )
}

///|
/// Endpoints: `v <= 1.0.0 and v >= 1.0.0` leaves exactly the point, which is
/// satisfiable; making either side strict empties it.
test "version interval endpoints" {
  let le : @wasm_types.Cond = Cmp(Le, var_("v"), Version(1, 0, 0))
  let ge : @wasm_types.Cond = Cmp(Ge, var_("v"), Version(1, 0, 0))
  let lt : @wasm_types.Cond = Cmp(Lt, var_("v"), Version(1, 0, 0))
  let gt : @wasm_types.Cond = Cmp(Gt, var_("v"), Version(1, 0, 0))
  inspect(sat(And([le, ge])), content="true")
  inspect(sat(And([lt, ge])), content="false")
  inspect(sat(And([le, gt])), content="false")
  // Equality is the interval collapsed to a point, and agrees with itself.
  inspect(sat(Cmp(Eq, var_("v"), Version(1, 2, 3))), content="true")
  inspect(
    sat(
      And([
        Cmp(Eq, var_("v"), Version(1, 2, 3)),
        Cmp(Eq, var_("v"), Version(1, 2, 4)),
      ]),
    ),
    content="false",
  )
  // Not-equal is the negation of that point, so it excludes only the point.
  inspect(
    sat(
      And([
        Cmp(Ne, var_("v"), Version(1, 2, 3)),
        Cmp(Eq, var_("v"), Version(1, 2, 3)),
      ]),
    ),
    content="false",
  )
  inspect(
    sat(
      And([
        Cmp(Ne, var_("v"), Version(1, 2, 3)),
        Cmp(Eq, var_("v"), Version(1, 2, 4)),
      ]),
    ),
    content="true",
  )
}

///|
/// Version comparisons are lexicographic over the triple, so 1.10.0 is above
/// 1.9.0 rather than below it.
test "versions order lexicographically, not textually" {
  inspect(
    sat(
      And([
        Cmp(Gt, var_("v"), Version(1, 9, 0)),
        Cmp(Lt, var_("v"), Version(1, 10, 0)),
      ]),
    ),
    content="true",
  )
  inspect(
    sat(
      And([
        Cmp(Gt, var_("v"), Version(1, 10, 0)),
        Cmp(Lt, var_("v"), Version(1, 9, 0)),
      ]),
    ),
    content="false",
  )
}

///|
test "a string variable can equal only one constant" {
  let is_a : @wasm_types.Cond = Cmp(Eq, var_("t"), str_("wasm"))
  let is_b : @wasm_types.Cond = Cmp(Eq, var_("t"), str_("native"))
  inspect(sat(is_a), content="true")
  inspect(sat(And([is_a, is_b])), content="false")
  inspect(sat(And([is_a, Cmp(Ne, var_("t"), str_("native"))])), content="true")
  inspect(sat(And([is_a, Cmp(Ne, var_("t"), str_("wasm"))])), content="false")
  // Two different variables are unrelated.
  inspect(sat(And([is_a, Cmp(Eq, var_("u"), str_("native"))])), content="true")
}

///|
/// Comparisons between two literals are decided at translation time.
test "literal comparisons fold" {
  inspect(sat(Cmp(Lt, Version(1, 0, 0), Version(2, 0, 0))), content="true")
  inspect(sat(Cmp(Gt, Version(1, 0, 0), Version(2, 0, 0))), content="false")
  inspect(sat(Cmp(Eq, str_("a"), str_("a"))), content="true")
  inspect(sat(Cmp(Eq, str_("a"), str_("b"))), content="false")
  inspect(sat(Cmp(Ne, str_("a"), str_("b"))), content="true")
}

///|
/// Which side the variable is on cannot change the meaning.
test "a flipped comparison means the same thing" {
  inspect(
    sat(
      And([
        Cmp(Ge, var_("v"), Version(2, 0, 0)),
        Cmp(Gt, Version(1, 0, 0), var_("v")),
      ]),
    ),
    content="false",
  )
  inspect(
    sat(
      And([
        Cmp(Le, Version(1, 0, 0), var_("v")),
        Cmp(Lt, var_("v"), Version(2, 0, 0)),
      ]),
    ),
    content="true",
  )
}

///|
/// Implication is the query the checker actually asks: is this declaration's
/// condition subsumed by the one in scope?
test "implication" {
  // One Env, so both formulas intern the same variables -- two Envs would
  // number them independently and the question would be meaningless.
  let env = @cond.Env::new()
  let ctx = @diagnostic.collector()
  let a = env.of_cond(ctx, loc(), And([var_("x"), var_("y")]))
  let x = env.of_cond(ctx, loc(), var_("x"))
  inspect(@cond.logical_implies(a, x), content="true")
  inspect(@cond.logical_implies(x, a), content="false")
  let v2 = env.of_cond(ctx, loc(), Cmp(Ge, var_("v"), Version(2, 0, 0)))
  let v1 = env.of_cond(ctx, loc(), Cmp(Ge, var_("v"), Version(1, 0, 0)))
  // v >= 2 entails v >= 1, not the other way round.
  inspect(@cond.logical_implies(v2, v1), content="true")
  inspect(@cond.logical_implies(v1, v2), content="false")
}

///|
/// `explain` names an assumption under which the formula holds, for the
/// diagnostic that says why a branch is reachable. A tautology has nothing to
/// assume and an unsatisfiable formula has no assumption that would do, so both
/// are `None`.
test "explain" {
  let env = @cond.Env::new()
  let ctx = @diagnostic.collector()
  fn say(f : @cond.T) -> String {
    env.explain(f).unwrap_or("<none>")
  }

  fn say_wax(f : @cond.T) -> String {
    env.explain(f, style=Wax).unwrap_or("<none>")
  }

  let f = env.of_cond(ctx, loc(), And([var_("oxcaml"), Not(var_("debug"))]))
  inspect(say(f), content="$oxcaml and not $debug")
  inspect(say_wax(f), content="oxcaml and not debug")
  // A tautology has nothing to assume; an unsatisfiable formula has no
  // assumption that would do. Both are silent.
  inspect(say(@cond.true_), content="<none>")
  inspect(say(@cond.false_), content="<none>")
  // A version bound renders in the style's spelling.
  let v = env.of_cond(ctx, loc(), Cmp(Ge, var_("v"), Version(1, 2, 3)))
  inspect(say(v), content="$v >= 1.2.3")
  inspect(say_wax(v), content="v >= (1, 2, 3)")
  let t = env.of_cond(ctx, loc(), Cmp(Eq, var_("t"), str_("wasm")))
  inspect(say(t), content="$t = \"wasm\"")
}
