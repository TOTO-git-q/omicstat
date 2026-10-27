#!/usr/bin/env bash
# Build the omicstat-py image from env/py/py-env.json ("python_lane", the
# only pin source) and the hash lock env/py_lock.txt.
# Usage: bash env/py/build.sh          (from anywhere; needs docker + internet)
# Writes: env/py/py_installed.csv  (installed distributions copied out of the image)
#         env/py/image_id.txt      (image ID recorded in every Python run's provenance)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
pcfg() { python3 -c "import json,sys; print(json.load(open('$ROOT/env/py/py-env.json'))[sys.argv[1]])" "$1"; }
# Bootstrap recipes cannot reconstruct appended candidate layers.
python3 - "$ROOT/env/py/py-env.json" <<'PYGUARD'
import json,sys
if json.load(open(sys.argv[1])).get('candidate_history'):
    sys.exit('Active lineage has promoted candidate layers; prepare a new offline candidate from the archived sources, never rebuild a canonical tag with the bootstrap recipe.')
PYGUARD
IMAGE="$(pcfg image):$(pcfg image_tag)"
if docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "OS_ENV_TAG_EXISTS: refusing to overwrite $IMAGE" >&2; exit 1
fi
python3 "$ROOT/env/py/test_py_env_config.py"
docker build -f "$ROOT/env/py/Dockerfile" \
  --build-arg BASE_IMAGE="$(pcfg base_image)@$(pcfg base_image_digest)" \
  --build-arg PY_ENV_VERSION="$(pcfg py_env_version)" \
  --build-arg PYTHON_VERSION="$(pcfg python_version)" \
  --build-arg PYPI_INDEX="$(pcfg pypi_index)" \
  --build-arg PYTORCH_INDEX="$(pcfg pytorch_index)" \
  -t "$IMAGE" "$ROOT/env"
docker run --rm "$IMAGE" cat /opt/omicstat/py_installed.csv > "$ROOT/env/py/py_installed.csv"
docker image inspect "$IMAGE" --format '{{.Id}}' > "$ROOT/env/py/image_id.txt"
echo "built $IMAGE ($(cat "$ROOT/env/py/image_id.txt")); installed: env/py/py_installed.csv ($(($(wc -l < "$ROOT/env/py/py_installed.csv") - 1)) distributions)"
