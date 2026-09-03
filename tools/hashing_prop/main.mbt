///|
fn rotate_left(value : UInt, shift : Int) -> UInt {
  (value << shift) | (value >> (32 - shift))
}

///|
fn mix_word(value : UInt) -> UInt {
  let value = value * 0xcc9e2d51
  let value = rotate_left(value, 15)
  value * 0x1b873593
}

///|
fn finish(value : UInt) -> UInt {
  let value = value ^ (value >> 16)
  let value = value * 0x85ebca6b
  let value = value ^ (value >> 13)
  let value = value * 0xc2b2ae35
  value ^ (value >> 16)
}

///|
fn murmur3(bytes : Array[Int], seed : Int) -> Int {
  let mut hash = seed.reinterpret_as_uint()
  let mut offset = 0
  while offset + 4 <= bytes.length() {
    let word = bytes[offset].reinterpret_as_uint() |
      (bytes[offset + 1].reinterpret_as_uint() << 8) |
      (bytes[offset + 2].reinterpret_as_uint() << 16) |
      (bytes[offset + 3].reinterpret_as_uint() << 24)
    hash = hash ^ mix_word(word)
    hash = rotate_left(hash, 13) * 5 + 0xe6546b64
    offset += 4
  }
  let mut tail : UInt = 0
  let remaining = bytes.length() - offset
  if remaining >= 1 {
    tail = tail | bytes[offset].reinterpret_as_uint()
  }
  if remaining >= 2 {
    tail = tail | (bytes[offset + 1].reinterpret_as_uint() << 8)
  }
  if remaining == 3 {
    tail = tail | (bytes[offset + 2].reinterpret_as_uint() << 16)
  }
  if remaining != 0 {
    hash = hash ^ mix_word(tail)
  }
  finish(hash ^ bytes.length().reinterpret_as_uint()).reinterpret_as_int()
}

///|
fn emit_bytes(out : StringBuilder, bytes : Array[Int]) -> Unit {
  out.write_string("[wax_hash_bytes|")
  for index, byte in bytes {
    if index != 0 {
      out.write_string(",")
    }
    out.write_string("\{byte}")
  }
  out.write_string("]")
}

///|
fn main raise {
  let args = @env.args()
  if args.length() != 2 {
    println("usage: hashing_prop <output.wasm>")
    return
  }
  let seed : UInt64 = 0x48415348494e47
  let cases = 96
  let out = StringBuilder()
  out.write_string(@fs.read_file_to_string("stdlib/collections/hashing.wax"))
  out.write_string("\n")
  out.write_string(@fs.read_file_to_string("test/hashing/support.wax"))
  out.write_string("\n#[export = \"hashing_properties\"]\n")
  out.write_string("fn wax_hash_properties() -> i32 {\n")
  for case_index in 0..<cases {
    let length = if case_index < 12 {
      case_index
    } else {
      case_index * 53 % 257
    }
    let bytes = @quickcheck.int_range(0, 256)
      .array_with_size(length)
      .sample(size=length, seed=seed + case_index.to_uint64())
    let case_seed = @quickcheck.int_range(-0x7fffffff, 0x7fffffff).sample(
      seed=seed + 1000 + case_index.to_uint64(),
    )
    let word = @quickcheck.int_range(-0x7fffffff, 0x7fffffff).sample(
      seed=seed + 2000 + case_index.to_uint64(),
    )
    let word2 = @quickcheck.int_range(-0x7fffffff, 0x7fffffff).sample(
      seed=seed + 3000 + case_index.to_uint64(),
    )
    let expected = murmur3(bytes, case_seed)
    out.write_string("    wax_hash_assert(if wax_hash_bytes_seeded(")
    emit_bytes(out, bytes)
    out.write_string(", \{case_seed}) == \{expected} { 1 } else { 0 });\n")
    let unsigned_word = word.reinterpret_as_uint()
    let unsigned_word2 = word2.reinterpret_as_uint()
    let words = [
      (unsigned_word & 0xff).reinterpret_as_int(),
      ((unsigned_word >> 8) & 0xff).reinterpret_as_int(),
      ((unsigned_word >> 16) & 0xff).reinterpret_as_int(),
      ((unsigned_word >> 24) & 0xff).reinterpret_as_int(),
      (unsigned_word2 & 0xff).reinterpret_as_int(),
      ((unsigned_word2 >> 8) & 0xff).reinterpret_as_int(),
      ((unsigned_word2 >> 16) & 0xff).reinterpret_as_int(),
      ((unsigned_word2 >> 24) & 0xff).reinterpret_as_int(),
    ]
    out.write_string(
      "    wax_hash_assert(if wax_hash_i32_seeded(\{word}, \{case_seed}) == wax_hash_bytes_seeded(",
    )
    emit_bytes(out, [words[0], words[1], words[2], words[3]])
    out.write_string(", \{case_seed}) { 1 } else { 0 });\n")
    out.write_string(
      "    wax_hash_assert(if wax_hash_finalize(wax_hash_add_i32(wax_hash_add_i32(\{case_seed}, \{word}), \{word2}), 8) == wax_hash_bytes_seeded(",
    )
    emit_bytes(out, words)
    out.write_string(", \{case_seed}) { 1 } else { 0 });\n")
  }
  out.write_string("    1\n}\n")
  let source = out.to_string()
  @fs.write_string_to_file(args[1] + ".wax", source)
  let bytes = match
    @wax.compile_string(source, fname="generated-hashing-properties.wax") {
    Ok(bytes) => bytes
    Err(diagnostics) =>
      abort(
        "generated Wax hashing module was rejected (\{diagnostics.length()} diagnostics)",
      )
  }
  @fs.write_bytes_to_file(args[1], bytes)
  println("hashing properties: seed=\{seed}, cases=\{cases}")
}
