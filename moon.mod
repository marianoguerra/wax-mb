// The DEVELOPMENT module. Never published; it exists so that the differential
// harness, the corpus tests and the porting tools can depend on the two
// published modules the way an outside consumer would -- through their public
// API only, which is what keeps that API honest.
//
// It sits at the repository root rather than in a directory of its own so that
// `test/corpus/`, `test/golden/` and `tools/` keep the paths the justfile, the
// Python harness and AGENTS.md all use.
//
// "Never published" is a rule, not a mechanism: `moon.mod` has no `private` or
// `publish = false`, so a bare `moon publish` HERE uploads the corpus, the
// porting tools and the alternative layout engine under this name. It fails
// today only because `marianoguerra/wax` is not on the registry for the
// extracted copy to resolve -- an accident that stops protecting anything the
// moment `wax` is published. Always `moon -C lib` / `moon -C cli`, or better,
// `just publish-dry` and `just publish`, which cannot address this module.
//
// The two missing manifest fields below are deliberate. `moon publish` warns
// that `readme` and `repository` are unset; filling them in would quiet the one
// signal that says which module is being packaged.
name = "marianoguerra/wax-dev"

version = "0.0.0"

import {
  "marianoguerra/wax@0.2.1",
  "moonbitlang/x@0.4.47",
  "marianoguerra/pretty-fast-pretty-printer@0.2.1",
}

license = "Apache-2.0"

description = "Development harness for wax-mb: the differential suite, the corpus tools, and the alternative layout engine"
