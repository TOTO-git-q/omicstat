#!/usr/bin/env bash
# Create the omicstat Python environment WITHOUT docker (native engine), as an
# isolated venv inside the repository, and register its interpreter as the
# "python" key of the native environment file (ENGINEERING_PLAN 10.6 item 2).
# Usage: bash env/py/setup_native.sh [<python3.12 interpreter>]
#   - Linux x86_64 only: env/py_lock.txt is resolved for that platform.
#   - Installs env/py_lock.txt with --require-hashes --no-deps (same files as
#     the omicstat-py image); needs internet once.
#   - venv: <repo>/.omicstat-r/py-venv (git-ignored with .omicstat-r/)
#   - native env file: $OMICSTAT_NATIVE_ENV, else .omicstat-r/native-env.json;
#     only the "python" key is added/replaced, R keys are kept.
# Golden baselines are defined on the container; native runs are the
# "visual equivalence" tier (ENGINEERING_PLAN 3.5 / 10.4 lock 5).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
pcfg() { python3 -c "import json,sys; print(json.load(open('$ROOT/env/py/py-env.json'))[sys.argv[1]])" "$1"; }
want="$(pcfg python_version)"
base="${1:-python${want%.*}}"
have="$("$base" -c 'import platform; print(platform.python_version())')"
if [ "${have%.*}" != "${want%.*}" ]; then
  echo "OS_ENV_PYTHON_VERSION: $base is Python $have; the omicstat-py lock needs Python ${want%.*}.x (image pin $want)" >&2; exit 3
fi
[ "$have" = "$want" ] || echo "NOTE: Python $have differs from the image pin $want (patch level only)." >&2
if [ "$(uname -s)-$(uname -m)" != "Linux-x86_64" ]; then
  echo "OS_ENV_PLATFORM: env/py_lock.txt is resolved for Linux x86_64 only" >&2; exit 3
fi
venv="$ROOT/.omicstat-r/py-venv"
"$base" -m venv "$venv"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
"$venv/bin/python" "$ROOT/env/py/split_lock.py" "$ROOT/env/py_lock.txt" "$ROOT/env/py/uv.lock" "$tmp/w.txt" "$tmp/s.txt"
"$venv/bin/pip" install --disable-pip-version-check --require-hashes --no-deps --only-binary=:all: \
  --index-url "$(pcfg pypi_index)" --extra-index-url "$(pcfg pytorch_index)" -r "$tmp/w.txt"
"$venv/bin/pip" install --disable-pip-version-check --require-hashes --no-deps --no-build-isolation \
  --index-url "$(pcfg pypi_index)" -r "$tmp/s.txt"
"$venv/bin/pip" check
envfile="${OMICSTAT_NATIVE_ENV:-$ROOT/.omicstat-r/native-env.json}"
mkdir -p "$(dirname "$envfile")"
"$venv/bin/python" - "$envfile" "$venv/bin/python" "$(pcfg py_env_version)" <<'PY'
import json, os, sys
path, py, ver = sys.argv[1:4]
cfg = json.load(open(path, encoding="utf-8")) if os.path.isfile(path) else {"schema": "omicstat.native-env.v1"}
cfg["python"] = py
cfg["py_env_version"] = ver
with open(path, "w", encoding="utf-8", newline="\n") as fh:
    json.dump(cfg, fh, indent=2)
    fh.write("\n")
PY
echo "omicstat native Python environment ready: $venv (registered in $envfile)"
