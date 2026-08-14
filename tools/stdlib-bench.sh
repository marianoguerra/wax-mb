#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "$0")/.." && pwd)
size=${1:-10000}
rounds=${2:-5}
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

cd "$repo_dir"
moon run --target native tools/stdlib_prop -- \
  "$tmp_dir/stdlib.wasm" "$tmp_dir/utf8-cases.txt"
node tools/stdlib_bench.mjs "$tmp_dir/stdlib.wasm" "$size" "$rounds"
