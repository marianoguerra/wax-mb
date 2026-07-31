///|
using @basic {type Location, type Annotated}

///|
/// Note `Limits` is deliberately absent: the Wax AST stores memory and table
/// bounds inline as `(UInt64, UInt64?)?`, exactly as the reference does, and
/// the `Limits` record in wasm_types belongs to the binary form.
using @wasm_types {
  type ValType,
  type RefType,
  type StorageType,
  type FieldType,
  type AddressType,
  type Signage,
  type Cond,
  type V128,
}
