// Parses the whole differential corpus.
//
// This is the Phase 2 gate, and it is the check that cannot be fooled by an
// unreachable grammar: every file the REFERENCE could parse must parse here,
// and every file it rejected must be rejected here. The bucket classification
// in test/golden/index.json is the reference's own verdict, recorded by
// tools/waxdiff.py.

///|
priv struct Case {
  file : String
  bucket : String
}

///|
fn load_index() -> Array[Case] raise {
  let text = @fs.read_file_to_string("test/golden/index.json")
  let files = match @json.parse(text) {
    { "files": Object(m), .. } => m
    _ => return []
  }
  let out = []
  for name, meta in files {
    let bucket = match meta {
      { "bucket": String(b), .. } => b
      _ => "?"
    }
    out.push({ file: name, bucket, })
  }
  out
}

///|
test "every file the reference parses, we parse" {
  let failures = []
  let mut checked = 0
  for c in load_index() {
    // syntax-bad files are the reference's own rejections; covered below.
    if c.bucket == "syntax-bad" {
      continue
    }
    let src = @fs.read_file_to_string("test/corpus/" + c.file)
    let r = @grammar.parse_string(src, fname=c.file)
    checked += 1
    if r.errors.length() > 0 {
      failures.push("\{c.file}: \{r.errors[0].message}")
    } else if r.module_ is None {
      failures.push("\{c.file}: no module and no error")
    }
  }
  if failures.length() > 0 {
    let sample = failures[:@cmp.minimum(8, failures.length())].to_owned()
    let joined = sample.join("\n  ")
    fail("\{failures.length()} of \{checked} failed to parse:\n  \{joined}")
  }
  inspect(failures.length(), content="0")
}

///|
test "every file the reference rejects, we reject" {
  // The converse direction. Accepting something the reference rejects is just
  // as much a divergence as the reverse, and is the easier mistake to make:
  // a missing check simply lets more through.
  let accepted = []
  let mut checked = 0
  for c in load_index() {
    if c.bucket != "syntax-bad" {
      continue
    }
    let src = @fs.read_file_to_string("test/corpus/" + c.file)
    let r = @grammar.parse_string(src, fname=c.file)
    checked += 1
    if r.errors.length() == 0 {
      accepted.push(c.file)
    }
  }
  if accepted.length() > 0 {
    let sample = accepted[:@cmp.minimum(8, accepted.length())].to_owned()
    let joined = sample.join("\n  ")
    fail("\{accepted.length()} of \{checked} wrongly accepted:\n  \{joined}")
  }
  inspect(accepted.length(), content="0")
}
