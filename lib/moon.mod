name = "marianoguerra/wax"

version = "0.3.0"

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

// Warning 79 (implicit_impl_as_method) is off by default per the MoonBit docs
// (E0079, "disabled by default starting in version 0.10.4"), but moonc
// v0.10.14 reports it, and CI's `--deny-warn` turns every derive(Eq, Debug, ...)
// on a public type into an error. Nothing here relies on promotion: the .mbti
// records none of these impls' methods as methods. Declaring them with
// `pub extend T with Trait::{...}` would make ~340 names a public promise, and
// that is an API decision, not a toolchain fix -- so the warning is turned back
// off in every module of the workspace instead.

warnings = "-implicit_impl_as_method"
