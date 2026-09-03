name = "marianoguerra/wax-cli"

version = "0.2.1"

// The command-line tool, separated from the library so that `moonbitlang/x`
// (filesystem and process access) is a cost only the people who want a binary
// pay. Everything language-related is in `marianoguerra/wax`.
import {
  "marianoguerra/wax@0.2.1",
  "moonbitlang/x@0.4.47",
}

readme = "README.md"

repository = "https://github.com/marianoguerra/wax-mb"

license = "Apache-2.0"

keywords = [ "wax", "webassembly", "wasm", "cli", "formatter" ]

description = "The wax-mb command-line tool: convert, format and check Wax source"
