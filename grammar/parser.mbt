
pub suberror ParseError {
  UnexpectedToken(Token, (Position, Position), Array[TokenKind])
  UnexpectedEndOfInput(Position, Array[TokenKind])
}

type YYObj = Error

priv suberror YYObj_Void

priv suberror YYObj_Char {
  YYObj_Char(Char)
}

priv suberror YYObj_Unit {
  YYObj_Unit(Unit)
}

priv suberror YYObj_String {
  YYObj_String(String)
}

priv suberror YYObj_LocString {
  YYObj_LocString(LocString)
}

type YYState = (YYSymbol) -> YYDecision

type YYAction = (Position, ArrayView[(YYObj, Position, Position)]) -> YYObj

priv enum YYDecision {
  Accept
  Shift(YYState)
  Reduce(Int, YYSymbol, YYAction)
  ReduceNoLookahead(Int, YYSymbol, YYAction)
  Error
}

priv enum YYSymbol {
  T_IDENT
  T_INT
  T_FLOAT
  T_STRING
  T_CHAR
  T_EOF
  T_INF
  T_NAN
  T_SEMI
  T_SHARP
  T_QUESTIONMARK
  T_LPAREN
  T_RPAREN
  T_LBRACE
  T_RBRACE
  T_LBRACKET
  T_RBRACKET
  T_COMMA
  T_COLON
  T_COLONCOLON
  T_ARROW
  T_FATARROW
  T_EQUAL
  T_COLONEQUAL
  T_AT
  T_QUOTE
  T_DOT
  T_DOTDOT
  T_BANG
  T_PLUS
  T_PLUSPLUS
  T_PLUSEQUAL
  T_MINUS
  T_MINUSEQUAL
  T_STAR
  T_STAREQUAL
  T_SLASH
  T_SLASHEQUAL
  T_SLASHS
  T_SLASHSEQUAL
  T_SLASHU
  T_SLASHUEQUAL
  T_PERCENTS
  T_PERCENTSEQUAL
  T_PERCENTU
  T_PERCENTUEQUAL
  T_AMPERSAND
  T_AMPERSANDEQUAL
  T_PIPE
  T_PIPEEQUAL
  T_CARET
  T_CARETEQUAL
  T_SHL
  T_SHLEQUAL
  T_SHRS
  T_SHRSEQUAL
  T_SHRU
  T_SHRUEQUAL
  T_EQUALEQUAL
  T_BANGEQUAL
  T_GT
  T_GTS
  T_GTU
  T_LT
  T_LTS
  T_LTU
  T_GE
  T_GES
  T_GEU
  T_LE
  T_LES
  T_LEU
  T_UNDERSCORE
  T_FN
  T_TAG
  T_MUT
  T_TYPE
  T_REC
  T_OPEN
  T_NOP
  T_UNREACHABLE
  T_NULL
  T_DO
  T_WHILE
  T_LOOP
  T_IF
  T_ELSE
  T_CONST
  T_LET
  T_AS
  T_IS
  T_BECOME
  T_BR
  T_BR_IF
  T_BR_TABLE
  T_RETURN
  T_THROW
  T_THROW_REF
  T_BR_ON_CAST
  T_BR_ON_CAST_FAIL
  T_BR_ON_NULL
  T_BR_ON_NON_NULL
  T_TRY
  T_TRY_LEGACY
  T_CATCH
  T_CONT
  T_SUSPEND
  T_ON
  T_DISPATCH
  T_MATCH
  T_MEMORY
  T_DATA
  T_TABLE
  T_ELEM
  T_PAGESIZE
  T_SHARED
  T_DESCRIPTOR
  T_DESCRIBES
  T_IMPORT
  NT_ident_or_keyword
  NT_label_name
  NT_heap_type
  NT_reference_type
  NT_value_type
  NT_cast_type
  NT_result_type_
  NT_result_type
  NT_storage_type
  NT_field_type
  NT_field_name
  NT_structure_type_field
  NT_structure_type
  NT_structtype
  NT_arraytype
  NT_composite_type
  NT_type_name
  NT_type_definition
  NT_rectype
  NT_attribute_expression
  NT_attribute_guard
  NT_attribute
  NT_hint_attr
  NT_hint_target
  NT_inner_attribute
  NT_simple_pattern
  NT_function_parameter
  NT_parameter_list
  NT_function_type_definition
  NT_function_name
  NT_optional_function_type
  NT_func
  NT_tag_name
  NT_tag_signature
  NT_block_param_type
  NT_parameter_types
  NT_block_type
  NT_braced_block
  NT_catch
  NT_on_clause
  NT_on_clauses
  NT_legacy_catch
  NT_catch_arm
  NT_catch_all_arm
  NT_legacy_catch_all
  NT_structure_field
  NT_structure
  NT_dispatch_arm
  NT_match_pattern
  NT_match_arm
  NT_match_default
  NT_case_labels
  NT_blockinstr
  NT_parenthesized_expression
  NT_descriptor_operand
  NT_index_expression
  NT_then_branch
  NT_condition_expression
  NT_length_expression
  NT_expression_list
  NT_argument
  NT_argument_list
  NT_plaininstr
  NT_branch_expr
  NT_array_body
  NT_expression
  NT_parse
  NT_statement_list
  NT_hinted_statement
  NT_condition
  NT_boption_QUESTIONMARK_
  NT_boption_BANG_
  NT_non_empty_sep_trailing_COMMA_value_type_
  NT_boption_MUT_
  NT_sep_trailing_COMMA_structure_type_field_
  NT_option_supertype_clause_
  NT_boption_OPEN_
  NT_list_of_type_definition_
  NT_sep_trailing_COMMA_hint_target_
  NT_sep_trailing_COMMA_function_parameter_
  NT_function_type_AS_
  NT_function_type_TYPE_
  NT_function_type_FN_
  NT_option_function_type_FN__
  NT_sep_trailing_COMMA_block_param_type_
  NT_sep_trailing_COMMA_on_clause_
  NT_sep_trailing_COMMA_structure_field_
  NT_semi_list_dispatch_arm_
  NT_semi_list_match_arm_
  NT_option_block_type_
  NT_option_if_block_type_
  NT_sep_trailing_COMMA_catch_
  NT_semi_list_catch_arm_
  NT_option_catch_all_arm_
  NT_semi_list_legacy_catch_
  NT_option_legacy_catch_all_
  NT_sep_trailing_COMMA_expression_
  NT_sep_trailing_COMMA_argument_
  NT_non_empty_sep_trailing_COMMA_structure_type_field_
  NT_non_empty_sep_trailing_COMMA_hint_target_
  NT_non_empty_sep_trailing_COMMA_function_parameter_
  NT_non_empty_sep_trailing_COMMA_block_param_type_
  NT_non_empty_sep_trailing_COMMA_on_clause_
  NT_non_empty_sep_trailing_COMMA_structure_field_
  NT_non_empty_sep_trailing_COMMA_catch_
  NT_non_empty_sep_trailing_COMMA_expression_
  NT_non_empty_sep_trailing_COMMA_argument_
  EOI
}

// Workaround for EOI unused warning
fn init {
  match (EOI : YYSymbol) {
    EOI => ()
    _ => ()
  }
}

// file:///./parser.mbty
// 1043|    EOF { () }
fn yy_action_0(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Unit({();  () })
}

fn yy_input(token : Token, _start_pos : Position, _end_pos : Position) -> (YYSymbol, YYObj) {
  match token {
    IDENT(data) => (T_IDENT, YYObj_String(data))
    INT(data) => (T_INT, YYObj_String(data))
    FLOAT(data) => (T_FLOAT, YYObj_String(data))
    STRING(data) => (T_STRING, YYObj_LocString(data))
    CHAR(data) => (T_CHAR, YYObj_Char(data))
    EOF => (T_EOF, YYObj_Void)
    INF => (T_INF, YYObj_Void)
    NAN => (T_NAN, YYObj_Void)
    SEMI => (T_SEMI, YYObj_Void)
    SHARP => (T_SHARP, YYObj_Void)
    QUESTIONMARK => (T_QUESTIONMARK, YYObj_Void)
    LPAREN => (T_LPAREN, YYObj_Void)
    RPAREN => (T_RPAREN, YYObj_Void)
    LBRACE => (T_LBRACE, YYObj_Void)
    RBRACE => (T_RBRACE, YYObj_Void)
    LBRACKET => (T_LBRACKET, YYObj_Void)
    RBRACKET => (T_RBRACKET, YYObj_Void)
    COMMA => (T_COMMA, YYObj_Void)
    COLON => (T_COLON, YYObj_Void)
    COLONCOLON => (T_COLONCOLON, YYObj_Void)
    ARROW => (T_ARROW, YYObj_Void)
    FATARROW => (T_FATARROW, YYObj_Void)
    EQUAL => (T_EQUAL, YYObj_Void)
    COLONEQUAL => (T_COLONEQUAL, YYObj_Void)
    AT => (T_AT, YYObj_Void)
    QUOTE => (T_QUOTE, YYObj_Void)
    DOT => (T_DOT, YYObj_Void)
    DOTDOT => (T_DOTDOT, YYObj_Void)
    BANG => (T_BANG, YYObj_Void)
    PLUS => (T_PLUS, YYObj_Void)
    PLUSPLUS => (T_PLUSPLUS, YYObj_Void)
    PLUSEQUAL => (T_PLUSEQUAL, YYObj_Void)
    MINUS => (T_MINUS, YYObj_Void)
    MINUSEQUAL => (T_MINUSEQUAL, YYObj_Void)
    STAR => (T_STAR, YYObj_Void)
    STAREQUAL => (T_STAREQUAL, YYObj_Void)
    SLASH => (T_SLASH, YYObj_Void)
    SLASHEQUAL => (T_SLASHEQUAL, YYObj_Void)
    SLASHS => (T_SLASHS, YYObj_Void)
    SLASHSEQUAL => (T_SLASHSEQUAL, YYObj_Void)
    SLASHU => (T_SLASHU, YYObj_Void)
    SLASHUEQUAL => (T_SLASHUEQUAL, YYObj_Void)
    PERCENTS => (T_PERCENTS, YYObj_Void)
    PERCENTSEQUAL => (T_PERCENTSEQUAL, YYObj_Void)
    PERCENTU => (T_PERCENTU, YYObj_Void)
    PERCENTUEQUAL => (T_PERCENTUEQUAL, YYObj_Void)
    AMPERSAND => (T_AMPERSAND, YYObj_Void)
    AMPERSANDEQUAL => (T_AMPERSANDEQUAL, YYObj_Void)
    PIPE => (T_PIPE, YYObj_Void)
    PIPEEQUAL => (T_PIPEEQUAL, YYObj_Void)
    CARET => (T_CARET, YYObj_Void)
    CARETEQUAL => (T_CARETEQUAL, YYObj_Void)
    SHL => (T_SHL, YYObj_Void)
    SHLEQUAL => (T_SHLEQUAL, YYObj_Void)
    SHRS => (T_SHRS, YYObj_Void)
    SHRSEQUAL => (T_SHRSEQUAL, YYObj_Void)
    SHRU => (T_SHRU, YYObj_Void)
    SHRUEQUAL => (T_SHRUEQUAL, YYObj_Void)
    EQUALEQUAL => (T_EQUALEQUAL, YYObj_Void)
    BANGEQUAL => (T_BANGEQUAL, YYObj_Void)
    GT => (T_GT, YYObj_Void)
    GTS => (T_GTS, YYObj_Void)
    GTU => (T_GTU, YYObj_Void)
    LT => (T_LT, YYObj_Void)
    LTS => (T_LTS, YYObj_Void)
    LTU => (T_LTU, YYObj_Void)
    GE => (T_GE, YYObj_Void)
    GES => (T_GES, YYObj_Void)
    GEU => (T_GEU, YYObj_Void)
    LE => (T_LE, YYObj_Void)
    LES => (T_LES, YYObj_Void)
    LEU => (T_LEU, YYObj_Void)
    UNDERSCORE => (T_UNDERSCORE, YYObj_Void)
    FN => (T_FN, YYObj_Void)
    TAG => (T_TAG, YYObj_Void)
    MUT => (T_MUT, YYObj_Void)
    TYPE => (T_TYPE, YYObj_Void)
    REC => (T_REC, YYObj_Void)
    OPEN => (T_OPEN, YYObj_Void)
    NOP => (T_NOP, YYObj_Void)
    UNREACHABLE => (T_UNREACHABLE, YYObj_Void)
    NULL => (T_NULL, YYObj_Void)
    DO => (T_DO, YYObj_Void)
    WHILE => (T_WHILE, YYObj_Void)
    LOOP => (T_LOOP, YYObj_Void)
    IF => (T_IF, YYObj_Void)
    ELSE => (T_ELSE, YYObj_Void)
    CONST => (T_CONST, YYObj_Void)
    LET => (T_LET, YYObj_Void)
    AS => (T_AS, YYObj_Void)
    IS => (T_IS, YYObj_Void)
    BECOME => (T_BECOME, YYObj_Void)
    BR => (T_BR, YYObj_Void)
    BR_IF => (T_BR_IF, YYObj_Void)
    BR_TABLE => (T_BR_TABLE, YYObj_Void)
    RETURN => (T_RETURN, YYObj_Void)
    THROW => (T_THROW, YYObj_Void)
    THROW_REF => (T_THROW_REF, YYObj_Void)
    BR_ON_CAST => (T_BR_ON_CAST, YYObj_Void)
    BR_ON_CAST_FAIL => (T_BR_ON_CAST_FAIL, YYObj_Void)
    BR_ON_NULL => (T_BR_ON_NULL, YYObj_Void)
    BR_ON_NON_NULL => (T_BR_ON_NON_NULL, YYObj_Void)
    TRY => (T_TRY, YYObj_Void)
    TRY_LEGACY => (T_TRY_LEGACY, YYObj_Void)
    CATCH => (T_CATCH, YYObj_Void)
    CONT => (T_CONT, YYObj_Void)
    SUSPEND => (T_SUSPEND, YYObj_Void)
    ON => (T_ON, YYObj_Void)
    DISPATCH => (T_DISPATCH, YYObj_Void)
    MATCH => (T_MATCH, YYObj_Void)
    MEMORY => (T_MEMORY, YYObj_Void)
    DATA => (T_DATA, YYObj_Void)
    TABLE => (T_TABLE, YYObj_Void)
    ELEM => (T_ELEM, YYObj_Void)
    PAGESIZE => (T_PAGESIZE, YYObj_Void)
    SHARED => (T_SHARED, YYObj_Void)
    DESCRIPTOR => (T_DESCRIPTOR, YYObj_Void)
    DESCRIBES => (T_DESCRIBES, YYObj_Void)
    IMPORT => (T_IMPORT, YYObj_Void)
  }
}

fn yy_state_0(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_parse => Shift(yy_state_1)
    T_EOF => Shift(yy_state_2)
    _ => Error
  }
}

fn yy_state_1(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

fn yy_state_2(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_parse, yy_action_0)
}

fn[T] yy_parse(
  tokens : Array[(Token, Position, Position)],
  start : YYState,
  return_ : (YYObj) -> T,
  initial_pos? : Position,
) -> T raise ParseError {
  let mut cursor = 0
  let mut state_stack : @list.List[YYState] = @list.cons(start, @list.empty())
  let data_stack : Array[(YYObj, Position, Position)] = []
  let mut last_pos = initial_pos.unwrap_or(tokens[0].1)
  let mut state = start
  let mut lookahead : Option[(YYSymbol, (YYObj, Position, Position), Token?)] = None
  let mut last_shifted_state_stack = state_stack
  while true {
    let decision = match state(EOI) {
      ReduceNoLookahead(_) | Accept as t => t
      _ => {
        match lookahead {
          Some(la) => state(la.0)
          None => {
            if cursor < tokens.length() {
              let (token, start_pos, end_pos) = tokens[cursor]
              cursor += 1
              let (symbol, data) = yy_input(token, start_pos, end_pos)
              lookahead = Some((symbol, (data, start_pos, end_pos), Some(token)))
              state(symbol)
            } else {
              lookahead = Some((EOI, (YYObj_Void, last_pos, last_pos), None))
              state(EOI)
            }
          }
        }
      }
    }
    match decision {
      Accept => return return_(data_stack.unsafe_pop().0)
      Shift(next_state) => {
        guard lookahead is Some(la)
        data_stack.push(la.1)
        state_stack = @list.cons(next_state, state_stack)
        last_shifted_state_stack = state_stack
        state = next_state
        last_pos = la.1.2
        lookahead = None
      }
      Reduce(count, symbol, action)
      | ReduceNoLookahead(count, symbol, action) => {
        for count = count, symbol = symbol, action = action {
          let args = data_stack[data_stack.length() - count:]
          let data = action(last_pos, args)
          let (start_pos, end_pos) = if args.length() == 0 {
            (last_pos, last_pos)
          } else {
            (args[0].1, args[args.length() - 1].2)
          }
          for _ in 0..<count {
            ignore(data_stack.unsafe_pop())
            state_stack = state_stack.unsafe_tail()
          }
          state = state_stack.unsafe_head()
          data_stack.push((data, start_pos, end_pos))
          match state(symbol) {
            Accept => return return_(data_stack.unsafe_pop().0)
            Shift(next_state) => {
              state_stack = @list.cons(next_state, state_stack)
              state = next_state
              break ()
            }
            Reduce(count, symbol, action)
            | ReduceNoLookahead(count, symbol, action) => continue count, symbol, action
            _ => panic()
          }
        }
      }
      Error => {
        let (_, (_, start_pos, end_pos), token) = lookahead.unwrap()
        error(last_shifted_state_stack, token, (start_pos, end_pos))
      }
    }
  }
  panic()
}

fn error(stack : @list.List[YYState], token : Token?, loc : (Position, Position)) -> Unit raise ParseError {
  let expected = []
  fn try_add(symbol : YYSymbol, kind : TokenKind) {
    fn go(stack : @list.List[YYState]) {
      match stack {
        Empty => ()
        More(state, ..) => {
          match state(symbol) {
            Accept | Shift(_) => expected.push(kind)
            Reduce(count, symbol, _) | ReduceNoLookahead(count, symbol, _) => {
              fn inner_go(stack : @list.List[YYState], count, symbol) {
                let stack = stack.drop(count)
                guard stack is More(state, ..)
                match state(symbol) {
                  Shift(state) => go(@list.cons(state, stack))
                  Reduce(count, symbol, _) | ReduceNoLookahead(count, symbol, _) => inner_go(stack, count, symbol)
                  _ => panic()
                }
              }
              inner_go(stack, count, symbol)
            }
            Error => ()
          }
        }
      }
    }
    go(stack)
  }
  for term in ([(T_IDENT, TK_IDENT), (T_INT, TK_INT), (T_FLOAT, TK_FLOAT), (T_STRING, TK_STRING), (T_CHAR, TK_CHAR), (T_EOF, TK_EOF), (T_INF, TK_INF), (T_NAN, TK_NAN), (T_SEMI, TK_SEMI), (T_SHARP, TK_SHARP), (T_QUESTIONMARK, TK_QUESTIONMARK), (T_LPAREN, TK_LPAREN), (T_RPAREN, TK_RPAREN), (T_LBRACE, TK_LBRACE), (T_RBRACE, TK_RBRACE), (T_LBRACKET, TK_LBRACKET), (T_RBRACKET, TK_RBRACKET), (T_COMMA, TK_COMMA), (T_COLON, TK_COLON), (T_COLONCOLON, TK_COLONCOLON), (T_ARROW, TK_ARROW), (T_FATARROW, TK_FATARROW), (T_EQUAL, TK_EQUAL), (T_COLONEQUAL, TK_COLONEQUAL), (T_AT, TK_AT), (T_QUOTE, TK_QUOTE), (T_DOT, TK_DOT), (T_DOTDOT, TK_DOTDOT), (T_BANG, TK_BANG), (T_PLUS, TK_PLUS), (T_PLUSPLUS, TK_PLUSPLUS), (T_PLUSEQUAL, TK_PLUSEQUAL), (T_MINUS, TK_MINUS), (T_MINUSEQUAL, TK_MINUSEQUAL), (T_STAR, TK_STAR), (T_STAREQUAL, TK_STAREQUAL), (T_SLASH, TK_SLASH), (T_SLASHEQUAL, TK_SLASHEQUAL), (T_SLASHS, TK_SLASHS), (T_SLASHSEQUAL, TK_SLASHSEQUAL), (T_SLASHU, TK_SLASHU), (T_SLASHUEQUAL, TK_SLASHUEQUAL), (T_PERCENTS, TK_PERCENTS), (T_PERCENTSEQUAL, TK_PERCENTSEQUAL), (T_PERCENTU, TK_PERCENTU), (T_PERCENTUEQUAL, TK_PERCENTUEQUAL), (T_AMPERSAND, TK_AMPERSAND), (T_AMPERSANDEQUAL, TK_AMPERSANDEQUAL), (T_PIPE, TK_PIPE), (T_PIPEEQUAL, TK_PIPEEQUAL), (T_CARET, TK_CARET), (T_CARETEQUAL, TK_CARETEQUAL), (T_SHL, TK_SHL), (T_SHLEQUAL, TK_SHLEQUAL), (T_SHRS, TK_SHRS), (T_SHRSEQUAL, TK_SHRSEQUAL), (T_SHRU, TK_SHRU), (T_SHRUEQUAL, TK_SHRUEQUAL), (T_EQUALEQUAL, TK_EQUALEQUAL), (T_BANGEQUAL, TK_BANGEQUAL), (T_GT, TK_GT), (T_GTS, TK_GTS), (T_GTU, TK_GTU), (T_LT, TK_LT), (T_LTS, TK_LTS), (T_LTU, TK_LTU), (T_GE, TK_GE), (T_GES, TK_GES), (T_GEU, TK_GEU), (T_LE, TK_LE), (T_LES, TK_LES), (T_LEU, TK_LEU), (T_UNDERSCORE, TK_UNDERSCORE), (T_FN, TK_FN), (T_TAG, TK_TAG), (T_MUT, TK_MUT), (T_TYPE, TK_TYPE), (T_REC, TK_REC), (T_OPEN, TK_OPEN), (T_NOP, TK_NOP), (T_UNREACHABLE, TK_UNREACHABLE), (T_NULL, TK_NULL), (T_DO, TK_DO), (T_WHILE, TK_WHILE), (T_LOOP, TK_LOOP), (T_IF, TK_IF), (T_ELSE, TK_ELSE), (T_CONST, TK_CONST), (T_LET, TK_LET), (T_AS, TK_AS), (T_IS, TK_IS), (T_BECOME, TK_BECOME), (T_BR, TK_BR), (T_BR_IF, TK_BR_IF), (T_BR_TABLE, TK_BR_TABLE), (T_RETURN, TK_RETURN), (T_THROW, TK_THROW), (T_THROW_REF, TK_THROW_REF), (T_BR_ON_CAST, TK_BR_ON_CAST), (T_BR_ON_CAST_FAIL, TK_BR_ON_CAST_FAIL), (T_BR_ON_NULL, TK_BR_ON_NULL), (T_BR_ON_NON_NULL, TK_BR_ON_NON_NULL), (T_TRY, TK_TRY), (T_TRY_LEGACY, TK_TRY_LEGACY), (T_CATCH, TK_CATCH), (T_CONT, TK_CONT), (T_SUSPEND, TK_SUSPEND), (T_ON, TK_ON), (T_DISPATCH, TK_DISPATCH), (T_MATCH, TK_MATCH), (T_MEMORY, TK_MEMORY), (T_DATA, TK_DATA), (T_TABLE, TK_TABLE), (T_ELEM, TK_ELEM), (T_PAGESIZE, TK_PAGESIZE), (T_SHARED, TK_SHARED), (T_DESCRIPTOR, TK_DESCRIPTOR), (T_DESCRIBES, TK_DESCRIBES), (T_IMPORT, TK_IMPORT)] : Array[(YYSymbol, TokenKind)]) {
    try_add(term.0, term.1)
  }
  match token {
    None => raise UnexpectedEndOfInput(loc.1, expected)
    Some(token) => raise UnexpectedToken(token, loc, expected)
  }
}

pub fn parse(tokens : Array[(Token, Position, Position)], initial_pos? : Position) -> Unit raise ParseError {
  yy_parse(
    tokens,
    yy_state_0,
    (it) => {
      guard it is YYObj_Unit(result)
      result
    },
    initial_pos?,
  )
}
