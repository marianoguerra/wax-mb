///|
fn emit_bytes(out : StringBuilder, bytes : Array[Int]) -> Unit {
  out.write_string("[wax_hash_bytes|")
  for index, byte in bytes {
    if index != 0 {
      out.write_string(",")
    }
    out.write_string(byte.to_string())
  }
  out.write_string("]")
}

///|
fn append_utf8(scalar : Int, out : Array[Int]) -> Unit {
  if scalar <= 0x7f {
    out.push(scalar)
  } else if scalar <= 0x7ff {
    out.push(0xc0 | (scalar >> 6))
    out.push(0x80 | (scalar & 0x3f))
  } else if scalar <= 0xffff {
    out.push(0xe0 | (scalar >> 12))
    out.push(0x80 | ((scalar >> 6) & 0x3f))
    out.push(0x80 | (scalar & 0x3f))
  } else {
    out.push(0xf0 | (scalar >> 18))
    out.push(0x80 | ((scalar >> 12) & 0x3f))
    out.push(0x80 | ((scalar >> 6) & 0x3f))
    out.push(0x80 | (scalar & 0x3f))
  }
}

///|
fn valid_utf8_case(case_index : Int, seed : UInt64) -> Array[Int] {
  let count = case_index % 9
  let raw = @quickcheck.int_range(0, 0x110000)
    .array_with_size(count)
    .sample(size=count, seed~)
  let bytes : Array[Int] = []
  for value in raw {
    let scalar = if value >= 0xd800 && value <= 0xdfff {
      value + 0x800
    } else {
      value
    }
    append_utf8(scalar, bytes)
  }
  bytes
}

///|
fn emit_utf8_cases(
  out : StringBuilder,
  cases_out : StringBuilder,
  seed : UInt64,
) -> Int {
  let count = 96
  for case_index in 0..<count {
    let bytes = if case_index < 48 {
      valid_utf8_case(case_index, seed + case_index.to_uint64())
    } else {
      let length = case_index * 17 % 31
      @quickcheck.int_range(0, 256)
      .array_with_size(length)
      .sample(size=length, seed=seed + case_index.to_uint64())
    }
    out.write_string(
      "#[export = \"stdlib_utf8_case_\{case_index}\"]\nfn st_utf8_case_\{case_index}() -> i32 {\n    let (valid, _) = utf8_try_from_bytes(",
    )
    emit_bytes(out, bytes)
    out.write_string(");\n    valid\n}\n\n")
    for index, byte in bytes {
      if index != 0 {
        cases_out.write_string(",")
      }
      cases_out.write_string(byte.to_string())
    }
    cases_out.write_string("\n")
  }
  count
}

///|
fn emit_map_assert(
  out : StringBuilder,
  key : Int,
  present : Bool,
  value : Int,
) -> Unit {
  out.write_string(
    "    st_assert_map(map, \{key}, \{if present { 1 } else { 0 }}, \{value});\n",
  )
}

///|
fn emit_set_assert(out : StringBuilder, value : Int, present : Bool) -> Unit {
  out.write_string(
    "    st_assert_set(set, \{value}, \{if present { 1 } else { 0 }});\n",
  )
}

///|
fn emit_expected_i32(out : StringBuilder, values : Array[Int]) -> Unit {
  out.write_string("[st_expected_i32|")
  for index, value in values {
    if index != 0 {
      out.write_string(",")
    }
    out.write_string(value.to_string())
  }
  out.write_string("]")
}

///|
fn emit_order_asserts(
  out : StringBuilder,
  map_keys : Array[Int],
  map_values : @hashmap.HashMap[Int, Int],
  set_values : Array[Int],
  map_name? : String = "ordered_map",
  set_name? : String = "ordered_set",
) -> Unit {
  out.write_string("    st_assert_ordered_map(\{map_name}, ")
  emit_expected_i32(out, map_keys)
  out.write_string(", ")
  let values : Array[Int] = []
  for key in map_keys {
    values.push(map_values[key])
  }
  emit_expected_i32(out, values)
  out.write_string(");\n    st_assert_ordered_set(\{set_name}, ")
  emit_expected_i32(out, set_values)
  out.write_string(");\n")
}

///|
fn emit_property_case(
  out : StringBuilder,
  case_index : Int,
  inputs : Array[Int],
) -> Unit {
  let vector : Array[Int] = []
  let map : @hashmap.HashMap[Int, Int] = @hashmap.HashMap::HashMap([])
  let set : @hashmap.HashMap[Int, Int] = @hashmap.HashMap::HashMap([])
  let ordered_map_keys : Array[Int] = []
  let ordered_map_values : @hashmap.HashMap[Int, Int] = @hashmap.HashMap([])
  let ordered_set_values : Array[Int] = []
  let record_values = [0, 0, 0]
  out.write_string("fn st_property_case_\{case_index}() {\n")
  out.write_string("    st_stage = \{100 + case_index};\n")
  out.write_string("    let vector = jv_vector_empty();\n")
  out.write_string("    let map = jv_map_empty();\n")
  out.write_string("    let set = jv_set_empty();\n")
  out.write_string("    let ordered_map = jv_ordered_map_empty();\n")
  out.write_string("    let ordered_set = jv_ordered_set_empty();\n")
  out.write_string(
    "    let record = jv_record_default(st_property_record_type());\n",
  )
  for step, raw in inputs {
    let n = if raw < 0 { -raw } else { raw }
    let operation = n % 12
    let key = n / 17 % 64
    let value = n % 20001 - 10000
    if operation <= 1 {
      out.write_string("    let old_vector_\{step} = vector;\n")
      out.write_string(
        "    vector = jv_vector_push(vector, jv_i32(\{value}));\n",
      )
      out.write_string(
        "    st_assert(if jv_vector_count(old_vector_\{step}) == \{vector.length()} { 1 } else { 0 });\n",
      )
      vector.push(value)
      out.write_string(
        "    st_assert_vector(vector, \{vector.length() - 1}, \{value});\n",
      )
    } else if operation == 2 && !vector.is_empty() {
      let index = n / 29 % vector.length()
      let old_value = vector[index]
      out.write_string("    let old_vector_\{step} = vector;\n")
      out.write_string(
        "    vector = jv_vector_assoc(vector, \{index}, jv_i32(\{value}));\n",
      )
      out.write_string(
        "    st_assert_vector(old_vector_\{step}, \{index}, \{old_value});\n",
      )
      vector[index] = value
      out.write_string("    st_assert_vector(vector, \{index}, \{value});\n")
    } else if operation == 3 && !vector.is_empty() {
      let index = vector.length() - 1
      let old_value = vector[index]
      out.write_string("    let old_vector_\{step} = vector;\n")
      out.write_string("    vector = jv_vector_pop(vector);\n")
      out.write_string(
        "    st_assert_vector(old_vector_\{step}, \{index}, \{old_value});\n",
      )
      ignore(vector.pop())
    } else if operation <= 6 {
      let was_present = map.contains(key)
      let old_value = map.get(key).unwrap_or(0)
      out.write_string("    let old_map_\{step} = map;\n")
      out.write_string(
        "    map = jv_map_assoc(map, st_key(\{key}), jv_i32(\{value}));\n",
      )
      out.write_string(
        "    ordered_map = jv_ordered_map_assoc(ordered_map, st_key(\{key}), jv_i32(\{value}));\n",
      )
      out.write_string(
        "    st_assert_map(old_map_\{step}, \{key}, \{if was_present { 1 } else { 0 }}, \{old_value});\n",
      )
      map.set(key, value)
      if !ordered_map_values.contains(key) {
        ordered_map_keys.push(key)
      }
      ordered_map_values.set(key, value)
      emit_map_assert(out, key, true, value)
    } else if operation == 7 {
      let was_present = map.contains(key)
      let old_value = map.get(key).unwrap_or(0)
      out.write_string("    let old_map_\{step} = map;\n")
      out.write_string("    map = jv_map_dissoc(map, st_key(\{key}));\n")
      out.write_string(
        "    ordered_map = jv_ordered_map_dissoc(ordered_map, st_key(\{key}));\n",
      )
      out.write_string(
        "    st_assert_map(old_map_\{step}, \{key}, \{if was_present { 1 } else { 0 }}, \{old_value});\n",
      )
      if was_present {
        map.remove(key)
      }
      if ordered_map_values.contains(key) {
        ordered_map_values.remove(key)
        let index = ordered_map_keys.search_by(item => item == key).unwrap()
        ignore(ordered_map_keys.remove(index))
      }
      emit_map_assert(out, key, false, 0)
    } else if operation <= 9 {
      out.write_string("    let old_set_\{step} = set;\n")
      out.write_string("    set = jv_set_add(set, jv_i32(\{value}));\n")
      out.write_string(
        "    ordered_set = jv_ordered_set_add(ordered_set, jv_i32(\{value}));\n",
      )
      out.write_string(
        "    st_assert(if jv_set_count(old_set_\{step}) == \{set.length()} { 1 } else { 0 });\n",
      )
      set.set(value, 1)
      if ordered_set_values.search_by(item => item == value) is None {
        ordered_set_values.push(value)
      }
      emit_set_assert(out, value, true)
    } else if operation == 10 {
      let was_present = set.contains(value)
      out.write_string("    let old_set_\{step} = set;\n")
      out.write_string("    set = jv_set_remove(set, jv_i32(\{value}));\n")
      out.write_string(
        "    ordered_set = jv_ordered_set_remove(ordered_set, jv_i32(\{value}));\n",
      )
      out.write_string(
        "    st_assert_set(old_set_\{step}, \{value}, \{if was_present { 1 } else { 0 }});\n",
      )
      if was_present {
        set.remove(value)
      }
      match ordered_set_values.search_by(item => item == value) {
        Some(index) => ignore(ordered_set_values.remove(index))
        None => ()
      }
      emit_set_assert(out, value, false)
    } else {
      emit_map_assert(out, key, map.contains(key), map.get(key).unwrap_or(0))
      emit_set_assert(out, value, set.contains(value))
      if !vector.is_empty() {
        let index = n / 31 % vector.length()
        out.write_string(
          "    st_assert_vector(vector, \{index}, \{vector[index]});\n",
        )
      }
    }
    out.write_string(
      "    st_assert(if jv_vector_count(vector) == \{vector.length()} { 1 } else { 0 });\n",
    )
    out.write_string(
      "    st_assert(if jv_map_count(map) == \{map.length()} { 1 } else { 0 });\n",
    )
    out.write_string(
      "    st_assert(if jv_set_count(set) == \{set.length()} { 1 } else { 0 });\n",
    )
    emit_order_asserts(
      out, ordered_map_keys, ordered_map_values, ordered_set_values,
    )
    let record_operation = n / 13 % 6
    let record_field = n / 37 % 3
    let field_key = record_field + 1
    if record_operation <= 2 {
      let old_value = record_values[record_field]
      out.write_string("    let old_record_\{step} = record;\n")
      out.write_string(
        "    let (record_status_\{step}, record_out_\{step}) = jv_record_try_set(record, st_key(\{field_key}), jv_i32(\{value}));\n",
      )
      out.write_string(
        "    st_assert(if record_status_\{step} == jv_record_ok { 1 } else { 0 });\n",
      )
      out.write_string("    record = record_out_\{step}!;\n")
      out.write_string(
        "    st_assert_record(old_record_\{step}, \{field_key}, \{old_value});\n",
      )
      record_values[record_field] = value
    } else if record_operation == 3 {
      let old_value = record_values[record_field]
      out.write_string("    let old_record_\{step} = record;\n")
      out.write_string(
        "    record = jv_record_reset(record, st_key(\{field_key}));\n",
      )
      out.write_string(
        "    st_assert_record(old_record_\{step}, \{field_key}, \{old_value});\n",
      )
      record_values[record_field] = 0
    } else if record_operation == 4 {
      out.write_string(
        "    let (record_status_\{step}, _) = jv_record_try_set(record, st_key(\{field_key}), jv_bool(1));\n",
      )
      out.write_string(
        "    st_assert(if record_status_\{step} == jv_record_type_mismatch { 1 } else { 0 });\n",
      )
    } else {
      out.write_string(
        "    let (record_status_\{step}, _) = jv_record_try_set(record, st_key(63), jv_i32(\{value}));\n",
      )
      out.write_string(
        "    st_assert(if record_status_\{step} == jv_record_unknown_field { 1 } else { 0 });\n",
      )
    }
    for index, expected in record_values {
      out.write_string(
        "    st_assert_record(record, \{index + 1}, \{expected});\n",
      )
    }
    out.write_string(
      "    st_assert(if jv_record_count(record) == 3 { 1 } else { 0 });\n",
    )
  }
  out.write_string(
    "    let transient_ordered_map = jv_ordered_map_as_transient(ordered_map);\n",
  )
  out.write_string(
    "    let transient_ordered_set = jv_ordered_set_as_transient(ordered_set);\n",
  )
  for step in 0..<16 {
    let raw = inputs[step]
    let n = if raw < 0 { -raw } else { raw }
    let key = n / 17 % 64
    let value = n % 20001 - 10000
    if step % 3 != 2 {
      out.write_string(
        "    jvt_ordered_map_assoc(transient_ordered_map, st_key(\{key}), jv_i32(\{value}));\n",
      )
      if !ordered_map_values.contains(key) {
        ordered_map_keys.push(key)
      }
      ordered_map_values.set(key, value)
      out.write_string(
        "    jvt_ordered_set_add(transient_ordered_set, jv_i32(\{value}));\n",
      )
      if ordered_set_values.search_by(item => item == value) is None {
        ordered_set_values.push(value)
      }
    } else {
      out.write_string(
        "    jvt_ordered_map_dissoc(transient_ordered_map, st_key(\{key}));\n",
      )
      if ordered_map_values.contains(key) {
        ordered_map_values.remove(key)
        let index = ordered_map_keys.search_by(item => item == key).unwrap()
        ignore(ordered_map_keys.remove(index))
      }
      out.write_string(
        "    jvt_ordered_set_remove(transient_ordered_set, jv_i32(\{value}));\n",
      )
      match ordered_set_values.search_by(item => item == value) {
        Some(index) => ignore(ordered_set_values.remove(index))
        None => ()
      }
    }
  }
  out.write_string(
    "    let frozen_ordered_map = jvt_ordered_map_persistent(transient_ordered_map);\n",
  )
  out.write_string(
    "    let frozen_ordered_set = jvt_ordered_set_persistent(transient_ordered_set);\n",
  )
  emit_order_asserts(
    out,
    ordered_map_keys,
    ordered_map_values,
    ordered_set_values,
    map_name="frozen_ordered_map",
    set_name="frozen_ordered_set",
  )
  out.write_string("}\n\n")
}

///|
fn append_sources(out : StringBuilder) -> Unit raise {
  for
    path in [
      "stdlib/collections/hashing.wax", "stdlib/collections/persistent_hash_map.wax",
      "stdlib/collections/persistent_hash_set.wax", "stdlib/collections/persistent_vector.wax",
      "stdlib/text/utf8.wax", "stdlib/data/immutable_value.wax", "stdlib/data/record.wax",
      "test/stdlib/support.wax", "stdlib/data/example.wax",
    ] {
    out.write_string(@fs.read_file_to_string(path))
    out.write_string("\n")
  }
}

///|
fn main raise {
  let args = @env.args()
  if args.length() != 3 {
    println("usage: stdlib_prop <output.wasm> <utf8-cases.txt>")
    return
  }
  let seed : UInt64 = 0x5354444c49425631
  let traces = @quickcheck.int_range(-1000000, 1000001)
    .array_with_size(48)
    .samples(count=24, size=48, seed~)
  let out = StringBuilder()
  append_sources(out)
  for case_index, inputs in traces {
    emit_property_case(out, case_index, inputs)
  }
  out.write_string("#[export = \"stdlib_properties\"]\n")
  out.write_string("fn st_properties() -> i32 {\n")
  for case_index in 0..<traces.length() {
    out.write_string("    st_property_case_\{case_index}();\n")
  }
  out.write_string("    1\n}\n\n")
  let utf8_cases = StringBuilder()
  let utf8_count = emit_utf8_cases(out, utf8_cases, seed + 1000)
  let source = out.to_string()
  @fs.write_string_to_file(args[1] + ".wax", source)
  @fs.write_string_to_file(args[2], utf8_cases.to_string())
  let bytes = match
    @wax.compile_string(source, fname="generated-stdlib-properties.wax") {
    Ok(bytes) => bytes
    Err(diagnostics) => {
      for diagnostic in diagnostics {
        println(@message.to_plain_string(diagnostic.message))
      }
      abort(
        "generated Wax stdlib module was rejected (\{diagnostics.length()} diagnostics)",
      )
    }
  }
  @fs.write_bytes_to_file(args[1], bytes)
  println(
    "stdlib properties: seed=\{seed}, traces=\{traces.length()}, utf8_cases=\{utf8_count}",
  )
}
