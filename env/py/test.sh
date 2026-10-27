#!/usr/bin/env bash
# Run the Python-lane tests INSIDE the omicstat-py image: the image self-test
# (static + functional determinism), the _shared/py unit tests, the lock-3
# checker tests and every Python module smoke test (engine part; the R render
# part and the MCP path run from the host: env/py/test_e2e.sh).
# Usage: bash env/py/test.sh   -> env/py/test_report.txt
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
IMAGE="${OMICSTAT_IMAGE:-$(python3 -c "import json; c=json.load(open('$ROOT/env/py/py-env.json')); print(c['image']+':'+c['image_tag'])")}"
REPORT="${OMICSTAT_TEST_REPORT:-$ROOT/env/py/test_report.txt}"
mkdir -p "$(dirname "$REPORT")"
IMAGE_ID="$(docker image inspect "$IMAGE" --format '{{.Id}}')" || exit 1
artifact_mounts=()
if [ -n "${OMICSTAT_TEST_ARTIFACTS:-}" ]; then
  mkdir -p "$OMICSTAT_TEST_ARTIFACTS"
  artifacts="$(cd "$OMICSTAT_TEST_ARTIFACTS" && pwd -P)"
  artifact_mounts=(-v "$artifacts:/tmp/omicstat-test")
fi
docker run --rm --network none --user "$(id -u):$(id -g)" \
  -v "$ROOT":/omicstat:ro "${artifact_mounts[@]}" -w /omicstat \
  -e OMICSTAT_WRITE_GOLDEN= -e PYTHONDONTWRITEBYTECODE=1 -e HOME=/tmp/omicstat-home -e OMICSTAT_TEST_TMP=/tmp/omicstat-test \
  -e OMICSTAT_PY_IMAGE_ID="$IMAGE_ID" -e OMICSTAT_REQUIRE_LOCKED=1 -e OMICSTAT_TEST_LOG_DIR=/tmp/omicstat-test/logs \
  "$IMAGE_ID" bash -c 'mkdir -p /tmp/omicstat-test /tmp/omicstat-home; bash tools/run_tests_py.sh' 2>&1 | tee "$REPORT"
status=${PIPESTATUS[0]}
echo "image: $IMAGE $(docker image inspect "$IMAGE" --format '{{.Id}}')" >> "$REPORT"
exit $status
