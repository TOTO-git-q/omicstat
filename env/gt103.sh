#!/usr/bin/env bash
# One command on GT103 (or any Linux box with docker + internet):
#   1. pin GitHub packages (once), 2. build omicstat-r, 3. run every test in
#   the image, 4. regenerate the figure gallery in the image, 5. commit the
#   lock / pins / reports and push (if this checkout can push).
# Usage (on GT103):
#   git clone -b claude/gallant-fermat-ifhpkl https://github.com/TOTO-git-q/omic-MCP.git ~/omic-MCP
#   cd ~/omic-MCP && bash env/gt103.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
git pull --ff-only || true
bash env/pin_github.sh
bash env/build.sh
bash env/pin_github.sh --from-lock            # freeze transitive GitHub deps too
test_status=0; bash env/test.sh || test_status=$?
IMAGE="$(python3 -c "import json; c=json.load(open('env/omicstat-env.json')); print(c['image']+':'+c['image_tag'])")"
docker run --rm --network none -v "$ROOT":/omicstat -w /omicstat "$IMAGE" Rscript skills/_shared/tests/make_figure_gallery.R
selftest_status=0
docker run --rm --network none -v "$ROOT":/omicstat -w /omicstat "$IMAGE" \
  Rscript skills/omicstat-selftest/scripts/run_omicstat_selftest.R --outdir /tmp/selftest --strict || selftest_status=$?
{
  echo "# omicstat-r build record"; echo
  echo "- host: $(hostname)  date (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "- image: $IMAGE  id: $(cat env/image_id.txt)"
  echo "- packages locked: $(($(wc -l < env/pkg_lock.csv) - 1))"
  echo "- test exit status: $test_status (details: env/test_report.txt)"
  echo "- omicstat-selftest --strict exit status: $selftest_status (0 = every environment check passed)"
} > env/BUILD_RECORD.md
git add env/pkg_lock.csv env/image_id.txt env/layers/github_pins.txt env/test_report.txt env/BUILD_RECORD.md docs/figure-gallery
git commit -m "env: build omicstat-r $(python3 -c "import json; print(json.load(open('env/omicstat-env.json'))['env_version'])") on $(hostname); lock + test report" || true
git push || echo "push failed: copy env/pkg_lock.csv, env/layers/github_pins.txt, env/test_report.txt, env/BUILD_RECORD.md back manually"
exit $(( test_status != 0 ? test_status : selftest_status ))
