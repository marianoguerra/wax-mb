///|
pub struct Artifact {
  wasm : Bytes
  wat : String
  manifest : Json
}

///|
pub fn Artifact::wasm(self : Artifact) -> Bytes {
  self.wasm
}

///|
pub fn Artifact::wat(self : Artifact) -> String {
  self.wat
}

///|
pub fn Artifact::manifest(self : Artifact) -> Json {
  self.manifest
}

///|
/// Compile in-memory source modules. No import performs I/O or initialization.
pub fn compile(
  source : String,
  modules? : Map[String, String] = Map([]),
  protocols? : Map[String, Array[String]] = Map([]),
) -> Artifact raise ScriptError {
  if source.length() > 1_000_000 || modules.length() > 128 {
    raise ScriptError("compilation input limit exceeded")
  }
  let mut source_size = source.length()
  for text in modules.values() {
    source_size += text.length()
    if source_size > 2_000_000 {
      raise ScriptError("aggregate source limit exceeded")
    }
  }
  let units : Array[SourceUnit] = []
  units.push({
    name: "core",
    imports: [],
    requirements: [],
    functions: [],
    source: "",
    records: [
      { name: "Ok", fields: [("value", "value")], },
      { name: "Err", fields: [("error", "value")], },
    ],
  })
  let visited : Map[String, Bool] = Map([])
  let active : Map[String, Bool] = Map([])
  fn visit(src : String, path : String, depth : Int) -> Unit raise ScriptError {
    if depth > 64 || src.length() > 1_000_000 {
      raise ScriptError("module limit exceeded")
    }
    if active.contains(path) {
      raise ScriptError("cyclic import: " + path)
    }
    if visited.contains(path) {
      return
    }
    active[path] = true
    let unit = read_unit(src)
    for dependency in unit.imports {
      let text = match modules.get(dependency) {
        Some(s) => s
        None => raise ScriptError("missing in-memory module " + dependency)
      }
      visit(text, dependency, depth + 1)
    }
    active.remove(path)
    visited[path] = true
    units.push(unit)
  }
  visit(source, "<entry>", 0)
  let runtime = @wp.parse_module(runtime_source) catch {
    @wp.ParseError(r) =>
      raise ScriptError(
        "runtime parse error: " +
        r.message +
        " " +
        r.labels.map(l => l.span.start.to_string()).join(","),
      )
  }
  // The universal closure dispatcher must itself tail-call the function ref.
  for j, decl in runtime.module_().decls {
    if decl is Fn(f) && f.name == "apply" && f.body is Some(body) {
      let last = body.length() - 1
      if body[last].it is Call(target, args) {
        body[last] = n(TailCall(target, args))
      }
      runtime.module_().decls[j] = Fn({ ..f, body: Some(body), })
    }
  }
  let gen : Generator = {
    decls: runtime.module_().decls,
    functions: Map([]),
    records: Map([]),
    aliases: Map([]),
    requirements: Map([]),
    sources: Map([]),
    counter: 0,
    module_: "",
  }
  let module_names : Map[String, Bool] = Map([])
  for index, unit in units {
    gen.sources[unit.name] = index
    if module_names.contains(unit.name) {
      raise ScriptError("duplicate module " + unit.name)
    }
    module_names[unit.name] = true
    for f in unit.functions {
      gen.functions[unit.name + "." + f.name] = f
    }
    for r in unit.records {
      gen.records[unit.name + "." + r.name] = r
    }
    for pair in unit.requirements {
      let (name, protocol) = pair
      gen.requirements[unit.name + "." + name] = protocol
    }
  }
  // Cross-module function names are admitted only through explicit imports/exports.
  for unit in units {
    gen.aliases[unit.name + ":Ok"] = "core.Ok"
    gen.aliases[unit.name + ":Err"] = "core.Err"
    for imported in units {
      if unit.imports.contains(imported.name) {
        for f in imported.functions {
          if f.exported {
            gen.aliases[unit.name + ":" + imported.name + "." + f.name] = imported.name +
              "." +
              f.name
          }
        }
        for r in imported.records {
          gen.aliases[unit.name + ":" + imported.name + "." + r.name] = imported.name +
            "." +
            r.name
        }
      }
    }
  }
  let record_arms = []
  let record_manifest : Map[String, Json] = Map([])
  for unit in units {
    gen.module_ = unit.name
    for r in unit.records {
      let fs : Array[@w.Field] = []
      for j, f in r.fields {
        fs.push({
          name: "slot_" + j.to_string(),
          mut_: false,
          typ: gen.storage_type(f.1),
          span: @w.nowhere,
        })
      }
      gen.decls.push(
        TypeD(
          name=mangled(unit.name + "." + r.name),
          def=Record(parent=Some("record_value"), fields=fs),
          is_pub=false,
          span=@w.nowhere,
        ),
      )
      let full_name = unit.name + "." + r.name
      let scope : Map[String, @w.Node] = Map([])
      let args = []
      for j, f in r.fields {
        scope[f.0] = n(Index(v("args"), i(j)))
        args.push({ expr: Name(f.0), span: @w.nowhere, })
      }
      let ctor = "new_" + mangled(full_name)
      gen.decls.push(
        function_decl(
          ctor,
          [("ctx", Named("context")), ("args", Named("values"))],
          Nullable(Eq),
          [
            call("arity", [v("ctx"), v("args"), i(args.length())]),
            gen.record(full_name, r, args, scope),
          ],
          export_name=ctor,
        ),
      )
      record_manifest[full_name] = {
        "constructor": ctor.to_json(),
        "fields": r.fields.map(f => f.0).to_json(),
      }
      record_arms.push(
        (
          Some(n(Test(v("record"), Named(mangled(full_name))))),
          [
            call(ctor, [
              v("ctx"),
              call("replace_field", [v("ctx"), v("record"), v("key"), v("item")]),
            ]),
          ],
        ),
      )
    }
    for f in unit.functions {
      gen.emit_function(
        mangled(unit.name + "." + f.name),
        f.params,
        f.body,
        Map([]),
      )
    }
  }
  record_arms.push((None, [call("die", [v("ctx"), i(4)]), n(Unreachable)]))
  gen.decls.push(
    function_decl(
      "record_assoc",
      [
        ("ctx", Named("context")),
        ("record", Nullable(Eq)),
        ("key", Nullable(Eq)),
        ("item", Nullable(Eq)),
      ],
      Eq,
      [n(NonNull(n(If(arms=record_arms, typ=Some(Nullable(Eq))))))],
    ),
  )
  for id in 0..<18 {
    gen.decls.push(
      function_decl(
        "builtin_" + id.to_string(),
        [
          ("ctx", Named("context")),
          ("env", Nullable(Eq)),
          ("args", Named("values")),
        ],
        Nullable(Eq),
        [call("builtin", [v("ctx"), i(id), v("args")])],
      ),
    )
  }
  let entry = units[units.length() - 1]
  let entries : Map[String, Json] = Map([])
  for f in entry.functions {
    if f.exported {
      let data_params = f.params.filter(p => {
        !gen.requirements.contains(entry.name + "." + p)
      })
      if data_params.length() > 1 {
        problem(
          "an entry accepts at most one data parameter; other parameters must be declared requirements",
          f.span,
        )
      }
      gen.decls.push(
        function_decl(
          "entry_" + f.name,
          [("ctx", Named("context")), ("args", Named("values"))],
          Nullable(Eq),
          [
            n(
              TailCall(v(mangled(entry.name + "." + f.name)), [
                v("ctx"),
                n(Null),
                v("args"),
              ]),
            ),
          ],
          export_name="run_" + f.name,
        ),
      )
      entries[f.name] = f.params.to_json()
    }
  }
  let required : Map[String, Json] = Map([])
  let schemas = protocols.copy()
  for
    pair in [
      ("std.clock.Wall.v1", ["now_ms"]),
      ("std.clock.Monotonic.v1", ["now_ns"]),
      ("std.random.v1", ["bytes"]),
      ("std.fetch.v1", ["request"]),
      ("std.objects.Read.v1", ["get", "head", "list"]),
      ("std.objects.Write.v1", ["put", "delete"]),
    ] {
    if !schemas.contains(pair.0) {
      schemas[pair.0] = pair.1
    }
  }
  for unit in units {
    for pair in unit.requirements {
      if !schemas.contains(pair.1) {
        raise ScriptError("unknown protocol schema " + pair.1)
      }
    }
  }
  for pair in entry.requirements {
    let (name, protocol) = pair
    required[name] = protocol.to_json()
  }
  let vector = @wp.parse_module(vector_source) catch {
    @wp.ParseError(r) => raise ScriptError(r.message)
  }
  let hamt = @wp.parse_module(map_source) catch {
    @wp.ParseError(r) => raise ScriptError(r.message)
  }
  let sources = @er.Sources::new()
  let map_id = sources.add("persistent_hash_map.wap", map_source)
  let vector_id = sources.add("persistent_vector.wap", vector_source)
  let runtime_id = sources.add("input.wisp", source)
  let lowered = @lower.lower_program([
    {
      module_: hamt.module_(),
      source: {
        fname: "persistent_hash_map.wap",
        text: map_source,
        src: map_id,
      },
    },
    {
      module_: vector.module_(),
      source: {
        fname: "persistent_vector.wap",
        text: vector_source,
        src: vector_id,
      },
    },
    {
      module_: { name: "rt", decls: gen.decls, },
      source: { fname: "input.wisp", text: source, src: runtime_id, },
    },
  ])
  if !lowered.diagnostics().is_empty() {
    raise ScriptError(
      "wap lowering: " + lowered.diagnostics().map(r => r.message).join("\n"),
    )
  }
  let session = @compile.Session::new(source~)
  let checked = session.check(lowered.fields(), warn_unused=false)
  if @compile.rejected(session.reports()) {
    raise ScriptError(
      "Wax check: " +
      session
      .reports()
      .map(r => {
        @message.to_plain_string(r.message) +
        " at " +
        r.loc.start.cnum.to_string()
      })
      .join("\n"),
    )
  }
  let wasm = checked.to_bytes() catch {
    e => raise ScriptError("encoding: \{e}")
  }
  let wat = checked.to_wat() catch { e => raise ScriptError("wat: \{e}") }
  {
    wasm,
    wat,
    manifest: {
      "abi": 1,
      "entries": entries.to_json(),
      "records": record_manifest.to_json(),
      "requirements": required.to_json(),
      "protocols": schemas.to_json(),
      "sources": units
      .map(u => {
        ({ "module": u.name.to_json(), "text": u.source.to_json() } : Json)
      })
      .to_json(),
      "features": ["gc", "tail-call", "jspi"],
    },
  }
}
