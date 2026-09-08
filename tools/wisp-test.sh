#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 tools/gen-wisp-runtime.py --check
moon build --target js wisp/bridge
node wisp/js/runtime.test.mjs
