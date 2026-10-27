#!/usr/bin/env bash
# Re-resolve the omicstat-py lock (ONLY when a pin in env/py/pyproject.toml
# changes; that is a new python_lane.py_env_version).
# Usage: bash env/py/lock.sh      (needs uv == the "locker" version in omicstat-env.json + internet)
# Writes: env/py/uv.lock (universal lock, every file with sha256; resolution
#         capped at exclude-newer) and env/py_lock.txt (its pip export).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
want="$(python3 -c "import json; print(json.load(open('$ROOT/env/py/py-env.json'))['locker'].split()[1])")"
have="$(uv --version | awk '{print $2}')"
if [ "$have" != "$want" ]; then
  echo "OS_ENV_LOCKER_VERSION: uv $have found, the lock is defined with uv $want (pip install uv==$want)" >&2; exit 3
fi
cd "$ROOT/env/py"
uv lock
uv export --frozen --format requirements-txt --no-emit-project --no-header -o "$ROOT/env/py_lock.txt"
python3 "$ROOT/env/py/test_py_env_config.py"
echo "locked: env/py/uv.lock + env/py_lock.txt ($(grep -c '^[a-z]' "$ROOT/env/py_lock.txt") requirements)"
