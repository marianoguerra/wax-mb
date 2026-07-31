///|
using @basic {type Location, type Annotated}

///|
/// A string literal's text together with its span.
///
/// Named here rather than written inline in the grammar because the generated
/// token enum has to spell the type, and `Annotated[String, Location]` reads
/// poorly in a `%token<...>` declaration.
pub type LocString = Annotated[String, Location]
