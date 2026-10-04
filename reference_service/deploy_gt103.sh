#!/usr/bin/env bash
# Build and (re)start omicstat-reference on GT103. Run ON GT103 from the extracted release:
#   bash ~/omic-infra-reference/release/deploy_gt103.sh
# (ship_to_gt103.sh, run on the laptop, extracts a committed reference_service/ into release/ and calls this.)
#
# Touches only ~/omic-infra-reference/{release,context,runtime} and ~/omic-build-logs/infra-reference/,
# the image omicstat-reference:* and the compose project / container omicstat-reference.
# No compose down, no rm, no prune, no sudo. Never deletes runtime/data or runtime/logs.
set -Eeuo pipefail

BASE="$HOME/omic-infra-reference"
REL="$BASE/release"
CTX="$BASE/context"
RUN="$BASE/runtime"
LOGDIR="$HOME/omic-build-logs/infra-reference"
NAME="omicstat-reference"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$LOGDIR"
LOG="$LOGDIR/deploy-$STAMP.log"
exec > >(tee -a "$LOG") 2>&1

say() { printf '[%s] %s\n' "$(date -u +%H:%M:%SZ)" "$*"; }
die() { say "FAILED: $*"; exit 1; }

[ "$(cd "$(dirname "$0")" && pwd)" = "$REL" ] || die "run this script from $REL"
cd "$REL"
grep -q "^name: $NAME$" compose.yaml || die "compose project name is not $NAME"
grep -q "container_name: $NAME$" compose.yaml || die "container name is not $NAME"
if grep -Eq 'container_name:\s*medstat|image:\s*medstat|^\s*ports:' compose.yaml; then die "compose.yaml would collide with medstat-reference or publish a port"; fi

# A container named omicstat-reference must be ours (compose project omicstat-reference) or absent.
if docker inspect "$NAME" >/dev/null 2>&1; then
  proj="$(docker inspect -f '{{ index .Config.Labels "com.docker.compose.project" }}' "$NAME")"
  [ "$proj" = "$NAME" ] || die "a foreign container named $NAME exists (project '$proj'); not touching it"
fi

say "release commit: $(cat "$REL/RELEASE_COMMIT" 2>/dev/null || echo unknown)"
say "offline tests on the host (fork provenance + configuration through the fork's loaders)"
python3 -m unittest discover -s tests -p "test_*.py" -v

say "staging build context"
rm -rf "$CTX.new"
python3 stage_build.py --out "$CTX.new" --commit "$(cat "$REL/RELEASE_COMMIT" 2>/dev/null || echo unknown)"
if [ -d "$CTX" ]; then mv "$CTX" "$BASE/context.prev-$STAMP"; fi
mv "$CTX.new" "$CTX"

mkdir -p "$RUN/data" "$RUN/logs"
[ -w "$RUN/data" ] && [ -w "$RUN/logs" ] || die "runtime directories are not writable by $(id -un)"

say "docker compose build ($NAME)"
docker compose -f "$REL/compose.yaml" build
IMAGE="$(sed -n 's/^ *image: *//p' "$REL/compose.yaml" | head -1)"
say "fork test suite inside the new image $IMAGE (one-off container, no network, read-only root)"
docker run --rm --network none --read-only --tmpfs /tmp:rw,size=67108864 --user 1000:1000   -e OMICSTAT_REFERENCE_TEST_SCRATCH=/tmp/scratch -w /app "$IMAGE" python -m unittest discover -s tests -p "test_*.py"
say "docker compose up -d ($NAME)"
docker compose -f "$REL/compose.yaml" up -d

say "waiting for worker health (max 120 s)"
ok=0
for _ in $(seq 1 24); do
  if docker exec "$NAME" python /app/worker.py --health; then ok=1; break; fi
  sleep 5
done
[ "$ok" = 1 ] || die "worker health did not pass; inspect: docker logs --tail 50 $NAME"

say "status"
docker exec "$NAME" python /app/cli.py status
docker exec "$NAME" cat /app/STAGED.json
docker compose -f "$REL/compose.yaml" ps
say "done; log: $LOG"
