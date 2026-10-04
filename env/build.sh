#!/usr/bin/env bash
# Build the omicstat-r image from env/omicstat-env.json (the only pin source).
# Usage: bash env/build.sh            (from anywhere; needs docker + internet)
# Writes: env/pkg_lock.csv (package lock copied out of the image)
#         env/image_id.txt (image digest recorded in every run's provenance)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cfg() { python3 -c "import json,sys; print(json.load(open('$ROOT/env/omicstat-env.json'))[sys.argv[1]])" "$1"; }
IMAGE="$(cfg image):$(cfg image_tag)"
base_id="$(docker image inspect "$(cfg addon_base_image)" --format '{{.Id}}')"
if [ "$base_id" != "$(cfg addon_base_image_id)" ]; then
  echo "OS_ENV_BASE_MISMATCH: addon base identity changed" >&2
  exit 1
fi
if docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "OS_ENV_TAG_EXISTS: refusing to overwrite $IMAGE" >&2
  exit 1
fi
if grep -qE '^[^#]*UNPINNED' "$ROOT/env/layers/github_pins.txt"; then
  echo "github_pins.txt has UNPINNED rows -> running env/pin_github.sh first"; bash "$ROOT/env/pin_github.sh"
fi
docker build -f "$ROOT/env/container/Dockerfile" \
  --build-arg BASE_IMAGE="$(cfg base_image)@$(cfg base_image_digest)" \
  --build-arg BIOC_VERSION="$(cfg bioconductor)" \
  --build-arg CRAN_REPO="$(cfg cran_repo_linux)" \
  --build-arg ENV_VERSION="$(cfg env_version)" \
  --build-arg ADDON_BASE_IMAGE="$(cfg addon_base_image)" \
  -t "$IMAGE" "$ROOT"
docker run --rm "$IMAGE" cat /opt/omicstat/pkg_lock.csv > "$ROOT/env/pkg_lock.csv"
docker image inspect "$IMAGE" --format '{{.Id}}' > "$ROOT/env/image_id.txt"
echo "built $IMAGE ($(cat "$ROOT/env/image_id.txt")); lock: env/pkg_lock.csv ($(($(wc -l < "$ROOT/env/pkg_lock.csv") - 1)) packages)"
