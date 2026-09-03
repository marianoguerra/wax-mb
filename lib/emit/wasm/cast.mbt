// Lowering a cast.
//
// Ported from the `Cast` case of wax/src/lib-conversion/to_wasm.ml.
//
// `e as t` is one syntax over three unrelated jobs, and which one it is depends
// entirely on the pair of types involved:
//
//   * between two numeric types it is a CONVERSION, and the instruction is a
//     table entry over (from, to) -- widen, narrow, or change family;
//   * between two reference types it is a `ref.cast`, which checks at run time
//     and traps;
//   * from a numeric type to the same numeric type it is nothing at all, which
//     is worth emitting nothing for rather than an identity instruction.
//
// The float-to-integer direction has two forms the syntax spells differently:
// `as i32_s` saturates and `as i32_s_strict` traps. They are different
// instructions, and picking the wrong one is a module that silently computes
// something else at the edges.

///|
/// The instruction a numeric conversion becomes, or `None` when the pair has no
/// conversion at all.
///
/// An identity pair yields `Some([])`: the cast is real in the source -- it
/// pins a width the checker used -- and nothing at all in the output.
fn numeric_cast(
  from : @wasm_types.ValType[Int],
  to : @wasm_types.ValType[Int],
) -> Array[@wasm_bin.Instruction]? {
  if from == to {
    return Some([])
  }
  match (from, to) {
    (I64, I32) => Some([I32WrapI64])
    // A widening integer cast is SIGNED: wax `as i64` on an i32 means the
    // value, and the unsigned form is written `as i64_u`, which reaches here as
    // a `Signed` cast rather than this one.
    (I32, I64) => Some([I64ExtendI32S])
    (F64, F32) => Some([F32DemoteF64])
    (F32, F64) => Some([F64PromoteF32])
    (I32, F32) => Some([F32ConvertI32S])
    (I32, F64) => Some([F64ConvertI32S])
    (I64, F32) => Some([F32ConvertI64S])
    (I64, F64) => Some([F64ConvertI64S])
    // Float to integer without a written signedness has no instruction: the
    // source has to say `as i32_s` or `as i32_u`, and the checker has said so.
    (F32, I32) | (F32, I64) | (F64, I32) | (F64, I64) => None
    _ => None
  }
}

///|
/// The instruction a `Signed` cast becomes: a float-to-integer conversion, or a
/// widening of an integer with the signedness written out.
///
/// `strict` is the trapping form; without it the saturating one. They differ
/// only at the edges, which is exactly where a wrong choice is hardest to
/// notice.
fn signed_cast(
  from : @wasm_types.ValType[Int],
  to : @ast.NumType,
  signage : @wasm_types.Signage,
  strict : Bool,
) -> Array[@wasm_bin.Instruction]? {
  match (from, to, signage, strict) {
    (F32, I32, Signed, true) => Some([I32TruncF32S])
    (F32, I32, Unsigned, true) => Some([I32TruncF32U])
    (F64, I32, Signed, true) => Some([I32TruncF64S])
    (F64, I32, Unsigned, true) => Some([I32TruncF64U])
    (F32, I64, Signed, true) => Some([I64TruncF32S])
    (F32, I64, Unsigned, true) => Some([I64TruncF32U])
    (F64, I64, Signed, true) => Some([I64TruncF64S])
    (F64, I64, Unsigned, true) => Some([I64TruncF64U])
    (F32, I32, Signed, false) => Some([I32TruncSatF32S])
    (F32, I32, Unsigned, false) => Some([I32TruncSatF32U])
    (F64, I32, Signed, false) => Some([I32TruncSatF64S])
    (F64, I32, Unsigned, false) => Some([I32TruncSatF64U])
    (F32, I64, Signed, false) => Some([I64TruncSatF32S])
    (F32, I64, Unsigned, false) => Some([I64TruncSatF32U])
    (F64, I64, Signed, false) => Some([I64TruncSatF64S])
    (F64, I64, Unsigned, false) => Some([I64TruncSatF64U])
    // An integer widened with its signedness written out.
    (I32, I64, Signed, _) => Some([I64ExtendI32S])
    (I32, I64, Unsigned, _) => Some([I64ExtendI32U])
    // An integer converted to a float with its signedness written out.
    (I32, F32, Signed, _) => Some([F32ConvertI32S])
    (I32, F32, Unsigned, _) => Some([F32ConvertI32U])
    (I32, F64, Signed, _) => Some([F64ConvertI32S])
    (I32, F64, Unsigned, _) => Some([F64ConvertI32U])
    (I64, F32, Signed, _) => Some([F32ConvertI64S])
    (I64, F32, Unsigned, _) => Some([F32ConvertI64U])
    (I64, F64, Signed, _) => Some([F64ConvertI64S])
    (I64, F64, Unsigned, _) => Some([F64ConvertI64U])
    // A narrowing needs no sign: the bits are simply dropped.
    (I64, I32, _, _) => Some([I32WrapI64])
    _ => None
  }
}

///|
/// Emit whatever must happen BEFORE a cast's own instruction, and report the
/// type the value then has.
///
/// Several wax casts are two wasm instructions, because the source names only
/// the destination and the route there passes through a forced intermediate.
/// `r as i64_s` on a reference is `i31.get_s` and then a widening; `n as
/// &extern` on an i64 wraps to an i32, boxes it as an i31, and only then
/// converts. Emitting the intermediate here -- and reporting the type it
/// leaves -- is what lets the single match below finish every one of them the
/// same way the equivalent double cast would.
fn cast_prologue(
  out : Array[@wasm_bin.Instruction],
  from : @wasm_types.ValType[Int],
  target : @ast.CastType,
) -> @wasm_types.ValType[Int] {
  let i31ref : @wasm_types.RefType[Int] = { nullable: false, typ: I31, }
  match (from, target) {
    // `r as i32_s/u`: an i31 is already one, and anything else in the `any`
    // hierarchy is cast to one first. The `i31.get` follows in the match.
    (Ref({ typ: I31, .. }), Signed(typ=I32, ..)) => from
    (Ref(_), Signed(typ=I32, ..)) => {
      out.push(RefCast(i31ref))
      from
    }
    // `r as i64_s/u`: the same, and then the i32 it yields is widened.
    (Ref({ typ: I31, .. }), Signed(typ=I64, signage~, ..)) => {
      out.push(i31_get(signage))
      I32
    }
    (Ref(_), Signed(typ=I64, signage~, ..)) => {
      out.push(RefCast(i31ref))
      out.push(i31_get(signage))
      I32
    }
    // `ref.i31` takes an i32, so an i64 wraps first.
    (I64, Value(Ref({ typ: I31, .. }))) => {
      out.push(I32WrapI64)
      I32
    }
    // Crossing into the `extern` hierarchy from a number: box as an i31 first,
    // because the conversion takes a reference.
    (I32, Value(Ref({ typ: Extern, .. }))) => {
      out.push(RefI31)
      Ref({ nullable: false, typ: I31, })
    }
    (I64, Value(Ref({ typ: Extern, .. }))) => {
      out.push(I32WrapI64)
      out.push(RefI31)
      Ref({ nullable: false, typ: I31, })
    }
    // `extern as &T` for an `any`-hierarchy T: convert to `any` first, and let
    // the match below do the `ref.cast` to T. A non-null `&any` target from a
    // NULLABLE operand needs that cast too, to null-check the conversion's
    // result; a non-null operand already yields a non-null `any`, so it does
    // not, and falls to the convert alone.
    (
      Ref({ typ: Extern | NoExtern, .. }),
      Value(
        Ref({ typ: Eq | I31 | Struct | Array | Type(_) | Exact(_) | None_, .. })
      ),
    )
    | (
      Ref({ typ: Extern | NoExtern, nullable: true, }),
      Value(Ref({ typ: Any, nullable: false, })),
    ) => {
      out.push(AnyConvertExtern)
      Ref({ nullable: true, typ: Any, })
    }
    _ => from
  }
}

///|
/// The `i31.get` of this signedness. An i31 is 31 bits wide, so reading it as
/// an i32 has to say what the missing bit becomes.
fn i31_get(signage : @wasm_types.Signage) -> @wasm_bin.Instruction {
  match signage {
    Signed => I31GetS
    Unsigned => I31GetU
  }
}

///|
/// Emit a cast's own instruction, given the type the prologue left.
///
/// Every arm here is one instruction or none. An identity cast is real in the
/// source -- it pins a width the checker used -- and nothing at all in the
/// output, which is why the reference calls its sentinel `Nop` and then elides
/// it.
fn Lowering::cast_instruction(
  self : Lowering,
  out : Array[@wasm_bin.Instruction],
  from : @wasm_types.ValType[Int],
  target : @ast.CastType,
  node : @ast.Instr[@typing_env.InferredAnnotation],
  loc : @basic.Location,
) -> Unit raise LowerError {
  match (from, target) {
    (I32, Value(Ref({ typ: I31, .. }))) => out.push(RefI31)
    (Ref(_), Signed(typ=I32, signage~, ..)) => out.push(i31_get(signage))
    (
      Ref(
        {
          typ: Any
          | Eq
          | I31
          | Struct
          | Array
          | Type(_)
          | Exact(_)
          | None_,
          ..
        }
      ),
      Value(Ref({ typ: Extern, .. })),
    ) => out.push(ExternConvertAny)
    (Ref({ typ: Extern | NoExtern, .. }), Value(Ref({ typ: Any, .. }))) =>
      out.push(AnyConvertExtern)
    (Ref(_), Value(Ref(r))) => out.push(RefCast(self.reftype_index(r, loc)))
    (I64, Value(I32)) => out.push(I32WrapI64)
    (F64, Value(F32)) => out.push(F32DemoteF64)
    (F32, Value(F64)) => out.push(F64PromoteF32)
    (I32, Signed(typ=I64, signage~, ..)) =>
      out.push(
        match signage {
          Signed => I64ExtendI32S
          Unsigned => I64ExtendI32U
        },
      )
    // A cast to an inline function type is a `ref.cast` to the anonymous type
    // minted for the cast's own result.
    (_, Func(..)) => {
      guard node_valtype(node) is Some(Ref(r)) else {
        raise Unresolved("function-type cast", loc)
      }
      out.push(RefCast(r))
    }
    (_, Signed(typ~, signage~, strict~)) => {
      guard signed_cast(from, typ, signage, strict) is Some(instrs) else {
        raise NotLowered("signed cast between these types", loc)
      }
      for x in instrs {
        out.push(x)
      }
    }
    (_, Value(_)) => {
      guard node_valtype(node) is Some(to) else {
        raise Unresolved("cast target type", loc)
      }
      guard numeric_cast(from, to) is Some(instrs) else {
        raise NotLowered("cast between these types", loc)
      }
      for x in instrs {
        out.push(x)
      }
    }
  }
}
