///|
using @basic {type Location, type Annotated}

///|
/// A string literal's decoded BYTES together with its span.
///
/// Bytes rather than a String because a Wax string literal is a byte string:
/// `\xff` is one raw byte, and a data segment may hold arbitrary binary that is
/// not valid UTF-8. Named here rather than written inline in the grammar
/// because the generated token enum has to spell the type.
pub type LocString = Annotated[Bytes, Location]
