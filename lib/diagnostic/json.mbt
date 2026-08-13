// The JSON Lines renderer.
//
// Built as TEXT rather than through a JSON value, because the field order is
// part of the contract the harness compares against and a keyed map does not
// promise one.

///|
/// Escape a string as a JSON scalar.
///
/// Matches the reference's encoder: quote and backslash escaped, the five
/// named control escapes, everything else below 0x20 as `\u00xx`, and non-ASCII
/// passed through as raw UTF-8 rather than escaped.
fn json_string(s : String) -> String {
  let out = StringBuilder::new()
  out.write_char('"')
  for c in s {
    match c {
      '"' => out.write_string("\\\"")
      '\\' => out.write_string("\\\\")
      '\n' => out.write_string("\\n")
      '\r' => out.write_string("\\r")
      '\t' => out.write_string("\\t")
      '\u{08}' => out.write_string("\\b")
      '\u{0C}' => out.write_string("\\f")
      _ =>
        if c.to_int() < 0x20 {
          let hex = "0123456789abcdef"
          let n = c.to_int()
          out.write_string("\\u00")
          out.write_char(
            hex.unsafe_get((n >> 4) & 0xF).to_int().unsafe_to_char(),
          )
          out.write_char(hex.unsafe_get(n & 0xF).to_int().unsafe_to_char())
        } else {
          out.write_char(c)
        }
    }
  }
  out.write_char('"')
  out.to_string()
}

///|
/// The six span fields, in the order the contract fixes.
///
/// Columns are 0-based here (against the human format's 1-based one), and the
/// offsets are UTF-8 BYTE offsets into the source, so an agent can rewrite the
/// raw bytes.
fn span_fields(loc : @basic.Location) -> Array[(String, String)] {
  [
    ("startLine", loc.start.lnum.to_string()),
    ("startColumn", loc.start.column0().to_string()),
    ("endLine", loc.end.lnum.to_string()),
    ("endColumn", loc.end.column0().to_string()),
    ("startOffset", loc.start.cnum.to_string()),
    ("endOffset", loc.end.cnum.to_string()),
  ]
}

///|
fn obj(fields : Array[(String, String)]) -> String {
  let parts = fields.map(f => json_string(f.0) + ":" + f.1)
  "{" + parts.join(",") + "}"
}

///|
/// Emit one diagnostic as a single-line JSON object.
///
/// `warning` and `hint` are null when absent; `related` is always an array;
/// `edit` is OMITTED entirely when absent rather than being null.
fn output_json(sink : Sink, d : Diagnostic) -> Unit {
  let fields : Array[(String, String)] = [
    ("severity", json_string(d.severity.to_str())),
    ("file", json_string(d.loc.start.fname)),
  ]
  fields.append(span_fields(d.loc))
  fields.push(("message", json_string(@message.to_plain_string(d.message))))
  fields.push(
    (
      "warning",
      match d.warning {
        Some(w) => json_string(w.name())
        None => "null"
      },
    ),
  )
  fields.push(
    (
      "hint",
      match d.hint {
        Some(m) => json_string(@message.to_plain_string(m))
        None => "null"
      },
    ),
  )
  let related = d.related.map(l => {
    let f = span_fields(l.loc)
    f.push(("message", json_string(@message.to_plain_string(l.message))))
    obj(f)
  })
  fields.push(("related", "[" + related.join(",") + "]"))
  match d.edit {
    Some(e) => {
      let f = span_fields(e.loc)
      f.push(("newText", json_string(e.new_text)))
      fields.push(("edit", obj(f)))
    }
    None => ()
  }
  line(sink, obj(fields))
}
