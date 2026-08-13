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
    BinOpI(op, e1, e2) => {
      lint_precedence(ctx, op, e1, e2)
      go(e1)
      go(e2)
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
      // Both branches run, so a hazard in either is reported -- against the
      // `?:` itself, which is what makes it happen.
      for arm in [t, e] {
        if find_eager_hazard(arm) is Some(loc) {
          eager_select(ctx.diagnostics, loc, i.info)
        }
      }
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

///|
/// The first operation in `e` that traps or has an effect, if any.
///
/// A `?:` compiles to a wasm `select`, which evaluates both operands before
/// choosing -- so anything here runs whichever way the condition goes. Pure
/// operators are descended into, because their operands run too; a nested
/// CONTROL construct guards its own sub-expressions, so the walk stops there.
pub fn find_eager_hazard(e : @ast.Instr[@basic.Location]) -> @basic.Location? {
  fn descend(l : Array[@ast.Instr[@basic.Location]]) -> @basic.Location? {
    for x in l {
      if find_eager_hazard(x) is Some(loc) {
        return Some(loc)
      }
    }
    None
  }

  fn field_values(
    fields : Array[(@ast.Ident, @ast.Instr[@basic.Location]?)],
  ) -> Array[@ast.Instr[@basic.Location]] {
    let out : Array[@ast.Instr[@basic.Location]] = []
    for f in fields {
      if f.1 is Some(v) {
        out.push(v)
      }
    }
    out
  }

  match e.desc {
    // Trapping or effectful operations: the operation itself is the hazard.
    ArrayGet(_, _)
    | ArraySet(_, _, _)
    | StructGet(_, _)
    | StructSet(_, _, _)
    | GetDescriptor(_)
    | NonNull(_)
    | CastDesc(_, _, _)
    | ArraySegment(_, _, _, _)
    | Unreachable
    | Call(_, _)
    | TailCall(_, _)
    | Set(_, _, _)
    | Tee(_, _)
    | Throw(_, _)
    | ThrowRef(_)
    | ContNew(_, _)
    | ContBind(_, _, _)
    | Suspend(_, _)
    | Resume(_, _, _)
    | ResumeThrow(_, _, _, _)
    | ResumeThrowRef(_, _, _)
    | Switch(_, _, _) => Some(e.info)
    // Division and remainder trap on a zero divisor; the other operators do
    // not, so their operands are what to look at.
    BinOpI(op, a, b) =>
      if op.desc is (Div(Some(_)) | Rem(_)) {
        Some(e.info)
      } else {
        descend([a, b])
      }
    UnOpI(_, a)
    | Cast(a, _)
    | Test(a, _)
    | Labelled(_, a)
    | ArrayDefault(_, a)
    | StructDefaultDesc(a)
    // An `on` clause only ever wraps a resume-family call -- itself a hazard --
    // so descend into it rather than treating it as a control construct.
    | On(a, _) => find_eager_hazard(a)
    Array(_, a, b) => descend([a, b])
    ArrayFixed(_, l) | Sequence(l) => descend(l)
    Struct(_, fields) => descend(field_values(fields))
    StructDesc(d, fields) =>
      match find_eager_hazard(d) {
        Some(loc) => Some(loc)
        None => descend(field_values(fields))
      }
    Let(_, init) =>
      match init {
        Some(x) => find_eager_hazard(x)
        None => None
      }
    // Constants, reads and default allocations never trap; a nested control
    // construct guards its own sub-expressions, so the walk stops at both.
    _ => None
  }
}

///|
/// Every label a function body declares.
///
/// Collected once, up front, because the unused-label lint needs the set of
/// DECLARATIONS and the checker only ever sees them one scope at a time. Only
/// the block-like forms carry a label; the function's own is not among them,
/// since it is bound by the frame rather than declared in the body.
pub fn collect_labels(
  instrs : Array[@ast.Instr[@basic.Location]],
) -> Array[@ast.Ident] {
  let out : Array[@ast.Ident] = []
  fn go(i : @ast.Instr[@basic.Location]) -> Unit {
    let label = match i.desc {
      Block(label~, ..)
      | Loop(label~, ..)
      | While(label~, ..)
      | If(label~, ..)
      | TryTable(label~, ..)
      | Try(label~, ..)
      | TryCatch(label~, ..) => label
      _ => None
    }
    if label is Some(l) {
      out.push(l)
    }
    for sub in i.sub_instrs() {
      go(sub)
    }
  }

  for s in instrs {
    go(s)
  }
  out
}

///|
/// A shift count parsed UNSIGNED.
///
/// A hex literal past 2^63 wraps to a negative `Int64` under a signed parse, so
/// the count is read unsigned and compared that way. The sign folds exactly as
/// the code generator folds it, for the same reason as `int_operand_value`.
fn shift_count(e : @ast.Instr[@basic.Location]) -> Int64? {
  fn of_int(s : String) -> Int64? {
    let bits = s.split("_").join("")
    Some(@string.parse_uint64(bits).reinterpret_as_int64()) catch {
      _ => None
    }
  }

  match e.desc {
    Int(s) => of_int(s)
    UnOpI(op, inner) =>
      match (op.desc, inner.desc) {
        (Neg, Int(s)) => of_int(s).map(v => -v)
        (Pos, _) => shift_count(inner)
        _ => None
      }
    _ => None
  }
}

///|
/// Report a shift whose constant count is at least the operand's width.
///
/// DEFERRED until typing finishes: the width comes from the result cell, and a
/// later context can still widen it -- `1 << 40` typed `i64` is fine, typed
/// `i32` is not. Only a genuinely unconstrained operand falls back to a default.
pub fn lint_shift(
  ctx : @typing_env.ModuleContext,
  op : @basic.Annotated[@ast.BinOp, @basic.Location],
  result : @infer.Cell[@infer.InferredType],
  rhs : @ast.Instr[@basic.Location],
) -> Unit {
  guard op.desc is (Shl | Shr(_)) else { return }
  let width = match result.get() {
    Valtype({ internal: I32, .. }) | Number | Int => Some(32)
    Valtype({ internal: I64, .. }) | LargeInt => Some(64)
    _ => None
  }
  guard width is Some(width) else { return }
  guard shift_count(rhs) is Some(n) else { return }
  if n.reinterpret_as_uint64() >= width.to_uint64() {
    shift_overflow(ctx.diagnostics, op.info, width, n)
  }
}

///|
/// Report an integer division or remainder by a constant zero.
///
/// `Div(None)` is float division, which does not trap on a zero divisor.
pub fn lint_division(
  ctx : @typing_env.ModuleContext,
  op : @basic.Annotated[@ast.BinOp, @basic.Location],
  rhs : @ast.Instr[@basic.Location],
) -> Unit {
  guard op.desc is (Div(Some(_)) | Rem(_)) else { return }
  if int_operand_value(rhs) is Some(0) {
    division_by_zero(ctx.diagnostics, op.info)
  }
}

///|
/// Run and clear the lints that were waiting for their result cells to settle.
pub fn flush_deferred_lints(ctx : @typing_env.ModuleContext) -> Unit {
  for f in ctx.deferred_lints {
    f()
  }
  ctx.deferred_lints.clear()
}

///|
/// The next significant character at or after `i`, skipping trivia.
///
/// Whitespace and comments -- line and NESTING block -- because a comment
/// between an operand and its bracket would otherwise hide the parenthesis and
/// make the lint fire on code that reads perfectly well.
fn skip_trivia(src : String, start : Int) -> Int {
  let n = src.length()
  let mut i = start
  while i < n {
    let c = src[i]
    if c == 32 || c == 9 || c == 10 || c == 13 {
      i = i + 1
    } else if i + 1 < n && c == 47 && src[i + 1] == 47 {
      // A line comment, to the newline.
      while i < n && src[i] != 10 {
        i = i + 1
      }
    } else if i + 1 < n && c == 47 && src[i + 1] == 42 {
      let mut depth = 1
      let mut j = i + 2
      while j + 1 < n && depth > 0 {
        if src[j] == 47 && src[j + 1] == 42 {
          depth = depth + 1
          j = j + 2
        } else if src[j] == 42 && src[j + 1] == 47 {
          depth = depth - 1
          j = j + 2
        } else {
          j = j + 1
        }
      }
      i = if depth > 0 { n } else { j }
    } else {
      return i
    }
  }
  i
}

///|
/// Whether an operand was WRITTEN parenthesized.
///
/// The grammar erases parentheses -- `1 << (n - 1)` and `1 << n - 1` parse to
/// the same tree -- so this can only be answered from the source text. Both
/// sides are found by scanning FORWARD, since a parenthesized operand always has
/// a bracket downstream: the right operand's `(` follows the operator, the left
/// operand's `)` follows the operand.
///
/// With no source, assume it was: the lint then stays quiet rather than risking
/// a false positive on text it cannot see.
fn operand_parenthesized(
  ctx : @typing_env.ModuleContext,
  op : @basic.Annotated[@ast.BinOp, @basic.Location],
  child : @ast.Instr[@basic.Location],
  right~ : Bool,
) -> Bool {
  guard ctx.diagnostics.source is Some(src) else { return true }
  let from = skip_trivia(
    src,
    if right {
      op.info.end.cnum
    } else {
      child.info.end.cnum
    },
  )
  guard from < src.length() else { return false }
  src[from] == (if right { 40 } else { 41 })
}

///|
/// The name of a binary operator's precedence class, for the message.
fn binop_kind_name(k : @output.BinopKind) -> String {
  match k {
    Shift => "shift"
    Arith => "arithmetic"
    Bitwise => "bitwise"
    Comparison => "comparison"
  }
}

///|
/// Report a binary operator whose operand is a tighter-binding operator of a
/// confusingly-related class, written without disambiguating parentheses.
///
/// The classification is the PRINTER's -- it parenthesises exactly these mixes,
/// so re-printed or decompiled Wax stays quiet under the lint. Sharing the table
/// is what makes that true rather than merely likely.
fn lint_precedence(
  ctx : @typing_env.ModuleContext,
  op : @basic.Annotated[@ast.BinOp, @basic.Location],
  e1 : @ast.Instr[@basic.Location],
  e2 : @ast.Instr[@basic.Location],
) -> Unit {
  let outer = @output.binop_kind(op.desc)
  for side in [(e1, false), (e2, true)] {
    let (child, right) = side
    guard child.desc is BinOpI(inner_op, _, _) else { continue }
    let inner = @output.binop_kind(inner_op.desc)
    guard @output.confusing_precedence(outer, inner) else { continue }
    guard !operand_parenthesized(ctx, op, child, right~) else { continue }
    // The fix parenthesises the tighter-binding sub-expression the lint names.
    // An edit is one contiguous replacement, so it replaces that span with its
    // own source slice wrapped in brackets.
    let edit = match ctx.diagnostics.source {
      Some(src) => {
        let s = child.info.start.cnum
        let e = child.info.end.cnum
        if 0 <= s && s <= e && e <= src.length() {
          Some(
            (
              { loc: child.info, new_text: "(" + src[s:e].to_owned() + ")" } :
              @diagnostic.Edit),
          )
        } else {
          None
        }
      }
      None => None
    }
    precedence(
      ctx.diagnostics,
      op.info,
      inner_op.info,
      binop_kind_name(outer),
      binop_kind_name(inner),
      edit~,
    )
  }
}
