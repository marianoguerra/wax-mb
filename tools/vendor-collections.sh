#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "usage: tools/vendor-collections.sh <target-directory> [hashing|map|vector|all]" >&2
  exit 2
fi

repo_dir=$(cd "$(dirname "$0")/.." && pwd)
target_dir=$1
selection=${2:-all}

mkdir -p "$target_dir"
case "$selection" in
  hashing)
    install -m 0644 "$repo_dir/stdlib/collections/hashing.wax" "$target_dir/"
    ;;
  map)
    install -m 0644 "$repo_dir/stdlib/collections/persistent_hash_map.wax" "$target_dir/"
    ;;
  vector)
    install -m 0644 "$repo_dir/stdlib/collections/persistent_vector.wax" "$target_dir/"
    ;;
  all)
    install -m 0644 "$repo_dir/stdlib/collections/hashing.wax" "$target_dir/"
    install -m 0644 "$repo_dir/stdlib/collections/persistent_hash_map.wax" "$target_dir/"
    install -m 0644 "$repo_dir/stdlib/collections/persistent_vector.wax" "$target_dir/"
    ;;
  *)
    echo "selection must be hashing, map, vector, or all" >&2
    exit 2
    ;;
esac

echo "vendored Wax collections into $target_dir"
