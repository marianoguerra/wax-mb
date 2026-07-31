// Lexer behaviour tests.
//
// The differential harness cannot grade a lexer on its own -- oracle 1 needs a
// printer, which arrives in phase 3 -- so these pin the cases the reference's
// own lexer.ml is shaped around, especially the ones where a plausible
// implementation is subtly wrong rather than obviously broken.

///|
/// The token stream, for `debug_inspect`. Token derives Debug, not Show.
fn toks(src : String) -> Array[@tokens.Token] {
  let r = @lexer.tokens_from_string(src)
  let out = []
  for t in r.tokens {
    out.push(t.0)
  }
  out
}

///|
fn errs(src : String) -> Array[String] {
  let r = @lexer.tokens_from_string(src)
  let out = []
  for e in r.errors {
    out.push(e.message)
  }
  out
}

///|
test "a keyword is a keyword only when it is the whole identifier" {
  // `null` is NULL, but `nullable` is one identifier -- the classic
  // longest-match trap.
  debug_inspect(
    toks("null"),
    content=(
      #|[NULL, EOF]
    ),
  )
  debug_inspect(
    toks("nullable"),
    content=(
      #|[IDENT("nullable"), EOF]
    ),
  )
  debug_inspect(
    toks("if_"),
    content=(
      #|[IDENT("if_"), EOF]
    ),
  )
  debug_inspect(
    toks("br br_if br_on_cast_fail"),
    content=(
      #|[BR, BR_IF, BR_ON_CAST_FAIL, EOF]
    ),
  )
}

///|
test "nan:0x1 is a float and beats the nan keyword" {
  // The single case where longest-match genuinely bites: scanning keywords
  // first would give NAN COLON INT.
  debug_inspect(
    toks("nan:0x1"),
    content=(
      #|[FLOAT("nan:0x1"), EOF]
    ),
  )
  debug_inspect(
    toks("nan"),
    content=(
      #|[NAN, EOF]
    ),
  )
  debug_inspect(
    toks("inf"),
    content=(
      #|[INF, EOF]
    ),
  )
}

///|
test "operators are maximal munch, deepest chain first" {
  // Getting the order wrong yields `a >> (s= b)` rather than `a >>s= b`.
  debug_inspect(
    toks(">>s="),
    content=(
      #|[SHRSEQUAL, EOF]
    ),
  )
  debug_inspect(
    toks(">>s"),
    content=(
      #|[SHRS, EOF]
    ),
  )
  debug_inspect(
    toks(">>u="),
    content=(
      #|[SHRUEQUAL, EOF]
    ),
  )
  debug_inspect(
    toks("<<="),
    content=(
      #|[SHLEQUAL, EOF]
    ),
  )
  debug_inspect(
    toks("<="),
    content=(
      #|[LE, EOF]
    ),
  )
  debug_inspect(
    toks("<=s"),
    content=(
      #|[LES, EOF]
    ),
  )
  debug_inspect(
    toks("/s="),
    content=(
      #|[SLASHSEQUAL, EOF]
    ),
  )
  debug_inspect(
    toks("/s"),
    content=(
      #|[SLASHS, EOF]
    ),
  )
  debug_inspect(
    toks("/"),
    content=(
      #|[SLASH, EOF]
    ),
  )
  debug_inspect(
    toks("::"),
    content=(
      #|[COLONCOLON, EOF]
    ),
  )
  debug_inspect(
    toks(":="),
    content=(
      #|[COLONEQUAL, EOF]
    ),
  )
  debug_inspect(
    toks(".."),
    content=(
      #|[DOTDOT, EOF]
    ),
  )
  debug_inspect(
    toks("++"),
    content=(
      #|[PLUSPLUS, EOF]
    ),
  )
}

///|
test "underscore alone is a token, with an identifier it is a name" {
  debug_inspect(
    toks("_"),
    content=(
      #|[UNDERSCORE, EOF]
    ),
  )
  debug_inspect(
    toks("_x"),
    content=(
      #|[IDENT("_x"), EOF]
    ),
  )
  debug_inspect(
    toks("_ = 1"),
    content=(
      #|[UNDERSCORE, EQUAL, INT("1"), EOF]
    ),
  )
}

///|
test "numeric literals keep their raw text" {
  // Round-tripping depends on this: 0x1_0 must print back as written.
  debug_inspect(
    toks("0x1_0"),
    content=(
      #|[INT("0x1_0"), EOF]
    ),
  )
  debug_inspect(
    toks("1_000"),
    content=(
      #|[INT("1_000"), EOF]
    ),
  )
  debug_inspect(
    toks("1.5"),
    content=(
      #|[FLOAT("1.5"), EOF]
    ),
  )
  debug_inspect(
    toks("1e10"),
    content=(
      #|[FLOAT("1e10"), EOF]
    ),
  )
  debug_inspect(
    toks("1E+10"),
    content=(
      #|[FLOAT("1E+10"), EOF]
    ),
  )
  debug_inspect(
    toks("0x1p3"),
    content=(
      #|[FLOAT("0x1p3"), EOF]
    ),
  )
  debug_inspect(
    toks("0x1.8p1"),
    content=(
      #|[FLOAT("0x1.8p1"), EOF]
    ),
  )
}

///|
test "a dot after an integer is only part of it when a number follows" {
  // `0..1` is a range, not the float `0.` then `.1`.
  debug_inspect(
    toks("0..1"),
    content=(
      #|[INT("0"), DOTDOT, INT("1"), EOF]
    ),
  )
}

///|
test "quote is a character literal or a label introducer" {
  // Both readings of `'` exist in Wax, and the lexer has to try the literal
  // first and fall back.
  debug_inspect(
    toks("'a'"),
    content=(
      #|[CHAR('a'), EOF]
    ),
  )
  debug_inspect(
    toks("'outer"),
    content=(
      #|[QUOTE, IDENT("outer"), EOF]
    ),
  )
  // A label whose name IS a keyword still lexes as QUOTE + that keyword; the
  // grammar, not the lexer, decides a label may be spelled that way.
  debug_inspect(
    toks("'loop"),
    content=(
      #|[QUOTE, LOOP, EOF]
    ),
  )
  debug_inspect(
    toks("'\\n'"),
    content=(
      #|[CHAR('\n'), EOF]
    ),
  )
}

///|
test "string escapes are decoded" {
  debug_inspect(
    toks("\"a\\tb\""),
    content=(
      #|[
      #|  STRING(
      #|    {
      #|      desc: "a\tb",
      #|      info: {
      #|        start: { fname: "", lnum: 1, bol: 0, cnum: 0 },
      #|        end: { fname: "", lnum: 1, bol: 0, cnum: 6 },
      #|      },
      #|    },
      #|  ),
      #|  EOF,
      #|]
    ),
  )
  debug_inspect(
    toks("\"\\u{48}i\""),
    content=(
      #|[
      #|  STRING(
      #|    {
      #|      desc: "Hi",
      #|      info: {
      #|        start: { fname: "", lnum: 1, bol: 0, cnum: 0 },
      #|        end: { fname: "", lnum: 1, bol: 0, cnum: 9 },
      #|      },
      #|    },
      #|  ),
      #|  EOF,
      #|]
    ),
  )
}

///|
test "block comments nest" {
  // A non-nesting scanner ends the comment at the inner `*/` and then chokes.
  let r = @lexer.tokens_from_string("/* a /* b */ c */ fn")
  inspect(r.errors.length(), content="0")
  debug_inspect(
    toks("/* a /* b */ c */ fn"),
    content=(
      #|[FN, EOF]
    ),
  )
}

///|
test "positions are UTF-8 byte offsets, not UTF-16 indices" {
  // `"é"` is 1 UTF-16 unit but 2 UTF-8 bytes. The reference reports bytes, and
  // oracle 3 compares them exactly.
  let r = @lexer.tokens_from_string("\"é\" x")
  let x = r.tokens[1]
  debug_inspect(
    x.0,
    content=(
      #|IDENT("x")
    ),
  )
  inspect(x.1.cnum, content="5") // "  é(2)  "  space  -> 5
  inspect(x.1.column0(), content="5")
}

///|
test "lexical errors match the reference and stop the scan" {
  debug_inspect(
    errs("fn f() { $x; }"),
    content=(
      #|["Unexpected character '$'."]
    ),
  )
  debug_inspect(
    errs("/* oops"),
    content=(
      #|["Malformed comment."]
    ),
  )
  debug_inspect(
    errs("\"abc"),
    content=(
      #|["Malformed string."]
    ),
  )
  debug_inspect(
    errs("\"\\u{110000}\""),
    content=(
      #|["Malformed Unicode escape."]
    ),
  )
  debug_inspect(
    errs("'\\xFF'"),
    content=(
      #|["Invalid Unicode character."]
    ),
  )
}

///|
test "an invalid identifier character is reported at its own offset" {
  // The reference narrows the span to the offending character rather than
  // blaming the whole word, which is why it re-validates XID separately.
  let r = @lexer.tokens_from_string("let a\u{00A9}b = 1;")
  inspect(r.errors.length(), content="1")
  inspect(r.errors[0].message, content="Unexpected character '©'.")
  // 'let ' is 4 bytes and 'a' is 1, so the © starts at byte 5 and spans 2.
  inspect(r.errors[0].loc.start.cnum, content="5")
  inspect(r.errors[0].loc.end.cnum, content="7")
}

///|
test "non-ASCII identifiers are accepted when they are valid XID" {
  let r = @lexer.tokens_from_string("let café = 1;")
  inspect(r.errors.length(), content="0")
  debug_inspect(
    r.tokens[1].0,
    content=(
      #|IDENT("café")
    ),
  )
}

///|
test "comments and blank lines reach the trivia table, not the parser" {
  let src = "fn f() {} // trailing\n\n// own line\nfn g() {}"
  let r = @lexer.tokens_from_string(src)
  debug_inspect(
    toks(src),
    content=(
      #|[
      #|  FN,
      #|  IDENT("f"),
      #|  LPAREN,
      #|  RPAREN,
      #|  LBRACE,
      #|  RBRACE,
      #|  FN,
      #|  IDENT("g"),
      #|  LPAREN,
      #|  RPAREN,
      #|  LBRACE,
      #|  RBRACE,
      #|  EOF,
      #|]
    ),
  )
  let e = r.trivia.entries()
  inspect(e.length(), content="3")
  debug_inspect(
    e[0].position,
    content=(
      #|Inline
    ),
  ) // trailing comment
  debug_inspect(
    e[1].trivia,
    content=(
      #|BlankLine
    ),
  )
  debug_inspect(
    e[2].position,
    content=(
      #|LineStart
    ),
  )
}

///|
test "the token stream is always EOF-terminated" {
  debug_inspect(
    toks(""),
    content=(
      #|[EOF]
    ),
  )
  debug_inspect(
    toks("   \n  "),
    content=(
      #|[EOF]
    ),
  )
}
