#!/usr/bin/env bash
# Run the ported standard library, rather than only compiling it.
#
# `just wap-stdlib` proves the ports type check. That is not the same as their
# working: the whole point of `stdlib-wap/` is that it does what the `.wax`
# sources do, and a port can type check while returning the wrong number.
#
# So the two example modules are built to wasm, run in Node's WebAssembly GC
# runtime, and compared against what the ORIGINALS return. The expected values
# below were produced by concatenating the .wax sources in the order
# `stdlib/README.md` prescribes, compiling them with the pinned reference `wax`
# binary, and running the result the same way -- `--against-reference` does
# exactly that again, and is how these numbers are re-derived if the sources
# change. CI runs the hermetic half, which needs neither the reference binary
# nor the .wax sources.
set -euo pipefail

repo_dir=$(cd "$(dirname "$0")/.." && pwd)
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
cd "$repo_dir"

# module : exported function : expected result
CASES=(
  "collections.example:collections_example:8"
  "data.example:immutable_data_example:19"
)

against_reference=0
if [ "${1-}" = "--against-reference" ]; then
  against_reference=1
fi

run_one() {
  # $1 wasm file, $2 export name
  node -e '
    const fs = require("fs");
    WebAssembly.instantiate(fs.readFileSync(process.argv[1]), {})
      .then(({ instance }) => { process.stdout.write(String(instance.exports[process.argv[2]]())); })
      .catch(e => { process.stderr.write(e.message); process.exit(1); });
  ' "$1" "$2"
}

status=0
for entry in "${CASES[@]}"; do
  IFS=: read -r module export expected <<<"$entry"
  moon run --target native tools/wapc -- --out "$tmp_dir/$module.wasm" "$module" >/dev/null
  actual=$(run_one "$tmp_dir/$module.wasm" "$export")
  if [ "$actual" != "$expected" ]; then
    echo "wap-stdlib-test: $module returned $actual, expected $expected" >&2
    status=1
  else
    echo "wap-stdlib-test: $module -> $actual"
  fi
done

if [ "$against_reference" -eq 1 ]; then
  # The .wax profiles, in the order stdlib/README.md prescribes.
  cat stdlib/collections/hashing.wax \
      stdlib/collections/persistent_hash_map.wax \
      stdlib/collections/persistent_vector.wax \
      stdlib/collections/example.wax > "$tmp_dir/collections.wax"
  cat stdlib/collections/hashing.wax \
      stdlib/collections/persistent_hash_map.wax \
      stdlib/collections/persistent_hash_set.wax \
      stdlib/collections/persistent_vector.wax \
      stdlib/text/utf8.wax \
      stdlib/data/immutable_value.wax \
      stdlib/data/record.wax \
      stdlib/data/example.wax > "$tmp_dir/data.wax"
  for entry in "collections.example:collections_example:collections" \
               "data.example:immutable_data_example:data"; do
    IFS=: read -r module export profile <<<"$entry"
    tools/wax-ref "$tmp_dir/$profile.wax" -f wasm -o "$tmp_dir/$profile-ref.wasm"
    reference=$(run_one "$tmp_dir/$profile-ref.wasm" "$export")
    actual=$(run_one "$tmp_dir/$module.wasm" "$export")
    if [ "$actual" != "$reference" ]; then
      echo "wap-stdlib-test: $module returned $actual, the .wax original returned $reference" >&2
      status=1
    else
      echo "wap-stdlib-test: $module agrees with the .wax original ($reference)"
    fi
  done
fi

exit "$status"
