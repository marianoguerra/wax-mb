name = "marianoguerra/wax"

version = "0.1.0"

// THERE IS NO `import` BLOCK HERE, and that is the point. A module's
// dependencies are fetched by every consumer whether or not it imports the
// packages that use them, so a single convenience dependency would be paid for
// by every project that only wants the type checker. The CLI's filesystem
// access lives in `marianoguerra/wax-cli` and the test harness in
// `marianoguerra/wax-dev` for exactly this reason. Keep this module on
// `moonbitlang/core` alone.

readme = "README.md"

repository = "https://github.com/marianoguerra/wax-mb"

license = "Apache-2.0"

keywords = [
  "wax",
  "webassembly",
  "wasm",
  "compiler",
  "parser",
  "formatter",
  "wat",
]

description = "The Wax language in MoonBit: parser, formatter, type checker, and wasm/wat emitters"
