# scater-qc — independent S3 review

Reviewed source commit: `d7355bec9aa73496eba8e2c548a55415455e0508` (branch `s3/m3m4`). Review-only files are excluded from the implementation under review. No module source, golden or lock was changed.

Environment: `omicstat-r:2026.10.1`; image ID `sha256:d77c48fe94fe3f06ded5af701246b0d06eaf823096b84529e620a2fc7cdde0c7`. Non-root, network disabled; suite and acceptance-library mounts read-only; lane scratch writable. `OMICSTAT_WRITE_GOLDEN` was not set.

## Commands and runtime evidence

```bash
docker run --rm --network none --user 1000:1000 -v /home/<user>/omic-s3m:/omicstat:ro -v /home/<user>/omic-sol61/s3_m3m4/scater-qc:/scratch -v /home/<user>/omic-integrate/.omicstat-acceptance:/omicstat/.omicstat-acceptance:ro -w /omicstat -e HOME=/tmp/omicstat-home -e OMICSTAT_TEST_TMP=/scratch -e OMICSTAT_CONTAINER=1 -e OMICSTAT_IMAGE_ID=sha256:d77c48fe94fe3f06ded5af701246b0d06eaf823096b84529e620a2fc7cdde0c7 -e OMICSTAT_REQUIRE_LOCKED=1 -e PYTHONDONTWRITEBYTECODE=1 -e OMP_NUM_THREADS=1 -e OPENBLAS_NUM_THREADS=1 -e MKL_NUM_THREADS=1 -e NUMBA_NUM_THREADS=1 -e PATH=/opt/omicstat/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin omicstat-r:2026.10.1 Rscript skills/scater-qc/tests/run_smoke_test.R
```
Exit 0; raw log: `/home/<user>/omic-sol61/s3_m3m4/scater-qc/smoke.log`.
```bash
docker run --rm --network none --user 1000:1000 -v /home/<user>/omic-s3m:/omicstat:ro -v /home/<user>/omic-sol61/s3_m3m4/scater-qc:/scratch -v /home/<user>/omic-integrate/.omicstat-acceptance:/omicstat/.omicstat-acceptance:ro -w /omicstat -e HOME=/tmp/omicstat-home -e OMICSTAT_TEST_TMP=/scratch -e OMICSTAT_CONTAINER=1 -e OMICSTAT_IMAGE_ID=sha256:d77c48fe94fe3f06ded5af701246b0d06eaf823096b84529e620a2fc7cdde0c7 -e OMICSTAT_REQUIRE_LOCKED=1 -e PYTHONDONTWRITEBYTECODE=1 -e OMP_NUM_THREADS=1 -e OPENBLAS_NUM_THREADS=1 -e MKL_NUM_THREADS=1 -e NUMBA_NUM_THREADS=1 -e PATH=/opt/omicstat/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin omicstat-r:2026.10.1 Rscript tools/make_module_lock.R scater-qc --check
```
Exit 0; raw log: `/home/<user>/omic-sol61/s3_m3m4/scater-qc/lock.log`.

Golden must PASS rather than SKIP: verified in smoke assertions/log; smoke exit 0.
Lock evidence (exit 0):
```text
module_lock scater-qc 1.0.0: OK (16 files)
```.

## Official workflow and anchor

scater overview Zeisel setup with ERCC/repeat altExps; scuttle perCellQCMetrics -> perCellQCFilters/MAD or explicit fixed filtering. 20006 genes,3005 cells; exact native metric/filter replay.

Locked documentary evidence: `/home/<user>/omic-s0-a/acceptance/exemplars/scater-qc/L1_bioc3.23`. PACK C/D/F and S0_VERIFICATION_M3M4 §3/§4.3 were used with the owner’s slim-policy override. No literature counts were used to choose defaults. Statistics are delegated to the named native package functions; descriptive reshaping/ranking is distinguished from inference.

Smoke evidence:
```text
PASS PRINTED scater overview: 20006 genes x 3005 cells, after splitAltExps 
PASS PRINTED alternative experiments 
PASS REPLAY exact vignette library sizes 
PASS REPLAY exact filter decisions 
PASS REPLAY mitochondrial percent 
PASS anchor_cli 
PASS from_run 
PASS figure detected 
PASS figure subsets_Mito_percent 
PASS figure qc_violin 
PASS golden PASS 
PASS no Rplots.pdf 
```

## Options

Compared engine/entry/registry/options.md and SKILL.md. `17` documented option rows; all non-`none` S0 extraction keys exist in `/home/<user>/omic-s0-a/acceptance/exemplars/scater-qc/literature/extraction.jsonl`. Both reference services and ask-user guidance are present. Mandatory scientific inputs and native JSON overrides were inspected; input/object names, output keys, serial execution and recorded seeds are transport/execution contracts, not inferred scientific defaults.
The exact options defects, if any, are listed in the closed repair list below.

## Outputs, Methods and handoffs

Native objects observed: 2 RDS/H5AD files; Methods drafts observed: 2. Native result columns/objects are retained except any explicitly listed repair. Methods names, package versions and run options were inspected against the engine and generated outputs. `--from-run` and chain-state evidence are in the smoke logs; real producer-chain supplement is recorded separately where needed.

## Figures

Opened every generated PNG through SHA256-indexed contact sheets (byte-identical repeats share the opened image). 6 unique PNG contents for this module, 6 figure specs. Inventory: `/home/<user>/omic-sol61/s3_m3m4/visual/inventory.json`; sheets: `sheet_012.jpg`, `sheet_013.jpg`. Captions reside in `*.figure_spec.json`, not necessarily inside PNG pixels. Suite builders/theme/palette and finalizer are used. Visual findings: Plots are nonblank, labels readable and not clipped; plotted quantities follow the package workflow. Captions record n and thresholds or explicitly state no cutoff.

## Known issues / scope

Supplementary native JSON arguments are exposed, resolved in Methods and provenance. QC thresholds are required conditional choices.

## Closed repair list

None. Notes are limitations/documentation observations, not permission to alter scientific defaults.

VERDICT: PASS WITH NOTES
