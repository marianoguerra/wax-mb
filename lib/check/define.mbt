// `-D`: resolving conditional compilation ahead of everything else.
//
// Ported from wax/src/lib-wax/cond_specialize.ml and the evaluator of
// wax/src/lib-wasm/cond_specialize.ml.
//
// Each `#[if(...)]` whose condition the defines decide is replaced by the
// branch that survives; one they only partly decide is kept, its condition
// simplified -- the set variables substituted, the rest left. Attribute guards
// are resolved the same way. The source ranges of the dropped branches are
// returned, so the comments written in them can be dropped too.

///|
/// The value a `-D NAME[=VALUE]` sets.
pub(all) enum Define {
  DefineBool(Bool)
  DefineVersion(Int32, Int32, Int32)
  DefineString(String)
} derive(Eq, Debug)

///|
/// Parse one `-D` argument: a bare name, or `NAME=true`, sets a boolean;
/// `NAME=false` clears it; `NAME=A.B.C` with three non-negative integers sets a
/// version; anything else sets a string. The name must be a Wax identifier --
/// a keyword is allowed -- since no conditional could name anything else.
pub fn parse_define(s : String) -> Result[(String, Define), String] {
  let chars = s.iter().collect()
  let mut eq = -1
  for k, c in chars {
    if c == '=' {
      eq = k
      break
    }
  }
  let (name, value) = if eq < 0 {
    (s, None)
  } else {
    (
      String::from_array(chars[:eq].to_owned()),
      Some(String::from_array(chars[eq + 1:].to_owned())),
    )
  }
  if name == "" {
    return Err("empty variable name")
  }
  if !valid_identifier(name) {
    return Err("'\{name}' is not a valid variable name (a Wax identifier)")
  }
  let v = match value {
    None | Some("true") => DefineBool(true)
    Some("false") => DefineBool(false)
    Some(v) =>
      match parse_version(v) {
        Some((a, b, c)) => DefineVersion(a, b, c)
        None => DefineString(v)
      }
  }
  Ok((name, v))
}

///|
/// Three non-negative integers separated by dots.
fn parse_version(v : String) -> (Int32, Int32, Int32)? {
  let parts = v.split(".").map(p => p.to_owned()).collect()
  guard parts.length() == 3 else { return None }
  let nums : Array[Int32] = []
  for p in parts {
    guard p.length() > 0 && p.iter().all(c => c >= '0' && c <= '9') else {
      return None
    }
    let mut n = 0
    for c in p {
      n = n * 10 + (c.to_int() - '0'.to_int())
      if n > 1000000000 {
        return None
      }
    }
    nums.push(n)
  }
  Some((nums[0], nums[1], nums[2]))
}

///|
/// Whether `s` is a Wax identifier: an ASCII letter, or `_` followed by at least
/// one more character, or an `XID_Start` character, then identifier characters
/// (ASCII letters, digits, `_`, `'`, or `XID_Continue`).
fn valid_identifier(s : String) -> Bool {
  let chars = s.iter().collect()
  guard chars.length() > 0 else { return false }
  fn ascii_start(c : Char) -> Bool {
    (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
  }

  fn cont(c : Char) -> Bool {
    if c.to_int() < 0x80 {
      ascii_start(c) || (c >= '0' && c <= '9') || c == '_' || c == '\''
    } else {
      @xid.is_xid_continue(c.to_int())
    }
  }

  let first = chars[0]
  let rest_ok = chars[1:].iter().all(cont)
  if first.to_int() < 0x80 {
    if first == '_' {
      chars.length() > 1 && rest_ok
    } else {
      ascii_start(first) && rest_ok
    }
  } else {
    @xid.is_xid_start(first.to_int()) && rest_ok
  }
}

///|
/// What a condition comes to under the defines.
priv enum Decided {
  Holds
  Fails
  Residual(@wasm_types.Cond)
}

///|
fn decided(b : Bool) -> Decided {
  if b {
    Holds
  } else {
    Fails
  }
}

///|
fn flip(op : @wasm_types.CmpOp) -> @wasm_types.CmpOp {
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
fn apply_order(op : @wasm_types.CmpOp, c : Int32) -> Bool {
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
fn compare_versions(
  a : (Int32, Int32, Int32),
  b : (Int32, Int32, Int32),
) -> Int32 {
  if a.0 != b.0 {
    a.0.compare(b.0)
  } else if a.1 != b.1 {
    a.1.compare(b.1)
  } else {
    a.2.compare(b.2)
  }
}

///|
fn define_error(
  d : @diagnostic.Context,
  location : @basic.Location,
  message : String,
) -> Unit {
  d.report(location, Error, @message.text(message))
}

///|
/// Evaluate a condition as far as the defines allow.
fn eval_cond(
  d : @diagnostic.Context,
  env : Map[String, Define],
  c : @wasm_types.Cond,
) -> Decided {
  match c {
    Var(v) =>
      match env.get(v.desc) {
        Some(DefineBool(b)) => decided(b)
        Some(_) => {
          define_error(
            d,
            v.info,
            "Variable $\{v.desc} is set to a non-boolean value but used as a boolean here.",
          )
          Residual(c)
        }
        None => Residual(c)
      }
    And(l) => {
      let rest : Array[@wasm_types.Cond] = []
      for x in l {
        match eval_cond(d, env, x) {
          Fails => return Fails
          Holds => ()
          Residual(x2) => rest.push(x2)
        }
      }
      match rest {
        [] => Holds
        [x] => Residual(x)
        _ => Residual(And(rest))
      }
    }
    Or(l) => {
      let rest : Array[@wasm_types.Cond] = []
      for x in l {
        match eval_cond(d, env, x) {
          Holds => return Holds
          Fails => ()
          Residual(x2) => rest.push(x2)
        }
      }
      match rest {
        [] => Fails
        [x] => Residual(x)
        _ => Residual(Or(rest))
      }
    }
    Not(e) =>
      match eval_cond(d, env, e) {
        Holds => Fails
        Fails => Holds
        Residual(e2) => Residual(Not(e2))
      }
    Cmp(op, a, b) => eval_cmp(d, env, c, op, a, b)
    // Not a boolean: ill-formed, and left for the checker to report.
    Str(_) | Version(_, _, _) => Residual(c)
  }
}

///|
fn eval_cmp(
  d : @diagnostic.Context,
  env : Map[String, Define],
  whole : @wasm_types.Cond,
  op : @wasm_types.CmpOp,
  a : @wasm_types.Cond,
  b : @wasm_types.Cond,
) -> Decided {
  fn cmp_version(
    v : @basic.Annotated[String, @basic.Location],
    op : @wasm_types.CmpOp,
    ver : (Int32, Int32, Int32),
  ) -> Decided {
    match env.get(v.desc) {
      Some(DefineVersion(x, y, z)) =>
        decided(apply_order(op, compare_versions((x, y, z), ver)))
      Some(_) => {
        define_error(
          d,
          v.info,
          "Variable $\{v.desc} is not set to a version but compared with one here.",
        )
        Residual(whole)
      }
      None => Residual(whole)
    }
  }

  fn cmp_string(
    v : @basic.Annotated[String, @basic.Location],
    op : @wasm_types.CmpOp,
    s : Bytes,
  ) -> Decided {
    match env.get(v.desc) {
      Some(DefineString(s2)) => {
        let same = @utf8.encode(s2) == s
        match op {
          Eq => decided(same)
          Ne => decided(!same)
          _ => Residual(whole)
        }
      }
      Some(_) => {
        define_error(
          d,
          v.info,
          "Variable $\{v.desc} is not set to a string but compared with one here.",
        )
        Residual(whole)
      }
      None => Residual(whole)
    }
  }

  fn literal(c : @wasm_types.Cond) -> Bool {
    c is (Version(_, _, _) | Str(_))
  }

  match (a, b) {
    (Var(v), Version(x, y, z)) => cmp_version(v, op, (x, y, z))
    (Version(x, y, z), Var(v)) => cmp_version(v, flip(op), (x, y, z))
    (Var(v), Str(s)) => cmp_string(v, op, s.desc)
    (Str(s), Var(v)) => cmp_string(v, flip(op), s.desc)
    (Version(x1, y1, z1), Version(x2, y2, z2)) =>
      decided(apply_order(op, compare_versions((x1, y1, z1), (x2, y2, z2))))
    (Str(s1), Str(s2)) =>
      match op {
        Eq => decided(s1.desc == s2.desc)
        Ne => decided(s1.desc != s2.desc)
        _ => Residual(whole)
      }
    // The only other form: `=`/`!=` between two boolean sub-conditions.
    _ =>
      match op {
        Eq | Ne if !literal(a) && !literal(b) => {
          let ra = eval_cond(d, env, a)
          let rb = eval_cond(d, env, b)
          fn neg(r : Decided) -> Decided {
            match r {
              Holds => Fails
              Fails => Holds
              Residual(c) => Residual(Not(c))
            }
          }

          let eq = op is Eq
          match (ra, rb) {
            (Holds, _) => if eq { rb } else { neg(rb) }
            (Fails, _) => if eq { neg(rb) } else { rb }
            (_, Holds) => if eq { ra } else { neg(ra) }
            (_, Fails) => if eq { neg(ra) } else { ra }
            (Residual(ca), Residual(cb)) => Residual(Cmp(op, ca, cb))
          }
        }
        _ => Residual(whole)
      }
  }
}

///|
/// The walk that resolves conditionals, and the ranges it dropped.
priv struct Specializer {
  d : @diagnostic.Context
  env : Map[String, Define]
  ranges : Array[(Int32, Int32)]
}

///|
/// Resolve every conditional the defines decide, returning the module and the
/// byte ranges of the branches dropped.
pub fn specialize_defines(
  d : @diagnostic.Context,
  env : Map[String, Define],
  fields : @ast.Module[@basic.Location],
) -> (@ast.Module[@basic.Location], Array[(Int32, Int32)]) {
  let s : Specializer = { d, env, ranges: [], }
  let out = s.fields(fields)
  (out, s.ranges)
}

///|
/// The boundary between the two branches: the conditional's own end when it
/// has no else, else the end of the last then-node -- the best the AST offers
/// short of the `#[else]` token's own position.
fn split_at(
  loc : @basic.Location,
  then_ends : Array[@basic.Location],
  else_present : Bool,
) -> Int32 {
  if else_present {
    match then_ends.last() {
      Some(l) => l.end.cnum
      None => loc.end.cnum
    }
  } else {
    loc.end.cnum
  }
}

///|
/// Then kept, else dropped.
fn Specializer::drop_else(
  self : Specializer,
  loc : @basic.Location,
  then_ends : Array[@basic.Location],
  else_present : Bool,
) -> Unit {
  self.ranges.push((split_at(loc, then_ends, else_present), loc.end.cnum))
}

///|
/// Else kept (or nothing), then dropped.
fn Specializer::drop_then(
  self : Specializer,
  loc : @basic.Location,
  then_ends : Array[@basic.Location],
  else_present : Bool,
) -> Unit {
  self.ranges.push((loc.start.cnum, split_at(loc, then_ends, else_present)))
}

///|
fn Specializer::instrs(
  self : Specializer,
  l : Array[@ast.Instr[@basic.Location]],
) -> Array[@ast.Instr[@basic.Location]] {
  let out = []
  for i in l {
    for x in self.instr(i) {
      out.push(x)
    }
  }
  out
}

///|
fn Specializer::instr(
  self : Specializer,
  i : @ast.Instr[@basic.Location],
) -> Array[@ast.Instr[@basic.Location]] {
  match i.desc {
    IfAnnotation(cond~, then_body~, else_body~) => {
      let else_present = else_body is Some(_)
      let ends = then_body.desc.map(x => x.info)
      match eval_cond(self.d, self.env, cond) {
        Holds => {
          self.drop_else(i.info, ends, else_present)
          self.instrs(then_body.desc)
        }
        Fails => {
          self.drop_then(i.info, ends, else_present)
          match else_body {
            Some(e) => self.instrs(e.desc)
            None => []
          }
        }
        Residual(c) =>
          [
            {
              ..i,
              desc: IfAnnotation(
                cond=c,
                then_body={ ..then_body, desc: self.instrs(then_body.desc), },
                else_body=else_body.map(b => { ..b, desc: self.instrs(b.desc), }),
              ),
            },
          ]
      }
    }
    _ =>
      [
        {
          ..i,
          desc: i.desc.map_desc(instr=x => self.one(x), block=l => {
            self.instrs(l)
          }),
        },
      ]
  }
}

///|
/// A single-instruction position, where an `#[if]` cannot stand.
fn Specializer::one(
  self : Specializer,
  i : @ast.Instr[@basic.Location],
) -> @ast.Instr[@basic.Location] {
  match self.instr(i) {
    [x] => x
    _ => i
  }
}

///|
/// Resolve each attribute guard: a holding one is dropped and the attribute
/// kept, a failing one drops the attribute, and an undecided one is simplified.
fn Specializer::attrs(
  self : Specializer,
  attrs : @ast.Attributes,
) -> @ast.Attributes {
  let out : @ast.Attributes = []
  for a in attrs {
    match a.attr_guard {
      None => out.push(a)
      Some(g) =>
        match eval_cond(self.d, self.env, g.desc) {
          Holds => out.push({ ..a, attr_guard: None, })
          Fails => ()
          Residual(c) => out.push({ ..a, attr_guard: Some({ ..g, desc: c, }), })
        }
    }
  }
  out
}

///|
fn Specializer::decl(
  self : Specializer,
  decl : @basic.Annotated[@ast.ImportDecl, @basic.Location],
) -> @basic.Annotated[@ast.ImportDecl, @basic.Location] {
  {
    ..decl,
    desc: { ..decl.desc, attributes: self.attrs(decl.desc.attributes), },
  }
}

///|
fn Specializer::fields(
  self : Specializer,
  l : Array[
    @basic.Annotated[@ast.ModuleField[@basic.Location], @basic.Location],
  ],
) -> Array[@basic.Annotated[@ast.ModuleField[@basic.Location], @basic.Location]] {
  let out = []
  for f in l {
    for x in self.field(f) {
      out.push(x)
    }
  }
  out
}

///|
fn Specializer::field(
  self : Specializer,
  f : @basic.Annotated[@ast.ModuleField[@basic.Location], @basic.Location],
) -> Array[@basic.Annotated[@ast.ModuleField[@basic.Location], @basic.Location]] {
  let desc : @ast.ModuleField[@basic.Location] = match f.desc {
    Conditional(cond~, then_fields~, else_fields~) => {
      let else_present = else_fields is Some(_)
      let ends = then_fields.desc.map(x => x.info)
      match eval_cond(self.d, self.env, cond) {
        Holds => {
          self.drop_else(f.info, ends, else_present)
          return self.fields(then_fields.desc)
        }
        Fails => {
          self.drop_then(f.info, ends, else_present)
          return match else_fields {
            Some(e) => self.fields(e.desc)
            None => []
          }
        }
        Residual(c) =>
          Conditional(
            cond=c,
            then_fields={ ..then_fields, desc: self.fields(then_fields.desc), },
            else_fields=else_fields.map(e => { ..e, desc: self.fields(e.desc), }),
          )
      }
    }
    Func(name~, typ~, sign~, body~, attributes~) =>
      Func(
        name~,
        typ~,
        sign~,
        body=(body.0, self.instrs(body.1)),
        attributes=self.attrs(attributes),
      )
    Global(name~, mut_~, typ~, def~, attributes~) =>
      Global(
        name~,
        mut_~,
        typ~,
        def=self.one(def),
        attributes=self.attrs(attributes),
      )
    Tag(name~, typ~, sign~, attributes~) =>
      Tag(name~, typ~, sign~, attributes=self.attrs(attributes))
    Memory(
      name~,
      address_type~,
      limits~,
      page_size_log2~,
      shared~,
      data~,
      attributes~
    ) =>
      Memory(
        name~,
        address_type~,
        limits~,
        page_size_log2~,
        shared~,
        data~,
        attributes=self.attrs(attributes),
      )
    Table(name~, address_type~, reftype~, limits~, init~, attributes~) =>
      Table(
        name~,
        address_type~,
        reftype~,
        limits~,
        init~,
        attributes=self.attrs(attributes),
      )
    Import(module_~, decl~) => Import(module_~, decl=self.decl(decl))
    ImportGroup(module_~, decls~) =>
      ImportGroup(module_~, decls=decls.map(x => self.decl(x)))
    ModuleAnnotation(attrs) => ModuleAnnotation(self.attrs(attrs))
    Type(_) | TypeAlias(..) | Data(..) | Elem(..) => f.desc
  }
  [{ ..f, desc, }]
}
