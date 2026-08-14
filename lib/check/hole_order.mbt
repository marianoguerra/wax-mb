// The hole-order check.
//
// Ported from wax/src/lib-wax/typing.ml.
//
// A hole `_` does not push a value: it NAMES one that is already on the stack
// when the expression runs. So a hole can only take what was there before the
// expression started -- once a sibling operand has pushed something, the value
// a later hole wants is buried under it, and wasm has no way to reach past the
// top of the stack to get it.
//
// The reference folds this into its expression monad, where the state carries
// the location of the first value-producing operand seen so far. We run it as a
// pass of its own over the finished tree, which is where the two ingredients it
// needs are both available: the operands in EMISSION order (a call's callee is
// emitted after its arguments, a struct's fields in DECLARED order, and the
// typed tree already records both), and the types, which decide whether a cast
// lowers to an instruction or to nothing at all.
//
// One report per statement. After the first, everything that follows is the
// same mistake seen again from further in.

///|
/// Reject a hole in the operand of a construct that lowers to blocks.
///
/// A `match` scrutinee, a `dispatch` index and a `while` condition are all
/// evaluated INSIDE the blocks their construct lowers to, and a block's stack
/// excludes the values pending in the enclosing sequence -- so a hole there has
/// nothing to take. A `while` condition could not take one even in principle:
/// it runs once per iteration, and the value would be gone after the first.
///
/// Rejected outright rather than left to underflow, and the operand replaced
/// with a hole-free value of the shape the construct wants, so the lowering
/// still type-checks and the reader gets one clear error instead of a cascade.
/// The flag says the operand was replaced, for a caller with a follow-up check
/// that the replacement would answer wrongly.
fn reject_control_holes(
  ctx : @typing_env.ModuleContext,
  construct : String,
  role : String,
  recovery : @ast.InstrDesc[@basic.Location],
  operand : @ast.Instr[@basic.Location],
) -> (@ast.Instr[@basic.Location], Bool) {
  if !contains_hole(operand) {
    return (operand, false)
  }
  hole_in_control_operand(ctx.diagnostics, operand.info, construct, role)
  ({ ..operand, desc: recovery }, true)
}

///|
/// The running state of one statement's hole-order walk.
///
/// `value_loc` is the first value-producing operand met in emission order, and
/// stays put once set: it is the value a later hole would have to reach under,
/// so it is where the reader is shown the conflict.
priv struct HoleOrder {
  ctx : @typing_env.ModuleContext
  mut value_loc : @basic.Location?
  mut reported : Bool
}

///|
/// Report a hole that would have to reach under a value already pushed.
///
/// A statement with no hole in it anywhere cannot fail this, which is worth the
/// early test: the walk is otherwise run over every statement of every body.
fn check_hole_order(
  ctx : @typing_env.ModuleContext,
  node : @ast.Instr[@typing_env.InferredAnnotation],
) -> Unit {
  if count_holes(node) == 0 {
    return
  }
  HoleOrder::{ ctx, value_loc: None, reported: false }.walk(node)
}

///|
/// Walk one distribution point's operands in emission order.
///
/// The order of the three steps is the whole check: an operand is tested
/// against what came BEFORE it, then descended into, and only then does it get
/// to claim `value_loc` -- so an operand never reports against itself.
fn HoleOrder::walk(
  self : HoleOrder,
  node : @ast.Instr[@typing_env.InferredAnnotation],
) -> Unit {
  // A compound assignment reads its target before evaluating its right-hand
  // side: `x op= e` is `x = x op e`, and the implicit `x` is pushed first. The
  // typed tree keeps the compound spelling, so that read exists only here --
  // and without it a hole in `e` would silently take the value BELOW the
  // receiver and compute `_ op x`.
  if node.desc is Set(idx, Some(_), _) && self.value_loc is None {
    self.value_loc = Some(idx.loc)
  }
  for child in operands(node) {
    if !self.reported && self.value_loc is Some(loc) && count_holes(child) > 0 {
      before_hole(self.ctx.diagnostics, loc)
      self.reported = true
    }
    self.walk(child)
    if self.value_loc is None && emits_value(child) {
      self.value_loc = Some(child.info.1)
    }
  }
}

///|
/// How many holes draw from THIS expression's incoming stack.
///
/// A block-like construct is a boundary: its body runs on a stack of its own,
/// so a hole inside it belongs to a statement in there and is counted by that
/// statement's own walk, not by this one.
fn count_holes(i : @ast.Instr[@typing_env.InferredAnnotation]) -> Int {
  if i.desc is Hole {
    return 1
  }
  let mut n = 0
  for c in operands(i) {
    n = n + count_holes(c)
  }
  n
}

///|
/// This instruction's operands, minus the ones that are not values.
///
/// An immediate carries no type, because nothing pushes it: a memory access's
/// `offset:`, the table a `t[i]` reads from, the method half of an intrinsic
/// receiver. They are part of the instruction rather than of the stack, so a
/// hole neither draws past them nor is buried by them.
fn operands(
  i : @ast.Instr[@typing_env.InferredAnnotation],
) -> Array[@ast.Instr[@typing_env.InferredAnnotation]] {
  let out = []
  for c in hole_operands(i) {
    if c.info.0.length() > 0 {
      out.push(c)
    }
  }
  out
}

///|
/// This instruction's operands, in the order wasm emits them.
///
/// Empty for the block-like constructs (the boundary above) and for everything
/// with no operands at all. The two orderings that are not the written one are
/// a call's callee, emitted after the arguments it is applied to, and a
/// `StructDesc`'s descriptor, emitted after the fields -- both typed first, for
/// their type, and both emitted last.
fn hole_operands(
  i : @ast.Instr[@typing_env.InferredAnnotation],
) -> Array[@ast.Instr[@typing_env.InferredAnnotation]] {
  match i.desc {
    // Value-less, operand-less, or a boundary.
    Block(..)
    | Loop(..)
    | While(..)
    | TryTable(..)
    | Try(..)
    | TryCatch(..)
    | Dispatch(..)
    | Match(..)
    | IfAnnotation(..)
    | Unreachable
    | Nop
    | Hole
    | Null
    | Get(_)
    | Path(_, _)
    | Char(_)
    | Str(_, _)
    | Int(_)
    | Float(_)
    | StructDefault(_)
    | Let(_, None)
    | Br(_, None)
    | Return(None) => []

    // One operand.
    If(cond~, ..) => [cond]
    Set(_, _, e)
    | Tee(_, e)
    | Labelled(_, e)
    | Cast(e, _)
    | Test(e, _)
    | NonNull(e)
    | StructDefaultDesc(e)
    | StructGet(e, _)
    | GetDescriptor(e)
    | ArrayDefault(_, e)
    | UnOpI(_, e)
    | Let(_, Some(e))
    | Br(_, Some(e))
    | BrIf(_, e)
    | BrTable(_, e)
    | BrOnNull(_, e)
    | BrOnNonNull(_, e)
    | BrOnCast(_, _, e)
    | BrOnCastFail(_, _, e)
    | ThrowRef(e)
    | ContNew(_, e)
    | On(e, _)
    | Return(Some(e)) => [e]

    // Two, in written order.
    CastDesc(a, _, b)
    | StructSet(a, _, b)
    | Array(_, a, b)
    | ArraySegment(_, _, a, b)
    | ArrayGet(a, b)
    | BinOpI(_, a, b)
    | BrOnCastDescEq(_, _, a, b)
    | BrOnCastDescEqFail(_, _, a, b) => [a, b]

    // Three, in written order.
    ArraySet(a, b, c) => [a, b, c]

    // `c ? a : b` pushes both arms and then the condition `select` tests.
    Select(c, a, b) => [a, b, c]

    // A list, in written order.
    ArrayFixed(_, l)
    | ContBind(_, _, l)
    | Suspend(_, l)
    | Resume(_, _, l)
    | ResumeThrow(_, _, _, l)
    | ResumeThrowRef(_, _, l)
    | Switch(_, _, l)
    | Throw(_, l)
    | Sequence(l) => l

    // A punned field carries no instruction of its own: it abbreviates a read
    // of the like-named variable, which holds no hole.
    Struct(_, fields) => {
      let out = []
      for f in fields {
        if f.1 is Some(v) {
          out.push(v)
        }
      }
      out
    }
    StructDesc(d, fields) => {
      let out = []
      for f in fields {
        if f.1 is Some(v) {
          out.push(v)
        }
      }
      out.push(d)
      out
    }
    // An intrinsic is written as a call but is not one: its callee names an
    // opcode rather than producing a function reference, so it carries no type.
    // What its parentheses hold is then a MIXTURE of stack operands and static
    // immediates -- a lane index, a vector constant's sixteen bytes -- in an
    // order the surface form does not show. Left unwalked rather than guessed
    // at: mistaking an immediate for a value is a report about code that is
    // fine, which is worse than missing one about code that is not.
    Call(f, args) | TailCall(f, args) =>
      if f.info.0.length() == 0 {
        []
      } else {
        let out = args.copy()
        out.push(f)
        out
      }
  }
}

///|
/// Whether this operand leaves a value on the stack for a later hole to have to
/// reach under.
///
/// A hole pushes nothing -- that is what it is. A cast that lowers to no
/// instruction pushes exactly what its operand does, so it is transparent here
/// as it is at run time. Everything else emits at least one value-producing
/// instruction.
fn emits_value(node : @ast.Instr[@typing_env.InferredAnnotation]) -> Bool {
  match node.desc {
    Hole => false
    Cast(inner, _) =>
      if cast_is_transparent(node, inner) {
        emits_value(inner)
      } else {
        true
      }
    _ => true
  }
}

///|
/// Whether a cast lowers to nothing at all.
///
/// Two cases, and only two: an operand with no value type -- unreachable or
/// failed code, where the cast emits nothing to begin with -- and a numeric
/// scalar cast to its own type. A width change is a real conversion
/// instruction, and a reference cast is a `ref.cast` even when it widens, so
/// both occupy the stack top and must be ordered like any other value.
fn cast_is_transparent(
  cast : @ast.Instr[@typing_env.InferredAnnotation],
  operand : @ast.Instr[@typing_env.InferredAnnotation],
) -> Bool {
  match sole_type(operand) {
    Unknown | Error => true
    Valtype(src) =>
      match src.internal {
        I32 | I64 | F32 | F64 =>
          match sole_type(cast) {
            Valtype(dst) => src.internal == dst.internal
            _ => false
          }
        _ => false
      }
    _ => false
  }
}

///|
/// The one value an instruction left, or `Error` when it left none or several.
///
/// Deliberately not `expression_type`: that one REPORTS a value-less
/// expression, and this pass asks about nodes whose consumers have already had
/// their say. `Error` is the answer that makes a cast transparent, which is the
/// quiet reading in both cases.
fn sole_type(
  node : @ast.Instr[@typing_env.InferredAnnotation],
) -> @infer.InferredType {
  let (types, _) = node.info
  if types.length() == 1 {
    types[0].get()
  } else {
    @infer.InferredType::Error
  }
}
