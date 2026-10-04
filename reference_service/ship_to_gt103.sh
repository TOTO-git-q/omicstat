#!/usr/bin/env bash
# Run on the laptop (Git Bash) from the omic-MCP checkout. Ships the COMMITTED reference_service/ of
# <commit> (default HEAD) to GT103 ~/omic-infra-reference/release/ and runs deploy_gt103.sh there.
#   bash reference_service/ship_to_gt103.sh [commit]
# The previous release directory is kept as release.prev-<UTC>; runtime/ (data, logs) is never touched.
set -Eeuo pipefail
HOST="${GT103:-<user>@<analysis-host>}"
COMMIT="$(git rev-parse "${1:-HEAD}")"
git diff --quiet "$COMMIT" -- reference_service || echo "note: working tree differs from $COMMIT; shipping the commit, not the working tree"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
git archive --format=tar "$COMMIT" reference_service | ssh -o BatchMode=yes "$HOST" "set -e
  base=\$HOME/omic-infra-reference; mkdir -p \$base/incoming/$STAMP
  tar -x -C \$base/incoming/$STAMP
  echo $COMMIT > \$base/incoming/$STAMP/reference_service/RELEASE_COMMIT
  if [ -d \$base/release ]; then mv \$base/release \$base/release.prev-$STAMP; fi
  mv \$base/incoming/$STAMP/reference_service \$base/release
  rmdir \$base/incoming/$STAMP"
ssh -o BatchMode=yes "$HOST" "bash \$HOME/omic-infra-reference/release/deploy_gt103.sh"
