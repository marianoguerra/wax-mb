#!/usr/bin/env bash
# Rehearse one module's publish, and get the exit code right.
#
# `moon publish --dry-run` exits 255 on a dry run the SERVER ACCEPTED. It prints
# "Server status: 202 Accepted, detail: Dry run completed successfully" and then
# "Error: `moon publish` failed" -- it treats 202 as a failure. On moon
# 0.1.20260807 that makes `moon -C lib publish --dry-run` unusable as a gate:
# the recipe stops there and never reaches `cli`. So the acceptance line is what
# is believed here, not the status.
#
# The second thing this exists for is refusing to run at the repository root.
# `moon publish` with no -C publishes `marianoguerra/wax-dev`, the development
# harness -- the corpus, the porting tools, the alternative layout engine -- and
# there is no `private`/`publish = false` field in `moon.mod` to prevent it.
# Today that upload fails only because it depends on `marianoguerra/wax`, which
# is not on the registry yet. The day `wax` IS published, that accident starts
# succeeding.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(dirname "$here")"

mod="${1:-}"
case "$mod" in
  lib | cli | wap) ;;
  "")
    echo "publish-dry: usage: $0 lib|cli|wap" >&2
    exit 2
    ;;
  *)
    echo "publish-dry: '$mod' is not a published module; only lib, cli and wap are." >&2
    echo "publish-dry: the repository root is 'marianoguerra/wax-dev', which is" >&2
    echo "publish-dry: the harness and must never reach the registry." >&2
    exit 2
    ;;
esac

out="$(moon -C "$root/$mod" publish --dry-run 2>&1)"
code=$?
echo "$out"

if grep -q "Dry run completed successfully" <<<"$out"; then
  echo "publish-dry: $mod accepted by the registry (moon exited $code; see the note in this script)"
  exit 0
fi

# `cli`'s manifest pins `marianoguerra/wax`, and the extracted zip resolves it
# from the REGISTRY rather than from this tree -- so before the first release
# there is nothing for it to resolve. That is expected exactly once, and only
# while `wax` is genuinely absent: the local index has a file per published
# module, so this asks rather than assumes. Once `wax` is published the branch
# stops being reachable, and a real resolution failure is a real failure again.
index="$HOME/.moon/registry/index/user/marianoguerra/wax.index"
if [ "$mod" = cli ] &&
  grep -q "Failed to resolve registry dependency \`marianoguerra/wax\`" <<<"$out" &&
  [ ! -s "$index" ]; then
  echo "publish-dry: cli cannot rehearse until marianoguerra/wax is on the registry."
  echo "publish-dry: expected before the first release; publish lib first."
  exit 0
fi

echo "publish-dry: $mod FAILED (moon exited $code)" >&2
exit "${code:-1}"
