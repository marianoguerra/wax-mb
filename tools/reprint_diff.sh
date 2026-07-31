#!/usr/bin/env bash
# Diff this port's reprint against the reference's, for one snippet.
#
# The inner loop of porting output.ml: paste a construct, see exactly where the
# layout diverges. Much faster than waiting for oracle 1 over the whole corpus,
# and it points at one construct rather than a pile of files.
#
#   tools/reprint_diff.sh 'fn f() -> i32 { 1 + 2; }'
#   tools/reprint_diff.sh < some.wax
set -euo pipefail
cd "$(dirname "$0")/.."
src=${1:-$(cat)}
printf '%s\n' "$src" > /tmp/reprint_in.wax
tools/wax-ref /tmp/reprint_in.wax -f wax > /tmp/reprint_ref.txt 2>/tmp/reprint_err.txt || {
  echo "reference rejected the input:"; cat /tmp/reprint_err.txt; exit 1; }
moon run tools/reprint --target native -- /tmp/reprint_in.wax > /tmp/reprint_ours.txt 2>/dev/null || {
  echo "our reprint failed"; exit 1; }
if diff -u /tmp/reprint_ref.txt /tmp/reprint_ours.txt > /tmp/reprint_diff.txt; then
  echo "MATCH"
else
  echo "DIFFERS (- reference, + ours):"
  cat /tmp/reprint_diff.txt
fi
