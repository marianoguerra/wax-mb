// The custom sections.
//
// None of this came from `wasm_core`, which emits no custom section at all --
// it has the magic number, thirteen standard sections and nothing else. The
// specification here is `wax/src/lib-wasm/wasm_output.ml`, because these are
// the bytes byte identity is measured against; `wasm-encoder`'s
// `core/{names,custom}.rs` is the cross-check.
//
// A custom section is section id 0, whose body begins with its name. Which
// means "is it empty?" has to be decided before the name is written, not after
// -- an empty `name` section is a real, different module from no `name`
// section.

///|
/// Section id 0: a name, then whatever that name implies.
fn write_custom_section(w : BinaryWriter, name : Bytes, body : Bytes) -> Unit {
  let content = BinaryWriter::new()
  content.write_name(name)
  content.write_bytes(body)
  write_section(w, 0, content.to_bytes())
}

///|
/// Indices in ascending order, which is what the format requires of every
/// vector in the name section and what the reference gets for free from
/// `IntMap.bindings`.
fn[V] sorted_keys(m : Map[Int, V]) -> Array[Int] {
  let keys = m.keys().collect()
  keys.sort()
  keys
}

///|
/// A name subsection: id, byte length, then a vector of (index, name).
///
/// Absent when the map is empty -- not present-and-empty. The reference makes
/// the same distinction, and it is a byte.
fn name_subsection(w : BinaryWriter, id : Int, names : Map[Int, Bytes]) -> Unit {
  if names.is_empty() {
    return
  }
  let sub = BinaryWriter::new()
  let keys = sorted_keys(names)
  sub.write_u32(keys.length())
  for idx in keys {
    sub.write_u32(idx)
    sub.write_name(names[idx])
  }
  let body = sub.to_bytes()
  w.write_byte(id)
  w.write_u32(body.length())
  w.write_bytes(body)
}

///|
/// The same, for the three spaces indexed twice: locals by function then slot,
/// labels by function then label, fields by type then field.
fn indirect_name_subsection(
  w : BinaryWriter,
  id : Int,
  names : Map[Int, Map[Int, Bytes]],
) -> Unit {
  if names.is_empty() {
    return
  }
  let sub = BinaryWriter::new()
  let outer = sorted_keys(names)
  sub.write_u32(outer.length())
  for o in outer {
    sub.write_u32(o)
    let inner_map = names[o]
    let inner = sorted_keys(inner_map)
    sub.write_u32(inner.length())
    for i in inner {
      sub.write_u32(i)
      sub.write_name(inner_map[i])
    }
  }
  let body = sub.to_bytes()
  w.write_byte(id)
  w.write_u32(body.length())
  w.write_bytes(body)
}

///|
/// The `name` section: twelve subsections, in ascending id order.
fn encode_name_section(w : BinaryWriter, names : Names) -> Unit {
  let b = BinaryWriter::new()
  if names.module_ is Some(name) {
    b.write_byte(0x00)
    let sub = BinaryWriter::new()
    sub.write_name(name)
    let body = sub.to_bytes()
    b.write_u32(body.length())
    b.write_bytes(body)
  }
  name_subsection(b, 0x01, names.functions)
  indirect_name_subsection(b, 0x02, names.locals)
  indirect_name_subsection(b, 0x03, names.labels)
  name_subsection(b, 0x04, names.types)
  name_subsection(b, 0x05, names.tables)
  name_subsection(b, 0x06, names.memories)
  name_subsection(b, 0x07, names.globals)
  name_subsection(b, 0x08, names.elem)
  name_subsection(b, 0x09, names.data)
  indirect_name_subsection(b, 0x0A, names.fields)
  name_subsection(b, 0x0B, names.tags)
  let body = b.to_bytes()
  if body.length() > 0 {
    write_custom_section(w, b"name", body)
  }
}

///|
/// The `target_features` section (a tool-conventions extension): a vector of
/// (prefix byte, feature name). The prefix says whether the feature is used,
/// required or disallowed; entries pass through verbatim, including any this
/// toolchain does not recognise.
fn encode_target_features_section(
  w : BinaryWriter,
  features : Array[(Int, Bytes)],
) -> Unit {
  if features.is_empty() {
    return
  }
  let b = BinaryWriter::new()
  b.write_u32(features.length())
  for f in features {
    let (prefix, name) = f
    b.write_byte(prefix)
    b.write_name(name)
  }
  write_custom_section(w, b"target_features", b.to_bytes())
}

///|
/// One function's hints, as the `metadata.code.*` sections want them: a
/// function index, then that function's (offset, payload) pairs.
priv struct FuncHints {
  funcidx : Int
  entries : Array[(Int, Bytes)]
}

///|
/// A `metadata.code.<kind>` section.
///
/// All four share a shape -- per function index, a vector of (offset within the
/// body, payload length, payload) -- so only the name and the payload bytes
/// differ. Both vectors are already in increasing order: functions are encoded
/// in order, and a body's opcodes are written at strictly increasing offsets.
fn encode_code_metadata_section(
  w : BinaryWriter,
  kind : Bytes,
  funcs : Array[FuncHints],
) -> Unit {
  if funcs.is_empty() {
    return
  }
  let b = BinaryWriter::new()
  b.write_u32(funcs.length())
  for f in funcs {
    b.write_u32(f.funcidx)
    b.write_u32(f.entries.length())
    for e in f.entries {
      let (offset, payload) = e
      b.write_u32(offset)
      b.write_u32(payload.length())
      b.write_bytes(payload)
    }
  }
  write_custom_section(w, b"metadata.code." + kind, b.to_bytes())
}

///|
/// `#[likely]` and `#[unlikely]` are one byte, 1 and 0.
fn branch_payload(likely : Bool) -> Bytes {
  if likely {
    b"\x01"
  } else {
    b"\x00"
  }
}

///|
/// A frequency is one byte, already reduced to the wire's offset logarithm.
fn freq_payload(f : Int) -> Bytes {
  let w = BinaryWriter::new()
  w.write_byte(f)
  w.to_bytes()
}

///|
/// Call targets are a run of LEB128 pairs: function index, then percentage.
fn call_targets_payload(targets : Array[(Int, Int)]) -> Bytes {
  let w = BinaryWriter::new()
  for t in targets {
    let (idx, pct) = t
    w.write_u32(idx)
    w.write_u32(pct)
  }
  w.to_bytes()
}

///|
/// A compilation priority, optionally followed by an optimization priority.
fn priority_payload(p : Priority) -> Bytes {
  let w = BinaryWriter::new()
  w.write_u32(p.compilation)
  if p.optimization is Some(o) {
    w.write_u32(o)
  }
  w.to_bytes()
}

///|
/// The hints gathered from every function body, already split across the four
/// sections that carry them.
priv struct CodeHints {
  branch : Array[FuncHints]
  freq : Array[FuncHints]
  targets : Array[FuncHints]
  priorities : Array[FuncHints]
}

///|
fn CodeHints::new() -> CodeHints {
  { branch: [], freq: [], targets: [], priorities: [] }
}

///|
/// Split one function's hints across the sections. A section takes an entry for
/// this function only if at least one of its hints is of that kind.
fn CodeHints::take(
  self : CodeHints,
  funcidx : Int,
  sink : Array[(Int, InstrHints)],
  priority : Priority?,
) -> Unit {
  fn collect(
    into : Array[FuncHints],
    payload_of : (InstrHints) -> Bytes?,
  ) -> Unit {
    let entries = []
    for e in sink {
      let (offset, hints) = e
      if payload_of(hints) is Some(payload) {
        entries.push((offset, payload))
      }
    }
    if !entries.is_empty() {
      into.push({ funcidx, entries })
    }
  }

  collect(self.branch, h => h.branch.map(branch_payload))
  collect(self.freq, h => h.freq.map(freq_payload))
  collect(self.targets, h => h.targets.map(call_targets_payload))
  // A priority is about the function, not an instruction, so it is recorded at
  // offset 0 -- the position that means "the function itself".
  if priority is Some(p) {
    self.priorities.push({ funcidx, entries: [(0, priority_payload(p))] })
  }
}
