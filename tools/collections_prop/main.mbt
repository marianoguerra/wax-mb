///|
priv struct MapModel {
  entries : @hashmap.HashMap[Int, Int?]
}

///|
fn normalized(value : Int) -> Int {
  if value < 0 {
    -value
  } else {
    value
  }
}

///|
fn key_hash(key : Int) -> Int {
  if key % 5 == 0 {
    7
  } else {
    key * 0x45d9f3b
  }
}

///|
fn key_expr(key : Int) -> String {
  "ct_key_new(\{key}, \{key_hash(key)})"
}

///|
fn value_expr(value : Int?) -> String {
  match value {
    None => "null"
    Some(n) => "ct_box(\{n})"
  }
}

///|
fn emit_map_assert(
  out : StringBuilder,
  map : String,
  key : String,
  present : Bool,
  value : Int?,
) -> Unit {
  let found = if present { 1 } else { 0 }
  let is_null = if value is None { 1 } else { 0 }
  let expected = value.unwrap_or(0)
  out.write_string(
    "    ct_assert_map(\{map}, \{key}, \{found}, \{is_null}, \{expected});\n",
  )
}

///|
fn emit_vector_assert(
  out : StringBuilder,
  vector : String,
  index : Int,
  present : Bool,
  value : Int?,
) -> Unit {
  let found = if present { 1 } else { 0 }
  let is_null = if value is None { 1 } else { 0 }
  let expected = value.unwrap_or(0)
  out.write_string(
    "    ct_assert_vector(\{vector}, \{index}, \{found}, \{is_null}, \{expected});\n",
  )
}

///|
fn emit_case(
  out : StringBuilder,
  case_index : Int,
  inputs : Array[Int],
) -> Unit {
  let model = { entries: @hashmap.HashMap::HashMap([]) }
  let vector : Array[Int?] = []
  out.write_string("fn ct_property_case_\{case_index}() {\n")
  out.write_string("    ct_stage = \{100 + case_index};\n")
  out.write_string("    let map = phm_empty(ct_hash, ct_equal);\n")
  out.write_string("    let vector = pv_empty();\n")
  for step, raw in inputs {
    let n = normalized(raw)
    let operation = n % 10
    let key = n / 17 % 64
    let value : Int? = if n / 13 % 7 == 0 {
      None
    } else {
      Some(n % 10000 - 5000)
    }
    if operation <= 2 {
      let was_present = model.entries.contains(key)
      let old_value = model.entries.get(key).unwrap_or(None)
      out.write_string("    let old_map_\{step} = map;\n")
      out.write_string(
        "    map = phm_assoc(map, \{key_expr(key)}, \{value_expr(value)});\n",
      )
      model.entries.set(key, value)
      emit_map_assert(
        out,
        "old_map_\{step}",
        key_expr(key),
        was_present,
        old_value,
      )
      emit_map_assert(out, "map", key_expr(key), true, value)
    } else if operation == 3 {
      let was_present = model.entries.contains(key)
      let old_value = model.entries.get(key).unwrap_or(None)
      out.write_string("    let old_map_\{step} = map;\n")
      out.write_string("    map = phm_dissoc(map, \{key_expr(key)});\n")
      if was_present {
        model.entries.remove(key)
      }
      emit_map_assert(
        out,
        "old_map_\{step}",
        key_expr(key),
        was_present,
        old_value,
      )
      emit_map_assert(out, "map", key_expr(key), false, None)
    } else if operation == 4 {
      let was_present = model.entries.contains(64)
      let old_value = model.entries.get(64).unwrap_or(None)
      out.write_string("    let old_map_\{step} = map;\n")
      if n / 19 % 3 == 0 {
        out.write_string("    map = phm_dissoc(map, null);\n")
        if was_present {
          model.entries.remove(64)
        }
        emit_map_assert(out, "map", "null", false, None)
      } else {
        out.write_string(
          "    map = phm_assoc(map, null, \{value_expr(value)});\n",
        )
        model.entries.set(64, value)
        emit_map_assert(out, "map", "null", true, value)
      }
      emit_map_assert(out, "old_map_\{step}", "null", was_present, old_value)
    } else if operation <= 6 {
      out.write_string("    let old_vector_\{step} = vector;\n")
      out.write_string("    vector = pv_push(vector, \{value_expr(value)});\n")
      vector.push(value)
      emit_vector_assert(
        out,
        "old_vector_\{step}",
        vector.length() - 1,
        false,
        None,
      )
      emit_vector_assert(out, "vector", vector.length() - 1, true, value)
    } else if operation == 7 {
      if !vector.is_empty() {
        let index = n / 23 % vector.length()
        let old_value = vector[index]
        out.write_string("    let old_vector_\{step} = vector;\n")
        out.write_string(
          "    vector = pv_assoc(vector, \{index}, \{value_expr(value)});\n",
        )
        vector[index] = value
        emit_vector_assert(out, "old_vector_\{step}", index, true, old_value)
        emit_vector_assert(out, "vector", index, true, value)
      }
    } else if operation == 8 {
      if !vector.is_empty() {
        let old_index = vector.length() - 1
        let old_value = vector[old_index]
        out.write_string("    let old_vector_\{step} = vector;\n")
        out.write_string("    vector = pv_pop(vector);\n")
        ignore(vector.pop())
        emit_vector_assert(
          out,
          "old_vector_\{step}",
          old_index,
          true,
          old_value,
        )
        emit_vector_assert(out, "vector", old_index, false, None)
      }
    } else {
      emit_map_assert(
        out,
        "map",
        key_expr(key),
        model.entries.contains(key),
        model.entries.get(key).unwrap_or(None),
      )
      let index = if vector.is_empty() {
        0
      } else {
        n / 29 % (vector.length() + 1)
      }
      emit_vector_assert(
        out,
        "vector",
        index,
        index < vector.length(),
        if index < vector.length() {
          vector[index]
        } else {
          None
        },
      )
    }
    out.write_string(
      "    ct_assert(if phm_count(map) == \{model.entries.length()} { 1 } else { 0 });\n",
    )
    out.write_string(
      "    ct_assert(if pv_count(vector) == \{vector.length()} { 1 } else { 0 });\n",
    )
  }

  out.write_string("    let transient_map = phm_as_transient(map);\n")
  for key = 0; key < 20; key = key + 1 {
    let value : Int? = if key % 6 == 0 { None } else { Some(20000 + key) }
    out.write_string(
      "    phmt_assoc(transient_map, \{key_expr(key)}, \{value_expr(value)});\n",
    )
    model.entries.set(key, value)
  }
  for key = 40; key < 48; key = key + 1 {
    out.write_string("    phmt_dissoc(transient_map, \{key_expr(key)});\n")
    model.entries.remove(key)
  }
  out.write_string("    map = phmt_persistent(transient_map);\n")
  out.write_string(
    "    ct_assert(if phm_count(map) == \{model.entries.length()} { 1 } else { 0 });\n",
  )

  out.write_string("    let transient_vector = pv_as_transient(vector);\n")
  for index = 0; index < 40; index = index + 1 {
    let value : Int? = if index % 9 == 0 { None } else { Some(30000 + index) }
    out.write_string("    pvt_push(transient_vector, \{value_expr(value)});\n")
    vector.push(value)
  }
  if !vector.is_empty() {
    let updates = if vector.length() < 12 { vector.length() } else { 12 }
    for index = 0; index < updates; index = index + 1 {
      let value : Int? = Some(40000 + index)
      out.write_string(
        "    pvt_assoc(transient_vector, \{index}, \{value_expr(value)});\n",
      )
      vector[index] = value
    }
  }
  let pops = if vector.length() < 7 { vector.length() } else { 7 }
  for pop_index = 0; pop_index < pops; pop_index = pop_index + 1 {
    out.write_string("    pvt_pop(transient_vector);\n")
    ignore(vector.pop())
  }
  out.write_string("    vector = pvt_persistent(transient_vector);\n")
  out.write_string(
    "    ct_assert(if pv_count(vector) == \{vector.length()} { 1 } else { 0 });\n",
  )

  for key = 0; key < 65; key = key + 1 {
    let expression = if key == 64 { "null" } else { key_expr(key) }
    emit_map_assert(
      out,
      "map",
      expression,
      model.entries.contains(key),
      model.entries.get(key).unwrap_or(None),
    )
  }
  for index, value in vector {
    emit_vector_assert(out, "vector", index, true, value)
  }
  emit_vector_assert(out, "vector", vector.length(), false, None)
  out.write_string("}\n\n")
}

///|
fn main raise {
  let args = @env.args()
  if args.length() < 2 || args.length() > 3 {
    println("usage: collections_prop <output.wasm> [--bench]")
    return
  }
  let benchmark = args.length() == 3 && args[2] == "--bench"
  let count = if benchmark { 0 } else { 2 }
  let steps = 32
  let seed : UInt64 = 0x5eedc011ec7105
  let traces = @quickcheck.int_range(-1000000, 1000001)
    .array_with_size(steps)
    .samples(count~, size=steps, seed~)
  let out = StringBuilder::new()
  out.write_string(@fs.read_file_to_string("stdlib/collections/hashing.wax"))
  out.write_string("\n")
  out.write_string(
    @fs.read_file_to_string("stdlib/collections/persistent_hash_map.wax"),
  )
  out.write_string("\n")
  out.write_string(
    @fs.read_file_to_string("stdlib/collections/persistent_vector.wax"),
  )
  out.write_string("\n")
  out.write_string(@fs.read_file_to_string("test/collections/support.wax"))
  out.write_string("\n")
  if benchmark {
    out.write_string(@fs.read_file_to_string("test/collections/bench.wax"))
    out.write_string("\n")
  }
  for index, trace in traces {
    emit_case(out, index, trace)
  }
  out.write_string("#[export = \"collections_properties\"]\n")
  out.write_string("fn ct_properties() -> i32 {\n")
  for index = 0; index < count; index = index + 1 {
    out.write_string("    ct_property_case_\{index}();\n")
  }
  out.write_string("    1\n}\n")
  let source = out.to_string()
  @fs.write_string_to_file(args[1] + ".wax", source)
  let bytes = match
    @wax.compile_string(source, fname="generated-collections-properties.wax") {
    Ok(bytes) => bytes
    Err(diagnostics) =>
      abort(
        "generated Wax property module was rejected (\{diagnostics.length()} diagnostics)",
      )
  }
  @fs.write_bytes_to_file(args[1], bytes)
  if benchmark {
    println("collections benchmark module compiled")
  } else {
    println(
      "collections properties: seed=\{seed}, cases=\{count}, steps=\{steps}",
    )
  }
}
