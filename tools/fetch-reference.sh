#!/usr/bin/env bash
# Restore the pinned reference `wax` binary described by tools/reference.json.
#
# The binary itself is not committed (13 MB); this script fetches it and refuses
# to install anything whose sha256 does not match the pin.
#
# TWO sources, in this order:
#
#   1. `mirror_repo`/`mirror_release` -- a release of OUR OWN holding a copy of
#      exactly the pinned build. Upstream publishes only the floating 'edge'
#      asset and one tagged release 328 commits behind it, so once 'edge' is
#      rebuilt the build these goldens were made with is gone from upstream for
#      good. The mirror is the copy that outlives that.
#
#   2. `repo`/`release` -- upstream's 'edge', rebuilt on every push to
#      ocsigen/wax main. Still tried, so a tree whose mirror has not been
#      created yet behaves exactly as it did before, and so that a mismatch here
#      keeps reporting what it always reported: upstream moved. See
#      reference.json, and the `drift` job, which exists to say so on a
#      schedule.
#
# sha256 is the authority for both. A mirror that does not match the pin is
# refused like any other download -- the point of a mirror is to keep serving
# the pinned bytes, not to become a second source of truth.
set -euo pipefail

cd "$(dirname "$0")"

json() { python3 -c "import json,sys;print(json.load(open('reference.json')).get('$1',''))"; }

REPO=$(json repo)
RELEASE=$(json release)
MIRROR_REPO=$(json mirror_repo)
MIRROR_RELEASE=$(json mirror_release)
ASSET=$(json asset)
WANT_SHA=$(json sha256)
WANT_VERSION=$(json reports_version)

have_sha() { sha256sum "$ASSET" | cut -d' ' -f1; }

if [ -x "$ASSET" ] && [ "$(have_sha)" = "$WANT_SHA" ]; then
  echo "reference: $ASSET already present and matches the pin"
  exit 0
fi

# `|| true` on the mirror: an absent release, an unauthenticated `gh`, or no
# network are all reasons to fall through to upstream rather than to stop. A
# mirror that downloads something WRONG is a different matter, and the sha256
# check below catches it.
if [ -n "$MIRROR_REPO" ] && [ -n "$MIRROR_RELEASE" ]; then
  echo "reference: trying the mirror $MIRROR_REPO@$MIRROR_RELEASE"
  gh release download "$MIRROR_RELEASE" --repo "$MIRROR_REPO" \
    --pattern "$ASSET" --clobber -D . 2>/dev/null || true
  if [ -f "$ASSET" ] && [ "$(have_sha)" = "$WANT_SHA" ]; then
    chmod +x "$ASSET"
    GOT_VERSION=$("./$ASSET" --version)
    if [ "$GOT_VERSION" != "$WANT_VERSION" ]; then
      echo "reference: version mismatch from the mirror: expected $WANT_VERSION, got $GOT_VERSION" >&2
      exit 1
    fi
    echo "reference: $ASSET installed from the mirror ($GOT_VERSION, sha256 ok)"
    exit 0
  fi
  # Whatever it served is not the pin. Do not leave it lying around looking
  # like an oracle.
  rm -f "$ASSET"
  echo "reference: the mirror did not serve the pinned build; falling back to $REPO@$RELEASE" >&2
fi

echo "reference: fetching $ASSET from $REPO@$RELEASE"
gh release download "$RELEASE" --repo "$REPO" --pattern "$ASSET" --clobber -D .

GOT_SHA=$(have_sha)
if [ "$GOT_SHA" != "$WANT_SHA" ]; then
  cat >&2 <<EOF

reference: SHA256 MISMATCH -- upstream 'edge' has been rebuilt.

  expected  $WANT_SHA
  got       $GOT_SHA

The committed goldens in test/golden/ were produced by the expected binary, so
this build is NOT interchangeable with it. Do one of:

  * Keep the old oracle: publish the pinned build as the mirror release this
    file names, if it is not there already --
        gh release create $MIRROR_RELEASE --repo $MIRROR_REPO \\
          --title "Pinned wax reference ($(json upstream_commit))" \\
          --notes "Upstream ocsigen/wax build, Apache-2.0. See NOTICE." \\
          /path/to/$ASSET
    Upstream serves no per-commit asset, so once 'edge' moves this is the only
    way the pinned bytes stay reachable.
  * Adopt the new one: confirm the front end is unaffected with
        gh api repos/$REPO/compare/\$(json ported_from_commit)...<new commit>
    then update reference.json (sha256, upstream_commit, mirror_release) and
    regenerate the goldens with 'waxdiff golden'. Review that diff -- it is
    upstream's behaviour change, and it is exactly what this pin exists to
    surface.

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
