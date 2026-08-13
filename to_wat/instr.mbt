// Instruction mnemonics.
//
// A first slice: the instructions the corpus's simplest modules are made of.
// Anything not here reports rather than guessing a name -- the same discipline
// the lowering uses, so a gap is a gap and not a plausible wrong answer.

///|
pub suberror WatError {
  /// An instruction with no spelling here yet, named so the gap is legible.
  NotPrinted(String)
}

///|
pub impl Show for WatError with fn output(self, logger) {
  let NotPrinted(what) = self
  logger.write_string(what + " has no text form yet")
}

///|
/// The constructor name of an instruction, for the gap report: the debug
/// rendering up to its first immediate.
fn constructor_of(i : @wasm_bin.Instruction) -> String {
  let s = @debug.to_string(i)
  match s.find("(") {
    Some(k) => s[:k].to_owned()
    None => s
  }
}

///|
/// `br_on_cast $l (ref null $a) (ref $b)`: the type it came from, then the type
/// it is going to.
fn cast_branch(
  name : String,
  l : Int,
  a : @wasm_bin.RefType,
  b : @wasm_bin.RefType,
  names : @wasm_bin.Names,
  scope : Array[String?],
) -> String {
  name +
  " " +
  label(scope, l) +
  " " +
  reftype(a, names.types) +
  " " +
  reftype(b, names.types)
}

///|
/// A resume's handler table: `(on $tag $label)` for each tag it handles, or
/// `(on $tag switch)` for the one it switches to.
fn on_clauses(
  on : Array[@wasm_bin.OnClause],
  names : @wasm_bin.Names,
  scope : Array[String?],
) -> String {
  let out = StringBuilder::new()
  for c in on {
    match c {
      OnLabel(tag, l) =>
        out.write_string(
          " (on " + name_or(names.tags, tag) + " " + label(scope, l) + ")",
        )
      OnSwitch(tag) =>
        out.write_string(" (on " + name_or(names.tags, tag) + " switch)")
    }
  }
  out.to_string()
}

///|
/// A struct field's name, under the type that declared it.
fn field_name(names : @wasm_bin.Names, t : Int, f : Int) -> String {
  match names.fields.get(t) {
    Some(fs) => name_or(fs, f)
    None => f.to_string()
  }
}

///|
/// The two indices a copy takes, written only when they are not both the
/// unnamed default -- there is no way to write the second without the first.
fn index_pair(names : Map[Int, Bytes], a : Int, b : Int) -> String {
  if a == 0 && b == 0 && !names.contains(0) {
    ""
  } else {
    " " + name_or(names, a) + " " + name_or(names, b)
  }
}

///|
/// The label a branch depth names: the enclosing blocks are counted outward
/// from the innermost, so a depth is a distance from the END of the scope.
fn label(scope : Array[String?], depth : Int) -> String {
  let k = scope.length() - 1 - depth
  if k >= 0 && k < scope.length() && scope[k] is Some(name) {
    name
  } else {
    depth.to_string()
  }
}

///|
/// The mnemonic and immediates of one instruction, without its operands.
pub fn mnemonic(
  i : @wasm_bin.Instruction,
  names : @wasm_bin.Names,
  locals : Map[Int, Bytes],
  scope? : Array[String?] = [],
) -> Sexp raise WatError {
  Atom(mnemonic_text(i, names, locals, scope~))
}

///|
/// The same, as one string. The immediates are not separate atoms yet, so an
/// instruction breaks as a unit -- which is where the layout still differs from
/// the reference for the few whose immediate lists are long.
fn mnemonic_text(
  i : @wasm_bin.Instruction,
  names : @wasm_bin.Names,
  locals : Map[Int, Bytes],
  scope? : Array[String?] = [],
) -> String raise WatError {
  // Everything with no immediate follows one rule and lives in its own table;
  // what is left here is the instructions whose immediates have to be written.
  if nullary(i) is Some(name) {
    return name
  }
  if memarg_instr(i, names) is Some(name) {
    return name
  }
  match i {
    I32Const(v) => "i32.const " + v.to_string()
    I64Const(v) => "i64.const " + v.to_string()
    // A local is named where the function named it, which is per FUNCTION --
    // unlike every other index space, whose names are the module's.
    LocalGet(k) => "local.get " + name_or(locals, k)
    LocalSet(k) => "local.set " + name_or(locals, k)
    LocalTee(k) => "local.tee " + name_or(locals, k)
    GlobalGet(k) => "global.get " + name_or(names.globals, k)
    GlobalSet(k) => "global.set " + name_or(names.globals, k)
    Call(k) => "call " + name_or(names.functions, k)
    ReturnCall(k) => "return_call " + name_or(names.functions, k)
    RefFunc(k) => "ref.func " + name_or(names.functions, k)
    Br(d) => "br " + label(scope, d)
    BrIf(d) => "br_if " + label(scope, d)
    // The table is left out when it is the unnamed default, the same rule the
    // memory accesses follow; the signature is always named, because an
    // indirect call is checked against it at run time.
    CallIndirect(t, tab) =>
      "call_indirect" +
      opt_index(names.tables, tab) +
      " (type " +
      name_or(names.types, t) +
      ")"
    ReturnCallIndirect(t, tab) =>
      "return_call_indirect" +
      opt_index(names.tables, tab) +
      " (type " +
      name_or(names.types, t) +
      ")"
    CallRef(t) => "call_ref " + name_or(names.types, t)
    ReturnCallRef(t) => "return_call_ref " + name_or(names.types, t)
    RefNull(h) => "ref.null " + heaptype(h, names.types)
    F32Const(v) => "f32.const " + v.to_double().to_string()
    F64Const(v) => "f64.const " + v.to_string()
    StructNew(t) => "struct.new " + name_or(names.types, t)
    StructNewDefault(t) => "struct.new_default " + name_or(names.types, t)
    ArrayNew(t) => "array.new " + name_or(names.types, t)
    ArrayNewDefault(t) => "array.new_default " + name_or(names.types, t)
    ArrayNewFixed(t, n) =>
      "array.new_fixed " + name_or(names.types, t) + " " + n.to_string()
    RefTest(r) => "ref.test " + reftype(r, names.types)
    RefCast(r) => "ref.cast " + reftype(r, names.types)
    Throw(t) => "throw " + name_or(names.tags, t)
    // Tables and memories: the index is left out when it is the unnamed
    // default, which is what makes `(i32.load (local.get $i))` the usual
    // spelling rather than `(i32.load 0 ...)`.
    TableGet(t) => "table.get" + opt_index(names.tables, t)
    TableSet(t) => "table.set" + opt_index(names.tables, t)
    TableSize(t) => "table.size" + opt_index(names.tables, t)
    TableGrow(t) => "table.grow" + opt_index(names.tables, t)
    TableFill(t) => "table.fill" + opt_index(names.tables, t)
    // Two indices, and the pair is left out only when BOTH are the default --
    // `table.copy 0 2` needs the source, and there is no way to write the
    // second without the first.
    TableCopy(d, s) => "table.copy" + index_pair(names.tables, d, s)
    TableInit(t, e) =>
      "table.init" + opt_index(names.tables, t) + " " + name_or(names.elem, e)
    ElemDrop(e) => "elem.drop " + name_or(names.elem, e)
    MemorySize(m) => "memory.size" + memidx(names, m)
    MemoryGrow(m) => "memory.grow" + memidx(names, m)
    MemoryFill(m) => "memory.fill" + memidx(names, m)
    MemoryCopy(d, s) => "memory.copy" + index_pair(names.memories, d, s)
    MemoryInit(m, d) =>
      "memory.init" + memidx(names, m) + " " + name_or(names.data, d)
    DataDrop(d) => "data.drop " + name_or(names.data, d)

    // A struct field is named where its TYPE named it, so the field name is
    // looked up under the type the access goes through -- not under the
    // instruction, which has no namespace of its own.
    StructGet(t, f) =>
      "struct.get " + name_or(names.types, t) + " " + field_name(names, t, f)
    StructGetS(t, f) =>
      "struct.get_s " + name_or(names.types, t) + " " + field_name(names, t, f)
    StructGetU(t, f) =>
      "struct.get_u " + name_or(names.types, t) + " " + field_name(names, t, f)
    StructSet(t, f) =>
      "struct.set " + name_or(names.types, t) + " " + field_name(names, t, f)
    StructNewDesc(t) => "struct.new_desc " + name_or(names.types, t)
    StructNewDefaultDesc(t) =>
      "struct.new_default_desc " + name_or(names.types, t)
    RefGetDesc(t) => "ref.get_desc " + name_or(names.types, t)
    ArrayGet(t) => "array.get " + name_or(names.types, t)
    ArrayGetS(t) => "array.get_s " + name_or(names.types, t)
    ArrayGetU(t) => "array.get_u " + name_or(names.types, t)
    ArraySet(t) => "array.set " + name_or(names.types, t)
    ArrayFill(t) => "array.fill " + name_or(names.types, t)
    ArrayCopy(d, s) =>
      "array.copy " + name_or(names.types, d) + " " + name_or(names.types, s)
    ArrayNewData(t, d) =>
      "array.new_data " + name_or(names.types, t) + " " + name_or(names.data, d)
    ArrayNewElem(t, e) =>
      "array.new_elem " + name_or(names.types, t) + " " + name_or(names.elem, e)
    ArrayInitData(t, d) =>
      "array.init_data " +
      name_or(names.types, t) +
      " " +
      name_or(names.data, d)
    ArrayInitElem(t, e) =>
      "array.init_elem " +
      name_or(names.types, t) +
      " " +
      name_or(names.elem, e)

    // A branch table names every arm and then the default, which is written
    // last and no differently -- the position is what makes it the default.
    BrTable(ls, d) => {
      let out = StringBuilder::new()
      out.write_string("br_table")
      for l in ls {
        out.write_string(" " + label(scope, l))
      }
      out.write_string(" " + label(scope, d))
      out.to_string()
    }
    BrOnNull(l) => "br_on_null " + label(scope, l)
    BrOnNonNull(l) => "br_on_non_null " + label(scope, l)
    BrOnCast(l, a, b) => cast_branch("br_on_cast", l, a, b, names, scope)
    BrOnCastFail(l, a, b) =>
      cast_branch("br_on_cast_fail", l, a, b, names, scope)
    BrOnCastDescEq(l, a, b) =>
      cast_branch("br_on_cast_desc_eq", l, a, b, names, scope)
    BrOnCastDescEqFail(l, a, b) =>
      cast_branch("br_on_cast_desc_eq_fail", l, a, b, names, scope)
    RefCastDescEq(r) => "ref.cast_desc_eq " + reftype(r, names.types)

    // Stack switching. A continuation names the type it runs at, and a resume
    // carries the handler table as immediates rather than as nested code.
    ContNew(t) => "cont.new " + name_or(names.types, t)
    ContBind(a, b) =>
      "cont.bind " + name_or(names.types, a) + " " + name_or(names.types, b)
    Suspend(t) => "suspend " + name_or(names.tags, t)
    Resume(t, on) =>
      "resume " + name_or(names.types, t) + on_clauses(on, names, scope)
    ResumeThrow(t, tag, on) =>
      "resume_throw " +
      name_or(names.types, t) +
      " " +
      name_or(names.tags, tag) +
      on_clauses(on, names, scope)
    ResumeThrowRef(t, on) =>
      "resume_throw_ref " +
      name_or(names.types, t) +
      on_clauses(on, names, scope)
    Switch(t, tag) =>
      "switch " + name_or(names.types, t) + " " + name_or(names.tags, tag)

    // `select` with an explicit result type. Written with the type when the
    // operands are references, because then it cannot be inferred.
    SelectTyped(ts) => {
      let out = StringBuilder::new()
      out.write_string("select (result")
      for t in ts {
        out.write_string(" " + valtype(t, names.types))
      }
      out.write_string(")")
      out.to_string()
    }
    // The lane accessors: the shape says which lane width, the immediate says
    // which lane.
    I8x16ExtractLaneS(l) => "i8x16.extract_lane_s " + l.to_string()
    I8x16ExtractLaneU(l) => "i8x16.extract_lane_u " + l.to_string()
    I16x8ExtractLaneS(l) => "i16x8.extract_lane_s " + l.to_string()
    I16x8ExtractLaneU(l) => "i16x8.extract_lane_u " + l.to_string()
    I32x4ExtractLane(l) => "i32x4.extract_lane " + l.to_string()
    I64x2ExtractLane(l) => "i64x2.extract_lane " + l.to_string()
    F32x4ExtractLane(l) => "f32x4.extract_lane " + l.to_string()
    F64x2ExtractLane(l) => "f64x2.extract_lane " + l.to_string()
    I8x16ReplaceLane(l) => "i8x16.replace_lane " + l.to_string()
    I16x8ReplaceLane(l) => "i16x8.replace_lane " + l.to_string()
    I32x4ReplaceLane(l) => "i32x4.replace_lane " + l.to_string()
    I64x2ReplaceLane(l) => "i64x2.replace_lane " + l.to_string()
    F32x4ReplaceLane(l) => "f32x4.replace_lane " + l.to_string()
    F64x2ReplaceLane(l) => "f64x2.replace_lane " + l.to_string()
    I8x16Shuffle(lanes) => {
      let out = StringBuilder::new()
      out.write_string("i8x16.shuffle")
      for k in 0..<16 {
        out.write_string(" " + lanes[k].to_string())
      }
      out.to_string()
    }

    // An atomic access. The opcode is the operation, and the registry that
    // assigned it is also the one that knows its mnemonic and the alignment it
    // naturally has -- an atomic's alignment is not a hint, so writing the
    // wrong default would change what the instruction means.
    Atomic(code, mem, align, offset) => {
      guard @atomics.of_opcode(code) is Some(op) else {
        raise NotPrinted("an atomic with opcode " + code.to_string())
      }
      memarg(
        @atomics.name(op),
        mem,
        align,
        offset,
        @atomics.natural_align_log2(op),
        names,
      )
    }
    // Everything else is a gap, not a guess: reporting it keeps the burn-down
    // honest, exactly as the lowering's own gaps do -- and NAMING it is what
    // makes the remainder countable rather than one undifferentiated pile.
    _ => raise NotPrinted(constructor_of(i))
  }
}
