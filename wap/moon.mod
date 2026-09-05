// Wap: a Wirth-tradition surface language that lowers to the Wax AST.
//
// It depends on `marianoguerra/wax` for the target AST, the type checker and
// the emitters, and on `marianoguerra/shrubbery` for the notation. It does NOT
// depend on `marianoguerra/wax`'s front end: a wap program never becomes wax
// source text on the way to wasm, it becomes `@ast` values directly.
name = "marianoguerra/wap"

version = "0.2.1"

import {
  "marianoguerra/error-report@0.1.0",
  "marianoguerra/shrubbery@0.1.0",
  "marianoguerra/wax@0.2.1",
}

readme = "README.md"

repository = "https://github.com/marianoguerra/wax-mb"

license = "Apache-2.0"

keywords = [ "wap", "wax", "webassembly", "wasm", "shrubbery", "compiler" ]

description = "Wap: an Oberon-level language on shrubbery notation, compiled through the Wax AST"
