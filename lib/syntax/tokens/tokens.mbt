pub(all) enum Token {
  IDENT(String)
  INT(String)
  FLOAT(String)
  STRING(LocString)
  CHAR(Char)
  EOF
  INF
  NAN
  SEMI
  SHARP
  QUESTIONMARK
  LPAREN
  RPAREN
  LBRACE
  RBRACE
  LBRACKET
  RBRACKET
  COMMA
  COLON
  COLONCOLON
  ARROW
  FATARROW
  EQUAL
  COLONEQUAL
  AT
  QUOTE
  DOT
  DOTDOT
  BANG
  PLUS
  PLUSPLUS
  PLUSEQUAL
  MINUS
  MINUSEQUAL
  STAR
  STAREQUAL
  SLASH
  SLASHEQUAL
  SLASHS
  SLASHSEQUAL
  SLASHU
  SLASHUEQUAL
  PERCENTS
  PERCENTSEQUAL
  PERCENTU
  PERCENTUEQUAL
  AMPERSAND
  AMPERSANDEQUAL
  PIPE
  PIPEEQUAL
  CARET
  CARETEQUAL
  SHL
  SHLEQUAL
  SHRS
  SHRSEQUAL
  SHRU
  SHRUEQUAL
  EQUALEQUAL
  BANGEQUAL
  GT
  GTS
  GTU
  LT
  LTS
  LTU
  GE
  GES
  GEU
  LE
  LES
  LEU
  UNDERSCORE
  FN
  TAG
  MUT
  TYPE
  REC
  OPEN
  NOP
  UNREACHABLE
  NULL
  DO
  WHILE
  LOOP
  IF
  ELSE
  CONST
  LET
  AS
  IS
  BECOME
  BR
  BR_IF
  BR_TABLE
  RETURN
  THROW
  THROW_REF
  BR_ON_CAST
  BR_ON_CAST_FAIL
  BR_ON_NULL
  BR_ON_NON_NULL
  TRY
  TRY_LEGACY
  CATCH
  CONT
  SUSPEND
  ON
  DISPATCH
  MATCH
  MEMORY
  DATA
  TABLE
  ELEM
  PAGESIZE
  SHARED
  DESCRIPTOR
  DESCRIBES
  IMPORT
} derive(Debug)

pub fn Token::kind(self : Token) -> TokenKind {
  match self {
    IDENT(_) => TK_IDENT
    INT(_) => TK_INT
    FLOAT(_) => TK_FLOAT
    STRING(_) => TK_STRING
    CHAR(_) => TK_CHAR
    EOF => TK_EOF
    INF => TK_INF
    NAN => TK_NAN
    SEMI => TK_SEMI
    SHARP => TK_SHARP
    QUESTIONMARK => TK_QUESTIONMARK
    LPAREN => TK_LPAREN
    RPAREN => TK_RPAREN
    LBRACE => TK_LBRACE
    RBRACE => TK_RBRACE
    LBRACKET => TK_LBRACKET
    RBRACKET => TK_RBRACKET
    COMMA => TK_COMMA
    COLON => TK_COLON
    COLONCOLON => TK_COLONCOLON
    ARROW => TK_ARROW
    FATARROW => TK_FATARROW
    EQUAL => TK_EQUAL
    COLONEQUAL => TK_COLONEQUAL
    AT => TK_AT
    QUOTE => TK_QUOTE
    DOT => TK_DOT
    DOTDOT => TK_DOTDOT
    BANG => TK_BANG
    PLUS => TK_PLUS
    PLUSPLUS => TK_PLUSPLUS
    PLUSEQUAL => TK_PLUSEQUAL
    MINUS => TK_MINUS
    MINUSEQUAL => TK_MINUSEQUAL
    STAR => TK_STAR
    STAREQUAL => TK_STAREQUAL
    SLASH => TK_SLASH
    SLASHEQUAL => TK_SLASHEQUAL
    SLASHS => TK_SLASHS
    SLASHSEQUAL => TK_SLASHSEQUAL
    SLASHU => TK_SLASHU
    SLASHUEQUAL => TK_SLASHUEQUAL
    PERCENTS => TK_PERCENTS
    PERCENTSEQUAL => TK_PERCENTSEQUAL
    PERCENTU => TK_PERCENTU
    PERCENTUEQUAL => TK_PERCENTUEQUAL
    AMPERSAND => TK_AMPERSAND
    AMPERSANDEQUAL => TK_AMPERSANDEQUAL
    PIPE => TK_PIPE
    PIPEEQUAL => TK_PIPEEQUAL
    CARET => TK_CARET
    CARETEQUAL => TK_CARETEQUAL
    SHL => TK_SHL
    SHLEQUAL => TK_SHLEQUAL
    SHRS => TK_SHRS
    SHRSEQUAL => TK_SHRSEQUAL
    SHRU => TK_SHRU
    SHRUEQUAL => TK_SHRUEQUAL
    EQUALEQUAL => TK_EQUALEQUAL
    BANGEQUAL => TK_BANGEQUAL
    GT => TK_GT
    GTS => TK_GTS
    GTU => TK_GTU
    LT => TK_LT
    LTS => TK_LTS
    LTU => TK_LTU
    GE => TK_GE
    GES => TK_GES
    GEU => TK_GEU
    LE => TK_LE
    LES => TK_LES
    LEU => TK_LEU
    UNDERSCORE => TK_UNDERSCORE
    FN => TK_FN
    TAG => TK_TAG
    MUT => TK_MUT
    TYPE => TK_TYPE
    REC => TK_REC
    OPEN => TK_OPEN
    NOP => TK_NOP
    UNREACHABLE => TK_UNREACHABLE
    NULL => TK_NULL
    DO => TK_DO
    WHILE => TK_WHILE
    LOOP => TK_LOOP
    IF => TK_IF
    ELSE => TK_ELSE
    CONST => TK_CONST
    LET => TK_LET
    AS => TK_AS
    IS => TK_IS
    BECOME => TK_BECOME
    BR => TK_BR
    BR_IF => TK_BR_IF
    BR_TABLE => TK_BR_TABLE
    RETURN => TK_RETURN
    THROW => TK_THROW
    THROW_REF => TK_THROW_REF
    BR_ON_CAST => TK_BR_ON_CAST
    BR_ON_CAST_FAIL => TK_BR_ON_CAST_FAIL
    BR_ON_NULL => TK_BR_ON_NULL
    BR_ON_NON_NULL => TK_BR_ON_NON_NULL
    TRY => TK_TRY
    TRY_LEGACY => TK_TRY_LEGACY
    CATCH => TK_CATCH
    CONT => TK_CONT
    SUSPEND => TK_SUSPEND
    ON => TK_ON
    DISPATCH => TK_DISPATCH
    MATCH => TK_MATCH
    MEMORY => TK_MEMORY
    DATA => TK_DATA
    TABLE => TK_TABLE
    ELEM => TK_ELEM
    PAGESIZE => TK_PAGESIZE
    SHARED => TK_SHARED
    DESCRIPTOR => TK_DESCRIPTOR
    DESCRIBES => TK_DESCRIBES
    IMPORT => TK_IMPORT
  }
}

pub(all) enum TokenKind {
  TK_IDENT
  TK_INT
  TK_FLOAT
  TK_STRING
  TK_CHAR
  TK_EOF
  TK_INF
  TK_NAN
  TK_SEMI
  TK_SHARP
  TK_QUESTIONMARK
  TK_LPAREN
  TK_RPAREN
  TK_LBRACE
  TK_RBRACE
  TK_LBRACKET
  TK_RBRACKET
  TK_COMMA
  TK_COLON
  TK_COLONCOLON
  TK_ARROW
  TK_FATARROW
  TK_EQUAL
  TK_COLONEQUAL
  TK_AT
  TK_QUOTE
  TK_DOT
  TK_DOTDOT
  TK_BANG
  TK_PLUS
  TK_PLUSPLUS
  TK_PLUSEQUAL
  TK_MINUS
  TK_MINUSEQUAL
  TK_STAR
  TK_STAREQUAL
  TK_SLASH
  TK_SLASHEQUAL
  TK_SLASHS
  TK_SLASHSEQUAL
  TK_SLASHU
  TK_SLASHUEQUAL
  TK_PERCENTS
  TK_PERCENTSEQUAL
  TK_PERCENTU
  TK_PERCENTUEQUAL
  TK_AMPERSAND
  TK_AMPERSANDEQUAL
  TK_PIPE
  TK_PIPEEQUAL
  TK_CARET
  TK_CARETEQUAL
  TK_SHL
  TK_SHLEQUAL
  TK_SHRS
  TK_SHRSEQUAL
  TK_SHRU
  TK_SHRUEQUAL
  TK_EQUALEQUAL
  TK_BANGEQUAL
  TK_GT
  TK_GTS
  TK_GTU
  TK_LT
  TK_LTS
  TK_LTU
  TK_GE
  TK_GES
  TK_GEU
  TK_LE
  TK_LES
  TK_LEU
  TK_UNDERSCORE
  TK_FN
  TK_TAG
  TK_MUT
  TK_TYPE
  TK_REC
  TK_OPEN
  TK_NOP
  TK_UNREACHABLE
  TK_NULL
  TK_DO
  TK_WHILE
  TK_LOOP
  TK_IF
  TK_ELSE
  TK_CONST
  TK_LET
  TK_AS
  TK_IS
  TK_BECOME
  TK_BR
  TK_BR_IF
  TK_BR_TABLE
  TK_RETURN
  TK_THROW
  TK_THROW_REF
  TK_BR_ON_CAST
  TK_BR_ON_CAST_FAIL
  TK_BR_ON_NULL
  TK_BR_ON_NON_NULL
  TK_TRY
  TK_TRY_LEGACY
  TK_CATCH
  TK_CONT
  TK_SUSPEND
  TK_ON
  TK_DISPATCH
  TK_MATCH
  TK_MEMORY
  TK_DATA
  TK_TABLE
  TK_ELEM
  TK_PAGESIZE
  TK_SHARED
  TK_DESCRIPTOR
  TK_DESCRIBES
  TK_IMPORT
} derive(Eq, Hash, Compare)

pub impl Show for TokenKind with fn output(self, logger) {
  logger.write_string(
    match self {
      TK_IDENT => "IDENT"
      TK_INT => "INT"
      TK_FLOAT => "FLOAT"
      TK_STRING => "STRING"
      TK_CHAR => "CHAR"
      TK_EOF => "EOF"
      TK_INF => "INF"
      TK_NAN => "NAN"
      TK_SEMI => "\";\""
      TK_SHARP => "\"#\""
      TK_QUESTIONMARK => "\"?\""
      TK_LPAREN => "\"(\""
      TK_RPAREN => "\")\""
      TK_LBRACE => "\"{\""
      TK_RBRACE => "\"}\""
      TK_LBRACKET => "\"[\""
      TK_RBRACKET => "\"]\""
      TK_COMMA => "\",\""
      TK_COLON => "\":\""
      TK_COLONCOLON => "\"::\""
      TK_ARROW => "\"->\""
      TK_FATARROW => "\"=>\""
      TK_EQUAL => "\"=\""
      TK_COLONEQUAL => "\":=\""
      TK_AT => "\"@\""
      TK_QUOTE => "\"'\""
      TK_DOT => "\".\""
      TK_DOTDOT => "\"..\""
      TK_BANG => "\"!\""
      TK_PLUS => "\"+\""
      TK_PLUSPLUS => "\"++\""
      TK_PLUSEQUAL => "\"+=\""
      TK_MINUS => "\"-\""
      TK_MINUSEQUAL => "\"-=\""
      TK_STAR => "\"*\""
      TK_STAREQUAL => "\"*=\""
      TK_SLASH => "\"/\""
      TK_SLASHEQUAL => "\"/=\""
      TK_SLASHS => "\"/s\""
      TK_SLASHSEQUAL => "\"/s=\""
      TK_SLASHU => "\"/u\""
      TK_SLASHUEQUAL => "\"/u=\""
      TK_PERCENTS => "\"%s\""
      TK_PERCENTSEQUAL => "\"%s=\""
      TK_PERCENTU => "\"%u\""
      TK_PERCENTUEQUAL => "\"%u=\""
      TK_AMPERSAND => "\"&\""
      TK_AMPERSANDEQUAL => "\"&=\""
      TK_PIPE => "\"|\""
      TK_PIPEEQUAL => "\"|=\""
      TK_CARET => "\"^\""
      TK_CARETEQUAL => "\"^=\""
      TK_SHL => "\"<<\""
      TK_SHLEQUAL => "\"<<=\""
      TK_SHRS => "\">>s\""
      TK_SHRSEQUAL => "\">>s=\""
      TK_SHRU => "\">>u\""
      TK_SHRUEQUAL => "\">>u=\""
      TK_EQUALEQUAL => "\"==\""
      TK_BANGEQUAL => "\"!=\""
      TK_GT => "\">\""
      TK_GTS => "\">s\""
      TK_GTU => "\">u\""
      TK_LT => "\"<\""
      TK_LTS => "\"<s\""
      TK_LTU => "\"<u\""
      TK_GE => "\">=\""
      TK_GES => "\">=s\""
      TK_GEU => "\">=u\""
      TK_LE => "\"<=\""
      TK_LES => "\"<=s\""
      TK_LEU => "\"<=u\""
      TK_UNDERSCORE => "\"_\""
      TK_FN => "FN"
      TK_TAG => "TAG"
      TK_MUT => "MUT"
      TK_TYPE => "TYPE"
      TK_REC => "REC"
      TK_OPEN => "OPEN"
      TK_NOP => "NOP"
      TK_UNREACHABLE => "UNREACHABLE"
      TK_NULL => "NULL"
      TK_DO => "DO"
      TK_WHILE => "WHILE"
      TK_LOOP => "LOOP"
      TK_IF => "IF"
      TK_ELSE => "ELSE"
      TK_CONST => "CONST"
      TK_LET => "LET"
      TK_AS => "AS"
      TK_IS => "IS"
      TK_BECOME => "BECOME"
      TK_BR => "BR"
      TK_BR_IF => "BR_IF"
      TK_BR_TABLE => "BR_TABLE"
      TK_RETURN => "RETURN"
      TK_THROW => "THROW"
      TK_THROW_REF => "THROW_REF"
      TK_BR_ON_CAST => "BR_ON_CAST"
      TK_BR_ON_CAST_FAIL => "BR_ON_CAST_FAIL"
      TK_BR_ON_NULL => "BR_ON_NULL"
      TK_BR_ON_NON_NULL => "BR_ON_NON_NULL"
      TK_TRY => "TRY"
      TK_TRY_LEGACY => "TRY_LEGACY"
      TK_CATCH => "CATCH"
      TK_CONT => "CONT"
      TK_SUSPEND => "SUSPEND"
      TK_ON => "ON"
      TK_DISPATCH => "DISPATCH"
      TK_MATCH => "MATCH"
      TK_MEMORY => "MEMORY"
      TK_DATA => "DATA"
      TK_TABLE => "TABLE"
      TK_ELEM => "ELEM"
      TK_PAGESIZE => "PAGESIZE"
      TK_SHARED => "SHARED"
      TK_DESCRIPTOR => "DESCRIPTOR"
      TK_DESCRIBES => "DESCRIBES"
      TK_IMPORT => "IMPORT"
    }
  )
}

pub impl Debug for TokenKind with fn to_repr(self) {
    match self {
      TK_IDENT => Repr("IDENT")
      TK_INT => Repr("INT")
      TK_FLOAT => Repr("FLOAT")
      TK_STRING => Repr("STRING")
      TK_CHAR => Repr("CHAR")
      TK_EOF => Repr("EOF")
      TK_INF => Repr("INF")
      TK_NAN => Repr("NAN")
      TK_SEMI => Repr(";")
      TK_SHARP => Repr("#")
      TK_QUESTIONMARK => Repr("?")
      TK_LPAREN => Repr("(")
      TK_RPAREN => Repr(")")
      TK_LBRACE => Repr("{")
      TK_RBRACE => Repr("}")
      TK_LBRACKET => Repr("[")
      TK_RBRACKET => Repr("]")
      TK_COMMA => Repr(",")
      TK_COLON => Repr(":")
      TK_COLONCOLON => Repr("::")
      TK_ARROW => Repr("->")
      TK_FATARROW => Repr("=>")
      TK_EQUAL => Repr("=")
      TK_COLONEQUAL => Repr(":=")
      TK_AT => Repr("@")
      TK_QUOTE => Repr("'")
      TK_DOT => Repr(".")
      TK_DOTDOT => Repr("..")
      TK_BANG => Repr("!")
      TK_PLUS => Repr("+")
      TK_PLUSPLUS => Repr("++")
      TK_PLUSEQUAL => Repr("+=")
      TK_MINUS => Repr("-")
      TK_MINUSEQUAL => Repr("-=")
      TK_STAR => Repr("*")
      TK_STAREQUAL => Repr("*=")
      TK_SLASH => Repr("/")
      TK_SLASHEQUAL => Repr("/=")
      TK_SLASHS => Repr("/s")
      TK_SLASHSEQUAL => Repr("/s=")
      TK_SLASHU => Repr("/u")
      TK_SLASHUEQUAL => Repr("/u=")
      TK_PERCENTS => Repr("%s")
      TK_PERCENTSEQUAL => Repr("%s=")
      TK_PERCENTU => Repr("%u")
      TK_PERCENTUEQUAL => Repr("%u=")
      TK_AMPERSAND => Repr("&")
      TK_AMPERSANDEQUAL => Repr("&=")
      TK_PIPE => Repr("|")
      TK_PIPEEQUAL => Repr("|=")
      TK_CARET => Repr("^")
      TK_CARETEQUAL => Repr("^=")
      TK_SHL => Repr("<<")
      TK_SHLEQUAL => Repr("<<=")
      TK_SHRS => Repr(">>s")
      TK_SHRSEQUAL => Repr(">>s=")
      TK_SHRU => Repr(">>u")
      TK_SHRUEQUAL => Repr(">>u=")
      TK_EQUALEQUAL => Repr("==")
      TK_BANGEQUAL => Repr("!=")
      TK_GT => Repr(">")
      TK_GTS => Repr(">s")
      TK_GTU => Repr(">u")
      TK_LT => Repr("<")
      TK_LTS => Repr("<s")
      TK_LTU => Repr("<u")
      TK_GE => Repr(">=")
      TK_GES => Repr(">=s")
      TK_GEU => Repr(">=u")
      TK_LE => Repr("<=")
      TK_LES => Repr("<=s")
      TK_LEU => Repr("<=u")
      TK_UNDERSCORE => Repr("_")
      TK_FN => Repr("FN")
      TK_TAG => Repr("TAG")
      TK_MUT => Repr("MUT")
      TK_TYPE => Repr("TYPE")
      TK_REC => Repr("REC")
      TK_OPEN => Repr("OPEN")
      TK_NOP => Repr("NOP")
      TK_UNREACHABLE => Repr("UNREACHABLE")
      TK_NULL => Repr("NULL")
      TK_DO => Repr("DO")
      TK_WHILE => Repr("WHILE")
      TK_LOOP => Repr("LOOP")
      TK_IF => Repr("IF")
      TK_ELSE => Repr("ELSE")
      TK_CONST => Repr("CONST")
      TK_LET => Repr("LET")
      TK_AS => Repr("AS")
      TK_IS => Repr("IS")
      TK_BECOME => Repr("BECOME")
      TK_BR => Repr("BR")
      TK_BR_IF => Repr("BR_IF")
      TK_BR_TABLE => Repr("BR_TABLE")
      TK_RETURN => Repr("RETURN")
      TK_THROW => Repr("THROW")
      TK_THROW_REF => Repr("THROW_REF")
      TK_BR_ON_CAST => Repr("BR_ON_CAST")
      TK_BR_ON_CAST_FAIL => Repr("BR_ON_CAST_FAIL")
      TK_BR_ON_NULL => Repr("BR_ON_NULL")
      TK_BR_ON_NON_NULL => Repr("BR_ON_NON_NULL")
      TK_TRY => Repr("TRY")
      TK_TRY_LEGACY => Repr("TRY_LEGACY")
      TK_CATCH => Repr("CATCH")
      TK_CONT => Repr("CONT")
      TK_SUSPEND => Repr("SUSPEND")
      TK_ON => Repr("ON")
      TK_DISPATCH => Repr("DISPATCH")
      TK_MATCH => Repr("MATCH")
      TK_MEMORY => Repr("MEMORY")
      TK_DATA => Repr("DATA")
      TK_TABLE => Repr("TABLE")
      TK_ELEM => Repr("ELEM")
      TK_PAGESIZE => Repr("PAGESIZE")
      TK_SHARED => Repr("SHARED")
      TK_DESCRIPTOR => Repr("DESCRIPTOR")
      TK_DESCRIBES => Repr("DESCRIBES")
      TK_IMPORT => Repr("IMPORT")
    }
}

