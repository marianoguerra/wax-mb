// The instruction dispatcher.
//
// Ported from `instruction` / `toplevel_instruction` in
// wax/src/lib-wax/typing.ml.
//
// This is where everything the last several files built gets used: the operand
// stack, the name tables, block inference, the branch frames. One arm per AST
// constructor, and there are seventy-one of them.
//
// It is being built incrementally, and the match is TOTAL from the start. An
// arm that is not written yet does not fall through silently -- it recurses
// into its children, so they are still annotated, and TALLIES itself under its
// constructor name. `Checker::unported` is that tally, and it is the burn-down
// number for the rest of this stage. A silent fallback here would be the same
// mistake as the vendored encoder's `_ => 0x00`, which hid 256 instructions
// until it was removed.

///|
/// One run of the checker over one function body.
pub struct Checker {
  ctx : @typing_env.ModuleContext
  ops : Operands
  /// Constructors reached that have no arm yet, and how often. Empty when the
  /// dispatcher is complete.
  unported : Map[String, Int]
}

///|
pub fn Checker::new(ctx : @typing_env.ModuleContext, ops : Operands) -> Checker {
  { ctx, ops, unported: Map([]) }
}

///|
/// Note that a constructor has no arm yet.
fn Checker::tally(self : Checker, name : String) -> Unit {
  self.unported[name] = self.unported.get(name).unwrap_or(0) + 1
}

///|
/// The unported constructors, most frequent first, for a report.
pub fn Checker::gaps(self : Checker) -> Array[(String, Int)] {
  let out : Array[(String, Int)] = []
  for name, count in self.unported {
    out.push((name, count))
  }
  out.sort_by((a, b) => {
    if a.1 != b.1 {
      b.1 - a.1
    } else if a.0 < b.0 {
      -1
    } else {
      1
    }
  })
  out
}

///|
/// The annotation an instruction carries once checked: the values it leaves on
/// the stack, and its span.
fn annotate(
  types : Array[@infer.Cell[@infer.InferredType]],
  location : @basic.Location,
) -> @typing_env.InferredAnnotation {
  (types, location)
}

///|
/// Check one instruction in STATEMENT position, returning the typed node.
///
/// Statement position is the general case: the instruction may leave any number
/// of values, including none. Expression position is the special one, and goes
/// through `expression_type` to insist on exactly one.
pub fn Checker::statement(
  self : Checker,
  i : @ast.Instr[@basic.Location],
) -> @ast.Instr[@typing_env.InferredAnnotation] {
  let loc = i.info
  let ctx = self.ctx
  match i.desc {
    // --- Values that need nothing but their own token ---
    Int(_) | Float(_) | Char(_) | Null => {
      let ty = @infer.Cell::make(literal_type(i.desc).unwrap())
      self.ops.push(Some(loc), ty)
      self.rebuild(i, [ty])
    }

    // --- Statements that leave nothing ---
    Nop => self.rebuild(i, [])
    Unreachable => {
      // Everything after this is dead code, and the polymorphic stack is how
      // the rest of the checker knows it.
      self.ops.set_unreachable()
      self.rebuild(i, [])
    }

    // --- Reading a variable ---
    Get(idx) => {
      let ty = type_get(ctx, idx)
      self.ops.push(Some(loc), ty)
      self.rebuild(i, [ty])
    }

    // --- A hole: a value the surrounding call will supply ---
    Hole => {
      let batch : Ref[MissingBatch?] = @ref.new(None)
      let ty = self.ops.pop_any(batch, 0, 1)
      report_missing_hole(self.ops, ctx.diagnostics, loc, ty)
      self.ops.push(Some(loc), ty)
      self.rebuild(i, [ty])
    }

    // --- A qualified intrinsic name outside a call ---
    Path(ns, name) => {
      intrinsic_not_called(ctx.diagnostics, loc, ns.name, name.name)
      let ty = @infer.Cell::make(@infer.InferredType::Error)
      self.ops.push(Some(loc), ty)
      self.rebuild(i, [ty])
    }

    // --- A labelled argument anywhere but a memory access ---
    Labelled(_, e) => {
      labelled_argument_not_allowed(ctx.diagnostics, loc)
      // Recover by checking the payload in place, so one misplaced label does
      // not lose the expression it labelled.
      let e_ = self.statement(e)
      self.rebuild_labelled(i, e_)
    }

    // --- A plain sequence: each in turn, the last one's values are the
    // sequence's ---
    Sequence(l) => {
      let checked : Array[@ast.Instr[@typing_env.InferredAnnotation]] = []
      let mut types : Array[@infer.Cell[@infer.InferredType]] = []
      for s in l {
        let c = self.statement(s)
        types = c.info.0
        checked.push(c)
      }
      {
        desc: Sequence(checked),
        info: annotate(types, loc),
        hints: i.hints,
        expected: i.expected,
      }
    }

    // --- Everything else: not written yet ---
    _ => {
      self.tally(constructor_name(i.desc))
      self.placeholder(i)
    }
  }
}

///|
/// Rebuild a leaf node with its annotation.
fn Checker::rebuild(
  self : Checker,
  i : @ast.Instr[@basic.Location],
  types : Array[@infer.Cell[@infer.InferredType]],
) -> @ast.Instr[@typing_env.InferredAnnotation] {
  ignore(self)
  {
    desc: i.desc.map_desc(
      instr=_ => abort("a leaf node has no sub-instructions"),
      block=_ => abort("a leaf node has no blocks"),
    ),
    info: annotate(types, i.info),
    hints: i.hints,
    expected: i.expected,
  }
}

///|
/// Rebuild a `Labelled` around an already-checked payload.
fn Checker::rebuild_labelled(
  self : Checker,
  i : @ast.Instr[@basic.Location],
  payload : @ast.Instr[@typing_env.InferredAnnotation],
) -> @ast.Instr[@typing_env.InferredAnnotation] {
  ignore(self)
  guard i.desc is Labelled(l, _) else {
    abort("rebuild_labelled on something else")
  }
  {
    desc: Labelled(l, payload),
    info: annotate(payload.info.0, i.info),
    hints: i.hints,
    expected: i.expected,
  }
}

///|
/// An arm with no implementation yet: annotate the children, and leave this
/// node's own values unknown.
///
/// The children are still walked, so a missing arm costs the annotations of the
/// node itself and nothing below it. What it does NOT do is guess: an empty
/// annotation says "this produced nothing we know of", which is what it is.
fn Checker::placeholder(
  self : Checker,
  i : @ast.Instr[@basic.Location],
) -> @ast.Instr[@typing_env.InferredAnnotation] {
  {
    desc: i.desc.map_desc(instr=s => self.statement(s), block=b => {
      b.map(s => self.statement(s))
    }),
    info: annotate([], i.info),
    hints: i.hints,
    expected: i.expected,
  }
}

///|
/// The constructor's name, for the burn-down tally.
///
/// Spelled out rather than derived, because the tally is read by a human
/// deciding what to write next and the AST's own debug rendering would carry
/// the whole subtree with it.
pub fn constructor_name(d : @ast.InstrDesc[@basic.Location]) -> String {
  match d {
    Block(..) => "Block"
    Loop(..) => "Loop"
    While(..) => "While"
    If(..) => "If"
    TryTable(..) => "TryTable"
    Try(..) => "Try"
    TryCatch(..) => "TryCatch"
    Unreachable => "Unreachable"
    Nop => "Nop"
    Hole => "Hole"
    Null => "Null"
    Get(_) => "Get"
    Path(_, _) => "Path"
    Set(_, _, _) => "Set"
    Tee(_, _) => "Tee"
    Call(_, _) => "Call"
    TailCall(_, _) => "TailCall"
    Labelled(_, _) => "Labelled"
    Char(_) => "Char"
    Str(_, _) => "Str"
    Int(_) => "Int"
    Float(_) => "Float"
    Cast(_, _) => "Cast"
    CastDesc(_, _, _) => "CastDesc"
    Test(_, _) => "Test"
    NonNull(_) => "NonNull"
    Struct(_, _) => "Struct"
    StructDefault(_) => "StructDefault"
    StructDesc(_, _) => "StructDesc"
    StructDefaultDesc(_) => "StructDefaultDesc"
    StructGet(_, _) => "StructGet"
    GetDescriptor(_) => "GetDescriptor"
    StructSet(_, _, _) => "StructSet"
    Array(_, _, _) => "Array"
    ArrayDefault(_, _) => "ArrayDefault"
    ArrayFixed(_, _) => "ArrayFixed"
    ArraySegment(_, _, _, _) => "ArraySegment"
    ArrayGet(_, _) => "ArrayGet"
    ArraySet(_, _, _) => "ArraySet"
    BinOpI(_, _, _) => "BinOp"
    UnOpI(_, _) => "UnOp"
    Let(_, _) => "Let"
    Br(_, _) => "Br"
    BrIf(_, _) => "BrIf"
    BrTable(_, _) => "BrTable"
    Dispatch(..) => "Dispatch"
    Match(..) => "Match"
    BrOnNull(_, _) => "BrOnNull"
    BrOnNonNull(_, _) => "BrOnNonNull"
    BrOnCast(_, _, _) => "BrOnCast"
    BrOnCastFail(_, _, _) => "BrOnCastFail"
    BrOnCastDescEq(_, _, _, _) => "BrOnCastDescEq"
    BrOnCastDescEqFail(_, _, _, _) => "BrOnCastDescEqFail"
    Throw(_, _) => "Throw"
    ThrowRef(_) => "ThrowRef"
    ContNew(_, _) => "ContNew"
    ContBind(_, _, _) => "ContBind"
    Suspend(_, _) => "Suspend"
    Resume(_, _, _) => "Resume"
    ResumeThrow(_, _, _, _) => "ResumeThrow"
    ResumeThrowRef(_, _, _) => "ResumeThrowRef"
    Switch(_, _, _) => "Switch"
    On(_, _) => "On"
    Return(_) => "Return"
    Sequence(_) => "Sequence"
    Select(_, _, _) => "Select"
    IfAnnotation(..) => "IfAnnotation"
  }
}
