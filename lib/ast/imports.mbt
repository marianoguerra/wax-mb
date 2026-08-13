///|
using @basic {type Location, type Annotated}

///|
/// The Wax instantiations of the shared type family.
///
/// Wax refers to types by NAME, so every one of these is at `Idx = Ident`.
/// Naming them here keeps `[Ident]` out of the ~90 AST constructors, and means
/// the binary form's instantiation (at `Idx = Int`, for the code generator)
/// will sit beside these rather than replace them.
///
/// Note `Limits` is deliberately absent: the Wax AST stores memory and table
/// bounds inline as `(UInt64, UInt64?)?`, exactly as the reference does, and
/// the `Limits` record in wasm_types belongs to the binary form.
pub type ValType = @wasm_types.ValType[Ident]

///|
pub type RefType = @wasm_types.RefType[Ident]

///|
pub type HeapType = @wasm_types.HeapType[Ident]

///|
pub type StorageType = @wasm_types.StorageType[Ident]

///|
pub type FieldType = @wasm_types.FieldType[Ident]

///|
using @wasm_types {type AddressType, type Signage, type Cond, type V128}
