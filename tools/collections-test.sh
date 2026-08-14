#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "$0")/.." && pwd)
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

cd "$repo_dir"
moon run --target native tools/collections_prop -- "$tmp_dir/properties.wasm"
node tools/collections_runner.mjs "$tmp_dir/properties.wasm"
