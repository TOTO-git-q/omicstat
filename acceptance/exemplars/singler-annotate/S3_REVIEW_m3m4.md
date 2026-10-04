# singler-annotate — independent S3 review

Reviewed source commit: `d7355bec9aa73496eba8e2c548a55415455e0508` (branch `s3/m3m4`). Review-only files are excluded from the implementation under review. No module source, golden or lock was changed.

Environment: `omicstat-r:2026.10.1`; image ID `sha256:d77c48fe94fe3f06ded5af701246b0d06eaf823096b84529e620a2fc7cdde0c7`. Non-root, network disabled; suite and acceptance-library mounts read-only; lane scratch writable. `OMICSTAT_WRITE_GOLDEN` was not set.

## Commands and runtime evidence

```bash
docker run --rm --network none --user 1000:1000 -v /home/<user>/omic-s3m:/omicstat:ro -v /home/<user>/omic-sol61/s3_m3m4/singler-annotate:/scratch -v /home/<user>/omic-integrate/.omicstat-acceptance:/omicstat/.omicstat-acceptance:ro -w /omicstat -e HOME=/tmp/omicstat-home -e OMICSTAT_TEST_TMP=/scratch -e OMICSTAT_CONTAINER=1 -e OMICSTAT_IMAGE_ID=sha256:d77c48fe94fe3f06ded5af701246b0d06eaf823096b84529e620a2fc7cdde0c7 -e OMICSTAT_REQUIRE_LOCKED=1 -e PYTHONDONTWRITEBYTECODE=1 -e OMP_NUM_THREADS=1 -e OPENBLAS_NUM_THREADS=1 -e MKL_NUM_THREADS=1 -e NUMBA_NUM_THREADS=1 -e PATH=/opt/omicstat/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin omicstat-r:2026.10.1 Rscript skills/singler-annotate/tests/run_smoke_test.R
```
Exit 0; raw log: `/home/<user>/omic-sol61/s3_m3m4/singler-annotate/smoke.log`.
```bash
docker run --rm --network none --user 1000:1000 -v /home/<user>/omic-s3m:/omicstat:ro -v /home/<user>/omic-sol61/s3_m3m4/singler-annotate:/scratch -v /home/<user>/omic-integrate/.omicstat-acceptance:/omicstat/.omicstat-acceptance:ro -w /omicstat -e HOME=/tmp/omicstat-home -e OMICSTAT_TEST_TMP=/scratch -e OMICSTAT_CONTAINER=1 -e OMICSTAT_IMAGE_ID=sha256:d77c48fe94fe3f06ded5af701246b0d06eaf823096b84529e620a2fc7cdde0c7 -e OMICSTAT_REQUIRE_LOCKED=1 -e PYTHONDONTWRITEBYTECODE=1 -e OMP_NUM_THREADS=1 -e OPENBLAS_NUM_THREADS=1 -e MKL_NUM_THREADS=1 -e NUMBA_NUM_THREADS=1 -e PATH=/opt/omicstat/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin omicstat-r:2026.10.1 Rscript tools/make_module_lock.R singler-annotate --check
```
Exit 0; raw log: `/home/<user>/omic-sol61/s3_m3m4/singler-annotate/lock.log`.

Golden must PASS rather than SKIP: verified in smoke assertions/log; smoke exit 0.
Lock evidence (exit 0):
```text
module_lock singler-annotate 1.0.0: OK (16 files)
```.

## Official workflow and anchor

Locked SingleR pancreas path: scRNAseq-equivalent ERCC split; Muraro reference and Grun test -> logNormCounts -> SingleR(de.method=wilcox) -> pruneScores. Exact 1718 cells,59 pruned,1659 assigned and all ten printed label counts replay; final golden PASS. Native SingleR result/scores/labels saved.

Locked documentary evidence: `/home/<user>/omic-s3m/acceptance/exemplars/singler-annotate/L1_bioc3.23`. PACK C/D/F and S0_VERIFICATION_M3M4 §3/§4.3 were used with the owner’s slim-policy override. No literature counts were used to choose defaults. Statistics are delegated to the named native package functions; descriptive reshaping/ranking is distinguished from inference.

Smoke evidence:
```text
PASS: static calls, locked default drift and R lint (dynamic JSON flags documented in options.md)
PASS: synthetic classic labels and deterministic --spec tables/figures
PASS: nmads flag changes pruned labels
PASS: typed errors, --from-run and ecosystem/tamper/corrected-lineage rejection
Observed official pancreas label counts:
Observed pruned: 59 
PASS: PACK C exact vignette printed labels and pruning, engine replay
PASS: pancreas golden; 1718 cells, 59 pruned, exact printed label counts
```

## Options

Compared engine/entry/registry/options.md and SKILL.md. `54` documented option rows; all non-`none` S0 extraction keys exist in `/home/<user>/omic-s3m/acceptance/exemplars/singler-annotate/literature/extraction.jsonl`. Both reference services and ask-user guidance are present. Mandatory scientific inputs and native JSON overrides were inspected; input/object names, output keys, serial execution and recorded seeds are transport/execution contracts, not inferred scientific defaults.
The exact options defects, if any, are listed in the closed repair list below.

## Outputs, Methods and handoffs

Native objects observed: 16 RDS/H5AD files; Methods drafts observed: 8. Native result columns/objects are retained except any explicitly listed repair. Methods names, package versions and run options were inspected against the engine and generated outputs. `--from-run` and chain-state evidence are in the smoke logs; real producer-chain supplement is recorded separately where needed.

Independent real producer chain: `{
  "exits": [
    0,
    0,
    0
  ],
  "table": "tables/annotations.csv",
  "native_anchor_bytes_equal": true,
  "upstream": "real scater-qc producer, explicit permissive diagnostic thresholds (first feature is a carrier subset, not a mitochondrial biological claim)",
  "consumer": "/home/<user>/omic-sol61/s3_m3m4/singler-annotate/real_chain/consumer/tables/annotations.csv"
}`. Commands/logs: `/home/<user>/omic-sol61/s3_m3m4/singler-annotate/real_chain_*.command.json` / `real_chain_*.log`.

Supplemental override_proof command:
```bash
docker run --rm --network none --user 1000:1000 -v /home/<user>/omic-s3m:/omicstat:ro -v /home/<user>/omic-sol61/s3_m3m4/singler-annotate:/scratch -v /home/<user>/omic-integrate/.omicstat-acceptance:/omicstat/.omicstat-acceptance:ro -w /omicstat -e HOME=/tmp/omicstat-home -e OMICSTAT_TEST_TMP=/scratch -e OMICSTAT_CONTAINER=1 -e OMICSTAT_IMAGE_ID=sha256:d77c48fe94fe3f06ded5af701246b0d06eaf823096b84529e620a2fc7cdde0c7 -e OMICSTAT_REQUIRE_LOCKED=1 -e PYTHONDONTWRITEBYTECODE=1 -e OMP_NUM_THREADS=1 -e OPENBLAS_NUM_THREADS=1 -e MKL_NUM_THREADS=1 -e NUMBA_NUM_THREADS=1 -e PATH=/opt/omicstat/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin -v /home/<user>/omic-sol61/s3_m3m4:/review:ro omicstat-r:2026.10.1 Rscript skills/singler-annotate/scripts/run_singler_annotate.R --input /scratch/singler-smoke/sce.rds --cluster-col cluster --logcounts-layer logcounts --ecosystem bioconductor --seed 20260925 --journal nature --reference /scratch/singler-smoke/sce.rds --reference-name synthetic-smoke --reference-version v1 --species synthetic --reference-label-col label --unit cell --test-role logcounts --de-method classic --aggr-ref false --fine-tune true --quantile 0.8 --tune-thresh 0.05 --nmads 3 --singler-quantile 0.5 --prune-min-diff-next 0.05 --outdir /scratch/override_proof
```
Raw log: `/home/<user>/omic-sol61/s3_m3m4/singler-annotate/override_proof.log`.

Observed report mismatch: `{
  "native_overrides": {
    "quantile": 0.5,
    "min.diff.next": 0.05
  },
  "reported_quantile": 0.8,
  "command": "/home/<user>/omic-sol61/s3_m3m4/singler-annotate/override_proof.command.json"
}`.

## Figures

Opened every generated PNG through SHA256-indexed contact sheets (byte-identical repeats share the opened image). 8 unique PNG contents for this module, 17 figure specs. Inventory: `/home/<user>/omic-sol61/s3_m3m4/visual/inventory.json`; sheets: `sheet_015.jpg`, `sheet_016.jpg`, `sheet_017.jpg`, `sheet_029.jpg`, `sheet_030.jpg`. Captions reside in `*.figure_spec.json`, not necessarily inside PNG pixels. Suite builders/theme/palette and finalizer are used. Visual findings: Plots are nonblank, labels readable and not clipped; plotted quantities follow the package workflow. Captions record n and thresholds or explicitly state no cutoff.

## Known issues / scope

scrapper rebuild resolves the missing dependency. Synthetic tests are additional controls, not the pancreas anchor. Relative-score heatmap uses the same per-cell [0,1] normalization described in SingleR diagnostics; probabilities are not claimed.

## Closed repair list

1. `skills/singler-annotate/scripts/singler_annotate_report.R:12` — Use the resolved native SingleR/pruneScores arguments from core instead of convenience a fields when writing Methods/results/figure captions. --singler-quantile/--singler-de-method/--prune-nmads currently override native computation while reporting a$quantile/a$de-method/a$nmads. Pass actual min.diff.med and min.diff.next into fig_mod_sc_backend.R:14/:20 instead of hard-coded -Inf/0. Re-verify quantile=.5 and prune-min-diff-next=.05 against native results and emitted text/spec, then smoke and lock. Evidence: PACK C/D/F; owner slim options/output/figure requirements. Re-verify in the same locked image; no tolerance relaxation or silent golden replacement.

VERDICT: FAIL
