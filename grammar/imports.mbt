///|
using @basic {type Location, type Position, type Annotated}

///|
/// Token, TokenKind and LocString are referenced by the GENERATED parser
/// (moonyacc is run with --external-tokens, so it expects them in scope here).
using @tokens {type Token, type TokenKind, type LocString}

///|
using @ast {
  type Instr,
  type InstrDesc,
  type FuncType,
  type Ident,
  type Body,
  type ModuleField,
  type Attributes,
}

///|
using @wasm_types {type Cond}
