// The binary form of a WebAssembly module: indices resolved, ready to encode.
//
// Vendored from Milky2018/wasm_core 0.5.0 (Apache-2.0) and then changed; see
// VENDORED.md for what and why. The short version: the model is upstream's, the
// type spine is ours.
//
// THE SEAM, from the other side. `wasm_types` is generic over `Idx` precisely so
// two instances of the type family exist without duplicating it: Wax names its
// types (`Idx = @ast.Ident`), the binary form numbers them (`Idx = Int`). This
// package is that second instance, so it supplies the four wrapper-carrying
// types -- functype, comptype, subtype, rectype -- that `wasm_types` leaves to
// each instance, and takes everything else from the shared spine.
//
// Upstream had its own flat `ValueType`: 31 constructors enumerating the ref
// types somebody happened to need (`RefStruct`, `RefNullFuncTyped`, ...). It
// cannot spell `(ref null $t)` for a `$t` that is not a func, struct or array,
// has no `exact` and no `cont`, and -- because nullability is baked into the
// constructor name rather than carried as a field -- it forced `ref.test` and
// `ref.test null` apart into two instructions that differ only in a flag. All
// of that goes away here.

///|
/// A value type, at the binary form's index instantiation.
pub type ValType = @wasm_types.ValType[Int]

///|
/// A reference type: nullability plus what it points at.
pub type RefType = @wasm_types.RefType[Int]

///|
/// What a reference can point at.
pub type HeapType = @wasm_types.HeapType[Int]

///|
/// What a struct field or array element stores.
pub type StorageType = @wasm_types.StorageType[Int]

///|
/// A struct field or array element type: a storage type plus mutability.
pub type FieldType = @wasm_types.FieldType[Int]

///|
/// A global's type: a value type plus mutability.
pub type GlobalType = @wasm_types.GlobalType[Int]

///|
/// The size bounds of a memory or table.
///
/// Upstream split this into a bare `{min, max}` plus `is_memory64`,
/// `page_size_log2` and `is_table64` fields hung off the memory and table types.
/// The shared spine already carries all of them, and carries `shared` besides,
/// which upstream cannot express at all -- so a shared memory was silently
/// unrepresentable there.
pub type Limits = @wasm_types.Limits

// ============================================================
// Defined types
// ============================================================

///|
/// A function type.
pub(all) struct FuncType {
  params : Array[ValType]
  results : Array[ValType]
} derive(Eq, Debug)

///|
/// A struct type.
pub(all) struct StructType {
  fields : Array[FieldType]
} derive(Eq, Debug)

///|
/// An array type.
pub(all) struct ArrayType {
  element : FieldType
} derive(Eq, Debug)

///|
/// What a defined type actually defines.
pub(all) enum CompositeType {
  Func(FuncType)
  Struct(StructType)
  Array(ArrayType)
  /// A continuation over the function type at this index -- the stack-switching
  /// proposal's `(cont $ft)`. Upstream had the switching INSTRUCTIONS nowhere
  /// and the type nowhere either; the instructions arrived first, but a module
  /// that uses them has to be able to define what they act on.
  Cont(Int)
} derive(Eq, Debug)

///|
/// A defined type, with its supertypes and whether it may be subtyped further.
///
/// `descriptor` and `describes` are the custom-descriptors proposal's two
/// clauses, and they come in pairs: `descriptor` names the type of this
/// struct's runtime descriptor, `describes` names the struct this one is the
/// descriptor OF. A type may carry either, both, or neither.
pub(all) struct SubType {
  final_ : Bool
  supertypes : Array[Int]
  descriptor : Int?
  describes : Int?
  composite : CompositeType
} derive(Eq, Debug)

///|
/// A run of defined types emitted as one `rec (...)`.
///
/// Upstream carried this as one group id per type and then never read it: the
/// type section wrote every type flat, so a module whose types referred to each
/// other came out as a set of unrelated definitions.
///
/// `explicit` is not redundant with `len == 1`. A singleton `rec` is a
/// different type from the same definition written bare -- recursive type
/// identity is by group -- so the encoder cannot infer the prefix from the
/// length, and what the source said has to be recorded.
pub(all) struct RecGroup {
  start : Int
  len : Int
  explicit : Bool
} derive(Eq, Debug)

///|
/// A subtype that is final and inherits from nothing -- the common case.
pub fn SubType::simple(composite : CompositeType) -> SubType {
  { final_: true, supertypes: [], descriptor: None, describes: None, composite }
}

///|
/// A final function type, from its parameters and results.
pub fn SubType::func(
  params : Array[ValType],
  results : Array[ValType],
) -> SubType {
  SubType::simple(Func({ params, results }))
}

// ============================================================
// Instructions
// ============================================================

///|
pub(all) enum Instruction {
  // Control instructions
  Unreachable
  Nop
  Block(BlockType, Array[Instruction])
  Loop(BlockType, Array[Instruction])
  If(BlockType, Array[Instruction], Array[Instruction])
  Br(Int) // label index
  BrIf(Int)
  BrTable(Array[Int], Int) // labels, default
  Return
  Call(Int) // function index
  CallIndirect(Int, Int) // type index, table index
  CallRef(Int) // type index (WasmGC)
  ReturnCall(Int) // function index (tail call)
  ReturnCallIndirect(Int, Int) // type index, table index (tail call)
  ReturnCallRef(Int) // type index (tail call, WasmGC)

  // Exception handling instructions
  Throw(Int) // tag index - throw exception with tag
  ThrowRef // throw exception from exnref on stack
  TryTable(BlockType, Array[CatchHandler], Array[Instruction]) // block type, handlers, body
  /// The DEPRECATED legacy handler: block type, body, per-tag catches, and an
  /// optional catch-all. Unlike `try_table`, whose handlers are immediates that
  /// branch out, these handlers are inline bodies that run in place.
  LegacyTry(
    BlockType,
    Array[Instruction],
    Array[(Int, Array[Instruction])],
    Array[Instruction]?
  )

  // Parametric instructions
  Drop
  Select
  SelectTyped(Array[ValType]) // select with explicit result type

  // Variable instructions
  LocalGet(Int)
  LocalSet(Int)
  LocalTee(Int)
  GlobalGet(Int)
  GlobalSet(Int)

  // Table instructions
  TableGet(Int) // table index
  TableSet(Int) // table index
  TableSize(Int) // table index
  TableGrow(Int) // table index
  TableFill(Int) // table index
  TableCopy(Int, Int) // dest table index, src table index
  /// The TABLE index first, then the element segment -- and, as for
  /// `MemoryInit`, the encoding writes them the other way round.
  TableInit(Int, Int)

  // Memory instructions - (memidx, align, offset)
  // offset is Int64 to support memory64 64-bit offsets
  I32Load(Int, Int, Int64) // memidx, align, offset
  I64Load(Int, Int, Int64)
  F32Load(Int, Int, Int64)
  F64Load(Int, Int, Int64)
  I32Load8S(Int, Int, Int64)
  I32Load8U(Int, Int, Int64)
  I32Load16S(Int, Int, Int64)
  I32Load16U(Int, Int, Int64)
  I64Load8S(Int, Int, Int64)
  I64Load8U(Int, Int, Int64)
  I64Load16S(Int, Int, Int64)
  I64Load16U(Int, Int, Int64)
  I64Load32S(Int, Int, Int64)
  I64Load32U(Int, Int, Int64)
  I32Store(Int, Int, Int64)
  I64Store(Int, Int, Int64)
  F32Store(Int, Int, Int64)
  F64Store(Int, Int, Int64)
  I32Store8(Int, Int, Int64)
  I32Store16(Int, Int, Int64)
  I64Store8(Int, Int, Int64)
  I64Store16(Int, Int, Int64)
  I64Store32(Int, Int, Int64)
  MemorySize(Int) // memidx
  MemoryGrow(Int) // memidx
  /// The MEMORY index first, then the data segment. Note the encoding writes
  /// them the other way round -- segment, then memory -- which is exactly why
  /// the order is stated here rather than left to be inferred from the bytes.
  MemoryInit(Int, Int)
  DataDrop(Int) // data segment index
  MemoryCopy(Int, Int) // dest memidx, src memidx
  MemoryFill(Int) // memidx
  ElemDrop(Int) // element segment index

  // Atomic instructions (0xFE prefix)
  /// The 0xFE sub-opcode FIRST, then the memarg: memory index, alignment
  /// exponent, offset. The sub-opcode leads because that is the order the
  /// bytes go out in, and naming it second invited reading the memory index
  /// as the opcode.
  Atomic(Int, Int, Int, Int64)
  /// `atomic.fence`, which unlike every other atomic has no memory operand.
  AtomicFence

  // Stack switching. Absent from upstream entirely -- the model had no way to
  // say any of this -- though the Wax AST has had all seven since Phase 2.
  ContNew(Int) // type index
  ContBind(Int, Int) // source type index, target type index
  Suspend(Int) // tag index
  Resume(Int, Array[OnClause]) // type index, resume table
  ResumeThrow(Int, Int, Array[OnClause]) // type index, tag index, resume table
  ResumeThrowRef(Int, Array[OnClause]) // type index, resume table
  Switch(Int, Int) // type index, tag index
  /// An instruction with compilation hints on it.
  ///
  /// A wrapper rather than a field on every instruction: hints are rare, the
  /// enum is 500 constructors wide, and the encoder needs exactly one place to
  /// notice them. It emits no opcode of its own.
  Hinted(InstrHints, Instruction)
  /// A constant, with the text the source wrote it as.
  ///
  /// A literal is not its value: `0x4` and `4` are the same i32 and two
  /// different programs to read, and `0x1.4p+3` does not come back from the
  /// bits of the float it denotes. The binary encodes the value and forgets
  /// the spelling; the text format writes what was written, so the spelling
  /// rides along on the instruction the way a branch hint does.
  ///
  /// Carries no opcode of its own -- the encoder unwraps it.
  Spelled(String, Instruction)
  /// An array construction that the source wrote as a STRING literal.
  ///
  /// The literal lowers to one constant per byte and an `array.new_fixed` over
  /// them; the text format writes `(@string "...")` and lets the reader assume
  /// the rest. Nothing in a run of constants says it was ever text, so the
  /// bytes are carried here.
  ///
  /// Carries no opcode of its own either.
  FromString(Bytes, Instruction)

  // Reference type instructions
  RefNull(HeapType) // ref.null: push a null reference to this heap type
  RefIsNull // ref.is_null: test if reference is null
  RefFunc(Int) // ref.func: push reference to function by index
  RefAsNonNull // ref.as_non_null: convert nullable ref to non-null ref
  RefEqInstr // ref.eq: compare two references for equality
  BrOnNull(Int) // br_on_null: branch if reference is null
  BrOnNonNull(Int) // br_on_non_null: branch if reference is non-null

  // Numeric instructions - Constants
  I32Const(Int)
  I64Const(Int64)
  F32Const(Float)
  F64Const(Double)

  // Numeric instructions - i32
  I32Eqz
  I32Eq
  I32Ne
  I32LtS
  I32LtU
  I32GtS
  I32GtU
  I32LeS
  I32LeU
  I32GeS
  I32GeU
  I32Clz
  I32Ctz
  I32Popcnt
  I32Add
  I32Sub
  I32Mul
  I32DivS
  I32DivU
  I32RemS
  I32RemU
  I32And
  I32Or
  I32Xor
  I32Shl
  I32ShrS
  I32ShrU
  I32Rotl
  I32Rotr
  // Sign-extension operators
  I32Extend8S
  I32Extend16S

  // Numeric instructions - i64
  I64Eqz
  I64Eq
  I64Ne
  I64LtS
  I64LtU
  I64GtS
  I64GtU
  I64LeS
  I64LeU
  I64GeS
  I64GeU
  I64Clz
  I64Ctz
  I64Popcnt
  I64Add
  I64Sub
  I64Mul
  I64MulWideS
  I64MulWideU
  I64Add128
  I64Sub128
  I64DivS
  I64DivU
  I64RemS
  I64RemU
  I64And
  I64Or
  I64Xor
  I64Shl
  I64ShrS
  I64ShrU
  I64Rotl
  I64Rotr
  // Sign-extension operators
  I64Extend8S
  I64Extend16S
  I64Extend32S

  // Numeric instructions - f32
  F32Eq
  F32Ne
  F32Lt
  F32Gt
  F32Le
  F32Ge
  F32Abs
  F32Neg
  F32Ceil
  F32Floor
  F32Trunc
  F32Nearest
  F32Sqrt
  F32Add
  F32Sub
  F32Mul
  F32Div
  F32Min
  F32Max
  F32Copysign

  // Numeric instructions - f64
  F64Eq
  F64Ne
  F64Lt
  F64Gt
  F64Le
  F64Ge
  F64Abs
  F64Neg
  F64Ceil
  F64Floor
  F64Trunc
  F64Nearest
  F64Sqrt
  F64Add
  F64Sub
  F64Mul
  F64Div
  F64Min
  F64Max
  F64Copysign

  // Conversion instructions
  I32WrapI64
  I32TruncF32S
  I32TruncF32U
  I32TruncF64S
  I32TruncF64U
  I64ExtendI32S
  I64ExtendI32U
  I64TruncF32S
  I64TruncF32U
  I64TruncF64S
  I64TruncF64U
  F32ConvertI32S
  F32ConvertI32U
  F32ConvertI64S
  F32ConvertI64U
  F32DemoteF64
  F64ConvertI32S
  F64ConvertI32U
  F64ConvertI64S
  F64ConvertI64U
  F64PromoteF32
  I32ReinterpretF32
  I64ReinterpretF64
  F32ReinterpretI32
  F64ReinterpretI64

  // Saturating truncation instructions (nontrapping float-to-int)
  I32TruncSatF32S
  I32TruncSatF32U
  I32TruncSatF64S
  I32TruncSatF64U
  I64TruncSatF32S
  I64TruncSatF32U
  I64TruncSatF64S
  I64TruncSatF64U

  // GC instructions - struct operations
  /// The custom-descriptors forms: like `struct.new` and its default sibling,
  /// but taking the runtime DESCRIPTOR as a further operand, pushed last --
  /// above the field values, because that is the order the instruction reads.
  StructNewDesc(Int)
  StructNewDefaultDesc(Int)
  /// A struct's own descriptor, read back off it.
  RefGetDesc(Int)
  /// A cast that tests a value against a DESCRIPTOR rather than against a type
  /// immediate: the descriptor is an operand, so the same instruction can test
  /// against a descriptor only known at run time.
  RefCastDescEq(RefType)
  /// The branching forms of the same test. Both reference types are immediates
  /// and their nullability rides in one byte before the label.
  BrOnCastDescEq(Int, RefType, RefType)
  BrOnCastDescEqFail(Int, RefType, RefType)
  StructNew(Int) // type index
  StructNewDefault(Int) // type index
  StructGet(Int, Int) // type index, field index
  StructGetS(Int, Int) // type index, field index (signed packed)
  StructGetU(Int, Int) // type index, field index (unsigned packed)
  StructSet(Int, Int) // type index, field index

  // GC instructions - array operations
  ArrayNew(Int) // type index
  ArrayNewDefault(Int) // type index
  ArrayNewFixed(Int, Int) // type index, length
  ArrayNewData(Int, Int) // type index, data index
  ArrayNewElem(Int, Int) // type index, elem index
  ArrayGet(Int) // type index
  ArrayGetS(Int) // type index (signed packed)
  ArrayGetU(Int) // type index (unsigned packed)
  ArraySet(Int) // type index
  ArrayLen // get array length
  ArrayFill(Int) // type index
  ArrayCopy(Int, Int) // dest type index, src type index
  ArrayInitData(Int, Int) // type index, data index
  ArrayInitElem(Int, Int) // type index, elem index

  // GC instructions - reference casting
  RefTest(RefType) // ref.test: does the reference match this type?
  RefCast(RefType) // ref.cast: cast, trapping on failure
  BrOnCast(Int, RefType, RefType) // label, source type, target type
  BrOnCastFail(Int, RefType, RefType) // label, source type, target type

  // GC instructions - i31
  RefI31 // create i31ref from i32
  I31GetS // get signed i32 from i31ref
  I31GetU // get unsigned i32 from i31ref

  // GC instructions - type conversion
  AnyConvertExtern // convert externref to anyref
  ExternConvertAny // convert anyref to externref

  // ============================================================
  // SIMD Instructions (128-bit packed SIMD)
  // ============================================================

  // SIMD constants
  V128Const(Bytes) // 16-byte constant

  // SIMD load/store - (memidx, align, offset)
  V128Load(Int, Int, Int64)
  V128Load8x8S(Int, Int, Int64)
  V128Load8x8U(Int, Int, Int64)
  V128Load16x4S(Int, Int, Int64)
  V128Load16x4U(Int, Int, Int64)
  V128Load32x2S(Int, Int, Int64)
  V128Load32x2U(Int, Int, Int64)
  V128Load8Splat(Int, Int, Int64)
  V128Load16Splat(Int, Int, Int64)
  V128Load32Splat(Int, Int, Int64)
  V128Load64Splat(Int, Int, Int64)
  V128Load32Zero(Int, Int, Int64)
  V128Load64Zero(Int, Int, Int64)
  V128Store(Int, Int, Int64)

  // SIMD load/store lane - (memidx, align, offset, lane)
  V128Load8Lane(Int, Int, Int64, Int)
  V128Load16Lane(Int, Int, Int64, Int)
  V128Load32Lane(Int, Int, Int64, Int)
  V128Load64Lane(Int, Int, Int64, Int)
  V128Store8Lane(Int, Int, Int64, Int)
  V128Store16Lane(Int, Int, Int64, Int)
  V128Store32Lane(Int, Int, Int64, Int)
  V128Store64Lane(Int, Int, Int64, Int)

  // SIMD shuffle/swizzle
  I8x16Shuffle(FixedArray[Int]) // 16 lane indices
  I8x16Swizzle

  // SIMD splat (scalar -> vector)
  I8x16Splat
  I16x8Splat
  I32x4Splat
  I64x2Splat
  F32x4Splat
  F64x2Splat

  // SIMD extract lane (vector -> scalar)
  I8x16ExtractLaneS(Int)
  I8x16ExtractLaneU(Int)
  I16x8ExtractLaneS(Int)
  I16x8ExtractLaneU(Int)
  I32x4ExtractLane(Int)
  I64x2ExtractLane(Int)
  F32x4ExtractLane(Int)
  F64x2ExtractLane(Int)

  // SIMD replace lane (vector, scalar -> vector)
  I8x16ReplaceLane(Int)
  I16x8ReplaceLane(Int)
  I32x4ReplaceLane(Int)
  I64x2ReplaceLane(Int)
  F32x4ReplaceLane(Int)
  F64x2ReplaceLane(Int)

  // i8x16 comparisons
  I8x16Eq
  I8x16Ne
  I8x16LtS
  I8x16LtU
  I8x16GtS
  I8x16GtU
  I8x16LeS
  I8x16LeU
  I8x16GeS
  I8x16GeU

  // i16x8 comparisons
  I16x8Eq
  I16x8Ne
  I16x8LtS
  I16x8LtU
  I16x8GtS
  I16x8GtU
  I16x8LeS
  I16x8LeU
  I16x8GeS
  I16x8GeU

  // i32x4 comparisons
  I32x4Eq
  I32x4Ne
  I32x4LtS
  I32x4LtU
  I32x4GtS
  I32x4GtU
  I32x4LeS
  I32x4LeU
  I32x4GeS
  I32x4GeU

  // i64x2 comparisons
  I64x2Eq
  I64x2Ne
  I64x2LtS
  I64x2GtS
  I64x2LeS
  I64x2GeS

  // f32x4 comparisons
  F32x4Eq
  F32x4Ne
  F32x4Lt
  F32x4Gt
  F32x4Le
  F32x4Ge

  // f64x2 comparisons
  F64x2Eq
  F64x2Ne
  F64x2Lt
  F64x2Gt
  F64x2Le
  F64x2Ge

  // v128 bitwise operations
  V128Not
  V128And
  V128AndNot
  V128Or
  V128Xor
  V128Bitselect
  V128AnyTrue

  // i8x16 operations
  I8x16Abs
  I8x16Neg
  I8x16Popcnt
  I8x16AllTrue
  I8x16Bitmask
  I8x16NarrowI16x8S
  I8x16NarrowI16x8U
  I8x16Shl
  I8x16ShrS
  I8x16ShrU
  I8x16Add
  I8x16AddSatS
  I8x16AddSatU
  I8x16Sub
  I8x16SubSatS
  I8x16SubSatU
  I8x16MinS
  I8x16MinU
  I8x16MaxS
  I8x16MaxU
  I8x16AvgrU

  // i16x8 operations
  I16x8ExtAddPairwiseI8x16S
  I16x8ExtAddPairwiseI8x16U
  I16x8Abs
  I16x8Neg
  I16x8Q15MulrSatS
  I16x8AllTrue
  I16x8Bitmask
  I16x8NarrowI32x4S
  I16x8NarrowI32x4U
  I16x8ExtendLowI8x16S
  I16x8ExtendHighI8x16S
  I16x8ExtendLowI8x16U
  I16x8ExtendHighI8x16U
  I16x8Shl
  I16x8ShrS
  I16x8ShrU
  I16x8Add
  I16x8AddSatS
  I16x8AddSatU
  I16x8Sub
  I16x8SubSatS
  I16x8SubSatU
  I16x8Mul
  I16x8MinS
  I16x8MinU
  I16x8MaxS
  I16x8MaxU
  I16x8AvgrU
  I16x8ExtMulLowI8x16S
  I16x8ExtMulHighI8x16S
  I16x8ExtMulLowI8x16U
  I16x8ExtMulHighI8x16U

  // i32x4 operations
  I32x4ExtAddPairwiseI16x8S
  I32x4ExtAddPairwiseI16x8U
  I32x4Abs
  I32x4Neg
  I32x4AllTrue
  I32x4Bitmask
  I32x4ExtendLowI16x8S
  I32x4ExtendHighI16x8S
  I32x4ExtendLowI16x8U
  I32x4ExtendHighI16x8U
  I32x4Shl
  I32x4ShrS
  I32x4ShrU
  I32x4Add
  I32x4Sub
  I32x4Mul
  I32x4MinS
  I32x4MinU
  I32x4MaxS
  I32x4MaxU
  I32x4DotI16x8S
  I32x4ExtMulLowI16x8S
  I32x4ExtMulHighI16x8S
  I32x4ExtMulLowI16x8U
  I32x4ExtMulHighI16x8U

  // i64x2 operations
  I64x2Abs
  I64x2Neg
  I64x2AllTrue
  I64x2Bitmask
  I64x2ExtendLowI32x4S
  I64x2ExtendHighI32x4S
  I64x2ExtendLowI32x4U
  I64x2ExtendHighI32x4U
  I64x2Shl
  I64x2ShrS
  I64x2ShrU
  I64x2Add
  I64x2Sub
  I64x2Mul
  I64x2ExtMulLowI32x4S
  I64x2ExtMulHighI32x4S
  I64x2ExtMulLowI32x4U
  I64x2ExtMulHighI32x4U

  // f32x4 operations
  F32x4Ceil
  F32x4Floor
  F32x4Trunc
  F32x4Nearest
  F32x4Abs
  F32x4Neg
  F32x4Sqrt
  F32x4Add
  F32x4Sub
  F32x4Mul
  F32x4Div
  F32x4Min
  F32x4Max
  F32x4Pmin
  F32x4Pmax

  // f64x2 operations
  F64x2Ceil
  F64x2Floor
  F64x2Trunc
  F64x2Nearest
  F64x2Abs
  F64x2Neg
  F64x2Sqrt
  F64x2Add
  F64x2Sub
  F64x2Mul
  F64x2Div
  F64x2Min
  F64x2Max
  F64x2Pmin
  F64x2Pmax

  // SIMD conversions
  I32x4TruncSatF32x4S
  I32x4TruncSatF32x4U
  F32x4ConvertI32x4S
  F32x4ConvertI32x4U
  I32x4TruncSatF64x2SZero
  I32x4TruncSatF64x2UZero
  F64x2ConvertLowI32x4S
  F64x2ConvertLowI32x4U
  F32x4DemoteF64x2Zero
  F64x2PromoteLowF32x4

  // Relaxed SIMD instructions
  I8x16RelaxedSwizzle
  I32x4RelaxedTruncF32x4S
  I32x4RelaxedTruncF32x4U
  I32x4RelaxedTruncF64x2SZero
  I32x4RelaxedTruncF64x2UZero
  F32x4RelaxedMadd
  F32x4RelaxedNmadd
  F64x2RelaxedMadd
  F64x2RelaxedNmadd
  I8x16RelaxedLaneselect
  I16x8RelaxedLaneselect
  I32x4RelaxedLaneselect
  I64x2RelaxedLaneselect
  F32x4RelaxedMin
  F32x4RelaxedMax
  F64x2RelaxedMin
  F64x2RelaxedMax
  I16x8RelaxedQ15mulrS
  I16x8RelaxedDotI8x16I7x16S
  I32x4RelaxedDotI8x16I7x16AddS
} derive(Eq, Debug)

///|
/// What a block, loop or `if` consumes and produces.
pub(all) enum BlockType {
  Empty
  Value(ValType)
  MultiValue(Array[ValType])
  InlineType(Array[ValType], Array[ValType])
  TypeIndex(Int)
} derive(Eq, Debug)

///|
/// The compilation hints attached to a single instruction.
///
/// These do not change what the instruction does; they are advice, carried out
/// of line in the `metadata.code.*` sections, keyed by the instruction's byte
/// offset within its function body. Which is why they hang off the instruction
/// here: the offset is only knowable while encoding, and only the encoder knows
/// it.
pub(all) struct InstrHints {
  /// `#[likely]` / `#[unlikely]` on a branch.
  branch : Bool?
  /// `#[freq]`: a saturating base-2 logarithm of executions per call, already
  /// reduced to the byte the section stores.
  freq : Int?
  /// `#[targets]`: likely call targets, as (function index, percentage).
  targets : Array[(Int, Int)]?
} derive(Eq, Debug)

///|
/// No hints.
pub fn InstrHints::none() -> InstrHints {
  { branch: None, freq: None, targets: None }
}

///|
pub fn InstrHints::is_empty(self : InstrHints) -> Bool {
  self.branch is None && self.freq is None && self.targets is None
}

///|
/// `#[priority]`: advice about the function as a whole rather than about one
/// instruction, which is why it lives on the code entry and is recorded at
/// offset 0 -- the position that means "the function itself".
pub(all) struct Priority {
  compilation : Int
  optimization : Int?
} derive(Eq, Debug)

///|
/// One arm of a resume table: what happens when the continuation suspends with
/// a given tag.
pub(all) enum OnClause {
  /// Branch to this label.
  OnLabel(Int, Int)
  /// Switch to the continuation on the stack.
  OnSwitch(Int)
} derive(Eq, Debug)

///|
/// One arm of a `try_table`.
pub(all) enum CatchHandler {
  /// Catch this tag, branching to this label.
  Catch(Int, Int)
  /// As `Catch`, but the exception reference is pushed too.
  CatchRef(Int, Int)
  /// Catch anything, branching to this label.
  CatchAll(Int)
  /// As `CatchAll`, but the exception reference is pushed too.
  CatchAllRef(Int)
} derive(Eq, Debug)

// ============================================================
// Module structure
// ============================================================

///|
/// A memory's type.
pub(all) struct MemoryType {
  limits : Limits
} derive(Eq, Debug)

///|
/// A table's type. The element type is a REFERENCE type, not a value type:
/// nothing else can go in a table.
pub(all) struct TableType {
  elem_type : RefType
  limits : Limits
} derive(Eq, Debug)

///|
/// A defined table, with the initialiser every element starts at.
pub(all) struct Table {
  type_ : TableType
  init : Array[Instruction]?
  init_spans : Array[Span]
} derive(Eq, Debug)

///|
/// An exception tag: an index into the type section, naming a function type
/// whose parameters are the exception's payload and whose results are empty.
pub(all) struct TagType {
  type_idx : Int
} derive(Eq, Debug)

///|
/// What an import brings in.
pub(all) enum ImportDesc {
  /// A function's type index, and whether the import is EXACT -- a `ref.func`
  /// on it then yields an exact reference rather than a plain one. The flag
  /// rides in the kind byte, not beside the index: 0x20 instead of 0x00.
  Func(Int, Bool)
  Table(TableType)
  Memory(MemoryType)
  Global(GlobalType)
  Tag(Int)
} derive(Eq, Debug)

///|
pub(all) struct Import {
  mod_name : Bytes
  name : Bytes
  desc : ImportDesc
  /// The rest of a COMPACT group, when this entry heads one.
  ///
  /// The compact-import-section proposal writes a module name once for a run
  /// of imports from it. The marker sits where an externtype kind byte would,
  /// and neither marker is a valid kind, so a plain import stays unambiguous.
  group : ImportGroup?
} derive(Eq, Debug)

///|
/// The two compact forms: per-item descriptors, or one shared descriptor and a
/// list of names.
pub(all) enum ImportGroup {
  /// Marker 0x7F: each item carries its own name and descriptor.
  Heterogeneous(Array[(Bytes, ImportDesc)])
  /// Marker 0x7E: one descriptor, then the names that share it.
  Homogeneous(Array[Bytes])
} derive(Eq, Debug)

///|
/// What an export names, as an index into the matching space.
pub(all) enum ExportDesc {
  Func(Int)
  Table(Int)
  Memory(Int)
  Global(Int)
  Tag(Int)
} derive(Eq, Debug)

///|
pub(all) struct Export {
  name : Bytes
  desc : ExportDesc
} derive(Eq, Debug)

///|
/// A function body: its locals, then its instructions.
/// One node's run in a body: where it starts, where its OWN emission begins
/// (everything before that is its operands), where it ends, and where the
/// source wrote it.
pub(all) struct Span {
  start : Int
  head : Int
  end : Int
  loc : @basic.Location
} derive(Eq, Debug)

///|
pub(all) struct FunctionCode {
  locals : Array[ValType]
  body : Array[Instruction]
  /// Where each source instruction's run starts and ends in `body`, in the
  /// order the runs COMPLETE.
  ///
  /// Not part of the format and not encoded: the binary writes the body flat
  /// and the text writes it FOLDED, and this is the nesting the text needs.
  /// It is recorded where the body was built rather than re-derived from an
  /// arity table, because a second derivation could disagree with the first
  /// and nothing would say which output was wrong.
  spans : Array[Span]
  /// The same, for each NESTED body -- a block's, a loop's, each arm of an
  /// `if` -- in the order those bodies completed while the function was
  /// lowered: deepest first, then left to right. A nested body is a separate
  /// array with its own indices, so its spans cannot live in the list above;
  /// that order is what pairs them up again.
  nested_spans : Array[Array[Span]]
  /// `#[priority]` on the function, if any.
  priority : Priority?
} derive(Eq, Debug)

///|
pub(all) struct Global {
  type_ : GlobalType
  init : Array[Instruction]
  /// The spans of that initialiser, so the text form can fold it. A constant
  /// expression is its own body with its own indices, so its spans are its
  /// own too.
  init_spans : Array[Span]
} derive(Eq, Debug)

///|
/// How an element segment reaches its table.
pub(all) enum ElemMode {
  /// Copied into a table at instantiation, at this offset.
  Active(Int, Array[Instruction])
  /// Left for `table.init`.
  Passive
  /// Present only so the references in it count as declared.
  Declarative
} derive(Eq, Debug)

///|
pub(all) struct Element {
  mode : ElemMode
  type_ : RefType
  init : Array[Array[Instruction]]
  /// One span list per initialiser, and one for the active offset.
  init_spans : Array[Array[Span]]
  offset_spans : Array[Span]
} derive(Eq, Debug)

///|
/// How a data segment reaches its memory.
///
/// Upstream had no such type: it hung a bare `memory_idx` off the segment and
/// signalled "passive" with a NEGATIVE index. That makes an unrepresentable
/// state representable -- an active segment with an empty offset expression --
/// and it decided the encoding from `offset.is_empty()`, so such a segment was
/// silently written as active-at-an-explicit-memory instead.
pub(all) enum DataMode {
  /// Copied into this memory at instantiation, at this offset.
  Active(Int, Array[Instruction])
  /// Left for `memory.init`.
  Passive
} derive(Eq, Debug)

///|
pub(all) struct Data {
  mode : DataMode
  init : Bytes
  /// The spans of the active offset expression.
  offset_spans : Array[Span]
  /// How the source wrote those bytes.
  ///
  /// A segment is a run of bytes to the binary and a list of PIECES to the
  /// text: `"hdr" (f32 0.2 0.3 0.4) (i8 1 2 3)` flattens to bytes and does not
  /// come back from them. Empty when nothing recorded it, and then the bytes
  /// are written as one string.
  spelling : Array[DataPiece]
} derive(Eq, Debug)

///|
/// One piece of a data segment, as the source wrote it.
pub(all) enum DataPiece {
  /// A byte string.
  PieceStr(Bytes)
  /// A numeric run: the element keyword, then the literals as written. A
  /// vector run keeps its shapes among them, because `(v128 i32x4 1 2 3 4
  /// f64x2 1.0 2.0)` is one run of two vectors written two different ways.
  PieceRun(String, Array[String])
} derive(Eq, Debug)

///|
/// The `name` custom section: what everything in the module is called.
///
/// Upstream had a single `func_names : Map[Int, String]` on the module, which
/// the encoder never read -- so every name was dropped. There are twelve name
/// spaces, not one, and `wasm_output.ml` emits all of them.
///
/// Maps rather than arrays, mirroring the reference's `IntMap`: the format
/// wants each vector in ascending index order, and making that the encoder's
/// job rather than the caller's is one fewer way to differ by a byte.
pub(all) struct Names {
  mut module_ : Bytes?
  functions : Map[Int, Bytes]
  /// Locals, labels and fields are indexed twice: by the function or type they
  /// belong to, then within it.
  locals : Map[Int, Map[Int, Bytes]]
  labels : Map[Int, Map[Int, Bytes]]
  types : Map[Int, Bytes]
  tables : Map[Int, Bytes]
  memories : Map[Int, Bytes]
  globals : Map[Int, Bytes]
  elem : Map[Int, Bytes]
  data : Map[Int, Bytes]
  fields : Map[Int, Map[Int, Bytes]]
  tags : Map[Int, Bytes]
} derive(Debug)

///|
/// No names at all, which is also what makes the section disappear.
pub fn Names::empty() -> Names {
  {
    module_: None,
    functions: {},
    locals: {},
    labels: {},
    types: {},
    tables: {},
    memories: {},
    globals: {},
    elem: {},
    data: {},
    fields: {},
    tags: {},
  }
}

///|
/// A whole module, in the form the encoder writes out.
pub(all) struct Module {
  /// Every defined type, flat, because that is the space indices refer to.
  types : Array[SubType]
  /// How those types are grouped into `rec (...)`. The groups partition
  /// `types` in order, so `rec_groups` is a view of the same array rather than
  /// a second copy of it.
  rec_groups : Array[RecGroup]
  imports : Array[Import]
  /// One type index per defined function, parallel to `codes`.
  funcs : Array[Int]
  tables : Array[Table]
  memories : Array[MemoryType]
  globals : Array[Global]
  exports : Array[Export]
  mut start : Int?
  elems : Array[Element]
  codes : Array[FunctionCode]
  datas : Array[Data]
  tags : Array[TagType]
  /// What the TEXT form needs and the binary drops.
  ///
  /// Everything else here is encoded. These are not: they are the source
  /// facts a binary has no room for -- where a field stood, what a
  /// declaration called its parameters -- kept together so that reading this
  /// model for the encoding does not mean reading past them.
  text : TextView
  /// The `name` custom section.
  names : Names
  /// The `target_features` custom section: (prefix byte, feature name) pairs,
  /// emitted verbatim and in order, because entries from other producers pass
  /// through untouched.
  target_features : Array[(Int, Bytes)]
} derive(Debug)

///|
/// The source facts the text form needs and the binary has no room for.
///
/// Recorded as the lowering goes rather than recovered afterwards: there is
/// nothing in the sections to recover them from, and a second derivation could
/// disagree with the first with nothing to say which output is wrong.
pub(all) struct TextView {
  /// The order the SOURCE wrote the fields in.
  ///
  /// The sections group items by kind, which is not the order they were
  /// written, and the text format writes each field where it stood. Nothing in
  /// the sections records that order, so the lowering notes it as it goes --
  /// the same way it notes the instruction spans, and for the same reason: a
  /// second derivation could disagree with the first.
  ///
  /// Only the binary encoder's input is authoritative for the bytes; this is a
  /// view for the text form, and is empty when nothing recorded it.
  field_order : Array[FieldRef]
  /// Where each of those fields stood in the source, parallel to
  /// `field_order`.
  ///
  /// The binary has no notion of a source position; the text format needs one,
  /// because a comment attaches to the field it was written against and there
  /// is nothing else to attach it to.
  field_locs : Array[@basic.Location]
  /// The parameter names a DECLARATION wrote, for the declarations whose
  /// names the binary does not carry.
  ///
  /// A name section can hold local names for an imported function, and the
  /// reference does not write them -- so these cannot ride in `names.locals`
  /// without changing the bytes. The text format shows them, so they are kept
  /// apart from the section that is encoded.
  decl_param_names : Map[ParamOwner, Map[Int, Bytes]]
  /// The declarations whose type the SOURCE named.
  ///
  /// `tag t: ft;` writes `(type $ft)` and `tag t(i32);` spells the signature
  /// out; a function is the same. The binary keeps only the index, which is
  /// the same either way, so which was written has to be recorded.
  named_decl_types : Map[ParamOwner, Bool]
  /// The conditional groups the source wrote.
  ///
  /// A conditional has no binary form -- that is the whole point of it, and
  /// `-f wasm` refuses a module that still has one. The text keeps it, so the
  /// condition and the extent of each branch are recorded here and the fields
  /// are grouped back under them by where they stood.
  conditionals : Array[CondGroup]
} derive(Debug)

///|
/// One `#[if(..)]` group: the condition as the TEXT format writes it, and
/// where each branch stood in the source.
pub(all) struct CondGroup {
  cond : String
  loc : @basic.Location
  then_ : @basic.Location
  else_ : @basic.Location?
} derive(Debug)

///|
/// An empty view, for a module nothing recorded one for.
pub fn TextView::empty() -> TextView {
  {
    field_order: [],
    field_locs: [],
    decl_param_names: Map([]),
    named_decl_types: Map([]),
    conditionals: [],
  }
}

///|
/// Whose parameters a name list belongs to. Imported functions and tags sit in
/// different index spaces, so the index alone does not say.
pub(all) enum ParamOwner {
  OwnerFunc(Int)
  OwnerTag(Int)
} derive(Eq, Hash, Debug)

///|
/// One field of a module, named by where its item landed.
pub(all) enum FieldRef {
  /// The type-section entries one `type` or `rec` field declared.
  FTypes(Array[Int])
  /// A `#![feature = "name"]` inner attribute, which the text format keeps as
  /// a leading `(@feature "name")` so the emitted module still says what it
  /// needs. There is no binary section for it; the text is where it survives.
  FFeature(Bytes)
  FImport(Int)
  FFunc(Int)
  /// `(start $f)`. Written where the `#[start]` attribute was, because that is
  /// what a conditional around it guards.
  FStart(Int)
  FTable(Int)
  FMemory(Int)
  FGlobal(Int)
  FTag(Int)
  FElem(Int)
  FData(Int)
} derive(Eq, Debug)

///|
/// A module with nothing in it.
pub fn Module::empty() -> Module {
  {
    types: [],
    rec_groups: [],
    text: TextView::empty(),
    imports: [],
    funcs: [],
    tables: [],
    memories: [],
    globals: [],
    exports: [],
    start: None,
    elems: [],
    codes: [],
    datas: [],
    tags: [],
    names: Names::empty(),
    target_features: [],
  }
}
