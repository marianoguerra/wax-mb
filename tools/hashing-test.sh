#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "$0")/.." && pwd)
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

cd "$repo_dir"
cc -O2 -std=c99 -Wall -Wextra -Werror \
  test/hashing/reference_murmur3.c -o "$tmp_dir/reference-murmur3"
"$tmp_dir/reference-murmur3" > "$tmp_dir/reference-output.txt"
moon run --target native tools/hashing_prop -- "$tmp_dir/hashing.wasm"
node tools/hashing_runner.mjs "$tmp_dir/hashing.wasm" "$tmp_dir/reference-output.txt"
