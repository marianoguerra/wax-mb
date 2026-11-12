// The wap abstract syntax tree.
//
// Two properties are load-bearing and should survive any edit here.
//
// FIRST, everything is public and constructible. A project that generates wap
// -- a DSL compiler, a schema-to-wasm tool -- builds these values directly and
// never produces source text. That is why every type is `pub(all)` and why the
// constructors in `build.mbt` default their spans: string codegen is not a
// supported way to use this compiler, it is the thing this AST exists to avoid.
//
// SECOND, a wap program is made of expressions, not statements. Blocks, loops
// and conditionals are expressions whose value is the value of the last
// expression in them, exactly as in Wax, so the lowering is a translation and
// not a restructuring.

///|
/// A source span, as byte offsets into the file the node came from.
///
/// This is `marianoguerra/error-report`'s span, so a wap diagnostic and a
/// diagnostic from any other library that uses error-report render through the
/// same code. `nowhere` is the span a generated node carries; the lowering
/// gives those fresh synthetic locations so that two generated bindings never
/// collide (see `lower`, and the `AmbiguousBinding` note in AGENTS.md).
pub using @er {type Span}

///|
/// The span of a node that was never written down.
pub let nowhere : Span = { start: -1, len: 0, }

///|
/// True when a span points at real source text.
pub fn has_source(s : Span) -> Bool {
  s.start >= 0
}

// ---------------------------------------------------------------- types

///|
/// A wap type.
///
/// The signed/unsigned distinction lives here rather than on the operators,
/// which is the whole reason wap can spell integer comparison `<` where was has
/// to spell it `<` or `<$`. `U32` and `I32` are both wasm i32; they differ only
/// in which instruction an operator on them selects.
#derive(Eq, @debug.Debug)
pub(all) enum Type {
  I8
  I16
  I32
  I64
  U8
  U16
  U32
  U64
  F32
  F64
  Bool
  Char
  /// A reference to a declared type: a record, an array alias, an enum, a set.
  Named(String)
  /// `t?` -- a nullable reference.
  Nullable(Type)
  /// `[t]` written inline rather than through an alias.
  ArrayOf(Type)
  /// `(a, b)` -- flattened at every use, never boxed.
  Tuple(Array[Type])
  /// `fn(a, b) -> c`
  Func(params~ : Array[Type], results~ : Array[Type])
  /// `any` -- the top of the reference hierarchy.
  Any
  /// `eq` -- the part of it that supports identity comparison.
  Eq
  /// `i31` -- a boxed 31-bit integer.
  I31
}

///|
/// What a `type` declaration introduces.
#derive(Eq, @debug.Debug)
pub(all) enum TypeDef {
  /// `{ x :: i32, y :: mut f64 }`, optionally extending another record.
  Record(parent~ : String?, fields~ : Array[Field])
  /// `enum { red, green = 4, blue }`
  Enum(Array[(String, Int32?)])
  /// `set[color]` -- a bitmask over an enumeration.
  SetOf(String)
  /// `1 .. 31` -- an integer with known bounds.
  Subrange(low~ : Int32, high~ : Int32)
  /// `[u8]`, `fn(i32) -> i32`, or any other type expression.
  Alias(Type)
}

///|
/// One field of a record.
#derive(Eq, @debug.Debug)
pub(all) struct Field {
  name : String
  mut_ : Bool
  typ : Type
  span : Span
}

// ---------------------------------------------------------------- operators

///|
/// A binary operator, before signedness is resolved.
///
/// `Div`, `Rem`, `Shr` and the four comparisons become signed or unsigned wasm
/// instructions according to the type of their operands; the parser never has
/// to decide, and there is no wap spelling that lets it.
#derive(Eq, @debug.Debug)
pub(all) enum BinOp {
  Add
  Sub
  Mul
  Div
  Rem
  Shl
  Shr
  BitAnd
  BitOr
  BitXor
  Eq
  Ne
  Lt
  Gt
  Le
  Ge
}

///|
/// A prefix operator.
#derive(Eq, @debug.Debug)
pub(all) enum UnOp {
  Neg
  Not
}

///|
/// How an assignment combines with the old value.
#derive(Eq, @debug.Debug)
pub(all) enum AssignOp {
  Set
  OpSet(BinOp)
}

// ---------------------------------------------------------------- patterns

///|
/// A `match` arm's pattern.
#derive(Eq, @debug.Debug)
pub(all) enum Pattern {
  /// `c :: circle` -- a type test that binds.
  PType(name~ : String?, typ~ : Type)
  /// `null`
  PNull
  /// `7`
  PInt(String)
  /// `2 .. 6`
  PRange(low~ : String, high~ : String)
  /// `{1, 7}` -- a set of labels, which is what a case label list has always been.
  PSet(Array[Pattern])
  /// `_`
  PWild
}

// ---------------------------------------------------------------- expressions

///|
/// An expression with the span it was written at.
#derive(Eq, @debug.Debug)
pub(all) struct Node {
  it : Expr
  span : Span
}

///|
/// One arm of a `match`.
#derive(Eq, @debug.Debug)
pub(all) struct Arm {
  pat : Pattern
  body : Array[Node]
  span : Span
}

///|
/// A `let`/`var` binding target.
#derive(Eq, @debug.Debug)
pub(all) struct Binder {
  name : String
  typ : Type?
  span : Span
}

///|
/// Everything a wap body can contain.
#derive(Eq, @debug.Debug)
pub(all) enum Expr {
  // -- literals -----------------------------------------------------------
  /// An integer literal, kept as written. Parsing it here would lose the
  /// flexible-literal typing the Wax checker does later.
  Int(String)
  Float(String)
  BoolLit(Bool)
  CharLit(Char)
  /// A string literal, lowered to an `[u8]` array.
  StrLit(String)
  Null
  /// `(a, b)` -- flattened at the point of use.
  TupleLit(Array[Node])
  /// `{red, blue}` in a set-typed position.
  SetLit(Array[Node])

  // -- names --------------------------------------------------------------
  Var(String)
  Field(Node, String)
  Index(Node, Node)

  // -- construction -------------------------------------------------------
  /// `point{x: 1, y}` -- a field with no value is punned.
  RecordLit(typ~ : String?, fields~ : Array[(String, Node?)])
  /// `point{..}`
  RecordDefault(typ~ : String?)
  /// `ints[1, 2, 3]`
  ArrayLit(typ~ : String?, items~ : Array[Node])
  /// `bytes[0 ** n]`
  ArrayRepeat(typ~ : String?, value~ : Node, count~ : Node)

  // -- application --------------------------------------------------------
  Call(Node, Array[Node])
  /// An explicit proper tail call, primarily for AST-first functional compilers.
  TailCall(Node, Array[Node])
  /// `xs.len()`, `p.area()` -- resolved to a field access plus call, an
  /// intrinsic, or a method, by the lowering.
  MethodCall(Node, String, Array[Node])

  // -- operators ----------------------------------------------------------
  Bin(BinOp, Node, Node)
  Un(UnOp, Node)
  /// `&&` and `||`, which short-circuit and therefore become `if`.
  AndAlso(Node, Node)
  OrElse(Node, Node)
  /// `x in s` -- set membership.
  InSet(Node, Node)
  /// `e as t`
  Cast(Node, Type)
  /// `e is t`
  Test(Node, Type)
  /// `e!`
  NonNull(Node)

  // -- binding and assignment ---------------------------------------------
  /// `let (q, r) = e` / `var x :: i32 = e`
  Bind(binders~ : Array[Binder], value~ : Node?, mutable~ : Bool)
  /// `x = e`, `x += e`, `(x, y) = (y, x)`
  Assign(targets~ : Array[Node], op~ : AssignOp, value~ : Node)

  // -- control ------------------------------------------------------------
  /// A sequence whose value is its last element.
  Block(Array[Node])
  /// `if c | a | b` and the multi-arm `if | c: a | d: b | _: c`. The final
  /// arm may have no condition, and is then the else.
  If(arms~ : Array[(Node?, Array[Node])], typ~ : Type?)
  While(label~ : String?, cond~ : Node, step~ : Node?, body~ : Array[Node])
  /// `for i in lo .. hi by n:`
  ForRange(
    label~ : String?,
    var_~ : String,
    from~ : Node,
    to~ : Node,
    inclusive~ : Bool,
    by~ : Node?,
    body~ : Array[Node]
  )
  /// `for x in xs:`
  ForIn(label~ : String?, var_~ : String, seq~ : Node, body~ : Array[Node])
  Loop(label~ : String?, body~ : Array[Node])
  Break(String?)
  Continue(String?)
  Return(Node?)
  Match(scrutinee~ : Node, arms~ : Array[Arm], typ~ : Type?)
  Unreachable
  Nop
  /// `_ = e` -- evaluate and drop.
  Drop(Node)
}

// ---------------------------------------------------------------- declarations

///|
/// A function or method, defined or merely declared.
#derive(Eq, @debug.Debug)
pub(all) struct FnDecl {
  name : String
  /// Set when the function came from an `impl` block: the receiver's type.
  receiver : String?
  params : Array[Param]
  results : Array[Type]
  /// `None` for a declaration with no body, which is how an import is written.
  body : Array[Node]?
  export_name : String?
  import_name : String?
  is_start : Bool
  /// Whether another module may name this one. Wasm exports are a different
  /// thing entirely: `export "n"` is an ABI, `pub` is visibility.
  is_pub : Bool
  span : Span
}

///|
/// One parameter.
#derive(Eq, @debug.Debug)
pub(all) struct Param {
  name : String
  typ : Type
  span : Span
}

///|
/// A global constant.
#derive(Eq, @debug.Debug)
pub(all) struct ConstDecl {
  name : String
  typ : Type?
  value : Node
  export_name : String?
  import_name : String?
  is_pub : Bool
  span : Span
}

///|
/// A top-level declaration.
#derive(Eq, @debug.Debug)
pub(all) enum Decl {
  /// `module vector`
  ModuleName(String)
  /// `import collections.hashing`
  Import(Array[String])
  /// `import was "kernels.was": ...` -- signatures for functions defined in
  /// was and compiled alongside. Nothing is generated for these; they are a
  /// type ascription for a name the linker will already have.
  ImportWas(file~ : String, funcs~ : Array[FnDecl], consts~ : Array[ConstDecl])
  /// `import "env": ...` -- a wasm import.
  ImportHost(
    module_~ : String,
    funcs~ : Array[FnDecl],
    consts~ : Array[ConstDecl]
  )
  Const(ConstDecl)
  TypeD(name~ : String, def~ : TypeDef, is_pub~ : Bool, span~ : Span)
  Fn(FnDecl)
  /// `impl circle: ...`
  Impl(typ~ : String, methods~ : Array[FnDecl], span~ : Span)
}

///|
/// A whole wap compilation unit.
#derive(Eq, @debug.Debug)
pub(all) struct Module {
  name : String
  decls : Array[Decl]
}
