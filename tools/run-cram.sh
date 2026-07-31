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
bin="$root/_build/native/debug/build/cmd/wax-mb/wax-mb.exe"
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

pass=0; fail=0; failed=()
for t in "$root"/test/cram/*.t; do
  [ -d "$t" ] || continue
  name="$(basename "$t")"
  sandbox="$work/$name"
  cp -r "$t" "$sandbox"
  if "$cram" test --cram-compat -w "$sandbox" "$sandbox/run.t" \
       >"$work/$name.log" 2>&1; then
    pass=$((pass + 1))
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

echo "cram: $pass passed, $fail failed"
if [ "$fail" -gt 0 ]; then
  printf '  %s\n' "${failed[@]}"
  if [ "${1:-}" = "-v" ]; then
    for n in "${failed[@]}"; do
      echo "=== $n"; sed -n '1,40p' "$work/$n.log"
    done
  fi
  exit 1
fi
