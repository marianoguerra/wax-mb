///|
pub suberror ScriptError {
  ScriptError(String)
}

///|
pub impl Show for ScriptError with fn output(self, logger) {
  let ScriptError(message) = self
  logger.write_string(message)
}

///|
priv struct Term {
  expr : Expr
  span : @w.Span
}

///|
priv enum Expr {
  Nil
  Boolean(Bool)
  Integer(String)
  Float(String)
  Text(String, Bool)
  Name(String)
  Vector(Array[Term])
  MapLit(Array[(Term, Term)])
  Call(Term, Array[Term])
  Field(Term, String)
  Binary(String, Term, Term)
  Lambda(Array[String], Array[Term])
  Bind(Array[String], Term)
  If(Term, Array[Term], Array[Term])
  Match(Term, Array[(Term, Array[Term])])
}

///|
priv struct Function {
  name : String
  params : Array[String]
  body : Array[Term]
  exported : Bool
  span : @w.Span
}

///|
priv struct Record {
  name : String
  fields : Array[(String, String)]
}

///|
priv struct SourceUnit {
  name : String
  imports : Array[String]
  functions : Array[Function]
  records : Array[Record]
  requirements : Array[(String, String)]
  source : String
}

///|
fn[X] problem(message : String, span : @w.Span) -> X raise ScriptError {
  raise ScriptError("\{message} at offset \{span.start}")
}
