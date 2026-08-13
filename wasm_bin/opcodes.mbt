///|
/// The opcode table.
///
/// This is upstream's, near enough verbatim, and it is the reason to vendor at
/// all. What changed: the four reference-type arms now take heap types rather
/// than value types (the format's operand there is a heap type, so writing a
/// value type prefixed a spurious 0x63/0x64 byte), and the catch-all that
/// emitted `unreachable` for anything unmatched is gone.
fn encode_instruction(
  w : BinaryWriter,
  instr : Instruction,
) -> Unit raise EncodeError {
  match instr {
    // Control instructions
    Unreachable => w.write_byte(0x00)
    Nop => w.write_byte(0x01)
    Block(bt, body) => {
      w.write_byte(0x02)
      encode_block_type(w, bt)
      encode_instructions(w, body)
      w.write_byte(0x0B) // end
    }
    Loop(bt, body) => {
      w.write_byte(0x03)
      encode_block_type(w, bt)
      encode_instructions(w, body)
      w.write_byte(0x0B) // end
    }
    If(bt, then_body, else_body) => {
      w.write_byte(0x04)
      encode_block_type(w, bt)
      encode_instructions(w, then_body)
      if !else_body.is_empty() {
        w.write_byte(0x05) // else
        encode_instructions(w, else_body)
      }
      w.write_byte(0x0B) // end
    }
    Br(label) => {
      w.write_byte(0x0C)
      w.write_u32(label)
    }
    BrIf(label) => {
      w.write_byte(0x0D)
      w.write_u32(label)
    }
    BrTable(labels, default) => {
      w.write_byte(0x0E)
      w.write_u32(labels.length())
      for l in labels {
        w.write_u32(l)
      }
      w.write_u32(default)
    }
    Return => w.write_byte(0x0F)
    Call(idx) => {
      w.write_byte(0x10)
      w.write_u32(idx)
    }
    CallIndirect(type_idx, table_idx) => {
      w.write_byte(0x11)
      w.write_u32(type_idx)
      w.write_u32(table_idx)
    }
    ReturnCall(idx) => {
      w.write_byte(0x12)
      w.write_u32(idx)
    }
    ReturnCallIndirect(type_idx, table_idx) => {
      w.write_byte(0x13)
      w.write_u32(type_idx)
      w.write_u32(table_idx)
    }
    CallRef(type_idx) => {
      w.write_byte(0x14)
      w.write_u32(type_idx)
    }
    ReturnCallRef(type_idx) => {
      w.write_byte(0x15)
      w.write_u32(type_idx)
    }

    // Exception handling
    Throw(tag_idx) => {
      w.write_byte(0x08)
      w.write_u32(tag_idx)
    }
    ThrowRef => w.write_byte(0x0A)
    LegacyTry(bt, body, catches, catch_all) => {
      w.write_byte(0x06)
      encode_block_type(w, bt)
      encode_instructions(w, body)
      for entry in catches {
        w.write_byte(0x07)
        w.write_u32(entry.0)
        encode_instructions(w, entry.1)
      }
      if catch_all is Some(body) {
        w.write_byte(0x19)
        encode_instructions(w, body)
      }
      w.write_byte(0x0B) // end
    }
    TryTable(bt, handlers, body) => {
      w.write_byte(0x1F)
      encode_block_type(w, bt)
      w.write_u32(handlers.length())
      for handler in handlers {
        encode_catch_handler(w, handler)
      }
      encode_instructions(w, body)
      w.write_byte(0x0B) // end
    }

    // Parametric instructions
    Drop => w.write_byte(0x1A)
    Select => w.write_byte(0x1B)
    SelectTyped(types) => {
      w.write_byte(0x1C)
      w.write_u32(types.length())
      for t in types {
        encode_valtype(w, t)
      }
    }

    // Variable instructions
    LocalGet(idx) => {
      w.write_byte(0x20)
      w.write_u32(idx)
    }
    LocalSet(idx) => {
      w.write_byte(0x21)
      w.write_u32(idx)
    }
    LocalTee(idx) => {
      w.write_byte(0x22)
      w.write_u32(idx)
    }
    GlobalGet(idx) => {
      w.write_byte(0x23)
      w.write_u32(idx)
    }
    GlobalSet(idx) => {
      w.write_byte(0x24)
      w.write_u32(idx)
    }

    // Table instructions
    TableGet(idx) => {
      w.write_byte(0x25)
      w.write_u32(idx)
    }
    TableSet(idx) => {
      w.write_byte(0x26)
      w.write_u32(idx)
    }
    TableSize(idx) => {
      w.write_byte(0xFC)
      w.write_u32(16)
      w.write_u32(idx)
    }
    TableGrow(idx) => {
      w.write_byte(0xFC)
      w.write_u32(15)
      w.write_u32(idx)
    }
    TableFill(idx) => {
      w.write_byte(0xFC)
      w.write_u32(17)
      w.write_u32(idx)
    }
    TableCopy(dst, src) => {
      w.write_byte(0xFC)
      w.write_u32(14)
      w.write_u32(dst)
      w.write_u32(src)
    }
    TableInit(table_idx, elem_idx) => {
      w.write_byte(0xFC)
      w.write_u32(12)
      w.write_u32(elem_idx)
      w.write_u32(table_idx)
    }

    // Memory instructions
    I32Load(memidx, align, offset) => {
      w.write_byte(0x28)
      encode_memarg(w, memidx, align, offset)
    }
    I64Load(memidx, align, offset) => {
      w.write_byte(0x29)
      encode_memarg(w, memidx, align, offset)
    }
    F32Load(memidx, align, offset) => {
      w.write_byte(0x2A)
      encode_memarg(w, memidx, align, offset)
    }
    F64Load(memidx, align, offset) => {
      w.write_byte(0x2B)
      encode_memarg(w, memidx, align, offset)
    }
    I32Load8S(memidx, align, offset) => {
      w.write_byte(0x2C)
      encode_memarg(w, memidx, align, offset)
    }
    I32Load8U(memidx, align, offset) => {
      w.write_byte(0x2D)
      encode_memarg(w, memidx, align, offset)
    }
    I32Load16S(memidx, align, offset) => {
      w.write_byte(0x2E)
      encode_memarg(w, memidx, align, offset)
    }
    I32Load16U(memidx, align, offset) => {
      w.write_byte(0x2F)
      encode_memarg(w, memidx, align, offset)
    }
    I64Load8S(memidx, align, offset) => {
      w.write_byte(0x30)
      encode_memarg(w, memidx, align, offset)
    }
    I64Load8U(memidx, align, offset) => {
      w.write_byte(0x31)
      encode_memarg(w, memidx, align, offset)
    }
    I64Load16S(memidx, align, offset) => {
      w.write_byte(0x32)
      encode_memarg(w, memidx, align, offset)
    }
    I64Load16U(memidx, align, offset) => {
      w.write_byte(0x33)
      encode_memarg(w, memidx, align, offset)
    }
    I64Load32S(memidx, align, offset) => {
      w.write_byte(0x34)
      encode_memarg(w, memidx, align, offset)
    }
    I64Load32U(memidx, align, offset) => {
      w.write_byte(0x35)
      encode_memarg(w, memidx, align, offset)
    }
    I32Store(memidx, align, offset) => {
      w.write_byte(0x36)
      encode_memarg(w, memidx, align, offset)
    }
    I64Store(memidx, align, offset) => {
      w.write_byte(0x37)
      encode_memarg(w, memidx, align, offset)
    }
    F32Store(memidx, align, offset) => {
      w.write_byte(0x38)
      encode_memarg(w, memidx, align, offset)
    }
    F64Store(memidx, align, offset) => {
      w.write_byte(0x39)
      encode_memarg(w, memidx, align, offset)
    }
    I32Store8(memidx, align, offset) => {
      w.write_byte(0x3A)
      encode_memarg(w, memidx, align, offset)
    }
    I32Store16(memidx, align, offset) => {
      w.write_byte(0x3B)
      encode_memarg(w, memidx, align, offset)
    }
    I64Store8(memidx, align, offset) => {
      w.write_byte(0x3C)
      encode_memarg(w, memidx, align, offset)
    }
    I64Store16(memidx, align, offset) => {
      w.write_byte(0x3D)
      encode_memarg(w, memidx, align, offset)
    }
    I64Store32(memidx, align, offset) => {
      w.write_byte(0x3E)
      encode_memarg(w, memidx, align, offset)
    }
    MemorySize(memidx) => {
      w.write_byte(0x3F)
      w.write_u32(memidx)
    }
    MemoryGrow(memidx) => {
      w.write_byte(0x40)
      w.write_u32(memidx)
    }
    MemoryInit(memidx, data_idx) => {
      w.write_byte(0xFC)
      w.write_u32(8)
      w.write_u32(data_idx)
      w.write_u32(memidx)
    }
    DataDrop(data_idx) => {
      w.write_byte(0xFC)
      w.write_u32(9)
      w.write_u32(data_idx)
    }
    MemoryCopy(dst, src) => {
      w.write_byte(0xFC)
      w.write_u32(10)
      w.write_u32(dst)
      w.write_u32(src)
    }
    MemoryFill(memidx) => {
      w.write_byte(0xFC)
      w.write_u32(11)
      w.write_u32(memidx)
    }
    ElemDrop(elem_idx) => {
      w.write_byte(0xFC)
      w.write_u32(13)
      w.write_u32(elem_idx)
    }

    // Reference instructions
    RefNull(ht) => {
      w.write_byte(0xD0)
      encode_heaptype(w, ht)
    }
    RefIsNull => w.write_byte(0xD1)
    RefFunc(idx) => {
      w.write_byte(0xD2)
      w.write_u32(idx)
    }
    RefAsNonNull => w.write_byte(0xD4)
    RefEqInstr => w.write_byte(0xD3)
    BrOnNull(label) => {
      w.write_byte(0xD5)
      w.write_u32(label)
    }
    BrOnNonNull(label) => {
      w.write_byte(0xD6)
      w.write_u32(label)
    }

    // Numeric constants
    I32Const(val) => {
      w.write_byte(0x41)
      w.write_s32(val)
    }
    I64Const(val) => {
      w.write_byte(0x42)
      w.write_s64(val)
    }
    F32Const(val) => {
      w.write_byte(0x43)
      w.write_f32(val)
    }
    F64Const(val) => {
      w.write_byte(0x44)
      w.write_f64(val)
    }

    // i32 operations
    I32Eqz => w.write_byte(0x45)
    I32Eq => w.write_byte(0x46)
    I32Ne => w.write_byte(0x47)
    I32LtS => w.write_byte(0x48)
    I32LtU => w.write_byte(0x49)
    I32GtS => w.write_byte(0x4A)
    I32GtU => w.write_byte(0x4B)
    I32LeS => w.write_byte(0x4C)
    I32LeU => w.write_byte(0x4D)
    I32GeS => w.write_byte(0x4E)
    I32GeU => w.write_byte(0x4F)
    I32Clz => w.write_byte(0x67)
    I32Ctz => w.write_byte(0x68)
    I32Popcnt => w.write_byte(0x69)
    I32Add => w.write_byte(0x6A)
    I32Sub => w.write_byte(0x6B)
    I32Mul => w.write_byte(0x6C)
    I32DivS => w.write_byte(0x6D)
    I32DivU => w.write_byte(0x6E)
    I32RemS => w.write_byte(0x6F)
    I32RemU => w.write_byte(0x70)
    I32And => w.write_byte(0x71)
    I32Or => w.write_byte(0x72)
    I32Xor => w.write_byte(0x73)
    I32Shl => w.write_byte(0x74)
    I32ShrS => w.write_byte(0x75)
    I32ShrU => w.write_byte(0x76)
    I32Rotl => w.write_byte(0x77)
    I32Rotr => w.write_byte(0x78)
    I32Extend8S => w.write_byte(0xC0)
    I32Extend16S => w.write_byte(0xC1)

    // i64 operations
    I64Eqz => w.write_byte(0x50)
    I64Eq => w.write_byte(0x51)
    I64Ne => w.write_byte(0x52)
    I64LtS => w.write_byte(0x53)
    I64LtU => w.write_byte(0x54)
    I64GtS => w.write_byte(0x55)
    I64GtU => w.write_byte(0x56)
    I64LeS => w.write_byte(0x57)
    I64LeU => w.write_byte(0x58)
    I64GeS => w.write_byte(0x59)
    I64GeU => w.write_byte(0x5A)
    I64Clz => w.write_byte(0x79)
    I64Ctz => w.write_byte(0x7A)
    I64Popcnt => w.write_byte(0x7B)
    I64Add => w.write_byte(0x7C)
    I64Sub => w.write_byte(0x7D)
    I64Mul => w.write_byte(0x7E)
    I64DivS => w.write_byte(0x7F)
    I64DivU => w.write_byte(0x80)
    I64RemS => w.write_byte(0x81)
    I64RemU => w.write_byte(0x82)
    I64And => w.write_byte(0x83)
    I64Or => w.write_byte(0x84)
    I64Xor => w.write_byte(0x85)
    I64Shl => w.write_byte(0x86)
    I64ShrS => w.write_byte(0x87)
    I64ShrU => w.write_byte(0x88)
    I64Rotl => w.write_byte(0x89)
    I64Rotr => w.write_byte(0x8A)
    I64Extend8S => w.write_byte(0xC2)
    I64Extend16S => w.write_byte(0xC3)
    I64Extend32S => w.write_byte(0xC4)

    // f32 operations
    F32Eq => w.write_byte(0x5B)
    F32Ne => w.write_byte(0x5C)
    F32Lt => w.write_byte(0x5D)
    F32Gt => w.write_byte(0x5E)
    F32Le => w.write_byte(0x5F)
    F32Ge => w.write_byte(0x60)
    F32Abs => w.write_byte(0x8B)
    F32Neg => w.write_byte(0x8C)
    F32Ceil => w.write_byte(0x8D)
    F32Floor => w.write_byte(0x8E)
    F32Trunc => w.write_byte(0x8F)
    F32Nearest => w.write_byte(0x90)
    F32Sqrt => w.write_byte(0x91)
    F32Add => w.write_byte(0x92)
    F32Sub => w.write_byte(0x93)
    F32Mul => w.write_byte(0x94)
    F32Div => w.write_byte(0x95)
    F32Min => w.write_byte(0x96)
    F32Max => w.write_byte(0x97)
    F32Copysign => w.write_byte(0x98)

    // f64 operations
    F64Eq => w.write_byte(0x61)
    F64Ne => w.write_byte(0x62)
    F64Lt => w.write_byte(0x63)
    F64Gt => w.write_byte(0x64)
    F64Le => w.write_byte(0x65)
    F64Ge => w.write_byte(0x66)
    F64Abs => w.write_byte(0x99)
    F64Neg => w.write_byte(0x9A)
    F64Ceil => w.write_byte(0x9B)
    F64Floor => w.write_byte(0x9C)
    F64Trunc => w.write_byte(0x9D)
    F64Nearest => w.write_byte(0x9E)
    F64Sqrt => w.write_byte(0x9F)
    F64Add => w.write_byte(0xA0)
    F64Sub => w.write_byte(0xA1)
    F64Mul => w.write_byte(0xA2)
    F64Div => w.write_byte(0xA3)
    F64Min => w.write_byte(0xA4)
    F64Max => w.write_byte(0xA5)
    F64Copysign => w.write_byte(0xA6)

    // Conversions
    I32WrapI64 => w.write_byte(0xA7)
    I32TruncF32S => w.write_byte(0xA8)
    I32TruncF32U => w.write_byte(0xA9)
    I32TruncF64S => w.write_byte(0xAA)
    I32TruncF64U => w.write_byte(0xAB)
    I64ExtendI32S => w.write_byte(0xAC)
    I64ExtendI32U => w.write_byte(0xAD)
    I64TruncF32S => w.write_byte(0xAE)
    I64TruncF32U => w.write_byte(0xAF)
    I64TruncF64S => w.write_byte(0xB0)
    I64TruncF64U => w.write_byte(0xB1)
    F32ConvertI32S => w.write_byte(0xB2)
    F32ConvertI32U => w.write_byte(0xB3)
    F32ConvertI64S => w.write_byte(0xB4)
    F32ConvertI64U => w.write_byte(0xB5)
    F32DemoteF64 => w.write_byte(0xB6)
    F64ConvertI32S => w.write_byte(0xB7)
    F64ConvertI32U => w.write_byte(0xB8)
    F64ConvertI64S => w.write_byte(0xB9)
    F64ConvertI64U => w.write_byte(0xBA)
    F64PromoteF32 => w.write_byte(0xBB)
    I32ReinterpretF32 => w.write_byte(0xBC)
    I64ReinterpretF64 => w.write_byte(0xBD)
    F32ReinterpretI32 => w.write_byte(0xBE)
    F64ReinterpretI64 => w.write_byte(0xBF)

    // Saturating truncation
    I32TruncSatF32S => {
      w.write_byte(0xFC)
      w.write_u32(0)
    }
    I32TruncSatF32U => {
      w.write_byte(0xFC)
      w.write_u32(1)
    }
    I32TruncSatF64S => {
      w.write_byte(0xFC)
      w.write_u32(2)
    }
    I32TruncSatF64U => {
      w.write_byte(0xFC)
      w.write_u32(3)
    }
    I64TruncSatF32S => {
      w.write_byte(0xFC)
      w.write_u32(4)
    }
    I64TruncSatF32U => {
      w.write_byte(0xFC)
      w.write_u32(5)
    }
    I64TruncSatF64S => {
      w.write_byte(0xFC)
      w.write_u32(6)
    }
    I64TruncSatF64U => {
      w.write_byte(0xFC)
      w.write_u32(7)
    }

    // GC instructions
    StructNewDesc(type_idx) => {
      w.write_byte(0xFB)
      w.write_byte(0x20)
      w.write_u32(type_idx)
    }
    StructNewDefaultDesc(type_idx) => {
      w.write_byte(0xFB)
      w.write_byte(0x21)
      w.write_u32(type_idx)
    }
    RefGetDesc(type_idx) => {
      w.write_byte(0xFB)
      w.write_byte(0x22)
      w.write_u32(type_idx)
    }
    RefCastDescEq(rt) => {
      w.write_byte(0xFB)
      w.write_byte(if rt.nullable { 0x24 } else { 0x23 })
      encode_heaptype(w, rt.typ)
    }
    BrOnCastDescEq(label, from, to) => {
      w.write_byte(0xFB)
      w.write_byte(0x25)
      w.write_byte(
        (if from.nullable { 1 } else { 0 }) + (if to.nullable { 2 } else { 0 }),
      )
      w.write_u32(label)
      encode_heaptype(w, from.typ)
      encode_heaptype(w, to.typ)
    }
    BrOnCastDescEqFail(label, from, to) => {
      w.write_byte(0xFB)
      w.write_byte(0x26)
      w.write_byte(
        (if from.nullable { 1 } else { 0 }) + (if to.nullable { 2 } else { 0 }),
      )
      w.write_u32(label)
      encode_heaptype(w, from.typ)
      encode_heaptype(w, to.typ)
    }
    StructNew(type_idx) => {
      w.write_byte(0xFB)
      w.write_u32(0)
      w.write_u32(type_idx)
    }
    StructNewDefault(type_idx) => {
      w.write_byte(0xFB)
      w.write_u32(1)
      w.write_u32(type_idx)
    }
    StructGet(type_idx, field_idx) => {
      w.write_byte(0xFB)
      w.write_u32(2)
      w.write_u32(type_idx)
      w.write_u32(field_idx)
    }
    StructGetS(type_idx, field_idx) => {
      w.write_byte(0xFB)
      w.write_u32(3)
      w.write_u32(type_idx)
      w.write_u32(field_idx)
    }
    StructGetU(type_idx, field_idx) => {
      w.write_byte(0xFB)
      w.write_u32(4)
      w.write_u32(type_idx)
      w.write_u32(field_idx)
    }
    StructSet(type_idx, field_idx) => {
      w.write_byte(0xFB)
      w.write_u32(5)
      w.write_u32(type_idx)
      w.write_u32(field_idx)
    }
    ArrayNew(type_idx) => {
      w.write_byte(0xFB)
      w.write_u32(6)
      w.write_u32(type_idx)
    }
    ArrayNewDefault(type_idx) => {
      w.write_byte(0xFB)
      w.write_u32(7)
      w.write_u32(type_idx)
    }
    ArrayNewFixed(type_idx, len) => {
      w.write_byte(0xFB)
      w.write_u32(8)
      w.write_u32(type_idx)
      w.write_u32(len)
    }
    ArrayNewData(type_idx, data_idx) => {
      w.write_byte(0xFB)
      w.write_u32(9)
      w.write_u32(type_idx)
      w.write_u32(data_idx)
    }
    ArrayNewElem(type_idx, elem_idx) => {
      w.write_byte(0xFB)
      w.write_u32(10)
      w.write_u32(type_idx)
      w.write_u32(elem_idx)
    }
    ArrayGet(type_idx) => {
      w.write_byte(0xFB)
      w.write_u32(11)
      w.write_u32(type_idx)
    }
    ArrayGetS(type_idx) => {
      w.write_byte(0xFB)
      w.write_u32(12)
      w.write_u32(type_idx)
    }
    ArrayGetU(type_idx) => {
      w.write_byte(0xFB)
      w.write_u32(13)
      w.write_u32(type_idx)
    }
    ArraySet(type_idx) => {
      w.write_byte(0xFB)
      w.write_u32(14)
      w.write_u32(type_idx)
    }
    ArrayLen => {
      w.write_byte(0xFB)
      w.write_u32(15)
    }
    ArrayFill(type_idx) => {
      w.write_byte(0xFB)
      w.write_u32(16)
      w.write_u32(type_idx)
    }
    ArrayCopy(dst_type, src_type) => {
      w.write_byte(0xFB)
      w.write_u32(17)
      w.write_u32(dst_type)
      w.write_u32(src_type)
    }
    ArrayInitData(type_idx, data_idx) => {
      w.write_byte(0xFB)
      w.write_u32(18)
      w.write_u32(type_idx)
      w.write_u32(data_idx)
    }
    ArrayInitElem(type_idx, elem_idx) => {
      w.write_byte(0xFB)
      w.write_u32(19)
      w.write_u32(type_idx)
      w.write_u32(elem_idx)
    }
    RefTest(rt) => {
      w.write_byte(0xFB)
      w.write_u32(if rt.nullable { 21 } else { 20 })
      encode_heaptype(w, rt.typ)
    }
    RefCast(rt) => {
      w.write_byte(0xFB)
      w.write_u32(if rt.nullable { 23 } else { 22 })
      encode_heaptype(w, rt.typ)
    }
    BrOnCast(label, from_type, to_type) => {
      w.write_byte(0xFB)
      w.write_u32(24)
      // Cast flags: bit 0 = source nullable, bit 1 = target nullable.
      w.write_byte(cast_flags(from_type, to_type))
      w.write_u32(label)
      encode_heaptype(w, from_type.typ)
      encode_heaptype(w, to_type.typ)
    }
    BrOnCastFail(label, from_type, to_type) => {
      w.write_byte(0xFB)
      w.write_u32(25)
      w.write_byte(cast_flags(from_type, to_type))
      w.write_u32(label)
      encode_heaptype(w, from_type.typ)
      encode_heaptype(w, to_type.typ)
    }
    RefI31 => {
      w.write_byte(0xFB)
      w.write_u32(28)
    }
    I31GetS => {
      w.write_byte(0xFB)
      w.write_u32(29)
    }
    I31GetU => {
      w.write_byte(0xFB)
      w.write_u32(30)
    }
    AnyConvertExtern => {
      w.write_byte(0xFB)
      w.write_u32(26)
    }
    ExternConvertAny => {
      w.write_byte(0xFB)
      w.write_u32(27)
    }

    // SIMD - V128 constant and load/store
    V128Const(bytes) => {
      w.write_byte(0xFD)
      w.write_u32(12)
      for i in 0..<16 {
        w.write_byte(bytes[i].to_int())
      }
    }
    V128Load(memidx, align, offset) => {
      w.write_byte(0xFD)
      w.write_u32(0)
      encode_memarg(w, memidx, align, offset)
    }
    V128Store(memidx, align, offset) => {
      w.write_byte(0xFD)
      w.write_u32(11)
      encode_memarg(w, memidx, align, offset)
    }
    // Hints carry no opcode: record where the instruction they belong to
    // starts, then encode that instruction.
    Hinted(hints, inner) => {
      w.record_hint(hints)
      encode_instruction(w, inner)
    }
    // Stack switching. `wasm_core` had none of these; the encodings are
    // wasm_output.ml's, which is what they are measured against.
    ContNew(idx) => {
      w.write_byte(0xE0)
      w.write_u32(idx)
    }
    ContBind(from_idx, to_idx) => {
      w.write_byte(0xE1)
      w.write_u32(from_idx)
      w.write_u32(to_idx)
    }
    Suspend(tag) => {
      w.write_byte(0xE2)
      w.write_u32(tag)
    }
    Resume(idx, clauses) => {
      w.write_byte(0xE3)
      w.write_u32(idx)
      encode_resume_table(w, clauses)
    }
    ResumeThrow(idx, tag, clauses) => {
      w.write_byte(0xE4)
      w.write_u32(idx)
      w.write_u32(tag)
      encode_resume_table(w, clauses)
    }
    ResumeThrowRef(idx, clauses) => {
      w.write_byte(0xE5)
      w.write_u32(idx)
      encode_resume_table(w, clauses)
    }
    Switch(idx, tag) => {
      w.write_byte(0xE6)
      w.write_u32(idx)
      w.write_u32(tag)
    }
    // The threads proposal. The sub-opcode is a BYTE, not a LEB -- they all
    // happen to be under 0x80, so the two agree today, but the reference writes
    // a byte and that is what these bytes are measured against.
    Atomic(op, memidx, align, offset) => {
      w.write_byte(0xFE)
      w.write_byte(op)
      encode_memarg(w, memidx, align, offset)
    }
    // `atomic.fence` is the one atomic with no memory operand, so it cannot be
    // spelled as an `Atomic` with a degenerate memarg: the format wants a
    // single 0x00 where the memarg would go, not an alignment and an offset.
    AtomicFence => {
      w.write_byte(0xFE)
      w.write_byte(0x03)
      w.write_byte(0x00)
    }
    I16x8RelaxedDotI8x16I7x16S => {
      w.write_byte(0xFD)
      w.write_u32(0x112)
    }
    I16x8RelaxedQ15mulrS => {
      w.write_byte(0xFD)
      w.write_u32(0x111)
    }
    F64x2RelaxedMax => {
      w.write_byte(0xFD)
      w.write_u32(0x110)
    }
    F64x2RelaxedMin => {
      w.write_byte(0xFD)
      w.write_u32(0x10F)
    }
    F32x4RelaxedMax => {
      w.write_byte(0xFD)
      w.write_u32(0x10E)
    }
    F32x4RelaxedMin => {
      w.write_byte(0xFD)
      w.write_u32(0x10D)
    }
    I64x2RelaxedLaneselect => {
      w.write_byte(0xFD)
      w.write_u32(0x10C)
    }
    I32x4RelaxedLaneselect => {
      w.write_byte(0xFD)
      w.write_u32(0x10B)
    }
    I16x8RelaxedLaneselect => {
      w.write_byte(0xFD)
      w.write_u32(0x10A)
    }
    I8x16RelaxedLaneselect => {
      w.write_byte(0xFD)
      w.write_u32(0x109)
    }
    F64x2RelaxedNmadd => {
      w.write_byte(0xFD)
      w.write_u32(0x108)
    }
    F64x2RelaxedMadd => {
      w.write_byte(0xFD)
      w.write_u32(0x107)
    }
    F32x4RelaxedNmadd => {
      w.write_byte(0xFD)
      w.write_u32(0x106)
    }
    F32x4RelaxedMadd => {
      w.write_byte(0xFD)
      w.write_u32(0x105)
    }
    I32x4RelaxedTruncF64x2UZero => {
      w.write_byte(0xFD)
      w.write_u32(0x104)
    }
    I32x4RelaxedTruncF64x2SZero => {
      w.write_byte(0xFD)
      w.write_u32(0x103)
    }
    I32x4RelaxedTruncF32x4U => {
      w.write_byte(0xFD)
      w.write_u32(0x102)
    }
    I32x4RelaxedTruncF32x4S => {
      w.write_byte(0xFD)
      w.write_u32(0x101)
    }
    I8x16RelaxedSwizzle => {
      w.write_byte(0xFD)
      w.write_u32(0x100)
    }
    F64x2PromoteLowF32x4 => {
      w.write_byte(0xFD)
      w.write_u32(0x5F)
    }
    F32x4DemoteF64x2Zero => {
      w.write_byte(0xFD)
      w.write_u32(0x5E)
    }
    F64x2ConvertLowI32x4U => {
      w.write_byte(0xFD)
      w.write_u32(0xFF)
    }
    F64x2ConvertLowI32x4S => {
      w.write_byte(0xFD)
      w.write_u32(0xFE)
    }
    I32x4TruncSatF64x2UZero => {
      w.write_byte(0xFD)
      w.write_u32(0xFD)
    }
    I32x4TruncSatF64x2SZero => {
      w.write_byte(0xFD)
      w.write_u32(0xFC)
    }
    F32x4ConvertI32x4U => {
      w.write_byte(0xFD)
      w.write_u32(0xFB)
    }
    F32x4ConvertI32x4S => {
      w.write_byte(0xFD)
      w.write_u32(0xFA)
    }
    I32x4TruncSatF32x4U => {
      w.write_byte(0xFD)
      w.write_u32(0xF9)
    }
    I32x4TruncSatF32x4S => {
      w.write_byte(0xFD)
      w.write_u32(0xF8)
    }
    F64x2Pmax => {
      w.write_byte(0xFD)
      w.write_u32(0xF7)
    }
    F64x2Pmin => {
      w.write_byte(0xFD)
      w.write_u32(0xF6)
    }
    F64x2Max => {
      w.write_byte(0xFD)
      w.write_u32(0xF5)
    }
    F64x2Min => {
      w.write_byte(0xFD)
      w.write_u32(0xF4)
    }
    F64x2Div => {
      w.write_byte(0xFD)
      w.write_u32(0xF3)
    }
    F64x2Mul => {
      w.write_byte(0xFD)
      w.write_u32(0xF2)
    }
    F64x2Sub => {
      w.write_byte(0xFD)
      w.write_u32(0xF1)
    }
    F64x2Add => {
      w.write_byte(0xFD)
      w.write_u32(0xF0)
    }
    F64x2Sqrt => {
      w.write_byte(0xFD)
      w.write_u32(0xEF)
    }
    F64x2Neg => {
      w.write_byte(0xFD)
      w.write_u32(0xED)
    }
    F64x2Abs => {
      w.write_byte(0xFD)
      w.write_u32(0xEC)
    }
    F64x2Nearest => {
      w.write_byte(0xFD)
      w.write_u32(0x94)
    }
    F64x2Trunc => {
      w.write_byte(0xFD)
      w.write_u32(0x7A)
    }
    F64x2Floor => {
      w.write_byte(0xFD)
      w.write_u32(0x75)
    }
    F64x2Ceil => {
      w.write_byte(0xFD)
      w.write_u32(0x74)
    }
    F32x4Pmax => {
      w.write_byte(0xFD)
      w.write_u32(0xEB)
    }
    F32x4Pmin => {
      w.write_byte(0xFD)
      w.write_u32(0xEA)
    }
    F32x4Max => {
      w.write_byte(0xFD)
      w.write_u32(0xE9)
    }
    F32x4Min => {
      w.write_byte(0xFD)
      w.write_u32(0xE8)
    }
    F32x4Div => {
      w.write_byte(0xFD)
      w.write_u32(0xE7)
    }
    F32x4Mul => {
      w.write_byte(0xFD)
      w.write_u32(0xE6)
    }
    F32x4Sub => {
      w.write_byte(0xFD)
      w.write_u32(0xE5)
    }
    F32x4Add => {
      w.write_byte(0xFD)
      w.write_u32(0xE4)
    }
    F32x4Sqrt => {
      w.write_byte(0xFD)
      w.write_u32(0xE3)
    }
    F32x4Neg => {
      w.write_byte(0xFD)
      w.write_u32(0xE1)
    }
    F32x4Abs => {
      w.write_byte(0xFD)
      w.write_u32(0xE0)
    }
    F32x4Nearest => {
      w.write_byte(0xFD)
      w.write_u32(0x6A)
    }
    F32x4Trunc => {
      w.write_byte(0xFD)
      w.write_u32(0x69)
    }
    F32x4Floor => {
      w.write_byte(0xFD)
      w.write_u32(0x68)
    }
    F32x4Ceil => {
      w.write_byte(0xFD)
      w.write_u32(0x67)
    }
    I64x2ExtMulHighI32x4U => {
      w.write_byte(0xFD)
      w.write_u32(0xDF)
    }
    I64x2ExtMulLowI32x4U => {
      w.write_byte(0xFD)
      w.write_u32(0xDE)
    }
    I64x2ExtMulHighI32x4S => {
      w.write_byte(0xFD)
      w.write_u32(0xDD)
    }
    I64x2ExtMulLowI32x4S => {
      w.write_byte(0xFD)
      w.write_u32(0xDC)
    }
    I64x2Mul => {
      w.write_byte(0xFD)
      w.write_u32(0xD5)
    }
    I64x2Sub => {
      w.write_byte(0xFD)
      w.write_u32(0xD1)
    }
    I64x2Add => {
      w.write_byte(0xFD)
      w.write_u32(0xCE)
    }
    I64x2ShrU => {
      w.write_byte(0xFD)
      w.write_u32(0xCD)
    }
    I64x2ShrS => {
      w.write_byte(0xFD)
      w.write_u32(0xCC)
    }
    I64x2Shl => {
      w.write_byte(0xFD)
      w.write_u32(0xCB)
    }
    I64x2ExtendHighI32x4U => {
      w.write_byte(0xFD)
      w.write_u32(0xCA)
    }
    I64x2ExtendLowI32x4U => {
      w.write_byte(0xFD)
      w.write_u32(0xC9)
    }
    I64x2ExtendHighI32x4S => {
      w.write_byte(0xFD)
      w.write_u32(0xC8)
    }
    I64x2ExtendLowI32x4S => {
      w.write_byte(0xFD)
      w.write_u32(0xC7)
    }
    I64x2Bitmask => {
      w.write_byte(0xFD)
      w.write_u32(0xC4)
    }
    I64x2AllTrue => {
      w.write_byte(0xFD)
      w.write_u32(0xC3)
    }
    I64x2Neg => {
      w.write_byte(0xFD)
      w.write_u32(0xC1)
    }
    I64x2Abs => {
      w.write_byte(0xFD)
      w.write_u32(0xC0)
    }
    I32x4ExtMulHighI16x8U => {
      w.write_byte(0xFD)
      w.write_u32(0xBF)
    }
    I32x4ExtMulLowI16x8U => {
      w.write_byte(0xFD)
      w.write_u32(0xBE)
    }
    I32x4ExtMulHighI16x8S => {
      w.write_byte(0xFD)
      w.write_u32(0xBD)
    }
    I32x4ExtMulLowI16x8S => {
      w.write_byte(0xFD)
      w.write_u32(0xBC)
    }
    I32x4DotI16x8S => {
      w.write_byte(0xFD)
      w.write_u32(0xBA)
    }
    I32x4MaxU => {
      w.write_byte(0xFD)
      w.write_u32(0xB9)
    }
    I32x4MaxS => {
      w.write_byte(0xFD)
      w.write_u32(0xB8)
    }
    I32x4MinU => {
      w.write_byte(0xFD)
      w.write_u32(0xB7)
    }
    I32x4MinS => {
      w.write_byte(0xFD)
      w.write_u32(0xB6)
    }
    I32x4Mul => {
      w.write_byte(0xFD)
      w.write_u32(0xB5)
    }
    I32x4Sub => {
      w.write_byte(0xFD)
      w.write_u32(0xB1)
    }
    I32x4Add => {
      w.write_byte(0xFD)
      w.write_u32(0xAE)
    }
    I32x4ShrU => {
      w.write_byte(0xFD)
      w.write_u32(0xAD)
    }
    I32x4ShrS => {
      w.write_byte(0xFD)
      w.write_u32(0xAC)
    }
    I32x4Shl => {
      w.write_byte(0xFD)
      w.write_u32(0xAB)
    }
    I32x4ExtendHighI16x8U => {
      w.write_byte(0xFD)
      w.write_u32(0xAA)
    }
    I32x4ExtendLowI16x8U => {
      w.write_byte(0xFD)
      w.write_u32(0xA9)
    }
    I32x4ExtendHighI16x8S => {
      w.write_byte(0xFD)
      w.write_u32(0xA8)
    }
    I32x4ExtendLowI16x8S => {
      w.write_byte(0xFD)
      w.write_u32(0xA7)
    }
    I32x4Bitmask => {
      w.write_byte(0xFD)
      w.write_u32(0xA4)
    }
    I32x4AllTrue => {
      w.write_byte(0xFD)
      w.write_u32(0xA3)
    }
    I32x4Neg => {
      w.write_byte(0xFD)
      w.write_u32(0xA1)
    }
    I32x4Abs => {
      w.write_byte(0xFD)
      w.write_u32(0xA0)
    }
    I32x4ExtAddPairwiseI16x8U => {
      w.write_byte(0xFD)
      w.write_u32(0x7F)
    }
    I32x4ExtAddPairwiseI16x8S => {
      w.write_byte(0xFD)
      w.write_u32(0x7E)
    }
    I16x8ExtMulHighI8x16U => {
      w.write_byte(0xFD)
      w.write_u32(0x9F)
    }
    I16x8ExtMulLowI8x16U => {
      w.write_byte(0xFD)
      w.write_u32(0x9E)
    }
    I16x8ExtMulHighI8x16S => {
      w.write_byte(0xFD)
      w.write_u32(0x9D)
    }
    I16x8ExtMulLowI8x16S => {
      w.write_byte(0xFD)
      w.write_u32(0x9C)
    }
    I16x8AvgrU => {
      w.write_byte(0xFD)
      w.write_u32(0x9B)
    }
    I16x8MaxU => {
      w.write_byte(0xFD)
      w.write_u32(0x99)
    }
    I16x8MaxS => {
      w.write_byte(0xFD)
      w.write_u32(0x98)
    }
    I16x8MinU => {
      w.write_byte(0xFD)
      w.write_u32(0x97)
    }
    I16x8MinS => {
      w.write_byte(0xFD)
      w.write_u32(0x96)
    }
    I16x8Mul => {
      w.write_byte(0xFD)
      w.write_u32(0x95)
    }
    I16x8SubSatU => {
      w.write_byte(0xFD)
      w.write_u32(0x93)
    }
    I16x8SubSatS => {
      w.write_byte(0xFD)
      w.write_u32(0x92)
    }
    I16x8Sub => {
      w.write_byte(0xFD)
      w.write_u32(0x91)
    }
    I16x8AddSatU => {
      w.write_byte(0xFD)
      w.write_u32(0x90)
    }
    I16x8AddSatS => {
      w.write_byte(0xFD)
      w.write_u32(0x8F)
    }
    I16x8Add => {
      w.write_byte(0xFD)
      w.write_u32(0x8E)
    }
    I16x8ShrU => {
      w.write_byte(0xFD)
      w.write_u32(0x8D)
    }
    I16x8ShrS => {
      w.write_byte(0xFD)
      w.write_u32(0x8C)
    }
    I16x8Shl => {
      w.write_byte(0xFD)
      w.write_u32(0x8B)
    }
    I16x8ExtendHighI8x16U => {
      w.write_byte(0xFD)
      w.write_u32(0x8A)
    }
    I16x8ExtendLowI8x16U => {
      w.write_byte(0xFD)
      w.write_u32(0x89)
    }
    I16x8ExtendHighI8x16S => {
      w.write_byte(0xFD)
      w.write_u32(0x88)
    }
    I16x8ExtendLowI8x16S => {
      w.write_byte(0xFD)
      w.write_u32(0x87)
    }
    I16x8NarrowI32x4U => {
      w.write_byte(0xFD)
      w.write_u32(0x86)
    }
    I16x8NarrowI32x4S => {
      w.write_byte(0xFD)
      w.write_u32(0x85)
    }
    I16x8Bitmask => {
      w.write_byte(0xFD)
      w.write_u32(0x84)
    }
    I16x8AllTrue => {
      w.write_byte(0xFD)
      w.write_u32(0x83)
    }
    I16x8Q15MulrSatS => {
      w.write_byte(0xFD)
      w.write_u32(0x82)
    }
    I16x8Neg => {
      w.write_byte(0xFD)
      w.write_u32(0x81)
    }
    I16x8Abs => {
      w.write_byte(0xFD)
      w.write_u32(0x80)
    }
    I16x8ExtAddPairwiseI8x16U => {
      w.write_byte(0xFD)
      w.write_u32(0x7D)
    }
    I16x8ExtAddPairwiseI8x16S => {
      w.write_byte(0xFD)
      w.write_u32(0x7C)
    }
    I8x16AvgrU => {
      w.write_byte(0xFD)
      w.write_u32(0x7B)
    }
    I8x16MaxU => {
      w.write_byte(0xFD)
      w.write_u32(0x79)
    }
    I8x16MaxS => {
      w.write_byte(0xFD)
      w.write_u32(0x78)
    }
    I8x16MinU => {
      w.write_byte(0xFD)
      w.write_u32(0x77)
    }
    I8x16MinS => {
      w.write_byte(0xFD)
      w.write_u32(0x76)
    }
    I8x16SubSatU => {
      w.write_byte(0xFD)
      w.write_u32(0x73)
    }
    I8x16SubSatS => {
      w.write_byte(0xFD)
      w.write_u32(0x72)
    }
    I8x16Sub => {
      w.write_byte(0xFD)
      w.write_u32(0x71)
    }
    I8x16AddSatU => {
      w.write_byte(0xFD)
      w.write_u32(0x70)
    }
    I8x16AddSatS => {
      w.write_byte(0xFD)
      w.write_u32(0x6f)
    }
    I8x16Add => {
      w.write_byte(0xFD)
      w.write_u32(0x6e)
    }
    I8x16ShrU => {
      w.write_byte(0xFD)
      w.write_u32(0x6d)
    }
    I8x16ShrS => {
      w.write_byte(0xFD)
      w.write_u32(0x6c)
    }
    I8x16Shl => {
      w.write_byte(0xFD)
      w.write_u32(0x6b)
    }
    I8x16NarrowI16x8U => {
      w.write_byte(0xFD)
      w.write_u32(0x66)
    }
    I8x16NarrowI16x8S => {
      w.write_byte(0xFD)
      w.write_u32(0x65)
    }
    I8x16Bitmask => {
      w.write_byte(0xFD)
      w.write_u32(0x64)
    }
    I8x16AllTrue => {
      w.write_byte(0xFD)
      w.write_u32(0x63)
    }
    I8x16Popcnt => {
      w.write_byte(0xFD)
      w.write_u32(0x62)
    }
    I8x16Neg => {
      w.write_byte(0xFD)
      w.write_u32(0x61)
    }
    I8x16Abs => {
      w.write_byte(0xFD)
      w.write_u32(0x60)
    }
    V128AnyTrue => {
      w.write_byte(0xFD)
      w.write_u32(0x53)
    }
    V128Bitselect => {
      w.write_byte(0xFD)
      w.write_u32(0x52)
    }
    V128Xor => {
      w.write_byte(0xFD)
      w.write_u32(0x51)
    }
    V128Or => {
      w.write_byte(0xFD)
      w.write_u32(0x50)
    }
    V128AndNot => {
      w.write_byte(0xFD)
      w.write_u32(0x4F)
    }
    V128And => {
      w.write_byte(0xFD)
      w.write_u32(0x4E)
    }
    V128Not => {
      w.write_byte(0xFD)
      w.write_u32(0x4D)
    }
    F64x2Ge => {
      w.write_byte(0xFD)
      w.write_u32(0x4C)
    }
    F64x2Le => {
      w.write_byte(0xFD)
      w.write_u32(0x4B)
    }
    F64x2Gt => {
      w.write_byte(0xFD)
      w.write_u32(0x4A)
    }
    F64x2Lt => {
      w.write_byte(0xFD)
      w.write_u32(0x49)
    }
    F64x2Ne => {
      w.write_byte(0xFD)
      w.write_u32(0x48)
    }
    F64x2Eq => {
      w.write_byte(0xFD)
      w.write_u32(0x47)
    }
    F32x4Ge => {
      w.write_byte(0xFD)
      w.write_u32(0x46)
    }
    F32x4Le => {
      w.write_byte(0xFD)
      w.write_u32(0x45)
    }
    F32x4Gt => {
      w.write_byte(0xFD)
      w.write_u32(0x44)
    }
    F32x4Lt => {
      w.write_byte(0xFD)
      w.write_u32(0x43)
    }
    F32x4Ne => {
      w.write_byte(0xFD)
      w.write_u32(0x42)
    }
    F32x4Eq => {
      w.write_byte(0xFD)
      w.write_u32(0x41)
    }
    I64x2GeS => {
      w.write_byte(0xFD)
      w.write_u32(0xDB)
    }
    I64x2LeS => {
      w.write_byte(0xFD)
      w.write_u32(0xDA)
    }
    I64x2GtS => {
      w.write_byte(0xFD)
      w.write_u32(0xD9)
    }
    I64x2LtS => {
      w.write_byte(0xFD)
      w.write_u32(0xD8)
    }
    I64x2Ne => {
      w.write_byte(0xFD)
      w.write_u32(0xD7)
    }
    I64x2Eq => {
      w.write_byte(0xFD)
      w.write_u32(0xD6)
    }
    I32x4GeU => {
      w.write_byte(0xFD)
      w.write_u32(0x40)
    }
    I32x4GeS => {
      w.write_byte(0xFD)
      w.write_u32(0x3F)
    }
    I32x4LeU => {
      w.write_byte(0xFD)
      w.write_u32(0x3E)
    }
    I32x4LeS => {
      w.write_byte(0xFD)
      w.write_u32(0x3D)
    }
    I32x4GtU => {
      w.write_byte(0xFD)
      w.write_u32(0x3C)
    }
    I32x4GtS => {
      w.write_byte(0xFD)
      w.write_u32(0x3B)
    }
    I32x4LtU => {
      w.write_byte(0xFD)
      w.write_u32(0x3A)
    }
    I32x4LtS => {
      w.write_byte(0xFD)
      w.write_u32(0x39)
    }
    I32x4Ne => {
      w.write_byte(0xFD)
      w.write_u32(0x38)
    }
    I32x4Eq => {
      w.write_byte(0xFD)
      w.write_u32(0x37)
    }
    I16x8GeU => {
      w.write_byte(0xFD)
      w.write_u32(0x36)
    }
    I16x8GeS => {
      w.write_byte(0xFD)
      w.write_u32(0x35)
    }
    I16x8LeU => {
      w.write_byte(0xFD)
      w.write_u32(0x34)
    }
    I16x8LeS => {
      w.write_byte(0xFD)
      w.write_u32(0x33)
    }
    I16x8GtU => {
      w.write_byte(0xFD)
      w.write_u32(0x32)
    }
    I16x8GtS => {
      w.write_byte(0xFD)
      w.write_u32(0x31)
    }
    I16x8LtU => {
      w.write_byte(0xFD)
      w.write_u32(0x30)
    }
    I16x8LtS => {
      w.write_byte(0xFD)
      w.write_u32(0x2F)
    }
    I16x8Ne => {
      w.write_byte(0xFD)
      w.write_u32(0x2E)
    }
    I16x8Eq => {
      w.write_byte(0xFD)
      w.write_u32(0x2D)
    }
    I8x16GeU => {
      w.write_byte(0xFD)
      w.write_u32(0x2C)
    }
    I8x16GeS => {
      w.write_byte(0xFD)
      w.write_u32(0x2B)
    }
    I8x16LeU => {
      w.write_byte(0xFD)
      w.write_u32(0x2A)
    }
    I8x16LeS => {
      w.write_byte(0xFD)
      w.write_u32(0x29)
    }
    I8x16GtU => {
      w.write_byte(0xFD)
      w.write_u32(0x28)
    }
    I8x16GtS => {
      w.write_byte(0xFD)
      w.write_u32(0x27)
    }
    I8x16LtU => {
      w.write_byte(0xFD)
      w.write_u32(0x26)
    }
    I8x16LtS => {
      w.write_byte(0xFD)
      w.write_u32(0x25)
    }
    I8x16Ne => {
      w.write_byte(0xFD)
      w.write_u32(0x24)
    }
    I8x16Eq => {
      w.write_byte(0xFD)
      w.write_u32(0x23)
    }
    F64x2ReplaceLane(lane) => {
      w.write_byte(0xFD)
      w.write_u32(0x22)
      w.write_byte(lane)
    }
    F32x4ReplaceLane(lane) => {
      w.write_byte(0xFD)
      w.write_u32(0x20)
      w.write_byte(lane)
    }
    I64x2ReplaceLane(lane) => {
      w.write_byte(0xFD)
      w.write_u32(0x1E)
      w.write_byte(lane)
    }
    I32x4ReplaceLane(lane) => {
      w.write_byte(0xFD)
      w.write_u32(0x1C)
      w.write_byte(lane)
    }
    I16x8ReplaceLane(lane) => {
      w.write_byte(0xFD)
      w.write_u32(0x1A)
      w.write_byte(lane)
    }
    I8x16ReplaceLane(lane) => {
      w.write_byte(0xFD)
      w.write_u32(0x17)
      w.write_byte(lane)
    }
    F64x2ExtractLane(lane) => {
      w.write_byte(0xFD)
      w.write_u32(0x21)
      w.write_byte(lane)
    }
    F32x4ExtractLane(lane) => {
      w.write_byte(0xFD)
      w.write_u32(0x1F)
      w.write_byte(lane)
    }
    I64x2ExtractLane(lane) => {
      w.write_byte(0xFD)
      w.write_u32(0x1D)
      w.write_byte(lane)
    }
    I32x4ExtractLane(lane) => {
      w.write_byte(0xFD)
      w.write_u32(0x1B)
      w.write_byte(lane)
    }
    I16x8ExtractLaneU(lane) => {
      w.write_byte(0xFD)
      w.write_u32(0x19)
      w.write_byte(lane)
    }
    I16x8ExtractLaneS(lane) => {
      w.write_byte(0xFD)
      w.write_u32(0x18)
      w.write_byte(lane)
    }
    I8x16ExtractLaneU(lane) => {
      w.write_byte(0xFD)
      w.write_u32(0x16)
      w.write_byte(lane)
    }
    I8x16ExtractLaneS(lane) => {
      w.write_byte(0xFD)
      w.write_u32(0x15)
      w.write_byte(lane)
    }
    F64x2Splat => {
      w.write_byte(0xFD)
      w.write_u32(0x14)
    }
    F32x4Splat => {
      w.write_byte(0xFD)
      w.write_u32(0x13)
    }
    I64x2Splat => {
      w.write_byte(0xFD)
      w.write_u32(0x12)
    }
    I32x4Splat => {
      w.write_byte(0xFD)
      w.write_u32(0x11)
    }
    I16x8Splat => {
      w.write_byte(0xFD)
      w.write_u32(0x10)
    }
    I8x16Splat => {
      w.write_byte(0xFD)
      w.write_u32(0x0F)
    }
    I8x16Swizzle => {
      w.write_byte(0xFD)
      w.write_u32(0x0E)
    }
    I8x16Shuffle(lanes) => {
      w.write_byte(0xFD)
      w.write_u32(0x0D)
      for lane in lanes {
        w.write_byte(lane)
      }
    }
    V128Store64Lane(memidx, align, offset, lane) => {
      w.write_byte(0xFD)
      w.write_u32(0x5B)
      encode_memarg(w, memidx, align, offset)
      w.write_byte(lane)
    }
    V128Store32Lane(memidx, align, offset, lane) => {
      w.write_byte(0xFD)
      w.write_u32(0x5A)
      encode_memarg(w, memidx, align, offset)
      w.write_byte(lane)
    }
    V128Store16Lane(memidx, align, offset, lane) => {
      w.write_byte(0xFD)
      w.write_u32(0x59)
      encode_memarg(w, memidx, align, offset)
      w.write_byte(lane)
    }
    V128Store8Lane(memidx, align, offset, lane) => {
      w.write_byte(0xFD)
      w.write_u32(0x58)
      encode_memarg(w, memidx, align, offset)
      w.write_byte(lane)
    }
    V128Load64Lane(memidx, align, offset, lane) => {
      w.write_byte(0xFD)
      w.write_u32(0x57)
      encode_memarg(w, memidx, align, offset)
      w.write_byte(lane)
    }
    V128Load32Lane(memidx, align, offset, lane) => {
      w.write_byte(0xFD)
      w.write_u32(0x56)
      encode_memarg(w, memidx, align, offset)
      w.write_byte(lane)
    }
    V128Load16Lane(memidx, align, offset, lane) => {
      w.write_byte(0xFD)
      w.write_u32(0x55)
      encode_memarg(w, memidx, align, offset)
      w.write_byte(lane)
    }
    V128Load8Lane(memidx, align, offset, lane) => {
      w.write_byte(0xFD)
      w.write_u32(0x54)
      encode_memarg(w, memidx, align, offset)
      w.write_byte(lane)
    }
    V128Load64Zero(memidx, align, offset) => {
      w.write_byte(0xFD)
      w.write_u32(0x5D)
      encode_memarg(w, memidx, align, offset)
    }
    V128Load32Zero(memidx, align, offset) => {
      w.write_byte(0xFD)
      w.write_u32(0x5C)
      encode_memarg(w, memidx, align, offset)
    }
    V128Load64Splat(memidx, align, offset) => {
      w.write_byte(0xFD)
      w.write_u32(0x0A)
      encode_memarg(w, memidx, align, offset)
    }
    V128Load32Splat(memidx, align, offset) => {
      w.write_byte(0xFD)
      w.write_u32(0x09)
      encode_memarg(w, memidx, align, offset)
    }
    V128Load16Splat(memidx, align, offset) => {
      w.write_byte(0xFD)
      w.write_u32(0x08)
      encode_memarg(w, memidx, align, offset)
    }
    V128Load8Splat(memidx, align, offset) => {
      w.write_byte(0xFD)
      w.write_u32(0x07)
      encode_memarg(w, memidx, align, offset)
    }
    V128Load32x2U(memidx, align, offset) => {
      w.write_byte(0xFD)
      w.write_u32(0x06)
      encode_memarg(w, memidx, align, offset)
    }
    V128Load32x2S(memidx, align, offset) => {
      w.write_byte(0xFD)
      w.write_u32(0x05)
      encode_memarg(w, memidx, align, offset)
    }
    V128Load16x4U(memidx, align, offset) => {
      w.write_byte(0xFD)
      w.write_u32(0x04)
      encode_memarg(w, memidx, align, offset)
    }
    V128Load16x4S(memidx, align, offset) => {
      w.write_byte(0xFD)
      w.write_u32(0x03)
      encode_memarg(w, memidx, align, offset)
    }
    V128Load8x8U(memidx, align, offset) => {
      w.write_byte(0xFD)
      w.write_u32(0x02)
      encode_memarg(w, memidx, align, offset)
    }
    V128Load8x8S(memidx, align, offset) => {
      w.write_byte(0xFD)
      w.write_u32(0x01)
      encode_memarg(w, memidx, align, offset)
    }
    I64MulWideU => {
      w.write_byte(0xFC)
      w.write_u32(0x16)
    }
    I64Add128 => {
      w.write_byte(0xFC)
      w.write_u32(0x13)
    }
    I64Sub128 => {
      w.write_byte(0xFC)
      w.write_u32(0x14)
    }
    I64MulWideS => {
      w.write_byte(0xFC)
      w.write_u32(0x15)
    }
    I32x4RelaxedDotI8x16I7x16AddS => {
      w.write_byte(0xFD)
      w.write_u32(0x113)
    }
  }
}
