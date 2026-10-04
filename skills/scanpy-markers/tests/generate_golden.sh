#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
python tools/capture_locked_defaults.py scanpy-markers
OMICSTAT_REQUIRE_LOCKED=1 OMICSTAT_WRITE_GOLDEN=1 python skills/scanpy-markers/tests/run_smoke_test.py
OMICSTAT_REQUIRE_LOCKED=1 python skills/scanpy-markers/tests/run_smoke_test.py
python tools/make_module_lock.py scanpy-markers
python tools/make_module_lock.py scanpy-markers --check
