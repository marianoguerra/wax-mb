#!/usr/bin/env bash
# Run the in-scope cram tests against wax-mb.
#
# Each test is a DIRECTORY (`foo.t/`) holding `run.t` plus its fixtures, and
# the commands inside address those fixtures by bare name. dune's cram runner
# copies the directory into a sandbox and runs there; moon-cram makes a
# temporary work directory but does not populate it, so the fixtures would be
# missing. This copies each test into its own scratch directory and points
# moon-cram at it with -w.
#
# `wax` on PATH is wax-mb: the ported tests invoke the reference's own command
# name, which is the point -- they are the reference's tests, unedited.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(dirname "$here")"
bin="$root/_build/native/debug/build/marianoguerra/wax-cli/wax-mb/wax-mb.exe"
[ -x "$bin" ] || { echo "run-cram: not built; run 'moon build --target native'" >&2; exit 127; }

cram="$(command -v moon-cram || true)"
[ -n "$cram" ] || cram="$HOME/.moon/bin/moon-cram"
[ -x "$cram" ] || {
  echo "run-cram: moon-cram not found (it ships with the moon toolchain)" >&2
  exit 127
}

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin"
ln -sf "$bin" "$work/bin/wax"
export PATH="$work/bin:$PATH"

# The reference's cram suite hides the correctness lints for the whole group
# (see wax/test/cram-tests/dune), because they fire during the validation these
# tests exercise and would clutter every unrelated one. A test that is ABOUT a
# lint re-enables it with an explicit -W, which overrides this. Setting it here
# is what makes the tests runnable unedited, which is the point of having them.
export WAX_WARN="correctness=hidden"

# Tests that fail for a gap this port has not closed yet, each with the reason.
#
# Listed rather than de-scoped: the classifier decides SCOPE from what the CLI
# can be asked to do, and every one of these is in scope -- the command runs and
# the port answers, just not the same way. Naming them keeps the suite green
# where it is right and keeps the gap countable, and the check below fails BOTH
# ways: a listed test that starts passing is an error too, so the list cannot
# quietly outlive what it excuses.
#
# The lint and diagnostic entries are the cram-side view of the oracle 3
# residual; closing that closes these.
declare -A KNOWN_FAILING=(
  [become-non-function.t]="missing check"
  [block-exit-mismatch.t]="diagnostic span differs"
  [duplicate-diagnostic-chains.t]="diagnostic chain differs"
  [error-format-short.t]="usage text for an unknown --error-format differs"
  [float-literal-f32-range.t]="missing check"
  [hole-control-operand.t]="missing check"
  [hole-struct-reorder.t]="missing check"
  [new-lints-wax.t]="missing lints"
  [non-empty-stack-location.t]="diagnostic span differs"
  [redundant-mul-zero-float.t]="missing lint: redundant-operation on floats"
  [redundant-sub-self-float.t]="missing lint: redundant-operation on floats"
  [suggestions.t]="missing suggestion: redundant-annotation"
  [switch-chain-dup.t]="missing check"
  [typing-crash-recovery.t]="missing check"
  [typing-error-recovery.t]="missing check"
  [unicode-identifier.t]="caret width counts UTF-16 units, not display columns"
  [wax-duplicate-params.t]="missing check"
  [wax-operand-type-checks.t]="missing check"
)

pass=0; fail=0; known=0; failed=(); fixed=()
for t in "$root"/test/cram/*.t; do
  [ -d "$t" ] || continue
  name="$(basename "$t")"
  sandbox="$work/$name"
  cp -r "$t" "$sandbox"
  if "$cram" test --cram-compat -w "$sandbox" "$sandbox/run.t" \
       >"$work/$name.log" 2>&1; then
    if [ -n "${KNOWN_FAILING[$name]+x}" ]; then
      fixed+=("$name")
    else
      pass=$((pass + 1))
    fi
  elif [ -n "${KNOWN_FAILING[$name]+x}" ]; then
    known=$((known + 1))
  else
    fail=$((fail + 1)); failed+=("$name")
  fi
done

# An empty test/cram/ would otherwise report "0 passed, 0 failed" and exit 0 --
# a green run that tested nothing. The suite is committed, so zero means the
# checkout or the glob is wrong.
if [ $((pass + fail)) -eq 0 ]; then
  echo "run-cram: no tests found under $root/test/cram" >&2
  exit 1
fi

echo "cram: $pass passed, $fail failed, $known known-failing"
if [ ${#fixed[@]} -gt 0 ]; then
  echo "cram: listed in KNOWN_FAILING but now passing -- drop the entry:" >&2
  printf '  %s\n' "${fixed[@]}" >&2
  exit 1
fi
if [ "$fail" -gt 0 ]; then
  printf '  %s\n' "${failed[@]}"
  if [ "${1:-}" = "-v" ]; then
    for n in "${failed[@]}"; do
      echo "=== $n"; sed -n '1,40p' "$work/$n.log"
    done
  fi
  exit 1
fi
