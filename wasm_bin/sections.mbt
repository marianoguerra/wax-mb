// The section layer: each of the format's sections, then the module around them.
//
// Vendored from Milky2018/wasm_core 0.5.0 and rewritten more heavily than the
// opcode table was; see VENDORED.md.
//
// A note on the LEBs. The format spells most indices `u32`, but the reference
// writes several of them SIGNED -- a function's type, a tag's, an export's
// target, the start function. For values under 64 the two coincide; at 64 and
// above a signed LEB takes a second byte, because a lone 0x40 would read as
// -64. Both encodings decode to the same number and both are accepted, so this
// is not a correctness question -- but it is a BYTE question, and the bytes are
// what is being compared.

///|
/// Build a section body, or nothing if there is none to build.
fn section_body(
  build : (BinaryWriter) -> Unit raise EncodeError,
) -> Bytes raise EncodeError {
  let w = BinaryWriter::new()
  build(w)
  w.to_bytes()
}

///|
/// Write a section: id, byte length, body. Empty bodies are not written at all.
fn write_section(w : BinaryWriter, id : Int, body : Bytes) -> Unit {
  if body.length() == 0 {
    return
  }
  w.write_byte(id)
  w.write_u32(body.length())
  w.write_bytes(body)
}

///|
/// The type section, which is a vector of REC GROUPS rather than of types.
///
/// A group of one written without the `0x4E` prefix is the shorthand for the
/// common case, and it is only available when the source did not write `rec`.
fn encode_type_section(mod : Module) -> Bytes raise EncodeError {
  if mod.types.is_empty() {
    return b""
  }
  section_body(w => {
    w.write_u32(mod.rec_groups.length())
    for g in mod.rec_groups {
      if g.explicit || g.len != 1 {
        w.write_byte(0x4E)
        w.write_u32(g.len)
      }
      for i in g.start..<(g.start + g.len) {
        encode_subtype(w, mod.types[i])
      }
    }
  })
}

///|
fn encode_import_section(mod : Module) -> Bytes raise EncodeError {
  if mod.imports.is_empty() {
    return b""
  }
  section_body(w => {
    w.write_u32(mod.imports.length())
    for imp in mod.imports {
      w.write_name(imp.mod_name)
      // A compact group writes the module name once, then an EMPTY second name
      // and a marker where a kind byte would go. Neither marker is a valid
      // kind, which is what keeps a plain import unambiguous.
      match imp.group {
        Some(Heterogeneous(items)) => {
          w.write_name(b"")
          w.write_byte(0x7F)
          w.write_u32(items.length())
          for item in items {
            w.write_name(item.0)
            encode_import_desc(w, item.1)
          }
          continue
        }
        Some(Homogeneous(names)) => {
          w.write_name(b"")
          w.write_byte(0x7E)
          encode_import_desc(w, imp.desc)
          w.write_u32(names.length())
          for n in names {
            w.write_name(n)
          }
          continue
        }
        None => ()
      }
      w.write_name(imp.name)
      encode_import_desc(w, imp.desc)
    }
  })
}

///|
/// One import's externtype.
fn encode_import_desc(w : BinaryWriter, desc : ImportDesc) -> Unit {
  match desc {
    Func(type_idx) => {
      w.write_byte(0x00)
      w.write_u32(type_idx)
    }
    Table(tt) => {
      w.write_byte(0x01)
      encode_table_type(w, tt)
    }
    Memory(mt) => {
      w.write_byte(0x02)
      encode_limits(w, mt.limits)
    }
    Global(gt) => {
      w.write_byte(0x03)
      encode_global_type(w, gt)
    }
    Tag(type_idx) => {
      w.write_byte(0x04)
      w.write_byte(0x00) // the exception attribute
      w.write_u32(type_idx)
    }
  }
}

///|
fn encode_function_section(mod : Module) -> Bytes raise EncodeError {
  if mod.funcs.is_empty() {
    return b""
  }
  section_body(w => {
    w.write_u32(mod.funcs.length())
    for type_idx in mod.funcs {
      w.write_s32(type_idx)
    }
  })
}

///|
fn encode_table_section(mod : Module) -> Bytes raise EncodeError {
  if mod.tables.is_empty() {
    return b""
  }
  section_body(w => {
    w.write_u32(mod.tables.length())
    for table in mod.tables {
      match table.init {
        Some(init) => {
          // A table whose elements start at something other than null.
          w.write_byte(0x40)
          w.write_byte(0x00)
          encode_table_type(w, table.type_)
          encode_expr(w, init)
        }
        None => encode_table_type(w, table.type_)
      }
    }
  })
}

///|
fn encode_memory_section(mod : Module) -> Bytes raise EncodeError {
  if mod.memories.is_empty() {
    return b""
  }
  section_body(w => {
    w.write_u32(mod.memories.length())
    for mem in mod.memories {
      encode_limits(w, mem.limits)
    }
  })
}

///|
fn encode_tag_section(mod : Module) -> Bytes raise EncodeError {
  if mod.tags.is_empty() {
    return b""
  }
  section_body(w => {
    w.write_u32(mod.tags.length())
    for tag in mod.tags {
      w.write_byte(0x00) // the exception attribute
      w.write_s32(tag.type_idx)
    }
  })
}

///|
fn encode_global_section(mod : Module) -> Bytes raise EncodeError {
  if mod.globals.is_empty() {
    return b""
  }
  section_body(w => {
    w.write_u32(mod.globals.length())
    for global in mod.globals {
      encode_global_type(w, global.type_)
      encode_expr(w, global.init)
    }
  })
}

///|
fn encode_export_section(mod : Module) -> Bytes raise EncodeError {
  if mod.exports.is_empty() {
    return b""
  }
  section_body(w => {
    w.write_u32(mod.exports.length())
    for exp in mod.exports {
      w.write_name(exp.name)
      let (kind, idx) = match exp.desc {
        Func(i) => (0x00, i)
        Table(i) => (0x01, i)
        Memory(i) => (0x02, i)
        Global(i) => (0x03, i)
        Tag(i) => (0x04, i)
      }
      w.write_byte(kind)
      w.write_s32(idx)
    }
  })
}

///|
fn encode_start_section(mod : Module) -> Bytes raise EncodeError {
  match mod.start {
    Some(func_idx) => section_body(w => w.write_s32(func_idx))
    None => b""
  }
}

///|
/// Is every initialiser a bare `ref.func`?
///
/// This decides whether the compact element encodings -- the ones that list
/// function indices instead of expressions -- are available.
///
/// The reference asks the same question of its own binary AST, where an
/// initialiser is always a FOLDED node and so never matches the bare pattern.
/// The answer there is therefore "only when the list is empty", vacuously --
/// so the compact form is reachable for an empty segment and nothing else. We
/// reproduce that: the bytes are what is being compared, and a shorter
/// encoding of the same segment is still a different module.
fn all_ref_func(init : Array[Array[Instruction]]) -> Bool {
  if !init.is_empty() {
    return false
  }
  for e in init {
    guard e is [RefFunc(_)] else { return false }
  }
  true
}

///|
/// Is this the plain nullable `funcref`, the only element type the compact
/// encodings can spell?
fn is_funcref(rt : RefType) -> Bool {
  rt.nullable && rt.typ is Func
}

///|
/// The element section.
///
/// Eight encodings, chosen by three independent questions: active or not, table
/// 0 or another, function indices or full expressions. Upstream picked the
/// compact form from the element type alone and then, if an initialiser turned
/// out not to be a bare `ref.func`, wrote function index **0** for it -- so a
/// table of anything else was silently filled with the wrong function.
fn encode_element_section(mod : Module) -> Bytes raise EncodeError {
  if mod.elems.is_empty() {
    return b""
  }
  section_body(w => {
    w.write_u32(mod.elems.length())
    for elem in mod.elems {
      // The eight forms are three independent economies, and they do not
      // combine freely: an index list instead of expressions, an implied table
      // 0, and an implied `funcref`. The spec spells out exactly which
      // combinations have a byte, so this is a table rather than a computation.
      let funcref = is_funcref(elem.type_)
      let compact = funcref && all_ref_func(elem.init)
      match elem.mode {
        Active(table_idx, offset) =>
          if compact && table_idx == 0 {
            w.write_byte(0x00)
            encode_expr(w, offset)
          } else if funcref && table_idx == 0 {
            // Table 0 and `funcref` are both implied, but the initializers are
            // real expressions -- a `ref.null func` among them is enough to
            // rule out the index list while leaving the rest of the economy.
            w.write_byte(0x04)
            encode_expr(w, offset)
          } else if compact {
            w.write_byte(0x02)
            w.write_u32(table_idx)
            encode_expr(w, offset)
            w.write_byte(0x00) // elemkind: funcref
          } else {
            w.write_byte(0x06)
            w.write_u32(table_idx)
            encode_expr(w, offset)
            encode_reftype(w, elem.type_)
          }
        Passive =>
          if compact {
            w.write_byte(0x01)
            w.write_byte(0x00) // elemkind: funcref
          } else {
            w.write_byte(0x05)
            encode_reftype(w, elem.type_)
          }
        Declarative =>
          if compact {
            w.write_byte(0x03)
            w.write_byte(0x00) // elemkind: funcref
          } else {
            w.write_byte(0x07)
            encode_reftype(w, elem.type_)
          }
      }
      w.write_u32(elem.init.length())
      for init in elem.init {
        // `compact` was decided by `all_ref_func` over this same array, so
        // the else branch is unreachable -- but it costs nothing to encode the
        // expression rather than assert, and an assert here would be the one
        // place this file could still panic.
        if compact && init is [RefFunc(idx)] {
          w.write_u32(idx)
        } else {
          encode_expr(w, init)
        }
      }
    }
  })
}

///|
/// Consecutive locals of the same type share one entry.
fn compress_locals(locals : Array[ValType]) -> Array[(Int, ValType)] {
  let out : Array[(Int, ValType)] = []
  let mut i = 0
  while i < locals.length() {
    let vt = locals[i]
    let mut count = 1
    while i + count < locals.length() && locals[i + count] == vt {
      count += 1
    }
    out.push((count, vt))
    i += count
  }
  out
}

///|
/// The code section, and the hints collected while writing it.
///
/// The two come together because they can only come together: a hint is keyed
/// by its instruction's byte offset within the function body, so it is knowable
/// exactly once, while that body is being encoded.
fn encode_code_section(mod : Module) -> (Bytes, CodeHints) raise EncodeError {
  let hints = CodeHints::new()
  if mod.codes.is_empty() {
    return (b"", hints)
  }
  // Defined functions are indexed after the imported ones.
  let num_func_imports = mod.imports
    .iter()
    .filter(i => i.desc is Func(_))
    .count()
  let body = section_body(w => {
    w.write_u32(mod.codes.length())
    for i, code in mod.codes {
      let funcidx = num_func_imports + i
      let sink : Array[(Int, InstrHints)] = []
      let fn_body = BinaryWriter::new_with_sink(sink)
      let locals = compress_locals(code.locals)
      fn_body.write_u32(locals.length())
      for entry in locals {
        let (count, vt) = entry
        fn_body.write_u32(count)
        encode_valtype(fn_body, vt)
      }
      encode_expr(fn_body, code.body)
      let bytes = fn_body.to_bytes()
      w.write_u32(bytes.length())
      w.write_bytes(bytes)
      hints.take(funcidx, sink, code.priority)
    }
  })
  (body, hints)
}

///|
fn encode_data_section(mod : Module) -> Bytes raise EncodeError {
  if mod.datas.is_empty() {
    return b""
  }
  section_body(w => {
    w.write_u32(mod.datas.length())
    for data in mod.datas {
      match data.mode {
        Active(0, offset) => {
          w.write_byte(0x00)
          encode_expr(w, offset)
        }
        Active(memory_idx, offset) => {
          w.write_byte(0x02)
          w.write_u32(memory_idx)
          encode_expr(w, offset)
        }
        Passive => w.write_byte(0x01)
      }
      w.write_u32(data.init.length())
      w.write_bytes(data.init)
    }
  })
}

///|
/// The data count section, which `memory.init` and `data.drop` need in order to
/// be validated without reading ahead to the data section.
fn encode_datacount_section(mod : Module) -> Bytes raise EncodeError {
  if mod.datas.is_empty() {
    return b""
  }
  section_body(w => w.write_u32(mod.datas.length()))
}

///|
/// Encode a module.
///
/// Section order is the reference's, which is the format's and not the order of
/// the section ids: tags (13) go between memories (5) and globals (6), the data
/// count (12) before the code (10), and the custom sections last -- except the
/// `metadata.code.*` ones, which the branch-hinting proposal requires between
/// the function and code sections, and which are not emitted yet.
pub fn encode(mod : Module) -> Bytes raise EncodeError {
  let (code, code_hints) = encode_code_section(mod)
  let w = BinaryWriter::new()
  w.write_bytes(b"\x00\x61\x73\x6D") // "\0asm"
  w.write_bytes(b"\x01\x00\x00\x00") // version 1
  write_section(w, 1, encode_type_section(mod))
  write_section(w, 2, encode_import_section(mod))
  write_section(w, 3, encode_function_section(mod))
  write_section(w, 4, encode_table_section(mod))
  write_section(w, 5, encode_memory_section(mod))
  write_section(w, 13, encode_tag_section(mod))
  write_section(w, 6, encode_global_section(mod))
  write_section(w, 7, encode_export_section(mod))
  write_section(w, 8, encode_start_section(mod))
  write_section(w, 9, encode_element_section(mod))
  write_section(w, 12, encode_datacount_section(mod))
  // The metadata.code.* sections go after the function section and before the
  // code section, which all four proposals require -- so the code section has
  // to be built before any of them can be written.
  encode_code_metadata_section(w, b"branch_hint", code_hints.branch)
  encode_code_metadata_section(w, b"instr_freq", code_hints.freq)
  encode_code_metadata_section(w, b"call_targets", code_hints.targets)
  encode_code_metadata_section(
    w,
    b"compilation_priority",
    code_hints.priorities,
  )
  write_section(w, 10, code)
  write_section(w, 11, encode_data_section(mod))
  encode_target_features_section(w, mod.target_features)
  encode_name_section(w, mod.names)
  w.to_bytes()
}
