// The vector memory accesses: `mem.loadv128(p)`, `mem.load8_lane(p, v, 0)`.
//
// These are methods on a MEMORY object, not on a stack value, which is why they
// are a separate registry from the arithmetic intrinsics: the receiver is not
// an operand, and there are trailing `align`/`offset` literals the others do
// not have.

///|
/// The lane width a `load8_lane`-style name carries.
pub(all) enum LaneWidth {
  L8
  L16
  L32
  L64
} derive(Eq, Hash, Debug)

///|
pub fn LaneWidth::to_str(self : LaneWidth) -> String {
  match self {
    L8 => "8"
    L16 => "16"
    L32 => "32"
    L64 => "64"
  }
}

///|
/// The alignment such an access naturally has, in bytes.
pub fn LaneWidth::nat_align(self : LaneWidth) -> Int {
  match self {
    L8 => 1
    L16 => 2
    L32 => 4
    L64 => 8
  }
}

///|
pub let lane_widths : Array[LaneWidth] = [L8, L16, L32, L64]

///|
/// The whole-vector loads, each of which reads a differently shaped chunk and
/// widens or zero-fills it.
pub(all) enum VecLoad {
  Load128
  Load8x8S
  Load8x8U
  Load16x4S
  Load16x4U
  Load32x2S
  Load32x2U
  Load32Zero
  Load64Zero
} derive(Eq, Hash, Debug)

///|
pub fn VecLoad::to_str(self : VecLoad) -> String {
  match self {
    Load128 => "loadv128"
    Load8x8S => "load8x8_s"
    Load8x8U => "load8x8_u"
    Load16x4S => "load16x4_s"
    Load16x4U => "load16x4_u"
    Load32x2S => "load32x2_s"
    Load32x2U => "load32x2_u"
    Load32Zero => "load32_zero"
    Load64Zero => "load64_zero"
  }
}

///|
/// How many bytes the load actually reads -- which is not always 16, and is
/// what its natural alignment follows from.
pub fn VecLoad::nat_align(self : VecLoad) -> Int {
  match self {
    Load128 => 16
    Load8x8S
    | Load8x8U
    | Load16x4S
    | Load16x4U
    | Load32x2S
    | Load32x2U
    | Load64Zero => 8
    Load32Zero => 4
  }
}

///|
pub let vec_loads : Array[VecLoad] = [
  Load128,
  Load8x8S,
  Load8x8U,
  Load16x4S,
  Load16x4U,
  Load32x2S,
  Load32x2U,
  Load32Zero,
  Load64Zero,
]

///|
pub let store_name : String = "storev128"

///|
pub fn load_splat_name(w : LaneWidth) -> String {
  "load" + w.to_str() + "_splat"
}

///|
pub fn load_lane_name(w : LaneWidth) -> String {
  "load" + w.to_str() + "_lane"
}

///|
pub fn store_lane_name(w : LaneWidth) -> String {
  "store" + w.to_str() + "_lane"
}

///|
/// What a vector memory method takes, gives back, and builds.
pub struct MemIntrinsic {
  /// The stack operands: the address first, then the vector for a store or a
  /// lane operation. The memory receiver is not among them.
  operands : Array[Ty]
  result : Ty?
  /// Whether a constant lane immediate follows the operands.
  lane : Bool
  /// The alignment the access naturally has, as a byte count.
  nat_align : Int
  /// Memory index, alignment exponent, offset, lane -> the instruction. The
  /// lane is ignored when `lane` is false.
  build : (Int, Int, Int64, Int) -> @wasm_bin.Instruction
}

///|
/// The vector memory method of this name, if there is one.
pub fn mem_method(name : String) -> MemIntrinsic? {
  fn load(op : VecLoad) -> MemIntrinsic {
    {
      operands: [TI32],
      result: Some(TV128),
      lane: false,
      nat_align: op.nat_align(),
      build: (m, a, o, _) => vec_load_instr(op, m, a, o),
    }
  }

  fn load_splat(w : LaneWidth) -> MemIntrinsic {
    {
      operands: [TI32],
      result: Some(TV128),
      lane: false,
      nat_align: w.nat_align(),
      build: (m, a, o, _) => load_splat_instr(w, m, a, o),
    }
  }

  fn load_lane(w : LaneWidth) -> MemIntrinsic {
    {
      // The vector to write the loaded lane into is an operand as well.
      operands: [TI32, TV128],
      result: Some(TV128),
      lane: true,
      nat_align: w.nat_align(),
      build: (m, a, o, l) => load_lane_instr(w, m, a, o, l),
    }
  }

  fn store_lane(w : LaneWidth) -> MemIntrinsic {
    {
      operands: [TI32, TV128],
      result: None,
      lane: true,
      nat_align: w.nat_align(),
      build: (m, a, o, l) => store_lane_instr(w, m, a, o, l),
    }
  }

  for op in vec_loads {
    if name == op.to_str() {
      return Some(load(op))
    }
  }
  if name == store_name {
    return Some({
      operands: [TI32, TV128],
      result: None,
      lane: false,
      nat_align: 16,
      build: (m, a, o, _) => V128Store(m, a, o),
    })
  }
  for w in lane_widths {
    if name == load_splat_name(w) {
      return Some(load_splat(w))
    }
    if name == load_lane_name(w) {
      return Some(load_lane(w))
    }
    if name == store_lane_name(w) {
      return Some(store_lane(w))
    }
  }
  None
}

///|
pub fn is_mem_method(name : String) -> Bool {
  mem_method(name) is Some(_)
}

///|
/// Every vector memory method name, for completion after `mem.`. Exactly the
/// set `mem_method` recognises, because both are built from the same lists.
pub let mem_method_names : Array[String] = {
  let out = vec_loads.map(op => op.to_str())
  out.push(store_name)
  for w in lane_widths {
    out.push(load_splat_name(w))
  }
  for w in lane_widths {
    out.push(load_lane_name(w))
  }
  for w in lane_widths {
    out.push(store_lane_name(w))
  }
  out
}

///|
fn vec_load_instr(
  op : VecLoad,
  m : Int,
  align : Int,
  offset : Int64,
) -> @wasm_bin.Instruction {
  match op {
    Load128 => V128Load(m, align, offset)
    Load8x8S => V128Load8x8S(m, align, offset)
    Load8x8U => V128Load8x8U(m, align, offset)
    Load16x4S => V128Load16x4S(m, align, offset)
    Load16x4U => V128Load16x4U(m, align, offset)
    Load32x2S => V128Load32x2S(m, align, offset)
    Load32x2U => V128Load32x2U(m, align, offset)
    Load32Zero => V128Load32Zero(m, align, offset)
    Load64Zero => V128Load64Zero(m, align, offset)
  }
}

///|
fn load_splat_instr(
  w : LaneWidth,
  m : Int,
  align : Int,
  offset : Int64,
) -> @wasm_bin.Instruction {
  match w {
    L8 => V128Load8Splat(m, align, offset)
    L16 => V128Load16Splat(m, align, offset)
    L32 => V128Load32Splat(m, align, offset)
    L64 => V128Load64Splat(m, align, offset)
  }
}

///|
fn load_lane_instr(
  w : LaneWidth,
  m : Int,
  align : Int,
  offset : Int64,
  lane : Int,
) -> @wasm_bin.Instruction {
  match w {
    L8 => V128Load8Lane(m, align, offset, lane)
    L16 => V128Load16Lane(m, align, offset, lane)
    L32 => V128Load32Lane(m, align, offset, lane)
    L64 => V128Load64Lane(m, align, offset, lane)
  }
}

///|
fn store_lane_instr(
  w : LaneWidth,
  m : Int,
  align : Int,
  offset : Int64,
  lane : Int,
) -> @wasm_bin.Instruction {
  match w {
    L8 => V128Store8Lane(m, align, offset, lane)
    L16 => V128Store16Lane(m, align, offset, lane)
    L32 => V128Store32Lane(m, align, offset, lane)
    L64 => V128Store64Lane(m, align, offset, lane)
  }
}
