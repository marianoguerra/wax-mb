// The alignment and offset immediates of a memory access.
//
// Ported from wax/src/lib-wax/typing.ml, and mirroring the validator's
// `check_memarg`.
//
// These are not operands. `mem.load32(addr, align: 4, offset: 16)` puts one
// value on the stack and two CONSTANTS in the instruction, so they are checked
// here as literals rather than typed as expressions -- an alignment that is not
// a literal at all is not a slower alignment, it is not an alignment.
//
// The alignment is a promise, not a request. It tells the engine the address is
// already aligned so the access can skip a check; promising more than the
// access naturally needs is unverifiable and so rejected, while promising less
// is merely pessimistic and allowed.

///|
/// The natural alignment of a memory access, in bytes: the width it reads or
/// writes.
pub fn mem_natural_align(meth : String) -> Int {
  match meth {
    "load8" | "store8" => 1
    "load16" | "store16" => 2
    "load32" | "store32" | "loadf32" | "storef32" => 4
    "load64" | "store64" | "loadf64" | "storef64" => 8
    _ => 1
  }
}

///|
/// The unsigned 64-bit value of an integer literal, or `None` when it is not an
/// integer literal or does not fit.
pub fn int_literal_u64(desc : @ast.InstrDesc[@basic.Location]) -> UInt64? {
  guard desc is Int(s) else { return None }
  @number.parse_int64(s).map(v => v.reinterpret_as_uint64())
}

///|
/// One past the largest offset a 32-bit memory can address.
pub let max_offset_i32_exclusive : UInt64 = 0x1_0000_0000UL

///|
/// The widest alignment any access has -- a v128 lane load.
pub let max_align : UInt64 = 16UL

///|
/// Validate the `align` and `offset` immediates of a memory access.
///
/// The two are checked independently and both are reported, because they are
/// two separate things the author wrote and either can be wrong on its own.
///
/// `natural` is the access's own width in bytes. An alignment above it is
/// rejected: it claims a guarantee the access cannot use and the engine cannot
/// check. Below it is fine -- that only forgoes an optimisation.
///
/// The offset is bounded by the address type rather than by the access: on a
/// 32-bit memory an offset at or past 2^32 can never name a reachable address,
/// whatever the base.
pub fn check_memarg(
  diagnostics : @diagnostic.Context,
  address_type : @wasm_types.AddressType,
  natural : Int,
  align : @basic.Annotated[@ast.InstrDesc[@basic.Location], @basic.Location]?,
  offset : @basic.Annotated[@ast.InstrDesc[@basic.Location], @basic.Location]?,
) -> Unit {
  if offset is Some(offset) {
    match int_literal_u64(offset.desc) {
      // Does not fit u64, so it cannot be a memory offset at all.
      None => memory_immediate_too_large(diagnostics, offset.info)
      Some(o) =>
        if address_type is I32 && o >= max_offset_i32_exclusive {
          memory_offset_too_large(
            diagnostics,
            offset.info,
            max_offset_i32_exclusive,
          )
        }
    }
  }
  guard align is Some(align) else { return }
  match int_literal_u64(align.desc) {
    None => memory_immediate_too_large(diagnostics, align.info)
    Some(a) =>
      if a > max_align || a.to_int() > natural {
        memory_align_too_large(diagnostics, align.info, natural)
      } else if !(a is (1UL | 2UL | 4UL | 8UL | 16UL)) {
        // Checked after the bound, so an alignment that is both too large and
        // not a power of two is reported as too large -- the more specific
        // complaint, and the one that names the number to compare against.
        bad_memory_align(diagnostics, align.info)
      }
  }
}

///|
/// How many lanes an immediate may name.
///
/// The bound comes from the OPCODE, not from the operand. A `v128` is sixteen
/// bytes however it is being read, so `i8x16.extract_lane` admits 0..15 and
/// `f64x2.extract_lane` only 0..1 -- and the value on the stack is the same
/// v128 in both cases. A shuffle names two vectors' lanes at once, hence 32.
pub fn lane_bound(imm : @simd.Imm) -> Int? {
  match imm {
    NoImm => None
    Lane(shape) => Some(shape.lane_count())
    Shuffle => Some(32)
  }
}

///|
/// Validate a lane immediate against its bound.
///
/// A lane index has to be a constant integer: there is no opcode for a computed
/// lane, so a non-literal is not a slower lane selection, it is not one at all.
///
/// Compared UNSIGNED, and a literal too large even for u64 is rejected here
/// rather than left to overflow: it would otherwise slip through to the code
/// generator, which parses it and crashes. The reference has the same guard in
/// both of its lane checks, for exactly that reason.
pub fn check_lane_immediate(
  diagnostics : @diagnostic.Context,
  bound : Int,
  lane : @basic.Annotated[@ast.InstrDesc[@basic.Location], @basic.Location],
) -> Unit {
  guard lane.desc is Int(_) else {
    integer_literal_required(diagnostics, lane.info)
    return
  }
  match int_literal_u64(lane.desc) {
    Some(l) if l < bound.to_uint64() => ()
    _ => invalid_lane_index(diagnostics, lane.info, bound)
  }
}

///|
/// The lane bound of a memory access that takes one.
///
/// Derived from the access width rather than from a shape: a `load8_lane` reads
/// one byte into one of sixteen byte lanes, a `load64_lane` eight bytes into
/// one of two.
pub fn mem_lane_bound(natural_align : Int) -> Int {
  16 / natural_align
}
