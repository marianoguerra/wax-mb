// The replayed parse has to agree with the real one.
//
// `@grammar.error_state` re-runs the automaton over the same tokens with the
// semantic actions left out, to recover the state the real parse failed in --
// information MoonYacc's error value does not carry. That is only sound if the
// replay follows the same path, and the corpus's 209 syntax-bad files are the
// evidence: for each one, the token the replay stops on must be the token the
// parse reported.
//
// This is also the rot guard on the whole arrangement. If a MoonYacc release
// changes the engine's control flow, this test fails here rather than quietly
// mis-keying the message table.

///|
test "the replay stops on the token the parse rejected" {
  let mismatched = []
  let mut checked = 0
  for c in load_index() {
    if c.bucket != "syntax-bad" {
      continue
    }
    let src = @fs.read_file_to_string("test/corpus/" + c.file)
    let ctx = @trivia.Context::new()
    @grammar.set_context(ctx)
    let lexed = @lexer.tokens_from_string(src, fname=c.file, trivia_ctx=ctx)
    // A lexical error stops the scan, so there is no parse to replay.
    if lexed.errors.length() > 0 {
      continue
    }
    try
      @grammar.parse(lexed.tokens) |> ignore
    // A file can be syntax-bad by way of a SEMANTIC error raised from an
    // action, which the automaton never sees -- those parse "successfully",
    // and the `noraise` arm below drops them.
    catch {
      err => {
        checked += 1
        match (err, @grammar.error_state(lexed.tokens)) {
          (_, None) => mismatched.push("\{c.file}: replay parsed it")
          (@grammar.UnexpectedToken(_, (start, end), _), Some(st)) => {
            let (_, s, e) = lexed.tokens[st.token_index]
            if s != start || e != end {
              mismatched.push(
                "\{c.file}: replay stopped at \{s.lnum}:\{s.cnum}, parse at \{start.lnum}:\{start.cnum}",
              )
            }
          }
          (@grammar.UnexpectedEndOfInput(_), Some(st)) =>
            // The token array always ends with EOF, so running out mid-array
            // is the only way here; the replay must agree that it did.
            if st.token_index < lexed.tokens.length() {
              mismatched.push("\{c.file}: replay stopped early on end of input")
            }
        }
      }
    } noraise {
      _ => ()
    }
  }
  if mismatched.length() > 0 {
    let sample = mismatched[:@cmp.minimum(8, mismatched.length())].to_owned()
    let joined = sample.join("\n  ")
    fail("\{mismatched.length()} of \{checked} disagreed:\n  \{joined}")
  }
  // Not zero: the count is the coverage, and it dropping would mean the
  // corpus stopped exercising this.
  inspect(checked, content="114")
}

///|
/// The labels resolve, or they do not appear.
///
/// `subject_span` emulates the reduction Menhir performs at the error to find
/// the construct the hedge names, and `enclosing_opener` scans the tokens for
/// the delimiter still open. Neither can be checked against the reference here
/// (the goldens are the harness's business), so what this pins is the property
/// that costs users: a label that points somewhere must point INSIDE the file
/// and span forwards.
test "a resolved label points at real source" {
  let mut labelled = 0
  for c in load_index() {
    if c.bucket != "syntax-bad" {
      continue
    }
    let src = @fs.read_file_to_string("test/corpus/" + c.file)
    let r = @grammar.parse_string(src, fname=c.file)
    for report in r.errors {
      for l in report.related {
        labelled += 1
        assert_true(l.loc.start.cnum < l.loc.end.cnum)
        assert_true(l.loc.end.cnum <= src.length())
        assert_true(l.message != "")
      }
    }
  }
  // The count is the coverage; it falling means the table stopped resolving.
  inspect(labelled, content="5")
}

///|
/// Recovery must not change what a clean file parses to.
///
/// `parse_recover` drives the same tables as the generated `yy_parse` from a
/// hand-written loop (recovery has to live outside a parser that raises), so
/// the risk is not that recovery is poor -- it is that the copy drifts. On a
/// file with no syntax error the two must be indistinguishable: same silence,
/// same tree.
test "recovery leaves a clean parse alone" {
  let differing = []
  let mut checked = 0
  for c in load_index() {
    if c.bucket == "syntax-bad" {
      continue
    }
    let src = @fs.read_file_to_string("test/corpus/" + c.file)
    let plain = @grammar.parse_string(src, fname=c.file)
    let recovered = @grammar.parse_recover(src, fname=c.file)
    checked += 1
    if recovered.errors.length() != 0 {
      differing.push(
        "\{c.file}: recovery reported \{recovered.errors[0].message}",
      )
      continue
    }
    match (plain.module_, recovered.module_) {
      (Some(a), Some(b)) =>
        if @ast.module_to_json(a).stringify() !=
          @ast.module_to_json(b).stringify() {
          differing.push("\{c.file}: different tree")
        }
      (None, _) | (_, None) => differing.push("\{c.file}: one side parsed")
    }
  }
  if differing.length() > 0 {
    let sample = differing[:@cmp.minimum(8, differing.length())].to_owned()
    let joined = sample.join("\n  ")
    fail("\{differing.length()} of \{checked} differ:\n  \{joined}")
  }
  inspect(checked, content="1818")
}
