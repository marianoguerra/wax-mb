#!/usr/bin/env bash
# Report what has changed upstream in the vendored sources since the pin in
# tools/vendor.json.
#
# This does NOT restore anything. lib/wasm/bin/ is a fork, not a copy -- re-spined
# onto wasm_types, with the silent encoder fallbacks removed and wax's custom
# sections added -- so overwriting it with upstream would throw all of that
# away. What is worth automating is the question a fork actually has to keep
# asking: did upstream change, and is the change one we want?
#
# With no arguments it verifies the pin (every file still hashes to what
# vendor.json records). With --check-upstream it fetches the same paths at the
# repository's HEAD and diffs them against the pinned revision, which is the
# review artifact for moving the pin.
set -euo pipefail

cd "$(dirname "$0")/.."

PIN=tools/vendor.json
ENTRY=${VENDOR_ENTRY:-wasm_core}

json() {
  python3 -c "import json,sys;d=json.load(open('$PIN'))['$ENTRY'];print(d$1)"
}

REPO=$(json "['repo']")
COMMIT=$(json "['commit']")
SUBDIR=$(json "['subdir']")
VERSION=$(json "['version']")
FILES=$(json "['files']" | python3 -c "import ast,sys;print(' '.join(ast.literal_eval(sys.stdin.read())))")

raw() { curl -fsSL "https://raw.githubusercontent.com/$REPO/$1/$SUBDIR/$2"; }

echo "vendor: $ENTRY = $REPO@$COMMIT ($SUBDIR, version $VERSION)"

status=0
for f in $FILES; do
  want=$(json "['files']['$f']")
  got=$(raw "$COMMIT" "$f" | sha256sum | cut -d' ' -f1)
  if [ "$want" != "$got" ]; then
    echo "  MISMATCH $f" >&2
    echo "    pinned $want" >&2
    echo "    fetched $got" >&2
    echo "    the pinned commit does not serve what vendor.json records." >&2
    status=1
  else
    echo "  ok  $f"
  fi
done

if [ "${1:-}" != "--check-upstream" ]; then
  exit $status
fi

head=$(curl -fsSL "https://api.github.com/repos/$REPO/commits?path=$SUBDIR&per_page=1" |
  python3 -c "import json,sys;print(json.load(sys.stdin)[0]['sha'])")

if [ "$head" = "$COMMIT" ]; then
  echo "upstream: unchanged since the pin"
  exit $status
fi

echo "upstream: $SUBDIR last changed at $head (pin is $COMMIT)"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
for f in $FILES; do
  raw "$COMMIT" "$f" >"$tmp/pinned" || continue
  raw "$head" "$f" >"$tmp/head" || { echo "  $f: gone upstream"; continue; }
  if ! diff -q "$tmp/pinned" "$tmp/head" >/dev/null; then
    echo
    echo "=== $f ==="
    diff -u --label "pinned/$f" --label "head/$f" "$tmp/pinned" "$tmp/head" || true
  fi
done
exit $status
