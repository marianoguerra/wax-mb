#!/usr/bin/env bash
# Prove the modularity claim rather than asserting it.
#
# Builds a throwaway module OUTSIDE the workspace with a local path dependency
# on lib/, importing only `marianoguerra/wax/compile` and
# `marianoguerra/wax/ast/build`. Two things are checked:
#
#   1. It builds and runs, so the AST-first path works with no front end in the
#      import graph.
#   2. `syntax/parser` produced NO artifact in that build. That is the claim --
#      an embedder does not compile the 6.5k-line generated LR table -- and it
#      is the part that would rot silently if the library grew an import from a
#      lower layer up into the front end.
#
# Outside the workspace on purpose: inside it, `moon check` builds every member
# and the second check would be meaningless.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(dirname "$here")"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/embed"

cat > "$work/moon.mod" <<EOF
name = "smoke/embed"
version = "0.0.0"
import { "marianoguerra/wax@0.1.0" }
EOF

# A path override is what makes this test the WORKING TREE rather than whatever
# is on the registry.
cat > "$work/moon.work" <<EOF
members = [ ".", "$root/lib" ]
EOF

cat > "$work/embed/moon.pkg" <<'EOF'
import {
  "marianoguerra/wax/ast",
  "marianoguerra/wax/ast/build" @build,
  "marianoguerra/wax/basic",
  "marianoguerra/wax/compile",
  "marianoguerra/wax/wasm/types" @wasm_types,
}

pkgtype(kind: "executable")
EOF

cat > "$work/embed/main.mbt" <<'EOF'
///|
fn main raise {
  let i32_ : @wasm_types.ValType[@ast.Ident] = I32
  let m : @ast.LocModule = [
    @build.func(
      "add",
      params=[(Some("x"), i32_), (Some("y"), i32_)],
      results=[i32_],
      body=[
        @ast.no_loc_instr(
          BinOpI(
            @basic.no_loc(Add),
            @ast.no_loc_instr(Get(@build.ident("x"))),
            @ast.no_loc_instr(Get(@build.ident("y"))),
          ),
        ),
      ],
      attributes=[@build.exported()],
    ),
    @build.func("two", results=[i32_], body=[@ast.no_loc_instr(Int("2"))]),
  ]
  let session = @compile.Session::new()
  let checked = session.check(m)
  if @compile.rejected(session.reports()) {
    println("embed-smoke: the module was rejected")
    panic()
  }
  let bytes = checked.to_bytes()
  if bytes.length() <= 8 {
    println("embed-smoke: no bytes")
    panic()
  }
  println("embed-smoke: \{bytes.length()} bytes")
}
EOF

cd "$work"
moon run ./embed --target native

# The claim. `moon` writes one artifact directory per package it built, so the
# absence of the front end's is the absence of the front end.
for pkg in syntax/parser syntax/lexer syntax/tokens; do
  if find _build -type d -path "*/marianoguerra/wax/$pkg" | grep -q .; then
    echo "embed-smoke: FAIL -- $pkg was built by an AST-first consumer" >&2
    echo "  something in check/ or emit/ now reaches up into the front end." >&2
    exit 1
  fi
done
echo "embed-smoke: the parser, lexer and token table were not built"

# `fmt` IS built, and the README says so rather than pretending otherwise:
# `check` and `check/infer` reach into the formatter to spell an inferred type
# in a diagnostic, and `wasm/wat` uses `syntax/trivia` to re-delimit comments.
# Five symbols in total. Extracting them into a lower package would let an
# emit-only consumer drop the formatter as well; until someone needs that, this
# line is here so the cost is stated rather than discovered.
if find _build -type d -path "*/marianoguerra/wax/fmt" | grep -q .; then
  echo "embed-smoke: (fmt is built too -- check/ spells types through it)"
fi
