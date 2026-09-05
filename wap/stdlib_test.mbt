///|
let hashing_wap : String =
  #|// MurmurHash3 x86-32 for wap byte arrays and boxed integer keys.
  #|//
  #|// A port of `stdlib/collections/hashing.wax`. Two things are worth comparing
  #|// against the original. The `wax_hash_` prefix on every name is gone: the
  #|// module supplies it, and the emitted names are `hashing__*`. And the `>>u`
  #|// spellings are gone with it -- the state is a `u32`, so `>>` is already the
  #|// logical shift, and a signed shift would be a different type rather than a
  #|// different operator.
  #|//
  #|// `||` is bitwise or here, not logical: shrubbery's `|` introduces
  #|// alternatives, so `||` carries both meanings and the operand type decides
  #|// which -- the same rule that decides `>>`.
  #|
  #|module hashing
  #|
  #|type bytes = [u8]
  #|
  #|fn mix_i32(value :: u32) -> u32:
  #|  var mixed = value * 0xcc9e2d51
  #|  mixed = mixed.rotl(15)
  #|  mixed * 0x1b873593
  #|
  #|// Add one 32-bit word to the state. A composite key's hash begins with its
  #|// seed, adds each field, then finalizes with the total byte length.
  #|fn add_i32(state :: u32, value :: u32) -> u32:
  #|  let out = state ^ mix_i32(value)
  #|  out.rotl(13) * 5 + 0xe6546b64
  #|
  #|fn finalize(state :: u32, byte_length :: u32) -> u32:
  #|  var out = state ^ byte_length
  #|  out ^= out >> 16
  #|  out *= 0x85ebca6b
  #|  out ^= out >> 13
  #|  out *= 0xc2b2ae35
  #|  out ^ out >> 16
  #|
  #|fn i32_seeded(value :: u32, seed :: u32) -> u32:
  #|  finalize(add_i32(seed, value), 4)
  #|
  #|export "hash_i32" fn i32_value(value :: u32) -> u32:
  #|  i32_seeded(value, 0)
  #|
  #|fn bytes_seeded(data :: bytes, seed :: u32) -> u32:
  #|  var state = seed
  #|  let length = data.len()
  #|  var offset :: u32 = 0
  #|  while offset + 4 <= length:
  #|    let word = data[offset]
  #|      || data[offset + 1] << 8
  #|      || data[offset + 2] << 16
  #|      || data[offset + 3] << 24
  #|    state = add_i32(state, word)
  #|    offset += 4
  #|  let remaining = length - offset
  #|  if remaining != 0:
  #|    var tail :: u32 = data[offset]
  #|    if remaining >= 2:
  #|      tail ||= data[offset + 1] << 8
  #|    if remaining == 3:
  #|      tail ||= data[offset + 2] << 16
  #|    state ^= mix_i32(tail)
  #|  finalize(state, length)
  #|
  #|export "hash_bytes" fn bytes_value(data :: bytes) -> u32:
  #|  bytes_seeded(data, 0)
  #|
  #|fn i31_key(key :: eq) -> u32:
  #|  i32_value(key as i32_s)
  #|
  #|fn equal_i31_key(left :: eq, right :: eq) -> bool:
  #|  (left as i32_s) == (right as i32_s)
  #|
  #|fn bytes_key(key :: eq) -> u32:
  #|  bytes_value(key as bytes)
  #|
  #|export "equal_bytes" fn equal_bytes_key(left :: eq, right :: eq) -> bool:
  #|  if left == right:
  #|    return true
  #|  let a = left as bytes
  #|  let b = right as bytes
  #|  if a.len() != b.len():
  #|    return false
  #|  for i in 0 ..< a.len():
  #|    if a[i] != b[i]:
  #|      return false
  #|  true

///|
test "the hashing stdlib module, ported to wap, compiles" {
  let w = try_wat(hashing_wap)
  if w.contains("FAILED") {
    println(w)
    fail("hashing.wap did not compile")
  }
  // The module supplies the prefix the .wax file writes by hand.
  assert_true(w.contains("$hashing__mix_i32"))
  // `u32` chose the logical shift with no `>>u` in the source.
  assert_true(w.contains("i32.shr_u"))
  assert_true(w.contains("i32.rotl"))
  assert_true(w.contains("array.get_u"))
}

///|
let pv_wap : String =
  #|// A persistent vector: the bit-partitioned trie, ported from
  #|// `stdlib/collections/persistent_vector.wax`.
  #|//
  #|// The .wax original opens with this comment:
  #|//
  #|//   All names use pv_/pvt_ prefixes because Wax has no source namespaces.
  #|//
  #|// That is the whole difference. Here the names are `node`, `empty`, `push`;
  #|// the module supplies the prefix, and the emitted wasm calls them
  #|// `persistent_vector__node`, `persistent_vector__empty` and so on. Nothing
  #|// else about the data structure changed.
  #|//
  #|// This is the persistent half. The transient half of the .wax file is a
  #|// separate exercise and is not ported here.
  #|
  #|module persistent_vector
  #|
  #|const branching = 32
  #|const shift_bits = 5
  #|const mask = 31
  #|
  #|type visit = fn(eq?, i32, eq?)
  #|type edit = { active :: mut i32 }
  #|type slots = [eq?]
  #|
  #|type node = {
  #|  edit :: mut edit?,
  #|  slots :: mut slots,
  #|}
  #|
  #|type vector = {
  #|  count :: i32,
  #|  shift :: i32,
  #|  root :: node,
  #|  tail :: slots,
  #|}
  #|
  #|fn node_new(owner :: edit?) -> node:
  #|  node{edit: owner, slots: slots[null ** branching]}
  #|
  #|fn copy_slots(src :: slots, length :: i32) -> slots:
  #|  let dst = slots[null ** length]
  #|  let n = if src.len() < length | src.len() | length
  #|  if n != 0:
  #|    dst.copy(0, src, 0, n)
  #|  dst
  #|
  #|fn node_copy(n :: node) -> node:
  #|  node{edit: null, slots: copy_slots(n.slots, branching)}
  #|
  #|fn tail_offset(count :: i32) -> i32:
  #|  if count < branching:
  #|    return 0
  #|  ((count - 1) >> shift_bits) << shift_bits
  #|
  #|fn new_path(level :: i32, n :: node) -> node:
  #|  if level == 0:
  #|    return n
  #|  let parent = node_new(null)
  #|  parent.slots[0] = new_path(level - shift_bits, n)
  #|  parent
  #|
  #|fn push_tail(level :: i32, parent :: node, tail_node :: node, index :: i32) -> node:
  #|  let out = node_copy(parent)
  #|  let subidx = (index >> level) & mask
  #|  if level == shift_bits:
  #|    out.slots[subidx] = tail_node
  #|    return out
  #|  let child = parent.slots[subidx]
  #|  if child == null
  #|  | out.slots[subidx] = new_path(level - shift_bits, tail_node)
  #|  | out.slots[subidx] = push_tail(level - shift_bits, child as node, tail_node, index)
  #|  out
  #|
  #|fn do_assoc(level :: i32, n :: node, index :: i32, value :: eq?) -> node:
  #|  let out = node_copy(n)
  #|  if level == 0:
  #|    out.slots[index & mask] = value
  #|    return out
  #|  let subidx = (index >> level) & mask
  #|  out.slots[subidx] = do_assoc(level - shift_bits, n.slots[subidx] as node, index, value)
  #|  out
  #|
  #|fn array_for(v :: vector, index :: i32) -> slots:
  #|  if index < 0:
  #|    unreachable
  #|  if index >= v.count:
  #|    unreachable
  #|  if index >= tail_offset(v.count):
  #|    return v.tail
  #|  var n = v.root
  #|  var level = v.shift
  #|  while level > 0:
  #|    n = n.slots[(index >> level) & mask] as node
  #|    level -= shift_bits
  #|  n.slots
  #|
  #|fn pop_tail(level :: i32, n :: node, index :: i32) -> node?:
  #|  let subidx = (index >> level) & mask
  #|  if level > shift_bits:
  #|    let child = pop_tail(level - shift_bits, n.slots[subidx] as node, index)
  #|    if child == null:
  #|      if subidx == 0:
  #|        return null
  #|    let out = node_copy(n)
  #|    out.slots[subidx] = child
  #|    return out
  #|  if subidx == 0:
  #|    return null
  #|  let out = node_copy(n)
  #|  out.slots[subidx] = null
  #|  out
  #|
  #|export "pv_empty" fn empty() -> vector:
  #|  vector{count: 0, shift: shift_bits, root: node_new(null), tail: slots[null ** 0]}
  #|
  #|export "pv_count" fn count(v :: vector) -> i32:
  #|  v.count
  #|
  #|fn get(v :: vector, index :: i32) -> (i32, eq?):
  #|  if index < 0:
  #|    return (0, null)
  #|  if index >= v.count:
  #|    return (0, null)
  #|  let found = array_for(v, index)
  #|  (1, found[index & mask])
  #|
  #|export "pv_at" fn at(v :: vector, index :: i32) -> eq?:
  #|  let (ok, value) = get(v, index)
  #|  if ok == 0:
  #|    unreachable
  #|  value
  #|
  #|export "pv_push" fn push(v :: vector, value :: eq?) -> vector:
  #|  if v.count == 0x7fffffff:
  #|    unreachable
  #|  if v.tail.len() < branching:
  #|    let grown_tail = copy_slots(v.tail, v.tail.len() + 1)
  #|    grown_tail[v.tail.len()] = value
  #|    return vector{
  #|      count: v.count + 1,
  #|      shift: v.shift,
  #|      root: v.root,
  #|      tail: grown_tail,
  #|    }
  #|  let tail_node = node{edit: null, slots: v.tail}
  #|  var shift = v.shift
  #|  var root = v.root
  #|  if (v.count >> shift_bits) > (1 << shift)
  #|  | let grown = node_new(null)
  #|    grown.slots[0] = v.root
  #|    grown.slots[1] = new_path(shift, tail_node)
  #|    shift += shift_bits
  #|    root = grown
  #|  | root = push_tail(shift, v.root, tail_node, v.count - 1)
  #|  vector{count: v.count + 1, shift: shift, root: root, tail: slots[value]}
  #|
  #|export "pv_assoc" fn assoc(v :: vector, index :: i32, value :: eq?) -> vector:
  #|  if index == v.count:
  #|    return push(v, value)
  #|  if index < 0:
  #|    unreachable
  #|  if index >= v.count:
  #|    unreachable
  #|  let offset = tail_offset(v.count)
  #|  if index >= offset:
  #|    if v.tail[index & mask] == value:
  #|      return v
  #|    let updated = copy_slots(v.tail, v.tail.len())
  #|    updated[index & mask] = value
  #|    return vector{
  #|      count: v.count,
  #|      shift: v.shift,
  #|      root: v.root,
  #|      tail: updated,
  #|    }
  #|  vector{
  #|    count: v.count,
  #|    shift: v.shift,
  #|    root: do_assoc(v.shift, v.root, index, value),
  #|    tail: v.tail,
  #|  }
  #|
  #|fn peek(v :: vector) -> (i32, eq?):
  #|  if v.count == 0:
  #|    return (0, null)
  #|  (1, v.tail[v.tail.len() - 1])
  #|
  #|export "pv_pop" fn pop(v :: vector) -> vector:
  #|  if v.count == 0:
  #|    unreachable
  #|  if v.count == 1:
  #|    return empty()
  #|  if v.tail.len() > 1:
  #|    return vector{
  #|      count: v.count - 1,
  #|      shift: v.shift,
  #|      root: v.root,
  #|      tail: copy_slots(v.tail, v.tail.len() - 1),
  #|    }
  #|  let new_tail = array_for(v, v.count - 2)
  #|  let shrunk = pop_tail(v.shift, v.root, v.count - 2)
  #|  var root = if shrunk == null | node_new(null) | shrunk!
  #|  var shift = v.shift
  #|  if shift > shift_bits:
  #|    if root.slots[1] == null:
  #|      root = root.slots[0] as node
  #|      shift -= shift_bits
  #|  vector{count: v.count - 1, shift: shift, root: root, tail: new_tail}
  #|
  #|export "pv_each" fn each(v :: vector, context :: eq?, seen :: visit):
  #|  for i in 0 ..< v.count:
  #|    seen(context, i, at(v, i))

///|
test "the persistent vector, ported to wap, compiles" {
  let w = try_wat(pv_wap)
  if w.contains("FAILED") {
    println(w)
    fail("persistent_vector.wap did not compile")
  }
  assert_true(w.contains("$persistent_vector__push"))
  assert_true(w.contains("\"pv_empty\""))
}
