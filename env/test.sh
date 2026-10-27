#!/usr/bin/env bash
# Run the full omicstat test suite INSIDE the omicstat-r image (R tests with the
# pinned R/Bioconductor, Python/MCP tests with the image's venv).
# Usage: bash env/test.sh      -> env/test_report.txt
#
# Git inside the container (the MCP provenance / publication tests read the
# repository state with `git rev-parse` / `git status`):
# - the container runs as the calling user, so files written into the mount
#   stay owned by that user and git's safe.directory ownership check passes;
#   safe.directory=/omicstat is also set through GIT_CONFIG_* in case the
#   checkout belongs to another uid (verified 2026-09-27: as root, git refuses
#   with "detected dubious ownership in repository at '/omicstat'");
# - when the checkout is a linked worktree (.git is a FILE pointing to
#   <main>/.git/worktrees/<name>), the git common dir is mounted read-only at
#   its own absolute path, otherwise git reports "not a git repository".
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
cfg() { python3 -c "import json,sys; print(json.load(open('$ROOT/env/r-env.json'))[sys.argv[1]])" "$1"; }
IMAGE="${OMICSTAT_IMAGE:-$(cfg image):$(cfg image_tag)}"
REPORT="${OMICSTAT_TEST_REPORT:-$ROOT/env/test_report.txt}"
mkdir -p "$(dirname "$REPORT")"
IMAGE_ID="$(docker image inspect "$IMAGE" --format '{{.Id}}')" || exit 1
acceptance_mounts=()
if [ -L "$ROOT/.omicstat-acceptance" ]; then
  acceptance="$(readlink -f "$ROOT/.omicstat-acceptance")"
  acceptance_mounts=(-v "$acceptance:/omicstat/.omicstat-acceptance:ro")
fi
artifact_mounts=()
if [ -n "${OMICSTAT_TEST_ARTIFACTS:-}" ]; then
  mkdir -p "$OMICSTAT_TEST_ARTIFACTS"
  artifacts="$(cd "$OMICSTAT_TEST_ARTIFACTS" && pwd -P)"
  artifact_mounts=(-v "$artifacts:/tmp/omicstat-test")
fi
git_mounts=()
if [ -f "$ROOT/.git" ]; then
  common="$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
  if [ -n "$common" ] && [ -d "$common" ]; then
    git_mounts=(-v "$common:$common:ro")
  fi
fi
docker run --rm --network none --user "$(id -u):$(id -g)" \
  -v "$ROOT":/omicstat:ro "${git_mounts[@]}" "${acceptance_mounts[@]}" "${artifact_mounts[@]}" -w /omicstat \
  -e OMICSTAT_WRITE_GOLDEN= -e PYTHONDONTWRITEBYTECODE=1 -e HOME=/tmp/omicstat-home -e OMICSTAT_TEST_TMP=/tmp/omicstat-test -e OMICSTAT_TEST_H5AD=1 \
  -e OMICSTAT_IMAGE_ID="$IMAGE_ID" -e OMICSTAT_TEST_LOG_DIR=/tmp/omicstat-test/logs \
  -e OMICSTAT_MCP_SCRATCH=/tmp/omicstat-test/mcp -e OMICSTAT_RUNS_ROOT=/tmp/omicstat-test/mcp-runs \
  -e GIT_CONFIG_COUNT=1 -e GIT_CONFIG_KEY_0=safe.directory -e GIT_CONFIG_VALUE_0=/omicstat \
  -e PATH="/opt/omicstat/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
  "$IMAGE_ID" bash -c 'mkdir -p /tmp/omicstat-test /tmp/omicstat-home; bash tools/run_tests.sh' 2>&1 | tee "$REPORT"
status=${PIPESTATUS[0]}
echo "image: $IMAGE $(docker image inspect "$IMAGE" --format '{{.Id}}')" >> "$REPORT"
exit $status
