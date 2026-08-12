// The atomic memory instructions, and the two names each one answers to.
//
// Ported from wax/src/lib-wasm/atomics.ml, which exists to be the single source
// of truth for the mapping between an atomic operation, its WAT mnemonic, its
// `0xFE`-prefix sub-opcode, its natural alignment and its stack signature. Four
// tables that have to agree, so they are generated from one.
//
// `atomic.fence` is not here: it has no memory operand, so it shares none of
// this shape. `wasm_bin` carries it as its own instruction for the same reason.

///|
/// The value type an atomic operation works in.
pub(all) enum NumTy {
  I32
  I64
} derive(Eq, Hash, Debug)

///|
/// A narrower access than the value type: `i64.atomic.load16_u` reads two bytes
/// into an i64. `None` means the access is the full width of the value type.
pub(all) enum Narrow {
  N8
  N16
  N32
} derive(Eq, Hash, Debug)

///|
/// The read-modify-write operations.
pub(all) enum RmwOp {
  Add
  Sub
  And
  Or
  Xor
  Xchg
  Cmpxchg
} derive(Eq, Hash, Debug)

///|
/// A concrete atomic operation, as the binary format sees it.
pub(all) enum Op {
  Notify
  Wait(NumTy)
  Load(NumTy, Narrow?)
  Store(NumTy, Narrow?)
  Rmw(RmwOp, NumTy, Narrow?)
} derive(Eq, Hash, Debug)

///|
fn NumTy::to_str(self : NumTy) -> String {
  match self {
    I32 => "i32"
    I64 => "i64"
  }
}

///|
fn Narrow::to_str(self : Narrow) -> String {
  match self {
    N8 => "8"
    N16 => "16"
    N32 => "32"
  }
}

///|
fn RmwOp::to_str(self : RmwOp) -> String {
  match self {
    Add => "add"
    Sub => "sub"
    And => "and"
    Or => "or"
    Xor => "xor"
    Xchg => "xchg"
    Cmpxchg => "cmpxchg"
  }
}

///|
/// The WAT mnemonic.
pub fn name(op : Op) -> String {
  match op {
    Notify => "memory.atomic.notify"
    Wait(I32) => "memory.atomic.wait32"
    Wait(I64) => "memory.atomic.wait64"
    Load(t, None) => t.to_str() + ".atomic.load"
    Load(t, Some(w)) => t.to_str() + ".atomic.load" + w.to_str() + "_u"
    Store(t, None) => t.to_str() + ".atomic.store"
    Store(t, Some(w)) => t.to_str() + ".atomic.store" + w.to_str()
    Rmw(op, t, None) => t.to_str() + ".atomic.rmw." + op.to_str()
    Rmw(op, t, Some(w)) =>
      t.to_str() + ".atomic.rmw" + w.to_str() + "." + op.to_str() + "_u"
  }
}

// ============================================================
// The sub-opcode table
// ============================================================

///|
/// The (type, width) sequence every load / store / rmw block repeats, in binary
/// order: the two full-width accesses, then the narrow ones.
///
/// Every block is laid out this way, which is why the whole table is generated
/// from this one list rather than written out and kept in step by hand.
let variants : Array[(NumTy, Narrow?)] = [
  (I32, None),
  (I64, None),
  (I32, Some(N8)),
  (I32, Some(N16)),
  (I64, Some(N8)),
  (I64, Some(N16)),
  (I64, Some(N32)),
]

///|
let rmw_ops : Array[RmwOp] = [Add, Sub, And, Or, Xor, Xchg, Cmpxchg]

///|
/// Every `(sub-opcode, operation)` pair.
let table : Array[(Int, Op)] = build_table()

///|
fn build_table() -> Array[(Int, Op)] {
  let out : Array[(Int, Op)] = [
    (0x00, Notify),
    (0x01, Wait(I32)),
    (0x02, Wait(I64)),
  ]
  for i, v in variants {
    let (t, w) = v
    out.push((0x10 + i, Load(t, w)))
  }
  for i, v in variants {
    let (t, w) = v
    out.push((0x17 + i, Store(t, w)))
  }
  for j, op in rmw_ops {
    let base = 0x1E + j * 7
    for i, v in variants {
      let (t, w) = v
      out.push((base + i, Rmw(op, t, w)))
    }
  }
  out
}

///|
let by_opcode : Map[Int, Op] = {
  let m = Map([])
  for entry in table {
    let (code, op) = entry
    m[code] = op
  }
  m
}

///|
let by_op : Map[Op, Int] = {
  let m = Map([])
  for entry in table {
    let (code, op) = entry
    m[op] = code
  }
  m
}

///|
/// Every atomic operation, in binary order.
pub fn all() -> Array[Op] {
  table.map(e => e.1)
}

///|
/// The `0xFE`-prefix sub-opcode.
pub fn opcode(op : Op) -> Int {
  by_op[op]
}

///|
pub fn of_opcode(code : Int) -> Op? {
  by_opcode.get(code)
}

// ============================================================
// The Wax surface
// ============================================================

///|
/// The access width a Wax method name carries.
pub(all) enum Width {
  W8
  W16
  W32
  W64
} derive(Eq, Hash, Debug)

///|
/// A Wax method name denotes a FAMILY, not a single operation.
///
/// The name carries the access width only -- `atomic_load16`, `atomic_rmw_add8`
/// -- and the i32/i64 value type is resolved from the operand and result types
/// while type checking, exactly as it is for the plain scalar accesses
/// (`load16(p) as i64_u`). `atomic_wait32`/`atomic_wait64` and `atomic_notify`
/// are the exceptions: they resolve from the name alone.
pub(all) enum Family {
  Load(Width)
  Store(Width)
  Rmw(RmwOp, Width)
  Wait(NumTy)
  Notify
} derive(Eq, Hash, Debug)

///|
let widths : Array[Width] = [W8, W16, W32, W64]

///|
fn Width::to_str(self : Width) -> String {
  match self {
    W8 => "8"
    W16 => "16"
    W32 => "32"
    W64 => "64"
  }
}

///|
/// How many bytes the width accesses. Its base-2 logarithm is the required --
/// and, for an atomic, exact -- alignment.
pub fn Width::bytes(self : Width) -> Int {
  match self {
    W8 => 1
    W16 => 2
    W32 => 4
    W64 => 8
  }
}

///|
/// Every Wax method family, in completion order: loads, stores, RMWs, then
/// wait and notify.
pub fn families() -> Array[Family] {
  let out : Array[Family] = []
  for w in widths {
    out.push(Load(w))
  }
  for w in widths {
    out.push(Store(w))
  }
  for op in rmw_ops {
    for w in widths {
      out.push(Rmw(op, w))
    }
  }
  out.push(Wait(I32))
  out.push(Wait(I64))
  out.push(Notify)
  out
}

///|
/// The Wax spelling on a memory receiver.
pub fn method_name(f : Family) -> String {
  match f {
    Load(w) => "atomic_load" + w.to_str()
    Store(w) => "atomic_store" + w.to_str()
    Rmw(op, w) => "atomic_rmw_" + op.to_str() + w.to_str()
    Wait(I32) => "atomic_wait32"
    Wait(I64) => "atomic_wait64"
    Notify => "atomic_notify"
  }
}

///|
let by_method : Map[String, Family] = {
  let m = Map([])
  for f in families() {
    m[method_name(f)] = f
  }
  m
}

///|
pub fn of_method_name(n : String) -> Family? {
  by_method.get(n)
}

///|
/// Which width an operation's access actually is: the narrow width if it has
/// one, otherwise the value type's own.
fn access_width(t : NumTy, w : Narrow?) -> Width {
  match w {
    Some(N8) => W8
    Some(N16) => W16
    Some(N32) => W32
    None =>
      match t {
        I32 => W32
        I64 => W64
      }
  }
}

///|
/// The family a concrete operation belongs to.
pub fn family(op : Op) -> Family {
  match op {
    Notify => Notify
    Wait(t) => Wait(t)
    Load(t, w) => Load(access_width(t, w))
    Store(t, w) => Store(access_width(t, w))
    Rmw(o, t, w) => Rmw(o, access_width(t, w))
  }
}

///|
/// How many bytes a family accesses.
pub fn family_bytes(f : Family) -> Int {
  match f {
    Load(w) | Store(w) | Rmw(_, w) => w.bytes()
    Wait(I32) => 4
    Wait(I64) => 8
    Notify => 4
  }
}

///|
/// How many bytes an operation accesses.
pub fn access_bytes(op : Op) -> Int {
  match op {
    Notify | Wait(I32) => 4
    Wait(I64) => 8
    Load(t, w) | Store(t, w) | Rmw(_, t, w) => access_width(t, w).bytes()
  }
}

///|
/// The alignment an atomic access requires, as a base-2 logarithm.
///
/// Unlike a plain load or store, where the alignment is a hint and any smaller
/// value is legal, an atomic's alignment must be exactly the natural one.
pub fn natural_align_log2(op : Op) -> Int {
  match access_bytes(op) {
    1 => 0
    2 => 1
    4 => 2
    _ => 3
  }
}

///|
/// The stack signature AFTER the address operand, which always has the memory's
/// own address type: what else is consumed, and what is produced.
pub fn signature(op : Op) -> (Array[NumTy], Array[NumTy]) {
  match op {
    Notify => ([I32], [I32])
    Wait(I32) => ([I32, I64], [I32])
    Wait(I64) => ([I64, I64], [I32])
    Load(t, _) => ([], [t])
    Store(t, _) => ([t], [])
    Rmw(Cmpxchg, t, _) => ([t, t], [t])
    Rmw(_, t, _) => ([t], [t])
  }
}
