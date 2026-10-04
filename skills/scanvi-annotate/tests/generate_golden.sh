#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
python tools/capture_locked_defaults.py scanvi-annotate
OMICSTAT_REQUIRE_LOCKED=1 OMICSTAT_WRITE_GOLDEN=1 python skills/scanvi-annotate/tests/run_smoke_test.py
OMICSTAT_REQUIRE_LOCKED=1 python skills/scanvi-annotate/tests/run_smoke_test.py
python tools/make_module_lock.py scanvi-annotate
python tools/make_module_lock.py scanvi-annotate --check
