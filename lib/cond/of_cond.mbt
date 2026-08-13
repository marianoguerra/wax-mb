// Translating a source condition into a formula.
//
// The diagnostics here are compared by oracle 3, so the wording and the
// conditions that trigger them follow `cond_solver.ml` exactly.

///|
/// Per-module solver state: variable interning, the kind each name is used at,
/// and deduplication of ill-formed-condition diagnostics.
///
/// One `Env` per module, so nothing leaks between modules processed in the same
/// run.
pub struct Env {
  bool_vars : Map[String, Int]
  version_vars : Map[String, Int]
  string_vars : Map[String, Int]
  /// The reverse mapping, for `explain`.
  names : Map[Int, String]
  mut next_var : Int
  /// The kind a name has been used at, so an inconsistent use is reported.
  var_kind : Map[String, String]
  /// Spans already reported, keyed by offsets: one ill-formed condition should
  /// not produce a report per enclosing pass.
  reported : Map[(Int, Int), Unit]
}

///|
pub fn Env::new() -> Env {
  {
    bool_vars: {},
    version_vars: {},
    string_vars: {},
    names: {},
    next_var: 0,
    var_kind: {},
    reported: {},
  }
}

///|
fn Env::intern(self : Env, tbl : Map[String, Int], name : String) -> Int {
  match tbl.get(name) {
    Some(v) => v
    None => {
      let v = self.next_var
      self.next_var = v + 1
      tbl[name] = v
      self.names[v] = name
      v
    }
  }
}

///|
/// A variable nothing constrains, which is what an unmodelable condition
/// becomes so that exploration can proceed past it.
fn Env::fresh(self : Env) -> T {
  let v = self.next_var
  self.next_var = v + 1
  { node: Lit(Bool(v), true) }
}

///|
fn Env::report_ill_formed(
  self : Env,
  ctx : @diagnostic.Context,
  location : @basic.Location,
  msg : String,
) -> Unit {
  let key = (location.start.cnum, location.end.cnum)
  if !self.reported.contains(key) {
    self.reported[key] = ()
    ctx.report(location, Error, @message.text(msg))
  }
}

///|
fn Env::check_kind(
  self : Env,
  ctx : @diagnostic.Context,
  location : @basic.Location,
  name : String,
  kind : String,
) -> Unit {
  if self.var_kind.get(name) is Some(k) && k != kind {
    self.report_ill_formed(
      ctx,
      location,
      "Variable $\{name} is used with inconsistent types.",
    )
  } else {
    self.var_kind[name] = kind
  }
}

///|
/// The comparison with its operands the other way round.
fn swap_op(op : @wasm_types.CmpOp) -> @wasm_types.CmpOp {
  match op {
    Le => Ge
    Ge => Le
    Lt => Gt
    Gt => Lt
    Eq => Eq
    Ne => Ne
  }
}

///|
fn bool_const(b : Bool) -> T {
  if b {
    true_
  } else {
    false_
  }
}

///|
/// Does this comparison hold, given `compare`'s verdict?
fn apply_order(op : @wasm_types.CmpOp, c : Int) -> Bool {
  match op {
    Eq => c == 0
    Ne => c != 0
    Lt => c < 0
    Le => c <= 0
    Gt => c > 0
    Ge => c >= 0
  }
}

///|
/// `vid OP version`, in terms of upper-bound atoms.
fn version_atom(vid : Int, op : @wasm_types.CmpOp, v : Version) -> T {
  let le = { node: Lit(Bound(vid, v, true), true) } // vid <= v
  let lt = { node: Lit(Bound(vid, v, false), true) } // vid <  v
  match op {
    Le => le
    Lt => lt
    Gt => not_(le)
    Ge => not_(lt)
    Eq => and_(le, not_(lt))
    Ne => not_(and_(le, not_(lt)))
  }
}

///|
fn Env::string_atom(
  self : Env,
  ctx : @diagnostic.Context,
  location : @basic.Location,
  vid : Int,
  op : @wasm_types.CmpOp,
  s : Bytes,
) -> T {
  match op {
    Eq => { node: Lit(Const(vid, s), true) }
    Ne => { node: Lit(Const(vid, s), false) }
    Lt | Gt | Le | Ge => {
      self.report_ill_formed(
        ctx, location, "Strings can only be compared with = or <> in a condition.",
      )
      self.fresh()
    }
  }
}

///|
fn is_literal(c : @wasm_types.Cond) -> Bool {
  c is (Version(_, _, _) | Str(_))
}

///|
/// Translate a condition, interning its variables.
///
/// A condition that cannot be modelled is reported (once per source location)
/// and becomes a fresh unconstrained variable, so that exploration proceeds
/// rather than stopping at the first unmodelable branch. `location` is the
/// enclosing conditional, used when a sub-condition carries no span of its own.
pub fn Env::of_cond(
  self : Env,
  ctx : @diagnostic.Context,
  location : @basic.Location,
  c : @wasm_types.Cond,
) -> T {
  match c {
    Var(v) => {
      self.check_kind(ctx, v.info, v.desc, "boolean")
      { node: Lit(Bool(self.intern(self.bool_vars, v.desc)), true) }
    }
    And(l) => and_list(l.map(x => self.of_cond(ctx, location, x)))
    Or(l) => or_list(l.map(x => self.of_cond(ctx, location, x)))
    Not(e) => not_(self.of_cond(ctx, location, e))
    Cmp(op, a, b) => self.cmp(ctx, location, op, a, b)
    Str(_) | Version(_, _, _) => {
      self.report_ill_formed(
        ctx, location, "This condition should be a boolean.",
      )
      self.fresh()
    }
  }
}

///|
fn Env::cmp(
  self : Env,
  ctx : @diagnostic.Context,
  location : @basic.Location,
  op : @wasm_types.CmpOp,
  a : @wasm_types.Cond,
  b : @wasm_types.Cond,
) -> T {
  fn version_var(loc : @basic.Location, name : String) -> Int {
    self.check_kind(ctx, loc, name, "version")
    self.intern(self.version_vars, name)
  }

  fn string_var(loc : @basic.Location, name : String) -> Int {
    self.check_kind(ctx, loc, name, "string")
    self.intern(self.string_vars, name)
  }

  match (a, b) {
    (Var(v), Version(x, y, z)) =>
      version_atom(version_var(v.info, v.desc), op, {
        major: x,
        minor: y,
        patch: z,
      })
    (Version(x, y, z), Var(v)) =>
      version_atom(version_var(v.info, v.desc), swap_op(op), {
        major: x,
        minor: y,
        patch: z,
      })
    (Var(v), Str(s)) =>
      self.string_atom(ctx, location, string_var(v.info, v.desc), op, s.desc)
    (Str(s), Var(v)) =>
      self.string_atom(
        ctx,
        location,
        string_var(v.info, v.desc),
        swap_op(op),
        s.desc,
      )
    (Version(x1, y1, z1), Version(x2, y2, z2)) =>
      bool_const(
        apply_order(
          op,
          ({ major: x1, minor: y1, patch: z1 } : Version).compare_to({
            major: x2,
            minor: y2,
            patch: z2,
          }),
        ),
      )
    (Str(x), Str(y)) =>
      match op {
        Eq => bool_const(x.desc == y.desc)
        Ne => bool_const(x.desc != y.desc)
        _ => {
          self.report_ill_formed(
            ctx, location, "Strings can only be compared with = or <> in a condition.",
          )
          self.fresh()
        }
      }
    _ =>
      // Two boolean-valued conditions compared: `=` is agreement, `<>` is
      // disagreement. Anything else is not modelled.
      if op is (Eq | Ne) && !is_literal(a) && !is_literal(b) {
        let ba = self.of_cond(ctx, location, a)
        let bb = self.of_cond(ctx, location, b)
        if op is Eq {
          iff(ba, bb)
        } else {
          xor(ba, bb)
        }
      } else {
        self.report_ill_formed(
          ctx, location, "This comparison in a condition is not supported.",
        )
        self.fresh()
      }
  }
}
