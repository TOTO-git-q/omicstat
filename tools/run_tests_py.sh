#!/usr/bin/env bash
# Run every Python-lane test INSIDE the omicstat-py image (env/py/test.sh):
# the image self-test (static + functional determinism), the python_lane
# config checks, the _shared/py unit tests, the lock-3 checker tests, and for
# every Python module (scripts/run_*.py) its smoke test, tools/check_calls.py
# and tools/check_defaults.py. The R render step and the MCP path are tested
# from omicstat-r / the host (skills/_shared/tests/test_render_figure_request.R,
# mcp/test_client.py).
# Usage: bash tools/run_tests_py.sh
set -u
cd "$(dirname "$0")/.."
fail=0; test_index=0
log="${TMPDIR:-/tmp}/omicstat_test_py.$$.log"
run() {
  echo "== $*"
  if "$@" > "$log" 2>&1; then tail -1 "$log"; else grep -v '^PASS' "$log" | tail -25; fail=1; fi
  test_index=$((test_index + 1))
  if [ -n "${OMICSTAT_TEST_LOG_DIR:-}" ]; then
    mkdir -p "$OMICSTAT_TEST_LOG_DIR"
    cp "$log" "$OMICSTAT_TEST_LOG_DIR/$(printf '%03d' "$test_index").log"
    printf '%03d\t%s\n' "$test_index" "$*" >> "$OMICSTAT_TEST_LOG_DIR/index.tsv"
  fi
}
run python env/py/selftest_image.py --functional
run python env/py/test_py_env_config.py
run python skills/_shared/py/tests/test_ospy.py
run python skills/_shared/py/tests/test_user_genesets.py
run python tools/test_check_calls.py
run python tools/test_new_module_py.py
run python tools/test_build_contracts.py
run python tools/check_skill_frontmatter.py
for mod in skills/*/; do
  set -- "$mod"scripts/run_*.py
  [ -f "$1" ] || continue
  run python tools/check_calls.py "${mod%/}"
  run python tools/check_defaults.py "${mod%/}"
  run python tools/check_flag_docs.py "${mod%/}"
  [ -f "$mod"tests/run_smoke_test.py ] && run python "$mod"tests/run_smoke_test.py
done
rm -f "$log"
echo "== done: $([ $fail -eq 0 ] && echo ALL PASSED || echo FAILURES) ($test_index commands)"
exit $fail
