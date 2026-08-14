#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "usage: tools/vendor-stdlib.sh <target-directory> [text|collections|data|all]" >&2
  exit 2
fi

repo_dir=$(cd "$(dirname "$0")/.." && pwd)
target_dir=$1
selection=${2:-all}

mkdir -p "$target_dir"

copy_hashing() {
  install -m 0644 "$repo_dir/stdlib/collections/hashing.wax" "$target_dir/"
}

copy_collections() {
  copy_hashing
  install -m 0644 "$repo_dir/stdlib/collections/persistent_hash_map.wax" "$target_dir/"
  install -m 0644 "$repo_dir/stdlib/collections/persistent_hash_set.wax" "$target_dir/"
  install -m 0644 "$repo_dir/stdlib/collections/persistent_vector.wax" "$target_dir/"
}

copy_text() {
  copy_hashing
  install -m 0644 "$repo_dir/stdlib/text/utf8.wax" "$target_dir/"
}

copy_data() {
  copy_collections
  install -m 0644 "$repo_dir/stdlib/text/utf8.wax" "$target_dir/"
  install -m 0644 "$repo_dir/stdlib/data/immutable_value.wax" "$target_dir/"
}

case "$selection" in
  text)
    copy_text
    ;;
  collections)
    copy_collections
    ;;
  data|all)
    copy_data
    ;;
  *)
    echo "selection must be text, collections, data, or all" >&2
    exit 2
    ;;
esac

echo "vendored Wax stdlib '$selection' profile into $target_dir"
