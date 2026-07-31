///|
using @basic {type Location, type Position, type Annotated}

///|
/// Token, TokenKind and LocString are referenced by the GENERATED parser
/// (moonyacc is run with --external-tokens, so it expects them in scope here).
using @tokens {type Token, type TokenKind, type LocString}

///|
/// The Wax instantiations live in @ast; the grammar never needs the generic
/// forms, since Wax refers to types by name throughout.
using @ast {
  type Instr,
  type InstrDesc,
  type FuncType,
  type Ident,
  type Body,
  type ModuleField,
  type Attribute,
  type Attributes,
  type CompType,
  type SubType,
  type CastType,
  type Catch,
  type OnClause,
  type MatchPattern,
  type TryCatchArm,
  type ValType,
  type RefType,
  type HeapType,
  type StorageType,
  type FieldType,
}

///|
using @wasm_types {type Cond, type AddressType}
