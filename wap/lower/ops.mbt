// Operators, sets, calls and casts.

///|
/// A binary operator, with its signedness taken from the operands' types.
fn Lowering::binary(
  self : Lowering,
  op : @wap.BinOp,
  a : @wap.Node,
  b : @wap.Node,
  sp : @wap.Span,
) -> @ast.Instr[@basic.Location] {
  let at = self.loc(sp)
  let lt = match self.type_of(a) {
    Some(t) => Some(t)
    None => self.type_of(b)
  }
  // Set arithmetic: `+` is union, `-` is difference, `&` is intersection.
  if self.set_type(lt) is Some(_) {
    return self.set_binary(op, a, b, lt, sp)
  }
  let sign = self.signage(lt)
  let wop : @ast.BinOp = match op {
    Add => Add
    Sub => Sub
    Mul => Mul
    Div => Div(sign)
    Rem =>
      match sign {
        Some(s) => Rem(s)
        None => {
          self.error("`%` is an integer operator", sp)
          Rem(Signed)
        }
      }
    Shl => Shl
    Shr =>
      match sign {
        Some(s) => Shr(s)
        None => {
          self.error("`>>` is an integer operator", sp)
          Shr(Signed)
        }
      }
    BitAnd => And
    BitOr => Or
    BitXor => Xor
    Eq => Eq
    Ne => Ne
    Lt => Lt(sign)
    Gt => Gt(sign)
    Le => Le(sign)
    Ge => Ge(sign)
  }
  @ast.build(
    BinOpI({ desc: wop, info: at, }, self.expr(a, lt), self.expr(b, lt)),
    at,
  )
}

///|
/// The enumeration a set type is over, if the type is a set.
fn Lowering::set_type(self : Lowering, t : @wap.Type?) -> String? {
  match t {
    Some(Named(n)) =>
      match self.resolve(n) {
        Some(SetOf(e)) => Some(e)
        _ => None
      }
    _ => None
  }
}

///|
/// `+`, `-` and `&` on sets, which are the masks they lower to.
fn Lowering::set_binary(
  self : Lowering,
  op : @wap.BinOp,
  a : @wap.Node,
  b : @wap.Node,
  t : @wap.Type?,
  sp : @wap.Span,
) -> @ast.Instr[@basic.Location] {
  let at = self.loc(sp)
  let l = self.expr(a, t)
  let r = self.expr(b, t)
  match op {
    Add | BitOr => @ast.build(BinOpI({ desc: Or, info: at, }, l, r), at)
    BitAnd => @ast.build(BinOpI({ desc: And, info: at, }, l, r), at)
    BitXor => @ast.build(BinOpI({ desc: Xor, info: at, }, l, r), at)
    Sub => {
      // Wax's `!` is `eqz`, not a bitwise complement, so the complement is a
      // xor with all ones -- which is what the printed expansion shows.
      let ones = @ast.build(Int("-1"), at)
      let comp = @ast.build(BinOpI({ desc: Xor, info: at, }, r, ones), at)
      @ast.build(BinOpI({ desc: And, info: at, }, l, comp), at)
    }
    Eq => @ast.build(BinOpI({ desc: Eq, info: at, }, l, r), at)
    Ne => @ast.build(BinOpI({ desc: Ne, info: at, }, l, r), at)
    _ => {
      self.error(
        "a set supports `+` (union), `-` (difference), `&` (intersection), `^`, `==` and `in`",
        sp,
      )
      l
    }
  }
}

///|
/// `{a, b}` as a bitmask.
fn Lowering::set_literal(
  self : Lowering,
  items : Array[@wap.Node],
  expected : @wap.Type?,
  sp : @wap.Span,
) -> @ast.Instr[@basic.Location] {
  let at = self.loc(sp)
  let mut constant = 0
  let dynamic = []
  for it in items {
    match self.ordinal_of(it, expected) {
      Some(k) => constant = constant | (1 << k)
      None => {
        // A set element that is not a literal: `1 << ord(x)`.
        let one = @ast.build(Int("1"), at)
        dynamic.push(
          @ast.build(
            BinOpI({ desc: Shl, info: at, }, one, self.expr(it, None)),
            at,
          ),
        )
      }
    }
  }
  let mut acc = @ast.build(Int(constant.to_string()), at)
  for d in dynamic {
    acc = @ast.build(BinOpI({ desc: Or, info: at, }, acc, d), at)
  }
  acc
}

///|
/// The ordinal of a set element written as an enumerator or an integer.
fn Lowering::ordinal_of(
  self : Lowering,
  e : @wap.Node,
  expected : @wap.Type?,
) -> Int? {
  match e.it {
    Var(n) => {
      let owner = match self.set_type(expected) {
        Some(o) => Some(o)
        None => self.member_owner.get(self.qualify(n))
      }
      match owner {
        Some(o) =>
          match self.enum_members.get(o) {
            Some(ms) => ms.get(n)
            None => None
          }
        None => None
      }
    }
    Int(s) => int_of(s)
    _ => None
  }
}

///|
/// `x in s`, which is one mask and one comparison.
fn Lowering::in_set(
  self : Lowering,
  x : @wap.Node,
  s : @wap.Node,
  sp : @wap.Span,
) -> @ast.Instr[@basic.Location] {
  let at = self.loc(sp)
  let stype = self.type_of(s)
  let set = self.expr(s, stype)
  let mask = match self.ordinal_of(x, stype) {
    Some(k) => @ast.build(Int((1 << k).to_string()), at)
    None =>
      @ast.build(
        BinOpI(
          { desc: Shl, info: at, },
          @ast.build(Int("1"), at),
          self.expr(x, None),
        ),
        at,
      )
  }
  let anded = @ast.build(BinOpI({ desc: And, info: at, }, set, mask), at)
  @ast.build(
    BinOpI({ desc: Ne, info: at, }, anded, @ast.build(Int("0"), at)),
    at,
  )
}

///|
/// `e as t`.
fn Lowering::cast(
  self : Lowering,
  inner : @wap.Node,
  t : @wap.Type,
  sp : @wap.Span,
) -> @ast.Instr[@basic.Location] {
  let at = self.loc(sp)
  let value = self.expr(inner, None)
  let from = self.type_of(inner)
  // Widening a packed or narrow integer needs the signedness Wax makes you
  // write; wap has it in the source type.
  let widening = match (from, self.underlying(t)) {
    (Some(f), I32) | (Some(f), I64) => self.is_packed(f)
    _ => false
  }
  // `x as i32_u` -- Wax's spelling, kept because there is no shorter way to
  // say "widen this, treating it as unsigned" when the source type does not
  // already say so.
  match t {
    Named(n) =>
      match signed_cast(n) {
        Some((nt, signage)) =>
          return @ast.build(
            Cast(value, Signed(typ=nt, signage~, strict=false)),
            at,
          )
        None => ()
      }
    _ => ()
  }
  if widening {
    let signage = match self.signage(from) {
      Some(s) => s
      None => @wasm_types.Signage::Unsigned
    }
    let nt : @ast.NumType = match self.underlying(t) {
      I64 | U64 => I64
      _ => I32
    }
    return @ast.build(Cast(value, Signed(typ=nt, signage~, strict=false)), at)
  }
  @ast.build(Cast(value, Value(self.valtype(t, sp))), at)
}

///|
/// A method call: an array intrinsic, or a function whose first parameter is
/// the receiver.
fn Lowering::method_call(
  self : Lowering,
  recv : @wap.Node,
  name : String,
  args : Array[@wap.Node],
  sp : @wap.Span,
) -> @ast.Instr[@basic.Location] {
  let at = self.loc(sp)
  // `hashing.i32_value(x)` is a call into another module, not a method.
  match self.module_ref(recv, name) {
    Some(q) => {
      self.check_visible(q, sp)
      let out = []
      for a in args {
        out.push(self.expr(a, None))
      }
      return @ast.build(Call(self.var_ref(q, sp), out), at)
    }
    None => ()
  }
  // The array intrinsics keep Wax's spelling, except that `len` is shorter
  // than `length` and is the only one worth renaming.
  let intrinsic = match name {
    "len" => Some("length")
    "copy" | "fill" | "init" => Some(name)
    _ => None
  }
  match intrinsic {
    Some(wax_name) => {
      let callee = @ast.build(
        StructGet(self.expr(recv, None), self.ident(wax_name, sp)),
        at,
      )
      let out = []
      for a in args {
        out.push(self.expr(a, None))
      }
      return @ast.build(Call(callee, out), at)
    }
    None => ()
  }
  let record = match self.type_of(recv) {
    Some(t) => self.record_name(t)
    None => None
  }
  // A method on something that is not a record with that method is Wax's --
  // `x.rotl(15)`, `m.load8(p)`, `f.to_bits()`. Wap does not carry a table of
  // them: it emits the shape Wax reads as a method call and lets Wax resolve
  // it, so every intrinsic Wax gains is one wap gains.
  let known = match record {
    Some(r) => self.lookup_method(r, name) is Some(_)
    None => false
  }
  if !known {
    let callee = @ast.build(
      StructGet(self.expr(recv, None), self.ident(name, sp)),
      at,
    )
    let out = []
    for a in args {
      out.push(self.expr(a, None))
    }
    return @ast.build(Call(callee, out), at)
  }
  match record {
    Some(r) => {
      let target = match self.method_owners.get(name) {
        // More than one type implements it, so the call goes through the
        // generated dispatcher for the receiver's static type.
        Some(owners) =>
          if owners.length() > 1 && self.has_subtype(r) {
            self.mangle_method(r, name + "__dyn")
          } else {
            match self.owner_of_method(r, name) {
              Some(o) => self.mangle_method(o, name)
              None => self.mangle_method(r, name)
            }
          }
        None => self.mangle_method(r, name)
      }
      let out = [self.expr(recv, None)]
      for a in args {
        out.push(self.expr(a, None))
      }
      @ast.build(Call(@ast.build(Get(self.ident(target, sp)), at), out), at)
    }
    None => @ast.build(Unreachable, at)
  }
}

///|
/// The nearest ancestor of `record` that defines the method.
fn Lowering::owner_of_method(
  self : Lowering,
  record : String,
  name : String,
) -> String? {
  if self.methods.contains(self.qualify(record) + "." + name) {
    return Some(record)
  }
  match self.resolve(record) {
    Some(Record(parent=Some(p), ..)) => self.owner_of_method(p, name)
    _ => None
  }
}

///|
/// True when some record extends this one.
fn Lowering::has_subtype(self : Lowering, record : String) -> Bool {
  let q = self.qualify(record)
  for _, def in self.types {
    if def is Record(parent=Some(p), ..) && p == q {
      return true
    }
  }
  false
}

///|
/// The Wax `as i32_u` family.
///
/// The float targets are here for the same reason the integer ones are: each
/// name is one instruction and the signedness picks it. `f64.convert_i64_s`
/// and `f64.convert_i64_u` read the same bits and answer different numbers, so
/// there is nothing for wap to infer -- the source type says how the integer
/// is signed, not how the conversion should read it. Going the other way,
/// `x as i32_s` on a float is `i32.trunc_f32_s`, which is why the integer
/// names already covered the truncations.
fn signed_cast(name : String) -> (@ast.NumType, @wasm_types.Signage)? {
  match name {
    "i32_s" => Some((I32, Signed))
    "i32_u" => Some((I32, Unsigned))
    "i64_s" => Some((I64, Signed))
    "i64_u" => Some((I64, Unsigned))
    "f32_s" => Some((F32, Signed))
    "f32_u" => Some((F32, Unsigned))
    "f64_s" => Some((F64, Signed))
    "f64_u" => Some((F64, Unsigned))
    _ => None
  }
}

///|
/// An integer literal in any radix.
fn int_of(text : String) -> Int? {
  Some(@string.parse_int(text)) catch {
    _ => None
  }
}
