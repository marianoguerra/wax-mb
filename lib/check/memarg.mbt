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
fn int_literal_u64(desc : @ast.InstrDesc[@basic.Location]) -> UInt64? {
  guard desc is Int(s) else { return None }
  @number.parse_int64(s).map(v => v.reinterpret_as_uint64())
}

///|
/// One past the largest offset a 32-bit memory can address.
let max_offset_i32_exclusive : UInt64 = 0x1_0000_0000UL

///|
/// The widest alignment any access has -- a v128 lane load.
let max_align : UInt64 = 16UL

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

///|
/// A memory access's arguments split into stack operands and labelled
/// immediates.
priv struct MemArgs {
  positional : Array[@ast.Instr[@basic.Location]]
  labelled : Array[(@ast.Ident, @ast.Instr[@basic.Location])]
}

///|
/// Split a call's arguments into the positional operands and the labelled
/// immediates.
///
/// A positional argument AFTER a labelled one is reported and kept positional:
/// the author meant it as an operand, and dropping it would cascade into an
/// arity complaint about something they did write.
fn split_labelled_args(args : Array[@ast.Instr[@basic.Location]]) -> MemArgs {
  let positional : Array[@ast.Instr[@basic.Location]] = []
  let labelled : Array[(@ast.Ident, @ast.Instr[@basic.Location])] = []
  for a in args {
    match a.desc {
      Labelled(l, e) => labelled.push((l, e))
      _ => positional.push(a)
    }
  }
  { positional, labelled }
}

///|
/// Resolve the labelled immediates, reporting a label that is unknown, given
/// twice, or not a literal.
///
/// A non-literal value is reported HERE and the pair dropped, so `check_memarg`
/// -- which would also fail to read it -- does not say the same thing again.
fn take_labels(
  diagnostics : @diagnostic.Context,
  allowed : Array[String],
  labelled : Array[(@ast.Ident, @ast.Instr[@basic.Location])],
) -> Map[
  String,
  @basic.Annotated[@ast.InstrDesc[@basic.Location], @basic.Location],
] {
  let out : Map[
    String,
    @basic.Annotated[@ast.InstrDesc[@basic.Location], @basic.Location],
  ] = Map([])
  let seen : Map[String, @basic.Location] = Map([])
  for pair in labelled {
    let (l, e) = pair
    if !allowed.contains(l.name) {
      unknown_argument_label(
        diagnostics,
        l.loc,
        l.name,
        suggestions=@spell.suggest(allowed.iter(), l.name),
      )
      continue
    }
    if seen.get(l.name) is Some(prev) {
      duplicate_argument_label(diagnostics, l.loc, prev, l.name)
      continue
    }
    seen[l.name] = l.loc
    match e.desc {
      Int(_) => out[l.name] = { desc: e.desc, info: e.info }
      _ => integer_literal_required(diagnostics, e.info)
    }
  }
  out
}

///|
/// Pick out a memory access's immediates, accepting the pre-label positional
/// spelling with a migration complaint.
///
/// Extra positional arguments are read as immediates ONLY when they are all
/// integer literals and no more than the immediate count. Otherwise they are an
/// ordinary arity mistake, and reading a local as an alignment would cascade
/// into a bogus memarg complaint on top of it.
fn mem_immediates(
  diagnostics : @diagnostic.Context,
  location : @basic.Location,
  example : String,
  nstack : Int,
  has_lane~ : Bool,
  found : Map[
    String,
    @basic.Annotated[@ast.InstrDesc[@basic.Location], @basic.Location],
  ],
  positional : Array[@ast.Instr[@basic.Location]],
) -> (
  @basic.Annotated[@ast.InstrDesc[@basic.Location], @basic.Location]?,
  @basic.Annotated[@ast.InstrDesc[@basic.Location], @basic.Location]?,
  @basic.Annotated[@ast.InstrDesc[@basic.Location], @basic.Location]?,
) {
  let nargs = positional.length()
  let extra = if nargs > nstack { positional[nstack:].to_owned() } else { [] }
  let nimms = if has_lane { 3 } else { 2 }
  let migration = !extra.is_empty() &&
    extra.length() <= nimms &&
    extra.iter().all(a => a.desc is Int(_))
  if nargs < nstack {
    operand_count_mismatch(
      diagnostics,
      location,
      expected=nstack,
      provided=nargs,
    )
  } else if !extra.is_empty() {
    if migration {
      positional_memory_immediate(diagnostics, extra[0].info, example)
    } else {
      operand_count_mismatch(
        diagnostics,
        location,
        expected=nstack,
        provided=nargs,
      )
    }
  }
  fn pick(
    name : String,
    k : Int,
  ) -> @basic.Annotated[@ast.InstrDesc[@basic.Location], @basic.Location]? {
    match found.get(name) {
      Some(e) => Some(e)
      None =>
        if migration && k < extra.length() {
          Some({ desc: extra[k].desc, info: extra[k].info })
        } else {
          None
        }
    }
  }

  if has_lane {
    (pick("lane", 0), pick("align", 1), pick("offset", 2))
  } else {
    (None, pick("align", 0), pick("offset", 1))
  }
}
