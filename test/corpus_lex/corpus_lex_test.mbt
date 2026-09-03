// Runs the lexer over the whole differential corpus.
//
// This is the first real differential signal for the lexer. Oracle 1 cannot
// grade it until the printer lands in phase 3, but the bucket classification in
// test/golden/index.json already tells us which files the REFERENCE was able to
// parse -- and a file the reference parsed cannot contain a lexical error, so
// ours must not report one either.
//
// Paths are relative to the module root, which is where moon runs tests from.

///|
priv struct Case {
  file : String
  bucket : String
}

///|
fn load_index() -> Array[Case] raise {
  let text = @fs.read_file_to_string("test/golden/index.json")
  let json = @json.parse(text)
  let files = match json {
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
test "the lexer accepts every corpus file the reference could parse" {
  let cases = load_index()
  assert_true(cases.length() > 1000)
  let unexpected = []
  let mut checked = 0
  for c in cases {
    // syntax-bad files may legitimately fail, and may fail in the PARSER rather
    // than the lexer, so they prove nothing here either way.
    if c.bucket == "syntax-bad" {
      continue
    }
    let src = @fs.read_file_to_string("test/corpus/" + c.file)
    let r = @lexer.tokens_from_string(src, fname=c.file)
    checked += 1
    if r.errors.length() > 0 {
      unexpected.push("\{c.file}: \{r.errors[0].message}")
    }
  }
  // Report a few concrete failures rather than a bare count.
  if unexpected.length() > 0 {
    let sample = unexpected[:@cmp.minimum(5, unexpected.length())].to_owned()
    let joined = sample.join("; ")
    fail(
      "\{unexpected.length()} of \{checked} parseable files hit a lexical error; e.g. \{joined}",
    )
  }
  inspect(unexpected.length(), content="0")
}

///|
test "every corpus file terminates the token stream with EOF" {
  let cases = load_index()
  let bad = []
  for c in cases {
    let src = @fs.read_file_to_string("test/corpus/" + c.file)
    let r = @lexer.tokens_from_string(src, fname=c.file)
    // A lexical error stops the scan, so only clean lexes are required to end
    // in EOF.
    if r.errors.length() == 0 {
      let n = r.tokens.length()
      if n == 0 || !(r.tokens[n - 1].0 is EOF) {
        bad.push(c.file)
      }
    }
  }
  inspect(bad.length(), content="0")
}

///|
/// A histogram of every token kind produced across the whole corpus.
///
/// The "no lexical errors" test above is a weak signal on its own: most lexer
/// bugs produce a DIFFERENT BUT VALID token stream rather than an error.
/// Deleting the nested-block-comment rule, for instance, leaves `/* a /* b */
/// c */` lexing cleanly as a comment followed by `c */` -- wrong, but not a
/// lexical error.
///
/// This histogram is sensitive to exactly that class of change: any alteration
/// in how the corpus tokenizes shows up as a reviewable diff. Verified by
/// mutation: breaking the `nan:0x` float rule fails this test while leaving the
/// "no lexical errors" test above green.
///
/// It is a REGRESSION guard, not a correctness proof -- only oracle 1, once the
/// printer lands in phase 3, can check the lexer against the reference.
///
/// Known coverage gap: NO corpus file contains a nested block comment (checked
/// with `grep -rlE '/\*[^*]*/\*' test/corpus/`), so deleting the nesting rule
/// passes every corpus test. That case is covered by a unit test in
/// lexer/lexer_test.mbt instead.
test "corpus token histogram" (t : @test.Test) {
  let counts : Map[String, Int] = Map([])
  let mut total = 0
  for c in load_index() {
    let src = @fs.read_file_to_string("test/corpus/" + c.file)
    let r = @lexer.tokens_from_string(src, fname=c.file)
    for tok in r.tokens {
      let k = @debug.render(tok.0.kind().to_repr())
      counts[k] = counts.get(k).unwrap_or(0) + 1
      total += 1
    }
  }
  let names = counts.keys().collect()
  names.sort()
  t.writeln("total tokens: \{total}")
  t.writeln("distinct kinds: \{names.length()}")
  for n in names {
    t.writeln("\{n} \{counts[n]}")
  }
  t.snapshot(filename="token_histogram.txt")
}
