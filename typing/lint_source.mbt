// The lints that read the SOURCE shape rather than the types.
//
// Ported from `lint_source` in wax/src/lib-wax/typing_lint.ml.
//
// These ask what the author wrote, not what it means: an expression computed and
// then dropped, a condition already decided, a variable assigned to itself.
// None of them needs the checker's result, which is why they walk the untyped
// tree -- and why they can say `x = x` is pointless without knowing what `x` is.

///|
/// The `int64` value of a constant integer operand, folded exactly as the code
/// generator folds it.
///
/// A negative literal is `UnOp(Neg, Int ..)` rather than a bare `Int`, and the
/// generator folds a `Neg` only over a bare literal -- `-40` becomes a constant,
/// `--40` becomes a runtime subtraction. `Pos` is transparent. Folding anything
/// deeper here would make the lint fire where the emitted code has no constant
/// at all.
pub fn int_operand_value(e : @ast.Instr[@basic.Location]) -> Int64? {
  match e.desc {
    Int(s) => int_literal_value(s)
    UnOpI(op, inner) =>
      match (op.desc, inner.desc) {
        (Neg, Int(s)) => int_literal_value(s).map(v => -v)
        (Pos, _) => int_operand_value(inner)
        _ => None
      }
    _ => None
  }
}

///|
/// A decimal or hex integer literal's value, underscores ignored.
fn int_literal_value(s : String) -> Int64? {
  let cleaned = s.split("_").join("")
  Some(@string.parse_int64(cleaned)) catch {
    _ =>
      // A `0x..` literal past 2^63 does not fit a signed parse; read it
      // unsigned and reinterpret, which is the bit pattern the encoder emits.
      Some(@string.parse_uint64(cleaned).reinterpret_as_int64()) catch {
        _ => None
      }
  }
}

///|
/// Whether a cast never traps, so discarding its result is pointless.
///
/// A STRICT float-to-integer conversion lowers to `trunc`, which traps out of
/// range; its saturating form and every numeric widen, narrow and convert are
/// total. A reference cast may trap and is conservatively treated as partial.
pub fn cast_is_total(c : @ast.CastType) -> Bool {
  match c {
    Signed(typ~, strict~, ..) =>
      match typ {
        F32 | F64 => true
        I32 | I64 => !strict
      }
    Value(I32 | I64 | F32 | F64) => true
    Value(V128 | Ref(_)) | Func(..) => false
  }
}

///|
/// Whether a method computes its result and does nothing else.
pub fn is_pure_unary_method(m : String) -> Bool {
  match m {
    "clz"
    | "ctz"
    | "popcnt"
    | "extend8_s"
    | "extend16_s"
    | "abs"
    | "ceil"
    | "floor"
    | "trunc"
    | "nearest"
    | "sqrt"
    | "to_bits"
    | "from_bits" => true
    _ => false
  }
}

///|
/// Likewise for the two-operand methods.
pub fn is_pure_binary_method(m : String) -> Bool {
  match m {
    "rotl" | "rotr" | "min" | "max" | "copysign" => true
    _ => false
  }
}

///|
/// Whether evaluating this expression can do nothing but produce a value.
///
/// Conservative in the one direction that matters: anything not listed is
/// assumed to have an effect, so the lint never claims a computation is
/// pointless when it might trap, write, or call.
pub fn is_effectless(e : @ast.Instr[@basic.Location]) -> Bool {
  fn field(f : (@ast.Ident, @ast.Instr[@basic.Location]?)) -> Bool {
    match f.1 {
      Some(v) => is_effectless(v)
      // A punned field `{x}` reads a local or a global, which is effectless.
      None => true
    }
  }

  match e.desc {
    Get(_)
    | Int(_)
    | Float(_)
    | Char(_)
    | Str(_, _)
    | Null
    | StructDefault(_) => true
    UnOpI(_, a) => is_effectless(a)
    Call(callee, args) =>
      match callee.desc {
        StructGet(recv, m) =>
          if args.is_empty() && is_pure_unary_method(m.name) {
            is_effectless(recv)
          } else if args.length() == 1 && is_pure_binary_method(m.name) {
            is_effectless(recv) && is_effectless(args[0])
          } else if @simd.classify(m.name) is Some(_) {
            // Every vector op is pure and non-trapping; the trapping SIMD
            // accesses go through the `mem.` path and are classified there.
            is_effectless(recv) && args.iter().all(is_effectless)
          } else if m.name == "size" && recv.desc is Get(_) && args.is_empty() {
            // `m.size()` / `tab.size()` reads the current size, unlike the
            // effectful grow/fill/copy/init on the same path.
            true
          } else {
            false
          }
        // A `v128::..` constructor or vector op is effect-free when its
        // operands are.
        Path(ns, _) => ns.name == "v128" && args.iter().all(is_effectless)
        _ => false
      }
    // A typed null `null as &?t` is `ref.null`, a constant, not a trapping
    // reference cast.
    Cast(inner, Value(Ref({ nullable: true, .. }))) => inner.desc is Null
    Cast(a, ct) => cast_is_total(ct) && is_effectless(a)
    // Division and remainder trap on a zero divisor.
    BinOpI(op, a, b) =>
      if op.desc is (Div(_) | Rem(_)) {
        false
      } else {
        is_effectless(a) && is_effectless(b)
      }
    Select(a, b, c) => is_effectless(a) && is_effectless(b) && is_effectless(c)
    Test(a, _) => is_effectless(a)
    Struct(_, fields) => fields.iter().all(field)
    StructDesc(d, fields) => is_effectless(d) && fields.iter().all(field)
    StructDefaultDesc(d) => is_effectless(d)
    Array(_, elt, len) => is_effectless(elt) && is_effectless(len)
    ArrayDefault(_, len) => is_effectless(len)
    ArrayFixed(_, elts) => elts.iter().all(is_effectless)
    _ => false
  }
}

///|
/// Report a condition whose value is already decided.
///
/// A `while (true)` is exempt: an infinite loop written that way is
/// deliberate, and saying so would be noise on the one shape that means it.
fn lint_condition(
  ctx : @typing_env.ModuleContext,
  cond : @ast.Instr[@basic.Location],
  is_while? : Bool = false,
) -> Unit {
  guard int_operand_value(cond) is Some(n) else { return }
  let value = n != 0
  if !(is_while && value) {
    constant_condition(ctx.diagnostics, cond.info, value)
  }
}

///|
/// Walk a function body reporting the source-shape lints.
///
/// Every arm here is a recursion; the ones that also report are `Let` (a drop
/// whose value is computed for nothing), `Set` (a variable written back to
/// itself), and the three that carry a condition.
pub fn lint_source(
  ctx : @typing_env.ModuleContext,
  i : @ast.Instr[@basic.Location],
) -> Unit {
  fn go(x : @ast.Instr[@basic.Location]) -> Unit {
    lint_source(ctx, x)
  }

  fn list(l : Array[@ast.Instr[@basic.Location]]) -> Unit {
    for x in l {
      go(x)
    }
  }

  match i.desc {
    If(cond~, if_block~, else_block~, ..) => {
      lint_condition(ctx, cond)
      go(cond)
      list(if_block.desc)
      if else_block is Some(b) {
        list(b.desc)
      }
    }
    While(cond~, step~, block~, ..) => {
      lint_condition(ctx, cond, is_while=true)
      go(cond)
      if step is Some(s) {
        go(s)
      }
      list(block.desc)
    }
    BrIf(_, c) => {
      // A `br_if` carrying a value has `Sequence [values..; cond]`, so the
      // condition is the last element; a bare one's operand IS the condition.
      let cond = match c.desc {
        Sequence(seq) => if seq.is_empty() { c } else { seq[seq.length() - 1] }
        _ => c
      }
      lint_condition(ctx, cond)
      go(c)
    }
    Let(bindings, body) => {
      // A drop `_ = e` is a single anonymous binding; if `e` is effect-free,
      // computing it only to discard the result is pointless.
      if bindings.length() == 1 &&
        bindings[0].0 is None &&
        body is Some(e) &&
        is_effectless(e) {
        unused_result(ctx.diagnostics, e.info)
      }
      if body is Some(e) {
        go(e)
      }
    }
    Set(idx, op, e) => {
      // A plain self-assignment `x = x` does nothing. A compound `x op= x` is
      // not redundant -- `x += x` doubles it.
      if op is None && e.desc is Get(other) && other.name == idx.name {
        redundant_operation(
          ctx.diagnostics,
          i.info,
          @message.text("This assignment writes the variable back to itself."),
        )
      }
      go(e)
    }
    Select(c, t, e) => {
      lint_condition(ctx, c)
      go(c)
      go(t)
      go(e)
    }
    Block(block~, ..) | Loop(block~, ..) | TryTable(block~, ..) =>
      list(block.desc)
    Try(block~, catches~, catch_all~, ..) => {
      list(block.desc)
      for c in catches {
        list(c.1.desc)
      }
      if catch_all is Some(b) {
        list(b.desc)
      }
    }
    TryCatch(block~, arms~, ..) => {
      list(block.desc)
      for a in arms {
        list(a.arm_body.desc)
      }
    }
    Call(t, args) | TailCall(t, args) => {
      go(t)
      list(args)
    }
    Dispatch(index~, arms~, ..) => {
      go(index)
      for a in arms {
        list(a.1.desc)
      }
    }
    Match(scrutinee~, arms~, default~) => {
      go(scrutinee)
      for a in arms {
        list(a.1.desc)
      }
      list(default.desc)
    }
    IfAnnotation(then_body~, else_body~, ..) => {
      list(then_body.desc)
      if else_body is Some(b) {
        list(b.desc)
      }
    }
    Struct(_, fields) =>
      for f in fields {
        if f.1 is Some(v) {
          go(v)
        }
      }
    StructDesc(d, fields) => {
      go(d)
      for f in fields {
        if f.1 is Some(v) {
          go(v)
        }
      }
    }
    Br(_, o) | Return(o) => if o is Some(e) { go(e) }
    // Everything else is a plain recursion into whatever it contains. NOT
    // `iter_instr`, which visits the node itself first and would recurse
    // forever here.
    _ =>
      for sub in i.sub_instrs() {
        go(sub)
      }
  }
}
