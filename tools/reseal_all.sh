#!/usr/bin/env bash
# Owner freeze: only check/dry-run evidence. NEVER creates a module lock/golden.
set -euo pipefail
cd "$(dirname "$0")/.."
exec python3 tools/reseal_all.py "$@"
