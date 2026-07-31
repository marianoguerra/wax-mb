// Keyword and operator tables, transcribed from wax/src/lib-wax/lexer.ml.

///|
/// Keywords, looked up after an identifier has been scanned.
///
/// The reference lists these as alternatives in one sedlex match alongside the
/// `ident` rule, relying on longest-match-then-first-rule to resolve `null` to
/// NULL but `nullable` to IDENT. Scanning the identifier first and then
/// consulting a table gives exactly that, without depending on how a particular
/// regex engine breaks ties.
///
/// `inf` and `nan` are here, but see `scan_number`: `nan:0x…` is a FLOAT and
/// must win over the `nan` keyword by being longer, which is the one place the
/// longest-match rule genuinely bites.
let keywords : Map[String, Token] = {
  "null": NULL,
  "inf": INF,
  "nan": NAN,
  "tag": TAG,
  "fn": FN,
  "mut": MUT,
  "type": TYPE,
  "rec": REC,
  "open": OPEN,
  "nop": NOP,
  "unreachable": UNREACHABLE,
  "do": DO,
  "while": WHILE,
  "loop": LOOP,
  "if": IF,
  "else": ELSE,
  "let": LET,
  "const": CONST,
  "as": AS,
  "is": IS,
  "become": BECOME,
  "br": BR,
  "br_if": BR_IF,
  "br_table": BR_TABLE,
  "dispatch": DISPATCH,
  "match": MATCH,
  "br_on_null": BR_ON_NULL,
  "br_on_non_null": BR_ON_NON_NULL,
  "br_on_cast": BR_ON_CAST,
  "br_on_cast_fail": BR_ON_CAST_FAIL,
  "return": RETURN,
  "try": TRY,
  "try_legacy": TRY_LEGACY,
  "catch": CATCH,
  "throw": THROW,
  "throw_ref": THROW_REF,
  "cont": CONT,
  "suspend": SUSPEND,
  "on": ON,
  "memory": MEMORY,
  "import": IMPORT,
  "pagesize": PAGESIZE,
  "shared": SHARED,
  "descriptor": DESCRIPTOR,
  "describes": DESCRIBES,
  "data": DATA,
  "table": TABLE,
  "elem": ELEM,
}

///|
/// Punctuation, LONGEST FIRST.
///
/// The order is the whole point: matching is maximal munch, so `>>s=` has to be
/// tried before `>>s`, which has to be tried before `>>`. Wasm's signed and
/// unsigned operators make these chains unusually deep -- `<=u`, `>>s=`,
/// `/s=` -- and getting the order wrong produces a lexing that is subtly wrong
/// rather than obviously broken, e.g. `a >>s= b` scanned as `a >> (s = b)`.
///
/// `_` is absent: it is UNDERSCORE, but it is also an identifier character, so
/// it is resolved by the identifier scanner instead (`_` alone is UNDERSCORE,
/// `_x` is an IDENT).
let operators : Array[(String, Token)] = [
  // 4 characters
  (">>s=", SHRSEQUAL),
  (">>u=", SHRUEQUAL),
  // 3 characters
  ("<<=", SHLEQUAL),
  (">>s", SHRS),
  (">>u", SHRU),
  ("/s=", SLASHSEQUAL),
  ("/u=", SLASHUEQUAL),
  ("%s=", PERCENTSEQUAL),
  ("%u=", PERCENTUEQUAL),
  ("<=s", LES),
  ("<=u", LEU),
  (">=s", GES),
  (">=u", GEU),
  // 2 characters
  ("::", COLONCOLON),
  ("->", ARROW),
  ("=>", FATARROW),
  (":=", COLONEQUAL),
  ("..", DOTDOT),
  ("++", PLUSPLUS),
  ("+=", PLUSEQUAL),
  ("-=", MINUSEQUAL),
  ("*=", STAREQUAL),
  ("/=", SLASHEQUAL),
  ("/s", SLASHS),
  ("/u", SLASHU),
  ("%s", PERCENTS),
  ("%u", PERCENTU),
  ("&=", AMPERSANDEQUAL),
  ("|=", PIPEEQUAL),
  ("^=", CARETEQUAL),
  ("<<", SHL),
  ("==", EQUALEQUAL),
  ("!=", BANGEQUAL),
  ("<=", LE),
  (">=", GE),
  (">s", GTS),
  (">u", GTU),
  ("<s", LTS),
  ("<u", LTU),
  // 1 character
  (";", SEMI),
  ("#", SHARP),
  ("?", QUESTIONMARK),
  ("(", LPAREN),
  (")", RPAREN),
  ("{", LBRACE),
  ("}", RBRACE),
  ("[", LBRACKET),
  ("]", RBRACKET),
  (",", COMMA),
  (":", COLON),
  ("=", EQUAL),
  ("@", AT),
  ("'", QUOTE),
  (".", DOT),
  ("!", BANG),
  ("+", PLUS),
  ("-", MINUS),
  ("*", STAR),
  ("/", SLASH),
  ("&", AMPERSAND),
  ("|", PIPE),
  ("^", CARET),
  (">", GT),
  ("<", LT),
]
