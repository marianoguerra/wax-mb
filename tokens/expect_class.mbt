// Token classes for the `Expecting …` list.
//
// Ported from the `[class …]` sections of the reference's
// src/lib-wax/parser_messages.config. A state whose continuation set is "a
// closer or any operator" would otherwise enumerate 27 operators; collapsing
// them to one label is what makes such a message readable.
//
// The collapse fires only when at least TWO members of the class are legal --
// see `expecting_message`, which owns that rule. Rendering a lone legal
// operator as "an operator" would wrongly suggest the others are legal too.

///|
/// The class label this kind collapses into, if any.
///
/// A kind in no class keeps its own spelling from `to_expect_string`.
pub fn TokenKind::expect_class(self : Self) -> String? {
  match self {
    TK_PLUS
    | TK_MINUS
    | TK_STAR
    | TK_SLASH
    | TK_SLASHS
    | TK_SLASHU
    | TK_PERCENTS
    | TK_PERCENTU
    | TK_AMPERSAND
    | TK_PIPE
    | TK_CARET
    | TK_SHL
    | TK_SHRS
    | TK_SHRU
    | TK_PLUSEQUAL
    | TK_MINUSEQUAL
    | TK_STAREQUAL
    | TK_SLASHEQUAL
    | TK_SLASHSEQUAL
    | TK_SLASHUEQUAL
    | TK_PERCENTSEQUAL
    | TK_PERCENTUEQUAL
    | TK_AMPERSANDEQUAL
    | TK_PIPEEQUAL
    | TK_CARETEQUAL
    | TK_SHLEQUAL
    | TK_SHRSEQUAL
    | TK_SHRUEQUAL => Some("an operator")
    TK_EQUALEQUAL
    | TK_BANGEQUAL
    | TK_LT
    | TK_LTS
    | TK_LTU
    | TK_LE
    | TK_LES
    | TK_LEU
    | TK_GT
    | TK_GTS
    | TK_GTU
    | TK_GE
    | TK_GES
    | TK_GEU => Some("a comparison operator")
    _ => None
  }
}
