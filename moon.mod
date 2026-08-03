name = "waxmb/wax"

version = "0.0.1"

import {
  "moonbitlang/x@0.4.47",
  "moonbitlang/async@0.20.3",
  "marianoguerra/pretty-fast-pretty-printer@0.2.0",
}

readme = "README.md"

license = "Apache-2.0"

keywords = [ "wax", "webassembly", "wasm", "parser", "AST" ]

description = "A MoonBit implementation of the Wax front end (lexer, AST, parser, formatter)"

options(
  exclude: [ "test", "tools" ],
)
