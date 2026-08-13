///|
/// A token with its start and end position — the unit the lexer produces and
/// the parser consumes.
///
/// MoonYacc's `array` input mode expects exactly this shape, so the lexer's
/// output feeds the generated parser with no adaptation.
pub type Triple = (Token, @basic.Position, @basic.Position)

///|
pub type Triples = Array[Triple]
