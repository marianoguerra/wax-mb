// Runs the checker over the whole differential corpus.
//
// This is stage 3a's gate: every instruction node the checker reaches must come
// out with an annotation, because that annotation is the entire interface to
// the code generator. A node without one is a node the lowering cannot emit.
//
// It measures rather than asserts a target, for one honest reason: the corpus
// holds files the reference itself rejects, and a checker that rejects them too
// legitimately leaves nodes unreached. So coverage is counted on the files that
// check CLEANLY, and what the rest report is recorded so a systematic mistake
// stands out from a scatter of one-offs.

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
/// Walk an instruction and everything under it, counting nodes and POISON.
///
/// `seen[0]` is every node; `seen[1]` is those carrying an `Error` type. An
/// empty annotation is not a gap -- a statement genuinely leaves nothing -- so
/// counting those would measure the language rather than the checker. An
/// `Error` on a file that reported NOTHING is the real inconsistency: `Error`
/// means "already complained about", so with no complaint it cannot be right.
///
/// Iterative, not recursive: the corpus holds expression trees deep enough to
/// exhaust the stack, and a test that dies on real input measures nothing.
fn count(
  root : @ast.Instr[@typing_env.InferredAnnotation],
  seen : Array[Int],
) -> Unit {
  let stack = [root]
  while stack.length() > 0 {
    let node = stack.pop().unwrap()
    seen[0] = seen[0] + 1
    for t in node.info.0 {
      if t.get() is Error {
        seen[1] = seen[1] + 1
      }
    }
    for sub in node.sub_instrs() {
      stack.push(sub)
    }
  }
}

///|
/// The instructions a typed field contains.
fn field_instrs(
  f : @ast.ModuleField[@typing_env.InferredAnnotation],
) -> Array[@ast.Instr[@typing_env.InferredAnnotation]] {
  match f {
    Func(body~, ..) => body.1
    Global(def~, ..) => [def]
    Table(init~, ..) =>
      match init {
        Some(e) => [e]
        None => []
      }
    Elem(init~, ..) => init
    _ => []
  }
}

///|
test "the checker annotates every node it reaches" {
  // seen[0] = nodes, seen[1] = annotated
  let seen = [0, 0]
  let mut files = 0
  let mut clean = 0
  let messages : Map[String, Int] = Map([])
  for c in load_index() {
    // The reference's own rejections: nothing here to annotate.
    if c.bucket == "syntax-bad" {
      continue
    }
    let src = @fs.read_file_to_string("test/corpus/" + c.file)
    let parsed = @grammar.parse_string(src, fname=c.file)
    guard parsed.module_ is Some(fields) else { continue }
    if parsed.errors.length() > 0 {
      continue
    }
    files += 1
    let diagnostics = @diagnostic.collector()
    let (_, typed) = @typing.check_module(
      diagnostics,
      @type_store.TypeStore::new(),
      @feature.default(),
      fields,
    )
    let reported = diagnostics.collected()
    for d in reported {
      let m = @message.to_plain_string(d.message)
      messages[m] = messages.get(m).unwrap_or(0) + 1
    }
    if reported.is_empty() {
      clean += 1
      for f in typed {
        for node in field_instrs(f.desc) {
          count(node, seen)
        }
      }
    }
  }
  inspect(
    "nodes \{seen[0]} poisoned \{seen[1]} files \{files} clean \{clean}",
    content=(
      #|nodes 180520 poisoned 0 files 1818 clean 1646
    ),
  )
  let top : Array[(String, Int)] = []
  for m, n in messages {
    top.push((m, n))
  }
  // Ties broken on the message, not left to the map's iteration order: two
  // messages reported the same number of times would otherwise swap places in
  // this snapshot whenever some UNRELATED message is added or removed.
  top.sort_by((a, b) => if a.1 == b.1 { a.0.compare(b.0) } else { b.1 - a.1 })
  let n = if top.length() < 8 { top.length() } else { 8 }
  inspect(
    top[0:n].map(e => e.1.to_string() + " " + e.0).join("\n"),
    content=(
      #|29 This uses the custom-descriptors feature, which is not enabled; pass --feature custom-descriptors.
      #|24 This cast always traps: the value can never have this type.
      #|17 This type test is always true: the value already has this type.
      #|6 This expression occurs before a hole '_'.
      #|5 This value remains on the stack.
      #|4 Expecting 1 returned value(s) from the stack, but there are 0.
      #|4 This expression has type 'i64' but is expected to have type 'i32'.
      #|4 This expression has type 'float' but is expected to have type 'i32'.
    ),
  )
}
