#!/usr/bin/env bash
# Execute only inside the locked omicstat-r image. Never edit golden hashes by hand.
set -euo pipefail
cd "$(dirname "$0")/../../.."
Rscript -e 'stopifnot(as.character(getRversion()) == "4.6.1", as.character(BiocManager::version()) == "3.23")'
# The original smoke also verifies withheld historical evidence. Keep its
# assertions unchanged; fail clearly rather than inventing or bypassing files.
for evidence in \
  acceptance/exemplars/limma-camera/routing_eval_limma_camera.jsonl \
  acceptance/exemplars/limma-camera/literature/corpus.jsonl \
  acceptance/exemplars/limma-camera/literature/extraction.jsonl \
  acceptance/exemplars/limma-camera/L1_bioc3.23/limma/vignettes/usersguide.rendered.txt; do
  if [ ! -f "$evidence" ]; then
    echo "OS_ACCEPTANCE_EVIDENCE_MISSING: original private fixture required: $evidence" >&2
    exit 3
  fi
done
OMICSTAT_WRITE_GOLDEN=1 Rscript skills/limma-camera/tests/run_smoke_test.R
Rscript skills/limma-camera/tests/run_smoke_test.R
Rscript tools/make_module_lock.R limma-camera
Rscript tools/make_module_lock.R limma-camera --check
