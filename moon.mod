// The DEVELOPMENT module. Never published; it exists so that the differential
// harness, the corpus tests and the porting tools can depend on the two
// published modules the way an outside consumer would -- through their public
// API only, which is what keeps that API honest.
//
// It sits at the repository root rather than in a directory of its own so that
// `test/corpus/`, `test/golden/` and `tools/` keep the paths the justfile, the
// Python harness and AGENTS.md all use.
name = "marianoguerra/wax-dev"

version = "0.0.0"

import {
  "marianoguerra/wax@0.1.0",
  "moonbitlang/x@0.4.47",
  "marianoguerra/pretty-fast-pretty-printer@0.2.1",
}

license = "Apache-2.0"

description = "Development harness for wax-mb: the differential suite, the corpus tools, and the alternative layout engine"
