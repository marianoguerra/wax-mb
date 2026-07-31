#!/usr/bin/env bash
# Restore the reference SOURCE checkout at the commit recorded in
# tools/reference.json, as a shallow clone in wax/.
#
# Two pins have to agree: the binary this project tests against
# (reference.json:sha256 / upstream_commit) and the sources it is ported from
# (reference.json:ported_from_commit). Version skew between them is silent and
# destructive -- it already bit us once, when the npm binary turned out to be
# 328 commits behind the checkout -- so both live in one file and both are
# restored by a script rather than by hand.
#
# wax/ is a READ-ONLY reference: corpus source for `waxdiff collect`, and the
# OCaml being ported. It is deliberately NOT a build input. test/corpus/ and
# test/golden/ are committed so the differential suite runs hermetically, with
# neither this checkout nor the reference binary present. Do not let CI grow a
# dependency on it.
set -euo pipefail

cd "$(dirname "$0")/.."

json() { python3 -c "import json;print(json.load(open('tools/reference.json'))['$1'])"; }

REPO=$(json repo)
COMMIT=$(json ported_from_commit)
DEST=wax

if [ -d "$DEST/.git" ]; then
  have=$(git -C "$DEST" rev-parse HEAD)
  if [ "$have" = "$COMMIT" ]; then
    echo "reference source: $DEST already at $COMMIT"
    exit 0
  fi
  echo "reference source: $DEST is at $have, want $COMMIT" >&2
  echo "  refusing to touch an existing checkout; move it aside and re-run." >&2
  exit 1
fi

echo "reference source: cloning $REPO at $COMMIT into $DEST"
# A shallow, single-commit fetch: the full history drags in vendor/,
# tree-sitter-wax/ and ~1800 test files across every revision, and nothing here
# needs history -- only this one tree.
mkdir -p "$DEST"
git -C "$DEST" init -q
git -C "$DEST" remote add origin "https://github.com/$REPO.git"
git -C "$DEST" fetch -q --depth 1 origin "$COMMIT"
git -C "$DEST" checkout -q FETCH_HEAD

echo "reference source: $DEST at $(git -C "$DEST" rev-parse HEAD)"
