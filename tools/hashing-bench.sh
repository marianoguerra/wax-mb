#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "$0")/.." && pwd)
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

cd "$repo_dir"
moon run --target native tools/hashing_prop -- "$tmp_dir/hashing.wasm"
node tools/hashing_bench.mjs "$tmp_dir/hashing.wasm" "${1:-4096}" "${2:-2000}"
