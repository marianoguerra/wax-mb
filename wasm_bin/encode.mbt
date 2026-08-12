// The binary encoder: a `Module` to the bytes of a `.wasm` file.
//
// Vendored from Milky2018/wasm_core 0.5.0 (Apache-2.0) and then changed; see
// VENDORED.md. The opcode table is upstream's and is the reason to vendor at
// all -- roughly 700 lines of it, which is 700 lines not hand-ported from
// wasm_output.ml. Everything around it is rewritten.
//
// `BinaryWriter` is deliberately kept as the seam even though it now writes
// into a `@buffer.Buffer` rather than an `Array[Int]`: `write_byte` still takes
// an `Int`, so the whole opcode table transfers untouched and the one place
// that has to know about `Byte` is the one place that writes one.

///|
/// A module that cannot be encoded as it stands.
///
/// Upstream had no such error. It emitted `0x00` -- `unreachable` -- for any
/// instruction its match did not cover, and an empty block type for any block
/// whose signature had not been resolved to a type index. Both produce a wasm
/// file that loads, validates and runs, and silently does the wrong thing;
/// against a differential harness that is the worst possible failure mode,
/// because the diff says "these bytes differ" rather than "this is unhandled".
pub suberror EncodeError {
  /// A block's signature was still inline. It has to become a type index, and
  /// interning it is the lowering's job, not the encoder's.
  UnresolvedBlockType
  /// An instruction the opcode table does not cover yet.
  ///
  /// 256 of them, and removing the catch-all is what counted them: the whole of
  /// SIMD beyond loads and stores, `i64.mul_wide_s`/`_u`, and every atomic.
  /// They are modelled but not encoded, which upstream did not distinguish from
  /// encoded -- see VENDORED.md, where the list is the work item.
  UnsupportedInstruction(Instruction)
} derive(Eq, Debug)

///|
pub impl Show for EncodeError with fn output(self, logger) {
  logger.write_string(
    match self {
      UnresolvedBlockType =>
        "block type is still inline; intern it as a type index before encoding"
      UnsupportedInstruction(instr) =>
        "instruction not encodable yet: " + @debug.to_string(instr)
    },
  )
}

// ============ Binary writer ============

///|
priv struct BinaryWriter {
  buf : @buffer.Buffer
}

///|
fn BinaryWriter::new() -> BinaryWriter {
  { buf: @buffer.Buffer::Buffer() }
}

///|
fn BinaryWriter::write_byte(self : BinaryWriter, b : Int) -> Unit {
  self.buf.write_byte((b & 0xFF).to_byte())
}

///|
fn BinaryWriter::write_bytes(self : BinaryWriter, bytes : Bytes) -> Unit {
  self.buf.write_bytes(bytes[:])
}

///|
/// Unsigned LEB128, from a value that is logically a u32.
///
/// A negative `Int` here means an index at or above 2^31, which is legal in the
/// binary format and arrives as a wrapped-around `Int`. Widening through
/// `UInt` rather than sign-extending is what keeps that from encoding as ten
/// bytes of sign extension.
fn BinaryWriter::write_u32(self : BinaryWriter, val : Int) -> Unit {
  let mut v = val.reinterpret_as_uint()
  while true {
    let byte = (v & 0x7F).reinterpret_as_int()
    v = v >> 7
    if v == 0 {
      self.write_byte(byte)
      break
    }
    self.write_byte(byte | 0x80)
  }
}

///|
/// Unsigned LEB128, 64-bit.
fn BinaryWriter::write_u64(self : BinaryWriter, val : UInt64) -> Unit {
  let mut v = val
  while true {
    let byte = (v & 0x7F).to_int()
    v = v >> 7
    if v == 0 {
      self.write_byte(byte)
      break
    }
    self.write_byte(byte | 0x80)
  }
}

///|
/// Signed LEB128, 32-bit.
fn BinaryWriter::write_s32(self : BinaryWriter, val : Int) -> Unit {
  let mut v = val
  while true {
    let byte = v & 0x7F
    v = v >> 7
    let sign_bit = (byte & 0x40) != 0
    if (v == 0 && !sign_bit) || (v == -1 && sign_bit) {
      self.write_byte(byte)
      break
    }
    self.write_byte(byte | 0x80)
  }
}

///|
/// Signed LEB128, 64-bit.
fn BinaryWriter::write_s64(self : BinaryWriter, val : Int64) -> Unit {
  let mut v = val
  while true {
    let byte = (v & 0x7FL).to_int()
    v = v >> 7
    let sign_bit = (byte & 0x40) != 0
    if (v == 0L && !sign_bit) || (v == -1L && sign_bit) {
      self.write_byte(byte)
      break
    }
    self.write_byte(byte | 0x80)
  }
}

///|
/// A length-prefixed byte vector -- what the format calls a `name`.
///
/// Names are byte vectors, not strings, which is also how the Wax AST carries
/// them. Upstream took a `String` and re-encoded it to UTF-8 by hand on the way
/// out; going through `Bytes` end to end removes both the conversion and the
/// chance of disagreeing with the front end about what a name is.
fn BinaryWriter::write_name(self : BinaryWriter, name : Bytes) -> Unit {
  self.write_u32(name.length())
  self.write_bytes(name)
}

///|
/// f32, little-endian. The bit pattern goes through untouched, so a signalling
/// NaN keeps its payload.
fn BinaryWriter::write_f32(self : BinaryWriter, val : Float) -> Unit {
  let bits = val.reinterpret_as_int()
  for i in 0..<4 {
    self.write_byte(bits >> (i * 8))
  }
}

///|
/// f64, little-endian, likewise payload-preserving.
fn BinaryWriter::write_f64(self : BinaryWriter, val : Double) -> Unit {
  let bits = val.reinterpret_as_int64()
  for i in 0..<8 {
    self.write_byte((bits >> (i * 8)).to_int())
  }
}

///|
fn BinaryWriter::to_bytes(self : BinaryWriter) -> Bytes {
  self.buf.to_bytes()
}

// ============ Types ============

///|
/// A heap type.
///
/// A concrete index is an **s33**, not a u32: the format reuses the same slot
/// for the negative one-byte codes above, so a positive index has to be written
/// as a signed LEB or it collides with them at 64 and beyond.
fn encode_heaptype(w : BinaryWriter, ht : HeapType) -> Unit {
  match ht {
    Func => w.write_byte(0x70)
    Extern => w.write_byte(0x6F)
    Any => w.write_byte(0x6E)
    None_ => w.write_byte(0x71)
    NoExtern => w.write_byte(0x72)
    NoFunc => w.write_byte(0x73)
    Eq => w.write_byte(0x6D)
    Struct => w.write_byte(0x6B)
    Array => w.write_byte(0x6A)
    I31 => w.write_byte(0x6C)
    Exn => w.write_byte(0x69)
    NoExn => w.write_byte(0x74)
    Cont => w.write_byte(0x68)
    NoCont => w.write_byte(0x75)
    Type(idx) => w.write_s32(idx)
    Exact(idx) => {
      w.write_byte(0x62)
      w.write_u32(idx)
    }
  }
}

///|
/// A reference type.
///
/// A nullable reference to an ABSTRACT heap type has a one-byte abbreviation --
/// `funcref`, `anyref`, `eqref` and the rest are exactly that -- and every real
/// producer uses it. Upstream's flat enum could not express the choice, so it
/// picked per constructor and came out inconsistent: `funcref` short, `anyref`
/// long. Two encodings of the same type are both valid and differ in bytes,
/// which is precisely what a byte-identity oracle cannot tolerate.
fn encode_reftype(w : BinaryWriter, rt : RefType) -> Unit {
  let abstract_ = match rt.typ {
    Type(_) | Exact(_) => false
    _ => true
  }
  if rt.nullable && abstract_ {
    encode_heaptype(w, rt.typ)
    return
  }
  w.write_byte(if rt.nullable { 0x63 } else { 0x64 })
  encode_heaptype(w, rt.typ)
}

///|
fn encode_valtype(w : BinaryWriter, vt : ValType) -> Unit {
  match vt {
    I32 => w.write_byte(0x7F)
    I64 => w.write_byte(0x7E)
    F32 => w.write_byte(0x7D)
    F64 => w.write_byte(0x7C)
    V128 => w.write_byte(0x7B)
    Ref(rt) => encode_reftype(w, rt)
  }
}

///|
fn encode_storage_type(w : BinaryWriter, st : StorageType) -> Unit {
  match st {
    Value(vt) => encode_valtype(w, vt)
    Packed(I8) => w.write_byte(0x78)
    Packed(I16) => w.write_byte(0x77)
  }
}

///|
fn encode_field_type(w : BinaryWriter, ft : FieldType) -> Unit {
  encode_storage_type(w, ft.typ)
  w.write_byte(if ft.mut_ { 1 } else { 0 })
}

///|
fn encode_func_type(w : BinaryWriter, ft : FuncType) -> Unit {
  w.write_byte(0x60)
  w.write_u32(ft.params.length())
  for p in ft.params {
    encode_valtype(w, p)
  }
  w.write_u32(ft.results.length())
  for r in ft.results {
    encode_valtype(w, r)
  }
}

///|
fn encode_composite_type(w : BinaryWriter, ct : CompositeType) -> Unit {
  match ct {
    Func(ft) => encode_func_type(w, ft)
    Struct(st) => {
      w.write_byte(0x5F)
      w.write_u32(st.fields.length())
      for f in st.fields {
        encode_field_type(w, f)
      }
    }
    Array(at) => {
      w.write_byte(0x5E)
      encode_field_type(w, at.element)
    }
  }
}

///|
/// A defined type. Final with no supertype is the common case and has a
/// shorthand: the composite type on its own, with no `sub` prefix at all.
fn encode_subtype(w : BinaryWriter, st : SubType) -> Unit {
  if st.final_ && st.supertypes.is_empty() {
    encode_composite_type(w, st.composite)
    return
  }
  w.write_byte(if st.final_ { 0x4F } else { 0x50 })
  w.write_u32(st.supertypes.length())
  for idx in st.supertypes {
    w.write_u32(idx)
  }
  encode_composite_type(w, st.composite)
}

///|
/// Limits, shared by memories and tables.
///
/// The flags byte carries four independent facts, which is why upstream needed
/// two near-identical copies of this function and a bool argument to pick
/// between them: 0x01 a maximum is present, 0x02 shared, 0x04 the 64-bit index
/// type, 0x08 a custom page size follows. `shared` upstream could not represent
/// at all.
fn encode_limits(w : BinaryWriter, l : Limits) -> Unit {
  let is64 = l.address_type is I64
  let mut flags = 0
  if l.ma is Some(_) {
    flags = flags | 0x01
  }
  if l.shared {
    flags = flags | 0x02
  }
  if is64 {
    flags = flags | 0x04
  }
  if l.page_size_log2 is Some(_) {
    flags = flags | 0x08
  }
  w.write_byte(flags)
  if is64 {
    w.write_u64(l.mi)
    if l.ma is Some(ma) {
      w.write_u64(ma)
    }
  } else {
    w.write_u32(l.mi.to_int())
    if l.ma is Some(ma) {
      w.write_u32(ma.to_int())
    }
  }
  if l.page_size_log2 is Some(log2) {
    w.write_u32(log2)
  }
}

///|
fn encode_table_type(w : BinaryWriter, tt : TableType) -> Unit {
  encode_reftype(w, tt.elem_type)
  encode_limits(w, tt.limits)
}

///|
fn encode_global_type(w : BinaryWriter, gt : GlobalType) -> Unit {
  encode_valtype(w, gt.typ)
  w.write_byte(if gt.mut_ { 1 } else { 0 })
}

// ============ Instructions ============

///|
/// A block's signature.
///
/// `MultiValue` and `InlineType` have no encoding: the format spells anything
/// beyond a single result as a type index. Upstream wrote `0x40` -- the empty
/// block type -- for both, silently dropping the results.
fn encode_block_type(
  w : BinaryWriter,
  bt : BlockType,
) -> Unit raise EncodeError {
  match bt {
    Empty => w.write_byte(0x40)
    Value(vt) => encode_valtype(w, vt)
    TypeIndex(idx) => w.write_s32(idx)
    MultiValue(_) | InlineType(_, _) => raise UnresolvedBlockType
  }
}

///|
/// A memory argument.
///
/// Multi-memory rides in the alignment field: bit 6 set means a memory index
/// follows. Upstream ignored the index entirely -- its parameter was named
/// `_memidx` -- so every access to a memory other than 0 was silently encoded
/// as an access to memory 0.
fn encode_memarg(
  w : BinaryWriter,
  memidx : Int,
  align : Int,
  offset : Int64,
) -> Unit {
  if memidx == 0 {
    w.write_u32(align)
  } else {
    w.write_u32(align | (1 << 6))
    w.write_u32(memidx)
  }
  w.write_u64(offset.reinterpret_as_uint64())
}

///|
/// The nullability bits `br_on_cast` and `br_on_cast_fail` carry ahead of their
/// two heap types.
fn cast_flags(from : RefType, to : RefType) -> Int {
  (if from.nullable { 1 } else { 0 }) | (if to.nullable { 2 } else { 0 })
}

///|
fn encode_instructions(
  w : BinaryWriter,
  instrs : Array[Instruction],
) -> Unit raise EncodeError {
  for instr in instrs {
    encode_instruction(w, instr)
  }
}

///|
/// An expression: instructions followed by the `end` marker.
fn encode_expr(
  w : BinaryWriter,
  instrs : Array[Instruction],
) -> Unit raise EncodeError {
  encode_instructions(w, instrs)
  w.write_byte(0x0B)
}

///|
fn encode_catch_handler(w : BinaryWriter, handler : CatchHandler) -> Unit {
  match handler {
    Catch(tag_idx, label) => {
      w.write_byte(0x00)
      w.write_u32(tag_idx)
      w.write_u32(label)
    }
    CatchRef(tag_idx, label) => {
      w.write_byte(0x01)
      w.write_u32(tag_idx)
      w.write_u32(label)
    }
    CatchAll(label) => {
      w.write_byte(0x02)
      w.write_u32(label)
    }
    CatchAllRef(label) => {
      w.write_byte(0x03)
      w.write_u32(label)
    }
  }
}
