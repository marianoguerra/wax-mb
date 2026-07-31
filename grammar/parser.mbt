
pub suberror ParseError {
  UnexpectedToken(Token, (Position, Position), Array[TokenKind])
  UnexpectedEndOfInput(Position, Array[TokenKind])
}

type YYObj = Error

priv suberror YYObj_Void

priv suberror YYObj_Int {
  YYObj_Int(Int)
}

priv suberror YYObj_Body_Location_ {
  YYObj_Body_Location_(Body[Location])
}

priv suberror YYObj_Bool {
  YYObj_Bool(Bool)
}

priv suberror YYObj_Char {
  YYObj_Char(Char)
}

priv suberror YYObj_Cond {
  YYObj_Cond(Cond)
}

priv suberror YYObj_Array_Cond_ {
  YYObj_Array_Cond_(Array[Cond])
}

priv suberror YYObj_Array_Catch_ {
  YYObj_Array_Catch_(Array[Catch])
}

priv suberror YYObj_Array_Instr_Location__ {
  YYObj_Array_Instr_Location__(Array[Instr[Location]])
}

priv suberror YYObj_Array_RawStmt_ {
  YYObj_Array_RawStmt_(Array[RawStmt])
}

priv suberror YYObj_Array_ValType_ {
  YYObj_Array_ValType_(Array[ValType])
}

priv suberror YYObj_Array_OnClause_ {
  YYObj_Array_OnClause_(Array[OnClause])
}

priv suberror YYObj_Array_RawField_ {
  YYObj_Array_RawField_(Array[RawField])
}

priv suberror YYObj_Array_Annotated_String__Location__ {
  YYObj_Array_Annotated_String__Location__(Array[Annotated[String, Location]])
}

priv suberror YYObj_Array_Annotated__ast_ImportDecl__Location__ {
  YYObj_Array_Annotated__ast_ImportDecl__Location__(Array[Annotated[@ast.ImportDecl, Location]])
}

priv suberror YYObj_Array_Annotated__Ident__SubType___Location__ {
  YYObj_Array_Annotated__Ident__SubType___Location__(Array[Annotated[(Ident, SubType), Location]])
}

priv suberror YYObj_Array_Annotated__Ident__FieldType___Location__ {
  YYObj_Array_Annotated__Ident__FieldType___Location__(Array[Annotated[(Ident, FieldType), Location]])
}

priv suberror YYObj_Array_Annotated__Ident___ValType___Location__ {
  YYObj_Array_Annotated__Ident___ValType___Location__(Array[Annotated[(Ident?, ValType), Location]])
}

priv suberror YYObj_Array_Attribute_ {
  YYObj_Array_Attribute_(Array[Attribute])
}

priv suberror YYObj_Array_DataRunItem_ {
  YYObj_Array_DataRunItem_(Array[DataRunItem])
}

priv suberror YYObj_Array_TryCatchArm_Location__ {
  YYObj_Array_TryCatchArm_Location__(Array[TryCatchArm[Location]])
}

priv suberror YYObj_Array__ast_MemData_Location__ {
  YYObj_Array__ast_MemData_Location__(Array[@ast.MemData[Location]])
}

priv suberror YYObj_Array__ast_DataElem_ {
  YYObj_Array__ast_DataElem_(Array[@ast.DataElem])
}

priv suberror YYObj_Array__Ident__Int__ {
  YYObj_Array__Ident__Int__(Array[(Ident, Int)])
}

priv suberror YYObj_Array__Ident__Body_Location___ {
  YYObj_Array__Ident__Body_Location___(Array[(Ident, Body[Location])])
}

priv suberror YYObj_Array__Ident__Instr_Location____ {
  YYObj_Array__Ident__Instr_Location____(Array[(Ident, Instr[Location]?)])
}

priv suberror YYObj_Array__MatchPattern__Body_Location___ {
  YYObj_Array__MatchPattern__Body_Location___(Array[(MatchPattern, Body[Location])])
}

priv suberror YYObj_Array__Ident___ValType___ {
  YYObj_Array__Ident___ValType___(Array[(Ident?, ValType?)])
}

priv suberror YYObj_Catch {
  YYObj_Catch(Catch)
}

priv suberror YYObj_Ident {
  YYObj_Ident(Ident)
}

priv suberror YYObj_Instr_Location_ {
  YYObj_Instr_Location_(Instr[Location])
}

priv suberror YYObj_Option_Int_ {
  YYObj_Option_Int_(Option[Int])
}

priv suberror YYObj_Option_Body_Location__ {
  YYObj_Option_Body_Location__(Option[Body[Location]])
}

priv suberror YYObj_Option_Array_RawStmt__ {
  YYObj_Option_Array_RawStmt__(Option[Array[RawStmt]])
}

priv suberror YYObj_Option_Array_ValType__ {
  YYObj_Option_Array_ValType__(Option[Array[ValType]])
}

priv suberror YYObj_Option_Ident_ {
  YYObj_Option_Ident_(Option[Ident])
}

priv suberror YYObj_Option_Instr_Location__ {
  YYObj_Option_Instr_Location__(Option[Instr[Location]])
}

priv suberror YYObj_Option_String_ {
  YYObj_Option_String_(Option[String])
}

priv suberror YYObj_Option_UInt64_ {
  YYObj_Option_UInt64_(Option[UInt64])
}

priv suberror YYObj_Option_ValType_ {
  YYObj_Option_ValType_(Option[ValType])
}

priv suberror YYObj_Option_FuncType_ {
  YYObj_Option_FuncType_(Option[FuncType])
}

priv suberror YYObj_Option_AddressType_ {
  YYObj_Option_AddressType_(Option[AddressType])
}

priv suberror YYObj_Option_TryCatchArm_Location__ {
  YYObj_Option_TryCatchArm_Location__(Option[TryCatchArm[Location]])
}

priv suberror YYObj_Option__Bool__Ident__ {
  YYObj_Option__Bool__Ident__(Option[(Bool, Ident)])
}

priv suberror YYObj_Option__UInt64__UInt64___ {
  YYObj_Option__UInt64__UInt64___(Option[(UInt64, UInt64?)])
}

priv suberror YYObj_String {
  YYObj_String(String)
}

priv suberror YYObj_UInt64 {
  YYObj_UInt64(UInt64)
}

priv suberror YYObj_RawStmt {
  YYObj_RawStmt(RawStmt)
}

priv suberror YYObj_RefType {
  YYObj_RefType(RefType)
}

priv suberror YYObj_ValType {
  YYObj_ValType(ValType)
}

priv suberror YYObj_CastType {
  YYObj_CastType(CastType)
}

priv suberror YYObj_CompType {
  YYObj_CompType(CompType)
}

priv suberror YYObj_FuncType {
  YYObj_FuncType(FuncType)
}

priv suberror YYObj_HeapType {
  YYObj_HeapType(HeapType)
}

priv suberror YYObj_OnClause {
  YYObj_OnClause(OnClause)
}

priv suberror YYObj_RawField {
  YYObj_RawField(RawField)
}

priv suberror YYObj_Annotated_Array_Annotated__Ident__SubType___Location____Location_ {
  YYObj_Annotated_Array_Annotated__Ident__SubType___Location____Location_(Annotated[Array[Annotated[(Ident, SubType), Location]], Location])
}

priv suberror YYObj_Annotated_String__Location_ {
  YYObj_Annotated_String__Location_(Annotated[String, Location])
}

priv suberror YYObj_Annotated__ast_BinOp__Location_ {
  YYObj_Annotated__ast_BinOp__Location_(Annotated[@ast.BinOp, Location])
}

priv suberror YYObj_Annotated__ast_ImportDecl__Location_ {
  YYObj_Annotated__ast_ImportDecl__Location_(Annotated[@ast.ImportDecl, Location])
}

priv suberror YYObj_Annotated__Ident__SubType___Location_ {
  YYObj_Annotated__Ident__SubType___Location_(Annotated[(Ident, SubType), Location])
}

priv suberror YYObj_Annotated__Ident__FieldType___Location_ {
  YYObj_Annotated__Ident__FieldType___Location_(Annotated[(Ident, FieldType), Location])
}

priv suberror YYObj_Annotated__Ident___ValType___Location_ {
  YYObj_Annotated__Ident___ValType___Location_(Annotated[(Ident?, ValType), Location])
}

priv suberror YYObj_Attribute {
  YYObj_Attribute(Attribute)
}

priv suberror YYObj_FieldType {
  YYObj_FieldType(FieldType)
}

priv suberror YYObj_LocString {
  YYObj_LocString(LocString)
}

priv suberror YYObj_AddressType {
  YYObj_AddressType(AddressType)
}

priv suberror YYObj_DataRunItem {
  YYObj_DataRunItem(DataRunItem)
}

priv suberror YYObj_StorageType {
  YYObj_StorageType(StorageType)
}

priv suberror YYObj_TryCatchArm_Location_ {
  YYObj_TryCatchArm_Location_(TryCatchArm[Location])
}

priv suberror YYObj_MatchPattern {
  YYObj_MatchPattern(MatchPattern)
}

priv suberror YYObj_LocatedFields {
  YYObj_LocatedFields(LocatedFields)
}

priv suberror YYObj__ast_MemData_Location_ {
  YYObj__ast_MemData_Location_(@ast.MemData[Location])
}

priv suberror YYObj__ast_DataElem {
  YYObj__ast_DataElem(@ast.DataElem)
}

priv suberror YYObj__ast_LocModule {
  YYObj__ast_LocModule(@ast.LocModule)
}

priv suberror YYObj__wasm_types_CmpOp {
  YYObj__wasm_types_CmpOp(@wasm_types.CmpOp)
}

priv suberror YYObj_Ident_ {
  YYObj_Ident_(Ident?)
}

priv suberror YYObj_FuncType_ {
  YYObj_FuncType_(FuncType?)
}

priv suberror YYObj_Annotated_Cond__Location__ {
  YYObj_Annotated_Cond__Location__(Annotated[Cond, Location]?)
}

priv suberror YYObj__Bool__Ident_ {
  YYObj__Bool__Ident_((Bool, Ident))
}

priv suberror YYObj__Array_Ident___Ident_ {
  YYObj__Array_Ident___Ident_((Array[Ident], Ident))
}

priv suberror YYObj__Ident__Int_ {
  YYObj__Ident__Int_((Ident, Int))
}

priv suberror YYObj__Ident__Body_Location__ {
  YYObj__Ident__Body_Location__((Ident, Body[Location]))
}

priv suberror YYObj__Ident___ast_ImportKind_ {
  YYObj__Ident___ast_ImportKind_((Ident, @ast.ImportKind))
}

priv suberror YYObj__Ident__Instr_Location___ {
  YYObj__Ident__Instr_Location___((Ident, Instr[Location]?))
}

priv suberror YYObj__UInt64__UInt64__ {
  YYObj__UInt64__UInt64__((UInt64, UInt64?))
}

priv suberror YYObj__MatchPattern__Body_Location__ {
  YYObj__MatchPattern__Body_Location__((MatchPattern, Body[Location]))
}

priv suberror YYObj__Ident___Array_Instr_Location___ {
  YYObj__Ident___Array_Instr_Location___((Ident?, Array[Instr[Location]]))
}

priv suberror YYObj__Ident___ValType__ {
  YYObj__Ident___ValType__((Ident?, ValType?))
}

priv suberror YYObj___Position__Position___HintSetter_ {
  YYObj___Position__Position___HintSetter_(((Position, Position), HintSetter))
}

priv suberror YYObj__Ident__Ident___FuncType__ {
  YYObj__Ident__Ident___FuncType__((Ident, Ident?, FuncType?))
}

priv suberror YYObj__Ident__Ident___FuncType___Bool_ {
  YYObj__Ident__Ident___FuncType___Bool_((Ident, Ident?, FuncType?, Bool))
}

priv suberror YYObj__Attributes_____Annotated_ModuleField_Location___Location_ {
  YYObj__Attributes_____Annotated_ModuleField_Location___Location_((Attributes) -> Annotated[ModuleField[Location], Location])
}

priv suberror YYObj__Ident______InstrDesc_Location_ {
  YYObj__Ident______InstrDesc_Location_((Ident?) -> InstrDesc[Location])
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
  NT_ident
  NT_ident_or_keyword
  NT_label_name
  NT_label
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
  NT_supertype_clause
  NT_describes_clause
  NT_descriptor_clause
  NT_rectype
  NT_attribute_expression
  NT_attribute_name
  NT_attribute_guard
  NT_attribute
  NT_hint_attr
  NT_hint_target
  NT_target_fraction
  NT_inner_attribute
  NT_simple_pattern
  NT_function_parameter
  NT_parameter_list
  NT_result_arrow
  NT_function_type_as
  NT_function_type_definition
  NT_function_name
  NT_optional_function_type
  NT_fundecl
  NT_fundecl_type
  NT_func
  NT_tag_name
  NT_tag_signature
  NT_tag_type
  NT_block_label
  NT_labelled
  NT_block_param_type
  NT_parameter_types
  NT_block_type
  NT_block
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
  NT_if_block_type
  NT_else_branch
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
  NT_let_pattern
  NT_type_annot
  NT_let_pattern_
  NT_compound_assign_op
  NT_hinted_statement
  NT_statement
  NT_let_init
  NT_statement_list
  NT_raw_statement_list
  NT_semi_then_statements
  NT_cond_stmt
  NT_globalmut
  NT_constant_expression
  NT_global
  NT_tag_def
  NT_definition
  NT_address_type
  NT_mem_limits
  NT_limit_max
  NT_data_name
  NT_data_init
  NT_data_element
  NT_data_run_item
  NT_data_number
  NT_data_sign
  NT_raw_number
  NT_data_item
  NT_loption_data_init
  NT_mem_pagesize
  NT_memory
  NT_data
  NT_table
  NT_table_init
  NT_elem
  NT_module_field
  NT_braced_fields
  NT_import_item
  NT_import_kind_decl
  NT_condition
  NT_condition_literal
  NT_condition_relop
  NT_parse
  NT_raw_parse
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
  NT_sep_trailing_COMMA_let_pattern_
  NT_option_semi_then_statements_
  NT_sep_trailing_COMMA_data_run_item_
  NT_sep_trailing_COMMA_data_number_
  NT_boption_SHARED_
  NT_list_of_data_item_
  NT_list_of_attribute_
  NT_semi_list_import_item_
  NT_semi_list_module_field_
  NT_sep_trailing_COMMA_condition_
  NT_non_empty_sep_trailing_COMMA_structure_type_field_
  NT_non_empty_sep_trailing_COMMA_hint_target_
  NT_non_empty_sep_trailing_COMMA_function_parameter_
  NT_non_empty_sep_trailing_COMMA_block_param_type_
  NT_non_empty_sep_trailing_COMMA_on_clause_
  NT_non_empty_sep_trailing_COMMA_structure_field_
  NT_non_empty_sep_trailing_COMMA_catch_
  NT_non_empty_sep_trailing_COMMA_expression_
  NT_non_empty_sep_trailing_COMMA_argument_
  NT_non_empty_sep_trailing_COMMA_let_pattern_
  NT_non_empty_sep_trailing_COMMA_data_run_item_
  NT_non_empty_sep_trailing_COMMA_data_number_
  NT_non_empty_sep_trailing_COMMA_condition_
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
// 1608|    raw_parse { lower_fields($1) }
fn yy_action_0(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_RawField_(_dollar1)
  YYObj__ast_LocModule({();  lower_fields(_dollar1) })
}

// file:///./parser.mbty
// 1508|    "#" "[" IF "(" condition ")" "]" braced_fields { FIf($sloc, $5, $8) }
fn yy_action_1(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[4].0 is YYObj_Cond(_dollar5)
  guard _args[7].0 is YYObj_LocatedFields(_dollar8)
  YYObj_RawField({();  FIf((_symbol_start_pos, _end_pos), _dollar5, _dollar8) })
}

// file:///./parser.mbty
// 1509|    "#" "[" ELSE "]" braced_fields { FElse($sloc, $5) }
fn yy_action_2(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[4].0 is YYObj_LocatedFields(_dollar5)
  YYObj_RawField({();  FElse((_symbol_start_pos, _end_pos), _dollar5) })
}

// file:///./parser.mbty
// 1516|    "{" semi_list(module_field) "}" { annot($sloc, lower_fields($2)) }
fn yy_action_3(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[1].0 is YYObj_Array_RawField_(_dollar2)
  YYObj_LocatedFields({();  annot((_symbol_start_pos, _end_pos), lower_fields(_dollar2)) })
}

// file:///./parser.mbty
// 422|    REC "{" list_of(type_definition) "}" { annot($loc($1), $3) }
fn yy_action_4(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _start_pos_of_item0 = _args[0].1
  let _end_pos_of_item0 = _args[0].2
  guard _args[2].0 is YYObj_Array_Annotated__Ident__SubType___Location__(_dollar3)
  YYObj_Annotated_Array_Annotated__Ident__SubType___Location____Location_({();  annot((_start_pos_of_item0, _end_pos_of_item0), _dollar3) })
}

// file:///./parser.mbty
// 395|    TYPE type_name option(supertype_clause) "=" boption(OPEN)
// 396|    ioption(describes_clause) ioption(descriptor_clause) composite_type ";" {
// 397|      annot($sloc, ($2, {
// 398|        typ: $8,
// 399|        supertype: $3,
// 400|        // `open` is the spelling; the AST stores the negation, because
// 401|        // final-by-default is what WebAssembly encodes.
// 402|        final_: !($5),
// 403|        descriptor: $7,
// 404|        describes: $6,
// 405|      }))
// 406|    }
fn yy_action_5(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_6(_args[4].2, _args[5:5])
  let _sub_action_1_result = yy_action_7(_args[4].2, _args[5:5])
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[1].0 is YYObj_Ident(_dollar2)
  guard _args[5].0 is YYObj_CompType(_dollar8)
  guard _args[2].0 is YYObj_Option_Ident_(_dollar3)
  guard _args[4].0 is YYObj_Bool(_dollar5)
  guard _sub_action_1_result is YYObj_Option_Ident_(_dollar7)
  guard _sub_action_0_result is YYObj_Option_Ident_(_dollar6)
  YYObj_Annotated__Ident__SubType___Location_({(); 
      annot((_symbol_start_pos, _end_pos), (_dollar2, {
        typ: _dollar8,
        supertype: _dollar3,
        // `open` is the spelling; the AST stores the negation, because
        // final-by-default is what WebAssembly encodes.
        final_: !(_dollar5),
        descriptor: _dollar7,
        describes: _dollar6,
      }))
    })
}

// file:///./parser.mbty
// 395|    TYPE type_name option(supertype_clause) "=" boption(OPEN)
// 396|    ioption(describes_clause) ioption(descriptor_clause) composite_type ";" {
// 397|      annot($sloc, ($2, {
// 398|        typ: $8,
// 399|        supertype: $3,
// 400|        // `open` is the spelling; the AST stores the negation, because
// 401|        // final-by-default is what WebAssembly encodes.
// 402|        final_: !($5),
// 403|        descriptor: $7,
// 404|        describes: $6,
// 405|      }))
// 406|    }
fn yy_action_8(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_6(_args[4].2, _args[5:5])
  let _sub_action_1_result = yy_action_9(_args[4].2, _args[5:6])
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[1].0 is YYObj_Ident(_dollar2)
  guard _args[6].0 is YYObj_CompType(_dollar8)
  guard _args[2].0 is YYObj_Option_Ident_(_dollar3)
  guard _args[4].0 is YYObj_Bool(_dollar5)
  guard _sub_action_1_result is YYObj_Option_Ident_(_dollar7)
  guard _sub_action_0_result is YYObj_Option_Ident_(_dollar6)
  YYObj_Annotated__Ident__SubType___Location_({(); 
      annot((_symbol_start_pos, _end_pos), (_dollar2, {
        typ: _dollar8,
        supertype: _dollar3,
        // `open` is the spelling; the AST stores the negation, because
        // final-by-default is what WebAssembly encodes.
        final_: !(_dollar5),
        descriptor: _dollar7,
        describes: _dollar6,
      }))
    })
}

// file:///./stdlib.mbty
// 9|    { None }
fn yy_action_6(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Option_Ident_({();  None })
}

// file:///./parser.mbty
// 395|    TYPE type_name option(supertype_clause) "=" boption(OPEN)
// 396|    ioption(describes_clause) ioption(descriptor_clause) composite_type ";" {
// 397|      annot($sloc, ($2, {
// 398|        typ: $8,
// 399|        supertype: $3,
// 400|        // `open` is the spelling; the AST stores the negation, because
// 401|        // final-by-default is what WebAssembly encodes.
// 402|        final_: !($5),
// 403|        descriptor: $7,
// 404|        describes: $6,
// 405|      }))
// 406|    }
fn yy_action_10(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_11(_args[4].2, _args[5:6])
  let _sub_action_1_result = yy_action_7(_args[5].2, _args[6:6])
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[1].0 is YYObj_Ident(_dollar2)
  guard _args[6].0 is YYObj_CompType(_dollar8)
  guard _args[2].0 is YYObj_Option_Ident_(_dollar3)
  guard _args[4].0 is YYObj_Bool(_dollar5)
  guard _sub_action_1_result is YYObj_Option_Ident_(_dollar7)
  guard _sub_action_0_result is YYObj_Option_Ident_(_dollar6)
  YYObj_Annotated__Ident__SubType___Location_({(); 
      annot((_symbol_start_pos, _end_pos), (_dollar2, {
        typ: _dollar8,
        supertype: _dollar3,
        // `open` is the spelling; the AST stores the negation, because
        // final-by-default is what WebAssembly encodes.
        final_: !(_dollar5),
        descriptor: _dollar7,
        describes: _dollar6,
      }))
    })
}

// file:///./stdlib.mbty
// 9|    { None }
fn yy_action_7(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Option_Ident_({();  None })
}

// file:///./parser.mbty
// 371|    "{" ".." "}" { [@ast.splice_field(loc_of($sloc))] }
fn yy_action_12(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Array_Annotated__Ident__FieldType___Location__({();  [@ast.splice_field(loc_of((_symbol_start_pos, _end_pos)))] })
}

// file:///./parser.mbty
// 364|    sep_trailing(",", structure_type_field) { $1 }
fn yy_action_13(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Annotated__Ident__FieldType___Location__(_dollar1)
  YYObj_Array_Annotated__Ident__FieldType___Location__({();  _dollar1 })
}

// file:///./parser.mbty
// 372|    "{" ".." "," structure_type "}" {
// 373|      [@ast.splice_field(loc_of($sloc)), ..$4]
// 374|    }
fn yy_action_14(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[3].0 is YYObj_Array_Annotated__Ident__FieldType___Location__(_dollar4)
  YYObj_Array_Annotated__Ident__FieldType___Location__({(); 
      [@ast.splice_field(loc_of((_symbol_start_pos, _end_pos))), .._dollar4]
    })
}

// file:///./parser.mbty
// 375|    "{" structure_type "}" { $2 }
fn yy_action_15(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_Annotated__Ident__FieldType___Location__(_dollar2)
  YYObj_Array_Annotated__Ident__FieldType___Location__({();  _dollar2 })
}

// file:///./parser.mbty
// 235|    non_empty_sep_trailing(SEP, X) { $1 }
fn yy_action_16(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Annotated__Ident__FieldType___Location__(_dollar1)
  YYObj_Array_Annotated__Ident__FieldType___Location__({();  _dollar1 })
}

// file:///./parser.mbty
// 360|    field_name ":" field_type { annot($sloc, ($1, $3)) }
fn yy_action_17(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[0].0 is YYObj_Ident(_dollar1)
  guard _args[2].0 is YYObj_FieldType(_dollar3)
  YYObj_Annotated__Ident__FieldType___Location_({();  annot((_symbol_start_pos, _end_pos), (_dollar1, _dollar3)) })
}

// file:///./parser.mbty
// 230|    X SEP non_empty_sep_trailing(SEP, X) { [$1, ..$3] }
fn yy_action_18(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Annotated__Ident__FieldType___Location_(_dollar1)
  guard _args[2].0 is YYObj_Array_Annotated__Ident__FieldType___Location__(_dollar3)
  YYObj_Array_Annotated__Ident__FieldType___Location__({();  [_dollar1, .._dollar3] })
}

// file:///./parser.mbty
// 229|    X SEP { [$1] }
fn yy_action_19(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Annotated__Ident__FieldType___Location_(_dollar1)
  YYObj_Array_Annotated__Ident__FieldType___Location__({();  [_dollar1] })
}

// file:///./parser.mbty
// 228|    X { [$1] }
fn yy_action_20(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Annotated__Ident__FieldType___Location_(_dollar1)
  YYObj_Array_Annotated__Ident__FieldType___Location__({();  [_dollar1] })
}

// file:///./parser.mbty
// 234|    { [] }
fn yy_action_21(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Array_Annotated__Ident__FieldType___Location__({();  [] })
}

// file:///./parser.mbty
// 347|    IDENT { storage_type_of($loc($1), $1) }
fn yy_action_22(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _start_pos_of_item0 = _args[0].1
  let _end_pos_of_item0 = _args[0].2
  guard _args[0].0 is YYObj_String(_dollar1)
  YYObj_StorageType({();  storage_type_of((_start_pos_of_item0, _end_pos_of_item0), _dollar1) })
}

// file:///./parser.mbty
// 348|    reference_type { Value(Ref($1)) }
fn yy_action_23(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_RefType(_dollar1)
  YYObj_StorageType({();  Value(Ref(_dollar1)) })
}

// file:///./parser.mbty
// 352|    boption(MUT) storage_type { { mut_: $1, typ: $2 } }
fn yy_action_24(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Bool(_dollar1)
  guard _args[1].0 is YYObj_StorageType(_dollar2)
  YYObj_FieldType({();  { mut_: _dollar1, typ: _dollar2 } })
}

// file:///./parser.mbty
// 379|    "[" field_type "]" { $2 }
fn yy_action_25(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[1].0 is YYObj_FieldType(_dollar2)
  YYObj_FieldType({();  _dollar2 })
}

// file:///./stdlib.mbty
// 20|    X { true }
fn yy_action_26(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Bool({();  true })
}

// file:///./stdlib.mbty
// 19|    { false }
fn yy_action_27(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Bool({();  false })
}

// file:///./parser.mbty
// 383|    structtype { Struct($1) }
fn yy_action_28(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Annotated__Ident__FieldType___Location__(_dollar1)
  YYObj_CompType({();  Struct(_dollar1) })
}

// file:///./parser.mbty
// 384|    function_type_definition { Func($1) }
fn yy_action_29(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_FuncType(_dollar1)
  YYObj_CompType({();  Func(_dollar1) })
}

// file:///./parser.mbty
// 385|    arraytype { Array($1) }
fn yy_action_30(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_FieldType(_dollar1)
  YYObj_CompType({();  Array(_dollar1) })
}

// file:///./parser.mbty
// 387|    CONT type_name { Cont($2) }
fn yy_action_31(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[1].0 is YYObj_Ident(_dollar2)
  YYObj_CompType({();  Cont(_dollar2) })
}

// file:///./parser.mbty
// 395|    TYPE type_name option(supertype_clause) "=" boption(OPEN)
// 396|    ioption(describes_clause) ioption(descriptor_clause) composite_type ";" {
// 397|      annot($sloc, ($2, {
// 398|        typ: $8,
// 399|        supertype: $3,
// 400|        // `open` is the spelling; the AST stores the negation, because
// 401|        // final-by-default is what WebAssembly encodes.
// 402|        final_: !($5),
// 403|        descriptor: $7,
// 404|        describes: $6,
// 405|      }))
// 406|    }
fn yy_action_32(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_11(_args[4].2, _args[5:6])
  let _sub_action_1_result = yy_action_9(_args[5].2, _args[6:7])
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[1].0 is YYObj_Ident(_dollar2)
  guard _args[7].0 is YYObj_CompType(_dollar8)
  guard _args[2].0 is YYObj_Option_Ident_(_dollar3)
  guard _args[4].0 is YYObj_Bool(_dollar5)
  guard _sub_action_1_result is YYObj_Option_Ident_(_dollar7)
  guard _sub_action_0_result is YYObj_Option_Ident_(_dollar6)
  YYObj_Annotated__Ident__SubType___Location_({(); 
      annot((_symbol_start_pos, _end_pos), (_dollar2, {
        typ: _dollar8,
        supertype: _dollar3,
        // `open` is the spelling; the AST stores the negation, because
        // final-by-default is what WebAssembly encodes.
        final_: !(_dollar5),
        descriptor: _dollar7,
        describes: _dollar6,
      }))
    })
}

// file:///./stdlib.mbty
// 10|    X { Some($1) }
fn yy_action_9(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Ident(_dollar1)
  YYObj_Option_Ident_({();  Some(_dollar1) })
}

// file:///./stdlib.mbty
// 10|    X { Some($1) }
fn yy_action_11(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Ident(_dollar1)
  YYObj_Option_Ident_({();  Some(_dollar1) })
}

// file:///./parser.mbty
// 414|    DESCRIBES type_name { $2 }
fn yy_action_33(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[1].0 is YYObj_Ident(_dollar2)
  YYObj_Ident({();  _dollar2 })
}

// file:///./parser.mbty
// 418|    DESCRIPTOR type_name { $2 }
fn yy_action_34(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[1].0 is YYObj_Ident(_dollar2)
  YYObj_Ident({();  _dollar2 })
}

// file:///./parser.mbty
// 574|    FN function_type(TYPE) { $2 }
fn yy_action_35(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[1].0 is YYObj_FuncType(_dollar2)
  YYObj_FuncType({();  _dollar2 })
}

// file:///./parser.mbty
// 560|    "(" parameter_list ")" ioption(result_arrow) {
// 561|      { params: $2, results: $4.unwrap_or([]) }
// 562|    }
fn yy_action_36(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_37(_args[2].2, _args[3:4])
  guard _args[1].0 is YYObj_Array_Annotated__Ident___ValType___Location__(_dollar2)
  guard _sub_action_0_result is YYObj_Option_Array_ValType__(_dollar4)
  YYObj_FuncType({(); 
      { params: _dollar2, results: _dollar4.unwrap_or([]) }
    })
}

// file:///./parser.mbty
// 560|    "(" parameter_list ")" ioption(result_arrow) {
// 561|      { params: $2, results: $4.unwrap_or([]) }
// 562|    }
fn yy_action_38(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_39(_args[2].2, _args[3:3])
  guard _args[1].0 is YYObj_Array_Annotated__Ident___ValType___Location__(_dollar2)
  guard _sub_action_0_result is YYObj_Option_Array_ValType__(_dollar4)
  YYObj_FuncType({(); 
      { params: _dollar2, results: _dollar4.unwrap_or([]) }
    })
}

// file:///./stdlib.mbty
// 20|    X { true }
fn yy_action_40(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Bool({();  true })
}

// file:///./stdlib.mbty
// 19|    { false }
fn yy_action_41(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Bool({();  false })
}

// file:///./parser.mbty
// 410|    ":" type_name { $2 }
fn yy_action_42(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[1].0 is YYObj_Ident(_dollar2)
  YYObj_Ident({();  _dollar2 })
}

// file:///./stdlib.mbty
// 5|    X { Some($1) }
fn yy_action_43(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Ident(_dollar1)
  YYObj_Option_Ident_({();  Some(_dollar1) })
}

// file:///./stdlib.mbty
// 4|    { None }
fn yy_action_44(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Option_Ident_({();  None })
}

// file:///./parser.mbty
// 443|    X list_of(X) { [$1, ..$2] }
fn yy_action_45(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Annotated__Ident__SubType___Location_(_dollar1)
  guard _args[1].0 is YYObj_Array_Annotated__Ident__SubType___Location__(_dollar2)
  YYObj_Array_Annotated__Ident__SubType___Location__({();  [_dollar1, .._dollar2] })
}

// file:///./parser.mbty
// 442|    { [] }
fn yy_action_46(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Array_Annotated__Ident__SubType___Location__({();  [] })
}

// file:///./parser.mbty
// 426|    type_definition { { desc: [$1], info: $1.info } }
fn yy_action_47(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Annotated__Ident__SubType___Location_(_dollar1)
  YYObj_Annotated_Array_Annotated__Ident__SubType___Location____Location_({();  { desc: [_dollar1], info: _dollar1.info } })
}

// file:///./parser.mbty
// 789|    ";" semi_list(X) { $2 }
fn yy_action_48(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_RawField_(_dollar2)
  YYObj_Array_RawField_({();  _dollar2 })
}

// file:///./parser.mbty
// 790|    X semi_list(X) { [$1, ..$2] }
fn yy_action_49(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_RawField(_dollar1)
  guard _args[1].0 is YYObj_Array_RawField_(_dollar2)
  YYObj_Array_RawField_({();  [_dollar1, .._dollar2] })
}

// file:///./parser.mbty
// 788|    { [] }
fn yy_action_50(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Array_RawField_({();  [] })
}

// file:///./parser.mbty
// 511|    "#" "!" "[" IDENT "=" attribute_expression "]" {
// 512|      {
// 513|        attr_name: $4,
// 514|        attr_value: Some($6),
// 515|        attr_guard: None,
// 516|        attr_span: loc_of($sloc),
// 517|      }
// 518|    }
fn yy_action_51(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[3].0 is YYObj_String(_dollar4)
  guard _args[5].0 is YYObj_Instr_Location_(_dollar6)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Attribute({(); 
      {
        attr_name: _dollar4,
        attr_value: Some(_dollar6),
        attr_guard: None,
        attr_span: loc_of((_symbol_start_pos, _end_pos)),
      }
    })
}

// file:///./parser.mbty
// 519|    "#" "!" "[" IDENT "]" {
// 520|      {
// 521|        attr_name: $4,
// 522|        attr_value: None,
// 523|        attr_guard: None,
// 524|        attr_span: loc_of($sloc),
// 525|      }
// 526|    }
fn yy_action_52(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[3].0 is YYObj_String(_dollar4)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Attribute({(); 
      {
        attr_name: _dollar4,
        attr_value: None,
        attr_guard: None,
        attr_span: loc_of((_symbol_start_pos, _end_pos)),
      }
    })
}

// file:///./parser.mbty
// 1499|    rectype { FPlain({ desc: ModuleField::Type($1.desc), info: $1.info }) }
fn yy_action_53(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Annotated_Array_Annotated__Ident__SubType___Location____Location_(_dollar1)
  YYObj_RawField({();  FPlain({ desc: ModuleField::Type(_dollar1.desc), info: _dollar1.info }) })
}

// file:///./parser.mbty
// 1500|    inner_attribute { FPlain(annot($sloc, ModuleField::ModuleAnnotation([$1]))) }
fn yy_action_54(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[0].0 is YYObj_Attribute(_dollar1)
  YYObj_RawField({();  FPlain(annot((_symbol_start_pos, _end_pos), ModuleField::ModuleAnnotation([_dollar1]))) })
}

// file:///./parser.mbty
// 609|    fundecl block {
// 610|      let (name, typ, sign, exact) = $1
// 611|      let body = $2
// 612|      if exact {
// 613|        record_error(
// 614|          loc_of($sloc),
// 615|          "A function definition is always exact; the '!' marker is only allowed on an (imported) function declaration.",
// 616|        )
// 617|      }
// 618|      fn(attributes) {
// 619|        annot($sloc, ModuleField::Func(name~, typ~, sign~, body~, attributes~))
// 620|      }
// 621|    }
fn yy_action_55(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj__Ident__Ident___FuncType___Bool_(_dollar1)
  guard _args[1].0 is YYObj__Ident___Array_Instr_Location___(_dollar2)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj__Attributes_____Annotated_ModuleField_Location___Location_({(); 
      let (name, typ, sign, exact) = _dollar1
      let body = _dollar2
      if exact {
        record_error(
          loc_of((_symbol_start_pos, _end_pos)),
          "A function definition is always exact; the '!' marker is only allowed on an (imported) function declaration.",
        )
      }
      fn(attributes) {
        annot((_symbol_start_pos, _end_pos), ModuleField::Func(name~, typ~, sign~, body~, attributes~))
      }
    })
}

// file:///./parser.mbty
// 675|    block_label "{" statement_list "}" { ($1, $3) }
fn yy_action_56(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Ident_(_dollar1)
  guard _args[2].0 is YYObj_Array_Instr_Location__(_dollar3)
  YYObj__Ident___Array_Instr_Location___({();  (_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 1264|    globalmut ident ioption(type_annot) "=" constant_expression ";" {
// 1265|      let (mut_, name, typ, def) = ($1, $2, $3, $5)
// 1266|      fn(attributes) {
// 1267|        annot($sloc, ModuleField::Global(name~, mut_~, typ~, def~, attributes~))
// 1268|      }
// 1269|    }
fn yy_action_57(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_58(_args[1].2, _args[2:2])
  guard _args[0].0 is YYObj_Bool(_dollar1)
  guard _args[1].0 is YYObj_Ident(_dollar2)
  guard _sub_action_0_result is YYObj_Option_ValType_(_dollar3)
  guard _args[3].0 is YYObj_Instr_Location_(_dollar5)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj__Attributes_____Annotated_ModuleField_Location___Location_({(); 
      let (mut_, name, typ, def) = (_dollar1, _dollar2, _dollar3, _dollar5)
      fn(attributes) {
        annot((_symbol_start_pos, _end_pos), ModuleField::Global(name~, mut_~, typ~, def~, attributes~))
      }
    })
}

// file:///./parser.mbty
// 1264|    globalmut ident ioption(type_annot) "=" constant_expression ";" {
// 1265|      let (mut_, name, typ, def) = ($1, $2, $3, $5)
// 1266|      fn(attributes) {
// 1267|        annot($sloc, ModuleField::Global(name~, mut_~, typ~, def~, attributes~))
// 1268|      }
// 1269|    }
fn yy_action_59(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_60(_args[1].2, _args[2:3])
  guard _args[0].0 is YYObj_Bool(_dollar1)
  guard _args[1].0 is YYObj_Ident(_dollar2)
  guard _sub_action_0_result is YYObj_Option_ValType_(_dollar3)
  guard _args[4].0 is YYObj_Instr_Location_(_dollar5)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj__Attributes_____Annotated_ModuleField_Location___Location_({(); 
      let (mut_, name, typ, def) = (_dollar1, _dollar2, _dollar3, _dollar5)
      fn(attributes) {
        annot((_symbol_start_pos, _end_pos), ModuleField::Global(name~, mut_~, typ~, def~, attributes~))
      }
    })
}

// file:///./parser.mbty
// 1273|    tag_signature ";" {
// 1274|      let (name, typ, sign) = $1
// 1275|      fn(attributes) {
// 1276|        annot($sloc, ModuleField::Tag(name~, typ~, sign~, attributes~))
// 1277|      }
// 1278|    }
fn yy_action_61(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj__Ident__Ident___FuncType__(_dollar1)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj__Attributes_____Annotated_ModuleField_Location___Location_({(); 
      let (name, typ, sign) = _dollar1
      fn(attributes) {
        annot((_symbol_start_pos, _end_pos), ModuleField::Tag(name~, typ~, sign~, attributes~))
      }
    })
}

// file:///./parser.mbty
// 1282|    func { $1 }
fn yy_action_62(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj__Attributes_____Annotated_ModuleField_Location___Location_(_dollar1)
  YYObj__Attributes_____Annotated_ModuleField_Location___Location_({();  _dollar1 })
}

// file:///./parser.mbty
// 1283|    global { $1 }
fn yy_action_63(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj__Attributes_____Annotated_ModuleField_Location___Location_(_dollar1)
  YYObj__Attributes_____Annotated_ModuleField_Location___Location_({();  _dollar1 })
}

// file:///./parser.mbty
// 1284|    memory { $1 }
fn yy_action_64(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj__Attributes_____Annotated_ModuleField_Location___Location_(_dollar1)
  YYObj__Attributes_____Annotated_ModuleField_Location___Location_({();  _dollar1 })
}

// file:///./parser.mbty
// 1285|    data { $1 }
fn yy_action_65(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj__Attributes_____Annotated_ModuleField_Location___Location_(_dollar1)
  YYObj__Attributes_____Annotated_ModuleField_Location___Location_({();  _dollar1 })
}

// file:///./parser.mbty
// 1286|    table { $1 }
fn yy_action_66(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj__Attributes_____Annotated_ModuleField_Location___Location_(_dollar1)
  YYObj__Attributes_____Annotated_ModuleField_Location___Location_({();  _dollar1 })
}

// file:///./parser.mbty
// 1287|    elem { $1 }
fn yy_action_67(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj__Attributes_____Annotated_ModuleField_Location___Location_(_dollar1)
  YYObj__Attributes_____Annotated_ModuleField_Location___Location_({();  _dollar1 })
}

// file:///./parser.mbty
// 1288|    tag_def { $1 }
fn yy_action_68(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj__Attributes_____Annotated_ModuleField_Location___Location_(_dollar1)
  YYObj__Attributes_____Annotated_ModuleField_Location___Location_({();  _dollar1 })
}

// file:///./parser.mbty
// 1372|    MEMORY ident ":" address_type ioption(mem_limits) ioption(mem_pagesize)
// 1373|    boption(SHARED) ";" {
// 1374|      let (name, at, lim, ps, sh) = ($2, $4, $5, $6, $7)
// 1375|      fn(attributes) {
// 1376|        annot(
// 1377|          $sloc,
// 1378|          ModuleField::Memory(
// 1379|            name~,
// 1380|            address_type=at,
// 1381|            limits=lim,
// 1382|            page_size_log2=ps,
// 1383|            shared=sh,
// 1384|            data=[],
// 1385|            attributes~,
// 1386|          ),
// 1387|        )
// 1388|      }
// 1389|    }
fn yy_action_69(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_70(_args[3].2, _args[4:4])
  let _sub_action_1_result = yy_action_71(_args[3].2, _args[4:4])
  guard _args[1].0 is YYObj_Ident(_dollar2)
  guard _args[3].0 is YYObj_AddressType(_dollar4)
  guard _sub_action_0_result is YYObj_Option__UInt64__UInt64___(_dollar5)
  guard _sub_action_1_result is YYObj_Option_Int_(_dollar6)
  guard _args[4].0 is YYObj_Bool(_dollar7)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj__Attributes_____Annotated_ModuleField_Location___Location_({(); 
      let (name, at, lim, ps, sh) = (_dollar2, _dollar4, _dollar5, _dollar6, _dollar7)
      fn(attributes) {
        annot(
          (_symbol_start_pos, _end_pos),
          ModuleField::Memory(
            name~,
            address_type=at,
            limits=lim,
            page_size_log2=ps,
            shared=sh,
            data=[],
            attributes~,
          ),
        )
      }
    })
}

// file:///./parser.mbty
// 1390|    MEMORY ident ":" address_type ioption(mem_limits) ioption(mem_pagesize)
// 1391|    boption(SHARED) "{" list_of(data_item) "}" {
// 1392|      let (name, at, lim, ps, sh, items) = ($2, $4, $5, $6, $7, $9)
// 1393|      fn(attributes) {
// 1394|        annot(
// 1395|          $sloc,
// 1396|          ModuleField::Memory(
// 1397|            name~,
// 1398|            address_type=at,
// 1399|            limits=lim,
// 1400|            page_size_log2=ps,
// 1401|            shared=sh,
// 1402|            data=items,
// 1403|            attributes~,
// 1404|          ),
// 1405|        )
// 1406|      }
// 1407|    }
fn yy_action_72(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_70(_args[3].2, _args[4:4])
  let _sub_action_1_result = yy_action_71(_args[3].2, _args[4:4])
  guard _args[1].0 is YYObj_Ident(_dollar2)
  guard _args[3].0 is YYObj_AddressType(_dollar4)
  guard _sub_action_0_result is YYObj_Option__UInt64__UInt64___(_dollar5)
  guard _sub_action_1_result is YYObj_Option_Int_(_dollar6)
  guard _args[4].0 is YYObj_Bool(_dollar7)
  guard _args[6].0 is YYObj_Array__ast_MemData_Location__(_dollar9)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj__Attributes_____Annotated_ModuleField_Location___Location_({(); 
      let (name, at, lim, ps, sh, items) = (_dollar2, _dollar4, _dollar5, _dollar6, _dollar7, _dollar9)
      fn(attributes) {
        annot(
          (_symbol_start_pos, _end_pos),
          ModuleField::Memory(
            name~,
            address_type=at,
            limits=lim,
            page_size_log2=ps,
            shared=sh,
            data=items,
            attributes~,
          ),
        )
      }
    })
}

// file:///./parser.mbty
// 1372|    MEMORY ident ":" address_type ioption(mem_limits) ioption(mem_pagesize)
// 1373|    boption(SHARED) ";" {
// 1374|      let (name, at, lim, ps, sh) = ($2, $4, $5, $6, $7)
// 1375|      fn(attributes) {
// 1376|        annot(
// 1377|          $sloc,
// 1378|          ModuleField::Memory(
// 1379|            name~,
// 1380|            address_type=at,
// 1381|            limits=lim,
// 1382|            page_size_log2=ps,
// 1383|            shared=sh,
// 1384|            data=[],
// 1385|            attributes~,
// 1386|          ),
// 1387|        )
// 1388|      }
// 1389|    }
fn yy_action_73(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_70(_args[3].2, _args[4:4])
  let _sub_action_1_result = yy_action_74(_args[3].2, _args[4:5])
  guard _args[1].0 is YYObj_Ident(_dollar2)
  guard _args[3].0 is YYObj_AddressType(_dollar4)
  guard _sub_action_0_result is YYObj_Option__UInt64__UInt64___(_dollar5)
  guard _sub_action_1_result is YYObj_Option_Int_(_dollar6)
  guard _args[5].0 is YYObj_Bool(_dollar7)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj__Attributes_____Annotated_ModuleField_Location___Location_({(); 
      let (name, at, lim, ps, sh) = (_dollar2, _dollar4, _dollar5, _dollar6, _dollar7)
      fn(attributes) {
        annot(
          (_symbol_start_pos, _end_pos),
          ModuleField::Memory(
            name~,
            address_type=at,
            limits=lim,
            page_size_log2=ps,
            shared=sh,
            data=[],
            attributes~,
          ),
        )
      }
    })
}

// file:///./parser.mbty
// 1390|    MEMORY ident ":" address_type ioption(mem_limits) ioption(mem_pagesize)
// 1391|    boption(SHARED) "{" list_of(data_item) "}" {
// 1392|      let (name, at, lim, ps, sh, items) = ($2, $4, $5, $6, $7, $9)
// 1393|      fn(attributes) {
// 1394|        annot(
// 1395|          $sloc,
// 1396|          ModuleField::Memory(
// 1397|            name~,
// 1398|            address_type=at,
// 1399|            limits=lim,
// 1400|            page_size_log2=ps,
// 1401|            shared=sh,
// 1402|            data=items,
// 1403|            attributes~,
// 1404|          ),
// 1405|        )
// 1406|      }
// 1407|    }
fn yy_action_75(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_70(_args[3].2, _args[4:4])
  let _sub_action_1_result = yy_action_74(_args[3].2, _args[4:5])
  guard _args[1].0 is YYObj_Ident(_dollar2)
  guard _args[3].0 is YYObj_AddressType(_dollar4)
  guard _sub_action_0_result is YYObj_Option__UInt64__UInt64___(_dollar5)
  guard _sub_action_1_result is YYObj_Option_Int_(_dollar6)
  guard _args[5].0 is YYObj_Bool(_dollar7)
  guard _args[7].0 is YYObj_Array__ast_MemData_Location__(_dollar9)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj__Attributes_____Annotated_ModuleField_Location___Location_({(); 
      let (name, at, lim, ps, sh, items) = (_dollar2, _dollar4, _dollar5, _dollar6, _dollar7, _dollar9)
      fn(attributes) {
        annot(
          (_symbol_start_pos, _end_pos),
          ModuleField::Memory(
            name~,
            address_type=at,
            limits=lim,
            page_size_log2=ps,
            shared=sh,
            data=items,
            attributes~,
          ),
        )
      }
    })
}

// file:///./parser.mbty
// 1372|    MEMORY ident ":" address_type ioption(mem_limits) ioption(mem_pagesize)
// 1373|    boption(SHARED) ";" {
// 1374|      let (name, at, lim, ps, sh) = ($2, $4, $5, $6, $7)
// 1375|      fn(attributes) {
// 1376|        annot(
// 1377|          $sloc,
// 1378|          ModuleField::Memory(
// 1379|            name~,
// 1380|            address_type=at,
// 1381|            limits=lim,
// 1382|            page_size_log2=ps,
// 1383|            shared=sh,
// 1384|            data=[],
// 1385|            attributes~,
// 1386|          ),
// 1387|        )
// 1388|      }
// 1389|    }
fn yy_action_76(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_77(_args[3].2, _args[4:5])
  let _sub_action_1_result = yy_action_71(_args[4].2, _args[5:5])
  guard _args[1].0 is YYObj_Ident(_dollar2)
  guard _args[3].0 is YYObj_AddressType(_dollar4)
  guard _sub_action_0_result is YYObj_Option__UInt64__UInt64___(_dollar5)
  guard _sub_action_1_result is YYObj_Option_Int_(_dollar6)
  guard _args[5].0 is YYObj_Bool(_dollar7)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj__Attributes_____Annotated_ModuleField_Location___Location_({(); 
      let (name, at, lim, ps, sh) = (_dollar2, _dollar4, _dollar5, _dollar6, _dollar7)
      fn(attributes) {
        annot(
          (_symbol_start_pos, _end_pos),
          ModuleField::Memory(
            name~,
            address_type=at,
            limits=lim,
            page_size_log2=ps,
            shared=sh,
            data=[],
            attributes~,
          ),
        )
      }
    })
}

// file:///./parser.mbty
// 1390|    MEMORY ident ":" address_type ioption(mem_limits) ioption(mem_pagesize)
// 1391|    boption(SHARED) "{" list_of(data_item) "}" {
// 1392|      let (name, at, lim, ps, sh, items) = ($2, $4, $5, $6, $7, $9)
// 1393|      fn(attributes) {
// 1394|        annot(
// 1395|          $sloc,
// 1396|          ModuleField::Memory(
// 1397|            name~,
// 1398|            address_type=at,
// 1399|            limits=lim,
// 1400|            page_size_log2=ps,
// 1401|            shared=sh,
// 1402|            data=items,
// 1403|            attributes~,
// 1404|          ),
// 1405|        )
// 1406|      }
// 1407|    }
fn yy_action_78(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_77(_args[3].2, _args[4:5])
  let _sub_action_1_result = yy_action_71(_args[4].2, _args[5:5])
  guard _args[1].0 is YYObj_Ident(_dollar2)
  guard _args[3].0 is YYObj_AddressType(_dollar4)
  guard _sub_action_0_result is YYObj_Option__UInt64__UInt64___(_dollar5)
  guard _sub_action_1_result is YYObj_Option_Int_(_dollar6)
  guard _args[5].0 is YYObj_Bool(_dollar7)
  guard _args[7].0 is YYObj_Array__ast_MemData_Location__(_dollar9)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj__Attributes_____Annotated_ModuleField_Location___Location_({(); 
      let (name, at, lim, ps, sh, items) = (_dollar2, _dollar4, _dollar5, _dollar6, _dollar7, _dollar9)
      fn(attributes) {
        annot(
          (_symbol_start_pos, _end_pos),
          ModuleField::Memory(
            name~,
            address_type=at,
            limits=lim,
            page_size_log2=ps,
            shared=sh,
            data=items,
            attributes~,
          ),
        )
      }
    })
}

// file:///./parser.mbty
// 1372|    MEMORY ident ":" address_type ioption(mem_limits) ioption(mem_pagesize)
// 1373|    boption(SHARED) ";" {
// 1374|      let (name, at, lim, ps, sh) = ($2, $4, $5, $6, $7)
// 1375|      fn(attributes) {
// 1376|        annot(
// 1377|          $sloc,
// 1378|          ModuleField::Memory(
// 1379|            name~,
// 1380|            address_type=at,
// 1381|            limits=lim,
// 1382|            page_size_log2=ps,
// 1383|            shared=sh,
// 1384|            data=[],
// 1385|            attributes~,
// 1386|          ),
// 1387|        )
// 1388|      }
// 1389|    }
fn yy_action_79(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_77(_args[3].2, _args[4:5])
  let _sub_action_1_result = yy_action_74(_args[4].2, _args[5:6])
  guard _args[1].0 is YYObj_Ident(_dollar2)
  guard _args[3].0 is YYObj_AddressType(_dollar4)
  guard _sub_action_0_result is YYObj_Option__UInt64__UInt64___(_dollar5)
  guard _sub_action_1_result is YYObj_Option_Int_(_dollar6)
  guard _args[6].0 is YYObj_Bool(_dollar7)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj__Attributes_____Annotated_ModuleField_Location___Location_({(); 
      let (name, at, lim, ps, sh) = (_dollar2, _dollar4, _dollar5, _dollar6, _dollar7)
      fn(attributes) {
        annot(
          (_symbol_start_pos, _end_pos),
          ModuleField::Memory(
            name~,
            address_type=at,
            limits=lim,
            page_size_log2=ps,
            shared=sh,
            data=[],
            attributes~,
          ),
        )
      }
    })
}

// file:///./parser.mbty
// 1390|    MEMORY ident ":" address_type ioption(mem_limits) ioption(mem_pagesize)
// 1391|    boption(SHARED) "{" list_of(data_item) "}" {
// 1392|      let (name, at, lim, ps, sh, items) = ($2, $4, $5, $6, $7, $9)
// 1393|      fn(attributes) {
// 1394|        annot(
// 1395|          $sloc,
// 1396|          ModuleField::Memory(
// 1397|            name~,
// 1398|            address_type=at,
// 1399|            limits=lim,
// 1400|            page_size_log2=ps,
// 1401|            shared=sh,
// 1402|            data=items,
// 1403|            attributes~,
// 1404|          ),
// 1405|        )
// 1406|      }
// 1407|    }
fn yy_action_80(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_77(_args[3].2, _args[4:5])
  let _sub_action_1_result = yy_action_74(_args[4].2, _args[5:6])
  guard _args[1].0 is YYObj_Ident(_dollar2)
  guard _args[3].0 is YYObj_AddressType(_dollar4)
  guard _sub_action_0_result is YYObj_Option__UInt64__UInt64___(_dollar5)
  guard _sub_action_1_result is YYObj_Option_Int_(_dollar6)
  guard _args[6].0 is YYObj_Bool(_dollar7)
  guard _args[8].0 is YYObj_Array__ast_MemData_Location__(_dollar9)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj__Attributes_____Annotated_ModuleField_Location___Location_({(); 
      let (name, at, lim, ps, sh, items) = (_dollar2, _dollar4, _dollar5, _dollar6, _dollar7, _dollar9)
      fn(attributes) {
        annot(
          (_symbol_start_pos, _end_pos),
          ModuleField::Memory(
            name~,
            address_type=at,
            limits=lim,
            page_size_log2=ps,
            shared=sh,
            data=items,
            attributes~,
          ),
        )
      }
    })
}

// file:///./parser.mbty
// 1356|    DATA data_name "@" "[" constant_expression "]" loption_data_init ";" {
// 1357|      { data_name: $2, offset: $5, init: $7 }
// 1358|    }
fn yy_action_81(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[1].0 is YYObj_Ident_(_dollar2)
  guard _args[4].0 is YYObj_Instr_Location_(_dollar5)
  guard _args[6].0 is YYObj_Array__ast_DataElem_(_dollar7)
  YYObj__ast_MemData_Location_({(); 
      { data_name: _dollar2, offset: _dollar5, init: _dollar7 }
    })
}

// file:///./parser.mbty
// 443|    X list_of(X) { [$1, ..$2] }
fn yy_action_82(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj__ast_MemData_Location_(_dollar1)
  guard _args[1].0 is YYObj_Array__ast_MemData_Location__(_dollar2)
  YYObj_Array__ast_MemData_Location__({();  [_dollar1, .._dollar2] })
}

// file:///./parser.mbty
// 442|    { [] }
fn yy_action_83(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Array__ast_MemData_Location__({();  [] })
}

// file:///./parser.mbty
// 1306|    "_" { None }
fn yy_action_84(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Ident_({();  None })
}

// file:///./parser.mbty
// 1307|    ident { Some($1) }
fn yy_action_85(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Ident(_dollar1)
  YYObj_Ident_({();  Some(_dollar1) })
}

// file:///./parser.mbty
// 1411|    DATA data_name loption_data_init ";" {
// 1412|      let (n, init) = ($2, $3)
// 1413|      fn(attributes) {
// 1414|        annot(
// 1415|          $sloc,
// 1416|          ModuleField::Data(name=n, mode=Passive, init~, attributes~),
// 1417|        )
// 1418|      }
// 1419|    }
fn yy_action_86(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[1].0 is YYObj_Ident_(_dollar2)
  guard _args[2].0 is YYObj_Array__ast_DataElem_(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj__Attributes_____Annotated_ModuleField_Location___Location_({(); 
      let (n, init) = (_dollar2, _dollar3)
      fn(attributes) {
        annot(
          (_symbol_start_pos, _end_pos),
          ModuleField::Data(name=n, mode=Passive, init~, attributes~),
        )
      }
    })
}

// file:///./parser.mbty
// 1314|    data_element "++" data_init { [$1, ..$3] }
fn yy_action_87(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj__ast_DataElem(_dollar1)
  guard _args[2].0 is YYObj_Array__ast_DataElem_(_dollar3)
  YYObj_Array__ast_DataElem_({();  [_dollar1, .._dollar3] })
}

// file:///./parser.mbty
// 1313|    data_element { [$1] }
fn yy_action_88(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj__ast_DataElem(_dollar1)
  YYObj_Array__ast_DataElem_({();  [_dollar1] })
}

// file:///./parser.mbty
// 1318|    STRING { Str($1.desc) }
fn yy_action_89(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_LocString(_dollar1)
  YYObj__ast_DataElem({();  Str(_dollar1.desc) })
}

// file:///./parser.mbty
// 1319|    "[" ident ":" sep_trailing(",", data_run_item) "]" {
// 1320|      data_run($loc($2), $2, $4)
// 1321|    }
fn yy_action_90(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _start_pos_of_item1 = _args[1].1
  let _end_pos_of_item1 = _args[1].2
  guard _args[1].0 is YYObj_Ident(_dollar2)
  guard _args[3].0 is YYObj_Array_DataRunItem_(_dollar4)
  YYObj__ast_DataElem({(); 
      data_run((_start_pos_of_item1, _end_pos_of_item1), _dollar2, _dollar4)
    })
}

// file:///./parser.mbty
// 235|    non_empty_sep_trailing(SEP, X) { $1 }
fn yy_action_91(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_DataRunItem_(_dollar1)
  YYObj_Array_DataRunItem_({();  _dollar1 })
}

// file:///./parser.mbty
// 1327|    data_number { Num($1) }
fn yy_action_92(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Annotated_String__Location_(_dollar1)
  YYObj_DataRunItem({();  Num(_dollar1) })
}

// file:///./parser.mbty
// 1328|    ident "(" sep_trailing(",", data_number) ")" {
// 1329|      let comps : Array[String] = []
// 1330|      for n in $3 {
// 1331|        comps.push(n.desc)
// 1332|      }
// 1333|      Vec(annot($sloc, { shape: vec_shape($loc($1), $1), components: comps }))
// 1334|    }
fn yy_action_93(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[2].0 is YYObj_Array_Annotated_String__Location__(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  let _start_pos_of_item0 = _args[0].1
  let _end_pos_of_item0 = _args[0].2
  guard _args[0].0 is YYObj_Ident(_dollar1)
  YYObj_DataRunItem({(); 
      let comps : Array[String] = []
      for n in _dollar3 {
        comps.push(n.desc)
      }
      Vec(annot((_symbol_start_pos, _end_pos), { shape: vec_shape((_start_pos_of_item0, _end_pos_of_item0), _dollar1), components: comps }))
    })
}

// file:///./parser.mbty
// 235|    non_empty_sep_trailing(SEP, X) { $1 }
fn yy_action_94(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Annotated_String__Location__(_dollar1)
  YYObj_Array_Annotated_String__Location__({();  _dollar1 })
}

// file:///./parser.mbty
// 230|    X SEP non_empty_sep_trailing(SEP, X) { [$1, ..$3] }
fn yy_action_95(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Annotated_String__Location_(_dollar1)
  guard _args[2].0 is YYObj_Array_Annotated_String__Location__(_dollar3)
  YYObj_Array_Annotated_String__Location__({();  [_dollar1, .._dollar3] })
}

// file:///./parser.mbty
// 229|    X SEP { [$1] }
fn yy_action_96(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Annotated_String__Location_(_dollar1)
  YYObj_Array_Annotated_String__Location__({();  [_dollar1] })
}

// file:///./parser.mbty
// 228|    X { [$1] }
fn yy_action_97(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Annotated_String__Location_(_dollar1)
  YYObj_Array_Annotated_String__Location__({();  [_dollar1] })
}

// file:///./parser.mbty
// 234|    { [] }
fn yy_action_98(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Array_Annotated_String__Location__({();  [] })
}

// file:///./parser.mbty
// 1340|    ioption(data_sign) raw_number { annot($sloc, $1.unwrap_or("") + $2) }
fn yy_action_99(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_100(_last_pos, _args[0:0])
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _sub_action_0_result is YYObj_Option_String_(_dollar1)
  guard _args[0].0 is YYObj_String(_dollar2)
  YYObj_Annotated_String__Location_({();  annot((_symbol_start_pos, _end_pos), _dollar1.unwrap_or("") + _dollar2) })
}

// file:///./stdlib.mbty
// 9|    { None }
fn yy_action_100(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Option_String_({();  None })
}

// file:///./parser.mbty
// 1340|    ioption(data_sign) raw_number { annot($sloc, $1.unwrap_or("") + $2) }
fn yy_action_101(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_102(_last_pos, _args[0:1])
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _sub_action_0_result is YYObj_Option_String_(_dollar1)
  guard _args[1].0 is YYObj_String(_dollar2)
  YYObj_Annotated_String__Location_({();  annot((_symbol_start_pos, _end_pos), _dollar1.unwrap_or("") + _dollar2) })
}

// file:///./stdlib.mbty
// 10|    X { Some($1) }
fn yy_action_102(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  YYObj_Option_String_({();  Some(_dollar1) })
}

// file:///./parser.mbty
// 1344|    "-" { "-" }
fn yy_action_103(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_String({();  "-" })
}

// file:///./parser.mbty
// 1345|    "+" { "" }
fn yy_action_104(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_String({();  "" })
}

// file:///./parser.mbty
// 1349|    INT { $1 }
fn yy_action_105(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  YYObj_String({();  _dollar1 })
}

// file:///./parser.mbty
// 1350|    FLOAT { $1 }
fn yy_action_106(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  YYObj_String({();  _dollar1 })
}

// file:///./parser.mbty
// 1351|    INF { "inf" }
fn yy_action_107(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_String({();  "inf" })
}

// file:///./parser.mbty
// 1352|    NAN { "nan" }
fn yy_action_108(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_String({();  "nan" })
}

// file:///./parser.mbty
// 230|    X SEP non_empty_sep_trailing(SEP, X) { [$1, ..$3] }
fn yy_action_109(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_DataRunItem(_dollar1)
  guard _args[2].0 is YYObj_Array_DataRunItem_(_dollar3)
  YYObj_Array_DataRunItem_({();  [_dollar1, .._dollar3] })
}

// file:///./parser.mbty
// 229|    X SEP { [$1] }
fn yy_action_110(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_DataRunItem(_dollar1)
  YYObj_Array_DataRunItem_({();  [_dollar1] })
}

// file:///./parser.mbty
// 228|    X { [$1] }
fn yy_action_111(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_DataRunItem(_dollar1)
  YYObj_Array_DataRunItem_({();  [_dollar1] })
}

// file:///./parser.mbty
// 234|    { [] }
fn yy_action_112(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Array_DataRunItem_({();  [] })
}

// file:///./parser.mbty
// 1364|    "=" data_init { $2 }
fn yy_action_113(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[1].0 is YYObj_Array__ast_DataElem_(_dollar2)
  YYObj_Array__ast_DataElem_({();  _dollar2 })
}

// file:///./parser.mbty
// 1420|    DATA data_name "@" ident "[" constant_expression "]" loption_data_init ";" {
// 1421|      let (n, mem, off, init) = ($2, $4, $6, $8)
// 1422|      fn(attributes) {
// 1423|        annot(
// 1424|          $sloc,
// 1425|          ModuleField::Data(
// 1426|            name=n,
// 1427|            mode=Active(mem, off),
// 1428|            init~,
// 1429|            attributes~,
// 1430|          ),
// 1431|        )
// 1432|      }
// 1433|    }
fn yy_action_114(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[1].0 is YYObj_Ident_(_dollar2)
  guard _args[3].0 is YYObj_Ident(_dollar4)
  guard _args[5].0 is YYObj_Instr_Location_(_dollar6)
  guard _args[7].0 is YYObj_Array__ast_DataElem_(_dollar8)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj__Attributes_____Annotated_ModuleField_Location___Location_({(); 
      let (n, mem, off, init) = (_dollar2, _dollar4, _dollar6, _dollar8)
      fn(attributes) {
        annot(
          (_symbol_start_pos, _end_pos),
          ModuleField::Data(
            name=n,
            mode=Active(mem, off),
            init~,
            attributes~,
          ),
        )
      }
    })
}

// file:///./parser.mbty
// 1363|    { [] }
fn yy_action_115(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Array__ast_DataElem_({();  [] })
}

// file:///./parser.mbty
// 1437|    TABLE ident ":" ioption(address_type) reference_type ioption(mem_limits)
// 1438|    ioption(table_init) ";" {
// 1439|      let (name, at, rt, lim, init) = ($2, $4, $5, $6, $7)
// 1440|      fn(attributes) {
// 1441|        annot(
// 1442|          $sloc,
// 1443|          ModuleField::Table(
// 1444|            name~,
// 1445|            address_type=at.unwrap_or(I32),
// 1446|            reftype=rt,
// 1447|            limits=lim,
// 1448|            init~,
// 1449|            attributes~,
// 1450|          ),
// 1451|        )
// 1452|      }
// 1453|    }
fn yy_action_116(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_117(_args[2].2, _args[3:3])
  let _sub_action_1_result = yy_action_70(_args[3].2, _args[4:4])
  let _sub_action_2_result = yy_action_118(_args[3].2, _args[4:4])
  guard _args[1].0 is YYObj_Ident(_dollar2)
  guard _sub_action_0_result is YYObj_Option_AddressType_(_dollar4)
  guard _args[3].0 is YYObj_RefType(_dollar5)
  guard _sub_action_1_result is YYObj_Option__UInt64__UInt64___(_dollar6)
  guard _sub_action_2_result is YYObj_Option_Instr_Location__(_dollar7)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj__Attributes_____Annotated_ModuleField_Location___Location_({(); 
      let (name, at, rt, lim, init) = (_dollar2, _dollar4, _dollar5, _dollar6, _dollar7)
      fn(attributes) {
        annot(
          (_symbol_start_pos, _end_pos),
          ModuleField::Table(
            name~,
            address_type=at.unwrap_or(I32),
            reftype=rt,
            limits=lim,
            init~,
            attributes~,
          ),
        )
      }
    })
}

// file:///./parser.mbty
// 1437|    TABLE ident ":" ioption(address_type) reference_type ioption(mem_limits)
// 1438|    ioption(table_init) ";" {
// 1439|      let (name, at, rt, lim, init) = ($2, $4, $5, $6, $7)
// 1440|      fn(attributes) {
// 1441|        annot(
// 1442|          $sloc,
// 1443|          ModuleField::Table(
// 1444|            name~,
// 1445|            address_type=at.unwrap_or(I32),
// 1446|            reftype=rt,
// 1447|            limits=lim,
// 1448|            init~,
// 1449|            attributes~,
// 1450|          ),
// 1451|        )
// 1452|      }
// 1453|    }
fn yy_action_119(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_117(_args[2].2, _args[3:3])
  let _sub_action_1_result = yy_action_70(_args[3].2, _args[4:4])
  let _sub_action_2_result = yy_action_120(_args[3].2, _args[4:5])
  guard _args[1].0 is YYObj_Ident(_dollar2)
  guard _sub_action_0_result is YYObj_Option_AddressType_(_dollar4)
  guard _args[3].0 is YYObj_RefType(_dollar5)
  guard _sub_action_1_result is YYObj_Option__UInt64__UInt64___(_dollar6)
  guard _sub_action_2_result is YYObj_Option_Instr_Location__(_dollar7)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj__Attributes_____Annotated_ModuleField_Location___Location_({(); 
      let (name, at, rt, lim, init) = (_dollar2, _dollar4, _dollar5, _dollar6, _dollar7)
      fn(attributes) {
        annot(
          (_symbol_start_pos, _end_pos),
          ModuleField::Table(
            name~,
            address_type=at.unwrap_or(I32),
            reftype=rt,
            limits=lim,
            init~,
            attributes~,
          ),
        )
      }
    })
}

// file:///./parser.mbty
// 1437|    TABLE ident ":" ioption(address_type) reference_type ioption(mem_limits)
// 1438|    ioption(table_init) ";" {
// 1439|      let (name, at, rt, lim, init) = ($2, $4, $5, $6, $7)
// 1440|      fn(attributes) {
// 1441|        annot(
// 1442|          $sloc,
// 1443|          ModuleField::Table(
// 1444|            name~,
// 1445|            address_type=at.unwrap_or(I32),
// 1446|            reftype=rt,
// 1447|            limits=lim,
// 1448|            init~,
// 1449|            attributes~,
// 1450|          ),
// 1451|        )
// 1452|      }
// 1453|    }
fn yy_action_121(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_117(_args[2].2, _args[3:3])
  let _sub_action_1_result = yy_action_77(_args[3].2, _args[4:5])
  let _sub_action_2_result = yy_action_118(_args[4].2, _args[5:5])
  guard _args[1].0 is YYObj_Ident(_dollar2)
  guard _sub_action_0_result is YYObj_Option_AddressType_(_dollar4)
  guard _args[3].0 is YYObj_RefType(_dollar5)
  guard _sub_action_1_result is YYObj_Option__UInt64__UInt64___(_dollar6)
  guard _sub_action_2_result is YYObj_Option_Instr_Location__(_dollar7)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj__Attributes_____Annotated_ModuleField_Location___Location_({(); 
      let (name, at, rt, lim, init) = (_dollar2, _dollar4, _dollar5, _dollar6, _dollar7)
      fn(attributes) {
        annot(
          (_symbol_start_pos, _end_pos),
          ModuleField::Table(
            name~,
            address_type=at.unwrap_or(I32),
            reftype=rt,
            limits=lim,
            init~,
            attributes~,
          ),
        )
      }
    })
}

// file:///./parser.mbty
// 1437|    TABLE ident ":" ioption(address_type) reference_type ioption(mem_limits)
// 1438|    ioption(table_init) ";" {
// 1439|      let (name, at, rt, lim, init) = ($2, $4, $5, $6, $7)
// 1440|      fn(attributes) {
// 1441|        annot(
// 1442|          $sloc,
// 1443|          ModuleField::Table(
// 1444|            name~,
// 1445|            address_type=at.unwrap_or(I32),
// 1446|            reftype=rt,
// 1447|            limits=lim,
// 1448|            init~,
// 1449|            attributes~,
// 1450|          ),
// 1451|        )
// 1452|      }
// 1453|    }
fn yy_action_122(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_117(_args[2].2, _args[3:3])
  let _sub_action_1_result = yy_action_77(_args[3].2, _args[4:5])
  let _sub_action_2_result = yy_action_120(_args[4].2, _args[5:6])
  guard _args[1].0 is YYObj_Ident(_dollar2)
  guard _sub_action_0_result is YYObj_Option_AddressType_(_dollar4)
  guard _args[3].0 is YYObj_RefType(_dollar5)
  guard _sub_action_1_result is YYObj_Option__UInt64__UInt64___(_dollar6)
  guard _sub_action_2_result is YYObj_Option_Instr_Location__(_dollar7)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj__Attributes_____Annotated_ModuleField_Location___Location_({(); 
      let (name, at, rt, lim, init) = (_dollar2, _dollar4, _dollar5, _dollar6, _dollar7)
      fn(attributes) {
        annot(
          (_symbol_start_pos, _end_pos),
          ModuleField::Table(
            name~,
            address_type=at.unwrap_or(I32),
            reftype=rt,
            limits=lim,
            init~,
            attributes~,
          ),
        )
      }
    })
}

// file:///./parser.mbty
// 1437|    TABLE ident ":" ioption(address_type) reference_type ioption(mem_limits)
// 1438|    ioption(table_init) ";" {
// 1439|      let (name, at, rt, lim, init) = ($2, $4, $5, $6, $7)
// 1440|      fn(attributes) {
// 1441|        annot(
// 1442|          $sloc,
// 1443|          ModuleField::Table(
// 1444|            name~,
// 1445|            address_type=at.unwrap_or(I32),
// 1446|            reftype=rt,
// 1447|            limits=lim,
// 1448|            init~,
// 1449|            attributes~,
// 1450|          ),
// 1451|        )
// 1452|      }
// 1453|    }
fn yy_action_123(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_124(_args[2].2, _args[3:4])
  let _sub_action_1_result = yy_action_70(_args[4].2, _args[5:5])
  let _sub_action_2_result = yy_action_118(_args[4].2, _args[5:5])
  guard _args[1].0 is YYObj_Ident(_dollar2)
  guard _sub_action_0_result is YYObj_Option_AddressType_(_dollar4)
  guard _args[4].0 is YYObj_RefType(_dollar5)
  guard _sub_action_1_result is YYObj_Option__UInt64__UInt64___(_dollar6)
  guard _sub_action_2_result is YYObj_Option_Instr_Location__(_dollar7)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj__Attributes_____Annotated_ModuleField_Location___Location_({(); 
      let (name, at, rt, lim, init) = (_dollar2, _dollar4, _dollar5, _dollar6, _dollar7)
      fn(attributes) {
        annot(
          (_symbol_start_pos, _end_pos),
          ModuleField::Table(
            name~,
            address_type=at.unwrap_or(I32),
            reftype=rt,
            limits=lim,
            init~,
            attributes~,
          ),
        )
      }
    })
}

// file:///./parser.mbty
// 1437|    TABLE ident ":" ioption(address_type) reference_type ioption(mem_limits)
// 1438|    ioption(table_init) ";" {
// 1439|      let (name, at, rt, lim, init) = ($2, $4, $5, $6, $7)
// 1440|      fn(attributes) {
// 1441|        annot(
// 1442|          $sloc,
// 1443|          ModuleField::Table(
// 1444|            name~,
// 1445|            address_type=at.unwrap_or(I32),
// 1446|            reftype=rt,
// 1447|            limits=lim,
// 1448|            init~,
// 1449|            attributes~,
// 1450|          ),
// 1451|        )
// 1452|      }
// 1453|    }
fn yy_action_125(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_124(_args[2].2, _args[3:4])
  let _sub_action_1_result = yy_action_70(_args[4].2, _args[5:5])
  let _sub_action_2_result = yy_action_120(_args[4].2, _args[5:6])
  guard _args[1].0 is YYObj_Ident(_dollar2)
  guard _sub_action_0_result is YYObj_Option_AddressType_(_dollar4)
  guard _args[4].0 is YYObj_RefType(_dollar5)
  guard _sub_action_1_result is YYObj_Option__UInt64__UInt64___(_dollar6)
  guard _sub_action_2_result is YYObj_Option_Instr_Location__(_dollar7)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj__Attributes_____Annotated_ModuleField_Location___Location_({(); 
      let (name, at, rt, lim, init) = (_dollar2, _dollar4, _dollar5, _dollar6, _dollar7)
      fn(attributes) {
        annot(
          (_symbol_start_pos, _end_pos),
          ModuleField::Table(
            name~,
            address_type=at.unwrap_or(I32),
            reftype=rt,
            limits=lim,
            init~,
            attributes~,
          ),
        )
      }
    })
}

// file:///./parser.mbty
// 1437|    TABLE ident ":" ioption(address_type) reference_type ioption(mem_limits)
// 1438|    ioption(table_init) ";" {
// 1439|      let (name, at, rt, lim, init) = ($2, $4, $5, $6, $7)
// 1440|      fn(attributes) {
// 1441|        annot(
// 1442|          $sloc,
// 1443|          ModuleField::Table(
// 1444|            name~,
// 1445|            address_type=at.unwrap_or(I32),
// 1446|            reftype=rt,
// 1447|            limits=lim,
// 1448|            init~,
// 1449|            attributes~,
// 1450|          ),
// 1451|        )
// 1452|      }
// 1453|    }
fn yy_action_126(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_124(_args[2].2, _args[3:4])
  let _sub_action_1_result = yy_action_77(_args[4].2, _args[5:6])
  let _sub_action_2_result = yy_action_118(_args[5].2, _args[6:6])
  guard _args[1].0 is YYObj_Ident(_dollar2)
  guard _sub_action_0_result is YYObj_Option_AddressType_(_dollar4)
  guard _args[4].0 is YYObj_RefType(_dollar5)
  guard _sub_action_1_result is YYObj_Option__UInt64__UInt64___(_dollar6)
  guard _sub_action_2_result is YYObj_Option_Instr_Location__(_dollar7)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj__Attributes_____Annotated_ModuleField_Location___Location_({(); 
      let (name, at, rt, lim, init) = (_dollar2, _dollar4, _dollar5, _dollar6, _dollar7)
      fn(attributes) {
        annot(
          (_symbol_start_pos, _end_pos),
          ModuleField::Table(
            name~,
            address_type=at.unwrap_or(I32),
            reftype=rt,
            limits=lim,
            init~,
            attributes~,
          ),
        )
      }
    })
}

// file:///./stdlib.mbty
// 9|    { None }
fn yy_action_118(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Option_Instr_Location__({();  None })
}

// file:///./parser.mbty
// 1437|    TABLE ident ":" ioption(address_type) reference_type ioption(mem_limits)
// 1438|    ioption(table_init) ";" {
// 1439|      let (name, at, rt, lim, init) = ($2, $4, $5, $6, $7)
// 1440|      fn(attributes) {
// 1441|        annot(
// 1442|          $sloc,
// 1443|          ModuleField::Table(
// 1444|            name~,
// 1445|            address_type=at.unwrap_or(I32),
// 1446|            reftype=rt,
// 1447|            limits=lim,
// 1448|            init~,
// 1449|            attributes~,
// 1450|          ),
// 1451|        )
// 1452|      }
// 1453|    }
fn yy_action_127(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_124(_args[2].2, _args[3:4])
  let _sub_action_1_result = yy_action_77(_args[4].2, _args[5:6])
  let _sub_action_2_result = yy_action_120(_args[5].2, _args[6:7])
  guard _args[1].0 is YYObj_Ident(_dollar2)
  guard _sub_action_0_result is YYObj_Option_AddressType_(_dollar4)
  guard _args[4].0 is YYObj_RefType(_dollar5)
  guard _sub_action_1_result is YYObj_Option__UInt64__UInt64___(_dollar6)
  guard _sub_action_2_result is YYObj_Option_Instr_Location__(_dollar7)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj__Attributes_____Annotated_ModuleField_Location___Location_({(); 
      let (name, at, rt, lim, init) = (_dollar2, _dollar4, _dollar5, _dollar6, _dollar7)
      fn(attributes) {
        annot(
          (_symbol_start_pos, _end_pos),
          ModuleField::Table(
            name~,
            address_type=at.unwrap_or(I32),
            reftype=rt,
            limits=lim,
            init~,
            attributes~,
          ),
        )
      }
    })
}

// file:///./stdlib.mbty
// 10|    X { Some($1) }
fn yy_action_120(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  YYObj_Option_Instr_Location__({();  Some(_dollar1) })
}

// file:///./parser.mbty
// 1457|    "=" expression { $2 }
fn yy_action_128(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[1].0 is YYObj_Instr_Location_(_dollar2)
  YYObj_Instr_Location_({();  _dollar2 })
}

// file:///./parser.mbty
// 1461|    ELEM ident ":" reference_type "=" "[" expression_list "]" ";" {
// 1462|      let (name, rt, l) = ($2, $4, $7)
// 1463|      fn(attributes) {
// 1464|        annot(
// 1465|          $sloc,
// 1466|          ModuleField::Elem(
// 1467|            name~,
// 1468|            reftype=rt,
// 1469|            mode=EPassive,
// 1470|            init=l,
// 1471|            attributes~,
// 1472|          ),
// 1473|        )
// 1474|      }
// 1475|    }
fn yy_action_129(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[1].0 is YYObj_Ident(_dollar2)
  guard _args[3].0 is YYObj_RefType(_dollar4)
  guard _args[6].0 is YYObj_Array_Instr_Location__(_dollar7)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj__Attributes_____Annotated_ModuleField_Location___Location_({(); 
      let (name, rt, l) = (_dollar2, _dollar4, _dollar7)
      fn(attributes) {
        annot(
          (_symbol_start_pos, _end_pos),
          ModuleField::Elem(
            name~,
            reftype=rt,
            mode=EPassive,
            init=l,
            attributes~,
          ),
        )
      }
    })
}

// file:///./parser.mbty
// 1260|    expression { $1 }
fn yy_action_130(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  YYObj_Instr_Location_({();  _dollar1 })
}

// file:///./parser.mbty
// 1476|    ELEM ident ":" reference_type "@" ident "[" constant_expression "]" "=" "["
// 1477|    expression_list "]" ";" {
// 1478|      let (name, rt, tab, off, l) = ($2, $4, $6, $8, $12)
// 1479|      fn(attributes) {
// 1480|        annot(
// 1481|          $sloc,
// 1482|          ModuleField::Elem(
// 1483|            name~,
// 1484|            reftype=rt,
// 1485|            mode=EActive(tab, off),
// 1486|            init=l,
// 1487|            attributes~,
// 1488|          ),
// 1489|        )
// 1490|      }
// 1491|    }
fn yy_action_131(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[1].0 is YYObj_Ident(_dollar2)
  guard _args[3].0 is YYObj_RefType(_dollar4)
  guard _args[5].0 is YYObj_Ident(_dollar6)
  guard _args[7].0 is YYObj_Instr_Location_(_dollar8)
  guard _args[11].0 is YYObj_Array_Instr_Location__(_dollar12)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj__Attributes_____Annotated_ModuleField_Location___Location_({(); 
      let (name, rt, tab, off, l) = (_dollar2, _dollar4, _dollar6, _dollar8, _dollar12)
      fn(attributes) {
        annot(
          (_symbol_start_pos, _end_pos),
          ModuleField::Elem(
            name~,
            reftype=rt,
            mode=EActive(tab, off),
            init=l,
            attributes~,
          ),
        )
      }
    })
}

// file:///./parser.mbty
// 1501|    list_of(attribute) definition { FPlain(attributed($sloc, $1, $2)) }
fn yy_action_132(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[0].0 is YYObj_Array_Attribute_(_dollar1)
  guard _args[1].0 is YYObj__Attributes_____Annotated_ModuleField_Location___Location_(_dollar2)
  YYObj_RawField({();  FPlain(attributed((_symbol_start_pos, _end_pos), _dollar1, _dollar2)) })
}

// file:///./parser.mbty
// 1502|    IMPORT STRING import_item {
// 1503|      FPlain(annot($sloc, ModuleField::Import(module_=$2, decl=$3)))
// 1504|    }
fn yy_action_133(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[1].0 is YYObj_LocString(_dollar2)
  guard _args[2].0 is YYObj_Annotated__ast_ImportDecl__Location_(_dollar3)
  YYObj_RawField({(); 
      FPlain(annot((_symbol_start_pos, _end_pos), ModuleField::Import(module_=_dollar2, decl=_dollar3)))
    })
}

// file:///./parser.mbty
// 1505|    IMPORT STRING "{" semi_list(import_item) "}" {
// 1506|      FPlain(annot($sloc, ModuleField::ImportGroup(module_=$2, decls=$4)))
// 1507|    }
fn yy_action_134(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[1].0 is YYObj_LocString(_dollar2)
  guard _args[3].0 is YYObj_Array_Annotated__ast_ImportDecl__Location__(_dollar4)
  YYObj_RawField({(); 
      FPlain(annot((_symbol_start_pos, _end_pos), ModuleField::ImportGroup(module_=_dollar2, decls=_dollar4)))
    })
}

// file:///./parser.mbty
// 789|    ";" semi_list(X) { $2 }
fn yy_action_135(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_Annotated__ast_ImportDecl__Location__(_dollar2)
  YYObj_Array_Annotated__ast_ImportDecl__Location__({();  _dollar2 })
}

// file:///./parser.mbty
// 790|    X semi_list(X) { [$1, ..$2] }
fn yy_action_136(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Annotated__ast_ImportDecl__Location_(_dollar1)
  guard _args[1].0 is YYObj_Array_Annotated__ast_ImportDecl__Location__(_dollar2)
  YYObj_Array_Annotated__ast_ImportDecl__Location__({();  [_dollar1, .._dollar2] })
}

// file:///./parser.mbty
// 788|    { [] }
fn yy_action_137(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Array_Annotated__ast_ImportDecl__Location__({();  [] })
}

// file:///./parser.mbty
// 578|    ident { $1 }
fn yy_action_138(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Ident(_dollar1)
  YYObj_Ident({();  _dollar1 })
}

// file:///./parser.mbty
// 592|    FN function_name boption("!") ioption(fundecl_type) optional_function_type {
// 593|      let (ex2, t) = match $4 {
// 594|        Some((e, ty)) => (e, Some(ty))
// 595|        None => (false, None)
// 596|      }
// 597|      if $3 && ex2 {
// 598|        record_error(loc_of($sloc), "Duplicate exact marker '!'.")
// 599|      }
// 600|      ($2, t, decl_sign($sloc, t, $5), $3 || ex2)
// 601|    }
fn yy_action_139(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_140(_args[2].2, _args[3:3])
  guard _sub_action_0_result is YYObj_Option__Bool__Ident__(_dollar4)
  guard _args[2].0 is YYObj_Bool(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[1].0 is YYObj_Ident(_dollar2)
  guard _args[3].0 is YYObj_FuncType_(_dollar5)
  YYObj__Ident__Ident___FuncType___Bool_({(); 
      let (ex2, t) = match _dollar4 {
        Some((e, ty)) => (e, Some(ty))
        None => (false, None)
      }
      if _dollar3 && ex2 {
        record_error(loc_of((_symbol_start_pos, _end_pos)), "Duplicate exact marker '!'.")
      }
      (_dollar2, t, decl_sign((_symbol_start_pos, _end_pos), t, _dollar5), _dollar3 || ex2)
    })
}

// file:///./stdlib.mbty
// 9|    { None }
fn yy_action_140(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Option__Bool__Ident__({();  None })
}

// file:///./parser.mbty
// 592|    FN function_name boption("!") ioption(fundecl_type) optional_function_type {
// 593|      let (ex2, t) = match $4 {
// 594|        Some((e, ty)) => (e, Some(ty))
// 595|        None => (false, None)
// 596|      }
// 597|      if $3 && ex2 {
// 598|        record_error(loc_of($sloc), "Duplicate exact marker '!'.")
// 599|      }
// 600|      ($2, t, decl_sign($sloc, t, $5), $3 || ex2)
// 601|    }
fn yy_action_141(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_142(_args[2].2, _args[3:4])
  guard _sub_action_0_result is YYObj_Option__Bool__Ident__(_dollar4)
  guard _args[2].0 is YYObj_Bool(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[1].0 is YYObj_Ident(_dollar2)
  guard _args[4].0 is YYObj_FuncType_(_dollar5)
  YYObj__Ident__Ident___FuncType___Bool_({(); 
      let (ex2, t) = match _dollar4 {
        Some((e, ty)) => (e, Some(ty))
        None => (false, None)
      }
      if _dollar3 && ex2 {
        record_error(loc_of((_symbol_start_pos, _end_pos)), "Duplicate exact marker '!'.")
      }
      (_dollar2, t, decl_sign((_symbol_start_pos, _end_pos), t, _dollar5), _dollar3 || ex2)
    })
}

// file:///./stdlib.mbty
// 10|    X { Some($1) }
fn yy_action_142(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj__Bool__Ident_(_dollar1)
  YYObj_Option__Bool__Ident__({();  Some(_dollar1) })
}

// file:///./parser.mbty
// 605|    ":" boption("!") type_name { ($2, $3) }
fn yy_action_143(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[1].0 is YYObj_Bool(_dollar2)
  guard _args[2].0 is YYObj_Ident(_dollar3)
  YYObj__Bool__Ident_({();  (_dollar2, _dollar3) })
}

// file:///./parser.mbty
// 629|    TAG tag_name ioption(tag_type) optional_function_type {
// 630|      ($2, $3, decl_sign($sloc, $3, $4))
// 631|    }
fn yy_action_144(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_145(_args[1].2, _args[2:2])
  guard _args[1].0 is YYObj_Ident(_dollar2)
  guard _sub_action_0_result is YYObj_Option_Ident_(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[2].0 is YYObj_FuncType_(_dollar4)
  YYObj__Ident__Ident___FuncType__({(); 
      (_dollar2, _dollar3, decl_sign((_symbol_start_pos, _end_pos), _dollar3, _dollar4))
    })
}

// file:///./stdlib.mbty
// 9|    { None }
fn yy_action_145(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Option_Ident_({();  None })
}

// file:///./parser.mbty
// 586|    option(function_type(FN)) { $1 }
fn yy_action_146(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Option_FuncType_(_dollar1)
  YYObj_FuncType_({();  _dollar1 })
}

// file:///./parser.mbty
// 629|    TAG tag_name ioption(tag_type) optional_function_type {
// 630|      ($2, $3, decl_sign($sloc, $3, $4))
// 631|    }
fn yy_action_147(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_148(_args[1].2, _args[2:3])
  guard _args[1].0 is YYObj_Ident(_dollar2)
  guard _sub_action_0_result is YYObj_Option_Ident_(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[3].0 is YYObj_FuncType_(_dollar4)
  YYObj__Ident__Ident___FuncType__({(); 
      (_dollar2, _dollar3, decl_sign((_symbol_start_pos, _end_pos), _dollar3, _dollar4))
    })
}

// file:///./stdlib.mbty
// 10|    X { Some($1) }
fn yy_action_148(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Ident(_dollar1)
  YYObj_Option_Ident_({();  Some(_dollar1) })
}

// file:///./parser.mbty
// 391|    ident { $1 }
fn yy_action_149(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Ident(_dollar1)
  YYObj_Ident({();  _dollar1 })
}

// file:///./parser.mbty
// 635|    ":" type_name { $2 }
fn yy_action_150(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[1].0 is YYObj_Ident(_dollar2)
  YYObj_Ident({();  _dollar2 })
}

// file:///./parser.mbty
// 560|    "(" parameter_list ")" ioption(result_arrow) {
// 561|      { params: $2, results: $4.unwrap_or([]) }
// 562|    }
fn yy_action_151(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_37(_args[2].2, _args[3:4])
  guard _args[1].0 is YYObj_Array_Annotated__Ident___ValType___Location__(_dollar2)
  guard _sub_action_0_result is YYObj_Option_Array_ValType__(_dollar4)
  YYObj_FuncType({(); 
      { params: _dollar2, results: _dollar4.unwrap_or([]) }
    })
}

// file:///./parser.mbty
// 560|    "(" parameter_list ")" ioption(result_arrow) {
// 561|      { params: $2, results: $4.unwrap_or([]) }
// 562|    }
fn yy_action_152(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_39(_args[2].2, _args[3:3])
  guard _args[1].0 is YYObj_Array_Annotated__Ident___ValType___Location__(_dollar2)
  guard _sub_action_0_result is YYObj_Option_Array_ValType__(_dollar4)
  YYObj_FuncType({(); 
      { params: _dollar2, results: _dollar4.unwrap_or([]) }
    })
}

// file:///./stdlib.mbty
// 5|    X { Some($1) }
fn yy_action_153(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_FuncType(_dollar1)
  YYObj_Option_FuncType_({();  Some(_dollar1) })
}

// file:///./stdlib.mbty
// 4|    { None }
fn yy_action_154(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Option_FuncType_({();  None })
}

// file:///./parser.mbty
// 1255|    LET { true }
fn yy_action_155(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Bool({();  true })
}

// file:///./parser.mbty
// 1256|    CONST { false }
fn yy_action_156(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Bool({();  false })
}

// file:///./parser.mbty
// 1523|    list_of(attribute) import_kind_decl ";" {
// 1524|      let (id, kind) = $2
// 1525|      annot($sloc, { id, kind, attributes: $1 })
// 1526|    }
fn yy_action_157(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[1].0 is YYObj__Ident___ast_ImportKind_(_dollar2)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[0].0 is YYObj_Array_Attribute_(_dollar1)
  YYObj_Annotated__ast_ImportDecl__Location_({(); 
      let (id, kind) = _dollar2
      annot((_symbol_start_pos, _end_pos), { id, kind, attributes: _dollar1 })
    })
}

// file:///./parser.mbty
// 1530|    fundecl {
// 1531|      let (name, typ, sign, exact) = $1
// 1532|      (name, Func(typ~, sign~, exact~))
// 1533|    }
fn yy_action_158(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj__Ident__Ident___FuncType___Bool_(_dollar1)
  YYObj__Ident___ast_ImportKind_({(); 
      let (name, typ, sign, exact) = _dollar1
      (name, Func(typ~, sign~, exact~))
    })
}

// file:///./parser.mbty
// 1534|    globalmut ident ":" value_type { ($2, Global(mut_=$1, typ=$4)) }
fn yy_action_159(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[1].0 is YYObj_Ident(_dollar2)
  guard _args[0].0 is YYObj_Bool(_dollar1)
  guard _args[3].0 is YYObj_ValType(_dollar4)
  YYObj__Ident___ast_ImportKind_({();  (_dollar2, Global(mut_=_dollar1, typ=_dollar4)) })
}

// file:///./parser.mbty
// 1535|    tag_signature {
// 1536|      let (name, typ, sign) = $1
// 1537|      (name, Tag(typ~, sign~))
// 1538|    }
fn yy_action_160(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj__Ident__Ident___FuncType__(_dollar1)
  YYObj__Ident___ast_ImportKind_({(); 
      let (name, typ, sign) = _dollar1
      (name, Tag(typ~, sign~))
    })
}

// file:///./parser.mbty
// 1539|    MEMORY ident ":" address_type ioption(mem_limits) ioption(mem_pagesize)
// 1540|    boption(SHARED) {
// 1541|      (
// 1542|        $2,
// 1543|        Memory(
// 1544|          address_type=$4,
// 1545|          limits=$5,
// 1546|          page_size_log2=$6,
// 1547|          shared=$7,
// 1548|        ),
// 1549|      )
// 1550|    }
fn yy_action_161(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_70(_args[3].2, _args[4:4])
  let _sub_action_1_result = yy_action_71(_args[3].2, _args[4:4])
  guard _args[1].0 is YYObj_Ident(_dollar2)
  guard _args[3].0 is YYObj_AddressType(_dollar4)
  guard _sub_action_0_result is YYObj_Option__UInt64__UInt64___(_dollar5)
  guard _sub_action_1_result is YYObj_Option_Int_(_dollar6)
  guard _args[4].0 is YYObj_Bool(_dollar7)
  YYObj__Ident___ast_ImportKind_({(); 
      (
        _dollar2,
        Memory(
          address_type=_dollar4,
          limits=_dollar5,
          page_size_log2=_dollar6,
          shared=_dollar7,
        ),
      )
    })
}

// file:///./parser.mbty
// 1539|    MEMORY ident ":" address_type ioption(mem_limits) ioption(mem_pagesize)
// 1540|    boption(SHARED) {
// 1541|      (
// 1542|        $2,
// 1543|        Memory(
// 1544|          address_type=$4,
// 1545|          limits=$5,
// 1546|          page_size_log2=$6,
// 1547|          shared=$7,
// 1548|        ),
// 1549|      )
// 1550|    }
fn yy_action_162(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_70(_args[3].2, _args[4:4])
  let _sub_action_1_result = yy_action_74(_args[3].2, _args[4:5])
  guard _args[1].0 is YYObj_Ident(_dollar2)
  guard _args[3].0 is YYObj_AddressType(_dollar4)
  guard _sub_action_0_result is YYObj_Option__UInt64__UInt64___(_dollar5)
  guard _sub_action_1_result is YYObj_Option_Int_(_dollar6)
  guard _args[5].0 is YYObj_Bool(_dollar7)
  YYObj__Ident___ast_ImportKind_({(); 
      (
        _dollar2,
        Memory(
          address_type=_dollar4,
          limits=_dollar5,
          page_size_log2=_dollar6,
          shared=_dollar7,
        ),
      )
    })
}

// file:///./parser.mbty
// 1368|    PAGESIZE INT { page_size_log2($loc($2), $2) }
fn yy_action_163(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _start_pos_of_item1 = _args[1].1
  let _end_pos_of_item1 = _args[1].2
  guard _args[1].0 is YYObj_String(_dollar2)
  YYObj_Int({();  page_size_log2((_start_pos_of_item1, _end_pos_of_item1), _dollar2) })
}

// file:///./parser.mbty
// 1539|    MEMORY ident ":" address_type ioption(mem_limits) ioption(mem_pagesize)
// 1540|    boption(SHARED) {
// 1541|      (
// 1542|        $2,
// 1543|        Memory(
// 1544|          address_type=$4,
// 1545|          limits=$5,
// 1546|          page_size_log2=$6,
// 1547|          shared=$7,
// 1548|        ),
// 1549|      )
// 1550|    }
fn yy_action_164(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_77(_args[3].2, _args[4:5])
  let _sub_action_1_result = yy_action_71(_args[4].2, _args[5:5])
  guard _args[1].0 is YYObj_Ident(_dollar2)
  guard _args[3].0 is YYObj_AddressType(_dollar4)
  guard _sub_action_0_result is YYObj_Option__UInt64__UInt64___(_dollar5)
  guard _sub_action_1_result is YYObj_Option_Int_(_dollar6)
  guard _args[5].0 is YYObj_Bool(_dollar7)
  YYObj__Ident___ast_ImportKind_({(); 
      (
        _dollar2,
        Memory(
          address_type=_dollar4,
          limits=_dollar5,
          page_size_log2=_dollar6,
          shared=_dollar7,
        ),
      )
    })
}

// file:///./stdlib.mbty
// 9|    { None }
fn yy_action_71(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Option_Int_({();  None })
}

// file:///./parser.mbty
// 1539|    MEMORY ident ":" address_type ioption(mem_limits) ioption(mem_pagesize)
// 1540|    boption(SHARED) {
// 1541|      (
// 1542|        $2,
// 1543|        Memory(
// 1544|          address_type=$4,
// 1545|          limits=$5,
// 1546|          page_size_log2=$6,
// 1547|          shared=$7,
// 1548|        ),
// 1549|      )
// 1550|    }
fn yy_action_165(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_77(_args[3].2, _args[4:5])
  let _sub_action_1_result = yy_action_74(_args[4].2, _args[5:6])
  guard _args[1].0 is YYObj_Ident(_dollar2)
  guard _args[3].0 is YYObj_AddressType(_dollar4)
  guard _sub_action_0_result is YYObj_Option__UInt64__UInt64___(_dollar5)
  guard _sub_action_1_result is YYObj_Option_Int_(_dollar6)
  guard _args[6].0 is YYObj_Bool(_dollar7)
  YYObj__Ident___ast_ImportKind_({(); 
      (
        _dollar2,
        Memory(
          address_type=_dollar4,
          limits=_dollar5,
          page_size_log2=_dollar6,
          shared=_dollar7,
        ),
      )
    })
}

// file:///./stdlib.mbty
// 10|    X { Some($1) }
fn yy_action_74(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Int(_dollar1)
  YYObj_Option_Int_({();  Some(_dollar1) })
}

// file:///./stdlib.mbty
// 20|    X { true }
fn yy_action_166(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Bool({();  true })
}

// file:///./stdlib.mbty
// 19|    { false }
fn yy_action_167(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Bool({();  false })
}

// file:///./parser.mbty
// 1292|    IDENT { address_type_of($sloc, $1) }
fn yy_action_168(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[0].0 is YYObj_String(_dollar1)
  YYObj_AddressType({();  address_type_of((_symbol_start_pos, _end_pos), _dollar1) })
}

// file:///./parser.mbty
// 1551|    TABLE ident ":" ioption(address_type) reference_type ioption(mem_limits) {
// 1552|      ($2, Table(address_type=$4.unwrap_or(I32), reftype=$5, limits=$6))
// 1553|    }
fn yy_action_169(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_117(_args[2].2, _args[3:3])
  let _sub_action_1_result = yy_action_77(_args[3].2, _args[4:5])
  guard _args[1].0 is YYObj_Ident(_dollar2)
  guard _sub_action_0_result is YYObj_Option_AddressType_(_dollar4)
  guard _args[3].0 is YYObj_RefType(_dollar5)
  guard _sub_action_1_result is YYObj_Option__UInt64__UInt64___(_dollar6)
  YYObj__Ident___ast_ImportKind_({(); 
      (_dollar2, Table(address_type=_dollar4.unwrap_or(I32), reftype=_dollar5, limits=_dollar6))
    })
}

// file:///./parser.mbty
// 1551|    TABLE ident ":" ioption(address_type) reference_type ioption(mem_limits) {
// 1552|      ($2, Table(address_type=$4.unwrap_or(I32), reftype=$5, limits=$6))
// 1553|    }
fn yy_action_170(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_117(_args[2].2, _args[3:3])
  let _sub_action_1_result = yy_action_70(_args[3].2, _args[4:4])
  guard _args[1].0 is YYObj_Ident(_dollar2)
  guard _sub_action_0_result is YYObj_Option_AddressType_(_dollar4)
  guard _args[3].0 is YYObj_RefType(_dollar5)
  guard _sub_action_1_result is YYObj_Option__UInt64__UInt64___(_dollar6)
  YYObj__Ident___ast_ImportKind_({(); 
      (_dollar2, Table(address_type=_dollar4.unwrap_or(I32), reftype=_dollar5, limits=_dollar6))
    })
}

// file:///./stdlib.mbty
// 9|    { None }
fn yy_action_117(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Option_AddressType_({();  None })
}

// file:///./parser.mbty
// 1296|    "[" INT ioption(limit_max) "]" {
// 1297|      (u64_of_int_literal($loc($2), $2), $3)
// 1298|    }
fn yy_action_171(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_172(_args[1].2, _args[2:2])
  let _start_pos_of_item1 = _args[1].1
  let _end_pos_of_item1 = _args[1].2
  guard _args[1].0 is YYObj_String(_dollar2)
  guard _sub_action_0_result is YYObj_Option_UInt64_(_dollar3)
  YYObj__UInt64__UInt64__({(); 
      (u64_of_int_literal((_start_pos_of_item1, _end_pos_of_item1), _dollar2), _dollar3)
    })
}

// file:///./stdlib.mbty
// 9|    { None }
fn yy_action_172(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Option_UInt64_({();  None })
}

// file:///./parser.mbty
// 1296|    "[" INT ioption(limit_max) "]" {
// 1297|      (u64_of_int_literal($loc($2), $2), $3)
// 1298|    }
fn yy_action_173(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_174(_args[1].2, _args[2:3])
  let _start_pos_of_item1 = _args[1].1
  let _end_pos_of_item1 = _args[1].2
  guard _args[1].0 is YYObj_String(_dollar2)
  guard _sub_action_0_result is YYObj_Option_UInt64_(_dollar3)
  YYObj__UInt64__UInt64__({(); 
      (u64_of_int_literal((_start_pos_of_item1, _end_pos_of_item1), _dollar2), _dollar3)
    })
}

// file:///./stdlib.mbty
// 10|    X { Some($1) }
fn yy_action_174(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_UInt64(_dollar1)
  YYObj_Option_UInt64_({();  Some(_dollar1) })
}

// file:///./parser.mbty
// 1302|    "," INT { u64_of_int_literal($loc($2), $2) }
fn yy_action_175(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _start_pos_of_item1 = _args[1].1
  let _end_pos_of_item1 = _args[1].2
  guard _args[1].0 is YYObj_String(_dollar2)
  YYObj_UInt64({();  u64_of_int_literal((_start_pos_of_item1, _end_pos_of_item1), _dollar2) })
}

// file:///./parser.mbty
// 1551|    TABLE ident ":" ioption(address_type) reference_type ioption(mem_limits) {
// 1552|      ($2, Table(address_type=$4.unwrap_or(I32), reftype=$5, limits=$6))
// 1553|    }
fn yy_action_176(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_124(_args[2].2, _args[3:4])
  let _sub_action_1_result = yy_action_77(_args[4].2, _args[5:6])
  guard _args[1].0 is YYObj_Ident(_dollar2)
  guard _sub_action_0_result is YYObj_Option_AddressType_(_dollar4)
  guard _args[4].0 is YYObj_RefType(_dollar5)
  guard _sub_action_1_result is YYObj_Option__UInt64__UInt64___(_dollar6)
  YYObj__Ident___ast_ImportKind_({(); 
      (_dollar2, Table(address_type=_dollar4.unwrap_or(I32), reftype=_dollar5, limits=_dollar6))
    })
}

// file:///./stdlib.mbty
// 10|    X { Some($1) }
fn yy_action_77(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj__UInt64__UInt64__(_dollar1)
  YYObj_Option__UInt64__UInt64___({();  Some(_dollar1) })
}

// file:///./parser.mbty
// 1551|    TABLE ident ":" ioption(address_type) reference_type ioption(mem_limits) {
// 1552|      ($2, Table(address_type=$4.unwrap_or(I32), reftype=$5, limits=$6))
// 1553|    }
fn yy_action_177(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_124(_args[2].2, _args[3:4])
  let _sub_action_1_result = yy_action_70(_args[4].2, _args[5:5])
  guard _args[1].0 is YYObj_Ident(_dollar2)
  guard _sub_action_0_result is YYObj_Option_AddressType_(_dollar4)
  guard _args[4].0 is YYObj_RefType(_dollar5)
  guard _sub_action_1_result is YYObj_Option__UInt64__UInt64___(_dollar6)
  YYObj__Ident___ast_ImportKind_({(); 
      (_dollar2, Table(address_type=_dollar4.unwrap_or(I32), reftype=_dollar5, limits=_dollar6))
    })
}

// file:///./stdlib.mbty
// 9|    { None }
fn yy_action_70(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Option__UInt64__UInt64___({();  None })
}

// file:///./stdlib.mbty
// 10|    X { Some($1) }
fn yy_action_124(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_AddressType(_dollar1)
  YYObj_Option_AddressType_({();  Some(_dollar1) })
}

// file:///./parser.mbty
// 1612|    EOF { [] }
fn yy_action_178(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Array_RawField_({();  [] })
}

// file:///./parser.mbty
// 1613|    ";" raw_parse { $2 }
fn yy_action_179(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_RawField_(_dollar2)
  YYObj_Array_RawField_({();  _dollar2 })
}

// file:///./parser.mbty
// 1614|    module_field raw_parse { [$1, ..$2] }
fn yy_action_180(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_RawField(_dollar1)
  guard _args[1].0 is YYObj_Array_RawField_(_dollar2)
  YYObj_Array_RawField_({();  [_dollar1, .._dollar2] })
}

// file:///./parser.mbty
// 451|    expression { $1 }
fn yy_action_181(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  YYObj_Instr_Location_({();  _dollar1 })
}

// file:///./parser.mbty
// 467|    "," IF "(" condition ")" { Some({ desc: $4, info: loc_of($loc($2)) }) }
fn yy_action_182(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[3].0 is YYObj_Cond(_dollar4)
  let _start_pos_of_item1 = _args[1].1
  let _end_pos_of_item1 = _args[1].2
  YYObj_Annotated_Cond__Location__({();  Some({ desc: _dollar4, info: loc_of((_start_pos_of_item1, _end_pos_of_item1)) }) })
}

// file:///./parser.mbty
// 471|    "#" "[" attribute_name "=" attribute_expression attribute_guard "]" {
// 472|      {
// 473|        attr_name: $3,
// 474|        attr_value: Some($5),
// 475|        attr_guard: $6,
// 476|        attr_span: loc_of($sloc),
// 477|      }
// 478|    }
fn yy_action_183(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[2].0 is YYObj_String(_dollar3)
  guard _args[4].0 is YYObj_Instr_Location_(_dollar5)
  guard _args[5].0 is YYObj_Annotated_Cond__Location__(_dollar6)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Attribute({(); 
      {
        attr_name: _dollar3,
        attr_value: Some(_dollar5),
        attr_guard: _dollar6,
        attr_span: loc_of((_symbol_start_pos, _end_pos)),
      }
    })
}

// file:///./parser.mbty
// 1053|    BR_ON_CAST_FAIL label reference_type expression %prec prec_branch {
// 1054|      with_loc($sloc, BrOnCastFail($2, $3, $4))
// 1055|    }
fn yy_action_184(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[1].0 is YYObj_Ident(_dollar2)
  guard _args[2].0 is YYObj_RefType(_dollar3)
  guard _args[3].0 is YYObj_Instr_Location_(_dollar4)
  YYObj_Instr_Location_({(); 
      with_loc((_symbol_start_pos, _end_pos), BrOnCastFail(_dollar2, _dollar3, _dollar4))
    })
}

// file:///./parser.mbty
// 1059|    BR_ON_CAST_FAIL label boption("?") descriptor_operand expression %prec prec_branch {
// 1060|      with_loc($sloc, BrOnCastDescEqFail($2, $3, $5, $4))
// 1061|    }
fn yy_action_185(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[1].0 is YYObj_Ident(_dollar2)
  guard _args[2].0 is YYObj_Bool(_dollar3)
  guard _args[4].0 is YYObj_Instr_Location_(_dollar5)
  guard _args[3].0 is YYObj_Instr_Location_(_dollar4)
  YYObj_Instr_Location_({(); 
      with_loc((_symbol_start_pos, _end_pos), BrOnCastDescEqFail(_dollar2, _dollar3, _dollar5, _dollar4))
    })
}

// file:///./parser.mbty
// 1050|    BR_ON_CAST label reference_type expression %prec prec_branch {
// 1051|      with_loc($sloc, BrOnCast($2, $3, $4))
// 1052|    }
fn yy_action_186(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[1].0 is YYObj_Ident(_dollar2)
  guard _args[2].0 is YYObj_RefType(_dollar3)
  guard _args[3].0 is YYObj_Instr_Location_(_dollar4)
  YYObj_Instr_Location_({(); 
      with_loc((_symbol_start_pos, _end_pos), BrOnCast(_dollar2, _dollar3, _dollar4))
    })
}

// file:///./parser.mbty
// 1056|    BR_ON_CAST label boption("?") descriptor_operand expression %prec prec_branch {
// 1057|      with_loc($sloc, BrOnCastDescEq($2, $3, $5, $4))
// 1058|    }
fn yy_action_187(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[1].0 is YYObj_Ident(_dollar2)
  guard _args[2].0 is YYObj_Bool(_dollar3)
  guard _args[4].0 is YYObj_Instr_Location_(_dollar5)
  guard _args[3].0 is YYObj_Instr_Location_(_dollar4)
  YYObj_Instr_Location_({(); 
      with_loc((_symbol_start_pos, _end_pos), BrOnCastDescEq(_dollar2, _dollar3, _dollar5, _dollar4))
    })
}

// file:///./parser.mbty
// 1047|    BR_ON_NON_NULL label expression %prec prec_branch {
// 1048|      with_loc($sloc, BrOnNonNull($2, $3))
// 1049|    }
fn yy_action_188(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[1].0 is YYObj_Ident(_dollar2)
  guard _args[2].0 is YYObj_Instr_Location_(_dollar3)
  YYObj_Instr_Location_({(); 
      with_loc((_symbol_start_pos, _end_pos), BrOnNonNull(_dollar2, _dollar3))
    })
}

// file:///./parser.mbty
// 1044|    BR_ON_NULL label expression %prec prec_branch {
// 1045|      with_loc($sloc, BrOnNull($2, $3))
// 1046|    }
fn yy_action_189(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[1].0 is YYObj_Ident(_dollar2)
  guard _args[2].0 is YYObj_Instr_Location_(_dollar3)
  YYObj_Instr_Location_({(); 
      with_loc((_symbol_start_pos, _end_pos), BrOnNull(_dollar2, _dollar3))
    })
}

// file:///./parser.mbty
// 1043|    BR_IF label expression %prec prec_branch { with_loc($sloc, BrIf($2, $3)) }
fn yy_action_190(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[1].0 is YYObj_Ident(_dollar2)
  guard _args[2].0 is YYObj_Instr_Location_(_dollar3)
  YYObj_Instr_Location_({();  with_loc((_symbol_start_pos, _end_pos), BrIf(_dollar2, _dollar3)) })
}

// file:///./parser.mbty
// 1033|    "-" expression %prec prec_unary { unop($sloc, $loc($1), Neg, $2) }
fn yy_action_191(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  let _start_pos_of_item0 = _args[0].1
  let _end_pos_of_item0 = _args[0].2
  guard _args[1].0 is YYObj_Instr_Location_(_dollar2)
  YYObj_Instr_Location_({();  unop((_symbol_start_pos, _end_pos), (_start_pos_of_item0, _end_pos_of_item0), Neg, _dollar2) })
}

// file:///./parser.mbty
// 1032|    "+" expression %prec prec_unary { unop($sloc, $loc($1), Pos, $2) }
fn yy_action_192(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  let _start_pos_of_item0 = _args[0].1
  let _end_pos_of_item0 = _args[0].2
  guard _args[1].0 is YYObj_Instr_Location_(_dollar2)
  YYObj_Instr_Location_({();  unop((_symbol_start_pos, _end_pos), (_start_pos_of_item0, _end_pos_of_item0), Pos, _dollar2) })
}

// file:///./parser.mbty
// 1031|    "!" expression %prec prec_unary { unop($sloc, $loc($1), Not, $2) }
fn yy_action_193(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  let _start_pos_of_item0 = _args[0].1
  let _end_pos_of_item0 = _args[0].2
  guard _args[1].0 is YYObj_Instr_Location_(_dollar2)
  YYObj_Instr_Location_({();  unop((_symbol_start_pos, _end_pos), (_start_pos_of_item0, _end_pos_of_item0), Not, _dollar2) })
}

// file:///./parser.mbty
// 979|    "[" ident "|" array_body "]" { with_loc($sloc, $4(Some($2))) }
fn yy_action_194(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[3].0 is YYObj__Ident______InstrDesc_Location_(_dollar4)
  guard _args[1].0 is YYObj_Ident(_dollar2)
  YYObj_Instr_Location_({();  with_loc((_symbol_start_pos, _end_pos), _dollar4(Some(_dollar2))) })
}

// file:///./parser.mbty
// 1070|    ident "@" expression ";" length_expression {
// 1071|      fn(t) { ArraySegment(t, $1, $3, $5) }
// 1072|    }
fn yy_action_195(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Ident(_dollar1)
  guard _args[2].0 is YYObj_Instr_Location_(_dollar3)
  guard _args[4].0 is YYObj_Instr_Location_(_dollar5)
  YYObj__Ident______InstrDesc_Location_({(); 
      fn(t) { ArraySegment(t, _dollar1, _dollar3, _dollar5) }
    })
}

// file:///./parser.mbty
// 1068|    expression ";" length_expression { fn(t) { Array(t, $1, $3) } }
fn yy_action_196(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  guard _args[2].0 is YYObj_Instr_Location_(_dollar3)
  YYObj__Ident______InstrDesc_Location_({();  fn(t) { Array(t, _dollar1, _dollar3) } })
}

// file:///./parser.mbty
// 978|    "[" array_body "]" { with_loc($sloc, $2(None)) }
fn yy_action_197(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[1].0 is YYObj__Ident______InstrDesc_Location_(_dollar2)
  YYObj_Instr_Location_({();  with_loc((_symbol_start_pos, _end_pos), _dollar2(None)) })
}

// file:///./parser.mbty
// 1067|    expression_list { fn(t) { ArrayFixed(t, $1) } }
fn yy_action_198(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Instr_Location__(_dollar1)
  YYObj__Ident______InstrDesc_Location_({();  fn(t) { ArrayFixed(t, _dollar1) } })
}

// file:///./parser.mbty
// 916|    expression { $1 }
fn yy_action_199(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  YYObj_Instr_Location_({();  _dollar1 })
}

// file:///./parser.mbty
// 964|    "{" ident "|" structure "}" { with_loc($sloc, Struct(Some($2), $4)) }
fn yy_action_200(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[1].0 is YYObj_Ident(_dollar2)
  guard _args[3].0 is YYObj_Array__Ident__Instr_Location____(_dollar4)
  YYObj_Instr_Location_({();  with_loc((_symbol_start_pos, _end_pos), Struct(Some(_dollar2), _dollar4)) })
}

// file:///./parser.mbty
// 970|    "{" ident "|" ".." "}" { with_loc($sloc, StructDefault(Some($2))) }
fn yy_action_201(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[1].0 is YYObj_Ident(_dollar2)
  YYObj_Instr_Location_({();  with_loc((_symbol_start_pos, _end_pos), StructDefault(Some(_dollar2))) })
}

// file:///./parser.mbty
// 965|    "{" structure_field "," structure "}" {
// 966|      with_loc($sloc, Struct(None, [$2, ..$4]))
// 967|    }
fn yy_action_202(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[1].0 is YYObj__Ident__Instr_Location___(_dollar2)
  guard _args[3].0 is YYObj_Array__Ident__Instr_Location____(_dollar4)
  YYObj_Instr_Location_({(); 
      with_loc((_symbol_start_pos, _end_pos), Struct(None, [_dollar2, .._dollar4]))
    })
}

// file:///./parser.mbty
// 968|    "{" structure_field "}" { with_loc($sloc, Struct(None, [$2])) }
fn yy_action_203(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[1].0 is YYObj__Ident__Instr_Location___(_dollar2)
  YYObj_Instr_Location_({();  with_loc((_symbol_start_pos, _end_pos), Struct(None, [_dollar2])) })
}

// file:///./parser.mbty
// 969|    "{" "}" { with_loc($sloc, Struct(None, [])) }
fn yy_action_204(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Instr_Location_({();  with_loc((_symbol_start_pos, _end_pos), Struct(None, [])) })
}

// file:///./parser.mbty
// 971|    "{" ".." "}" { with_loc($sloc, StructDefault(None)) }
fn yy_action_205(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Instr_Location_({();  with_loc((_symbol_start_pos, _end_pos), StructDefault(None)) })
}

// file:///./parser.mbty
// 754|    sep_trailing(",", structure_field) { $1 }
fn yy_action_206(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__Ident__Instr_Location____(_dollar1)
  YYObj_Array__Ident__Instr_Location____({();  _dollar1 })
}

// file:///./parser.mbty
// 972|    "{" descriptor_operand "|" structure "}" {
// 973|      with_loc($sloc, StructDesc($2, $4))
// 974|    }
fn yy_action_207(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[1].0 is YYObj_Instr_Location_(_dollar2)
  guard _args[3].0 is YYObj_Array__Ident__Instr_Location____(_dollar4)
  YYObj_Instr_Location_({(); 
      with_loc((_symbol_start_pos, _end_pos), StructDesc(_dollar2, _dollar4))
    })
}

// file:///./parser.mbty
// 975|    "{" descriptor_operand "|" ".." "}" {
// 976|      with_loc($sloc, StructDefaultDesc($2))
// 977|    }
fn yy_action_208(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[1].0 is YYObj_Instr_Location_(_dollar2)
  YYObj_Instr_Location_({(); 
      with_loc((_symbol_start_pos, _end_pos), StructDefaultDesc(_dollar2))
    })
}

// file:///./parser.mbty
// 235|    non_empty_sep_trailing(SEP, X) { $1 }
fn yy_action_209(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__Ident__Instr_Location____(_dollar1)
  YYObj_Array__Ident__Instr_Location____({();  _dollar1 })
}

// file:///./parser.mbty
// 356|    ident { $1 }
fn yy_action_210(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Ident(_dollar1)
  YYObj_Ident({();  _dollar1 })
}

// file:///./parser.mbty
// 747|    field_name ":" expression { ($1, Some($3)) }
fn yy_action_211(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Ident(_dollar1)
  guard _args[2].0 is YYObj_Instr_Location_(_dollar3)
  YYObj__Ident__Instr_Location___({();  (_dollar1, Some(_dollar3)) })
}

// file:///./parser.mbty
// 953|    "(" expression "," expression_list ")" {
// 954|      with_loc($sloc, Sequence([$2, ..$4]))
// 955|    }
fn yy_action_212(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[1].0 is YYObj_Instr_Location_(_dollar2)
  guard _args[3].0 is YYObj_Array_Instr_Location__(_dollar4)
  YYObj_Instr_Location_({(); 
      with_loc((_symbol_start_pos, _end_pos), Sequence([_dollar2, .._dollar4]))
    })
}

// file:///./parser.mbty
// 893|    expression { $1 }
fn yy_action_213(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  YYObj_Instr_Location_({();  _dollar1 })
}

// file:///./parser.mbty
// 908|    expression { $1 }
fn yy_action_214(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  YYObj_Instr_Location_({();  _dollar1 })
}

// file:///./parser.mbty
// 333|    "&" boption("?") FN function_type_as { Func(nullable=$2, sign=$4) }
fn yy_action_215(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[1].0 is YYObj_Bool(_dollar2)
  guard _args[3].0 is YYObj_FuncType(_dollar4)
  YYObj_CastType({();  Func(nullable=_dollar2, sign=_dollar4) })
}

// file:///./parser.mbty
// 570|    function_type(AS) { $1 }
fn yy_action_216(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_FuncType(_dollar1)
  YYObj_FuncType({();  _dollar1 })
}

// file:///./parser.mbty
// 544|    sep_trailing(",", function_parameter) { $1 }
fn yy_action_217(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Annotated__Ident___ValType___Location__(_dollar1)
  YYObj_Array_Annotated__Ident___ValType___Location__({();  _dollar1 })
}

// file:///./parser.mbty
// 235|    non_empty_sep_trailing(SEP, X) { $1 }
fn yy_action_218(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Annotated__Ident___ValType___Location__(_dollar1)
  YYObj_Array_Annotated__Ident___ValType___Location__({();  _dollar1 })
}

// file:///./parser.mbty
// 560|    "(" parameter_list ")" ioption(result_arrow) {
// 561|      { params: $2, results: $4.unwrap_or([]) }
// 562|    }
fn yy_action_219(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_37(_args[2].2, _args[3:4])
  guard _args[1].0 is YYObj_Array_Annotated__Ident___ValType___Location__(_dollar2)
  guard _sub_action_0_result is YYObj_Option_Array_ValType__(_dollar4)
  YYObj_FuncType({(); 
      { params: _dollar2, results: _dollar4.unwrap_or([]) }
    })
}

// file:///./parser.mbty
// 560|    "(" parameter_list ")" ioption(result_arrow) {
// 561|      { params: $2, results: $4.unwrap_or([]) }
// 562|    }
fn yy_action_220(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_39(_args[2].2, _args[3:3])
  guard _args[1].0 is YYObj_Array_Annotated__Ident___ValType___Location__(_dollar2)
  guard _sub_action_0_result is YYObj_Option_Array_ValType__(_dollar4)
  YYObj_FuncType({(); 
      { params: _dollar2, results: _dollar4.unwrap_or([]) }
    })
}

// file:///./parser.mbty
// 539|    ident ":" value_type { annot($sloc, (Some($1), $3)) }
fn yy_action_221(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[0].0 is YYObj_Ident(_dollar1)
  guard _args[2].0 is YYObj_ValType(_dollar3)
  YYObj_Annotated__Ident___ValType___Location_({();  annot((_symbol_start_pos, _end_pos), (Some(_dollar1), _dollar3)) })
}

// file:///./parser.mbty
// 540|    value_type { annot($sloc, (None, $1)) }
fn yy_action_222(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[0].0 is YYObj_ValType(_dollar1)
  YYObj_Annotated__Ident___ValType___Location_({();  annot((_symbol_start_pos, _end_pos), (None, _dollar1)) })
}

// file:///./parser.mbty
// 230|    X SEP non_empty_sep_trailing(SEP, X) { [$1, ..$3] }
fn yy_action_223(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Annotated__Ident___ValType___Location_(_dollar1)
  guard _args[2].0 is YYObj_Array_Annotated__Ident___ValType___Location__(_dollar3)
  YYObj_Array_Annotated__Ident___ValType___Location__({();  [_dollar1, .._dollar3] })
}

// file:///./parser.mbty
// 229|    X SEP { [$1] }
fn yy_action_224(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Annotated__Ident___ValType___Location_(_dollar1)
  YYObj_Array_Annotated__Ident___ValType___Location__({();  [_dollar1] })
}

// file:///./parser.mbty
// 228|    X { [$1] }
fn yy_action_225(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Annotated__Ident___ValType___Location_(_dollar1)
  YYObj_Array_Annotated__Ident___ValType___Location__({();  [_dollar1] })
}

// file:///./parser.mbty
// 234|    { [] }
fn yy_action_226(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Array_Annotated__Ident___ValType___Location__({();  [] })
}

// file:///./parser.mbty
// 331|    IDENT { cast_type_of($loc($1), $1) }
fn yy_action_227(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _start_pos_of_item0 = _args[0].1
  let _end_pos_of_item0 = _args[0].2
  guard _args[0].0 is YYObj_String(_dollar1)
  YYObj_CastType({();  cast_type_of((_start_pos_of_item0, _end_pos_of_item0), _dollar1) })
}

// file:///./parser.mbty
// 332|    reference_type { Value(Ref($1)) }
fn yy_action_228(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_RefType(_dollar1)
  YYObj_CastType({();  Value(Ref(_dollar1)) })
}

// file:///./parser.mbty
// 981|    expression AS cast_type { with_loc($sloc, Cast($1, $3)) }
fn yy_action_229(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  guard _args[2].0 is YYObj_CastType(_dollar3)
  YYObj_Instr_Location_({();  with_loc((_symbol_start_pos, _end_pos), Cast(_dollar1, _dollar3)) })
}

// file:///./parser.mbty
// 900|    DESCRIPTOR "(" expression ")" { $3 }
fn yy_action_230(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[2].0 is YYObj_Instr_Location_(_dollar3)
  YYObj_Instr_Location_({();  _dollar3 })
}

// file:///./parser.mbty
// 812|    block_label DO option(block_type) braced_block {
// 813|      with_loc($sloc, Block(label=$1, typ=blocktype($3), block=$4))
// 814|    }
fn yy_action_231(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[0].0 is YYObj_Ident_(_dollar1)
  guard _args[2].0 is YYObj_Option_FuncType_(_dollar3)
  guard _args[3].0 is YYObj_Body_Location_(_dollar4)
  YYObj_Instr_Location_({(); 
      with_loc((_symbol_start_pos, _end_pos), Block(label=_dollar1, typ=blocktype(_dollar3), block=_dollar4))
    })
}

// file:///./parser.mbty
// 815|    block_label WHILE condition_expression braced_block {
// 816|      with_loc($sloc, While(label=$1, cond=$3, step=None, block=$4))
// 817|    }
fn yy_action_232(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[0].0 is YYObj_Ident_(_dollar1)
  guard _args[2].0 is YYObj_Instr_Location_(_dollar3)
  guard _args[3].0 is YYObj_Body_Location_(_dollar4)
  YYObj_Instr_Location_({(); 
      with_loc((_symbol_start_pos, _end_pos), While(label=_dollar1, cond=_dollar3, step=None, block=_dollar4))
    })
}

// file:///./parser.mbty
// 822|    block_label WHILE condition_expression ":" "(" hinted_statement ")"
// 823|    braced_block {
// 824|      with_loc($sloc, While(label=$1, cond=$3, step=Some($6), block=$8))
// 825|    }
fn yy_action_233(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[0].0 is YYObj_Ident_(_dollar1)
  guard _args[2].0 is YYObj_Instr_Location_(_dollar3)
  guard _args[5].0 is YYObj_Instr_Location_(_dollar6)
  guard _args[7].0 is YYObj_Body_Location_(_dollar8)
  YYObj_Instr_Location_({(); 
      with_loc((_symbol_start_pos, _end_pos), While(label=_dollar1, cond=_dollar3, step=Some(_dollar6), block=_dollar8))
    })
}

// file:///./parser.mbty
// 1133|    hint_attr hinted_statement { hinted($1.0, [$1.1], $2) }
fn yy_action_234(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj___Position__Position___HintSetter_(_dollar1)
  guard _args[1].0 is YYObj_Instr_Location_(_dollar2)
  YYObj_Instr_Location_({();  hinted(_dollar1.0, [_dollar1.1], _dollar2) })
}

// file:///./parser.mbty
// 1132|    statement { $1 }
fn yy_action_235(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  YYObj_Instr_Location_({();  _dollar1 })
}

// file:///./parser.mbty
// 826|    block_label LOOP option(block_type) braced_block {
// 827|      with_loc($sloc, Loop(label=$1, typ=blocktype($3), block=$4))
// 828|    }
fn yy_action_236(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[0].0 is YYObj_Ident_(_dollar1)
  guard _args[2].0 is YYObj_Option_FuncType_(_dollar3)
  guard _args[3].0 is YYObj_Body_Location_(_dollar4)
  YYObj_Instr_Location_({(); 
      with_loc((_symbol_start_pos, _end_pos), Loop(label=_dollar1, typ=blocktype(_dollar3), block=_dollar4))
    })
}

// file:///./parser.mbty
// 829|    block_label IF condition_expression option(if_block_type) braced_block
// 830|    ioption(else_branch) {
// 831|      with_loc(
// 832|        $sloc,
// 833|        If(
// 834|          label=$1,
// 835|          typ=blocktype($4),
// 836|          cond=$3,
// 837|          if_block=$5,
// 838|          else_block=$6,
// 839|        ),
// 840|      )
// 841|    }
fn yy_action_237(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_238(_args[4].2, _args[5:6])
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[0].0 is YYObj_Ident_(_dollar1)
  guard _args[3].0 is YYObj_Option_FuncType_(_dollar4)
  guard _args[2].0 is YYObj_Instr_Location_(_dollar3)
  guard _args[4].0 is YYObj_Body_Location_(_dollar5)
  guard _sub_action_0_result is YYObj_Option_Body_Location__(_dollar6)
  YYObj_Instr_Location_({(); 
      with_loc(
        (_symbol_start_pos, _end_pos),
        If(
          label=_dollar1,
          typ=blocktype(_dollar4),
          cond=_dollar3,
          if_block=_dollar5,
          else_block=_dollar6,
        ),
      )
    })
}

// file:///./stdlib.mbty
// 10|    X { Some($1) }
fn yy_action_238(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Body_Location_(_dollar1)
  YYObj_Option_Body_Location__({();  Some(_dollar1) })
}

// file:///./parser.mbty
// 881|    ELSE braced_block { $2 }
fn yy_action_239(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[1].0 is YYObj_Body_Location_(_dollar2)
  YYObj_Body_Location_({();  _dollar2 })
}

// file:///./parser.mbty
// 829|    block_label IF condition_expression option(if_block_type) braced_block
// 830|    ioption(else_branch) {
// 831|      with_loc(
// 832|        $sloc,
// 833|        If(
// 834|          label=$1,
// 835|          typ=blocktype($4),
// 836|          cond=$3,
// 837|          if_block=$5,
// 838|          else_block=$6,
// 839|        ),
// 840|      )
// 841|    }
fn yy_action_240(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_241(_args[4].2, _args[5:5])
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[0].0 is YYObj_Ident_(_dollar1)
  guard _args[3].0 is YYObj_Option_FuncType_(_dollar4)
  guard _args[2].0 is YYObj_Instr_Location_(_dollar3)
  guard _args[4].0 is YYObj_Body_Location_(_dollar5)
  guard _sub_action_0_result is YYObj_Option_Body_Location__(_dollar6)
  YYObj_Instr_Location_({(); 
      with_loc(
        (_symbol_start_pos, _end_pos),
        If(
          label=_dollar1,
          typ=blocktype(_dollar4),
          cond=_dollar3,
          if_block=_dollar5,
          else_block=_dollar6,
        ),
      )
    })
}

// file:///./stdlib.mbty
// 9|    { None }
fn yy_action_241(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Option_Body_Location__({();  None })
}

// file:///./parser.mbty
// 877|    "=>" block_type { $2 }
fn yy_action_242(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[1].0 is YYObj_FuncType(_dollar2)
  YYObj_FuncType({();  _dollar2 })
}

// file:///./stdlib.mbty
// 5|    X { Some($1) }
fn yy_action_243(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_FuncType(_dollar1)
  YYObj_Option_FuncType_({();  Some(_dollar1) })
}

// file:///./stdlib.mbty
// 4|    { None }
fn yy_action_244(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Option_FuncType_({();  None })
}

// file:///./parser.mbty
// 912|    expression { $1 }
fn yy_action_245(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  YYObj_Instr_Location_({();  _dollar1 })
}

// file:///./parser.mbty
// 842|    block_label TRY option(block_type) braced_block CATCH "["
// 843|    sep_trailing(",", catch) "]" {
// 844|      with_loc(
// 845|        $sloc,
// 846|        TryTable(label=$1, typ=blocktype($3), catches=$7, block=$4),
// 847|      )
// 848|    }
fn yy_action_246(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[0].0 is YYObj_Ident_(_dollar1)
  guard _args[2].0 is YYObj_Option_FuncType_(_dollar3)
  guard _args[6].0 is YYObj_Array_Catch_(_dollar7)
  guard _args[3].0 is YYObj_Body_Location_(_dollar4)
  YYObj_Instr_Location_({(); 
      with_loc(
        (_symbol_start_pos, _end_pos),
        TryTable(label=_dollar1, typ=blocktype(_dollar3), catches=_dollar7, block=_dollar4),
      )
    })
}

// file:///./parser.mbty
// 235|    non_empty_sep_trailing(SEP, X) { $1 }
fn yy_action_247(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Catch_(_dollar1)
  YYObj_Array_Catch_({();  _dollar1 })
}

// file:///./parser.mbty
// 687|    ident "->" label { Catch($1, $3) }
fn yy_action_248(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Ident(_dollar1)
  guard _args[2].0 is YYObj_Ident(_dollar3)
  YYObj_Catch({();  Catch(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 688|    ident "&" "->" label { CatchRef($1, $4) }
fn yy_action_249(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Ident(_dollar1)
  guard _args[3].0 is YYObj_Ident(_dollar4)
  YYObj_Catch({();  CatchRef(_dollar1, _dollar4) })
}

// file:///./parser.mbty
// 689|    "_" "->" label { CatchAll($3) }
fn yy_action_250(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[2].0 is YYObj_Ident(_dollar3)
  YYObj_Catch({();  CatchAll(_dollar3) })
}

// file:///./parser.mbty
// 690|    "_" "&" "->" label { CatchAllRef($4) }
fn yy_action_251(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[3].0 is YYObj_Ident(_dollar4)
  YYObj_Catch({();  CatchAllRef(_dollar4) })
}

// file:///./parser.mbty
// 230|    X SEP non_empty_sep_trailing(SEP, X) { [$1, ..$3] }
fn yy_action_252(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Catch(_dollar1)
  guard _args[2].0 is YYObj_Array_Catch_(_dollar3)
  YYObj_Array_Catch_({();  [_dollar1, .._dollar3] })
}

// file:///./parser.mbty
// 229|    X SEP { [$1] }
fn yy_action_253(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Catch(_dollar1)
  YYObj_Array_Catch_({();  [_dollar1] })
}

// file:///./parser.mbty
// 228|    X { [$1] }
fn yy_action_254(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Catch(_dollar1)
  YYObj_Array_Catch_({();  [_dollar1] })
}

// file:///./parser.mbty
// 234|    { [] }
fn yy_action_255(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Array_Catch_({();  [] })
}

// file:///./parser.mbty
// 730|    "_" "=>" braced_block {
// 731|      { arm_tag: None, arm_ref: false, arm_types: [], arm_body: $3 }
// 732|    }
fn yy_action_256(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[2].0 is YYObj_Body_Location_(_dollar3)
  YYObj_TryCatchArm_Location_({(); 
      { arm_tag: None, arm_ref: false, arm_types: [], arm_body: _dollar3 }
    })
}

// file:///./parser.mbty
// 733|    "_" "&" "=>" braced_block {
// 734|      { arm_tag: None, arm_ref: true, arm_types: [], arm_body: $4 }
// 735|    }
fn yy_action_257(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[3].0 is YYObj_Body_Location_(_dollar4)
  YYObj_TryCatchArm_Location_({(); 
      { arm_tag: None, arm_ref: true, arm_types: [], arm_body: _dollar4 }
    })
}

// file:///./parser.mbty
// 849|    block_label TRY option(block_type) braced_block CATCH "{"
// 850|    semi_list(catch_arm) option(catch_all_arm) "}" {
// 851|      let arms = $7
// 852|      match $8 {
// 853|        Some(a) => arms.push(a)
// 854|        None => ()
// 855|      }
// 856|      with_loc(
// 857|        $sloc,
// 858|        TryCatch(label=$1, typ=blocktype($3), block=$4, arms~),
// 859|      )
// 860|    }
fn yy_action_258(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[6].0 is YYObj_Array_TryCatchArm_Location__(_dollar7)
  guard _args[7].0 is YYObj_Option_TryCatchArm_Location__(_dollar8)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[0].0 is YYObj_Ident_(_dollar1)
  guard _args[2].0 is YYObj_Option_FuncType_(_dollar3)
  guard _args[3].0 is YYObj_Body_Location_(_dollar4)
  YYObj_Instr_Location_({(); 
      let arms = _dollar7
      match _dollar8 {
        Some(a) => arms.push(a)
        None => ()
      }
      with_loc(
        (_symbol_start_pos, _end_pos),
        TryCatch(label=_dollar1, typ=blocktype(_dollar3), block=_dollar4, arms~),
      )
    })
}

// file:///./stdlib.mbty
// 5|    X { Some($1) }
fn yy_action_259(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_TryCatchArm_Location_(_dollar1)
  YYObj_Option_TryCatchArm_Location__({();  Some(_dollar1) })
}

// file:///./stdlib.mbty
// 4|    { None }
fn yy_action_260(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Option_TryCatchArm_Location__({();  None })
}

// file:///./parser.mbty
// 721|    ident "=>" braced_block {
// 722|      { arm_tag: Some($1), arm_ref: false, arm_types: [], arm_body: $3 }
// 723|    }
fn yy_action_261(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Ident(_dollar1)
  guard _args[2].0 is YYObj_Body_Location_(_dollar3)
  YYObj_TryCatchArm_Location_({(); 
      { arm_tag: Some(_dollar1), arm_ref: false, arm_types: [], arm_body: _dollar3 }
    })
}

// file:///./parser.mbty
// 724|    ident "&" "=>" braced_block {
// 725|      { arm_tag: Some($1), arm_ref: true, arm_types: [], arm_body: $4 }
// 726|    }
fn yy_action_262(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Ident(_dollar1)
  guard _args[3].0 is YYObj_Body_Location_(_dollar4)
  YYObj_TryCatchArm_Location_({(); 
      { arm_tag: Some(_dollar1), arm_ref: true, arm_types: [], arm_body: _dollar4 }
    })
}

// file:///./parser.mbty
// 789|    ";" semi_list(X) { $2 }
fn yy_action_263(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_TryCatchArm_Location__(_dollar2)
  YYObj_Array_TryCatchArm_Location__({();  _dollar2 })
}

// file:///./parser.mbty
// 790|    X semi_list(X) { [$1, ..$2] }
fn yy_action_264(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_TryCatchArm_Location_(_dollar1)
  guard _args[1].0 is YYObj_Array_TryCatchArm_Location__(_dollar2)
  YYObj_Array_TryCatchArm_Location__({();  [_dollar1, .._dollar2] })
}

// file:///./parser.mbty
// 788|    { [] }
fn yy_action_265(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Array_TryCatchArm_Location__({();  [] })
}

// file:///./parser.mbty
// 664|    sep_trailing(",", block_param_type) { $1 }
fn yy_action_266(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Annotated__Ident___ValType___Location__(_dollar1)
  YYObj_Array_Annotated__Ident___ValType___Location__({();  _dollar1 })
}

// file:///./parser.mbty
// 337|    non_empty_sep_trailing(",", value_type) { $1 }
fn yy_action_267(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_ValType_(_dollar1)
  YYObj_Array_ValType_({();  _dollar1 })
}

// file:///./parser.mbty
// 341|    "(" ")" { [] }
fn yy_action_268(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Array_ValType_({();  [] })
}

// file:///./parser.mbty
// 343|    "(" result_type_ ")" { $2 }
fn yy_action_269(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_ValType_(_dollar2)
  YYObj_Array_ValType_({();  _dollar2 })
}

// file:///./parser.mbty
// 230|    X SEP non_empty_sep_trailing(SEP, X) { [$1, ..$3] }
fn yy_action_270(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_ValType(_dollar1)
  guard _args[2].0 is YYObj_Array_ValType_(_dollar3)
  YYObj_Array_ValType_({();  [_dollar1, .._dollar3] })
}

// file:///./parser.mbty
// 229|    X SEP { [$1] }
fn yy_action_271(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_ValType(_dollar1)
  YYObj_Array_ValType_({();  [_dollar1] })
}

// file:///./parser.mbty
// 228|    X { [$1] }
fn yy_action_272(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_ValType(_dollar1)
  YYObj_Array_ValType_({();  [_dollar1] })
}

// file:///./parser.mbty
// 342|    value_type { [$1] }
fn yy_action_273(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_ValType(_dollar1)
  YYObj_Array_ValType_({();  [_dollar1] })
}

// file:///./parser.mbty
// 566|    "->" result_type { $2 }
fn yy_action_274(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_ValType_(_dollar2)
  YYObj_Array_ValType_({();  _dollar2 })
}

// file:///./parser.mbty
// 668|    "(" parameter_types ")" ioption(result_arrow) {
// 669|      { params: $2, results: $4.unwrap_or([]) }
// 670|    }
fn yy_action_275(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_37(_args[2].2, _args[3:4])
  guard _args[1].0 is YYObj_Array_Annotated__Ident___ValType___Location__(_dollar2)
  guard _sub_action_0_result is YYObj_Option_Array_ValType__(_dollar4)
  YYObj_FuncType({(); 
      { params: _dollar2, results: _dollar4.unwrap_or([]) }
    })
}

// file:///./stdlib.mbty
// 10|    X { Some($1) }
fn yy_action_37(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_ValType_(_dollar1)
  YYObj_Option_Array_ValType__({();  Some(_dollar1) })
}

// file:///./parser.mbty
// 668|    "(" parameter_types ")" ioption(result_arrow) {
// 669|      { params: $2, results: $4.unwrap_or([]) }
// 670|    }
fn yy_action_276(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_39(_args[2].2, _args[3:3])
  guard _args[1].0 is YYObj_Array_Annotated__Ident___ValType___Location__(_dollar2)
  guard _sub_action_0_result is YYObj_Option_Array_ValType__(_dollar4)
  YYObj_FuncType({(); 
      { params: _dollar2, results: _dollar4.unwrap_or([]) }
    })
}

// file:///./stdlib.mbty
// 9|    { None }
fn yy_action_39(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Option_Array_ValType__({();  None })
}

// file:///./parser.mbty
// 235|    non_empty_sep_trailing(SEP, X) { $1 }
fn yy_action_277(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Annotated__Ident___ValType___Location__(_dollar1)
  YYObj_Array_Annotated__Ident___ValType___Location__({();  _dollar1 })
}

// file:///./parser.mbty
// 660|    value_type { annot($sloc, (None, $1)) }
fn yy_action_278(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[0].0 is YYObj_ValType(_dollar1)
  YYObj_Annotated__Ident___ValType___Location_({();  annot((_symbol_start_pos, _end_pos), (None, _dollar1)) })
}

// file:///./parser.mbty
// 230|    X SEP non_empty_sep_trailing(SEP, X) { [$1, ..$3] }
fn yy_action_279(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Annotated__Ident___ValType___Location_(_dollar1)
  guard _args[2].0 is YYObj_Array_Annotated__Ident___ValType___Location__(_dollar3)
  YYObj_Array_Annotated__Ident___ValType___Location__({();  [_dollar1, .._dollar3] })
}

// file:///./parser.mbty
// 229|    X SEP { [$1] }
fn yy_action_280(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Annotated__Ident___ValType___Location_(_dollar1)
  YYObj_Array_Annotated__Ident___ValType___Location__({();  [_dollar1] })
}

// file:///./parser.mbty
// 228|    X { [$1] }
fn yy_action_281(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Annotated__Ident___ValType___Location_(_dollar1)
  YYObj_Array_Annotated__Ident___ValType___Location__({();  [_dollar1] })
}

// file:///./parser.mbty
// 234|    { [] }
fn yy_action_282(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Array_Annotated__Ident___ValType___Location__({();  [] })
}

// file:///./parser.mbty
// 671|    value_type { { params: [], results: [$1] } }
fn yy_action_283(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_ValType(_dollar1)
  YYObj_FuncType({();  { params: [], results: [_dollar1] } })
}

// file:///./parser.mbty
// 739|    "_" "=>" braced_block { $3 }
fn yy_action_284(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[2].0 is YYObj_Body_Location_(_dollar3)
  YYObj_Body_Location_({();  _dollar3 })
}

// file:///./parser.mbty
// 861|    block_label TRY_LEGACY option(block_type) braced_block CATCH "{"
// 862|    semi_list(legacy_catch) option(legacy_catch_all) "}" {
// 863|      with_loc(
// 864|        $sloc,
// 865|        Try(
// 866|          label=$1,
// 867|          typ=blocktype($3),
// 868|          block=$4,
// 869|          catches=$7,
// 870|          catch_all=$8,
// 871|        ),
// 872|      )
// 873|    }
fn yy_action_285(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[0].0 is YYObj_Ident_(_dollar1)
  guard _args[2].0 is YYObj_Option_FuncType_(_dollar3)
  guard _args[3].0 is YYObj_Body_Location_(_dollar4)
  guard _args[6].0 is YYObj_Array__Ident__Body_Location___(_dollar7)
  guard _args[7].0 is YYObj_Option_Body_Location__(_dollar8)
  YYObj_Instr_Location_({(); 
      with_loc(
        (_symbol_start_pos, _end_pos),
        Try(
          label=_dollar1,
          typ=blocktype(_dollar3),
          block=_dollar4,
          catches=_dollar7,
          catch_all=_dollar8,
        ),
      )
    })
}

// file:///./stdlib.mbty
// 5|    X { Some($1) }
fn yy_action_286(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Body_Location_(_dollar1)
  YYObj_Option_Body_Location__({();  Some(_dollar1) })
}

// file:///./stdlib.mbty
// 4|    { None }
fn yy_action_287(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Option_Body_Location__({();  None })
}

// file:///./parser.mbty
// 679|    "{" statement_list "}" { annot($sloc, $2) }
fn yy_action_288(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[1].0 is YYObj_Array_Instr_Location__(_dollar2)
  YYObj_Body_Location_({();  annot((_symbol_start_pos, _end_pos), _dollar2) })
}

// file:///./parser.mbty
// 1186|    raw_statement_list { process_stmts($1) }
fn yy_action_289(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_RawStmt_(_dollar1)
  YYObj_Array_Instr_Location__({();  process_stmts(_dollar1) })
}

// file:///./parser.mbty
// 1234|    statement option(semi_then_statements) {
// 1235|      [Plain($1), ..$2.unwrap_or([])]
// 1236|    }
fn yy_action_290(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  guard _args[1].0 is YYObj_Option_Array_RawStmt__(_dollar2)
  YYObj_Array_RawStmt_({(); 
      [Plain(_dollar1), .._dollar2.unwrap_or([])]
    })
}

// file:///./parser.mbty
// 1084|    hint_attr expression %prec prec_block { hinted($1.0, [$1.1], $2) }
fn yy_action_291(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj___Position__Position___HintSetter_(_dollar1)
  guard _args[1].0 is YYObj_Instr_Location_(_dollar2)
  YYObj_Instr_Location_({();  hinted(_dollar1.0, [_dollar1.1], _dollar2) })
}

// file:///./parser.mbty
// 1246|    "#" "[" IF "(" condition ")" "]" braced_block { If($sloc, $5, $8) }
fn yy_action_292(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[4].0 is YYObj_Cond(_dollar5)
  guard _args[7].0 is YYObj_Body_Location_(_dollar8)
  YYObj_RawStmt({();  If((_symbol_start_pos, _end_pos), _dollar5, _dollar8) })
}

// file:///./parser.mbty
// 1564|    ident condition_relop condition_literal {
// 1565|      Cmp($2, Var({ desc: $1.name, info: $1.loc }), $3)
// 1566|    }
fn yy_action_293(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[1].0 is YYObj__wasm_types_CmpOp(_dollar2)
  guard _args[0].0 is YYObj_Ident(_dollar1)
  guard _args[2].0 is YYObj_Cond(_dollar3)
  YYObj_Cond({(); 
      Cmp(_dollar2, Var({ desc: _dollar1.name, info: _dollar1.loc }), _dollar3)
    })
}

// file:///./parser.mbty
// 1583|    "(" INT "," INT "," INT ")" {
// 1584|      Version(
// 1585|        int_of_version_component($loc($2), $2),
// 1586|        int_of_version_component($loc($4), $4),
// 1587|        int_of_version_component($loc($6), $6),
// 1588|      )
// 1589|    }
fn yy_action_294(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _start_pos_of_item1 = _args[1].1
  let _end_pos_of_item1 = _args[1].2
  guard _args[1].0 is YYObj_String(_dollar2)
  let _start_pos_of_item3 = _args[3].1
  let _end_pos_of_item3 = _args[3].2
  guard _args[3].0 is YYObj_String(_dollar4)
  let _start_pos_of_item5 = _args[5].1
  let _end_pos_of_item5 = _args[5].2
  guard _args[5].0 is YYObj_String(_dollar6)
  YYObj_Cond({(); 
      Version(
        int_of_version_component((_start_pos_of_item1, _end_pos_of_item1), _dollar2),
        int_of_version_component((_start_pos_of_item3, _end_pos_of_item3), _dollar4),
        int_of_version_component((_start_pos_of_item5, _end_pos_of_item5), _dollar6),
      )
    })
}

// file:///./parser.mbty
// 1590|    STRING { Str($1) }
fn yy_action_295(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_LocString(_dollar1)
  YYObj_Cond({();  Str(_dollar1) })
}

// file:///./parser.mbty
// 1567|    ident "(" sep_trailing(",", condition) ")" {
// 1568|      match ($1.name, $3) {
// 1569|        ("all", l) => And(l)
// 1570|        ("any", l) => Or(l)
// 1571|        ("not", [c]) => Not(c)
// 1572|        _ =>
// 1573|          fail_at(
// 1574|            loc_of($sloc),
// 1575|            "Expected 'all', 'any', or 'not(<cond>)' in a condition.",
// 1576|            default=And($3),
// 1577|          )
// 1578|      }
// 1579|    }
fn yy_action_296(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Ident(_dollar1)
  guard _args[2].0 is YYObj_Array_Cond_(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Cond({(); 
      match (_dollar1.name, _dollar3) {
        ("all", l) => And(l)
        ("any", l) => Or(l)
        ("not", [c]) => Not(c)
        _ =>
          fail_at(
            loc_of((_symbol_start_pos, _end_pos)),
            "Expected 'all', 'any', or 'not(<cond>)' in a condition.",
            default=And(_dollar3),
          )
      }
    })
}

// file:///./parser.mbty
// 235|    non_empty_sep_trailing(SEP, X) { $1 }
fn yy_action_297(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Cond_(_dollar1)
  YYObj_Array_Cond_({();  _dollar1 })
}

// file:///./parser.mbty
// 230|    X SEP non_empty_sep_trailing(SEP, X) { [$1, ..$3] }
fn yy_action_298(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Cond(_dollar1)
  guard _args[2].0 is YYObj_Array_Cond_(_dollar3)
  YYObj_Array_Cond_({();  [_dollar1, .._dollar3] })
}

// file:///./parser.mbty
// 229|    X SEP { [$1] }
fn yy_action_299(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Cond(_dollar1)
  YYObj_Array_Cond_({();  [_dollar1] })
}

// file:///./parser.mbty
// 228|    X { [$1] }
fn yy_action_300(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Cond(_dollar1)
  YYObj_Array_Cond_({();  [_dollar1] })
}

// file:///./parser.mbty
// 234|    { [] }
fn yy_action_301(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Array_Cond_({();  [] })
}

// file:///./parser.mbty
// 1594|    "=" { Eq }
fn yy_action_302(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj__wasm_types_CmpOp({();  Eq })
}

// file:///./parser.mbty
// 1595|    "!=" { Ne }
fn yy_action_303(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj__wasm_types_CmpOp({();  Ne })
}

// file:///./parser.mbty
// 1596|    "<" { Lt }
fn yy_action_304(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj__wasm_types_CmpOp({();  Lt })
}

// file:///./parser.mbty
// 1597|    ">" { Gt }
fn yy_action_305(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj__wasm_types_CmpOp({();  Gt })
}

// file:///./parser.mbty
// 1598|    "<=" { Le }
fn yy_action_306(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj__wasm_types_CmpOp({();  Le })
}

// file:///./parser.mbty
// 1599|    ">=" { Ge }
fn yy_action_307(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj__wasm_types_CmpOp({();  Ge })
}

// file:///./parser.mbty
// 1563|    ident { Var({ desc: $1.name, info: $1.loc }) }
fn yy_action_308(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Ident(_dollar1)
  YYObj_Cond({();  Var({ desc: _dollar1.name, info: _dollar1.loc }) })
}

// file:///./parser.mbty
// 1247|    "#" "[" ELSE "]" braced_block { Else($sloc, $5) }
fn yy_action_309(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[4].0 is YYObj_Body_Location_(_dollar5)
  YYObj_RawStmt({();  Else((_symbol_start_pos, _end_pos), _dollar5) })
}

// file:///./parser.mbty
// 1145|    "_" "=" expression { with_loc($sloc, Let([(None, None)], Some($3))) }
fn yy_action_310(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[2].0 is YYObj_Instr_Location_(_dollar3)
  YYObj_Instr_Location_({();  with_loc((_symbol_start_pos, _end_pos), Let([(None, None)], Some(_dollar3))) })
}

// file:///./parser.mbty
// 1146|    "_" ":" value_type "=" expression {
// 1147|      with_loc($sloc, Let([(None, Some($3))], Some($5)))
// 1148|    }
fn yy_action_311(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[2].0 is YYObj_ValType(_dollar3)
  guard _args[4].0 is YYObj_Instr_Location_(_dollar5)
  YYObj_Instr_Location_({(); 
      with_loc((_symbol_start_pos, _end_pos), Let([(None, Some(_dollar3))], Some(_dollar5)))
    })
}

// file:///./parser.mbty
// 1107|    "+=" { annot($sloc, Add) }
fn yy_action_312(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Annotated__ast_BinOp__Location_({();  annot((_symbol_start_pos, _end_pos), Add) })
}

// file:///./parser.mbty
// 1108|    "-=" { annot($sloc, Sub) }
fn yy_action_313(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Annotated__ast_BinOp__Location_({();  annot((_symbol_start_pos, _end_pos), Sub) })
}

// file:///./parser.mbty
// 1109|    "*=" { annot($sloc, Mul) }
fn yy_action_314(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Annotated__ast_BinOp__Location_({();  annot((_symbol_start_pos, _end_pos), Mul) })
}

// file:///./parser.mbty
// 1110|    "/=" { annot($sloc, Div(None)) }
fn yy_action_315(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Annotated__ast_BinOp__Location_({();  annot((_symbol_start_pos, _end_pos), Div(None)) })
}

// file:///./parser.mbty
// 1111|    "/s=" { annot($sloc, Div(Some(Signed))) }
fn yy_action_316(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Annotated__ast_BinOp__Location_({();  annot((_symbol_start_pos, _end_pos), Div(Some(Signed))) })
}

// file:///./parser.mbty
// 1112|    "/u=" { annot($sloc, Div(Some(Unsigned))) }
fn yy_action_317(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Annotated__ast_BinOp__Location_({();  annot((_symbol_start_pos, _end_pos), Div(Some(Unsigned))) })
}

// file:///./parser.mbty
// 1113|    "%s=" { annot($sloc, Rem(Signed)) }
fn yy_action_318(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Annotated__ast_BinOp__Location_({();  annot((_symbol_start_pos, _end_pos), Rem(Signed)) })
}

// file:///./parser.mbty
// 1114|    "%u=" { annot($sloc, Rem(Unsigned)) }
fn yy_action_319(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Annotated__ast_BinOp__Location_({();  annot((_symbol_start_pos, _end_pos), Rem(Unsigned)) })
}

// file:///./parser.mbty
// 1115|    "&=" { annot($sloc, And) }
fn yy_action_320(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Annotated__ast_BinOp__Location_({();  annot((_symbol_start_pos, _end_pos), And) })
}

// file:///./parser.mbty
// 1116|    "|=" { annot($sloc, Or) }
fn yy_action_321(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Annotated__ast_BinOp__Location_({();  annot((_symbol_start_pos, _end_pos), Or) })
}

// file:///./parser.mbty
// 1117|    "^=" { annot($sloc, Xor) }
fn yy_action_322(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Annotated__ast_BinOp__Location_({();  annot((_symbol_start_pos, _end_pos), Xor) })
}

// file:///./parser.mbty
// 1118|    "<<=" { annot($sloc, Shl) }
fn yy_action_323(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Annotated__ast_BinOp__Location_({();  annot((_symbol_start_pos, _end_pos), Shl) })
}

// file:///./parser.mbty
// 1119|    ">>s=" { annot($sloc, Shr(Signed)) }
fn yy_action_324(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Annotated__ast_BinOp__Location_({();  annot((_symbol_start_pos, _end_pos), Shr(Signed)) })
}

// file:///./parser.mbty
// 1120|    ">>u=" { annot($sloc, Shr(Unsigned)) }
fn yy_action_325(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Annotated__ast_BinOp__Location_({();  annot((_symbol_start_pos, _end_pos), Shr(Unsigned)) })
}

// file:///./parser.mbty
// 1140|    ident "=" expression { with_loc($sloc, Set($1, None, $3)) }
fn yy_action_326(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[0].0 is YYObj_Ident(_dollar1)
  guard _args[2].0 is YYObj_Instr_Location_(_dollar3)
  YYObj_Instr_Location_({();  with_loc((_symbol_start_pos, _end_pos), Set(_dollar1, None, _dollar3)) })
}

// file:///./parser.mbty
// 1149|    ident compound_assign_op expression {
// 1150|      with_loc($sloc, Set($1, Some($2), $3))
// 1151|    }
fn yy_action_327(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[0].0 is YYObj_Ident(_dollar1)
  guard _args[1].0 is YYObj_Annotated__ast_BinOp__Location_(_dollar2)
  guard _args[2].0 is YYObj_Instr_Location_(_dollar3)
  YYObj_Instr_Location_({(); 
      with_loc((_symbol_start_pos, _end_pos), Set(_dollar1, Some(_dollar2), _dollar3))
    })
}

// file:///./parser.mbty
// 1196|    blockinstr raw_statement_list { [Plain($1), ..$2] }
fn yy_action_328(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  guard _args[1].0 is YYObj_Array_RawStmt_(_dollar2)
  YYObj_Array_RawStmt_({();  [Plain(_dollar1), .._dollar2] })
}

// file:///./parser.mbty
// 1137|    plaininstr { $1 }
fn yy_action_329(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  YYObj_Instr_Location_({();  _dollar1 })
}

// file:///./parser.mbty
// 1213|    hint_attr raw_statement_list {
// 1214|      let l = $2
// 1215|      if l.length() > 0 && l[0] is Plain(i) {
// 1216|        [Plain(hinted($1.0, [$1.1], i)), ..l[1:]]
// 1217|      } else {
// 1218|        {
// 1219|          record_error(loc_of($1.0), "A hint may only prefix an instruction.")
// 1220|          l
// 1221|        }
// 1222|      }
// 1223|    }
fn yy_action_330(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_RawStmt_(_dollar2)
  guard _args[0].0 is YYObj___Position__Position___HintSetter_(_dollar1)
  YYObj_Array_RawStmt_({(); 
      let l = _dollar2
      if l.length() > 0 && l[0] is Plain(i) {
        [Plain(hinted(_dollar1.0, [_dollar1.1], i)), ..l[1:]]
      } else {
        {
          record_error(loc_of(_dollar1.0), "A hint may only prefix an instruction.")
          l
        }
      }
    })
}

// file:///./parser.mbty
// 1138|    NOP { with_loc($sloc, Nop) }
fn yy_action_331(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Instr_Location_({();  with_loc((_symbol_start_pos, _end_pos), Nop) })
}

// file:///./parser.mbty
// 1139|    UNREACHABLE { with_loc($sloc, Unreachable) }
fn yy_action_332(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Instr_Location_({();  with_loc((_symbol_start_pos, _end_pos), Unreachable) })
}

// file:///./parser.mbty
// 1153|    LET simple_pattern "=" expression {
// 1154|      with_loc($sloc, Let([($2, None)], Some($4)))
// 1155|    }
fn yy_action_333(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[1].0 is YYObj_Ident_(_dollar2)
  guard _args[3].0 is YYObj_Instr_Location_(_dollar4)
  YYObj_Instr_Location_({(); 
      with_loc((_symbol_start_pos, _end_pos), Let([(_dollar2, None)], Some(_dollar4)))
    })
}

// file:///./parser.mbty
// 1156|    LET simple_pattern ":" value_type "=" expression {
// 1157|      with_loc($sloc, Let([($2, Some($4))], Some($6)))
// 1158|    }
fn yy_action_334(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[1].0 is YYObj_Ident_(_dollar2)
  guard _args[3].0 is YYObj_ValType(_dollar4)
  guard _args[5].0 is YYObj_Instr_Location_(_dollar6)
  YYObj_Instr_Location_({(); 
      with_loc((_symbol_start_pos, _end_pos), Let([(_dollar2, Some(_dollar4))], Some(_dollar6)))
    })
}

// file:///./parser.mbty
// 1159|    LET simple_pattern ":" value_type {
// 1160|      with_loc($sloc, Let([($2, Some($4))], None))
// 1161|    }
fn yy_action_335(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[1].0 is YYObj_Ident_(_dollar2)
  guard _args[3].0 is YYObj_ValType(_dollar4)
  YYObj_Instr_Location_({(); 
      with_loc((_symbol_start_pos, _end_pos), Let([(_dollar2, Some(_dollar4))], None))
    })
}

// file:///./parser.mbty
// 1152|    LET simple_pattern { with_loc($sloc, Let([($2, None)], None)) }
fn yy_action_336(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[1].0 is YYObj_Ident_(_dollar2)
  YYObj_Instr_Location_({();  with_loc((_symbol_start_pos, _end_pos), Let([(_dollar2, None)], None)) })
}

// file:///./parser.mbty
// 1100|    sep_trailing(",", let_pattern) { $1 }
fn yy_action_337(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__Ident___ValType___(_dollar1)
  YYObj_Array__Ident___ValType___({();  _dollar1 })
}

// file:///./parser.mbty
// 1162|    LET "(" let_pattern_ ")" ioption(let_init) {
// 1163|      with_loc($sloc, Let($3, $5))
// 1164|    }
fn yy_action_338(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_339(_args[3].2, _args[4:5])
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[2].0 is YYObj_Array__Ident___ValType___(_dollar3)
  guard _sub_action_0_result is YYObj_Option_Instr_Location__(_dollar5)
  YYObj_Instr_Location_({(); 
      with_loc((_symbol_start_pos, _end_pos), Let(_dollar3, _dollar5))
    })
}

// file:///./stdlib.mbty
// 10|    X { Some($1) }
fn yy_action_339(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  YYObj_Option_Instr_Location__({();  Some(_dollar1) })
}

// file:///./parser.mbty
// 1181|    "=" expression { $2 }
fn yy_action_340(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[1].0 is YYObj_Instr_Location_(_dollar2)
  YYObj_Instr_Location_({();  _dollar2 })
}

// file:///./parser.mbty
// 1162|    LET "(" let_pattern_ ")" ioption(let_init) {
// 1163|      with_loc($sloc, Let($3, $5))
// 1164|    }
fn yy_action_341(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_342(_args[3].2, _args[4:4])
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[2].0 is YYObj_Array__Ident___ValType___(_dollar3)
  guard _sub_action_0_result is YYObj_Option_Instr_Location__(_dollar5)
  YYObj_Instr_Location_({(); 
      with_loc((_symbol_start_pos, _end_pos), Let(_dollar3, _dollar5))
    })
}

// file:///./stdlib.mbty
// 9|    { None }
fn yy_action_342(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Option_Instr_Location__({();  None })
}

// file:///./parser.mbty
// 235|    non_empty_sep_trailing(SEP, X) { $1 }
fn yy_action_343(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__Ident___ValType___(_dollar1)
  YYObj_Array__Ident___ValType___({();  _dollar1 })
}

// file:///./parser.mbty
// 534|    ident { Some($1) }
fn yy_action_344(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Ident(_dollar1)
  YYObj_Ident_({();  Some(_dollar1) })
}

// file:///./parser.mbty
// 535|    "_" { None }
fn yy_action_345(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Ident_({();  None })
}

// file:///./parser.mbty
// 1092|    simple_pattern ioption(type_annot) { ($1, $2) }
fn yy_action_346(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_60(_args[0].2, _args[1:2])
  guard _args[0].0 is YYObj_Ident_(_dollar1)
  guard _sub_action_0_result is YYObj_Option_ValType_(_dollar2)
  YYObj__Ident___ValType__({();  (_dollar1, _dollar2) })
}

// file:///./stdlib.mbty
// 10|    X { Some($1) }
fn yy_action_60(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_ValType(_dollar1)
  YYObj_Option_ValType_({();  Some(_dollar1) })
}

// file:///./parser.mbty
// 326|    IDENT { value_type_of($loc($1), $1) }
fn yy_action_347(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _start_pos_of_item0 = _args[0].1
  let _end_pos_of_item0 = _args[0].2
  guard _args[0].0 is YYObj_String(_dollar1)
  YYObj_ValType({();  value_type_of((_start_pos_of_item0, _end_pos_of_item0), _dollar1) })
}

// file:///./parser.mbty
// 327|    reference_type { Ref($1) }
fn yy_action_348(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_RefType(_dollar1)
  YYObj_ValType({();  Ref(_dollar1) })
}

// file:///./parser.mbty
// 1096|    ":" value_type { $2 }
fn yy_action_349(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[1].0 is YYObj_ValType(_dollar2)
  YYObj_ValType({();  _dollar2 })
}

// file:///./parser.mbty
// 1092|    simple_pattern ioption(type_annot) { ($1, $2) }
fn yy_action_350(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_58(_args[0].2, _args[1:1])
  guard _args[0].0 is YYObj_Ident_(_dollar1)
  guard _sub_action_0_result is YYObj_Option_ValType_(_dollar2)
  YYObj__Ident___ValType__({();  (_dollar1, _dollar2) })
}

// file:///./stdlib.mbty
// 9|    { None }
fn yy_action_58(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Option_ValType_({();  None })
}

// file:///./parser.mbty
// 230|    X SEP non_empty_sep_trailing(SEP, X) { [$1, ..$3] }
fn yy_action_351(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj__Ident___ValType__(_dollar1)
  guard _args[2].0 is YYObj_Array__Ident___ValType___(_dollar3)
  YYObj_Array__Ident___ValType___({();  [_dollar1, .._dollar3] })
}

// file:///./parser.mbty
// 229|    X SEP { [$1] }
fn yy_action_352(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj__Ident___ValType__(_dollar1)
  YYObj_Array__Ident___ValType___({();  [_dollar1] })
}

// file:///./parser.mbty
// 228|    X { [$1] }
fn yy_action_353(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj__Ident___ValType__(_dollar1)
  YYObj_Array__Ident___ValType___({();  [_dollar1] })
}

// file:///./parser.mbty
// 234|    { [] }
fn yy_action_354(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Array__Ident___ValType___({();  [] })
}

// file:///./parser.mbty
// 1165|    BR label ioption(expression) { with_loc($sloc, Br($2, $3)) }
fn yy_action_355(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_356(_args[1].2, _args[2:3])
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[1].0 is YYObj_Ident(_dollar2)
  guard _sub_action_0_result is YYObj_Option_Instr_Location__(_dollar3)
  YYObj_Instr_Location_({();  with_loc((_symbol_start_pos, _end_pos), Br(_dollar2, _dollar3)) })
}

// file:///./parser.mbty
// 1165|    BR label ioption(expression) { with_loc($sloc, Br($2, $3)) }
fn yy_action_357(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_358(_args[1].2, _args[2:2])
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[1].0 is YYObj_Ident(_dollar2)
  guard _sub_action_0_result is YYObj_Option_Instr_Location__(_dollar3)
  YYObj_Instr_Location_({();  with_loc((_symbol_start_pos, _end_pos), Br(_dollar2, _dollar3)) })
}

// file:///./parser.mbty
// 1166|    BR_TABLE "[" case_labels "]" expression {
// 1167|      let (lst, l) = $3
// 1168|      with_loc($sloc, BrTable([..lst, l], $5))
// 1169|    }
fn yy_action_359(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[2].0 is YYObj__Array_Ident___Ident_(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[4].0 is YYObj_Instr_Location_(_dollar5)
  YYObj_Instr_Location_({(); 
      let (lst, l) = _dollar3
      with_loc((_symbol_start_pos, _end_pos), BrTable([..lst, l], _dollar5))
    })
}

// file:///./parser.mbty
// 1170|    RETURN ioption(expression) { with_loc($sloc, Return($2)) }
fn yy_action_360(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_356(_args[0].2, _args[1:2])
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _sub_action_0_result is YYObj_Option_Instr_Location__(_dollar2)
  YYObj_Instr_Location_({();  with_loc((_symbol_start_pos, _end_pos), Return(_dollar2)) })
}

// file:///./stdlib.mbty
// 10|    X { Some($1) }
fn yy_action_356(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  YYObj_Option_Instr_Location__({();  Some(_dollar1) })
}

// file:///./parser.mbty
// 1170|    RETURN ioption(expression) { with_loc($sloc, Return($2)) }
fn yy_action_361(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_358(_args[0].2, _args[1:1])
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _sub_action_0_result is YYObj_Option_Instr_Location__(_dollar2)
  YYObj_Instr_Location_({();  with_loc((_symbol_start_pos, _end_pos), Return(_dollar2)) })
}

// file:///./stdlib.mbty
// 9|    { None }
fn yy_action_358(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Option_Instr_Location__({();  None })
}

// file:///./parser.mbty
// 625|    ident { $1 }
fn yy_action_362(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Ident(_dollar1)
  YYObj_Ident({();  _dollar1 })
}

// file:///./parser.mbty
// 920|    sep_trailing(",", expression) { $1 }
fn yy_action_363(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Instr_Location__(_dollar1)
  YYObj_Array_Instr_Location__({();  _dollar1 })
}

// file:///./parser.mbty
// 230|    X SEP non_empty_sep_trailing(SEP, X) { [$1, ..$3] }
fn yy_action_364(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  guard _args[2].0 is YYObj_Array_Instr_Location__(_dollar3)
  YYObj_Array_Instr_Location__({();  [_dollar1, .._dollar3] })
}

// file:///./parser.mbty
// 229|    X SEP { [$1] }
fn yy_action_365(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  YYObj_Array_Instr_Location__({();  [_dollar1] })
}

// file:///./parser.mbty
// 228|    X { [$1] }
fn yy_action_366(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  YYObj_Array_Instr_Location__({();  [_dollar1] })
}

// file:///./parser.mbty
// 1171|    THROW tag_name "(" expression_list ")" {
// 1172|      with_loc($sloc, Throw($2, $4))
// 1173|    }
fn yy_action_367(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[1].0 is YYObj_Ident(_dollar2)
  guard _args[3].0 is YYObj_Array_Instr_Location__(_dollar4)
  YYObj_Instr_Location_({(); 
      with_loc((_symbol_start_pos, _end_pos), Throw(_dollar2, _dollar4))
    })
}

// file:///./parser.mbty
// 1174|    THROW_REF expression { with_loc($sloc, ThrowRef($2)) }
fn yy_action_368(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[1].0 is YYObj_Instr_Location_(_dollar2)
  YYObj_Instr_Location_({();  with_loc((_symbol_start_pos, _end_pos), ThrowRef(_dollar2)) })
}

// file:///./parser.mbty
// 927|    expression { $1 }
fn yy_action_369(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  YYObj_Instr_Location_({();  _dollar1 })
}

// file:///./parser.mbty
// 493|    "#" "[" IDENT "(" sep_trailing(",", hint_target) ")" "]" {
// 494|      ($sloc, targets_of_attr($sloc, $3, $5))
// 495|    }
fn yy_action_370(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[2].0 is YYObj_String(_dollar3)
  guard _args[4].0 is YYObj_Array__Ident__Int__(_dollar5)
  YYObj___Position__Position___HintSetter_({(); 
      ((_symbol_start_pos, _end_pos), targets_of_attr((_symbol_start_pos, _end_pos), _dollar3, _dollar5))
    })
}

// file:///./parser.mbty
// 235|    non_empty_sep_trailing(SEP, X) { $1 }
fn yy_action_371(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Array__Ident__Int__(_dollar1)
  YYObj_Array__Ident__Int__({();  _dollar1 })
}

// file:///./parser.mbty
// 501|    ident ":" target_fraction { ($1, $3) }
fn yy_action_372(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Ident(_dollar1)
  guard _args[2].0 is YYObj_Int(_dollar3)
  YYObj__Ident__Int_({();  (_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 505|    FLOAT { target_percent($loc($1), $1) }
fn yy_action_373(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _start_pos_of_item0 = _args[0].1
  let _end_pos_of_item0 = _args[0].2
  guard _args[0].0 is YYObj_String(_dollar1)
  YYObj_Int({();  target_percent((_start_pos_of_item0, _end_pos_of_item0), _dollar1) })
}

// file:///./parser.mbty
// 506|    INT { target_percent($loc($1), $1) }
fn yy_action_374(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _start_pos_of_item0 = _args[0].1
  let _end_pos_of_item0 = _args[0].2
  guard _args[0].0 is YYObj_String(_dollar1)
  YYObj_Int({();  target_percent((_start_pos_of_item0, _end_pos_of_item0), _dollar1) })
}

// file:///./parser.mbty
// 230|    X SEP non_empty_sep_trailing(SEP, X) { [$1, ..$3] }
fn yy_action_375(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj__Ident__Int_(_dollar1)
  guard _args[2].0 is YYObj_Array__Ident__Int__(_dollar3)
  YYObj_Array__Ident__Int__({();  [_dollar1, .._dollar3] })
}

// file:///./parser.mbty
// 229|    X SEP { [$1] }
fn yy_action_376(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj__Ident__Int_(_dollar1)
  YYObj_Array__Ident__Int__({();  [_dollar1] })
}

// file:///./parser.mbty
// 228|    X { [$1] }
fn yy_action_377(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj__Ident__Int_(_dollar1)
  YYObj_Array__Ident__Int__({();  [_dollar1] })
}

// file:///./parser.mbty
// 234|    { [] }
fn yy_action_378(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Array__Ident__Int__({();  [] })
}

// file:///./parser.mbty
// 457|    IDENT { $1 }
fn yy_action_379(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  YYObj_String({();  _dollar1 })
}

// file:///./parser.mbty
// 458|    IMPORT { "import" }
fn yy_action_380(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_String({();  "import" })
}

// file:///./parser.mbty
// 492|    attribute { ($loc($1), hint_of_attr($loc($1), $1)) }
fn yy_action_381(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _start_pos_of_item0 = _args[0].1
  let _end_pos_of_item0 = _args[0].2
  guard _args[0].0 is YYObj_Attribute(_dollar1)
  YYObj___Position__Position___HintSetter_({();  ((_start_pos_of_item0, _end_pos_of_item0), hint_of_attr((_start_pos_of_item0, _end_pos_of_item0), _dollar1)) })
}

// file:///./parser.mbty
// 650|    ioption(labelled) { $1 }
fn yy_action_382(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_383(_last_pos, _args[0:1])
  guard _sub_action_0_result is YYObj_Option_Ident_(_dollar1)
  YYObj_Ident_({();  _dollar1 })
}

// file:///./stdlib.mbty
// 10|    X { Some($1) }
fn yy_action_383(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Ident(_dollar1)
  YYObj_Option_Ident_({();  Some(_dollar1) })
}

// file:///./parser.mbty
// 654|    label ":" { $1 }
fn yy_action_384(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Ident(_dollar1)
  YYObj_Ident({();  _dollar1 })
}

// file:///./parser.mbty
// 797|    label "," case_labels { let (ls, d) = $3; ([$1, ..ls], d) }
fn yy_action_385(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[2].0 is YYObj__Array_Ident___Ident_(_dollar3)
  guard _args[0].0 is YYObj_Ident(_dollar1)
  YYObj__Array_Ident___Ident_({();  let (ls, d) = _dollar3; ([_dollar1, ..ls], d) })
}

// file:///./parser.mbty
// 796|    ELSE label { ([], $2) }
fn yy_action_386(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[1].0 is YYObj_Ident(_dollar2)
  YYObj__Array_Ident___Ident_({();  ([], _dollar2) })
}

// file:///./parser.mbty
// 805|    DISPATCH expression "[" case_labels "]" "{" semi_list(dispatch_arm) "}" {
// 806|      let (cases, default) = $4
// 807|      with_loc($sloc, Dispatch(index=$2, cases~, default~, arms=$7))
// 808|    }
fn yy_action_387(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[3].0 is YYObj__Array_Ident___Ident_(_dollar4)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[1].0 is YYObj_Instr_Location_(_dollar2)
  guard _args[6].0 is YYObj_Array__Ident__Body_Location___(_dollar7)
  YYObj_Instr_Location_({(); 
      let (cases, default) = _dollar4
      with_loc((_symbol_start_pos, _end_pos), Dispatch(index=_dollar2, cases~, default~, arms=_dollar7))
    })
}

// file:///./parser.mbty
// 761|    label ":" braced_block { ($1, $3) }
fn yy_action_388(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Ident(_dollar1)
  guard _args[2].0 is YYObj_Body_Location_(_dollar3)
  YYObj__Ident__Body_Location__({();  (_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 789|    ";" semi_list(X) { $2 }
fn yy_action_389(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[1].0 is YYObj_Array__Ident__Body_Location___(_dollar2)
  YYObj_Array__Ident__Body_Location___({();  _dollar2 })
}

// file:///./parser.mbty
// 790|    X semi_list(X) { [$1, ..$2] }
fn yy_action_390(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj__Ident__Body_Location__(_dollar1)
  guard _args[1].0 is YYObj_Array__Ident__Body_Location___(_dollar2)
  YYObj_Array__Ident__Body_Location___({();  [_dollar1, .._dollar2] })
}

// file:///./parser.mbty
// 788|    { [] }
fn yy_action_391(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Array__Ident__Body_Location___({();  [] })
}

// file:///./parser.mbty
// 904|    expression { $1 }
fn yy_action_392(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  YYObj_Instr_Location_({();  _dollar1 })
}

// file:///./parser.mbty
// 779|    "_" "=>" braced_block { $3 }
fn yy_action_393(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[2].0 is YYObj_Body_Location_(_dollar3)
  YYObj_Body_Location_({();  _dollar3 })
}

// file:///./parser.mbty
// 809|    MATCH expression "{" semi_list(match_arm) match_default "}" {
// 810|      with_loc($sloc, Match(scrutinee=$2, arms=$4, default=$5))
// 811|    }
fn yy_action_394(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[1].0 is YYObj_Instr_Location_(_dollar2)
  guard _args[3].0 is YYObj_Array__MatchPattern__Body_Location___(_dollar4)
  guard _args[4].0 is YYObj_Body_Location_(_dollar5)
  YYObj_Instr_Location_({(); 
      with_loc((_symbol_start_pos, _end_pos), Match(scrutinee=_dollar2, arms=_dollar4, default=_dollar5))
    })
}

// file:///./parser.mbty
// 767|    ident ":" reference_type { MatchCast(Some($1), $3) }
fn yy_action_395(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Ident(_dollar1)
  guard _args[2].0 is YYObj_RefType(_dollar3)
  YYObj_MatchPattern({();  MatchCast(Some(_dollar1), _dollar3) })
}

// file:///./parser.mbty
// 768|    reference_type { MatchCast(None, $1) }
fn yy_action_396(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_RefType(_dollar1)
  YYObj_MatchPattern({();  MatchCast(None, _dollar1) })
}

// file:///./parser.mbty
// 769|    NULL { MatchNull }
fn yy_action_397(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_MatchPattern({();  MatchNull })
}

// file:///./parser.mbty
// 773|    match_pattern "=>" braced_block { ($1, $3) }
fn yy_action_398(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_MatchPattern(_dollar1)
  guard _args[2].0 is YYObj_Body_Location_(_dollar3)
  YYObj__MatchPattern__Body_Location__({();  (_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 789|    ";" semi_list(X) { $2 }
fn yy_action_399(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[1].0 is YYObj_Array__MatchPattern__Body_Location___(_dollar2)
  YYObj_Array__MatchPattern__Body_Location___({();  _dollar2 })
}

// file:///./parser.mbty
// 790|    X semi_list(X) { [$1, ..$2] }
fn yy_action_400(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj__MatchPattern__Body_Location__(_dollar1)
  guard _args[1].0 is YYObj_Array__MatchPattern__Body_Location___(_dollar2)
  YYObj_Array__MatchPattern__Body_Location___({();  [_dollar1, .._dollar2] })
}

// file:///./parser.mbty
// 788|    { [] }
fn yy_action_401(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Array__MatchPattern__Body_Location___({();  [] })
}

// file:///./parser.mbty
// 928|    ident ":" expression { with_loc($sloc, Labelled($1, $3)) }
fn yy_action_402(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[0].0 is YYObj_Ident(_dollar1)
  guard _args[2].0 is YYObj_Instr_Location_(_dollar3)
  YYObj_Instr_Location_({();  with_loc((_symbol_start_pos, _end_pos), Labelled(_dollar1, _dollar3)) })
}

// file:///./parser.mbty
// 951|    ident "::" ident { with_loc($sloc, Path($1, $3)) }
fn yy_action_403(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[0].0 is YYObj_Ident(_dollar1)
  guard _args[2].0 is YYObj_Ident(_dollar3)
  YYObj_Instr_Location_({();  with_loc((_symbol_start_pos, _end_pos), Path(_dollar1, _dollar3)) })
}

// file:///./parser.mbty
// 959|    ident "#" STRING { with_loc($sloc, Str(Some($1), $3.desc)) }
fn yy_action_404(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[0].0 is YYObj_Ident(_dollar1)
  guard _args[2].0 is YYObj_LocString(_dollar3)
  YYObj_Instr_Location_({();  with_loc((_symbol_start_pos, _end_pos), Str(Some(_dollar1), _dollar3.desc)) })
}

// file:///./parser.mbty
// 940|    sep_trailing(",", argument) { $1 }
fn yy_action_405(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Instr_Location__(_dollar1)
  YYObj_Array_Instr_Location__({();  _dollar1 })
}

// file:///./parser.mbty
// 956|    expression "(" argument_list ")" { with_loc($sloc, Call($1, $3)) }
fn yy_action_406(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  guard _args[2].0 is YYObj_Array_Instr_Location__(_dollar3)
  YYObj_Instr_Location_({();  with_loc((_symbol_start_pos, _end_pos), Call(_dollar1, _dollar3)) })
}

// file:///./parser.mbty
// 1175|    BECOME expression "(" argument_list ")" {
// 1176|      with_loc($sloc, TailCall($2, $4))
// 1177|    }
fn yy_action_407(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[1].0 is YYObj_Instr_Location_(_dollar2)
  guard _args[3].0 is YYObj_Array_Instr_Location__(_dollar4)
  YYObj_Instr_Location_({(); 
      with_loc((_symbol_start_pos, _end_pos), TailCall(_dollar2, _dollar4))
    })
}

// file:///./parser.mbty
// 235|    non_empty_sep_trailing(SEP, X) { $1 }
fn yy_action_408(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Instr_Location__(_dollar1)
  YYObj_Array_Instr_Location__({();  _dollar1 })
}

// file:///./parser.mbty
// 1195|    ";" raw_statement_list { [Semi, ..$2] }
fn yy_action_409(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_RawStmt_(_dollar2)
  YYObj_Array_RawStmt_({();  [Semi, .._dollar2] })
}

// file:///./parser.mbty
// 1224|    cond_stmt raw_statement_list { [$1, ..$2] }
fn yy_action_410(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_RawStmt(_dollar1)
  guard _args[1].0 is YYObj_Array_RawStmt_(_dollar2)
  YYObj_Array_RawStmt_({();  [_dollar1, .._dollar2] })
}

// file:///./parser.mbty
// 1240|    ";" raw_statement_list { $2 }
fn yy_action_411(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_RawStmt_(_dollar2)
  YYObj_Array_RawStmt_({();  _dollar2 })
}

// file:///./stdlib.mbty
// 5|    X { Some($1) }
fn yy_action_412(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_RawStmt_(_dollar1)
  YYObj_Option_Array_RawStmt__({();  Some(_dollar1) })
}

// file:///./stdlib.mbty
// 4|    { None }
fn yy_action_413(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Option_Array_RawStmt__({();  None })
}

// file:///./parser.mbty
// 1190|    { [] }
fn yy_action_414(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Array_RawStmt_({();  [] })
}

// file:///./parser.mbty
// 714|    ident "=>" braced_block { ($1, $3) }
fn yy_action_415(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Ident(_dollar1)
  guard _args[2].0 is YYObj_Body_Location_(_dollar3)
  YYObj__Ident__Body_Location__({();  (_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 789|    ";" semi_list(X) { $2 }
fn yy_action_416(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[1].0 is YYObj_Array__Ident__Body_Location___(_dollar2)
  YYObj_Array__Ident__Body_Location___({();  _dollar2 })
}

// file:///./parser.mbty
// 790|    X semi_list(X) { [$1, ..$2] }
fn yy_action_417(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj__Ident__Body_Location__(_dollar1)
  guard _args[1].0 is YYObj_Array__Ident__Body_Location___(_dollar2)
  YYObj_Array__Ident__Body_Location___({();  [_dollar1, .._dollar2] })
}

// file:///./parser.mbty
// 788|    { [] }
fn yy_action_418(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Array__Ident__Body_Location___({();  [] })
}

// file:///./stdlib.mbty
// 5|    X { Some($1) }
fn yy_action_419(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_FuncType(_dollar1)
  YYObj_Option_FuncType_({();  Some(_dollar1) })
}

// file:///./stdlib.mbty
// 4|    { None }
fn yy_action_420(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Option_FuncType_({();  None })
}

// file:///./parser.mbty
// 931|    TAG ":" expression {
// 932|      with_loc(
// 933|        $sloc,
// 934|        Labelled({ name: "tag", loc: loc_of($loc($1)) }, $3),
// 935|      )
// 936|    }
fn yy_action_421(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  let _start_pos_of_item0 = _args[0].1
  let _end_pos_of_item0 = _args[0].2
  guard _args[2].0 is YYObj_Instr_Location_(_dollar3)
  YYObj_Instr_Location_({(); 
      with_loc(
        (_symbol_start_pos, _end_pos),
        Labelled({ name: "tag", loc: loc_of((_start_pos_of_item0, _end_pos_of_item0)) }, _dollar3),
      )
    })
}

// file:///./parser.mbty
// 230|    X SEP non_empty_sep_trailing(SEP, X) { [$1, ..$3] }
fn yy_action_422(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  guard _args[2].0 is YYObj_Array_Instr_Location__(_dollar3)
  YYObj_Array_Instr_Location__({();  [_dollar1, .._dollar3] })
}

// file:///./parser.mbty
// 229|    X SEP { [$1] }
fn yy_action_423(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  YYObj_Array_Instr_Location__({();  [_dollar1] })
}

// file:///./parser.mbty
// 228|    X { [$1] }
fn yy_action_424(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  YYObj_Array_Instr_Location__({();  [_dollar1] })
}

// file:///./parser.mbty
// 234|    { [] }
fn yy_action_425(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Array_Instr_Location__({();  [] })
}

// file:///./parser.mbty
// 948|    NULL { with_loc($sloc, Null) }
fn yy_action_426(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Instr_Location_({();  with_loc((_symbol_start_pos, _end_pos), Null) })
}

// file:///./parser.mbty
// 949|    "_" { with_loc($sloc, Hole) }
fn yy_action_427(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Instr_Location_({();  with_loc((_symbol_start_pos, _end_pos), Hole) })
}

// file:///./parser.mbty
// 982|    expression AS boption("?") descriptor_operand {
// 983|      with_loc($sloc, CastDesc($1, $3, $4))
// 984|    }
fn yy_action_428(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  guard _args[2].0 is YYObj_Bool(_dollar3)
  guard _args[3].0 is YYObj_Instr_Location_(_dollar4)
  YYObj_Instr_Location_({(); 
      with_loc((_symbol_start_pos, _end_pos), CastDesc(_dollar1, _dollar3, _dollar4))
    })
}

// file:///./parser.mbty
// 314|    CONT { Cont }
fn yy_action_429(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_HeapType({();  Cont })
}

// file:///./parser.mbty
// 315|    ident { heap_type_of($1) }
fn yy_action_430(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Ident(_dollar1)
  YYObj_HeapType({();  heap_type_of(_dollar1) })
}

// file:///./parser.mbty
// 319|    "&" boption("?") boption("!") heap_type {
// 320|      let typ = if $3 { make_exact($sloc, $4) } else { $4 }
// 321|      { nullable: $2, typ }
// 322|    }
fn yy_action_431(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[2].0 is YYObj_Bool(_dollar3)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[3].0 is YYObj_HeapType(_dollar4)
  guard _args[1].0 is YYObj_Bool(_dollar2)
  YYObj_RefType({(); 
      let typ = if _dollar3 { make_exact((_symbol_start_pos, _end_pos), _dollar4) } else { _dollar4 }
      { nullable: _dollar2, typ }
    })
}

// file:///./stdlib.mbty
// 20|    X { true }
fn yy_action_432(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Bool({();  true })
}

// file:///./stdlib.mbty
// 19|    { false }
fn yy_action_433(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Bool({();  false })
}

// file:///./parser.mbty
// 985|    expression IS reference_type { with_loc($sloc, Test($1, $3)) }
fn yy_action_434(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  guard _args[2].0 is YYObj_RefType(_dollar3)
  YYObj_Instr_Location_({();  with_loc((_symbol_start_pos, _end_pos), Test(_dollar1, _dollar3)) })
}

// file:///./parser.mbty
// 988|    expression "." ident "=" expression {
// 989|      with_loc($sloc, StructSet($1, $3, $5))
// 990|    }
fn yy_action_435(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  guard _args[2].0 is YYObj_Ident(_dollar3)
  guard _args[4].0 is YYObj_Instr_Location_(_dollar5)
  YYObj_Instr_Location_({(); 
      with_loc((_symbol_start_pos, _end_pos), StructSet(_dollar1, _dollar3, _dollar5))
    })
}

// file:///./parser.mbty
// 986|    expression "." ident { with_loc($sloc, StructGet($1, $3)) }
fn yy_action_436(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  guard _args[2].0 is YYObj_Ident(_dollar3)
  YYObj_Instr_Location_({();  with_loc((_symbol_start_pos, _end_pos), StructGet(_dollar1, _dollar3)) })
}

// file:///./parser.mbty
// 987|    expression "." DESCRIPTOR { with_loc($sloc, GetDescriptor($1)) }
fn yy_action_437(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  YYObj_Instr_Location_({();  with_loc((_symbol_start_pos, _end_pos), GetDescriptor(_dollar1)) })
}

// file:///./parser.mbty
// 991|    expression "+" expression { binop($sloc, $loc($2), Add, $1, $3) }
fn yy_action_438(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  let _start_pos_of_item1 = _args[1].1
  let _end_pos_of_item1 = _args[1].2
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  guard _args[2].0 is YYObj_Instr_Location_(_dollar3)
  YYObj_Instr_Location_({();  binop((_symbol_start_pos, _end_pos), (_start_pos_of_item1, _end_pos_of_item1), Add, _dollar1, _dollar3) })
}

// file:///./parser.mbty
// 992|    expression "-" expression { binop($sloc, $loc($2), Sub, $1, $3) }
fn yy_action_439(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  let _start_pos_of_item1 = _args[1].1
  let _end_pos_of_item1 = _args[1].2
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  guard _args[2].0 is YYObj_Instr_Location_(_dollar3)
  YYObj_Instr_Location_({();  binop((_symbol_start_pos, _end_pos), (_start_pos_of_item1, _end_pos_of_item1), Sub, _dollar1, _dollar3) })
}

// file:///./parser.mbty
// 993|    expression "*" expression { binop($sloc, $loc($2), Mul, $1, $3) }
fn yy_action_440(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  let _start_pos_of_item1 = _args[1].1
  let _end_pos_of_item1 = _args[1].2
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  guard _args[2].0 is YYObj_Instr_Location_(_dollar3)
  YYObj_Instr_Location_({();  binop((_symbol_start_pos, _end_pos), (_start_pos_of_item1, _end_pos_of_item1), Mul, _dollar1, _dollar3) })
}

// file:///./parser.mbty
// 994|    expression "/" expression { binop($sloc, $loc($2), Div(None), $1, $3) }
fn yy_action_441(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  let _start_pos_of_item1 = _args[1].1
  let _end_pos_of_item1 = _args[1].2
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  guard _args[2].0 is YYObj_Instr_Location_(_dollar3)
  YYObj_Instr_Location_({();  binop((_symbol_start_pos, _end_pos), (_start_pos_of_item1, _end_pos_of_item1), Div(None), _dollar1, _dollar3) })
}

// file:///./parser.mbty
// 995|    expression "/s" expression { binop($sloc, $loc($2), Div(Some(Signed)), $1, $3) }
fn yy_action_442(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  let _start_pos_of_item1 = _args[1].1
  let _end_pos_of_item1 = _args[1].2
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  guard _args[2].0 is YYObj_Instr_Location_(_dollar3)
  YYObj_Instr_Location_({();  binop((_symbol_start_pos, _end_pos), (_start_pos_of_item1, _end_pos_of_item1), Div(Some(Signed)), _dollar1, _dollar3) })
}

// file:///./parser.mbty
// 996|    expression "/u" expression { binop($sloc, $loc($2), Div(Some(Unsigned)), $1, $3) }
fn yy_action_443(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  let _start_pos_of_item1 = _args[1].1
  let _end_pos_of_item1 = _args[1].2
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  guard _args[2].0 is YYObj_Instr_Location_(_dollar3)
  YYObj_Instr_Location_({();  binop((_symbol_start_pos, _end_pos), (_start_pos_of_item1, _end_pos_of_item1), Div(Some(Unsigned)), _dollar1, _dollar3) })
}

// file:///./parser.mbty
// 997|    expression "%s" expression { binop($sloc, $loc($2), Rem(Signed), $1, $3) }
fn yy_action_444(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  let _start_pos_of_item1 = _args[1].1
  let _end_pos_of_item1 = _args[1].2
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  guard _args[2].0 is YYObj_Instr_Location_(_dollar3)
  YYObj_Instr_Location_({();  binop((_symbol_start_pos, _end_pos), (_start_pos_of_item1, _end_pos_of_item1), Rem(Signed), _dollar1, _dollar3) })
}

// file:///./parser.mbty
// 998|    expression "%u" expression { binop($sloc, $loc($2), Rem(Unsigned), $1, $3) }
fn yy_action_445(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  let _start_pos_of_item1 = _args[1].1
  let _end_pos_of_item1 = _args[1].2
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  guard _args[2].0 is YYObj_Instr_Location_(_dollar3)
  YYObj_Instr_Location_({();  binop((_symbol_start_pos, _end_pos), (_start_pos_of_item1, _end_pos_of_item1), Rem(Unsigned), _dollar1, _dollar3) })
}

// file:///./parser.mbty
// 999|    expression "&" expression { binop($sloc, $loc($2), And, $1, $3) }
fn yy_action_446(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  let _start_pos_of_item1 = _args[1].1
  let _end_pos_of_item1 = _args[1].2
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  guard _args[2].0 is YYObj_Instr_Location_(_dollar3)
  YYObj_Instr_Location_({();  binop((_symbol_start_pos, _end_pos), (_start_pos_of_item1, _end_pos_of_item1), And, _dollar1, _dollar3) })
}

// file:///./parser.mbty
// 1000|    expression "^" expression { binop($sloc, $loc($2), Xor, $1, $3) }
fn yy_action_447(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  let _start_pos_of_item1 = _args[1].1
  let _end_pos_of_item1 = _args[1].2
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  guard _args[2].0 is YYObj_Instr_Location_(_dollar3)
  YYObj_Instr_Location_({();  binop((_symbol_start_pos, _end_pos), (_start_pos_of_item1, _end_pos_of_item1), Xor, _dollar1, _dollar3) })
}

// file:///./parser.mbty
// 1001|    expression "|" expression { binop($sloc, $loc($2), Or, $1, $3) }
fn yy_action_448(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  let _start_pos_of_item1 = _args[1].1
  let _end_pos_of_item1 = _args[1].2
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  guard _args[2].0 is YYObj_Instr_Location_(_dollar3)
  YYObj_Instr_Location_({();  binop((_symbol_start_pos, _end_pos), (_start_pos_of_item1, _end_pos_of_item1), Or, _dollar1, _dollar3) })
}

// file:///./parser.mbty
// 1002|    expression "<<" expression { binop($sloc, $loc($2), Shl, $1, $3) }
fn yy_action_449(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  let _start_pos_of_item1 = _args[1].1
  let _end_pos_of_item1 = _args[1].2
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  guard _args[2].0 is YYObj_Instr_Location_(_dollar3)
  YYObj_Instr_Location_({();  binop((_symbol_start_pos, _end_pos), (_start_pos_of_item1, _end_pos_of_item1), Shl, _dollar1, _dollar3) })
}

// file:///./parser.mbty
// 1003|    expression ">>s" expression { binop($sloc, $loc($2), Shr(Signed), $1, $3) }
fn yy_action_450(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  let _start_pos_of_item1 = _args[1].1
  let _end_pos_of_item1 = _args[1].2
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  guard _args[2].0 is YYObj_Instr_Location_(_dollar3)
  YYObj_Instr_Location_({();  binop((_symbol_start_pos, _end_pos), (_start_pos_of_item1, _end_pos_of_item1), Shr(Signed), _dollar1, _dollar3) })
}

// file:///./parser.mbty
// 1004|    expression ">>u" expression { binop($sloc, $loc($2), Shr(Unsigned), $1, $3) }
fn yy_action_451(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  let _start_pos_of_item1 = _args[1].1
  let _end_pos_of_item1 = _args[1].2
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  guard _args[2].0 is YYObj_Instr_Location_(_dollar3)
  YYObj_Instr_Location_({();  binop((_symbol_start_pos, _end_pos), (_start_pos_of_item1, _end_pos_of_item1), Shr(Unsigned), _dollar1, _dollar3) })
}

// file:///./parser.mbty
// 1005|    expression "==" expression { binop($sloc, $loc($2), Eq, $1, $3) }
fn yy_action_452(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  let _start_pos_of_item1 = _args[1].1
  let _end_pos_of_item1 = _args[1].2
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  guard _args[2].0 is YYObj_Instr_Location_(_dollar3)
  YYObj_Instr_Location_({();  binop((_symbol_start_pos, _end_pos), (_start_pos_of_item1, _end_pos_of_item1), Eq, _dollar1, _dollar3) })
}

// file:///./parser.mbty
// 1006|    expression "!=" expression { binop($sloc, $loc($2), Ne, $1, $3) }
fn yy_action_453(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  let _start_pos_of_item1 = _args[1].1
  let _end_pos_of_item1 = _args[1].2
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  guard _args[2].0 is YYObj_Instr_Location_(_dollar3)
  YYObj_Instr_Location_({();  binop((_symbol_start_pos, _end_pos), (_start_pos_of_item1, _end_pos_of_item1), Ne, _dollar1, _dollar3) })
}

// file:///./parser.mbty
// 1007|    expression ">" expression { binop($sloc, $loc($2), Gt(None), $1, $3) }
fn yy_action_454(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  let _start_pos_of_item1 = _args[1].1
  let _end_pos_of_item1 = _args[1].2
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  guard _args[2].0 is YYObj_Instr_Location_(_dollar3)
  YYObj_Instr_Location_({();  binop((_symbol_start_pos, _end_pos), (_start_pos_of_item1, _end_pos_of_item1), Gt(None), _dollar1, _dollar3) })
}

// file:///./parser.mbty
// 1008|    expression ">s" expression { binop($sloc, $loc($2), Gt(Some(Signed)), $1, $3) }
fn yy_action_455(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  let _start_pos_of_item1 = _args[1].1
  let _end_pos_of_item1 = _args[1].2
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  guard _args[2].0 is YYObj_Instr_Location_(_dollar3)
  YYObj_Instr_Location_({();  binop((_symbol_start_pos, _end_pos), (_start_pos_of_item1, _end_pos_of_item1), Gt(Some(Signed)), _dollar1, _dollar3) })
}

// file:///./parser.mbty
// 1009|    expression ">u" expression { binop($sloc, $loc($2), Gt(Some(Unsigned)), $1, $3) }
fn yy_action_456(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  let _start_pos_of_item1 = _args[1].1
  let _end_pos_of_item1 = _args[1].2
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  guard _args[2].0 is YYObj_Instr_Location_(_dollar3)
  YYObj_Instr_Location_({();  binop((_symbol_start_pos, _end_pos), (_start_pos_of_item1, _end_pos_of_item1), Gt(Some(Unsigned)), _dollar1, _dollar3) })
}

// file:///./parser.mbty
// 1010|    expression "<" expression { binop($sloc, $loc($2), Lt(None), $1, $3) }
fn yy_action_457(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  let _start_pos_of_item1 = _args[1].1
  let _end_pos_of_item1 = _args[1].2
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  guard _args[2].0 is YYObj_Instr_Location_(_dollar3)
  YYObj_Instr_Location_({();  binop((_symbol_start_pos, _end_pos), (_start_pos_of_item1, _end_pos_of_item1), Lt(None), _dollar1, _dollar3) })
}

// file:///./parser.mbty
// 1011|    expression "<s" expression { binop($sloc, $loc($2), Lt(Some(Signed)), $1, $3) }
fn yy_action_458(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  let _start_pos_of_item1 = _args[1].1
  let _end_pos_of_item1 = _args[1].2
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  guard _args[2].0 is YYObj_Instr_Location_(_dollar3)
  YYObj_Instr_Location_({();  binop((_symbol_start_pos, _end_pos), (_start_pos_of_item1, _end_pos_of_item1), Lt(Some(Signed)), _dollar1, _dollar3) })
}

// file:///./parser.mbty
// 1012|    expression "<u" expression { binop($sloc, $loc($2), Lt(Some(Unsigned)), $1, $3) }
fn yy_action_459(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  let _start_pos_of_item1 = _args[1].1
  let _end_pos_of_item1 = _args[1].2
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  guard _args[2].0 is YYObj_Instr_Location_(_dollar3)
  YYObj_Instr_Location_({();  binop((_symbol_start_pos, _end_pos), (_start_pos_of_item1, _end_pos_of_item1), Lt(Some(Unsigned)), _dollar1, _dollar3) })
}

// file:///./parser.mbty
// 1013|    expression ">=" expression { binop($sloc, $loc($2), Ge(None), $1, $3) }
fn yy_action_460(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  let _start_pos_of_item1 = _args[1].1
  let _end_pos_of_item1 = _args[1].2
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  guard _args[2].0 is YYObj_Instr_Location_(_dollar3)
  YYObj_Instr_Location_({();  binop((_symbol_start_pos, _end_pos), (_start_pos_of_item1, _end_pos_of_item1), Ge(None), _dollar1, _dollar3) })
}

// file:///./parser.mbty
// 1014|    expression ">=s" expression { binop($sloc, $loc($2), Ge(Some(Signed)), $1, $3) }
fn yy_action_461(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  let _start_pos_of_item1 = _args[1].1
  let _end_pos_of_item1 = _args[1].2
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  guard _args[2].0 is YYObj_Instr_Location_(_dollar3)
  YYObj_Instr_Location_({();  binop((_symbol_start_pos, _end_pos), (_start_pos_of_item1, _end_pos_of_item1), Ge(Some(Signed)), _dollar1, _dollar3) })
}

// file:///./parser.mbty
// 1015|    expression ">=u" expression { binop($sloc, $loc($2), Ge(Some(Unsigned)), $1, $3) }
fn yy_action_462(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  let _start_pos_of_item1 = _args[1].1
  let _end_pos_of_item1 = _args[1].2
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  guard _args[2].0 is YYObj_Instr_Location_(_dollar3)
  YYObj_Instr_Location_({();  binop((_symbol_start_pos, _end_pos), (_start_pos_of_item1, _end_pos_of_item1), Ge(Some(Unsigned)), _dollar1, _dollar3) })
}

// file:///./parser.mbty
// 1016|    expression "<=" expression { binop($sloc, $loc($2), Le(None), $1, $3) }
fn yy_action_463(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  let _start_pos_of_item1 = _args[1].1
  let _end_pos_of_item1 = _args[1].2
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  guard _args[2].0 is YYObj_Instr_Location_(_dollar3)
  YYObj_Instr_Location_({();  binop((_symbol_start_pos, _end_pos), (_start_pos_of_item1, _end_pos_of_item1), Le(None), _dollar1, _dollar3) })
}

// file:///./parser.mbty
// 1017|    expression "<=s" expression { binop($sloc, $loc($2), Le(Some(Signed)), $1, $3) }
fn yy_action_464(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  let _start_pos_of_item1 = _args[1].1
  let _end_pos_of_item1 = _args[1].2
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  guard _args[2].0 is YYObj_Instr_Location_(_dollar3)
  YYObj_Instr_Location_({();  binop((_symbol_start_pos, _end_pos), (_start_pos_of_item1, _end_pos_of_item1), Le(Some(Signed)), _dollar1, _dollar3) })
}

// file:///./parser.mbty
// 1018|    expression "<=u" expression { binop($sloc, $loc($2), Le(Some(Unsigned)), $1, $3) }
fn yy_action_465(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  let _start_pos_of_item1 = _args[1].1
  let _end_pos_of_item1 = _args[1].2
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  guard _args[2].0 is YYObj_Instr_Location_(_dollar3)
  YYObj_Instr_Location_({();  binop((_symbol_start_pos, _end_pos), (_start_pos_of_item1, _end_pos_of_item1), Le(Some(Unsigned)), _dollar1, _dollar3) })
}

// file:///./parser.mbty
// 710|    "[" sep_trailing(",", on_clause) "]" { $2 }
fn yy_action_466(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[1].0 is YYObj_Array_OnClause_(_dollar2)
  YYObj_Array_OnClause_({();  _dollar2 })
}

// file:///./parser.mbty
// 235|    non_empty_sep_trailing(SEP, X) { $1 }
fn yy_action_467(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_OnClause_(_dollar1)
  YYObj_Array_OnClause_({();  _dollar1 })
}

// file:///./parser.mbty
// 243|    IDENT { { name: $1, loc: loc_of($loc($1)) } }
fn yy_action_468(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  let _start_pos_of_item0 = _args[0].1
  let _end_pos_of_item0 = _args[0].2
  YYObj_Ident({();  { name: _dollar1, loc: loc_of((_start_pos_of_item0, _end_pos_of_item0)) } })
}

// file:///./parser.mbty
// 250|    IDENT { $1 }
fn yy_action_469(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  YYObj_String({();  _dollar1 })
}

// file:///./parser.mbty
// 251|    FN { "fn" }
fn yy_action_470(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_String({();  "fn" })
}

// file:///./parser.mbty
// 252|    TAG { "tag" }
fn yy_action_471(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_String({();  "tag" })
}

// file:///./parser.mbty
// 253|    MUT { "mut" }
fn yy_action_472(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_String({();  "mut" })
}

// file:///./parser.mbty
// 254|    TYPE { "type" }
fn yy_action_473(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_String({();  "type" })
}

// file:///./parser.mbty
// 255|    REC { "rec" }
fn yy_action_474(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_String({();  "rec" })
}

// file:///./parser.mbty
// 256|    OPEN { "open" }
fn yy_action_475(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_String({();  "open" })
}

// file:///./parser.mbty
// 257|    NOP { "nop" }
fn yy_action_476(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_String({();  "nop" })
}

// file:///./parser.mbty
// 258|    UNREACHABLE { "unreachable" }
fn yy_action_477(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_String({();  "unreachable" })
}

// file:///./parser.mbty
// 259|    NULL { "null" }
fn yy_action_478(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_String({();  "null" })
}

// file:///./parser.mbty
// 260|    DO { "do" }
fn yy_action_479(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_String({();  "do" })
}

// file:///./parser.mbty
// 261|    WHILE { "while" }
fn yy_action_480(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_String({();  "while" })
}

// file:///./parser.mbty
// 262|    LOOP { "loop" }
fn yy_action_481(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_String({();  "loop" })
}

// file:///./parser.mbty
// 263|    IF { "if" }
fn yy_action_482(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_String({();  "if" })
}

// file:///./parser.mbty
// 264|    ELSE { "else" }
fn yy_action_483(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_String({();  "else" })
}

// file:///./parser.mbty
// 265|    CONST { "const" }
fn yy_action_484(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_String({();  "const" })
}

// file:///./parser.mbty
// 266|    LET { "let" }
fn yy_action_485(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_String({();  "let" })
}

// file:///./parser.mbty
// 267|    AS { "as" }
fn yy_action_486(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_String({();  "as" })
}

// file:///./parser.mbty
// 268|    IS { "is" }
fn yy_action_487(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_String({();  "is" })
}

// file:///./parser.mbty
// 269|    BECOME { "become" }
fn yy_action_488(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_String({();  "become" })
}

// file:///./parser.mbty
// 270|    BR { "br" }
fn yy_action_489(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_String({();  "br" })
}

// file:///./parser.mbty
// 271|    BR_IF { "br_if" }
fn yy_action_490(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_String({();  "br_if" })
}

// file:///./parser.mbty
// 272|    BR_TABLE { "br_table" }
fn yy_action_491(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_String({();  "br_table" })
}

// file:///./parser.mbty
// 273|    RETURN { "return" }
fn yy_action_492(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_String({();  "return" })
}

// file:///./parser.mbty
// 274|    THROW { "throw" }
fn yy_action_493(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_String({();  "throw" })
}

// file:///./parser.mbty
// 275|    THROW_REF { "throw_ref" }
fn yy_action_494(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_String({();  "throw_ref" })
}

// file:///./parser.mbty
// 276|    BR_ON_CAST { "br_on_cast" }
fn yy_action_495(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_String({();  "br_on_cast" })
}

// file:///./parser.mbty
// 277|    BR_ON_CAST_FAIL { "br_on_cast_fail" }
fn yy_action_496(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_String({();  "br_on_cast_fail" })
}

// file:///./parser.mbty
// 278|    BR_ON_NULL { "br_on_null" }
fn yy_action_497(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_String({();  "br_on_null" })
}

// file:///./parser.mbty
// 279|    BR_ON_NON_NULL { "br_on_non_null" }
fn yy_action_498(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_String({();  "br_on_non_null" })
}

// file:///./parser.mbty
// 280|    TRY { "try" }
fn yy_action_499(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_String({();  "try" })
}

// file:///./parser.mbty
// 281|    TRY_LEGACY { "try_legacy" }
fn yy_action_500(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_String({();  "try_legacy" })
}

// file:///./parser.mbty
// 282|    CATCH { "catch" }
fn yy_action_501(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_String({();  "catch" })
}

// file:///./parser.mbty
// 283|    CONT { "cont" }
fn yy_action_502(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_String({();  "cont" })
}

// file:///./parser.mbty
// 284|    SUSPEND { "suspend" }
fn yy_action_503(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_String({();  "suspend" })
}

// file:///./parser.mbty
// 285|    ON { "on" }
fn yy_action_504(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_String({();  "on" })
}

// file:///./parser.mbty
// 286|    MEMORY { "memory" }
fn yy_action_505(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_String({();  "memory" })
}

// file:///./parser.mbty
// 287|    IMPORT { "import" }
fn yy_action_506(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_String({();  "import" })
}

// file:///./parser.mbty
// 288|    PAGESIZE { "pagesize" }
fn yy_action_507(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_String({();  "pagesize" })
}

// file:///./parser.mbty
// 289|    SHARED { "shared" }
fn yy_action_508(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_String({();  "shared" })
}

// file:///./parser.mbty
// 290|    DATA { "data" }
fn yy_action_509(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_String({();  "data" })
}

// file:///./parser.mbty
// 291|    TABLE { "table" }
fn yy_action_510(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_String({();  "table" })
}

// file:///./parser.mbty
// 292|    ELEM { "elem" }
fn yy_action_511(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_String({();  "elem" })
}

// file:///./parser.mbty
// 293|    DISPATCH { "dispatch" }
fn yy_action_512(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_String({();  "dispatch" })
}

// file:///./parser.mbty
// 294|    MATCH { "match" }
fn yy_action_513(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_String({();  "match" })
}

// file:///./parser.mbty
// 295|    DESCRIPTOR { "descriptor" }
fn yy_action_514(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_String({();  "descriptor" })
}

// file:///./parser.mbty
// 296|    DESCRIBES { "describes" }
fn yy_action_515(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_String({();  "describes" })
}

// file:///./parser.mbty
// 297|    INF { "inf" }
fn yy_action_516(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_String({();  "inf" })
}

// file:///./parser.mbty
// 298|    NAN { "nan" }
fn yy_action_517(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_String({();  "nan" })
}

// file:///./parser.mbty
// 302|    ident_or_keyword { $1 }
fn yy_action_518(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  YYObj_String({();  _dollar1 })
}

// file:///./parser.mbty
// 306|    "'" label_name { { name: $2, loc: loc_of($sloc) } }
fn yy_action_519(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[1].0 is YYObj_String(_dollar2)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Ident({();  { name: _dollar2, loc: loc_of((_symbol_start_pos, _end_pos)) } })
}

// file:///./parser.mbty
// 694|    ident "->" label { OnLabel($1, $3) }
fn yy_action_520(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Ident(_dollar1)
  guard _args[2].0 is YYObj_Ident(_dollar3)
  YYObj_OnClause({();  OnLabel(_dollar1, _dollar3) })
}

// file:///./parser.mbty
// 696|    ident "->" ident {
// 697|      if $3.name == "switch" {
// 698|        OnSwitch($1)
// 699|      } else {
// 700|        fail_at(
// 701|          loc_of($loc($3)),
// 702|          "Expected a label or 'switch' as the handler target.",
// 703|          default=OnSwitch($1),
// 704|        )
// 705|      }
// 706|    }
fn yy_action_521(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[2].0 is YYObj_Ident(_dollar3)
  guard _args[0].0 is YYObj_Ident(_dollar1)
  let _start_pos_of_item2 = _args[2].1
  let _end_pos_of_item2 = _args[2].2
  YYObj_OnClause({(); 
      if _dollar3.name == "switch" {
        OnSwitch(_dollar1)
      } else {
        fail_at(
          loc_of((_start_pos_of_item2, _end_pos_of_item2)),
          "Expected a label or 'switch' as the handler target.",
          default=OnSwitch(_dollar1),
        )
      }
    })
}

// file:///./parser.mbty
// 230|    X SEP non_empty_sep_trailing(SEP, X) { [$1, ..$3] }
fn yy_action_522(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_OnClause(_dollar1)
  guard _args[2].0 is YYObj_Array_OnClause_(_dollar3)
  YYObj_Array_OnClause_({();  [_dollar1, .._dollar3] })
}

// file:///./parser.mbty
// 229|    X SEP { [$1] }
fn yy_action_523(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_OnClause(_dollar1)
  YYObj_Array_OnClause_({();  [_dollar1] })
}

// file:///./parser.mbty
// 228|    X { [$1] }
fn yy_action_524(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_OnClause(_dollar1)
  YYObj_Array_OnClause_({();  [_dollar1] })
}

// file:///./parser.mbty
// 234|    { [] }
fn yy_action_525(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Array_OnClause_({();  [] })
}

// file:///./parser.mbty
// 1026|    expression ON on_clauses { with_loc($sloc, On($1, $3)) }
fn yy_action_526(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  guard _args[2].0 is YYObj_Array_OnClause_(_dollar3)
  YYObj_Instr_Location_({();  with_loc((_symbol_start_pos, _end_pos), On(_dollar1, _dollar3)) })
}

// file:///./parser.mbty
// 1035|    expression "[" index_expression "]" "=" expression {
// 1036|      with_loc($sloc, ArraySet($1, $3, $6))
// 1037|    }
fn yy_action_527(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  guard _args[2].0 is YYObj_Instr_Location_(_dollar3)
  guard _args[5].0 is YYObj_Instr_Location_(_dollar6)
  YYObj_Instr_Location_({(); 
      with_loc((_symbol_start_pos, _end_pos), ArraySet(_dollar1, _dollar3, _dollar6))
    })
}

// file:///./parser.mbty
// 1027|    expression "[" index_expression "]" { with_loc($sloc, ArrayGet($1, $3)) }
fn yy_action_528(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  guard _args[2].0 is YYObj_Instr_Location_(_dollar3)
  YYObj_Instr_Location_({();  with_loc((_symbol_start_pos, _end_pos), ArrayGet(_dollar1, _dollar3)) })
}

// file:///./parser.mbty
// 1028|    expression "?" then_branch ":" expression {
// 1029|      with_loc($sloc, Select($1, $3, $5))
// 1030|    }
fn yy_action_529(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  guard _args[2].0 is YYObj_Instr_Location_(_dollar3)
  guard _args[4].0 is YYObj_Instr_Location_(_dollar5)
  YYObj_Instr_Location_({(); 
      with_loc((_symbol_start_pos, _end_pos), Select(_dollar1, _dollar3, _dollar5))
    })
}

// file:///./parser.mbty
// 1034|    expression "!" { with_loc($sloc, NonNull($1)) }
fn yy_action_530(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  YYObj_Instr_Location_({();  with_loc((_symbol_start_pos, _end_pos), NonNull(_dollar1)) })
}

// file:///./parser.mbty
// 980|    ident ":=" expression { with_loc($sloc, Tee($1, $3)) }
fn yy_action_531(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[0].0 is YYObj_Ident(_dollar1)
  guard _args[2].0 is YYObj_Instr_Location_(_dollar3)
  YYObj_Instr_Location_({();  with_loc((_symbol_start_pos, _end_pos), Tee(_dollar1, _dollar3)) })
}

// file:///./parser.mbty
// 950|    ident %prec prec_ident { with_loc($sloc, Get($1)) }
fn yy_action_532(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[0].0 is YYObj_Ident(_dollar1)
  YYObj_Instr_Location_({();  with_loc((_symbol_start_pos, _end_pos), Get(_dollar1)) })
}

// file:///./parser.mbty
// 952|    "(" parenthesized_expression ")" { mark_parenthesized($2) }
fn yy_action_533(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[1].0 is YYObj_Instr_Location_(_dollar2)
  YYObj_Instr_Location_({();  mark_parenthesized(_dollar2) })
}

// file:///./parser.mbty
// 957|    CHAR { with_loc($sloc, Char($1)) }
fn yy_action_534(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[0].0 is YYObj_Char(_dollar1)
  YYObj_Instr_Location_({();  with_loc((_symbol_start_pos, _end_pos), Char(_dollar1)) })
}

// file:///./parser.mbty
// 958|    STRING { with_loc($sloc, Str(None, $1.desc)) }
fn yy_action_535(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[0].0 is YYObj_LocString(_dollar1)
  YYObj_Instr_Location_({();  with_loc((_symbol_start_pos, _end_pos), Str(None, _dollar1.desc)) })
}

// file:///./parser.mbty
// 960|    INT { with_loc($sloc, Int($1)) }
fn yy_action_536(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[0].0 is YYObj_String(_dollar1)
  YYObj_Instr_Location_({();  with_loc((_symbol_start_pos, _end_pos), Int(_dollar1)) })
}

// file:///./parser.mbty
// 961|    FLOAT { with_loc($sloc, Float($1)) }
fn yy_action_537(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[0].0 is YYObj_String(_dollar1)
  YYObj_Instr_Location_({();  with_loc((_symbol_start_pos, _end_pos), Float(_dollar1)) })
}

// file:///./parser.mbty
// 962|    INF { with_loc($sloc, Float("inf")) }
fn yy_action_538(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Instr_Location_({();  with_loc((_symbol_start_pos, _end_pos), Float("inf")) })
}

// file:///./parser.mbty
// 963|    NAN { with_loc($sloc, Float("nan")) }
fn yy_action_539(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Instr_Location_({();  with_loc((_symbol_start_pos, _end_pos), Float("nan")) })
}

// file:///./parser.mbty
// 750|    field_name { ($1, None) }
fn yy_action_540(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Ident(_dollar1)
  YYObj__Ident__Instr_Location___({();  (_dollar1, None) })
}

// file:///./parser.mbty
// 230|    X SEP non_empty_sep_trailing(SEP, X) { [$1, ..$3] }
fn yy_action_541(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj__Ident__Instr_Location___(_dollar1)
  guard _args[2].0 is YYObj_Array__Ident__Instr_Location____(_dollar3)
  YYObj_Array__Ident__Instr_Location____({();  [_dollar1, .._dollar3] })
}

// file:///./parser.mbty
// 229|    X SEP { [$1] }
fn yy_action_542(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj__Ident__Instr_Location___(_dollar1)
  YYObj_Array__Ident__Instr_Location____({();  [_dollar1] })
}

// file:///./parser.mbty
// 228|    X { [$1] }
fn yy_action_543(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj__Ident__Instr_Location___(_dollar1)
  YYObj_Array__Ident__Instr_Location____({();  [_dollar1] })
}

// file:///./parser.mbty
// 234|    { [] }
fn yy_action_544(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Array__Ident__Instr_Location____({();  [] })
}

// file:///./parser.mbty
// 1069|    ".." ";" length_expression { fn(t) { ArrayDefault(t, $3) } }
fn yy_action_545(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[2].0 is YYObj_Instr_Location_(_dollar3)
  YYObj__Ident______InstrDesc_Location_({();  fn(t) { ArrayDefault(t, _dollar3) } })
}

// file:///./parser.mbty
// 1019|    branch_expr { $1 }
fn yy_action_546(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  YYObj_Instr_Location_({();  _dollar1 })
}

// file:///./parser.mbty
// 1020|    SUSPEND tag_name "(" expression_list ")" {
// 1021|      with_loc($sloc, Suspend($2, $4))
// 1022|    }
fn yy_action_547(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  guard _args[1].0 is YYObj_Ident(_dollar2)
  guard _args[3].0 is YYObj_Array_Instr_Location__(_dollar4)
  YYObj_Instr_Location_({(); 
      with_loc((_symbol_start_pos, _end_pos), Suspend(_dollar2, _dollar4))
    })
}

// file:///./parser.mbty
// 235|    non_empty_sep_trailing(SEP, X) { $1 }
fn yy_action_548(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Array_Instr_Location__(_dollar1)
  YYObj_Array_Instr_Location__({();  _dollar1 })
}

// file:///./parser.mbty
// 234|    { [] }
fn yy_action_549(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Array_Instr_Location__({();  [] })
}

// file:///./stdlib.mbty
// 20|    X { true }
fn yy_action_550(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Bool({();  true })
}

// file:///./stdlib.mbty
// 19|    { false }
fn yy_action_551(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Bool({();  false })
}

// file:///./parser.mbty
// 1076|    blockinstr %prec prec_block { $1 }
fn yy_action_552(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  YYObj_Instr_Location_({();  _dollar1 })
}

// file:///./parser.mbty
// 1077|    plaininstr { $1 }
fn yy_action_553(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Instr_Location_(_dollar1)
  YYObj_Instr_Location_({();  _dollar1 })
}

// file:///./parser.mbty
// 650|    ioption(labelled) { $1 }
fn yy_action_554(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  let _sub_action_0_result = yy_action_555(_last_pos, _args[0:0])
  guard _sub_action_0_result is YYObj_Option_Ident_(_dollar1)
  YYObj_Ident_({();  _dollar1 })
}

// file:///./stdlib.mbty
// 9|    { None }
fn yy_action_555(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Option_Ident_({();  None })
}

// file:///./parser.mbty
// 479|    "#" "[" attribute_name attribute_guard "]" {
// 480|      {
// 481|        attr_name: $3,
// 482|        attr_value: None,
// 483|        attr_guard: $4,
// 484|        attr_span: loc_of($sloc),
// 485|      }
// 486|    }
fn yy_action_556(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[2].0 is YYObj_String(_dollar3)
  guard _args[3].0 is YYObj_Annotated_Cond__Location__(_dollar4)
  let _symbol_start_pos = _get_symbol_start_pos(_args, _last_pos)
  let _end_pos = if _args.length() == 0 { _last_pos } else { _args[_args.length() - 1].2 }
  YYObj_Attribute({(); 
      {
        attr_name: _dollar3,
        attr_value: None,
        attr_guard: _dollar4,
        attr_span: loc_of((_symbol_start_pos, _end_pos)),
      }
    })
}

// file:///./parser.mbty
// 466|    { None }
fn yy_action_557(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Annotated_Cond__Location__({();  None })
}

// file:///./parser.mbty
// 443|    X list_of(X) { [$1, ..$2] }
fn yy_action_558(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  guard _args[0].0 is YYObj_Attribute(_dollar1)
  guard _args[1].0 is YYObj_Array_Attribute_(_dollar2)
  YYObj_Array_Attribute_({();  [_dollar1, .._dollar2] })
}

// file:///./parser.mbty
// 442|    { [] }
fn yy_action_559(_last_pos : Position, _args : ArrayView[(YYObj, Position, Position)]) -> YYObj {
  YYObj_Array_Attribute_({();  [] })
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
    NT_attribute => Shift(yy_state_2)
    NT_module_field => Shift(yy_state_639)
    T_SEMI => Shift(yy_state_641)
    T_EOF => Shift(yy_state_643)
    T_IMPORT => Shift(yy_state_644)
    NT_list_of_attribute_ => Shift(yy_state_719)
    NT_inner_attribute => Shift(yy_state_870)
    NT_rectype => Shift(yy_state_871)
    T_SHARP => Shift(yy_state_872)
    NT_type_definition => Shift(yy_state_888)
    T_REC => Shift(yy_state_889)
    T_TYPE => Shift(yy_state_893)
    NT_raw_parse => Shift(yy_state_963)
    T_FN | T_TAG | T_CONST | T_LET | T_MEMORY | T_DATA | T_TABLE | T_ELEM => Reduce(0, NT_list_of_attribute_, yy_action_559)
    _ => Error
  }
}

fn yy_state_1(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

fn yy_state_2(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_attribute => Shift(yy_state_2)
    NT_list_of_attribute_ => Shift(yy_state_3)
    T_SHARP => Shift(yy_state_4)
    T_FN | T_TAG | T_CONST | T_LET | T_MEMORY | T_DATA | T_TABLE | T_ELEM => Reduce(0, NT_list_of_attribute_, yy_action_559)
    _ => Error
  }
}

fn yy_state_3(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_list_of_attribute_, yy_action_558)
}

fn yy_state_4(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_5)
    _ => Error
  }
}

fn yy_state_5(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_attribute_name => Shift(yy_state_6)
    T_IMPORT => Shift(yy_state_308)
    T_IDENT => Shift(yy_state_638)
    _ => Error
  }
}

fn yy_state_6(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_attribute_guard => Shift(yy_state_7)
    T_EQUAL => Shift(yy_state_9)
    T_COMMA => Shift(yy_state_632)
    T_RBRACKET => Reduce(0, NT_attribute_guard, yy_action_557)
    _ => Error
  }
}

fn yy_state_7(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_8)
    _ => Error
  }
}

fn yy_state_8(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_attribute, yy_action_556)
}

fn yy_state_9(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    NT_attribute_expression => Shift(yy_state_629)
    NT_expression => Shift(yy_state_637)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_10(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    NT_expression => Shift(yy_state_443)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_11(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_expression, yy_action_553)
}

fn yy_state_12(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_expression, yy_action_552)
}

fn yy_state_13(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_label => Shift(yy_state_14)
    T_QUOTE => Shift(yy_state_82)
    _ => Error
  }
}

fn yy_state_14(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_QUESTIONMARK => Shift(yy_state_15)
    NT_boption_QUESTIONMARK_ => Shift(yy_state_16)
    T_AMPERSAND => Shift(yy_state_201)
    NT_reference_type => Shift(yy_state_627)
    T_DESCRIPTOR => Reduce(0, NT_boption_QUESTIONMARK_, yy_action_551)
    _ => Error
  }
}

fn yy_state_15(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_boption_QUESTIONMARK_, yy_action_550)
}

fn yy_state_16(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_descriptor_operand => Shift(yy_state_17)
    T_DESCRIPTOR => Shift(yy_state_211)
    _ => Error
  }
}

fn yy_state_17(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    NT_expression => Shift(yy_state_626)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_18(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_label => Shift(yy_state_19)
    T_QUOTE => Shift(yy_state_82)
    _ => Error
  }
}

fn yy_state_19(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_QUESTIONMARK => Shift(yy_state_15)
    NT_boption_QUESTIONMARK_ => Shift(yy_state_20)
    T_AMPERSAND => Shift(yy_state_201)
    NT_reference_type => Shift(yy_state_624)
    T_DESCRIPTOR => Reduce(0, NT_boption_QUESTIONMARK_, yy_action_551)
    _ => Error
  }
}

fn yy_state_20(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_descriptor_operand => Shift(yy_state_21)
    T_DESCRIPTOR => Shift(yy_state_211)
    _ => Error
  }
}

fn yy_state_21(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    NT_expression => Shift(yy_state_623)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_22(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_label => Shift(yy_state_23)
    T_QUOTE => Shift(yy_state_82)
    _ => Error
  }
}

fn yy_state_23(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    NT_expression => Shift(yy_state_622)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_24(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_label => Shift(yy_state_25)
    T_QUOTE => Shift(yy_state_82)
    _ => Error
  }
}

fn yy_state_25(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    NT_expression => Shift(yy_state_621)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_26(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_label => Shift(yy_state_27)
    T_QUOTE => Shift(yy_state_82)
    _ => Error
  }
}

fn yy_state_27(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    NT_expression => Shift(yy_state_620)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_28(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    NT_expression => Shift(yy_state_619)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_29(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    NT_expression => Shift(yy_state_618)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_30(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    NT_expression => Shift(yy_state_617)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_31(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_tag_name => Shift(yy_state_32)
    T_IDENT => Shift(yy_state_134)
    NT_ident => Shift(yy_state_336)
    _ => Error
  }
}

fn yy_state_32(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_33)
    _ => Error
  }
}

fn yy_state_33(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_non_empty_sep_trailing_COMMA_expression_ => Shift(yy_state_34)
    NT_expression_list => Shift(yy_state_35)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    NT_expression => Shift(yy_state_332)
    NT_sep_trailing_COMMA_expression_ => Shift(yy_state_335)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    T_RPAREN => Reduce(0, NT_sep_trailing_COMMA_expression_, yy_action_549)
    _ => Error
  }
}

fn yy_state_34(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_sep_trailing_COMMA_expression_, yy_action_548)
}

fn yy_state_35(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_36)
    _ => Error
  }
}

fn yy_state_36(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_plaininstr, yy_action_547)
}

fn yy_state_37(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_plaininstr, yy_action_546)
}

fn yy_state_38(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_non_empty_sep_trailing_COMMA_expression_ => Shift(yy_state_34)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_DOTDOT => Shift(yy_state_39)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    NT_sep_trailing_COMMA_expression_ => Shift(yy_state_335)
    NT_expression_list => Shift(yy_state_602)
    NT_array_body => Shift(yy_state_603)
    NT_expression => Shift(yy_state_605)
    NT_ident => Shift(yy_state_608)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    T_RBRACKET => Reduce(0, NT_sep_trailing_COMMA_expression_, yy_action_549)
    _ => Error
  }
}

fn yy_state_39(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_40)
    _ => Error
  }
}

fn yy_state_40(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    NT_length_expression => Shift(yy_state_41)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    NT_expression => Shift(yy_state_601)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_41(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_array_body, yy_action_545)
}

fn yy_state_42(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_descriptor_operand => Shift(yy_state_43)
    NT_field_name => Shift(yy_state_48)
    T_IDENT => Shift(yy_state_134)
    T_DESCRIPTOR => Shift(yy_state_211)
    T_DOTDOT => Shift(yy_state_587)
    T_RBRACE => Shift(yy_state_589)
    NT_structure_field => Shift(yy_state_590)
    NT_ident => Shift(yy_state_595)
    _ => Error
  }
}

fn yy_state_43(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PIPE => Shift(yy_state_44)
    _ => Error
  }
}

fn yy_state_44(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_structure_field => Shift(yy_state_45)
    NT_field_name => Shift(yy_state_48)
    T_IDENT => Shift(yy_state_134)
    NT_ident => Shift(yy_state_580)
    NT_non_empty_sep_trailing_COMMA_structure_field_ => Shift(yy_state_581)
    T_DOTDOT => Shift(yy_state_582)
    NT_structure => Shift(yy_state_584)
    NT_sep_trailing_COMMA_structure_field_ => Shift(yy_state_586)
    T_RBRACE => Reduce(0, NT_sep_trailing_COMMA_structure_field_, yy_action_544)
    _ => Error
  }
}

fn yy_state_45(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_46)
    T_RBRACE => Reduce(1, NT_non_empty_sep_trailing_COMMA_structure_field_, yy_action_543)
    _ => Error
  }
}

fn yy_state_46(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_structure_field => Shift(yy_state_45)
    NT_non_empty_sep_trailing_COMMA_structure_field_ => Shift(yy_state_47)
    NT_field_name => Shift(yy_state_48)
    T_IDENT => Shift(yy_state_134)
    NT_ident => Shift(yy_state_580)
    T_RBRACE => Reduce(2, NT_non_empty_sep_trailing_COMMA_structure_field_, yy_action_542)
    _ => Error
  }
}

fn yy_state_47(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_sep_trailing_COMMA_structure_field_, yy_action_541)
}

fn yy_state_48(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_49)
    T_RBRACE | T_COMMA => Reduce(1, NT_structure_field, yy_action_540)
    _ => Error
  }
}

fn yy_state_49(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    NT_expression => Shift(yy_state_579)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_50(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_plaininstr, yy_action_539)
}

fn yy_state_51(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_plaininstr, yy_action_538)
}

fn yy_state_52(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_plaininstr, yy_action_537)
}

fn yy_state_53(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_plaininstr, yy_action_536)
}

fn yy_state_54(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_plaininstr, yy_action_535)
}

fn yy_state_55(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_plaininstr, yy_action_534)
}

fn yy_state_56(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_parenthesized_expression => Shift(yy_state_57)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    NT_expression => Shift(yy_state_575)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_57(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_58)
    _ => Error
  }
}

fn yy_state_58(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_plaininstr, yy_action_533)
}

fn yy_state_59(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLONEQUAL => Shift(yy_state_60)
    T_SHARP => Shift(yy_state_254)
    T_COLONCOLON => Shift(yy_state_256)
    T_SEMI | T_QUESTIONMARK | T_LPAREN | T_RPAREN | T_LBRACE | T_RBRACE | T_LBRACKET | T_RBRACKET | T_COMMA | T_COLON | T_FATARROW | T_DOT | T_BANG | T_PLUS | T_MINUS | T_STAR | T_SLASH | T_SLASHS | T_SLASHU | T_PERCENTS | T_PERCENTU | T_AMPERSAND | T_PIPE | T_CARET | T_SHL | T_SHRS | T_SHRU | T_EQUALEQUAL | T_BANGEQUAL | T_GT | T_GTS | T_GTU | T_LT | T_LTS | T_LTU | T_GE | T_GES | T_GEU | T_LE | T_LES | T_LEU | T_AS | T_IS | T_ON => Reduce(1, NT_plaininstr, yy_action_532)
    _ => Error
  }
}

fn yy_state_60(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    NT_expression => Shift(yy_state_61)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_61(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_QUESTIONMARK => Shift(yy_state_63)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_LEU => Shift(yy_state_138)
    T_LES => Shift(yy_state_140)
    T_LE => Shift(yy_state_142)
    T_GEU => Shift(yy_state_144)
    T_GES => Shift(yy_state_146)
    T_GE => Shift(yy_state_148)
    T_LTU => Shift(yy_state_150)
    T_LTS => Shift(yy_state_152)
    T_LT => Shift(yy_state_154)
    T_GTU => Shift(yy_state_156)
    T_GTS => Shift(yy_state_158)
    T_GT => Shift(yy_state_160)
    T_BANGEQUAL => Shift(yy_state_162)
    T_EQUALEQUAL => Shift(yy_state_164)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_COLON | T_FATARROW => Reduce(3, NT_plaininstr, yy_action_531)
    _ => Error
  }
}

fn yy_state_62(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_plaininstr, yy_action_530)
}

fn yy_state_63(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    NT_then_branch => Shift(yy_state_64)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    NT_expression => Shift(yy_state_574)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_64(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_65)
    _ => Error
  }
}

fn yy_state_65(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    NT_expression => Shift(yy_state_66)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_66(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_QUESTIONMARK => Shift(yy_state_63)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_LEU => Shift(yy_state_138)
    T_LES => Shift(yy_state_140)
    T_LE => Shift(yy_state_142)
    T_GEU => Shift(yy_state_144)
    T_GES => Shift(yy_state_146)
    T_GE => Shift(yy_state_148)
    T_LTU => Shift(yy_state_150)
    T_LTS => Shift(yy_state_152)
    T_LT => Shift(yy_state_154)
    T_GTU => Shift(yy_state_156)
    T_GTS => Shift(yy_state_158)
    T_GT => Shift(yy_state_160)
    T_BANGEQUAL => Shift(yy_state_162)
    T_EQUALEQUAL => Shift(yy_state_164)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_COLON | T_FATARROW => Reduce(5, NT_plaininstr, yy_action_529)
    _ => Error
  }
}

fn yy_state_67(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    NT_index_expression => Shift(yy_state_68)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_expression => Shift(yy_state_284)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_68(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_69)
    _ => Error
  }
}

fn yy_state_69(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_70)
    T_SEMI | T_QUESTIONMARK | T_LPAREN | T_RPAREN | T_LBRACE | T_RBRACE | T_LBRACKET | T_RBRACKET | T_COMMA | T_COLON | T_FATARROW | T_DOT | T_BANG | T_PLUS | T_MINUS | T_STAR | T_SLASH | T_SLASHS | T_SLASHU | T_PERCENTS | T_PERCENTU | T_AMPERSAND | T_PIPE | T_CARET | T_SHL | T_SHRS | T_SHRU | T_EQUALEQUAL | T_BANGEQUAL | T_GT | T_GTS | T_GTU | T_LT | T_LTS | T_LTU | T_GE | T_GES | T_GEU | T_LE | T_LES | T_LEU | T_AS | T_IS | T_ON => Reduce(4, NT_plaininstr, yy_action_528)
    _ => Error
  }
}

fn yy_state_70(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    NT_expression => Shift(yy_state_71)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_71(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_QUESTIONMARK => Shift(yy_state_63)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_LEU => Shift(yy_state_138)
    T_LES => Shift(yy_state_140)
    T_LE => Shift(yy_state_142)
    T_GEU => Shift(yy_state_144)
    T_GES => Shift(yy_state_146)
    T_GE => Shift(yy_state_148)
    T_LTU => Shift(yy_state_150)
    T_LTS => Shift(yy_state_152)
    T_LT => Shift(yy_state_154)
    T_GTU => Shift(yy_state_156)
    T_GTS => Shift(yy_state_158)
    T_GT => Shift(yy_state_160)
    T_BANGEQUAL => Shift(yy_state_162)
    T_EQUALEQUAL => Shift(yy_state_164)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_COLON | T_FATARROW => Reduce(6, NT_plaininstr, yy_action_527)
    _ => Error
  }
}

fn yy_state_72(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_on_clauses => Shift(yy_state_73)
    T_LBRACKET => Shift(yy_state_74)
    _ => Error
  }
}

fn yy_state_73(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_plaininstr, yy_action_526)
}

fn yy_state_74(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_on_clause => Shift(yy_state_75)
    NT_ident => Shift(yy_state_78)
    T_IDENT => Shift(yy_state_134)
    NT_non_empty_sep_trailing_COMMA_on_clause_ => Shift(yy_state_135)
    NT_sep_trailing_COMMA_on_clause_ => Shift(yy_state_136)
    T_RBRACKET => Reduce(0, NT_sep_trailing_COMMA_on_clause_, yy_action_525)
    _ => Error
  }
}

fn yy_state_75(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_76)
    T_RBRACKET => Reduce(1, NT_non_empty_sep_trailing_COMMA_on_clause_, yy_action_524)
    _ => Error
  }
}

fn yy_state_76(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_on_clause => Shift(yy_state_75)
    NT_non_empty_sep_trailing_COMMA_on_clause_ => Shift(yy_state_77)
    NT_ident => Shift(yy_state_78)
    T_IDENT => Shift(yy_state_134)
    T_RBRACKET => Reduce(2, NT_non_empty_sep_trailing_COMMA_on_clause_, yy_action_523)
    _ => Error
  }
}

fn yy_state_77(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_sep_trailing_COMMA_on_clause_, yy_action_522)
}

fn yy_state_78(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_ARROW => Shift(yy_state_79)
    _ => Error
  }
}

fn yy_state_79(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_ident => Shift(yy_state_80)
    NT_label => Shift(yy_state_81)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    _ => Error
  }
}

fn yy_state_80(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_on_clause, yy_action_521)
}

fn yy_state_81(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_on_clause, yy_action_520)
}

fn yy_state_82(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_label_name => Shift(yy_state_83)
    NT_ident_or_keyword => Shift(yy_state_84)
    T_NAN => Shift(yy_state_85)
    T_INF => Shift(yy_state_86)
    T_DESCRIBES => Shift(yy_state_87)
    T_DESCRIPTOR => Shift(yy_state_88)
    T_MATCH => Shift(yy_state_89)
    T_DISPATCH => Shift(yy_state_90)
    T_ELEM => Shift(yy_state_91)
    T_TABLE => Shift(yy_state_92)
    T_DATA => Shift(yy_state_93)
    T_SHARED => Shift(yy_state_94)
    T_PAGESIZE => Shift(yy_state_95)
    T_IMPORT => Shift(yy_state_96)
    T_MEMORY => Shift(yy_state_97)
    T_ON => Shift(yy_state_98)
    T_SUSPEND => Shift(yy_state_99)
    T_CONT => Shift(yy_state_100)
    T_CATCH => Shift(yy_state_101)
    T_TRY_LEGACY => Shift(yy_state_102)
    T_TRY => Shift(yy_state_103)
    T_BR_ON_NON_NULL => Shift(yy_state_104)
    T_BR_ON_NULL => Shift(yy_state_105)
    T_BR_ON_CAST_FAIL => Shift(yy_state_106)
    T_BR_ON_CAST => Shift(yy_state_107)
    T_THROW_REF => Shift(yy_state_108)
    T_THROW => Shift(yy_state_109)
    T_RETURN => Shift(yy_state_110)
    T_BR_TABLE => Shift(yy_state_111)
    T_BR_IF => Shift(yy_state_112)
    T_BR => Shift(yy_state_113)
    T_BECOME => Shift(yy_state_114)
    T_IS => Shift(yy_state_115)
    T_AS => Shift(yy_state_116)
    T_LET => Shift(yy_state_117)
    T_CONST => Shift(yy_state_118)
    T_ELSE => Shift(yy_state_119)
    T_IF => Shift(yy_state_120)
    T_LOOP => Shift(yy_state_121)
    T_WHILE => Shift(yy_state_122)
    T_DO => Shift(yy_state_123)
    T_NULL => Shift(yy_state_124)
    T_UNREACHABLE => Shift(yy_state_125)
    T_NOP => Shift(yy_state_126)
    T_OPEN => Shift(yy_state_127)
    T_REC => Shift(yy_state_128)
    T_TYPE => Shift(yy_state_129)
    T_MUT => Shift(yy_state_130)
    T_TAG => Shift(yy_state_131)
    T_FN => Shift(yy_state_132)
    T_IDENT => Shift(yy_state_133)
    _ => Error
  }
}

fn yy_state_83(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_label, yy_action_519)
}

fn yy_state_84(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_label_name, yy_action_518)
}

fn yy_state_85(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_ident_or_keyword, yy_action_517)
}

fn yy_state_86(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_ident_or_keyword, yy_action_516)
}

fn yy_state_87(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_ident_or_keyword, yy_action_515)
}

fn yy_state_88(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_ident_or_keyword, yy_action_514)
}

fn yy_state_89(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_ident_or_keyword, yy_action_513)
}

fn yy_state_90(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_ident_or_keyword, yy_action_512)
}

fn yy_state_91(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_ident_or_keyword, yy_action_511)
}

fn yy_state_92(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_ident_or_keyword, yy_action_510)
}

fn yy_state_93(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_ident_or_keyword, yy_action_509)
}

fn yy_state_94(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_ident_or_keyword, yy_action_508)
}

fn yy_state_95(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_ident_or_keyword, yy_action_507)
}

fn yy_state_96(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_ident_or_keyword, yy_action_506)
}

fn yy_state_97(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_ident_or_keyword, yy_action_505)
}

fn yy_state_98(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_ident_or_keyword, yy_action_504)
}

fn yy_state_99(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_ident_or_keyword, yy_action_503)
}

fn yy_state_100(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_ident_or_keyword, yy_action_502)
}

fn yy_state_101(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_ident_or_keyword, yy_action_501)
}

fn yy_state_102(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_ident_or_keyword, yy_action_500)
}

fn yy_state_103(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_ident_or_keyword, yy_action_499)
}

fn yy_state_104(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_ident_or_keyword, yy_action_498)
}

fn yy_state_105(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_ident_or_keyword, yy_action_497)
}

fn yy_state_106(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_ident_or_keyword, yy_action_496)
}

fn yy_state_107(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_ident_or_keyword, yy_action_495)
}

fn yy_state_108(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_ident_or_keyword, yy_action_494)
}

fn yy_state_109(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_ident_or_keyword, yy_action_493)
}

fn yy_state_110(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_ident_or_keyword, yy_action_492)
}

fn yy_state_111(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_ident_or_keyword, yy_action_491)
}

fn yy_state_112(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_ident_or_keyword, yy_action_490)
}

fn yy_state_113(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_ident_or_keyword, yy_action_489)
}

fn yy_state_114(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_ident_or_keyword, yy_action_488)
}

fn yy_state_115(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_ident_or_keyword, yy_action_487)
}

fn yy_state_116(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_ident_or_keyword, yy_action_486)
}

fn yy_state_117(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_ident_or_keyword, yy_action_485)
}

fn yy_state_118(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_ident_or_keyword, yy_action_484)
}

fn yy_state_119(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_ident_or_keyword, yy_action_483)
}

fn yy_state_120(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_ident_or_keyword, yy_action_482)
}

fn yy_state_121(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_ident_or_keyword, yy_action_481)
}

fn yy_state_122(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_ident_or_keyword, yy_action_480)
}

fn yy_state_123(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_ident_or_keyword, yy_action_479)
}

fn yy_state_124(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_ident_or_keyword, yy_action_478)
}

fn yy_state_125(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_ident_or_keyword, yy_action_477)
}

fn yy_state_126(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_ident_or_keyword, yy_action_476)
}

fn yy_state_127(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_ident_or_keyword, yy_action_475)
}

fn yy_state_128(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_ident_or_keyword, yy_action_474)
}

fn yy_state_129(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_ident_or_keyword, yy_action_473)
}

fn yy_state_130(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_ident_or_keyword, yy_action_472)
}

fn yy_state_131(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_ident_or_keyword, yy_action_471)
}

fn yy_state_132(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_ident_or_keyword, yy_action_470)
}

fn yy_state_133(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_ident_or_keyword, yy_action_469)
}

fn yy_state_134(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_ident, yy_action_468)
}

fn yy_state_135(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_sep_trailing_COMMA_on_clause_, yy_action_467)
}

fn yy_state_136(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_137)
    _ => Error
  }
}

fn yy_state_137(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_on_clauses, yy_action_466)
}

fn yy_state_138(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    NT_expression => Shift(yy_state_139)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_139(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_QUESTIONMARK | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_COLON | T_FATARROW | T_EQUALEQUAL | T_BANGEQUAL | T_GT | T_GTS | T_GTU | T_LT | T_LTS | T_LTU | T_GE | T_GES | T_GEU | T_LE | T_LES | T_LEU => Reduce(3, NT_plaininstr, yy_action_465)
    _ => Error
  }
}

fn yy_state_140(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    NT_expression => Shift(yy_state_141)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_141(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_QUESTIONMARK | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_COLON | T_FATARROW | T_EQUALEQUAL | T_BANGEQUAL | T_GT | T_GTS | T_GTU | T_LT | T_LTS | T_LTU | T_GE | T_GES | T_GEU | T_LE | T_LES | T_LEU => Reduce(3, NT_plaininstr, yy_action_464)
    _ => Error
  }
}

fn yy_state_142(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    NT_expression => Shift(yy_state_143)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_143(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_QUESTIONMARK | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_COLON | T_FATARROW | T_EQUALEQUAL | T_BANGEQUAL | T_GT | T_GTS | T_GTU | T_LT | T_LTS | T_LTU | T_GE | T_GES | T_GEU | T_LE | T_LES | T_LEU => Reduce(3, NT_plaininstr, yy_action_463)
    _ => Error
  }
}

fn yy_state_144(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    NT_expression => Shift(yy_state_145)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_145(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_QUESTIONMARK | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_COLON | T_FATARROW | T_EQUALEQUAL | T_BANGEQUAL | T_GT | T_GTS | T_GTU | T_LT | T_LTS | T_LTU | T_GE | T_GES | T_GEU | T_LE | T_LES | T_LEU => Reduce(3, NT_plaininstr, yy_action_462)
    _ => Error
  }
}

fn yy_state_146(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    NT_expression => Shift(yy_state_147)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_147(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_QUESTIONMARK | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_COLON | T_FATARROW | T_EQUALEQUAL | T_BANGEQUAL | T_GT | T_GTS | T_GTU | T_LT | T_LTS | T_LTU | T_GE | T_GES | T_GEU | T_LE | T_LES | T_LEU => Reduce(3, NT_plaininstr, yy_action_461)
    _ => Error
  }
}

fn yy_state_148(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    NT_expression => Shift(yy_state_149)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_149(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_QUESTIONMARK | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_COLON | T_FATARROW | T_EQUALEQUAL | T_BANGEQUAL | T_GT | T_GTS | T_GTU | T_LT | T_LTS | T_LTU | T_GE | T_GES | T_GEU | T_LE | T_LES | T_LEU => Reduce(3, NT_plaininstr, yy_action_460)
    _ => Error
  }
}

fn yy_state_150(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    NT_expression => Shift(yy_state_151)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_151(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_QUESTIONMARK | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_COLON | T_FATARROW | T_EQUALEQUAL | T_BANGEQUAL | T_GT | T_GTS | T_GTU | T_LT | T_LTS | T_LTU | T_GE | T_GES | T_GEU | T_LE | T_LES | T_LEU => Reduce(3, NT_plaininstr, yy_action_459)
    _ => Error
  }
}

fn yy_state_152(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    NT_expression => Shift(yy_state_153)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_153(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_QUESTIONMARK | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_COLON | T_FATARROW | T_EQUALEQUAL | T_BANGEQUAL | T_GT | T_GTS | T_GTU | T_LT | T_LTS | T_LTU | T_GE | T_GES | T_GEU | T_LE | T_LES | T_LEU => Reduce(3, NT_plaininstr, yy_action_458)
    _ => Error
  }
}

fn yy_state_154(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    NT_expression => Shift(yy_state_155)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_155(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_QUESTIONMARK | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_COLON | T_FATARROW | T_EQUALEQUAL | T_BANGEQUAL | T_GT | T_GTS | T_GTU | T_LT | T_LTS | T_LTU | T_GE | T_GES | T_GEU | T_LE | T_LES | T_LEU => Reduce(3, NT_plaininstr, yy_action_457)
    _ => Error
  }
}

fn yy_state_156(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    NT_expression => Shift(yy_state_157)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_157(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_QUESTIONMARK | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_COLON | T_FATARROW | T_EQUALEQUAL | T_BANGEQUAL | T_GT | T_GTS | T_GTU | T_LT | T_LTS | T_LTU | T_GE | T_GES | T_GEU | T_LE | T_LES | T_LEU => Reduce(3, NT_plaininstr, yy_action_456)
    _ => Error
  }
}

fn yy_state_158(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    NT_expression => Shift(yy_state_159)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_159(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_QUESTIONMARK | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_COLON | T_FATARROW | T_EQUALEQUAL | T_BANGEQUAL | T_GT | T_GTS | T_GTU | T_LT | T_LTS | T_LTU | T_GE | T_GES | T_GEU | T_LE | T_LES | T_LEU => Reduce(3, NT_plaininstr, yy_action_455)
    _ => Error
  }
}

fn yy_state_160(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    NT_expression => Shift(yy_state_161)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_161(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_QUESTIONMARK | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_COLON | T_FATARROW | T_EQUALEQUAL | T_BANGEQUAL | T_GT | T_GTS | T_GTU | T_LT | T_LTS | T_LTU | T_GE | T_GES | T_GEU | T_LE | T_LES | T_LEU => Reduce(3, NT_plaininstr, yy_action_454)
    _ => Error
  }
}

fn yy_state_162(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    NT_expression => Shift(yy_state_163)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_163(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_QUESTIONMARK | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_COLON | T_FATARROW | T_EQUALEQUAL | T_BANGEQUAL | T_GT | T_GTS | T_GTU | T_LT | T_LTS | T_LTU | T_GE | T_GES | T_GEU | T_LE | T_LES | T_LEU => Reduce(3, NT_plaininstr, yy_action_453)
    _ => Error
  }
}

fn yy_state_164(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    NT_expression => Shift(yy_state_165)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_165(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_QUESTIONMARK | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_COLON | T_FATARROW | T_EQUALEQUAL | T_BANGEQUAL | T_GT | T_GTS | T_GTU | T_LT | T_LTS | T_LTU | T_GE | T_GES | T_GEU | T_LE | T_LES | T_LEU => Reduce(3, NT_plaininstr, yy_action_452)
    _ => Error
  }
}

fn yy_state_166(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    NT_expression => Shift(yy_state_167)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_167(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_QUESTIONMARK | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_COLON | T_FATARROW | T_AMPERSAND | T_PIPE | T_CARET | T_SHL | T_SHRS | T_SHRU | T_EQUALEQUAL | T_BANGEQUAL | T_GT | T_GTS | T_GTU | T_LT | T_LTS | T_LTU | T_GE | T_GES | T_GEU | T_LE | T_LES | T_LEU => Reduce(3, NT_plaininstr, yy_action_451)
    _ => Error
  }
}

fn yy_state_168(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    NT_expression => Shift(yy_state_169)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_169(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_QUESTIONMARK | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_COLON | T_FATARROW | T_AMPERSAND | T_PIPE | T_CARET | T_SHL | T_SHRS | T_SHRU | T_EQUALEQUAL | T_BANGEQUAL | T_GT | T_GTS | T_GTU | T_LT | T_LTS | T_LTU | T_GE | T_GES | T_GEU | T_LE | T_LES | T_LEU => Reduce(3, NT_plaininstr, yy_action_450)
    _ => Error
  }
}

fn yy_state_170(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    NT_expression => Shift(yy_state_171)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_171(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_QUESTIONMARK | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_COLON | T_FATARROW | T_AMPERSAND | T_PIPE | T_CARET | T_SHL | T_SHRS | T_SHRU | T_EQUALEQUAL | T_BANGEQUAL | T_GT | T_GTS | T_GTU | T_LT | T_LTS | T_LTU | T_GE | T_GES | T_GEU | T_LE | T_LES | T_LEU => Reduce(3, NT_plaininstr, yy_action_449)
    _ => Error
  }
}

fn yy_state_172(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    NT_expression => Shift(yy_state_173)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_173(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_QUESTIONMARK | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_COLON | T_FATARROW | T_PIPE | T_EQUALEQUAL | T_BANGEQUAL | T_GT | T_GTS | T_GTU | T_LT | T_LTS | T_LTU | T_GE | T_GES | T_GEU | T_LE | T_LES | T_LEU => Reduce(3, NT_plaininstr, yy_action_448)
    _ => Error
  }
}

fn yy_state_174(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    NT_expression => Shift(yy_state_175)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_175(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_QUESTIONMARK | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_COLON | T_FATARROW | T_PIPE | T_CARET | T_EQUALEQUAL | T_BANGEQUAL | T_GT | T_GTS | T_GTU | T_LT | T_LTS | T_LTU | T_GE | T_GES | T_GEU | T_LE | T_LES | T_LEU => Reduce(3, NT_plaininstr, yy_action_447)
    _ => Error
  }
}

fn yy_state_176(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    NT_expression => Shift(yy_state_177)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_177(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_QUESTIONMARK | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_COLON | T_FATARROW | T_AMPERSAND | T_PIPE | T_CARET | T_EQUALEQUAL | T_BANGEQUAL | T_GT | T_GTS | T_GTU | T_LT | T_LTS | T_LTU | T_GE | T_GES | T_GEU | T_LE | T_LES | T_LEU => Reduce(3, NT_plaininstr, yy_action_446)
    _ => Error
  }
}

fn yy_state_178(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    NT_expression => Shift(yy_state_179)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_179(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_QUESTIONMARK | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_COLON | T_FATARROW | T_PLUS | T_MINUS | T_STAR | T_SLASH | T_SLASHS | T_SLASHU | T_PERCENTS | T_PERCENTU | T_AMPERSAND | T_PIPE | T_CARET | T_SHL | T_SHRS | T_SHRU | T_EQUALEQUAL | T_BANGEQUAL | T_GT | T_GTS | T_GTU | T_LT | T_LTS | T_LTU | T_GE | T_GES | T_GEU | T_LE | T_LES | T_LEU => Reduce(3, NT_plaininstr, yy_action_445)
    _ => Error
  }
}

fn yy_state_180(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    NT_expression => Shift(yy_state_181)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_181(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_QUESTIONMARK | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_COLON | T_FATARROW | T_PLUS | T_MINUS | T_STAR | T_SLASH | T_SLASHS | T_SLASHU | T_PERCENTS | T_PERCENTU | T_AMPERSAND | T_PIPE | T_CARET | T_SHL | T_SHRS | T_SHRU | T_EQUALEQUAL | T_BANGEQUAL | T_GT | T_GTS | T_GTU | T_LT | T_LTS | T_LTU | T_GE | T_GES | T_GEU | T_LE | T_LES | T_LEU => Reduce(3, NT_plaininstr, yy_action_444)
    _ => Error
  }
}

fn yy_state_182(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    NT_expression => Shift(yy_state_183)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_183(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_QUESTIONMARK | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_COLON | T_FATARROW | T_PLUS | T_MINUS | T_STAR | T_SLASH | T_SLASHS | T_SLASHU | T_PERCENTS | T_PERCENTU | T_AMPERSAND | T_PIPE | T_CARET | T_SHL | T_SHRS | T_SHRU | T_EQUALEQUAL | T_BANGEQUAL | T_GT | T_GTS | T_GTU | T_LT | T_LTS | T_LTU | T_GE | T_GES | T_GEU | T_LE | T_LES | T_LEU => Reduce(3, NT_plaininstr, yy_action_443)
    _ => Error
  }
}

fn yy_state_184(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    NT_expression => Shift(yy_state_185)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_185(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_QUESTIONMARK | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_COLON | T_FATARROW | T_PLUS | T_MINUS | T_STAR | T_SLASH | T_SLASHS | T_SLASHU | T_PERCENTS | T_PERCENTU | T_AMPERSAND | T_PIPE | T_CARET | T_SHL | T_SHRS | T_SHRU | T_EQUALEQUAL | T_BANGEQUAL | T_GT | T_GTS | T_GTU | T_LT | T_LTS | T_LTU | T_GE | T_GES | T_GEU | T_LE | T_LES | T_LEU => Reduce(3, NT_plaininstr, yy_action_442)
    _ => Error
  }
}

fn yy_state_186(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    NT_expression => Shift(yy_state_187)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_187(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_QUESTIONMARK | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_COLON | T_FATARROW | T_PLUS | T_MINUS | T_STAR | T_SLASH | T_SLASHS | T_SLASHU | T_PERCENTS | T_PERCENTU | T_AMPERSAND | T_PIPE | T_CARET | T_SHL | T_SHRS | T_SHRU | T_EQUALEQUAL | T_BANGEQUAL | T_GT | T_GTS | T_GTU | T_LT | T_LTS | T_LTU | T_GE | T_GES | T_GEU | T_LE | T_LES | T_LEU => Reduce(3, NT_plaininstr, yy_action_441)
    _ => Error
  }
}

fn yy_state_188(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    NT_expression => Shift(yy_state_189)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_189(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_QUESTIONMARK | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_COLON | T_FATARROW | T_PLUS | T_MINUS | T_STAR | T_SLASH | T_SLASHS | T_SLASHU | T_PERCENTS | T_PERCENTU | T_AMPERSAND | T_PIPE | T_CARET | T_SHL | T_SHRS | T_SHRU | T_EQUALEQUAL | T_BANGEQUAL | T_GT | T_GTS | T_GTU | T_LT | T_LTS | T_LTU | T_GE | T_GES | T_GEU | T_LE | T_LES | T_LEU => Reduce(3, NT_plaininstr, yy_action_440)
    _ => Error
  }
}

fn yy_state_190(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    NT_expression => Shift(yy_state_191)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_191(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_QUESTIONMARK | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_COLON | T_FATARROW | T_PLUS | T_MINUS | T_AMPERSAND | T_PIPE | T_CARET | T_SHL | T_SHRS | T_SHRU | T_EQUALEQUAL | T_BANGEQUAL | T_GT | T_GTS | T_GTU | T_LT | T_LTS | T_LTU | T_GE | T_GES | T_GEU | T_LE | T_LES | T_LEU => Reduce(3, NT_plaininstr, yy_action_439)
    _ => Error
  }
}

fn yy_state_192(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    NT_expression => Shift(yy_state_193)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_193(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_QUESTIONMARK | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_COLON | T_FATARROW | T_PLUS | T_MINUS | T_AMPERSAND | T_PIPE | T_CARET | T_SHL | T_SHRS | T_SHRU | T_EQUALEQUAL | T_BANGEQUAL | T_GT | T_GTS | T_GTU | T_LT | T_LTS | T_LTU | T_GE | T_GES | T_GEU | T_LE | T_LES | T_LEU => Reduce(3, NT_plaininstr, yy_action_438)
    _ => Error
  }
}

fn yy_state_194(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_134)
    T_DESCRIPTOR => Shift(yy_state_195)
    NT_ident => Shift(yy_state_196)
    _ => Error
  }
}

fn yy_state_195(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_plaininstr, yy_action_437)
}

fn yy_state_196(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_197)
    T_SEMI | T_QUESTIONMARK | T_LPAREN | T_RPAREN | T_LBRACE | T_RBRACE | T_LBRACKET | T_RBRACKET | T_COMMA | T_COLON | T_FATARROW | T_DOT | T_BANG | T_PLUS | T_MINUS | T_STAR | T_SLASH | T_SLASHS | T_SLASHU | T_PERCENTS | T_PERCENTU | T_AMPERSAND | T_PIPE | T_CARET | T_SHL | T_SHRS | T_SHRU | T_EQUALEQUAL | T_BANGEQUAL | T_GT | T_GTS | T_GTU | T_LT | T_LTS | T_LTU | T_GE | T_GES | T_GEU | T_LE | T_LES | T_LEU | T_AS | T_IS | T_ON => Reduce(3, NT_plaininstr, yy_action_436)
    _ => Error
  }
}

fn yy_state_197(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    NT_expression => Shift(yy_state_198)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_198(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_QUESTIONMARK => Shift(yy_state_63)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_LEU => Shift(yy_state_138)
    T_LES => Shift(yy_state_140)
    T_LE => Shift(yy_state_142)
    T_GEU => Shift(yy_state_144)
    T_GES => Shift(yy_state_146)
    T_GE => Shift(yy_state_148)
    T_LTU => Shift(yy_state_150)
    T_LTS => Shift(yy_state_152)
    T_LT => Shift(yy_state_154)
    T_GTU => Shift(yy_state_156)
    T_GTS => Shift(yy_state_158)
    T_GT => Shift(yy_state_160)
    T_BANGEQUAL => Shift(yy_state_162)
    T_EQUALEQUAL => Shift(yy_state_164)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_COLON | T_FATARROW => Reduce(5, NT_plaininstr, yy_action_435)
    _ => Error
  }
}

fn yy_state_199(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_reference_type => Shift(yy_state_200)
    T_AMPERSAND => Shift(yy_state_201)
    _ => Error
  }
}

fn yy_state_200(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_plaininstr, yy_action_434)
}

fn yy_state_201(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_QUESTIONMARK => Shift(yy_state_15)
    NT_boption_QUESTIONMARK_ => Shift(yy_state_202)
    T_IDENT | T_BANG | T_CONT => Reduce(0, NT_boption_QUESTIONMARK_, yy_action_551)
    _ => Error
  }
}

fn yy_state_202(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_203)
    NT_boption_BANG_ => Shift(yy_state_204)
    T_IDENT | T_CONT => Reduce(0, NT_boption_BANG_, yy_action_433)
    _ => Error
  }
}

fn yy_state_203(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_boption_BANG_, yy_action_432)
}

fn yy_state_204(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_134)
    NT_heap_type => Shift(yy_state_205)
    NT_ident => Shift(yy_state_206)
    T_CONT => Shift(yy_state_207)
    _ => Error
  }
}

fn yy_state_205(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_reference_type, yy_action_431)
}

fn yy_state_206(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_heap_type, yy_action_430)
}

fn yy_state_207(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_heap_type, yy_action_429)
}

fn yy_state_208(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_QUESTIONMARK => Shift(yy_state_15)
    NT_boption_QUESTIONMARK_ => Shift(yy_state_209)
    NT_cast_type => Shift(yy_state_552)
    NT_reference_type => Shift(yy_state_553)
    T_IDENT => Shift(yy_state_554)
    T_AMPERSAND => Shift(yy_state_555)
    T_DESCRIPTOR => Reduce(0, NT_boption_QUESTIONMARK_, yy_action_551)
    _ => Error
  }
}

fn yy_state_209(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_descriptor_operand => Shift(yy_state_210)
    T_DESCRIPTOR => Shift(yy_state_211)
    _ => Error
  }
}

fn yy_state_210(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_plaininstr, yy_action_428)
}

fn yy_state_211(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_212)
    _ => Error
  }
}

fn yy_state_212(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_expression => Shift(yy_state_215)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_213(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_plaininstr, yy_action_427)
}

fn yy_state_214(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_plaininstr, yy_action_426)
}

fn yy_state_215(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_QUESTIONMARK => Shift(yy_state_63)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_LEU => Shift(yy_state_138)
    T_LES => Shift(yy_state_140)
    T_LE => Shift(yy_state_142)
    T_GEU => Shift(yy_state_144)
    T_GES => Shift(yy_state_146)
    T_GE => Shift(yy_state_148)
    T_LTU => Shift(yy_state_150)
    T_LTS => Shift(yy_state_152)
    T_LT => Shift(yy_state_154)
    T_GTU => Shift(yy_state_156)
    T_GTS => Shift(yy_state_158)
    T_GT => Shift(yy_state_160)
    T_BANGEQUAL => Shift(yy_state_162)
    T_EQUALEQUAL => Shift(yy_state_164)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_RPAREN => Shift(yy_state_551)
    _ => Error
  }
}

fn yy_state_216(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_argument => Shift(yy_state_217)
    T_TAG => Shift(yy_state_220)
    NT_block_label => Shift(yy_state_223)
    NT_non_empty_sep_trailing_COMMA_argument_ => Shift(yy_state_249)
    NT_sep_trailing_COMMA_argument_ => Shift(yy_state_252)
    NT_ident => Shift(yy_state_253)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    NT_expression => Shift(yy_state_324)
    NT_argument_list => Shift(yy_state_549)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    T_RPAREN => Reduce(0, NT_sep_trailing_COMMA_argument_, yy_action_425)
    _ => Error
  }
}

fn yy_state_217(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_218)
    T_RPAREN => Reduce(1, NT_non_empty_sep_trailing_COMMA_argument_, yy_action_424)
    _ => Error
  }
}

fn yy_state_218(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_argument => Shift(yy_state_217)
    NT_non_empty_sep_trailing_COMMA_argument_ => Shift(yy_state_219)
    T_TAG => Shift(yy_state_220)
    NT_block_label => Shift(yy_state_223)
    NT_ident => Shift(yy_state_253)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    NT_expression => Shift(yy_state_324)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    T_RPAREN => Reduce(2, NT_non_empty_sep_trailing_COMMA_argument_, yy_action_423)
    _ => Error
  }
}

fn yy_state_219(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_sep_trailing_COMMA_argument_, yy_action_422)
}

fn yy_state_220(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_221)
    _ => Error
  }
}

fn yy_state_221(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_expression => Shift(yy_state_222)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_222(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_QUESTIONMARK => Shift(yy_state_63)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_LEU => Shift(yy_state_138)
    T_LES => Shift(yy_state_140)
    T_LE => Shift(yy_state_142)
    T_GEU => Shift(yy_state_144)
    T_GES => Shift(yy_state_146)
    T_GE => Shift(yy_state_148)
    T_LTU => Shift(yy_state_150)
    T_LTS => Shift(yy_state_152)
    T_LT => Shift(yy_state_154)
    T_GTU => Shift(yy_state_156)
    T_GTS => Shift(yy_state_158)
    T_GT => Shift(yy_state_160)
    T_BANGEQUAL => Shift(yy_state_162)
    T_EQUALEQUAL => Shift(yy_state_164)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_RPAREN | T_COMMA => Reduce(3, NT_argument, yy_action_421)
    _ => Error
  }
}

fn yy_state_223(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TRY_LEGACY => Shift(yy_state_224)
    T_TRY => Shift(yy_state_477)
    T_IF => Shift(yy_state_521)
    T_LOOP => Shift(yy_state_532)
    T_WHILE => Shift(yy_state_535)
    T_DO => Shift(yy_state_546)
    _ => Error
  }
}

fn yy_state_224(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AMPERSAND => Shift(yy_state_201)
    NT_block_type => Shift(yy_state_225)
    NT_option_block_type_ => Shift(yy_state_226)
    NT_reference_type => Shift(yy_state_355)
    T_IDENT => Shift(yy_state_356)
    NT_value_type => Shift(yy_state_455)
    T_LPAREN => Shift(yy_state_456)
    T_LBRACE => Reduce(0, NT_option_block_type_, yy_action_420)
    _ => Error
  }
}

fn yy_state_225(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_option_block_type_, yy_action_419)
}

fn yy_state_226(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_braced_block => Shift(yy_state_227)
    T_LBRACE => Shift(yy_state_237)
    _ => Error
  }
}

fn yy_state_227(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_CATCH => Shift(yy_state_228)
    _ => Error
  }
}

fn yy_state_228(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_229)
    _ => Error
  }
}

fn yy_state_229(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_134)
    NT_legacy_catch => Shift(yy_state_230)
    T_SEMI => Shift(yy_state_232)
    NT_ident => Shift(yy_state_234)
    NT_semi_list_legacy_catch_ => Shift(yy_state_448)
    T_RBRACE | T_UNDERSCORE => Reduce(0, NT_semi_list_legacy_catch_, yy_action_418)
    _ => Error
  }
}

fn yy_state_230(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_134)
    NT_legacy_catch => Shift(yy_state_230)
    NT_semi_list_legacy_catch_ => Shift(yy_state_231)
    T_SEMI => Shift(yy_state_232)
    NT_ident => Shift(yy_state_234)
    T_RBRACE | T_UNDERSCORE => Reduce(0, NT_semi_list_legacy_catch_, yy_action_418)
    _ => Error
  }
}

fn yy_state_231(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_semi_list_legacy_catch_, yy_action_417)
}

fn yy_state_232(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_134)
    NT_legacy_catch => Shift(yy_state_230)
    T_SEMI => Shift(yy_state_232)
    NT_semi_list_legacy_catch_ => Shift(yy_state_233)
    NT_ident => Shift(yy_state_234)
    T_RBRACE | T_UNDERSCORE => Reduce(0, NT_semi_list_legacy_catch_, yy_action_418)
    _ => Error
  }
}

fn yy_state_233(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_semi_list_legacy_catch_, yy_action_416)
}

fn yy_state_234(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FATARROW => Shift(yy_state_235)
    _ => Error
  }
}

fn yy_state_235(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_braced_block => Shift(yy_state_236)
    T_LBRACE => Shift(yy_state_237)
    _ => Error
  }
}

fn yy_state_236(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_legacy_catch, yy_action_415)
}

fn yy_state_237(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    NT_statement => Shift(yy_state_238)
    NT_cond_stmt => Shift(yy_state_242)
    T_SEMI => Shift(yy_state_244)
    T_BECOME => Shift(yy_state_246)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    NT_label => Shift(yy_state_323)
    T_THROW_REF => Shift(yy_state_325)
    T_THROW => Shift(yy_state_327)
    T_RETURN => Shift(yy_state_337)
    T_BR_TABLE => Shift(yy_state_339)
    T_BR => Shift(yy_state_344)
    T_LET => Shift(yy_state_347)
    T_UNREACHABLE => Shift(yy_state_374)
    T_NOP => Shift(yy_state_375)
    NT_hint_attr => Shift(yy_state_376)
    NT_plaininstr => Shift(yy_state_378)
    NT_blockinstr => Shift(yy_state_379)
    NT_expression => Shift(yy_state_381)
    NT_ident => Shift(yy_state_382)
    T_UNDERSCORE => Shift(yy_state_401)
    T_SHARP => Shift(yy_state_408)
    NT_raw_statement_list => Shift(yy_state_445)
    NT_statement_list => Shift(yy_state_446)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    T_RBRACE => Reduce(0, NT_raw_statement_list, yy_action_414)
    _ => Error
  }
}

fn yy_state_238(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_semi_then_statements => Shift(yy_state_239)
    T_SEMI => Shift(yy_state_240)
    NT_option_semi_then_statements_ => Shift(yy_state_444)
    T_RBRACE => Reduce(0, NT_option_semi_then_statements_, yy_action_413)
    _ => Error
  }
}

fn yy_state_239(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_option_semi_then_statements_, yy_action_412)
}

fn yy_state_240(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    NT_statement => Shift(yy_state_238)
    NT_raw_statement_list => Shift(yy_state_241)
    NT_cond_stmt => Shift(yy_state_242)
    T_SEMI => Shift(yy_state_244)
    T_BECOME => Shift(yy_state_246)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    NT_label => Shift(yy_state_323)
    T_THROW_REF => Shift(yy_state_325)
    T_THROW => Shift(yy_state_327)
    T_RETURN => Shift(yy_state_337)
    T_BR_TABLE => Shift(yy_state_339)
    T_BR => Shift(yy_state_344)
    T_LET => Shift(yy_state_347)
    T_UNREACHABLE => Shift(yy_state_374)
    T_NOP => Shift(yy_state_375)
    NT_hint_attr => Shift(yy_state_376)
    NT_plaininstr => Shift(yy_state_378)
    NT_blockinstr => Shift(yy_state_379)
    NT_expression => Shift(yy_state_381)
    NT_ident => Shift(yy_state_382)
    T_UNDERSCORE => Shift(yy_state_401)
    T_SHARP => Shift(yy_state_408)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    T_RBRACE => Reduce(0, NT_raw_statement_list, yy_action_414)
    _ => Error
  }
}

fn yy_state_241(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_semi_then_statements, yy_action_411)
}

fn yy_state_242(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    NT_statement => Shift(yy_state_238)
    NT_cond_stmt => Shift(yy_state_242)
    NT_raw_statement_list => Shift(yy_state_243)
    T_SEMI => Shift(yy_state_244)
    T_BECOME => Shift(yy_state_246)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    NT_label => Shift(yy_state_323)
    T_THROW_REF => Shift(yy_state_325)
    T_THROW => Shift(yy_state_327)
    T_RETURN => Shift(yy_state_337)
    T_BR_TABLE => Shift(yy_state_339)
    T_BR => Shift(yy_state_344)
    T_LET => Shift(yy_state_347)
    T_UNREACHABLE => Shift(yy_state_374)
    T_NOP => Shift(yy_state_375)
    NT_hint_attr => Shift(yy_state_376)
    NT_plaininstr => Shift(yy_state_378)
    NT_blockinstr => Shift(yy_state_379)
    NT_expression => Shift(yy_state_381)
    NT_ident => Shift(yy_state_382)
    T_UNDERSCORE => Shift(yy_state_401)
    T_SHARP => Shift(yy_state_408)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    T_RBRACE => Reduce(0, NT_raw_statement_list, yy_action_414)
    _ => Error
  }
}

fn yy_state_243(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_raw_statement_list, yy_action_410)
}

fn yy_state_244(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    NT_statement => Shift(yy_state_238)
    NT_cond_stmt => Shift(yy_state_242)
    T_SEMI => Shift(yy_state_244)
    NT_raw_statement_list => Shift(yy_state_245)
    T_BECOME => Shift(yy_state_246)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    NT_label => Shift(yy_state_323)
    T_THROW_REF => Shift(yy_state_325)
    T_THROW => Shift(yy_state_327)
    T_RETURN => Shift(yy_state_337)
    T_BR_TABLE => Shift(yy_state_339)
    T_BR => Shift(yy_state_344)
    T_LET => Shift(yy_state_347)
    T_UNREACHABLE => Shift(yy_state_374)
    T_NOP => Shift(yy_state_375)
    NT_hint_attr => Shift(yy_state_376)
    NT_plaininstr => Shift(yy_state_378)
    NT_blockinstr => Shift(yy_state_379)
    NT_expression => Shift(yy_state_381)
    NT_ident => Shift(yy_state_382)
    T_UNDERSCORE => Shift(yy_state_401)
    T_SHARP => Shift(yy_state_408)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    T_RBRACE => Reduce(0, NT_raw_statement_list, yy_action_414)
    _ => Error
  }
}

fn yy_state_245(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_raw_statement_list, yy_action_409)
}

fn yy_state_246(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    NT_expression => Shift(yy_state_247)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_247(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_QUESTIONMARK => Shift(yy_state_63)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_LEU => Shift(yy_state_138)
    T_LES => Shift(yy_state_140)
    T_LE => Shift(yy_state_142)
    T_GEU => Shift(yy_state_144)
    T_GES => Shift(yy_state_146)
    T_GE => Shift(yy_state_148)
    T_LTU => Shift(yy_state_150)
    T_LTS => Shift(yy_state_152)
    T_LT => Shift(yy_state_154)
    T_GTU => Shift(yy_state_156)
    T_GTS => Shift(yy_state_158)
    T_GT => Shift(yy_state_160)
    T_BANGEQUAL => Shift(yy_state_162)
    T_EQUALEQUAL => Shift(yy_state_164)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_248)
    _ => Error
  }
}

fn yy_state_248(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_argument => Shift(yy_state_217)
    T_TAG => Shift(yy_state_220)
    NT_block_label => Shift(yy_state_223)
    NT_non_empty_sep_trailing_COMMA_argument_ => Shift(yy_state_249)
    NT_argument_list => Shift(yy_state_250)
    NT_sep_trailing_COMMA_argument_ => Shift(yy_state_252)
    NT_ident => Shift(yy_state_253)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    NT_expression => Shift(yy_state_324)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    T_RPAREN => Reduce(0, NT_sep_trailing_COMMA_argument_, yy_action_425)
    _ => Error
  }
}

fn yy_state_249(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_sep_trailing_COMMA_argument_, yy_action_408)
}

fn yy_state_250(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_251)
    _ => Error
  }
}

fn yy_state_251(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_QUESTIONMARK | T_LPAREN | T_LBRACKET | T_DOT | T_BANG | T_PLUS | T_MINUS | T_STAR | T_SLASH | T_SLASHS | T_SLASHU | T_PERCENTS | T_PERCENTU | T_AMPERSAND | T_PIPE | T_CARET | T_SHL | T_SHRS | T_SHRU | T_EQUALEQUAL | T_BANGEQUAL | T_GT | T_GTS | T_GTU | T_LT | T_LTS | T_LTU | T_GE | T_GES | T_GEU | T_LE | T_LES | T_LEU | T_AS | T_IS | T_ON => Reduce(4, NT_plaininstr, yy_action_406)
    T_SEMI | T_RPAREN | T_RBRACE => Reduce(5, NT_statement, yy_action_407)
    _ => Error
  }
}

fn yy_state_252(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_argument_list, yy_action_405)
}

fn yy_state_253(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLONEQUAL => Shift(yy_state_60)
    T_SHARP => Shift(yy_state_254)
    T_COLONCOLON => Shift(yy_state_256)
    T_COLON => Shift(yy_state_258)
    T_QUESTIONMARK | T_LPAREN | T_RPAREN | T_LBRACKET | T_COMMA | T_DOT | T_BANG | T_PLUS | T_MINUS | T_STAR | T_SLASH | T_SLASHS | T_SLASHU | T_PERCENTS | T_PERCENTU | T_AMPERSAND | T_PIPE | T_CARET | T_SHL | T_SHRS | T_SHRU | T_EQUALEQUAL | T_BANGEQUAL | T_GT | T_GTS | T_GTU | T_LT | T_LTS | T_LTU | T_GE | T_GES | T_GEU | T_LE | T_LES | T_LEU | T_AS | T_IS | T_ON => Reduce(1, NT_plaininstr, yy_action_532)
    _ => Error
  }
}

fn yy_state_254(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_STRING => Shift(yy_state_255)
    _ => Error
  }
}

fn yy_state_255(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_plaininstr, yy_action_404)
}

fn yy_state_256(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_134)
    NT_ident => Shift(yy_state_257)
    _ => Error
  }
}

fn yy_state_257(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_plaininstr, yy_action_403)
}

fn yy_state_258(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    NT_expression => Shift(yy_state_259)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_259(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_QUESTIONMARK => Shift(yy_state_63)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_LEU => Shift(yy_state_138)
    T_LES => Shift(yy_state_140)
    T_LE => Shift(yy_state_142)
    T_GEU => Shift(yy_state_144)
    T_GES => Shift(yy_state_146)
    T_GE => Shift(yy_state_148)
    T_LTU => Shift(yy_state_150)
    T_LTS => Shift(yy_state_152)
    T_LT => Shift(yy_state_154)
    T_GTU => Shift(yy_state_156)
    T_GTS => Shift(yy_state_158)
    T_GT => Shift(yy_state_160)
    T_BANGEQUAL => Shift(yy_state_162)
    T_EQUALEQUAL => Shift(yy_state_164)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_RPAREN | T_COMMA => Reduce(3, NT_argument, yy_action_402)
    _ => Error
  }
}

fn yy_state_260(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    NT_expression => Shift(yy_state_261)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_261(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_QUESTIONMARK => Shift(yy_state_63)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_LEU => Shift(yy_state_138)
    T_LES => Shift(yy_state_140)
    T_LE => Shift(yy_state_142)
    T_GEU => Shift(yy_state_144)
    T_GES => Shift(yy_state_146)
    T_GE => Shift(yy_state_148)
    T_LTU => Shift(yy_state_150)
    T_LTS => Shift(yy_state_152)
    T_LT => Shift(yy_state_154)
    T_GTU => Shift(yy_state_156)
    T_GTS => Shift(yy_state_158)
    T_GT => Shift(yy_state_160)
    T_BANGEQUAL => Shift(yy_state_162)
    T_EQUALEQUAL => Shift(yy_state_164)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_LBRACE => Shift(yy_state_262)
    _ => Error
  }
}

fn yy_state_262(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_134)
    T_AMPERSAND => Shift(yy_state_201)
    NT_match_arm => Shift(yy_state_263)
    T_SEMI => Shift(yy_state_265)
    NT_match_pattern => Shift(yy_state_267)
    T_NULL => Shift(yy_state_270)
    NT_reference_type => Shift(yy_state_271)
    NT_ident => Shift(yy_state_272)
    NT_semi_list_match_arm_ => Shift(yy_state_275)
    T_UNDERSCORE => Reduce(0, NT_semi_list_match_arm_, yy_action_401)
    _ => Error
  }
}

fn yy_state_263(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_134)
    T_AMPERSAND => Shift(yy_state_201)
    NT_match_arm => Shift(yy_state_263)
    NT_semi_list_match_arm_ => Shift(yy_state_264)
    T_SEMI => Shift(yy_state_265)
    NT_match_pattern => Shift(yy_state_267)
    T_NULL => Shift(yy_state_270)
    NT_reference_type => Shift(yy_state_271)
    NT_ident => Shift(yy_state_272)
    T_UNDERSCORE => Reduce(0, NT_semi_list_match_arm_, yy_action_401)
    _ => Error
  }
}

fn yy_state_264(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_semi_list_match_arm_, yy_action_400)
}

fn yy_state_265(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_134)
    T_AMPERSAND => Shift(yy_state_201)
    NT_match_arm => Shift(yy_state_263)
    T_SEMI => Shift(yy_state_265)
    NT_semi_list_match_arm_ => Shift(yy_state_266)
    NT_match_pattern => Shift(yy_state_267)
    T_NULL => Shift(yy_state_270)
    NT_reference_type => Shift(yy_state_271)
    NT_ident => Shift(yy_state_272)
    T_UNDERSCORE => Reduce(0, NT_semi_list_match_arm_, yy_action_401)
    _ => Error
  }
}

fn yy_state_266(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_semi_list_match_arm_, yy_action_399)
}

fn yy_state_267(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FATARROW => Shift(yy_state_268)
    _ => Error
  }
}

fn yy_state_268(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_237)
    NT_braced_block => Shift(yy_state_269)
    _ => Error
  }
}

fn yy_state_269(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_match_arm, yy_action_398)
}

fn yy_state_270(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_match_pattern, yy_action_397)
}

fn yy_state_271(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_match_pattern, yy_action_396)
}

fn yy_state_272(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_273)
    _ => Error
  }
}

fn yy_state_273(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AMPERSAND => Shift(yy_state_201)
    NT_reference_type => Shift(yy_state_274)
    _ => Error
  }
}

fn yy_state_274(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_match_pattern, yy_action_395)
}

fn yy_state_275(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_match_default => Shift(yy_state_276)
    T_UNDERSCORE => Shift(yy_state_278)
    _ => Error
  }
}

fn yy_state_276(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_277)
    _ => Error
  }
}

fn yy_state_277(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_blockinstr, yy_action_394)
}

fn yy_state_278(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FATARROW => Shift(yy_state_279)
    _ => Error
  }
}

fn yy_state_279(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_237)
    NT_braced_block => Shift(yy_state_280)
    _ => Error
  }
}

fn yy_state_280(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_match_default, yy_action_393)
}

fn yy_state_281(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_expression => Shift(yy_state_282)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_282(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_QUESTIONMARK => Shift(yy_state_63)
    T_ON => Shift(yy_state_72)
    T_LEU => Shift(yy_state_138)
    T_LES => Shift(yy_state_140)
    T_LE => Shift(yy_state_142)
    T_GEU => Shift(yy_state_144)
    T_GES => Shift(yy_state_146)
    T_GE => Shift(yy_state_148)
    T_LTU => Shift(yy_state_150)
    T_LTS => Shift(yy_state_152)
    T_LT => Shift(yy_state_154)
    T_GTU => Shift(yy_state_156)
    T_GTS => Shift(yy_state_158)
    T_GT => Shift(yy_state_160)
    T_BANGEQUAL => Shift(yy_state_162)
    T_EQUALEQUAL => Shift(yy_state_164)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_LBRACKET => Shift(yy_state_283)
    _ => Error
  }
}

fn yy_state_283(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    NT_index_expression => Shift(yy_state_68)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_expression => Shift(yy_state_284)
    NT_case_labels => Shift(yy_state_285)
    T_ELSE => Shift(yy_state_297)
    NT_label => Shift(yy_state_299)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_284(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_QUESTIONMARK => Shift(yy_state_63)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_LEU => Shift(yy_state_138)
    T_LES => Shift(yy_state_140)
    T_LE => Shift(yy_state_142)
    T_GEU => Shift(yy_state_144)
    T_GES => Shift(yy_state_146)
    T_GE => Shift(yy_state_148)
    T_LTU => Shift(yy_state_150)
    T_LTS => Shift(yy_state_152)
    T_LT => Shift(yy_state_154)
    T_GTU => Shift(yy_state_156)
    T_GTS => Shift(yy_state_158)
    T_GT => Shift(yy_state_160)
    T_BANGEQUAL => Shift(yy_state_162)
    T_EQUALEQUAL => Shift(yy_state_164)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_RBRACKET => Reduce(1, NT_index_expression, yy_action_392)
    _ => Error
  }
}

fn yy_state_285(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_286)
    _ => Error
  }
}

fn yy_state_286(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_287)
    _ => Error
  }
}

fn yy_state_287(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_QUOTE => Shift(yy_state_82)
    NT_dispatch_arm => Shift(yy_state_288)
    T_SEMI => Shift(yy_state_290)
    NT_label => Shift(yy_state_292)
    NT_semi_list_dispatch_arm_ => Shift(yy_state_295)
    T_RBRACE => Reduce(0, NT_semi_list_dispatch_arm_, yy_action_391)
    _ => Error
  }
}

fn yy_state_288(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_QUOTE => Shift(yy_state_82)
    NT_dispatch_arm => Shift(yy_state_288)
    NT_semi_list_dispatch_arm_ => Shift(yy_state_289)
    T_SEMI => Shift(yy_state_290)
    NT_label => Shift(yy_state_292)
    T_RBRACE => Reduce(0, NT_semi_list_dispatch_arm_, yy_action_391)
    _ => Error
  }
}

fn yy_state_289(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_semi_list_dispatch_arm_, yy_action_390)
}

fn yy_state_290(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_QUOTE => Shift(yy_state_82)
    NT_dispatch_arm => Shift(yy_state_288)
    T_SEMI => Shift(yy_state_290)
    NT_semi_list_dispatch_arm_ => Shift(yy_state_291)
    NT_label => Shift(yy_state_292)
    T_RBRACE => Reduce(0, NT_semi_list_dispatch_arm_, yy_action_391)
    _ => Error
  }
}

fn yy_state_291(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_semi_list_dispatch_arm_, yy_action_389)
}

fn yy_state_292(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_293)
    _ => Error
  }
}

fn yy_state_293(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_237)
    NT_braced_block => Shift(yy_state_294)
    _ => Error
  }
}

fn yy_state_294(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_dispatch_arm, yy_action_388)
}

fn yy_state_295(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_296)
    _ => Error
  }
}

fn yy_state_296(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(8, NT_blockinstr, yy_action_387)
}

fn yy_state_297(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_QUOTE => Shift(yy_state_82)
    NT_label => Shift(yy_state_298)
    _ => Error
  }
}

fn yy_state_298(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_case_labels, yy_action_386)
}

fn yy_state_299(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_300)
    T_COLON => Shift(yy_state_303)
    _ => Error
  }
}

fn yy_state_300(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_QUOTE => Shift(yy_state_82)
    T_ELSE => Shift(yy_state_297)
    NT_case_labels => Shift(yy_state_301)
    NT_label => Shift(yy_state_302)
    _ => Error
  }
}

fn yy_state_301(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_case_labels, yy_action_385)
}

fn yy_state_302(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_300)
    _ => Error
  }
}

fn yy_state_303(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_labelled, yy_action_384)
}

fn yy_state_304(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_block_label, yy_action_382)
}

fn yy_state_305(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_hint_attr, yy_action_381)
}

fn yy_state_306(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_307)
    _ => Error
  }
}

fn yy_state_307(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_attribute_name => Shift(yy_state_6)
    T_IMPORT => Shift(yy_state_308)
    T_IDENT => Shift(yy_state_309)
    _ => Error
  }
}

fn yy_state_308(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_attribute_name, yy_action_380)
}

fn yy_state_309(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_310)
    T_RBRACKET | T_COMMA | T_EQUAL => Reduce(1, NT_attribute_name, yy_action_379)
    _ => Error
  }
}

fn yy_state_310(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_134)
    NT_hint_target => Shift(yy_state_311)
    NT_ident => Shift(yy_state_314)
    NT_non_empty_sep_trailing_COMMA_hint_target_ => Shift(yy_state_319)
    NT_sep_trailing_COMMA_hint_target_ => Shift(yy_state_320)
    T_RPAREN => Reduce(0, NT_sep_trailing_COMMA_hint_target_, yy_action_378)
    _ => Error
  }
}

fn yy_state_311(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_312)
    T_RPAREN => Reduce(1, NT_non_empty_sep_trailing_COMMA_hint_target_, yy_action_377)
    _ => Error
  }
}

fn yy_state_312(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_134)
    NT_hint_target => Shift(yy_state_311)
    NT_non_empty_sep_trailing_COMMA_hint_target_ => Shift(yy_state_313)
    NT_ident => Shift(yy_state_314)
    T_RPAREN => Reduce(2, NT_non_empty_sep_trailing_COMMA_hint_target_, yy_action_376)
    _ => Error
  }
}

fn yy_state_313(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_sep_trailing_COMMA_hint_target_, yy_action_375)
}

fn yy_state_314(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_315)
    _ => Error
  }
}

fn yy_state_315(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_INT => Shift(yy_state_316)
    T_FLOAT => Shift(yy_state_317)
    NT_target_fraction => Shift(yy_state_318)
    _ => Error
  }
}

fn yy_state_316(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_target_fraction, yy_action_374)
}

fn yy_state_317(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_target_fraction, yy_action_373)
}

fn yy_state_318(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_hint_target, yy_action_372)
}

fn yy_state_319(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_sep_trailing_COMMA_hint_target_, yy_action_371)
}

fn yy_state_320(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_321)
    _ => Error
  }
}

fn yy_state_321(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_322)
    _ => Error
  }
}

fn yy_state_322(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(7, NT_hint_attr, yy_action_370)
}

fn yy_state_323(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_303)
    _ => Error
  }
}

fn yy_state_324(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_QUESTIONMARK => Shift(yy_state_63)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_LEU => Shift(yy_state_138)
    T_LES => Shift(yy_state_140)
    T_LE => Shift(yy_state_142)
    T_GEU => Shift(yy_state_144)
    T_GES => Shift(yy_state_146)
    T_GE => Shift(yy_state_148)
    T_LTU => Shift(yy_state_150)
    T_LTS => Shift(yy_state_152)
    T_LT => Shift(yy_state_154)
    T_GTU => Shift(yy_state_156)
    T_GTS => Shift(yy_state_158)
    T_GT => Shift(yy_state_160)
    T_BANGEQUAL => Shift(yy_state_162)
    T_EQUALEQUAL => Shift(yy_state_164)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_RPAREN | T_COMMA => Reduce(1, NT_argument, yy_action_369)
    _ => Error
  }
}

fn yy_state_325(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    NT_expression => Shift(yy_state_326)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_326(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_QUESTIONMARK => Shift(yy_state_63)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_LEU => Shift(yy_state_138)
    T_LES => Shift(yy_state_140)
    T_LE => Shift(yy_state_142)
    T_GEU => Shift(yy_state_144)
    T_GES => Shift(yy_state_146)
    T_GE => Shift(yy_state_148)
    T_LTU => Shift(yy_state_150)
    T_LTS => Shift(yy_state_152)
    T_LT => Shift(yy_state_154)
    T_GTU => Shift(yy_state_156)
    T_GTS => Shift(yy_state_158)
    T_GT => Shift(yy_state_160)
    T_BANGEQUAL => Shift(yy_state_162)
    T_EQUALEQUAL => Shift(yy_state_164)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_RPAREN | T_RBRACE => Reduce(2, NT_statement, yy_action_368)
    _ => Error
  }
}

fn yy_state_327(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_134)
    NT_tag_name => Shift(yy_state_328)
    NT_ident => Shift(yy_state_336)
    _ => Error
  }
}

fn yy_state_328(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_329)
    _ => Error
  }
}

fn yy_state_329(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_non_empty_sep_trailing_COMMA_expression_ => Shift(yy_state_34)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    NT_expression_list => Shift(yy_state_330)
    NT_expression => Shift(yy_state_332)
    NT_sep_trailing_COMMA_expression_ => Shift(yy_state_335)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    T_RPAREN => Reduce(0, NT_sep_trailing_COMMA_expression_, yy_action_549)
    _ => Error
  }
}

fn yy_state_330(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_331)
    _ => Error
  }
}

fn yy_state_331(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_statement, yy_action_367)
}

fn yy_state_332(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_QUESTIONMARK => Shift(yy_state_63)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_LEU => Shift(yy_state_138)
    T_LES => Shift(yy_state_140)
    T_LE => Shift(yy_state_142)
    T_GEU => Shift(yy_state_144)
    T_GES => Shift(yy_state_146)
    T_GE => Shift(yy_state_148)
    T_LTU => Shift(yy_state_150)
    T_LTS => Shift(yy_state_152)
    T_LT => Shift(yy_state_154)
    T_GTU => Shift(yy_state_156)
    T_GTS => Shift(yy_state_158)
    T_GT => Shift(yy_state_160)
    T_BANGEQUAL => Shift(yy_state_162)
    T_EQUALEQUAL => Shift(yy_state_164)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_COMMA => Shift(yy_state_333)
    T_RPAREN | T_RBRACKET => Reduce(1, NT_non_empty_sep_trailing_COMMA_expression_, yy_action_366)
    _ => Error
  }
}

fn yy_state_333(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    NT_expression => Shift(yy_state_332)
    NT_non_empty_sep_trailing_COMMA_expression_ => Shift(yy_state_334)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    T_RPAREN | T_RBRACKET => Reduce(2, NT_non_empty_sep_trailing_COMMA_expression_, yy_action_365)
    _ => Error
  }
}

fn yy_state_334(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_sep_trailing_COMMA_expression_, yy_action_364)
}

fn yy_state_335(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_expression_list, yy_action_363)
}

fn yy_state_336(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_tag_name, yy_action_362)
}

fn yy_state_337(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    NT_expression => Shift(yy_state_338)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    T_SEMI | T_RPAREN | T_RBRACE => Reduce(1, NT_statement, yy_action_361)
    _ => Error
  }
}

fn yy_state_338(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_QUESTIONMARK => Shift(yy_state_63)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_LEU => Shift(yy_state_138)
    T_LES => Shift(yy_state_140)
    T_LE => Shift(yy_state_142)
    T_GEU => Shift(yy_state_144)
    T_GES => Shift(yy_state_146)
    T_GE => Shift(yy_state_148)
    T_LTU => Shift(yy_state_150)
    T_LTS => Shift(yy_state_152)
    T_LT => Shift(yy_state_154)
    T_GTU => Shift(yy_state_156)
    T_GTS => Shift(yy_state_158)
    T_GT => Shift(yy_state_160)
    T_BANGEQUAL => Shift(yy_state_162)
    T_EQUALEQUAL => Shift(yy_state_164)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_RPAREN | T_RBRACE => Reduce(2, NT_statement, yy_action_360)
    _ => Error
  }
}

fn yy_state_339(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_340)
    _ => Error
  }
}

fn yy_state_340(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_QUOTE => Shift(yy_state_82)
    T_ELSE => Shift(yy_state_297)
    NT_label => Shift(yy_state_302)
    NT_case_labels => Shift(yy_state_341)
    _ => Error
  }
}

fn yy_state_341(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_342)
    _ => Error
  }
}

fn yy_state_342(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    NT_expression => Shift(yy_state_343)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_343(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_QUESTIONMARK => Shift(yy_state_63)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_LEU => Shift(yy_state_138)
    T_LES => Shift(yy_state_140)
    T_LE => Shift(yy_state_142)
    T_GEU => Shift(yy_state_144)
    T_GES => Shift(yy_state_146)
    T_GE => Shift(yy_state_148)
    T_LTU => Shift(yy_state_150)
    T_LTS => Shift(yy_state_152)
    T_LT => Shift(yy_state_154)
    T_GTU => Shift(yy_state_156)
    T_GTS => Shift(yy_state_158)
    T_GT => Shift(yy_state_160)
    T_BANGEQUAL => Shift(yy_state_162)
    T_EQUALEQUAL => Shift(yy_state_164)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_RPAREN | T_RBRACE => Reduce(5, NT_statement, yy_action_359)
    _ => Error
  }
}

fn yy_state_344(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_QUOTE => Shift(yy_state_82)
    NT_label => Shift(yy_state_345)
    _ => Error
  }
}

fn yy_state_345(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    NT_expression => Shift(yy_state_346)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    T_SEMI | T_RPAREN | T_RBRACE => Reduce(2, NT_statement, yy_action_357)
    _ => Error
  }
}

fn yy_state_346(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_QUESTIONMARK => Shift(yy_state_63)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_LEU => Shift(yy_state_138)
    T_LES => Shift(yy_state_140)
    T_LE => Shift(yy_state_142)
    T_GEU => Shift(yy_state_144)
    T_GES => Shift(yy_state_146)
    T_GE => Shift(yy_state_148)
    T_LTU => Shift(yy_state_150)
    T_LTS => Shift(yy_state_152)
    T_LT => Shift(yy_state_154)
    T_GTU => Shift(yy_state_156)
    T_GTS => Shift(yy_state_158)
    T_GT => Shift(yy_state_160)
    T_BANGEQUAL => Shift(yy_state_162)
    T_EQUALEQUAL => Shift(yy_state_164)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_RPAREN | T_RBRACE => Reduce(3, NT_statement, yy_action_355)
    _ => Error
  }
}

fn yy_state_347(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_134)
    T_LPAREN => Shift(yy_state_348)
    T_UNDERSCORE => Shift(yy_state_358)
    NT_ident => Shift(yy_state_359)
    NT_simple_pattern => Shift(yy_state_367)
    _ => Error
  }
}

fn yy_state_348(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_134)
    NT_let_pattern => Shift(yy_state_349)
    NT_simple_pattern => Shift(yy_state_352)
    T_UNDERSCORE => Shift(yy_state_358)
    NT_ident => Shift(yy_state_359)
    NT_non_empty_sep_trailing_COMMA_let_pattern_ => Shift(yy_state_360)
    NT_let_pattern_ => Shift(yy_state_361)
    NT_sep_trailing_COMMA_let_pattern_ => Shift(yy_state_366)
    T_RPAREN => Reduce(0, NT_sep_trailing_COMMA_let_pattern_, yy_action_354)
    _ => Error
  }
}

fn yy_state_349(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_350)
    T_RPAREN => Reduce(1, NT_non_empty_sep_trailing_COMMA_let_pattern_, yy_action_353)
    _ => Error
  }
}

fn yy_state_350(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_134)
    NT_let_pattern => Shift(yy_state_349)
    NT_non_empty_sep_trailing_COMMA_let_pattern_ => Shift(yy_state_351)
    NT_simple_pattern => Shift(yy_state_352)
    T_UNDERSCORE => Shift(yy_state_358)
    NT_ident => Shift(yy_state_359)
    T_RPAREN => Reduce(2, NT_non_empty_sep_trailing_COMMA_let_pattern_, yy_action_352)
    _ => Error
  }
}

fn yy_state_351(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_sep_trailing_COMMA_let_pattern_, yy_action_351)
}

fn yy_state_352(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_353)
    NT_type_annot => Shift(yy_state_357)
    T_RPAREN | T_COMMA => Reduce(1, NT_let_pattern, yy_action_350)
    _ => Error
  }
}

fn yy_state_353(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AMPERSAND => Shift(yy_state_201)
    NT_value_type => Shift(yy_state_354)
    NT_reference_type => Shift(yy_state_355)
    T_IDENT => Shift(yy_state_356)
    _ => Error
  }
}

fn yy_state_354(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_type_annot, yy_action_349)
}

fn yy_state_355(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_value_type, yy_action_348)
}

fn yy_state_356(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_value_type, yy_action_347)
}

fn yy_state_357(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_let_pattern, yy_action_346)
}

fn yy_state_358(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_simple_pattern, yy_action_345)
}

fn yy_state_359(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_simple_pattern, yy_action_344)
}

fn yy_state_360(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_sep_trailing_COMMA_let_pattern_, yy_action_343)
}

fn yy_state_361(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_362)
    _ => Error
  }
}

fn yy_state_362(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_363)
    NT_let_init => Shift(yy_state_365)
    T_SEMI | T_RPAREN | T_RBRACE => Reduce(4, NT_statement, yy_action_341)
    _ => Error
  }
}

fn yy_state_363(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    NT_expression => Shift(yy_state_364)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_364(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_QUESTIONMARK => Shift(yy_state_63)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_LEU => Shift(yy_state_138)
    T_LES => Shift(yy_state_140)
    T_LE => Shift(yy_state_142)
    T_GEU => Shift(yy_state_144)
    T_GES => Shift(yy_state_146)
    T_GE => Shift(yy_state_148)
    T_LTU => Shift(yy_state_150)
    T_LTS => Shift(yy_state_152)
    T_LT => Shift(yy_state_154)
    T_GTU => Shift(yy_state_156)
    T_GTS => Shift(yy_state_158)
    T_GT => Shift(yy_state_160)
    T_BANGEQUAL => Shift(yy_state_162)
    T_EQUALEQUAL => Shift(yy_state_164)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_RPAREN | T_RBRACE => Reduce(2, NT_let_init, yy_action_340)
    _ => Error
  }
}

fn yy_state_365(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_statement, yy_action_338)
}

fn yy_state_366(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_let_pattern_, yy_action_337)
}

fn yy_state_367(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_368)
    T_EQUAL => Shift(yy_state_372)
    T_SEMI | T_RPAREN | T_RBRACE => Reduce(2, NT_statement, yy_action_336)
    _ => Error
  }
}

fn yy_state_368(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AMPERSAND => Shift(yy_state_201)
    NT_reference_type => Shift(yy_state_355)
    T_IDENT => Shift(yy_state_356)
    NT_value_type => Shift(yy_state_369)
    _ => Error
  }
}

fn yy_state_369(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_370)
    T_SEMI | T_RPAREN | T_RBRACE => Reduce(4, NT_statement, yy_action_335)
    _ => Error
  }
}

fn yy_state_370(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    NT_expression => Shift(yy_state_371)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_371(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_QUESTIONMARK => Shift(yy_state_63)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_LEU => Shift(yy_state_138)
    T_LES => Shift(yy_state_140)
    T_LE => Shift(yy_state_142)
    T_GEU => Shift(yy_state_144)
    T_GES => Shift(yy_state_146)
    T_GE => Shift(yy_state_148)
    T_LTU => Shift(yy_state_150)
    T_LTS => Shift(yy_state_152)
    T_LT => Shift(yy_state_154)
    T_GTU => Shift(yy_state_156)
    T_GTS => Shift(yy_state_158)
    T_GT => Shift(yy_state_160)
    T_BANGEQUAL => Shift(yy_state_162)
    T_EQUALEQUAL => Shift(yy_state_164)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_RPAREN | T_RBRACE => Reduce(6, NT_statement, yy_action_334)
    _ => Error
  }
}

fn yy_state_372(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    NT_expression => Shift(yy_state_373)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_373(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_QUESTIONMARK => Shift(yy_state_63)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_LEU => Shift(yy_state_138)
    T_LES => Shift(yy_state_140)
    T_LE => Shift(yy_state_142)
    T_GEU => Shift(yy_state_144)
    T_GES => Shift(yy_state_146)
    T_GE => Shift(yy_state_148)
    T_LTU => Shift(yy_state_150)
    T_LTS => Shift(yy_state_152)
    T_LT => Shift(yy_state_154)
    T_GTU => Shift(yy_state_156)
    T_GTS => Shift(yy_state_158)
    T_GT => Shift(yy_state_160)
    T_BANGEQUAL => Shift(yy_state_162)
    T_EQUALEQUAL => Shift(yy_state_164)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_RPAREN | T_RBRACE => Reduce(4, NT_statement, yy_action_333)
    _ => Error
  }
}

fn yy_state_374(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_statement, yy_action_332)
}

fn yy_state_375(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_statement, yy_action_331)
}

fn yy_state_376(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    NT_statement => Shift(yy_state_238)
    NT_cond_stmt => Shift(yy_state_242)
    T_SEMI => Shift(yy_state_244)
    T_BECOME => Shift(yy_state_246)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    NT_label => Shift(yy_state_323)
    T_THROW_REF => Shift(yy_state_325)
    T_THROW => Shift(yy_state_327)
    T_RETURN => Shift(yy_state_337)
    T_BR_TABLE => Shift(yy_state_339)
    T_BR => Shift(yy_state_344)
    T_LET => Shift(yy_state_347)
    T_UNREACHABLE => Shift(yy_state_374)
    T_NOP => Shift(yy_state_375)
    NT_hint_attr => Shift(yy_state_376)
    NT_raw_statement_list => Shift(yy_state_377)
    NT_plaininstr => Shift(yy_state_378)
    NT_blockinstr => Shift(yy_state_379)
    NT_ident => Shift(yy_state_382)
    T_UNDERSCORE => Shift(yy_state_401)
    T_SHARP => Shift(yy_state_408)
    NT_expression => Shift(yy_state_443)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    T_RBRACE => Reduce(0, NT_raw_statement_list, yy_action_414)
    _ => Error
  }
}

fn yy_state_377(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_raw_statement_list, yy_action_330)
}

fn yy_state_378(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_QUESTIONMARK | T_LPAREN | T_LBRACKET | T_DOT | T_BANG | T_PLUS | T_MINUS | T_STAR | T_SLASH | T_SLASHS | T_SLASHU | T_PERCENTS | T_PERCENTU | T_AMPERSAND | T_PIPE | T_CARET | T_SHL | T_SHRS | T_SHRU | T_EQUALEQUAL | T_BANGEQUAL | T_GT | T_GTS | T_GTU | T_LT | T_LTS | T_LTU | T_GE | T_GES | T_GEU | T_LE | T_LES | T_LEU | T_AS | T_IS | T_ON => Reduce(1, NT_expression, yy_action_553)
    T_SEMI | T_RPAREN | T_RBRACE => Reduce(1, NT_statement, yy_action_329)
    _ => Error
  }
}

fn yy_state_379(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    NT_statement => Shift(yy_state_238)
    NT_cond_stmt => Shift(yy_state_242)
    T_SEMI => Shift(yy_state_244)
    T_BECOME => Shift(yy_state_246)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    NT_label => Shift(yy_state_323)
    T_THROW_REF => Shift(yy_state_325)
    T_THROW => Shift(yy_state_327)
    T_RETURN => Shift(yy_state_337)
    T_BR_TABLE => Shift(yy_state_339)
    T_BR => Shift(yy_state_344)
    T_LET => Shift(yy_state_347)
    T_UNREACHABLE => Shift(yy_state_374)
    T_NOP => Shift(yy_state_375)
    NT_hint_attr => Shift(yy_state_376)
    NT_plaininstr => Shift(yy_state_378)
    NT_blockinstr => Shift(yy_state_379)
    NT_raw_statement_list => Shift(yy_state_380)
    NT_expression => Shift(yy_state_381)
    NT_ident => Shift(yy_state_382)
    T_UNDERSCORE => Shift(yy_state_401)
    T_SHARP => Shift(yy_state_408)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    T_RBRACE => Reduce(0, NT_raw_statement_list, yy_action_414)
    T_QUESTIONMARK | T_DOT | T_STAR | T_SLASH | T_SLASHS | T_SLASHU | T_PERCENTS | T_PERCENTU | T_AMPERSAND | T_PIPE | T_CARET | T_SHL | T_SHRS | T_SHRU | T_EQUALEQUAL | T_BANGEQUAL | T_GT | T_GTS | T_GTU | T_LT | T_LTS | T_LTU | T_GE | T_GES | T_GEU | T_LE | T_LES | T_LEU | T_AS | T_IS | T_ON => Reduce(1, NT_expression, yy_action_552)
    _ => Error
  }
}

fn yy_state_380(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_raw_statement_list, yy_action_328)
}

fn yy_state_381(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_QUESTIONMARK => Shift(yy_state_63)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_LEU => Shift(yy_state_138)
    T_LES => Shift(yy_state_140)
    T_LE => Shift(yy_state_142)
    T_GEU => Shift(yy_state_144)
    T_GES => Shift(yy_state_146)
    T_GE => Shift(yy_state_148)
    T_LTU => Shift(yy_state_150)
    T_LTS => Shift(yy_state_152)
    T_LT => Shift(yy_state_154)
    T_GTU => Shift(yy_state_156)
    T_GTS => Shift(yy_state_158)
    T_GT => Shift(yy_state_160)
    T_BANGEQUAL => Shift(yy_state_162)
    T_EQUALEQUAL => Shift(yy_state_164)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    _ => Error
  }
}

fn yy_state_382(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLONEQUAL => Shift(yy_state_60)
    T_SHARP => Shift(yy_state_254)
    T_COLONCOLON => Shift(yy_state_256)
    NT_compound_assign_op => Shift(yy_state_383)
    T_EQUAL => Shift(yy_state_385)
    T_SHRUEQUAL => Shift(yy_state_387)
    T_SHRSEQUAL => Shift(yy_state_388)
    T_SHLEQUAL => Shift(yy_state_389)
    T_CARETEQUAL => Shift(yy_state_390)
    T_PIPEEQUAL => Shift(yy_state_391)
    T_AMPERSANDEQUAL => Shift(yy_state_392)
    T_PERCENTUEQUAL => Shift(yy_state_393)
    T_PERCENTSEQUAL => Shift(yy_state_394)
    T_SLASHUEQUAL => Shift(yy_state_395)
    T_SLASHSEQUAL => Shift(yy_state_396)
    T_SLASHEQUAL => Shift(yy_state_397)
    T_STAREQUAL => Shift(yy_state_398)
    T_MINUSEQUAL => Shift(yy_state_399)
    T_PLUSEQUAL => Shift(yy_state_400)
    T_SEMI | T_QUESTIONMARK | T_LPAREN | T_RPAREN | T_RBRACE | T_LBRACKET | T_DOT | T_BANG | T_PLUS | T_MINUS | T_STAR | T_SLASH | T_SLASHS | T_SLASHU | T_PERCENTS | T_PERCENTU | T_AMPERSAND | T_PIPE | T_CARET | T_SHL | T_SHRS | T_SHRU | T_EQUALEQUAL | T_BANGEQUAL | T_GT | T_GTS | T_GTU | T_LT | T_LTS | T_LTU | T_GE | T_GES | T_GEU | T_LE | T_LES | T_LEU | T_AS | T_IS | T_ON => Reduce(1, NT_plaininstr, yy_action_532)
    _ => Error
  }
}

fn yy_state_383(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    NT_expression => Shift(yy_state_384)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_384(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_QUESTIONMARK => Shift(yy_state_63)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_LEU => Shift(yy_state_138)
    T_LES => Shift(yy_state_140)
    T_LE => Shift(yy_state_142)
    T_GEU => Shift(yy_state_144)
    T_GES => Shift(yy_state_146)
    T_GE => Shift(yy_state_148)
    T_LTU => Shift(yy_state_150)
    T_LTS => Shift(yy_state_152)
    T_LT => Shift(yy_state_154)
    T_GTU => Shift(yy_state_156)
    T_GTS => Shift(yy_state_158)
    T_GT => Shift(yy_state_160)
    T_BANGEQUAL => Shift(yy_state_162)
    T_EQUALEQUAL => Shift(yy_state_164)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_RPAREN | T_RBRACE => Reduce(3, NT_statement, yy_action_327)
    _ => Error
  }
}

fn yy_state_385(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    NT_expression => Shift(yy_state_386)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_386(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_QUESTIONMARK => Shift(yy_state_63)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_LEU => Shift(yy_state_138)
    T_LES => Shift(yy_state_140)
    T_LE => Shift(yy_state_142)
    T_GEU => Shift(yy_state_144)
    T_GES => Shift(yy_state_146)
    T_GE => Shift(yy_state_148)
    T_LTU => Shift(yy_state_150)
    T_LTS => Shift(yy_state_152)
    T_LT => Shift(yy_state_154)
    T_GTU => Shift(yy_state_156)
    T_GTS => Shift(yy_state_158)
    T_GT => Shift(yy_state_160)
    T_BANGEQUAL => Shift(yy_state_162)
    T_EQUALEQUAL => Shift(yy_state_164)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_RPAREN | T_RBRACE => Reduce(3, NT_statement, yy_action_326)
    _ => Error
  }
}

fn yy_state_387(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_compound_assign_op, yy_action_325)
}

fn yy_state_388(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_compound_assign_op, yy_action_324)
}

fn yy_state_389(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_compound_assign_op, yy_action_323)
}

fn yy_state_390(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_compound_assign_op, yy_action_322)
}

fn yy_state_391(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_compound_assign_op, yy_action_321)
}

fn yy_state_392(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_compound_assign_op, yy_action_320)
}

fn yy_state_393(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_compound_assign_op, yy_action_319)
}

fn yy_state_394(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_compound_assign_op, yy_action_318)
}

fn yy_state_395(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_compound_assign_op, yy_action_317)
}

fn yy_state_396(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_compound_assign_op, yy_action_316)
}

fn yy_state_397(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_compound_assign_op, yy_action_315)
}

fn yy_state_398(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_compound_assign_op, yy_action_314)
}

fn yy_state_399(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_compound_assign_op, yy_action_313)
}

fn yy_state_400(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_compound_assign_op, yy_action_312)
}

fn yy_state_401(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_402)
    T_EQUAL => Shift(yy_state_406)
    T_SEMI | T_QUESTIONMARK | T_LPAREN | T_RPAREN | T_RBRACE | T_LBRACKET | T_DOT | T_BANG | T_PLUS | T_MINUS | T_STAR | T_SLASH | T_SLASHS | T_SLASHU | T_PERCENTS | T_PERCENTU | T_AMPERSAND | T_PIPE | T_CARET | T_SHL | T_SHRS | T_SHRU | T_EQUALEQUAL | T_BANGEQUAL | T_GT | T_GTS | T_GTU | T_LT | T_LTS | T_LTU | T_GE | T_GES | T_GEU | T_LE | T_LES | T_LEU | T_AS | T_IS | T_ON => Reduce(1, NT_plaininstr, yy_action_427)
    _ => Error
  }
}

fn yy_state_402(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AMPERSAND => Shift(yy_state_201)
    NT_reference_type => Shift(yy_state_355)
    T_IDENT => Shift(yy_state_356)
    NT_value_type => Shift(yy_state_403)
    _ => Error
  }
}

fn yy_state_403(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_404)
    _ => Error
  }
}

fn yy_state_404(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    NT_expression => Shift(yy_state_405)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_405(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_QUESTIONMARK => Shift(yy_state_63)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_LEU => Shift(yy_state_138)
    T_LES => Shift(yy_state_140)
    T_LE => Shift(yy_state_142)
    T_GEU => Shift(yy_state_144)
    T_GES => Shift(yy_state_146)
    T_GE => Shift(yy_state_148)
    T_LTU => Shift(yy_state_150)
    T_LTS => Shift(yy_state_152)
    T_LT => Shift(yy_state_154)
    T_GTU => Shift(yy_state_156)
    T_GTS => Shift(yy_state_158)
    T_GT => Shift(yy_state_160)
    T_BANGEQUAL => Shift(yy_state_162)
    T_EQUALEQUAL => Shift(yy_state_164)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_RPAREN | T_RBRACE => Reduce(5, NT_statement, yy_action_311)
    _ => Error
  }
}

fn yy_state_406(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    NT_expression => Shift(yy_state_407)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_407(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_QUESTIONMARK => Shift(yy_state_63)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_LEU => Shift(yy_state_138)
    T_LES => Shift(yy_state_140)
    T_LE => Shift(yy_state_142)
    T_GEU => Shift(yy_state_144)
    T_GES => Shift(yy_state_146)
    T_GE => Shift(yy_state_148)
    T_LTU => Shift(yy_state_150)
    T_LTS => Shift(yy_state_152)
    T_LT => Shift(yy_state_154)
    T_GTU => Shift(yy_state_156)
    T_GTS => Shift(yy_state_158)
    T_GT => Shift(yy_state_160)
    T_BANGEQUAL => Shift(yy_state_162)
    T_EQUALEQUAL => Shift(yy_state_164)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_RPAREN | T_RBRACE => Reduce(3, NT_statement, yy_action_310)
    _ => Error
  }
}

fn yy_state_408(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_409)
    _ => Error
  }
}

fn yy_state_409(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_attribute_name => Shift(yy_state_6)
    T_IMPORT => Shift(yy_state_308)
    T_IDENT => Shift(yy_state_309)
    T_ELSE => Shift(yy_state_410)
    T_IF => Shift(yy_state_413)
    _ => Error
  }
}

fn yy_state_410(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_411)
    _ => Error
  }
}

fn yy_state_411(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_237)
    NT_braced_block => Shift(yy_state_412)
    _ => Error
  }
}

fn yy_state_412(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_cond_stmt, yy_action_309)
}

fn yy_state_413(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_414)
    _ => Error
  }
}

fn yy_state_414(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_134)
    NT_ident => Shift(yy_state_415)
    NT_condition => Shift(yy_state_439)
    _ => Error
  }
}

fn yy_state_415(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_GE => Shift(yy_state_416)
    T_LE => Shift(yy_state_417)
    T_GT => Shift(yy_state_418)
    T_LT => Shift(yy_state_419)
    T_BANGEQUAL => Shift(yy_state_420)
    T_EQUAL => Shift(yy_state_421)
    T_LPAREN => Shift(yy_state_422)
    NT_condition_relop => Shift(yy_state_429)
    T_RPAREN | T_COMMA => Reduce(1, NT_condition, yy_action_308)
    _ => Error
  }
}

fn yy_state_416(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_condition_relop, yy_action_307)
}

fn yy_state_417(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_condition_relop, yy_action_306)
}

fn yy_state_418(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_condition_relop, yy_action_305)
}

fn yy_state_419(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_condition_relop, yy_action_304)
}

fn yy_state_420(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_condition_relop, yy_action_303)
}

fn yy_state_421(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_condition_relop, yy_action_302)
}

fn yy_state_422(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_134)
    NT_ident => Shift(yy_state_415)
    NT_condition => Shift(yy_state_423)
    NT_non_empty_sep_trailing_COMMA_condition_ => Shift(yy_state_426)
    NT_sep_trailing_COMMA_condition_ => Shift(yy_state_427)
    T_RPAREN => Reduce(0, NT_sep_trailing_COMMA_condition_, yy_action_301)
    _ => Error
  }
}

fn yy_state_423(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_424)
    T_RPAREN => Reduce(1, NT_non_empty_sep_trailing_COMMA_condition_, yy_action_300)
    _ => Error
  }
}

fn yy_state_424(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_134)
    NT_ident => Shift(yy_state_415)
    NT_condition => Shift(yy_state_423)
    NT_non_empty_sep_trailing_COMMA_condition_ => Shift(yy_state_425)
    T_RPAREN => Reduce(2, NT_non_empty_sep_trailing_COMMA_condition_, yy_action_299)
    _ => Error
  }
}

fn yy_state_425(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_sep_trailing_COMMA_condition_, yy_action_298)
}

fn yy_state_426(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_sep_trailing_COMMA_condition_, yy_action_297)
}

fn yy_state_427(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_428)
    _ => Error
  }
}

fn yy_state_428(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_condition, yy_action_296)
}

fn yy_state_429(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_STRING => Shift(yy_state_430)
    T_LPAREN => Shift(yy_state_431)
    NT_condition_literal => Shift(yy_state_438)
    _ => Error
  }
}

fn yy_state_430(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_condition_literal, yy_action_295)
}

fn yy_state_431(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_INT => Shift(yy_state_432)
    _ => Error
  }
}

fn yy_state_432(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_433)
    _ => Error
  }
}

fn yy_state_433(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_INT => Shift(yy_state_434)
    _ => Error
  }
}

fn yy_state_434(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_435)
    _ => Error
  }
}

fn yy_state_435(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_INT => Shift(yy_state_436)
    _ => Error
  }
}

fn yy_state_436(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_437)
    _ => Error
  }
}

fn yy_state_437(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(7, NT_condition_literal, yy_action_294)
}

fn yy_state_438(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_condition, yy_action_293)
}

fn yy_state_439(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_440)
    _ => Error
  }
}

fn yy_state_440(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_441)
    _ => Error
  }
}

fn yy_state_441(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_237)
    NT_braced_block => Shift(yy_state_442)
    _ => Error
  }
}

fn yy_state_442(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(8, NT_cond_stmt, yy_action_292)
}

fn yy_state_443(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_QUESTIONMARK => Shift(yy_state_63)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_LEU => Shift(yy_state_138)
    T_LES => Shift(yy_state_140)
    T_LE => Shift(yy_state_142)
    T_GEU => Shift(yy_state_144)
    T_GES => Shift(yy_state_146)
    T_GE => Shift(yy_state_148)
    T_LTU => Shift(yy_state_150)
    T_LTS => Shift(yy_state_152)
    T_LT => Shift(yy_state_154)
    T_GTU => Shift(yy_state_156)
    T_GTS => Shift(yy_state_158)
    T_GT => Shift(yy_state_160)
    T_BANGEQUAL => Shift(yy_state_162)
    T_EQUALEQUAL => Shift(yy_state_164)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_COLON | T_FATARROW => Reduce(2, NT_expression, yy_action_291)
    _ => Error
  }
}

fn yy_state_444(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_raw_statement_list, yy_action_290)
}

fn yy_state_445(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_statement_list, yy_action_289)
}

fn yy_state_446(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_447)
    _ => Error
  }
}

fn yy_state_447(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_braced_block, yy_action_288)
}

fn yy_state_448(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_legacy_catch_all => Shift(yy_state_449)
    NT_option_legacy_catch_all_ => Shift(yy_state_450)
    T_UNDERSCORE => Shift(yy_state_452)
    T_RBRACE => Reduce(0, NT_option_legacy_catch_all_, yy_action_287)
    _ => Error
  }
}

fn yy_state_449(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_option_legacy_catch_all_, yy_action_286)
}

fn yy_state_450(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_451)
    _ => Error
  }
}

fn yy_state_451(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(9, NT_blockinstr, yy_action_285)
}

fn yy_state_452(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FATARROW => Shift(yy_state_453)
    _ => Error
  }
}

fn yy_state_453(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_237)
    NT_braced_block => Shift(yy_state_454)
    _ => Error
  }
}

fn yy_state_454(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_legacy_catch_all, yy_action_284)
}

fn yy_state_455(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_block_type, yy_action_283)
}

fn yy_state_456(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AMPERSAND => Shift(yy_state_201)
    NT_reference_type => Shift(yy_state_355)
    T_IDENT => Shift(yy_state_356)
    NT_block_param_type => Shift(yy_state_457)
    NT_value_type => Shift(yy_state_460)
    NT_non_empty_sep_trailing_COMMA_block_param_type_ => Shift(yy_state_461)
    NT_parameter_types => Shift(yy_state_462)
    NT_sep_trailing_COMMA_block_param_type_ => Shift(yy_state_476)
    T_RPAREN => Reduce(0, NT_sep_trailing_COMMA_block_param_type_, yy_action_282)
    _ => Error
  }
}

fn yy_state_457(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_458)
    T_RPAREN => Reduce(1, NT_non_empty_sep_trailing_COMMA_block_param_type_, yy_action_281)
    _ => Error
  }
}

fn yy_state_458(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AMPERSAND => Shift(yy_state_201)
    NT_reference_type => Shift(yy_state_355)
    T_IDENT => Shift(yy_state_356)
    NT_block_param_type => Shift(yy_state_457)
    NT_non_empty_sep_trailing_COMMA_block_param_type_ => Shift(yy_state_459)
    NT_value_type => Shift(yy_state_460)
    T_RPAREN => Reduce(2, NT_non_empty_sep_trailing_COMMA_block_param_type_, yy_action_280)
    _ => Error
  }
}

fn yy_state_459(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_sep_trailing_COMMA_block_param_type_, yy_action_279)
}

fn yy_state_460(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_block_param_type, yy_action_278)
}

fn yy_state_461(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_sep_trailing_COMMA_block_param_type_, yy_action_277)
}

fn yy_state_462(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_463)
    _ => Error
  }
}

fn yy_state_463(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_result_arrow => Shift(yy_state_464)
    T_ARROW => Shift(yy_state_465)
    T_LBRACE => Reduce(3, NT_block_type, yy_action_276)
    _ => Error
  }
}

fn yy_state_464(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_block_type, yy_action_275)
}

fn yy_state_465(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AMPERSAND => Shift(yy_state_201)
    NT_reference_type => Shift(yy_state_355)
    T_IDENT => Shift(yy_state_356)
    NT_result_type => Shift(yy_state_466)
    NT_value_type => Shift(yy_state_467)
    T_LPAREN => Shift(yy_state_468)
    _ => Error
  }
}

fn yy_state_466(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_result_arrow, yy_action_274)
}

fn yy_state_467(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_result_type, yy_action_273)
}

fn yy_state_468(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AMPERSAND => Shift(yy_state_201)
    NT_reference_type => Shift(yy_state_355)
    T_IDENT => Shift(yy_state_356)
    NT_value_type => Shift(yy_state_469)
    NT_result_type_ => Shift(yy_state_472)
    T_RPAREN => Shift(yy_state_474)
    NT_non_empty_sep_trailing_COMMA_value_type_ => Shift(yy_state_475)
    _ => Error
  }
}

fn yy_state_469(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_470)
    T_RPAREN => Reduce(1, NT_non_empty_sep_trailing_COMMA_value_type_, yy_action_272)
    _ => Error
  }
}

fn yy_state_470(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AMPERSAND => Shift(yy_state_201)
    NT_reference_type => Shift(yy_state_355)
    T_IDENT => Shift(yy_state_356)
    NT_value_type => Shift(yy_state_469)
    NT_non_empty_sep_trailing_COMMA_value_type_ => Shift(yy_state_471)
    T_RPAREN => Reduce(2, NT_non_empty_sep_trailing_COMMA_value_type_, yy_action_271)
    _ => Error
  }
}

fn yy_state_471(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_sep_trailing_COMMA_value_type_, yy_action_270)
}

fn yy_state_472(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_473)
    _ => Error
  }
}

fn yy_state_473(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_result_type, yy_action_269)
}

fn yy_state_474(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_result_type, yy_action_268)
}

fn yy_state_475(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_result_type_, yy_action_267)
}

fn yy_state_476(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_parameter_types, yy_action_266)
}

fn yy_state_477(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AMPERSAND => Shift(yy_state_201)
    NT_block_type => Shift(yy_state_225)
    NT_reference_type => Shift(yy_state_355)
    T_IDENT => Shift(yy_state_356)
    NT_value_type => Shift(yy_state_455)
    T_LPAREN => Shift(yy_state_456)
    NT_option_block_type_ => Shift(yy_state_478)
    T_LBRACE => Reduce(0, NT_option_block_type_, yy_action_420)
    _ => Error
  }
}

fn yy_state_478(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_237)
    NT_braced_block => Shift(yy_state_479)
    _ => Error
  }
}

fn yy_state_479(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_CATCH => Shift(yy_state_480)
    _ => Error
  }
}

fn yy_state_480(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_481)
    T_LBRACKET => Shift(yy_state_502)
    _ => Error
  }
}

fn yy_state_481(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_134)
    NT_catch_arm => Shift(yy_state_482)
    T_SEMI => Shift(yy_state_484)
    NT_ident => Shift(yy_state_486)
    NT_semi_list_catch_arm_ => Shift(yy_state_492)
    T_RBRACE | T_UNDERSCORE => Reduce(0, NT_semi_list_catch_arm_, yy_action_265)
    _ => Error
  }
}

fn yy_state_482(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_134)
    NT_catch_arm => Shift(yy_state_482)
    NT_semi_list_catch_arm_ => Shift(yy_state_483)
    T_SEMI => Shift(yy_state_484)
    NT_ident => Shift(yy_state_486)
    T_RBRACE | T_UNDERSCORE => Reduce(0, NT_semi_list_catch_arm_, yy_action_265)
    _ => Error
  }
}

fn yy_state_483(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_semi_list_catch_arm_, yy_action_264)
}

fn yy_state_484(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_134)
    NT_catch_arm => Shift(yy_state_482)
    T_SEMI => Shift(yy_state_484)
    NT_semi_list_catch_arm_ => Shift(yy_state_485)
    NT_ident => Shift(yy_state_486)
    T_RBRACE | T_UNDERSCORE => Reduce(0, NT_semi_list_catch_arm_, yy_action_265)
    _ => Error
  }
}

fn yy_state_485(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_semi_list_catch_arm_, yy_action_263)
}

fn yy_state_486(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AMPERSAND => Shift(yy_state_487)
    T_FATARROW => Shift(yy_state_490)
    _ => Error
  }
}

fn yy_state_487(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FATARROW => Shift(yy_state_488)
    _ => Error
  }
}

fn yy_state_488(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_237)
    NT_braced_block => Shift(yy_state_489)
    _ => Error
  }
}

fn yy_state_489(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_catch_arm, yy_action_262)
}

fn yy_state_490(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_237)
    NT_braced_block => Shift(yy_state_491)
    _ => Error
  }
}

fn yy_state_491(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_catch_arm, yy_action_261)
}

fn yy_state_492(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_catch_all_arm => Shift(yy_state_493)
    NT_option_catch_all_arm_ => Shift(yy_state_494)
    T_UNDERSCORE => Shift(yy_state_496)
    T_RBRACE => Reduce(0, NT_option_catch_all_arm_, yy_action_260)
    _ => Error
  }
}

fn yy_state_493(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_option_catch_all_arm_, yy_action_259)
}

fn yy_state_494(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_495)
    _ => Error
  }
}

fn yy_state_495(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(9, NT_blockinstr, yy_action_258)
}

fn yy_state_496(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AMPERSAND => Shift(yy_state_497)
    T_FATARROW => Shift(yy_state_500)
    _ => Error
  }
}

fn yy_state_497(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FATARROW => Shift(yy_state_498)
    _ => Error
  }
}

fn yy_state_498(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_237)
    NT_braced_block => Shift(yy_state_499)
    _ => Error
  }
}

fn yy_state_499(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_catch_all_arm, yy_action_257)
}

fn yy_state_500(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_237)
    NT_braced_block => Shift(yy_state_501)
    _ => Error
  }
}

fn yy_state_501(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_catch_all_arm, yy_action_256)
}

fn yy_state_502(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_134)
    NT_catch => Shift(yy_state_503)
    T_UNDERSCORE => Shift(yy_state_506)
    NT_ident => Shift(yy_state_512)
    NT_non_empty_sep_trailing_COMMA_catch_ => Shift(yy_state_518)
    NT_sep_trailing_COMMA_catch_ => Shift(yy_state_519)
    T_RBRACKET => Reduce(0, NT_sep_trailing_COMMA_catch_, yy_action_255)
    _ => Error
  }
}

fn yy_state_503(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_504)
    T_RBRACKET => Reduce(1, NT_non_empty_sep_trailing_COMMA_catch_, yy_action_254)
    _ => Error
  }
}

fn yy_state_504(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_134)
    NT_catch => Shift(yy_state_503)
    NT_non_empty_sep_trailing_COMMA_catch_ => Shift(yy_state_505)
    T_UNDERSCORE => Shift(yy_state_506)
    NT_ident => Shift(yy_state_512)
    T_RBRACKET => Reduce(2, NT_non_empty_sep_trailing_COMMA_catch_, yy_action_253)
    _ => Error
  }
}

fn yy_state_505(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_sep_trailing_COMMA_catch_, yy_action_252)
}

fn yy_state_506(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AMPERSAND => Shift(yy_state_507)
    T_ARROW => Shift(yy_state_510)
    _ => Error
  }
}

fn yy_state_507(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_ARROW => Shift(yy_state_508)
    _ => Error
  }
}

fn yy_state_508(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_QUOTE => Shift(yy_state_82)
    NT_label => Shift(yy_state_509)
    _ => Error
  }
}

fn yy_state_509(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_catch, yy_action_251)
}

fn yy_state_510(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_QUOTE => Shift(yy_state_82)
    NT_label => Shift(yy_state_511)
    _ => Error
  }
}

fn yy_state_511(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_catch, yy_action_250)
}

fn yy_state_512(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AMPERSAND => Shift(yy_state_513)
    T_ARROW => Shift(yy_state_516)
    _ => Error
  }
}

fn yy_state_513(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_ARROW => Shift(yy_state_514)
    _ => Error
  }
}

fn yy_state_514(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_QUOTE => Shift(yy_state_82)
    NT_label => Shift(yy_state_515)
    _ => Error
  }
}

fn yy_state_515(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_catch, yy_action_249)
}

fn yy_state_516(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_QUOTE => Shift(yy_state_82)
    NT_label => Shift(yy_state_517)
    _ => Error
  }
}

fn yy_state_517(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_catch, yy_action_248)
}

fn yy_state_518(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_sep_trailing_COMMA_catch_, yy_action_247)
}

fn yy_state_519(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_520)
    _ => Error
  }
}

fn yy_state_520(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(8, NT_blockinstr, yy_action_246)
}

fn yy_state_521(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    NT_expression => Shift(yy_state_522)
    NT_condition_expression => Shift(yy_state_523)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_522(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_QUESTIONMARK => Shift(yy_state_63)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_LEU => Shift(yy_state_138)
    T_LES => Shift(yy_state_140)
    T_LE => Shift(yy_state_142)
    T_GEU => Shift(yy_state_144)
    T_GES => Shift(yy_state_146)
    T_GE => Shift(yy_state_148)
    T_LTU => Shift(yy_state_150)
    T_LTS => Shift(yy_state_152)
    T_LT => Shift(yy_state_154)
    T_GTU => Shift(yy_state_156)
    T_GTS => Shift(yy_state_158)
    T_GT => Shift(yy_state_160)
    T_BANGEQUAL => Shift(yy_state_162)
    T_EQUALEQUAL => Shift(yy_state_164)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_LBRACE | T_COLON | T_FATARROW => Reduce(1, NT_condition_expression, yy_action_245)
    _ => Error
  }
}

fn yy_state_523(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_if_block_type => Shift(yy_state_524)
    T_FATARROW => Shift(yy_state_525)
    NT_option_if_block_type_ => Shift(yy_state_527)
    T_LBRACE => Reduce(0, NT_option_if_block_type_, yy_action_244)
    _ => Error
  }
}

fn yy_state_524(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_option_if_block_type_, yy_action_243)
}

fn yy_state_525(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AMPERSAND => Shift(yy_state_201)
    NT_reference_type => Shift(yy_state_355)
    T_IDENT => Shift(yy_state_356)
    NT_value_type => Shift(yy_state_455)
    T_LPAREN => Shift(yy_state_456)
    NT_block_type => Shift(yy_state_526)
    _ => Error
  }
}

fn yy_state_526(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_if_block_type, yy_action_242)
}

fn yy_state_527(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_237)
    NT_braced_block => Shift(yy_state_528)
    _ => Error
  }
}

fn yy_state_528(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_ELSE => Shift(yy_state_529)
    NT_else_branch => Shift(yy_state_531)
    T_IDENT | T_INT | T_FLOAT | T_STRING | T_CHAR | T_INF | T_NAN | T_SEMI | T_SHARP | T_QUESTIONMARK | T_LPAREN | T_RPAREN | T_LBRACE | T_RBRACE | T_LBRACKET | T_RBRACKET | T_COMMA | T_COLON | T_FATARROW | T_QUOTE | T_DOT | T_BANG | T_PLUS | T_MINUS | T_STAR | T_SLASH | T_SLASHS | T_SLASHU | T_PERCENTS | T_PERCENTU | T_AMPERSAND | T_PIPE | T_CARET | T_SHL | T_SHRS | T_SHRU | T_EQUALEQUAL | T_BANGEQUAL | T_GT | T_GTS | T_GTU | T_LT | T_LTS | T_LTU | T_GE | T_GES | T_GEU | T_LE | T_LES | T_LEU | T_UNDERSCORE | T_NOP | T_UNREACHABLE | T_NULL | T_DO | T_WHILE | T_LOOP | T_IF | T_LET | T_AS | T_IS | T_BECOME | T_BR | T_BR_IF | T_BR_TABLE | T_RETURN | T_THROW | T_THROW_REF | T_BR_ON_CAST | T_BR_ON_CAST_FAIL | T_BR_ON_NULL | T_BR_ON_NON_NULL | T_TRY | T_TRY_LEGACY | T_SUSPEND | T_ON | T_DISPATCH | T_MATCH => Reduce(5, NT_blockinstr, yy_action_240)
    _ => Error
  }
}

fn yy_state_529(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_237)
    NT_braced_block => Shift(yy_state_530)
    _ => Error
  }
}

fn yy_state_530(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_else_branch, yy_action_239)
}

fn yy_state_531(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_blockinstr, yy_action_237)
}

fn yy_state_532(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AMPERSAND => Shift(yy_state_201)
    NT_block_type => Shift(yy_state_225)
    NT_reference_type => Shift(yy_state_355)
    T_IDENT => Shift(yy_state_356)
    NT_value_type => Shift(yy_state_455)
    T_LPAREN => Shift(yy_state_456)
    NT_option_block_type_ => Shift(yy_state_533)
    T_LBRACE => Reduce(0, NT_option_block_type_, yy_action_420)
    _ => Error
  }
}

fn yy_state_533(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_237)
    NT_braced_block => Shift(yy_state_534)
    _ => Error
  }
}

fn yy_state_534(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_blockinstr, yy_action_236)
}

fn yy_state_535(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    NT_expression => Shift(yy_state_522)
    NT_condition_expression => Shift(yy_state_536)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_536(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_237)
    T_COLON => Shift(yy_state_537)
    NT_braced_block => Shift(yy_state_545)
    _ => Error
  }
}

fn yy_state_537(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_538)
    _ => Error
  }
}

fn yy_state_538(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_BECOME => Shift(yy_state_246)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    T_THROW_REF => Shift(yy_state_325)
    T_THROW => Shift(yy_state_327)
    T_RETURN => Shift(yy_state_337)
    T_BR_TABLE => Shift(yy_state_339)
    T_BR => Shift(yy_state_344)
    T_LET => Shift(yy_state_347)
    T_UNREACHABLE => Shift(yy_state_374)
    T_NOP => Shift(yy_state_375)
    NT_plaininstr => Shift(yy_state_378)
    NT_expression => Shift(yy_state_381)
    NT_ident => Shift(yy_state_382)
    T_UNDERSCORE => Shift(yy_state_401)
    NT_statement => Shift(yy_state_539)
    NT_hint_attr => Shift(yy_state_540)
    NT_hinted_statement => Shift(yy_state_542)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_539(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_hinted_statement, yy_action_235)
}

fn yy_state_540(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_BECOME => Shift(yy_state_246)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    T_THROW_REF => Shift(yy_state_325)
    T_THROW => Shift(yy_state_327)
    T_RETURN => Shift(yy_state_337)
    T_BR_TABLE => Shift(yy_state_339)
    T_BR => Shift(yy_state_344)
    T_LET => Shift(yy_state_347)
    T_UNREACHABLE => Shift(yy_state_374)
    T_NOP => Shift(yy_state_375)
    NT_plaininstr => Shift(yy_state_378)
    NT_ident => Shift(yy_state_382)
    T_UNDERSCORE => Shift(yy_state_401)
    NT_expression => Shift(yy_state_443)
    NT_statement => Shift(yy_state_539)
    NT_hint_attr => Shift(yy_state_540)
    NT_hinted_statement => Shift(yy_state_541)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_541(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_hinted_statement, yy_action_234)
}

fn yy_state_542(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_543)
    _ => Error
  }
}

fn yy_state_543(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_237)
    NT_braced_block => Shift(yy_state_544)
    _ => Error
  }
}

fn yy_state_544(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(8, NT_blockinstr, yy_action_233)
}

fn yy_state_545(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_blockinstr, yy_action_232)
}

fn yy_state_546(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AMPERSAND => Shift(yy_state_201)
    NT_block_type => Shift(yy_state_225)
    NT_reference_type => Shift(yy_state_355)
    T_IDENT => Shift(yy_state_356)
    NT_value_type => Shift(yy_state_455)
    T_LPAREN => Shift(yy_state_456)
    NT_option_block_type_ => Shift(yy_state_547)
    T_LBRACE => Reduce(0, NT_option_block_type_, yy_action_420)
    _ => Error
  }
}

fn yy_state_547(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_237)
    NT_braced_block => Shift(yy_state_548)
    _ => Error
  }
}

fn yy_state_548(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_blockinstr, yy_action_231)
}

fn yy_state_549(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_550)
    _ => Error
  }
}

fn yy_state_550(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_plaininstr, yy_action_406)
}

fn yy_state_551(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_descriptor_operand, yy_action_230)
}

fn yy_state_552(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_plaininstr, yy_action_229)
}

fn yy_state_553(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_cast_type, yy_action_228)
}

fn yy_state_554(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_cast_type, yy_action_227)
}

fn yy_state_555(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_QUESTIONMARK => Shift(yy_state_15)
    NT_boption_QUESTIONMARK_ => Shift(yy_state_556)
    T_IDENT | T_BANG | T_FN | T_CONT => Reduce(0, NT_boption_QUESTIONMARK_, yy_action_551)
    _ => Error
  }
}

fn yy_state_556(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_203)
    NT_boption_BANG_ => Shift(yy_state_204)
    T_FN => Shift(yy_state_557)
    T_IDENT | T_CONT => Reduce(0, NT_boption_BANG_, yy_action_433)
    _ => Error
  }
}

fn yy_state_557(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_558)
    NT_function_type_AS_ => Shift(yy_state_572)
    NT_function_type_as => Shift(yy_state_573)
    _ => Error
  }
}

fn yy_state_558(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AMPERSAND => Shift(yy_state_201)
    NT_reference_type => Shift(yy_state_355)
    NT_function_parameter => Shift(yy_state_559)
    NT_value_type => Shift(yy_state_562)
    NT_ident => Shift(yy_state_563)
    T_IDENT => Shift(yy_state_566)
    NT_parameter_list => Shift(yy_state_567)
    NT_non_empty_sep_trailing_COMMA_function_parameter_ => Shift(yy_state_570)
    NT_sep_trailing_COMMA_function_parameter_ => Shift(yy_state_571)
    T_RPAREN => Reduce(0, NT_sep_trailing_COMMA_function_parameter_, yy_action_226)
    _ => Error
  }
}

fn yy_state_559(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_560)
    T_RPAREN => Reduce(1, NT_non_empty_sep_trailing_COMMA_function_parameter_, yy_action_225)
    _ => Error
  }
}

fn yy_state_560(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AMPERSAND => Shift(yy_state_201)
    NT_reference_type => Shift(yy_state_355)
    NT_function_parameter => Shift(yy_state_559)
    NT_non_empty_sep_trailing_COMMA_function_parameter_ => Shift(yy_state_561)
    NT_value_type => Shift(yy_state_562)
    NT_ident => Shift(yy_state_563)
    T_IDENT => Shift(yy_state_566)
    T_RPAREN => Reduce(2, NT_non_empty_sep_trailing_COMMA_function_parameter_, yy_action_224)
    _ => Error
  }
}

fn yy_state_561(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_sep_trailing_COMMA_function_parameter_, yy_action_223)
}

fn yy_state_562(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_function_parameter, yy_action_222)
}

fn yy_state_563(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_564)
    _ => Error
  }
}

fn yy_state_564(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AMPERSAND => Shift(yy_state_201)
    NT_reference_type => Shift(yy_state_355)
    T_IDENT => Shift(yy_state_356)
    NT_value_type => Shift(yy_state_565)
    _ => Error
  }
}

fn yy_state_565(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_function_parameter, yy_action_221)
}

fn yy_state_566(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Reduce(1, NT_ident, yy_action_468)
    T_RPAREN | T_COMMA => Reduce(1, NT_value_type, yy_action_347)
    _ => Error
  }
}

fn yy_state_567(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_568)
    _ => Error
  }
}

fn yy_state_568(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_ARROW => Shift(yy_state_465)
    NT_result_arrow => Shift(yy_state_569)
    T_SEMI | T_QUESTIONMARK | T_LPAREN | T_RPAREN | T_LBRACE | T_RBRACE | T_LBRACKET | T_RBRACKET | T_COMMA | T_COLON | T_FATARROW | T_DOT | T_BANG | T_PLUS | T_MINUS | T_STAR | T_SLASH | T_SLASHS | T_SLASHU | T_PERCENTS | T_PERCENTU | T_AMPERSAND | T_PIPE | T_CARET | T_SHL | T_SHRS | T_SHRU | T_EQUALEQUAL | T_BANGEQUAL | T_GT | T_GTS | T_GTU | T_LT | T_LTS | T_LTU | T_GE | T_GES | T_GEU | T_LE | T_LES | T_LEU | T_AS | T_IS | T_ON => Reduce(3, NT_function_type_AS_, yy_action_220)
    _ => Error
  }
}

fn yy_state_569(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_function_type_AS_, yy_action_219)
}

fn yy_state_570(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_sep_trailing_COMMA_function_parameter_, yy_action_218)
}

fn yy_state_571(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_parameter_list, yy_action_217)
}

fn yy_state_572(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_function_type_as, yy_action_216)
}

fn yy_state_573(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_cast_type, yy_action_215)
}

fn yy_state_574(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_QUESTIONMARK => Shift(yy_state_63)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_LEU => Shift(yy_state_138)
    T_LES => Shift(yy_state_140)
    T_LE => Shift(yy_state_142)
    T_GEU => Shift(yy_state_144)
    T_GES => Shift(yy_state_146)
    T_GE => Shift(yy_state_148)
    T_LTU => Shift(yy_state_150)
    T_LTS => Shift(yy_state_152)
    T_LT => Shift(yy_state_154)
    T_GTU => Shift(yy_state_156)
    T_GTS => Shift(yy_state_158)
    T_GT => Shift(yy_state_160)
    T_BANGEQUAL => Shift(yy_state_162)
    T_EQUALEQUAL => Shift(yy_state_164)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_COLON => Reduce(1, NT_then_branch, yy_action_214)
    _ => Error
  }
}

fn yy_state_575(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_QUESTIONMARK => Shift(yy_state_63)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_LEU => Shift(yy_state_138)
    T_LES => Shift(yy_state_140)
    T_LE => Shift(yy_state_142)
    T_GEU => Shift(yy_state_144)
    T_GES => Shift(yy_state_146)
    T_GE => Shift(yy_state_148)
    T_LTU => Shift(yy_state_150)
    T_LTS => Shift(yy_state_152)
    T_LT => Shift(yy_state_154)
    T_GTU => Shift(yy_state_156)
    T_GTS => Shift(yy_state_158)
    T_GT => Shift(yy_state_160)
    T_BANGEQUAL => Shift(yy_state_162)
    T_EQUALEQUAL => Shift(yy_state_164)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_COMMA => Shift(yy_state_576)
    T_RPAREN => Reduce(1, NT_parenthesized_expression, yy_action_213)
    _ => Error
  }
}

fn yy_state_576(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_non_empty_sep_trailing_COMMA_expression_ => Shift(yy_state_34)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    NT_expression => Shift(yy_state_332)
    NT_sep_trailing_COMMA_expression_ => Shift(yy_state_335)
    NT_expression_list => Shift(yy_state_577)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    T_RPAREN => Reduce(0, NT_sep_trailing_COMMA_expression_, yy_action_549)
    _ => Error
  }
}

fn yy_state_577(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_578)
    _ => Error
  }
}

fn yy_state_578(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_plaininstr, yy_action_212)
}

fn yy_state_579(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_QUESTIONMARK => Shift(yy_state_63)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_LEU => Shift(yy_state_138)
    T_LES => Shift(yy_state_140)
    T_LE => Shift(yy_state_142)
    T_GEU => Shift(yy_state_144)
    T_GES => Shift(yy_state_146)
    T_GE => Shift(yy_state_148)
    T_LTU => Shift(yy_state_150)
    T_LTS => Shift(yy_state_152)
    T_LT => Shift(yy_state_154)
    T_GTU => Shift(yy_state_156)
    T_GTS => Shift(yy_state_158)
    T_GT => Shift(yy_state_160)
    T_BANGEQUAL => Shift(yy_state_162)
    T_EQUALEQUAL => Shift(yy_state_164)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_RBRACE | T_COMMA => Reduce(3, NT_structure_field, yy_action_211)
    _ => Error
  }
}

fn yy_state_580(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_field_name, yy_action_210)
}

fn yy_state_581(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_sep_trailing_COMMA_structure_field_, yy_action_209)
}

fn yy_state_582(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_583)
    _ => Error
  }
}

fn yy_state_583(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_plaininstr, yy_action_208)
}

fn yy_state_584(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_585)
    _ => Error
  }
}

fn yy_state_585(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_plaininstr, yy_action_207)
}

fn yy_state_586(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_structure, yy_action_206)
}

fn yy_state_587(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_588)
    _ => Error
  }
}

fn yy_state_588(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_plaininstr, yy_action_205)
}

fn yy_state_589(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_plaininstr, yy_action_204)
}

fn yy_state_590(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_591)
    T_COMMA => Shift(yy_state_592)
    _ => Error
  }
}

fn yy_state_591(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_plaininstr, yy_action_203)
}

fn yy_state_592(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_structure_field => Shift(yy_state_45)
    NT_field_name => Shift(yy_state_48)
    T_IDENT => Shift(yy_state_134)
    NT_ident => Shift(yy_state_580)
    NT_non_empty_sep_trailing_COMMA_structure_field_ => Shift(yy_state_581)
    NT_sep_trailing_COMMA_structure_field_ => Shift(yy_state_586)
    NT_structure => Shift(yy_state_593)
    T_RBRACE => Reduce(0, NT_sep_trailing_COMMA_structure_field_, yy_action_544)
    _ => Error
  }
}

fn yy_state_593(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_594)
    _ => Error
  }
}

fn yy_state_594(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_plaininstr, yy_action_202)
}

fn yy_state_595(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PIPE => Shift(yy_state_596)
    T_RBRACE | T_COMMA | T_COLON => Reduce(1, NT_field_name, yy_action_210)
    _ => Error
  }
}

fn yy_state_596(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_structure_field => Shift(yy_state_45)
    NT_field_name => Shift(yy_state_48)
    T_IDENT => Shift(yy_state_134)
    NT_ident => Shift(yy_state_580)
    NT_non_empty_sep_trailing_COMMA_structure_field_ => Shift(yy_state_581)
    NT_sep_trailing_COMMA_structure_field_ => Shift(yy_state_586)
    T_DOTDOT => Shift(yy_state_597)
    NT_structure => Shift(yy_state_599)
    T_RBRACE => Reduce(0, NT_sep_trailing_COMMA_structure_field_, yy_action_544)
    _ => Error
  }
}

fn yy_state_597(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_598)
    _ => Error
  }
}

fn yy_state_598(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_plaininstr, yy_action_201)
}

fn yy_state_599(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_600)
    _ => Error
  }
}

fn yy_state_600(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_plaininstr, yy_action_200)
}

fn yy_state_601(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_QUESTIONMARK => Shift(yy_state_63)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_LEU => Shift(yy_state_138)
    T_LES => Shift(yy_state_140)
    T_LE => Shift(yy_state_142)
    T_GEU => Shift(yy_state_144)
    T_GES => Shift(yy_state_146)
    T_GE => Shift(yy_state_148)
    T_LTU => Shift(yy_state_150)
    T_LTS => Shift(yy_state_152)
    T_LT => Shift(yy_state_154)
    T_GTU => Shift(yy_state_156)
    T_GTS => Shift(yy_state_158)
    T_GT => Shift(yy_state_160)
    T_BANGEQUAL => Shift(yy_state_162)
    T_EQUALEQUAL => Shift(yy_state_164)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_RBRACKET => Reduce(1, NT_length_expression, yy_action_199)
    _ => Error
  }
}

fn yy_state_602(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_array_body, yy_action_198)
}

fn yy_state_603(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_604)
    _ => Error
  }
}

fn yy_state_604(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_plaininstr, yy_action_197)
}

fn yy_state_605(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_QUESTIONMARK => Shift(yy_state_63)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_LEU => Shift(yy_state_138)
    T_LES => Shift(yy_state_140)
    T_LE => Shift(yy_state_142)
    T_GEU => Shift(yy_state_144)
    T_GES => Shift(yy_state_146)
    T_GE => Shift(yy_state_148)
    T_LTU => Shift(yy_state_150)
    T_LTS => Shift(yy_state_152)
    T_LT => Shift(yy_state_154)
    T_GTU => Shift(yy_state_156)
    T_GTS => Shift(yy_state_158)
    T_GT => Shift(yy_state_160)
    T_BANGEQUAL => Shift(yy_state_162)
    T_EQUALEQUAL => Shift(yy_state_164)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_COMMA => Shift(yy_state_333)
    T_SEMI => Shift(yy_state_606)
    T_RBRACKET => Reduce(1, NT_non_empty_sep_trailing_COMMA_expression_, yy_action_366)
    _ => Error
  }
}

fn yy_state_606(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    NT_expression => Shift(yy_state_601)
    NT_length_expression => Shift(yy_state_607)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_607(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_array_body, yy_action_196)
}

fn yy_state_608(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLONEQUAL => Shift(yy_state_60)
    T_SHARP => Shift(yy_state_254)
    T_COLONCOLON => Shift(yy_state_256)
    T_AT => Shift(yy_state_609)
    T_PIPE => Shift(yy_state_613)
    T_SEMI | T_QUESTIONMARK | T_LPAREN | T_LBRACKET | T_RBRACKET | T_COMMA | T_DOT | T_BANG | T_PLUS | T_MINUS | T_STAR | T_SLASH | T_SLASHS | T_SLASHU | T_PERCENTS | T_PERCENTU | T_AMPERSAND | T_CARET | T_SHL | T_SHRS | T_SHRU | T_EQUALEQUAL | T_BANGEQUAL | T_GT | T_GTS | T_GTU | T_LT | T_LTS | T_LTU | T_GE | T_GES | T_GEU | T_LE | T_LES | T_LEU | T_AS | T_IS | T_ON => Reduce(1, NT_plaininstr, yy_action_532)
    _ => Error
  }
}

fn yy_state_609(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    NT_expression => Shift(yy_state_610)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_610(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_QUESTIONMARK => Shift(yy_state_63)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_LEU => Shift(yy_state_138)
    T_LES => Shift(yy_state_140)
    T_LE => Shift(yy_state_142)
    T_GEU => Shift(yy_state_144)
    T_GES => Shift(yy_state_146)
    T_GE => Shift(yy_state_148)
    T_LTU => Shift(yy_state_150)
    T_LTS => Shift(yy_state_152)
    T_LT => Shift(yy_state_154)
    T_GTU => Shift(yy_state_156)
    T_GTS => Shift(yy_state_158)
    T_GT => Shift(yy_state_160)
    T_BANGEQUAL => Shift(yy_state_162)
    T_EQUALEQUAL => Shift(yy_state_164)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI => Shift(yy_state_611)
    _ => Error
  }
}

fn yy_state_611(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    NT_expression => Shift(yy_state_601)
    NT_length_expression => Shift(yy_state_612)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_612(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_array_body, yy_action_195)
}

fn yy_state_613(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_non_empty_sep_trailing_COMMA_expression_ => Shift(yy_state_34)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_DOTDOT => Shift(yy_state_39)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    NT_sep_trailing_COMMA_expression_ => Shift(yy_state_335)
    NT_expression_list => Shift(yy_state_602)
    NT_expression => Shift(yy_state_605)
    NT_array_body => Shift(yy_state_614)
    NT_ident => Shift(yy_state_616)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    T_RBRACKET => Reduce(0, NT_sep_trailing_COMMA_expression_, yy_action_549)
    _ => Error
  }
}

fn yy_state_614(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_615)
    _ => Error
  }
}

fn yy_state_615(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_plaininstr, yy_action_194)
}

fn yy_state_616(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLONEQUAL => Shift(yy_state_60)
    T_SHARP => Shift(yy_state_254)
    T_COLONCOLON => Shift(yy_state_256)
    T_AT => Shift(yy_state_609)
    T_SEMI | T_QUESTIONMARK | T_LPAREN | T_LBRACKET | T_RBRACKET | T_COMMA | T_DOT | T_BANG | T_PLUS | T_MINUS | T_STAR | T_SLASH | T_SLASHS | T_SLASHU | T_PERCENTS | T_PERCENTU | T_AMPERSAND | T_PIPE | T_CARET | T_SHL | T_SHRS | T_SHRU | T_EQUALEQUAL | T_BANGEQUAL | T_GT | T_GTS | T_GTU | T_LT | T_LTS | T_LTU | T_GE | T_GES | T_GEU | T_LE | T_LES | T_LEU | T_AS | T_IS | T_ON => Reduce(1, NT_plaininstr, yy_action_532)
    _ => Error
  }
}

fn yy_state_617(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_LBRACKET => Shift(yy_state_67)
    T_DOT => Shift(yy_state_194)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_QUESTIONMARK | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_COLON | T_FATARROW | T_PLUS | T_MINUS | T_STAR | T_SLASH | T_SLASHS | T_SLASHU | T_PERCENTS | T_PERCENTU | T_AMPERSAND | T_PIPE | T_CARET | T_SHL | T_SHRS | T_SHRU | T_EQUALEQUAL | T_BANGEQUAL | T_GT | T_GTS | T_GTU | T_LT | T_LTS | T_LTU | T_GE | T_GES | T_GEU | T_LE | T_LES | T_LEU | T_AS | T_IS | T_ON => Reduce(2, NT_plaininstr, yy_action_193)
    _ => Error
  }
}

fn yy_state_618(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_LBRACKET => Shift(yy_state_67)
    T_DOT => Shift(yy_state_194)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_QUESTIONMARK | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_COLON | T_FATARROW | T_PLUS | T_MINUS | T_STAR | T_SLASH | T_SLASHS | T_SLASHU | T_PERCENTS | T_PERCENTU | T_AMPERSAND | T_PIPE | T_CARET | T_SHL | T_SHRS | T_SHRU | T_EQUALEQUAL | T_BANGEQUAL | T_GT | T_GTS | T_GTU | T_LT | T_LTS | T_LTU | T_GE | T_GES | T_GEU | T_LE | T_LES | T_LEU | T_AS | T_IS | T_ON => Reduce(2, NT_plaininstr, yy_action_192)
    _ => Error
  }
}

fn yy_state_619(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_LBRACKET => Shift(yy_state_67)
    T_DOT => Shift(yy_state_194)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_QUESTIONMARK | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_COLON | T_FATARROW | T_PLUS | T_MINUS | T_STAR | T_SLASH | T_SLASHS | T_SLASHU | T_PERCENTS | T_PERCENTU | T_AMPERSAND | T_PIPE | T_CARET | T_SHL | T_SHRS | T_SHRU | T_EQUALEQUAL | T_BANGEQUAL | T_GT | T_GTS | T_GTU | T_LT | T_LTS | T_LTU | T_GE | T_GES | T_GEU | T_LE | T_LES | T_LEU | T_AS | T_IS | T_ON => Reduce(2, NT_plaininstr, yy_action_191)
    _ => Error
  }
}

fn yy_state_620(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_QUESTIONMARK => Shift(yy_state_63)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_LEU => Shift(yy_state_138)
    T_LES => Shift(yy_state_140)
    T_LE => Shift(yy_state_142)
    T_GEU => Shift(yy_state_144)
    T_GES => Shift(yy_state_146)
    T_GE => Shift(yy_state_148)
    T_LTU => Shift(yy_state_150)
    T_LTS => Shift(yy_state_152)
    T_LT => Shift(yy_state_154)
    T_GTU => Shift(yy_state_156)
    T_GTS => Shift(yy_state_158)
    T_GT => Shift(yy_state_160)
    T_BANGEQUAL => Shift(yy_state_162)
    T_EQUALEQUAL => Shift(yy_state_164)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_COLON | T_FATARROW => Reduce(3, NT_branch_expr, yy_action_190)
    _ => Error
  }
}

fn yy_state_621(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_QUESTIONMARK => Shift(yy_state_63)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_LEU => Shift(yy_state_138)
    T_LES => Shift(yy_state_140)
    T_LE => Shift(yy_state_142)
    T_GEU => Shift(yy_state_144)
    T_GES => Shift(yy_state_146)
    T_GE => Shift(yy_state_148)
    T_LTU => Shift(yy_state_150)
    T_LTS => Shift(yy_state_152)
    T_LT => Shift(yy_state_154)
    T_GTU => Shift(yy_state_156)
    T_GTS => Shift(yy_state_158)
    T_GT => Shift(yy_state_160)
    T_BANGEQUAL => Shift(yy_state_162)
    T_EQUALEQUAL => Shift(yy_state_164)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_COLON | T_FATARROW => Reduce(3, NT_branch_expr, yy_action_189)
    _ => Error
  }
}

fn yy_state_622(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_QUESTIONMARK => Shift(yy_state_63)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_LEU => Shift(yy_state_138)
    T_LES => Shift(yy_state_140)
    T_LE => Shift(yy_state_142)
    T_GEU => Shift(yy_state_144)
    T_GES => Shift(yy_state_146)
    T_GE => Shift(yy_state_148)
    T_LTU => Shift(yy_state_150)
    T_LTS => Shift(yy_state_152)
    T_LT => Shift(yy_state_154)
    T_GTU => Shift(yy_state_156)
    T_GTS => Shift(yy_state_158)
    T_GT => Shift(yy_state_160)
    T_BANGEQUAL => Shift(yy_state_162)
    T_EQUALEQUAL => Shift(yy_state_164)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_COLON | T_FATARROW => Reduce(3, NT_branch_expr, yy_action_188)
    _ => Error
  }
}

fn yy_state_623(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_QUESTIONMARK => Shift(yy_state_63)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_LEU => Shift(yy_state_138)
    T_LES => Shift(yy_state_140)
    T_LE => Shift(yy_state_142)
    T_GEU => Shift(yy_state_144)
    T_GES => Shift(yy_state_146)
    T_GE => Shift(yy_state_148)
    T_LTU => Shift(yy_state_150)
    T_LTS => Shift(yy_state_152)
    T_LT => Shift(yy_state_154)
    T_GTU => Shift(yy_state_156)
    T_GTS => Shift(yy_state_158)
    T_GT => Shift(yy_state_160)
    T_BANGEQUAL => Shift(yy_state_162)
    T_EQUALEQUAL => Shift(yy_state_164)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_COLON | T_FATARROW => Reduce(5, NT_branch_expr, yy_action_187)
    _ => Error
  }
}

fn yy_state_624(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    NT_expression => Shift(yy_state_625)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_625(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_QUESTIONMARK => Shift(yy_state_63)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_LEU => Shift(yy_state_138)
    T_LES => Shift(yy_state_140)
    T_LE => Shift(yy_state_142)
    T_GEU => Shift(yy_state_144)
    T_GES => Shift(yy_state_146)
    T_GE => Shift(yy_state_148)
    T_LTU => Shift(yy_state_150)
    T_LTS => Shift(yy_state_152)
    T_LT => Shift(yy_state_154)
    T_GTU => Shift(yy_state_156)
    T_GTS => Shift(yy_state_158)
    T_GT => Shift(yy_state_160)
    T_BANGEQUAL => Shift(yy_state_162)
    T_EQUALEQUAL => Shift(yy_state_164)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_COLON | T_FATARROW => Reduce(4, NT_branch_expr, yy_action_186)
    _ => Error
  }
}

fn yy_state_626(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_QUESTIONMARK => Shift(yy_state_63)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_LEU => Shift(yy_state_138)
    T_LES => Shift(yy_state_140)
    T_LE => Shift(yy_state_142)
    T_GEU => Shift(yy_state_144)
    T_GES => Shift(yy_state_146)
    T_GE => Shift(yy_state_148)
    T_LTU => Shift(yy_state_150)
    T_LTS => Shift(yy_state_152)
    T_LT => Shift(yy_state_154)
    T_GTU => Shift(yy_state_156)
    T_GTS => Shift(yy_state_158)
    T_GT => Shift(yy_state_160)
    T_BANGEQUAL => Shift(yy_state_162)
    T_EQUALEQUAL => Shift(yy_state_164)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_COLON | T_FATARROW => Reduce(5, NT_branch_expr, yy_action_185)
    _ => Error
  }
}

fn yy_state_627(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    NT_expression => Shift(yy_state_628)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_628(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_QUESTIONMARK => Shift(yy_state_63)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_LEU => Shift(yy_state_138)
    T_LES => Shift(yy_state_140)
    T_LE => Shift(yy_state_142)
    T_GEU => Shift(yy_state_144)
    T_GES => Shift(yy_state_146)
    T_GE => Shift(yy_state_148)
    T_LTU => Shift(yy_state_150)
    T_LTS => Shift(yy_state_152)
    T_LT => Shift(yy_state_154)
    T_GTU => Shift(yy_state_156)
    T_GTS => Shift(yy_state_158)
    T_GT => Shift(yy_state_160)
    T_BANGEQUAL => Shift(yy_state_162)
    T_EQUALEQUAL => Shift(yy_state_164)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_RPAREN | T_LBRACE | T_RBRACE | T_RBRACKET | T_COMMA | T_COLON | T_FATARROW => Reduce(4, NT_branch_expr, yy_action_184)
    _ => Error
  }
}

fn yy_state_629(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_attribute_guard => Shift(yy_state_630)
    T_COMMA => Shift(yy_state_632)
    T_RBRACKET => Reduce(0, NT_attribute_guard, yy_action_557)
    _ => Error
  }
}

fn yy_state_630(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_631)
    _ => Error
  }
}

fn yy_state_631(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(7, NT_attribute, yy_action_183)
}

fn yy_state_632(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IF => Shift(yy_state_633)
    _ => Error
  }
}

fn yy_state_633(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_634)
    _ => Error
  }
}

fn yy_state_634(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_134)
    NT_ident => Shift(yy_state_415)
    NT_condition => Shift(yy_state_635)
    _ => Error
  }
}

fn yy_state_635(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_636)
    _ => Error
  }
}

fn yy_state_636(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_attribute_guard, yy_action_182)
}

fn yy_state_637(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_QUESTIONMARK => Shift(yy_state_63)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_LEU => Shift(yy_state_138)
    T_LES => Shift(yy_state_140)
    T_LE => Shift(yy_state_142)
    T_GEU => Shift(yy_state_144)
    T_GES => Shift(yy_state_146)
    T_GE => Shift(yy_state_148)
    T_LTU => Shift(yy_state_150)
    T_LTS => Shift(yy_state_152)
    T_LT => Shift(yy_state_154)
    T_GTU => Shift(yy_state_156)
    T_GTS => Shift(yy_state_158)
    T_GT => Shift(yy_state_160)
    T_BANGEQUAL => Shift(yy_state_162)
    T_EQUALEQUAL => Shift(yy_state_164)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_RBRACKET | T_COMMA => Reduce(1, NT_attribute_expression, yy_action_181)
    _ => Error
  }
}

fn yy_state_638(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_attribute_name, yy_action_379)
}

fn yy_state_639(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_attribute => Shift(yy_state_2)
    NT_module_field => Shift(yy_state_639)
    NT_raw_parse => Shift(yy_state_640)
    T_SEMI => Shift(yy_state_641)
    T_EOF => Shift(yy_state_643)
    T_IMPORT => Shift(yy_state_644)
    NT_list_of_attribute_ => Shift(yy_state_719)
    NT_inner_attribute => Shift(yy_state_870)
    NT_rectype => Shift(yy_state_871)
    T_SHARP => Shift(yy_state_872)
    NT_type_definition => Shift(yy_state_888)
    T_REC => Shift(yy_state_889)
    T_TYPE => Shift(yy_state_893)
    T_FN | T_TAG | T_CONST | T_LET | T_MEMORY | T_DATA | T_TABLE | T_ELEM => Reduce(0, NT_list_of_attribute_, yy_action_559)
    _ => Error
  }
}

fn yy_state_640(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_raw_parse, yy_action_180)
}

fn yy_state_641(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_attribute => Shift(yy_state_2)
    NT_module_field => Shift(yy_state_639)
    T_SEMI => Shift(yy_state_641)
    NT_raw_parse => Shift(yy_state_642)
    T_EOF => Shift(yy_state_643)
    T_IMPORT => Shift(yy_state_644)
    NT_list_of_attribute_ => Shift(yy_state_719)
    NT_inner_attribute => Shift(yy_state_870)
    NT_rectype => Shift(yy_state_871)
    T_SHARP => Shift(yy_state_872)
    NT_type_definition => Shift(yy_state_888)
    T_REC => Shift(yy_state_889)
    T_TYPE => Shift(yy_state_893)
    T_FN | T_TAG | T_CONST | T_LET | T_MEMORY | T_DATA | T_TABLE | T_ELEM => Reduce(0, NT_list_of_attribute_, yy_action_559)
    _ => Error
  }
}

fn yy_state_642(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_raw_parse, yy_action_179)
}

fn yy_state_643(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_raw_parse, yy_action_178)
}

fn yy_state_644(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_STRING => Shift(yy_state_645)
    _ => Error
  }
}

fn yy_state_645(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_attribute => Shift(yy_state_2)
    T_SHARP => Shift(yy_state_4)
    NT_list_of_attribute_ => Shift(yy_state_646)
    T_LBRACE => Shift(yy_state_711)
    NT_import_item => Shift(yy_state_718)
    T_FN | T_TAG | T_CONST | T_LET | T_MEMORY | T_TABLE => Reduce(0, NT_list_of_attribute_, yy_action_559)
    _ => Error
  }
}

fn yy_state_646(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_TABLE => Shift(yy_state_647)
    T_MEMORY => Shift(yy_state_663)
    NT_tag_signature => Shift(yy_state_677)
    NT_globalmut => Shift(yy_state_678)
    NT_fundecl => Shift(yy_state_682)
    NT_import_kind_decl => Shift(yy_state_683)
    T_CONST => Shift(yy_state_685)
    T_LET => Shift(yy_state_686)
    T_TAG => Shift(yy_state_687)
    T_FN => Shift(yy_state_701)
    _ => Error
  }
}

fn yy_state_647(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_134)
    NT_ident => Shift(yy_state_648)
    _ => Error
  }
}

fn yy_state_648(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_649)
    _ => Error
  }
}

fn yy_state_649(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AMPERSAND => Shift(yy_state_201)
    NT_address_type => Shift(yy_state_650)
    NT_reference_type => Shift(yy_state_660)
    T_IDENT => Shift(yy_state_662)
    _ => Error
  }
}

fn yy_state_650(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AMPERSAND => Shift(yy_state_201)
    NT_reference_type => Shift(yy_state_651)
    _ => Error
  }
}

fn yy_state_651(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_mem_limits => Shift(yy_state_652)
    T_LBRACKET => Shift(yy_state_653)
    T_SEMI => Reduce(5, NT_import_kind_decl, yy_action_177)
    _ => Error
  }
}

fn yy_state_652(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_import_kind_decl, yy_action_176)
}

fn yy_state_653(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_INT => Shift(yy_state_654)
    _ => Error
  }
}

fn yy_state_654(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_655)
    NT_limit_max => Shift(yy_state_657)
    T_RBRACKET => Shift(yy_state_659)
    _ => Error
  }
}

fn yy_state_655(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_INT => Shift(yy_state_656)
    _ => Error
  }
}

fn yy_state_656(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_limit_max, yy_action_175)
}

fn yy_state_657(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_658)
    _ => Error
  }
}

fn yy_state_658(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_mem_limits, yy_action_173)
}

fn yy_state_659(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_mem_limits, yy_action_171)
}

fn yy_state_660(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_653)
    NT_mem_limits => Shift(yy_state_661)
    T_SEMI => Reduce(4, NT_import_kind_decl, yy_action_170)
    _ => Error
  }
}

fn yy_state_661(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_import_kind_decl, yy_action_169)
}

fn yy_state_662(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_address_type, yy_action_168)
}

fn yy_state_663(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_134)
    NT_ident => Shift(yy_state_664)
    _ => Error
  }
}

fn yy_state_664(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_665)
    _ => Error
  }
}

fn yy_state_665(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_662)
    NT_address_type => Shift(yy_state_666)
    _ => Error
  }
}

fn yy_state_666(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_653)
    T_SHARED => Shift(yy_state_667)
    NT_mem_limits => Shift(yy_state_668)
    T_PAGESIZE => Shift(yy_state_672)
    NT_mem_pagesize => Shift(yy_state_674)
    NT_boption_SHARED_ => Shift(yy_state_676)
    T_SEMI => Reduce(0, NT_boption_SHARED_, yy_action_167)
    _ => Error
  }
}

fn yy_state_667(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_boption_SHARED_, yy_action_166)
}

fn yy_state_668(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SHARED => Shift(yy_state_667)
    NT_mem_pagesize => Shift(yy_state_669)
    NT_boption_SHARED_ => Shift(yy_state_671)
    T_PAGESIZE => Shift(yy_state_672)
    T_SEMI => Reduce(0, NT_boption_SHARED_, yy_action_167)
    _ => Error
  }
}

fn yy_state_669(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SHARED => Shift(yy_state_667)
    NT_boption_SHARED_ => Shift(yy_state_670)
    T_SEMI => Reduce(0, NT_boption_SHARED_, yy_action_167)
    _ => Error
  }
}

fn yy_state_670(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(7, NT_import_kind_decl, yy_action_165)
}

fn yy_state_671(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_import_kind_decl, yy_action_164)
}

fn yy_state_672(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_INT => Shift(yy_state_673)
    _ => Error
  }
}

fn yy_state_673(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_mem_pagesize, yy_action_163)
}

fn yy_state_674(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SHARED => Shift(yy_state_667)
    NT_boption_SHARED_ => Shift(yy_state_675)
    T_SEMI => Reduce(0, NT_boption_SHARED_, yy_action_167)
    _ => Error
  }
}

fn yy_state_675(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_import_kind_decl, yy_action_162)
}

fn yy_state_676(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_import_kind_decl, yy_action_161)
}

fn yy_state_677(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_import_kind_decl, yy_action_160)
}

fn yy_state_678(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_134)
    NT_ident => Shift(yy_state_679)
    _ => Error
  }
}

fn yy_state_679(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_680)
    _ => Error
  }
}

fn yy_state_680(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AMPERSAND => Shift(yy_state_201)
    NT_reference_type => Shift(yy_state_355)
    T_IDENT => Shift(yy_state_356)
    NT_value_type => Shift(yy_state_681)
    _ => Error
  }
}

fn yy_state_681(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_import_kind_decl, yy_action_159)
}

fn yy_state_682(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_import_kind_decl, yy_action_158)
}

fn yy_state_683(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_684)
    _ => Error
  }
}

fn yy_state_684(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_import_item, yy_action_157)
}

fn yy_state_685(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_globalmut, yy_action_156)
}

fn yy_state_686(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_globalmut, yy_action_155)
}

fn yy_state_687(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_134)
    NT_ident => Shift(yy_state_336)
    NT_tag_name => Shift(yy_state_688)
    _ => Error
  }
}

fn yy_state_688(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_function_type_FN_ => Shift(yy_state_689)
    T_LPAREN => Shift(yy_state_690)
    T_COLON => Shift(yy_state_694)
    NT_tag_type => Shift(yy_state_697)
    NT_option_function_type_FN__ => Shift(yy_state_699)
    NT_optional_function_type => Shift(yy_state_700)
    T_SEMI => Reduce(0, NT_option_function_type_FN__, yy_action_154)
    _ => Error
  }
}

fn yy_state_689(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_option_function_type_FN__, yy_action_153)
}

fn yy_state_690(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AMPERSAND => Shift(yy_state_201)
    NT_reference_type => Shift(yy_state_355)
    NT_function_parameter => Shift(yy_state_559)
    NT_value_type => Shift(yy_state_562)
    NT_ident => Shift(yy_state_563)
    T_IDENT => Shift(yy_state_566)
    NT_non_empty_sep_trailing_COMMA_function_parameter_ => Shift(yy_state_570)
    NT_sep_trailing_COMMA_function_parameter_ => Shift(yy_state_571)
    NT_parameter_list => Shift(yy_state_691)
    T_RPAREN => Reduce(0, NT_sep_trailing_COMMA_function_parameter_, yy_action_226)
    _ => Error
  }
}

fn yy_state_691(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_692)
    _ => Error
  }
}

fn yy_state_692(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_ARROW => Shift(yy_state_465)
    NT_result_arrow => Shift(yy_state_693)
    T_SEMI | T_LBRACE | T_QUOTE => Reduce(3, NT_function_type_FN_, yy_action_152)
    _ => Error
  }
}

fn yy_state_693(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_function_type_FN_, yy_action_151)
}

fn yy_state_694(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_134)
    NT_type_name => Shift(yy_state_695)
    NT_ident => Shift(yy_state_696)
    _ => Error
  }
}

fn yy_state_695(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_tag_type, yy_action_150)
}

fn yy_state_696(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_type_name, yy_action_149)
}

fn yy_state_697(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_function_type_FN_ => Shift(yy_state_689)
    T_LPAREN => Shift(yy_state_690)
    NT_optional_function_type => Shift(yy_state_698)
    NT_option_function_type_FN__ => Shift(yy_state_699)
    T_SEMI => Reduce(0, NT_option_function_type_FN__, yy_action_154)
    _ => Error
  }
}

fn yy_state_698(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_tag_signature, yy_action_147)
}

fn yy_state_699(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_optional_function_type, yy_action_146)
}

fn yy_state_700(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_tag_signature, yy_action_144)
}

fn yy_state_701(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_134)
    NT_function_name => Shift(yy_state_702)
    NT_ident => Shift(yy_state_710)
    _ => Error
  }
}

fn yy_state_702(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_203)
    NT_boption_BANG_ => Shift(yy_state_703)
    T_SEMI | T_LPAREN | T_LBRACE | T_COLON | T_QUOTE => Reduce(0, NT_boption_BANG_, yy_action_433)
    _ => Error
  }
}

fn yy_state_703(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_function_type_FN_ => Shift(yy_state_689)
    T_LPAREN => Shift(yy_state_690)
    NT_option_function_type_FN__ => Shift(yy_state_699)
    T_COLON => Shift(yy_state_704)
    NT_fundecl_type => Shift(yy_state_707)
    NT_optional_function_type => Shift(yy_state_709)
    T_SEMI | T_LBRACE | T_QUOTE => Reduce(0, NT_option_function_type_FN__, yy_action_154)
    _ => Error
  }
}

fn yy_state_704(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_203)
    NT_boption_BANG_ => Shift(yy_state_705)
    T_IDENT => Reduce(0, NT_boption_BANG_, yy_action_433)
    _ => Error
  }
}

fn yy_state_705(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_134)
    NT_ident => Shift(yy_state_696)
    NT_type_name => Shift(yy_state_706)
    _ => Error
  }
}

fn yy_state_706(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_fundecl_type, yy_action_143)
}

fn yy_state_707(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_function_type_FN_ => Shift(yy_state_689)
    T_LPAREN => Shift(yy_state_690)
    NT_option_function_type_FN__ => Shift(yy_state_699)
    NT_optional_function_type => Shift(yy_state_708)
    T_SEMI | T_LBRACE | T_QUOTE => Reduce(0, NT_option_function_type_FN__, yy_action_154)
    _ => Error
  }
}

fn yy_state_708(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_fundecl, yy_action_141)
}

fn yy_state_709(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_fundecl, yy_action_139)
}

fn yy_state_710(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_function_name, yy_action_138)
}

fn yy_state_711(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_attribute => Shift(yy_state_2)
    T_SHARP => Shift(yy_state_4)
    NT_list_of_attribute_ => Shift(yy_state_646)
    NT_import_item => Shift(yy_state_712)
    T_SEMI => Shift(yy_state_714)
    NT_semi_list_import_item_ => Shift(yy_state_716)
    T_FN | T_TAG | T_CONST | T_LET | T_MEMORY | T_TABLE => Reduce(0, NT_list_of_attribute_, yy_action_559)
    T_RBRACE => Reduce(0, NT_semi_list_import_item_, yy_action_137)
    _ => Error
  }
}

fn yy_state_712(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_attribute => Shift(yy_state_2)
    T_SHARP => Shift(yy_state_4)
    NT_list_of_attribute_ => Shift(yy_state_646)
    NT_import_item => Shift(yy_state_712)
    NT_semi_list_import_item_ => Shift(yy_state_713)
    T_SEMI => Shift(yy_state_714)
    T_FN | T_TAG | T_CONST | T_LET | T_MEMORY | T_TABLE => Reduce(0, NT_list_of_attribute_, yy_action_559)
    T_RBRACE => Reduce(0, NT_semi_list_import_item_, yy_action_137)
    _ => Error
  }
}

fn yy_state_713(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_semi_list_import_item_, yy_action_136)
}

fn yy_state_714(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_attribute => Shift(yy_state_2)
    T_SHARP => Shift(yy_state_4)
    NT_list_of_attribute_ => Shift(yy_state_646)
    NT_import_item => Shift(yy_state_712)
    T_SEMI => Shift(yy_state_714)
    NT_semi_list_import_item_ => Shift(yy_state_715)
    T_FN | T_TAG | T_CONST | T_LET | T_MEMORY | T_TABLE => Reduce(0, NT_list_of_attribute_, yy_action_559)
    T_RBRACE => Reduce(0, NT_semi_list_import_item_, yy_action_137)
    _ => Error
  }
}

fn yy_state_715(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_semi_list_import_item_, yy_action_135)
}

fn yy_state_716(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_717)
    _ => Error
  }
}

fn yy_state_717(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_module_field, yy_action_134)
}

fn yy_state_718(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_module_field, yy_action_133)
}

fn yy_state_719(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_CONST => Shift(yy_state_685)
    T_LET => Shift(yy_state_686)
    T_TAG => Shift(yy_state_687)
    T_FN => Shift(yy_state_701)
    NT_definition => Shift(yy_state_720)
    T_ELEM => Shift(yy_state_721)
    T_TABLE => Shift(yy_state_741)
    T_DATA => Shift(yy_state_763)
    T_MEMORY => Shift(yy_state_809)
    NT_tag_def => Shift(yy_state_846)
    NT_elem => Shift(yy_state_847)
    NT_table => Shift(yy_state_848)
    NT_data => Shift(yy_state_849)
    NT_memory => Shift(yy_state_850)
    NT_global => Shift(yy_state_851)
    NT_func => Shift(yy_state_852)
    NT_tag_signature => Shift(yy_state_853)
    NT_globalmut => Shift(yy_state_855)
    NT_fundecl => Shift(yy_state_864)
    _ => Error
  }
}

fn yy_state_720(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_module_field, yy_action_132)
}

fn yy_state_721(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_134)
    NT_ident => Shift(yy_state_722)
    _ => Error
  }
}

fn yy_state_722(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_723)
    _ => Error
  }
}

fn yy_state_723(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AMPERSAND => Shift(yy_state_201)
    NT_reference_type => Shift(yy_state_724)
    _ => Error
  }
}

fn yy_state_724(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AT => Shift(yy_state_725)
    T_EQUAL => Shift(yy_state_736)
    _ => Error
  }
}

fn yy_state_725(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_134)
    NT_ident => Shift(yy_state_726)
    _ => Error
  }
}

fn yy_state_726(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_727)
    _ => Error
  }
}

fn yy_state_727(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    NT_constant_expression => Shift(yy_state_728)
    NT_expression => Shift(yy_state_735)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_728(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_729)
    _ => Error
  }
}

fn yy_state_729(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_730)
    _ => Error
  }
}

fn yy_state_730(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_731)
    _ => Error
  }
}

fn yy_state_731(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_non_empty_sep_trailing_COMMA_expression_ => Shift(yy_state_34)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    NT_expression => Shift(yy_state_332)
    NT_sep_trailing_COMMA_expression_ => Shift(yy_state_335)
    NT_expression_list => Shift(yy_state_732)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    T_RBRACKET => Reduce(0, NT_sep_trailing_COMMA_expression_, yy_action_549)
    _ => Error
  }
}

fn yy_state_732(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_733)
    _ => Error
  }
}

fn yy_state_733(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_734)
    _ => Error
  }
}

fn yy_state_734(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(14, NT_elem, yy_action_131)
}

fn yy_state_735(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_QUESTIONMARK => Shift(yy_state_63)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_LEU => Shift(yy_state_138)
    T_LES => Shift(yy_state_140)
    T_LE => Shift(yy_state_142)
    T_GEU => Shift(yy_state_144)
    T_GES => Shift(yy_state_146)
    T_GE => Shift(yy_state_148)
    T_LTU => Shift(yy_state_150)
    T_LTS => Shift(yy_state_152)
    T_LT => Shift(yy_state_154)
    T_GTU => Shift(yy_state_156)
    T_GTS => Shift(yy_state_158)
    T_GT => Shift(yy_state_160)
    T_BANGEQUAL => Shift(yy_state_162)
    T_EQUALEQUAL => Shift(yy_state_164)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI | T_RBRACKET => Reduce(1, NT_constant_expression, yy_action_130)
    _ => Error
  }
}

fn yy_state_736(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_737)
    _ => Error
  }
}

fn yy_state_737(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_non_empty_sep_trailing_COMMA_expression_ => Shift(yy_state_34)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    NT_expression => Shift(yy_state_332)
    NT_sep_trailing_COMMA_expression_ => Shift(yy_state_335)
    NT_expression_list => Shift(yy_state_738)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    T_RBRACKET => Reduce(0, NT_sep_trailing_COMMA_expression_, yy_action_549)
    _ => Error
  }
}

fn yy_state_738(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_739)
    _ => Error
  }
}

fn yy_state_739(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_740)
    _ => Error
  }
}

fn yy_state_740(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(9, NT_elem, yy_action_129)
}

fn yy_state_741(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_134)
    NT_ident => Shift(yy_state_742)
    _ => Error
  }
}

fn yy_state_742(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_743)
    _ => Error
  }
}

fn yy_state_743(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AMPERSAND => Shift(yy_state_201)
    T_IDENT => Shift(yy_state_662)
    NT_address_type => Shift(yy_state_744)
    NT_reference_type => Shift(yy_state_755)
    _ => Error
  }
}

fn yy_state_744(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AMPERSAND => Shift(yy_state_201)
    NT_reference_type => Shift(yy_state_745)
    _ => Error
  }
}

fn yy_state_745(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_653)
    T_EQUAL => Shift(yy_state_746)
    NT_mem_limits => Shift(yy_state_748)
    NT_table_init => Shift(yy_state_752)
    T_SEMI => Shift(yy_state_754)
    _ => Error
  }
}

fn yy_state_746(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    NT_expression => Shift(yy_state_747)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_747(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_62)
    T_QUESTIONMARK => Shift(yy_state_63)
    T_LBRACKET => Shift(yy_state_67)
    T_ON => Shift(yy_state_72)
    T_LEU => Shift(yy_state_138)
    T_LES => Shift(yy_state_140)
    T_LE => Shift(yy_state_142)
    T_GEU => Shift(yy_state_144)
    T_GES => Shift(yy_state_146)
    T_GE => Shift(yy_state_148)
    T_LTU => Shift(yy_state_150)
    T_LTS => Shift(yy_state_152)
    T_LT => Shift(yy_state_154)
    T_GTU => Shift(yy_state_156)
    T_GTS => Shift(yy_state_158)
    T_GT => Shift(yy_state_160)
    T_BANGEQUAL => Shift(yy_state_162)
    T_EQUALEQUAL => Shift(yy_state_164)
    T_SHRU => Shift(yy_state_166)
    T_SHRS => Shift(yy_state_168)
    T_SHL => Shift(yy_state_170)
    T_PIPE => Shift(yy_state_172)
    T_CARET => Shift(yy_state_174)
    T_AMPERSAND => Shift(yy_state_176)
    T_PERCENTU => Shift(yy_state_178)
    T_PERCENTS => Shift(yy_state_180)
    T_SLASHU => Shift(yy_state_182)
    T_SLASHS => Shift(yy_state_184)
    T_SLASH => Shift(yy_state_186)
    T_STAR => Shift(yy_state_188)
    T_MINUS => Shift(yy_state_190)
    T_PLUS => Shift(yy_state_192)
    T_DOT => Shift(yy_state_194)
    T_IS => Shift(yy_state_199)
    T_AS => Shift(yy_state_208)
    T_LPAREN => Shift(yy_state_216)
    T_SEMI => Reduce(2, NT_table_init, yy_action_128)
    _ => Error
  }
}

fn yy_state_748(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_746)
    NT_table_init => Shift(yy_state_749)
    T_SEMI => Shift(yy_state_751)
    _ => Error
  }
}

fn yy_state_749(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_750)
    _ => Error
  }
}

fn yy_state_750(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(8, NT_table, yy_action_127)
}

fn yy_state_751(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(7, NT_table, yy_action_126)
}

fn yy_state_752(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_753)
    _ => Error
  }
}

fn yy_state_753(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(7, NT_table, yy_action_125)
}

fn yy_state_754(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_table, yy_action_123)
}

fn yy_state_755(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_653)
    T_EQUAL => Shift(yy_state_746)
    NT_mem_limits => Shift(yy_state_756)
    NT_table_init => Shift(yy_state_760)
    T_SEMI => Shift(yy_state_762)
    _ => Error
  }
}

fn yy_state_756(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_746)
    NT_table_init => Shift(yy_state_757)
    T_SEMI => Shift(yy_state_759)
    _ => Error
  }
}

fn yy_state_757(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_758)
    _ => Error
  }
}

fn yy_state_758(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(7, NT_table, yy_action_122)
}

fn yy_state_759(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_table, yy_action_121)
}

fn yy_state_760(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_761)
    _ => Error
  }
}

fn yy_state_761(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_table, yy_action_119)
}

fn yy_state_762(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_table, yy_action_116)
}

fn yy_state_763(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_134)
    NT_data_name => Shift(yy_state_764)
    NT_ident => Shift(yy_state_807)
    T_UNDERSCORE => Shift(yy_state_808)
    _ => Error
  }
}

fn yy_state_764(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AT => Shift(yy_state_765)
    T_EQUAL => Shift(yy_state_772)
    NT_loption_data_init => Shift(yy_state_805)
    T_SEMI => Reduce(0, NT_loption_data_init, yy_action_115)
    _ => Error
  }
}

fn yy_state_765(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_134)
    NT_ident => Shift(yy_state_766)
    _ => Error
  }
}

fn yy_state_766(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_767)
    _ => Error
  }
}

fn yy_state_767(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    NT_expression => Shift(yy_state_735)
    NT_constant_expression => Shift(yy_state_768)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_768(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_769)
    _ => Error
  }
}

fn yy_state_769(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_loption_data_init => Shift(yy_state_770)
    T_EQUAL => Shift(yy_state_772)
    T_SEMI => Reduce(0, NT_loption_data_init, yy_action_115)
    _ => Error
  }
}

fn yy_state_770(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_771)
    _ => Error
  }
}

fn yy_state_771(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(9, NT_data, yy_action_114)
}

fn yy_state_772(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_data_init => Shift(yy_state_773)
    T_LBRACKET => Shift(yy_state_774)
    T_STRING => Shift(yy_state_801)
    NT_data_element => Shift(yy_state_802)
    _ => Error
  }
}

fn yy_state_773(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_loption_data_init, yy_action_113)
}

fn yy_state_774(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_134)
    NT_ident => Shift(yy_state_775)
    _ => Error
  }
}

fn yy_state_775(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_776)
    _ => Error
  }
}

fn yy_state_776(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_134)
    NT_data_run_item => Shift(yy_state_777)
    T_NAN => Shift(yy_state_780)
    T_INF => Shift(yy_state_781)
    T_FLOAT => Shift(yy_state_782)
    T_INT => Shift(yy_state_783)
    T_PLUS => Shift(yy_state_784)
    T_MINUS => Shift(yy_state_785)
    NT_data_sign => Shift(yy_state_786)
    NT_raw_number => Shift(yy_state_788)
    NT_ident => Shift(yy_state_789)
    NT_data_number => Shift(yy_state_797)
    NT_non_empty_sep_trailing_COMMA_data_run_item_ => Shift(yy_state_798)
    NT_sep_trailing_COMMA_data_run_item_ => Shift(yy_state_799)
    T_RBRACKET => Reduce(0, NT_sep_trailing_COMMA_data_run_item_, yy_action_112)
    _ => Error
  }
}

fn yy_state_777(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_778)
    T_RBRACKET => Reduce(1, NT_non_empty_sep_trailing_COMMA_data_run_item_, yy_action_111)
    _ => Error
  }
}

fn yy_state_778(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_134)
    NT_data_run_item => Shift(yy_state_777)
    NT_non_empty_sep_trailing_COMMA_data_run_item_ => Shift(yy_state_779)
    T_NAN => Shift(yy_state_780)
    T_INF => Shift(yy_state_781)
    T_FLOAT => Shift(yy_state_782)
    T_INT => Shift(yy_state_783)
    T_PLUS => Shift(yy_state_784)
    T_MINUS => Shift(yy_state_785)
    NT_data_sign => Shift(yy_state_786)
    NT_raw_number => Shift(yy_state_788)
    NT_ident => Shift(yy_state_789)
    NT_data_number => Shift(yy_state_797)
    T_RBRACKET => Reduce(2, NT_non_empty_sep_trailing_COMMA_data_run_item_, yy_action_110)
    _ => Error
  }
}

fn yy_state_779(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_sep_trailing_COMMA_data_run_item_, yy_action_109)
}

fn yy_state_780(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_raw_number, yy_action_108)
}

fn yy_state_781(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_raw_number, yy_action_107)
}

fn yy_state_782(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_raw_number, yy_action_106)
}

fn yy_state_783(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_raw_number, yy_action_105)
}

fn yy_state_784(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_data_sign, yy_action_104)
}

fn yy_state_785(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_data_sign, yy_action_103)
}

fn yy_state_786(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_NAN => Shift(yy_state_780)
    T_INF => Shift(yy_state_781)
    T_FLOAT => Shift(yy_state_782)
    T_INT => Shift(yy_state_783)
    NT_raw_number => Shift(yy_state_787)
    _ => Error
  }
}

fn yy_state_787(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_data_number, yy_action_101)
}

fn yy_state_788(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_data_number, yy_action_99)
}

fn yy_state_789(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_790)
    _ => Error
  }
}

fn yy_state_790(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_NAN => Shift(yy_state_780)
    T_INF => Shift(yy_state_781)
    T_FLOAT => Shift(yy_state_782)
    T_INT => Shift(yy_state_783)
    T_PLUS => Shift(yy_state_784)
    T_MINUS => Shift(yy_state_785)
    NT_data_sign => Shift(yy_state_786)
    NT_raw_number => Shift(yy_state_788)
    NT_data_number => Shift(yy_state_791)
    NT_non_empty_sep_trailing_COMMA_data_number_ => Shift(yy_state_794)
    NT_sep_trailing_COMMA_data_number_ => Shift(yy_state_795)
    T_RPAREN => Reduce(0, NT_sep_trailing_COMMA_data_number_, yy_action_98)
    _ => Error
  }
}

fn yy_state_791(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_792)
    T_RPAREN => Reduce(1, NT_non_empty_sep_trailing_COMMA_data_number_, yy_action_97)
    _ => Error
  }
}

fn yy_state_792(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_NAN => Shift(yy_state_780)
    T_INF => Shift(yy_state_781)
    T_FLOAT => Shift(yy_state_782)
    T_INT => Shift(yy_state_783)
    T_PLUS => Shift(yy_state_784)
    T_MINUS => Shift(yy_state_785)
    NT_data_sign => Shift(yy_state_786)
    NT_raw_number => Shift(yy_state_788)
    NT_data_number => Shift(yy_state_791)
    NT_non_empty_sep_trailing_COMMA_data_number_ => Shift(yy_state_793)
    T_RPAREN => Reduce(2, NT_non_empty_sep_trailing_COMMA_data_number_, yy_action_96)
    _ => Error
  }
}

fn yy_state_793(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_sep_trailing_COMMA_data_number_, yy_action_95)
}

fn yy_state_794(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_sep_trailing_COMMA_data_number_, yy_action_94)
}

fn yy_state_795(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_796)
    _ => Error
  }
}

fn yy_state_796(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_data_run_item, yy_action_93)
}

fn yy_state_797(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_data_run_item, yy_action_92)
}

fn yy_state_798(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_sep_trailing_COMMA_data_run_item_, yy_action_91)
}

fn yy_state_799(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_800)
    _ => Error
  }
}

fn yy_state_800(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_data_element, yy_action_90)
}

fn yy_state_801(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_data_element, yy_action_89)
}

fn yy_state_802(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_PLUSPLUS => Shift(yy_state_803)
    T_SEMI => Reduce(1, NT_data_init, yy_action_88)
    _ => Error
  }
}

fn yy_state_803(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_774)
    T_STRING => Shift(yy_state_801)
    NT_data_element => Shift(yy_state_802)
    NT_data_init => Shift(yy_state_804)
    _ => Error
  }
}

fn yy_state_804(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_data_init, yy_action_87)
}

fn yy_state_805(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_806)
    _ => Error
  }
}

fn yy_state_806(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_data, yy_action_86)
}

fn yy_state_807(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_data_name, yy_action_85)
}

fn yy_state_808(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_data_name, yy_action_84)
}

fn yy_state_809(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_134)
    NT_ident => Shift(yy_state_810)
    _ => Error
  }
}

fn yy_state_810(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_811)
    _ => Error
  }
}

fn yy_state_811(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_662)
    NT_address_type => Shift(yy_state_812)
    _ => Error
  }
}

fn yy_state_812(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_653)
    T_SHARED => Shift(yy_state_667)
    T_PAGESIZE => Shift(yy_state_672)
    NT_mem_limits => Shift(yy_state_813)
    NT_mem_pagesize => Shift(yy_state_835)
    NT_boption_SHARED_ => Shift(yy_state_841)
    T_SEMI | T_LBRACE => Reduce(0, NT_boption_SHARED_, yy_action_167)
    _ => Error
  }
}

fn yy_state_813(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SHARED => Shift(yy_state_667)
    T_PAGESIZE => Shift(yy_state_672)
    NT_mem_pagesize => Shift(yy_state_814)
    NT_boption_SHARED_ => Shift(yy_state_830)
    T_SEMI | T_LBRACE => Reduce(0, NT_boption_SHARED_, yy_action_167)
    _ => Error
  }
}

fn yy_state_814(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SHARED => Shift(yy_state_667)
    NT_boption_SHARED_ => Shift(yy_state_815)
    T_SEMI | T_LBRACE => Reduce(0, NT_boption_SHARED_, yy_action_167)
    _ => Error
  }
}

fn yy_state_815(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_816)
    T_SEMI => Shift(yy_state_829)
    _ => Error
  }
}

fn yy_state_816(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_data_item => Shift(yy_state_817)
    T_DATA => Shift(yy_state_819)
    NT_list_of_data_item_ => Shift(yy_state_827)
    T_RBRACE => Reduce(0, NT_list_of_data_item_, yy_action_83)
    _ => Error
  }
}

fn yy_state_817(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_data_item => Shift(yy_state_817)
    NT_list_of_data_item_ => Shift(yy_state_818)
    T_DATA => Shift(yy_state_819)
    T_RBRACE => Reduce(0, NT_list_of_data_item_, yy_action_83)
    _ => Error
  }
}

fn yy_state_818(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_list_of_data_item_, yy_action_82)
}

fn yy_state_819(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_134)
    NT_ident => Shift(yy_state_807)
    T_UNDERSCORE => Shift(yy_state_808)
    NT_data_name => Shift(yy_state_820)
    _ => Error
  }
}

fn yy_state_820(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AT => Shift(yy_state_821)
    _ => Error
  }
}

fn yy_state_821(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_822)
    _ => Error
  }
}

fn yy_state_822(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    NT_expression => Shift(yy_state_735)
    NT_constant_expression => Shift(yy_state_823)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_823(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_824)
    _ => Error
  }
}

fn yy_state_824(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_772)
    NT_loption_data_init => Shift(yy_state_825)
    T_SEMI => Reduce(0, NT_loption_data_init, yy_action_115)
    _ => Error
  }
}

fn yy_state_825(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_826)
    _ => Error
  }
}

fn yy_state_826(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(8, NT_data_item, yy_action_81)
}

fn yy_state_827(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_828)
    _ => Error
  }
}

fn yy_state_828(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(10, NT_memory, yy_action_80)
}

fn yy_state_829(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(8, NT_memory, yy_action_79)
}

fn yy_state_830(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_831)
    T_SEMI => Shift(yy_state_834)
    _ => Error
  }
}

fn yy_state_831(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_data_item => Shift(yy_state_817)
    T_DATA => Shift(yy_state_819)
    NT_list_of_data_item_ => Shift(yy_state_832)
    T_RBRACE => Reduce(0, NT_list_of_data_item_, yy_action_83)
    _ => Error
  }
}

fn yy_state_832(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_833)
    _ => Error
  }
}

fn yy_state_833(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(9, NT_memory, yy_action_78)
}

fn yy_state_834(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(7, NT_memory, yy_action_76)
}

fn yy_state_835(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SHARED => Shift(yy_state_667)
    NT_boption_SHARED_ => Shift(yy_state_836)
    T_SEMI | T_LBRACE => Reduce(0, NT_boption_SHARED_, yy_action_167)
    _ => Error
  }
}

fn yy_state_836(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_837)
    T_SEMI => Shift(yy_state_840)
    _ => Error
  }
}

fn yy_state_837(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_data_item => Shift(yy_state_817)
    T_DATA => Shift(yy_state_819)
    NT_list_of_data_item_ => Shift(yy_state_838)
    T_RBRACE => Reduce(0, NT_list_of_data_item_, yy_action_83)
    _ => Error
  }
}

fn yy_state_838(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_839)
    _ => Error
  }
}

fn yy_state_839(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(9, NT_memory, yy_action_75)
}

fn yy_state_840(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(7, NT_memory, yy_action_73)
}

fn yy_state_841(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_842)
    T_SEMI => Shift(yy_state_845)
    _ => Error
  }
}

fn yy_state_842(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_data_item => Shift(yy_state_817)
    T_DATA => Shift(yy_state_819)
    NT_list_of_data_item_ => Shift(yy_state_843)
    T_RBRACE => Reduce(0, NT_list_of_data_item_, yy_action_83)
    _ => Error
  }
}

fn yy_state_843(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_844)
    _ => Error
  }
}

fn yy_state_844(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(8, NT_memory, yy_action_72)
}

fn yy_state_845(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_memory, yy_action_69)
}

fn yy_state_846(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_definition, yy_action_68)
}

fn yy_state_847(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_definition, yy_action_67)
}

fn yy_state_848(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_definition, yy_action_66)
}

fn yy_state_849(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_definition, yy_action_65)
}

fn yy_state_850(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_definition, yy_action_64)
}

fn yy_state_851(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_definition, yy_action_63)
}

fn yy_state_852(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_definition, yy_action_62)
}

fn yy_state_853(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_854)
    _ => Error
  }
}

fn yy_state_854(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_tag_def, yy_action_61)
}

fn yy_state_855(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_134)
    NT_ident => Shift(yy_state_856)
    _ => Error
  }
}

fn yy_state_856(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_353)
    NT_type_annot => Shift(yy_state_857)
    T_EQUAL => Shift(yy_state_861)
    _ => Error
  }
}

fn yy_state_857(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_858)
    _ => Error
  }
}

fn yy_state_858(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    NT_expression => Shift(yy_state_735)
    NT_constant_expression => Shift(yy_state_859)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_859(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_860)
    _ => Error
  }
}

fn yy_state_860(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_global, yy_action_59)
}

fn yy_state_861(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    NT_expression => Shift(yy_state_735)
    NT_constant_expression => Shift(yy_state_862)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_862(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_863)
    _ => Error
  }
}

fn yy_state_863(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_global, yy_action_57)
}

fn yy_state_864(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_QUOTE => Shift(yy_state_82)
    NT_labelled => Shift(yy_state_304)
    NT_label => Shift(yy_state_323)
    NT_block_label => Shift(yy_state_865)
    NT_block => Shift(yy_state_869)
    T_LBRACE => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_865(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_866)
    _ => Error
  }
}

fn yy_state_866(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    NT_statement => Shift(yy_state_238)
    NT_cond_stmt => Shift(yy_state_242)
    T_SEMI => Shift(yy_state_244)
    T_BECOME => Shift(yy_state_246)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    NT_label => Shift(yy_state_323)
    T_THROW_REF => Shift(yy_state_325)
    T_THROW => Shift(yy_state_327)
    T_RETURN => Shift(yy_state_337)
    T_BR_TABLE => Shift(yy_state_339)
    T_BR => Shift(yy_state_344)
    T_LET => Shift(yy_state_347)
    T_UNREACHABLE => Shift(yy_state_374)
    T_NOP => Shift(yy_state_375)
    NT_hint_attr => Shift(yy_state_376)
    NT_plaininstr => Shift(yy_state_378)
    NT_blockinstr => Shift(yy_state_379)
    NT_expression => Shift(yy_state_381)
    NT_ident => Shift(yy_state_382)
    T_UNDERSCORE => Shift(yy_state_401)
    T_SHARP => Shift(yy_state_408)
    NT_raw_statement_list => Shift(yy_state_445)
    NT_statement_list => Shift(yy_state_867)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    T_RBRACE => Reduce(0, NT_raw_statement_list, yy_action_414)
    _ => Error
  }
}

fn yy_state_867(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_868)
    _ => Error
  }
}

fn yy_state_868(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_block, yy_action_56)
}

fn yy_state_869(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_func, yy_action_55)
}

fn yy_state_870(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_module_field, yy_action_54)
}

fn yy_state_871(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_module_field, yy_action_53)
}

fn yy_state_872(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_BANG => Shift(yy_state_873)
    T_LBRACKET => Shift(yy_state_880)
    _ => Error
  }
}

fn yy_state_873(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACKET => Shift(yy_state_874)
    _ => Error
  }
}

fn yy_state_874(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_875)
    _ => Error
  }
}

fn yy_state_875(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_876)
    T_EQUAL => Shift(yy_state_877)
    _ => Error
  }
}

fn yy_state_876(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_inner_attribute, yy_action_52)
}

fn yy_state_877(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_hint_attr => Shift(yy_state_10)
    NT_plaininstr => Shift(yy_state_11)
    NT_blockinstr => Shift(yy_state_12)
    T_BR_ON_CAST_FAIL => Shift(yy_state_13)
    T_BR_ON_CAST => Shift(yy_state_18)
    T_BR_ON_NON_NULL => Shift(yy_state_22)
    T_BR_ON_NULL => Shift(yy_state_24)
    T_BR_IF => Shift(yy_state_26)
    T_MINUS => Shift(yy_state_28)
    T_PLUS => Shift(yy_state_29)
    T_BANG => Shift(yy_state_30)
    T_SUSPEND => Shift(yy_state_31)
    NT_branch_expr => Shift(yy_state_37)
    T_LBRACKET => Shift(yy_state_38)
    T_LBRACE => Shift(yy_state_42)
    T_NAN => Shift(yy_state_50)
    T_INF => Shift(yy_state_51)
    T_FLOAT => Shift(yy_state_52)
    T_INT => Shift(yy_state_53)
    T_STRING => Shift(yy_state_54)
    T_CHAR => Shift(yy_state_55)
    T_LPAREN => Shift(yy_state_56)
    NT_ident => Shift(yy_state_59)
    T_QUOTE => Shift(yy_state_82)
    T_IDENT => Shift(yy_state_134)
    T_UNDERSCORE => Shift(yy_state_213)
    T_NULL => Shift(yy_state_214)
    NT_block_label => Shift(yy_state_223)
    T_MATCH => Shift(yy_state_260)
    T_DISPATCH => Shift(yy_state_281)
    NT_labelled => Shift(yy_state_304)
    NT_attribute => Shift(yy_state_305)
    T_SHARP => Shift(yy_state_306)
    NT_label => Shift(yy_state_323)
    NT_expression => Shift(yy_state_637)
    NT_attribute_expression => Shift(yy_state_878)
    T_DO | T_WHILE | T_LOOP | T_IF | T_TRY | T_TRY_LEGACY => Reduce(0, NT_block_label, yy_action_554)
    _ => Error
  }
}

fn yy_state_878(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_879)
    _ => Error
  }
}

fn yy_state_879(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(7, NT_inner_attribute, yy_action_51)
}

fn yy_state_880(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_attribute_name => Shift(yy_state_6)
    T_IMPORT => Shift(yy_state_308)
    T_IDENT => Shift(yy_state_638)
    T_ELSE => Shift(yy_state_881)
    T_IF => Shift(yy_state_957)
    _ => Error
  }
}

fn yy_state_881(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_882)
    _ => Error
  }
}

fn yy_state_882(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_883)
    NT_braced_fields => Shift(yy_state_956)
    _ => Error
  }
}

fn yy_state_883(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_attribute => Shift(yy_state_2)
    T_IMPORT => Shift(yy_state_644)
    NT_list_of_attribute_ => Shift(yy_state_719)
    NT_inner_attribute => Shift(yy_state_870)
    NT_rectype => Shift(yy_state_871)
    T_SHARP => Shift(yy_state_872)
    NT_module_field => Shift(yy_state_884)
    T_SEMI => Shift(yy_state_886)
    NT_type_definition => Shift(yy_state_888)
    T_REC => Shift(yy_state_889)
    T_TYPE => Shift(yy_state_893)
    NT_semi_list_module_field_ => Shift(yy_state_954)
    T_FN | T_TAG | T_CONST | T_LET | T_MEMORY | T_DATA | T_TABLE | T_ELEM => Reduce(0, NT_list_of_attribute_, yy_action_559)
    T_RBRACE => Reduce(0, NT_semi_list_module_field_, yy_action_50)
    _ => Error
  }
}

fn yy_state_884(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_attribute => Shift(yy_state_2)
    T_IMPORT => Shift(yy_state_644)
    NT_list_of_attribute_ => Shift(yy_state_719)
    NT_inner_attribute => Shift(yy_state_870)
    NT_rectype => Shift(yy_state_871)
    T_SHARP => Shift(yy_state_872)
    NT_module_field => Shift(yy_state_884)
    NT_semi_list_module_field_ => Shift(yy_state_885)
    T_SEMI => Shift(yy_state_886)
    NT_type_definition => Shift(yy_state_888)
    T_REC => Shift(yy_state_889)
    T_TYPE => Shift(yy_state_893)
    T_FN | T_TAG | T_CONST | T_LET | T_MEMORY | T_DATA | T_TABLE | T_ELEM => Reduce(0, NT_list_of_attribute_, yy_action_559)
    T_RBRACE => Reduce(0, NT_semi_list_module_field_, yy_action_50)
    _ => Error
  }
}

fn yy_state_885(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_semi_list_module_field_, yy_action_49)
}

fn yy_state_886(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_attribute => Shift(yy_state_2)
    T_IMPORT => Shift(yy_state_644)
    NT_list_of_attribute_ => Shift(yy_state_719)
    NT_inner_attribute => Shift(yy_state_870)
    NT_rectype => Shift(yy_state_871)
    T_SHARP => Shift(yy_state_872)
    NT_module_field => Shift(yy_state_884)
    T_SEMI => Shift(yy_state_886)
    NT_semi_list_module_field_ => Shift(yy_state_887)
    NT_type_definition => Shift(yy_state_888)
    T_REC => Shift(yy_state_889)
    T_TYPE => Shift(yy_state_893)
    T_FN | T_TAG | T_CONST | T_LET | T_MEMORY | T_DATA | T_TABLE | T_ELEM => Reduce(0, NT_list_of_attribute_, yy_action_559)
    T_RBRACE => Reduce(0, NT_semi_list_module_field_, yy_action_50)
    _ => Error
  }
}

fn yy_state_887(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_semi_list_module_field_, yy_action_48)
}

fn yy_state_888(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_rectype, yy_action_47)
}

fn yy_state_889(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_890)
    _ => Error
  }
}

fn yy_state_890(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_definition => Shift(yy_state_891)
    T_TYPE => Shift(yy_state_893)
    NT_list_of_type_definition_ => Shift(yy_state_952)
    T_RBRACE => Reduce(0, NT_list_of_type_definition_, yy_action_46)
    _ => Error
  }
}

fn yy_state_891(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_type_definition => Shift(yy_state_891)
    NT_list_of_type_definition_ => Shift(yy_state_892)
    T_TYPE => Shift(yy_state_893)
    T_RBRACE => Reduce(0, NT_list_of_type_definition_, yy_action_46)
    _ => Error
  }
}

fn yy_state_892(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_list_of_type_definition_, yy_action_45)
}

fn yy_state_893(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_134)
    NT_ident => Shift(yy_state_696)
    NT_type_name => Shift(yy_state_894)
    _ => Error
  }
}

fn yy_state_894(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_supertype_clause => Shift(yy_state_895)
    T_COLON => Shift(yy_state_896)
    NT_option_supertype_clause_ => Shift(yy_state_898)
    T_EQUAL => Reduce(0, NT_option_supertype_clause_, yy_action_44)
    _ => Error
  }
}

fn yy_state_895(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_option_supertype_clause_, yy_action_43)
}

fn yy_state_896(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_134)
    NT_ident => Shift(yy_state_696)
    NT_type_name => Shift(yy_state_897)
    _ => Error
  }
}

fn yy_state_897(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_supertype_clause, yy_action_42)
}

fn yy_state_898(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EQUAL => Shift(yy_state_899)
    _ => Error
  }
}

fn yy_state_899(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_OPEN => Shift(yy_state_900)
    NT_boption_OPEN_ => Shift(yy_state_901)
    T_LBRACE | T_LBRACKET | T_FN | T_CONT | T_DESCRIPTOR | T_DESCRIBES => Reduce(0, NT_boption_OPEN_, yy_action_41)
    _ => Error
  }
}

fn yy_state_900(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_boption_OPEN_, yy_action_40)
}

fn yy_state_901(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FN => Shift(yy_state_902)
    T_DESCRIPTOR => Shift(yy_state_908)
    T_DESCRIBES => Shift(yy_state_910)
    NT_describes_clause => Shift(yy_state_912)
    T_CONT => Shift(yy_state_916)
    NT_arraytype => Shift(yy_state_918)
    NT_function_type_definition => Shift(yy_state_919)
    NT_structtype => Shift(yy_state_920)
    T_LBRACKET => Shift(yy_state_921)
    T_LBRACE => Shift(yy_state_929)
    NT_descriptor_clause => Shift(yy_state_947)
    NT_composite_type => Shift(yy_state_950)
    _ => Error
  }
}

fn yy_state_902(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_903)
    NT_function_type_TYPE_ => Shift(yy_state_907)
    _ => Error
  }
}

fn yy_state_903(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AMPERSAND => Shift(yy_state_201)
    NT_reference_type => Shift(yy_state_355)
    NT_function_parameter => Shift(yy_state_559)
    NT_value_type => Shift(yy_state_562)
    NT_ident => Shift(yy_state_563)
    T_IDENT => Shift(yy_state_566)
    NT_non_empty_sep_trailing_COMMA_function_parameter_ => Shift(yy_state_570)
    NT_sep_trailing_COMMA_function_parameter_ => Shift(yy_state_571)
    NT_parameter_list => Shift(yy_state_904)
    T_RPAREN => Reduce(0, NT_sep_trailing_COMMA_function_parameter_, yy_action_226)
    _ => Error
  }
}

fn yy_state_904(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_905)
    _ => Error
  }
}

fn yy_state_905(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_ARROW => Shift(yy_state_465)
    NT_result_arrow => Shift(yy_state_906)
    T_SEMI => Reduce(3, NT_function_type_TYPE_, yy_action_38)
    _ => Error
  }
}

fn yy_state_906(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_function_type_TYPE_, yy_action_36)
}

fn yy_state_907(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_function_type_definition, yy_action_35)
}

fn yy_state_908(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_134)
    NT_ident => Shift(yy_state_696)
    NT_type_name => Shift(yy_state_909)
    _ => Error
  }
}

fn yy_state_909(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_descriptor_clause, yy_action_34)
}

fn yy_state_910(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_134)
    NT_ident => Shift(yy_state_696)
    NT_type_name => Shift(yy_state_911)
    _ => Error
  }
}

fn yy_state_911(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_describes_clause, yy_action_33)
}

fn yy_state_912(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FN => Shift(yy_state_902)
    T_DESCRIPTOR => Shift(yy_state_908)
    NT_descriptor_clause => Shift(yy_state_913)
    T_CONT => Shift(yy_state_916)
    NT_arraytype => Shift(yy_state_918)
    NT_function_type_definition => Shift(yy_state_919)
    NT_structtype => Shift(yy_state_920)
    T_LBRACKET => Shift(yy_state_921)
    T_LBRACE => Shift(yy_state_929)
    NT_composite_type => Shift(yy_state_945)
    _ => Error
  }
}

fn yy_state_913(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FN => Shift(yy_state_902)
    NT_composite_type => Shift(yy_state_914)
    T_CONT => Shift(yy_state_916)
    NT_arraytype => Shift(yy_state_918)
    NT_function_type_definition => Shift(yy_state_919)
    NT_structtype => Shift(yy_state_920)
    T_LBRACKET => Shift(yy_state_921)
    T_LBRACE => Shift(yy_state_929)
    _ => Error
  }
}

fn yy_state_914(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_915)
    _ => Error
  }
}

fn yy_state_915(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(9, NT_type_definition, yy_action_32)
}

fn yy_state_916(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_134)
    NT_ident => Shift(yy_state_696)
    NT_type_name => Shift(yy_state_917)
    _ => Error
  }
}

fn yy_state_917(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_composite_type, yy_action_31)
}

fn yy_state_918(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_composite_type, yy_action_30)
}

fn yy_state_919(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_composite_type, yy_action_29)
}

fn yy_state_920(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_composite_type, yy_action_28)
}

fn yy_state_921(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_MUT => Shift(yy_state_922)
    NT_field_type => Shift(yy_state_923)
    NT_boption_MUT_ => Shift(yy_state_925)
    T_IDENT | T_AMPERSAND => Reduce(0, NT_boption_MUT_, yy_action_27)
    _ => Error
  }
}

fn yy_state_922(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_boption_MUT_, yy_action_26)
}

fn yy_state_923(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_924)
    _ => Error
  }
}

fn yy_state_924(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_arraytype, yy_action_25)
}

fn yy_state_925(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_AMPERSAND => Shift(yy_state_201)
    NT_storage_type => Shift(yy_state_926)
    NT_reference_type => Shift(yy_state_927)
    T_IDENT => Shift(yy_state_928)
    _ => Error
  }
}

fn yy_state_926(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_field_type, yy_action_24)
}

fn yy_state_927(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_storage_type, yy_action_23)
}

fn yy_state_928(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_storage_type, yy_action_22)
}

fn yy_state_929(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_134)
    NT_ident => Shift(yy_state_580)
    NT_structure_type_field => Shift(yy_state_930)
    NT_field_name => Shift(yy_state_933)
    NT_non_empty_sep_trailing_COMMA_structure_type_field_ => Shift(yy_state_936)
    NT_structure_type => Shift(yy_state_937)
    T_DOTDOT => Shift(yy_state_939)
    NT_sep_trailing_COMMA_structure_type_field_ => Shift(yy_state_943)
    T_RBRACE => Reduce(0, NT_sep_trailing_COMMA_structure_type_field_, yy_action_21)
    _ => Error
  }
}

fn yy_state_930(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_931)
    T_RBRACE => Reduce(1, NT_non_empty_sep_trailing_COMMA_structure_type_field_, yy_action_20)
    _ => Error
  }
}

fn yy_state_931(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_134)
    NT_ident => Shift(yy_state_580)
    NT_structure_type_field => Shift(yy_state_930)
    NT_non_empty_sep_trailing_COMMA_structure_type_field_ => Shift(yy_state_932)
    NT_field_name => Shift(yy_state_933)
    T_RBRACE => Reduce(2, NT_non_empty_sep_trailing_COMMA_structure_type_field_, yy_action_19)
    _ => Error
  }
}

fn yy_state_932(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_non_empty_sep_trailing_COMMA_structure_type_field_, yy_action_18)
}

fn yy_state_933(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COLON => Shift(yy_state_934)
    _ => Error
  }
}

fn yy_state_934(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_MUT => Shift(yy_state_922)
    NT_boption_MUT_ => Shift(yy_state_925)
    NT_field_type => Shift(yy_state_935)
    T_IDENT | T_AMPERSAND => Reduce(0, NT_boption_MUT_, yy_action_27)
    _ => Error
  }
}

fn yy_state_935(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_structure_type_field, yy_action_17)
}

fn yy_state_936(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_sep_trailing_COMMA_structure_type_field_, yy_action_16)
}

fn yy_state_937(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_938)
    _ => Error
  }
}

fn yy_state_938(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_structtype, yy_action_15)
}

fn yy_state_939(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_COMMA => Shift(yy_state_940)
    T_RBRACE => Shift(yy_state_944)
    _ => Error
  }
}

fn yy_state_940(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_134)
    NT_ident => Shift(yy_state_580)
    NT_structure_type_field => Shift(yy_state_930)
    NT_field_name => Shift(yy_state_933)
    NT_non_empty_sep_trailing_COMMA_structure_type_field_ => Shift(yy_state_936)
    NT_structure_type => Shift(yy_state_941)
    NT_sep_trailing_COMMA_structure_type_field_ => Shift(yy_state_943)
    T_RBRACE => Reduce(0, NT_sep_trailing_COMMA_structure_type_field_, yy_action_21)
    _ => Error
  }
}

fn yy_state_941(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_942)
    _ => Error
  }
}

fn yy_state_942(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_structtype, yy_action_14)
}

fn yy_state_943(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_structure_type, yy_action_13)
}

fn yy_state_944(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_structtype, yy_action_12)
}

fn yy_state_945(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_946)
    _ => Error
  }
}

fn yy_state_946(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(8, NT_type_definition, yy_action_10)
}

fn yy_state_947(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_FN => Shift(yy_state_902)
    T_CONT => Shift(yy_state_916)
    NT_arraytype => Shift(yy_state_918)
    NT_function_type_definition => Shift(yy_state_919)
    NT_structtype => Shift(yy_state_920)
    T_LBRACKET => Shift(yy_state_921)
    T_LBRACE => Shift(yy_state_929)
    NT_composite_type => Shift(yy_state_948)
    _ => Error
  }
}

fn yy_state_948(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_949)
    _ => Error
  }
}

fn yy_state_949(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(8, NT_type_definition, yy_action_8)
}

fn yy_state_950(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_951)
    _ => Error
  }
}

fn yy_state_951(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(7, NT_type_definition, yy_action_5)
}

fn yy_state_952(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_953)
    _ => Error
  }
}

fn yy_state_953(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_rectype, yy_action_4)
}

fn yy_state_954(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACE => Shift(yy_state_955)
    _ => Error
  }
}

fn yy_state_955(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_braced_fields, yy_action_3)
}

fn yy_state_956(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(5, NT_module_field, yy_action_2)
}

fn yy_state_957(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LPAREN => Shift(yy_state_958)
    _ => Error
  }
}

fn yy_state_958(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_134)
    NT_ident => Shift(yy_state_415)
    NT_condition => Shift(yy_state_959)
    _ => Error
  }
}

fn yy_state_959(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RPAREN => Shift(yy_state_960)
    _ => Error
  }
}

fn yy_state_960(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_RBRACKET => Shift(yy_state_961)
    _ => Error
  }
}

fn yy_state_961(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_883)
    NT_braced_fields => Shift(yy_state_962)
    _ => Error
  }
}

fn yy_state_962(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(8, NT_module_field, yy_action_1)
}

fn yy_state_963(_lookahead : YYSymbol) -> YYDecision {
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

pub fn parse(tokens : Array[(Token, Position, Position)], initial_pos? : Position) -> @ast.LocModule raise ParseError {
  yy_parse(
    tokens,
    yy_state_0,
    (it) => {
      guard it is YYObj__ast_LocModule(result)
      result
    },
    initial_pos?,
  )
}

fn _get_symbol_start_pos(args : ArrayView[(YYObj, Position, Position)], last_pos : Position) -> Position {
  if args.length() == 0 {
    last_pos
  } else {
    for i = 0; i < args.length(); i = i + 1 {
      let (_, start_pos, end_pos) = args[i]
      if start_pos == end_pos {
        continue
      }
      return start_pos
    }
    args[args.length() - 1].2
  }
}
