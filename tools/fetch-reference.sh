#!/usr/bin/env bash
# Restore the pinned reference `wax` binary described by tools/reference.json.
#
# The binary itself is not committed (13 MB); this script fetches it and refuses
# to install anything whose sha256 does not match the pin. The 'edge' release is
# rebuilt on every push to ocsigen/wax main, so a mismatch here is the expected
# signal that upstream moved -- not a transient error. See reference.json.
set -euo pipefail

cd "$(dirname "$0")"

json() { python3 -c "import json,sys;print(json.load(open('reference.json'))['$1'])"; }

REPO=$(json repo)
RELEASE=$(json release)
ASSET=$(json asset)
WANT_SHA=$(json sha256)
WANT_VERSION=$(json reports_version)

if [ -x "$ASSET" ] && [ "$(sha256sum "$ASSET" | cut -d' ' -f1)" = "$WANT_SHA" ]; then
  echo "reference: $ASSET already present and matches the pin"
  exit 0
fi

echo "reference: fetching $ASSET from $REPO@$RELEASE"
gh release download "$RELEASE" --repo "$REPO" --pattern "$ASSET" --clobber -D .

GOT_SHA=$(sha256sum "$ASSET" | cut -d' ' -f1)
if [ "$GOT_SHA" != "$WANT_SHA" ]; then
  cat >&2 <<EOF

reference: SHA256 MISMATCH -- upstream 'edge' has been rebuilt.

  expected  $WANT_SHA
  got       $GOT_SHA

The committed goldens in test/golden/ were produced by the expected binary, so
this build is NOT interchangeable with it. Do one of:

  * Keep the old oracle: download the binary for the pinned commit instead of
    the floating 'edge' asset.
  * Adopt the new one: confirm the front end is unaffected with
        gh api repos/$REPO/compare/\$(json ported_from_commit)...<new commit>
    then update reference.json (sha256, upstream_commit) and regenerate the
    goldens with 'waxdiff golden'. Review that diff -- it is upstream's
    behaviour change, and it is exactly what this pin exists to surface.

EOF
  rm -f "$ASSET"
  exit 1
fi

chmod +x "$ASSET"

GOT_VERSION=$("./$ASSET" --version)
if [ "$GOT_VERSION" != "$WANT_VERSION" ]; then
  echo "reference: version mismatch: expected $WANT_VERSION, got $GOT_VERSION" >&2
  exit 1
fi

echo "reference: $ASSET installed ($GOT_VERSION, sha256 ok)"
