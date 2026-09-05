// Was: shrubbery notation for Wax.
//
// A second reader for the same language, and nothing else. Where the Wax
// front end has a lexer, a token table and a generated LR parser, this has
// `marianoguerra/shrubbery` and a mapping: grouping is settled before this
// module runs, and what is left is meaning.
name = "marianoguerra/was"

version = "0.1.0"

import {
  "marianoguerra/error-report@0.1.0",
  "marianoguerra/shrubbery@0.1.0",
  "marianoguerra/wax@0.2.1",
}

readme = "README.md"

repository = "https://github.com/marianoguerra/wax-mb"

license = "Apache-2.0"

keywords = [ "was", "wax", "webassembly", "wasm", "shrubbery", "parser" ]

description = "Was: Wax in shrubbery notation -- a reader that produces the Wax AST"
