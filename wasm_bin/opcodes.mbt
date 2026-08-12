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
    // Modelled but not encodable yet. Upstream wrote `0x00` here -- a valid
    // `unreachable`, in place of whatever the instruction actually was.
    _ => raise UnsupportedInstruction(instr)
  }
}
