///|
/// Print the automaton state each line of the input file fails in.
///
/// A dev tool for `tools/gen_parser_messages.py`, which needs our error state
/// for several hundred of the reference's error sentences and would otherwise
/// pay a process launch for each. One line of source in, one line out:
///
///     STATE TAB stack TAB token-index TAB token-count TAB expected-signature
///     -                                    -- the line parses, or fails to lex
///
/// The two indices are how the caller checks that the source it wrote really
/// does fail on the token it meant: a lexeme chosen badly enough to fail
/// EARLIER would otherwise key a message to the wrong state. The signature is
/// what the table stores so a stack suffix cannot be borrowed by a context
/// where different tokens are legal.
///
/// Reading a whole file at once is what makes it worth existing at all; the
/// state itself is `@grammar.error_state`, and that is the interesting part.
/// `--whole` reads the file as ONE source instead, which is how you ask what a
/// real .wax file lands on -- the line-per-source form cannot express one.
fn main {
  let args = @env.args()
  if args.length() < 2 {
    println("usage: errstate [--whole] <file>")
    return
  }
  let whole = args[1] == "--whole"
  let path = if whole { args[2] } else { args[1] }
  let text = @fs.read_file_to_string(path) catch {
    e => {
      println("cannot read \{path}")
      ignore(e)
      return
    }
  }
  let sources = if whole { [text] } else { [] }
  if !whole {
    for line in text.split("\n") {
      sources.push(line.to_owned())
    }
  }
  for src in sources {
    if src == "" {
      continue
    }
    let ctx = @trivia.Context::new()
    @grammar.set_context(ctx)
    let lexed = @lexer.tokens_from_string(src, trivia_ctx=ctx)
    if lexed.errors.length() > 0 {
      println("-")
      continue
    }
    match @grammar.error_state(lexed.tokens) {
      None => println("-")
      Some(st) => {
        let stack = []
        for s in st.stack {
          stack.push(s.to_string())
        }
        // The acceptable set comes from the real parse, not the replay: it is
        // the parser's own answer, and the run-time lookup compares against
        // exactly this.
        let signature = try {
          @grammar.parse(lexed.tokens) |> ignore
          ""
        } catch {
          @grammar.UnexpectedToken(_, _, expected)
          | @grammar.UnexpectedEndOfInput(_, expected) =>
            @grammar.expected_signature(expected)
        } noraise {
          _ => ""
        }
        println(
          "\{st.state}\t\{stack.join(" ")}\t\{st.token_index}\t\{lexed.tokens.length()}\t\{signature}",
        )
      }
    }
  }
}
