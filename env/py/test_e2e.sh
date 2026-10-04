#!/usr/bin/env bash
# Host-level end-to-end test of the Python lane (ENGINEERING_PLAN 10.8 item 2):
# mcp/test_client.py over real MCP stdio on THIS host, so the container engine
# can start both images -- python in omicstat-py, then the R render step in
# omicstat-r. (Inside omicstat-r, env/test.sh runs the same client, but there
# docker is absent and the container cases SKIP.)
# Usage: bash env/py/test_e2e.sh      -> env/py/e2e_report.txt
#   needs docker, both pinned images, and a Python 3.10+ with venv/ensurepip
#   (OMICSTAT_E2E_PYTHON, default python3); the MCP client venv is .venv/
#   (git-ignored) with mcp/requirements.txt.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
VENV="$ROOT/.venv"
if [ ! -x "$VENV/bin/python" ]; then
  "${OMICSTAT_E2E_PYTHON:-python3}" -m venv "$VENV" && "$VENV/bin/pip" install -q --disable-pip-version-check -r "$ROOT/mcp/requirements.txt" || exit 3
fi
"$VENV/bin/python" "$ROOT/mcp/test_client.py" 2>&1 | grep -v " omicstat-mcp INFO " | tee "$ROOT/env/py/e2e_report.txt"
exit ${PIPESTATUS[0]}
