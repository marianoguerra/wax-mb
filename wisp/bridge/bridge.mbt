///|
/// A JSON boundary keeps the compiler independent of JavaScript object layout.
#export_name("compile_json")
pub fn compile_json(request : String) -> String {
  try {
    let input = @json.parse(request)
    let source = match input {
      { "source": String(s), .. } => s
      _ => return "{\"error\":\"source must be a string\"}"
    }
    let modules : Map[String, String] = Map([])
    if input is { "modules": Object(m), .. } {
      for name, value in m {
        if value is String(s) {
          modules[name] = s
        } else {
          return "{\"error\":\"module source must be a string\"}"
        }
      }
    }
    let protocols : Map[String, Array[String]] = Map([])
    if input is { "protocols": Object(m), .. } {
      for name, value in m {
        if value is Array(a) {
          let methods = []
          for item in a {
            if item is String(s) {
              methods.push(s)
            }
          }
          protocols[name] = methods
        }
      }
    }
    let artifact = @wisp.compile(source, modules~, protocols~)
    let bytes = []
    for b in artifact.wasm() {
      bytes.push(b.to_int())
    }
    let output : Json = {
      "wasm": bytes.to_json(),
      "manifest": artifact.manifest(),
      "wat": artifact.wat(),
    }
    output.stringify()
  } catch {
    e => ({ "error": e.to_string() } : Json).stringify()
  }
}
