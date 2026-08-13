// ANSI colouring: the semantic style categories, the two source palettes, and
// the rule deciding whether to emit escape codes at all.

///|
/// Whether to emit ANSI colour.
pub(all) enum Flag {
  Never
  Always
  /// Decide from the environment and whether the destination is a terminal.
  Auto
} derive(Eq, Debug)

///|
/// A semantic category for syntax highlighting.
///
/// Semantic rather than literal -- a `Type` is whatever the active palette says
/// a type looks like, which is why Wax types come out cyan and WAT types red
/// from the very same printer.
pub(all) enum Style {
  /// `fn`, `let`, `if`.
  Keyword
  /// A wasm instruction, `i32.add`.
  Instruction
  /// `offset=4`, `#[export]`.
  Attribute
  /// `i32`, `&func`.
  Type
  Identifier
  /// A numeric or boolean literal.
  Constant
  Str
  /// `+`, `=`, `!`.
  Operator
  /// `(@custom)`.
  Annotation
  Comment
  /// `{`, `(`, `:`, `;`.
  Punctuation
} derive(Eq, Debug)

///|
/// The ANSI escape code to introduce each style, plus the one that ends it.
///
/// An empty string means "this style is not coloured", which is how `no_color`
/// disables everything and how a palette opts one category out.
pub(all) struct Theme {
  keyword : String
  instruction : String
  attribute : String
  type_ : String
  identifier : String
  constant : String
  str : String
  operator : String
  annotation : String
  comment : String
  punctuation : String
  reset : String
}

///|
pub fn Theme::escape_sequence(self : Theme, style : Style) -> String {
  match style {
    Keyword => self.keyword
    Instruction => self.instruction
    Attribute => self.attribute
    Type => self.type_
    Identifier => self.identifier
    Constant => self.constant
    Str => self.str
    Operator => self.operator
    Annotation => self.annotation
    Comment => self.comment
    Punctuation => self.punctuation
  }
}

///|
/// Raw ANSI codes.
pub let reset : String = "\u{1b}[0m"

///|
pub let bold : String = "\u{1b}[1m"

///|
pub let red : String = "\u{1b}[31m"

///|
pub let high_red : String = "\u{1b}[91m"

///|
pub let green : String = "\u{1b}[32m"

///|
pub let yellow : String = "\u{1b}[33m"

///|
pub let high_yellow : String = "\u{1b}[93m"

///|
pub let blue : String = "\u{1b}[34m"

///|
pub let magenta : String = "\u{1b}[35m"

///|
pub let cyan : String = "\u{1b}[36m"

///|
pub let white : String = "\u{1b}[37m"

///|
pub let grey : String = "\u{1b}[90m"

///|
/// The Wax source palette.
///
/// One palette per surface language, each the single source of truth: the
/// language's own printer renders whole modules with it, and a diagnostic
/// colours an embedded AST fragment with it. So a message about Wax code
/// colours its types the same way Wax source does.
pub let wax_theme : Theme = {
  keyword: bold + magenta,
  operator: bold + white,
  annotation: blue,
  attribute: magenta,
  type_: cyan,
  identifier: yellow,
  constant: bold + blue,
  str: green,
  comment: grey,
  punctuation: white,
  instruction: "",
  reset,
}

///|
/// The WebAssembly-text palette. Types are red here against Wax's cyan.
pub let wat_theme : Theme = {
  keyword: bold + magenta,
  instruction: white,
  attribute: magenta,
  type_: red,
  identifier: yellow,
  constant: bold + blue,
  str: green,
  annotation: blue,
  comment: grey,
  punctuation: cyan,
  operator: "",
  reset,
}

///|
/// A palette that colours nothing.
pub let no_color : Theme = {
  keyword: "",
  instruction: "",
  attribute: "",
  type_: "",
  identifier: "",
  constant: "",
  str: "",
  annotation: "",
  comment: "",
  punctuation: "",
  operator: "",
  reset: "",
}

///|
/// Whether to emit colour on a destination.
///
/// `is_tty` is passed in rather than probed here, so the decision stays
/// testable and this package needs no knowledge of file descriptors. Under
/// `Auto` colour is suppressed by NO_COLOR, by a `dumb` or absent TERM, and by
/// the destination not being a terminal -- all three, not any one.
pub fn should_use_color(color : Flag, is_tty? : Bool = false) -> Bool {
  match color {
    Never => false
    Always => true
    Auto =>
      is_tty &&
      @env.get_env_var("NO_COLOR") is None &&
      (match @env.get_env_var("TERM") {
        None | Some("dumb") => false
        _ => true
      })
  }
}
