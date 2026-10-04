# maftools-landscape — independent S3 review

Reviewed source commit: `d7355bec9aa73496eba8e2c548a55415455e0508` (branch `s3/m3m4`). Review-only files are excluded from the implementation under review. No module source, golden or lock was changed.

Environment: `omicstat-r:2026.10.1`; image ID `sha256:d77c48fe94fe3f06ded5af701246b0d06eaf823096b84529e620a2fc7cdde0c7`. Non-root, network disabled; suite and acceptance-library mounts read-only; lane scratch writable. `OMICSTAT_WRITE_GOLDEN` was not set.

## Commands and runtime evidence

```bash
docker run --rm --network none --user 1000:1000 -v /home/<user>/omic-s3m:/omicstat:ro -v /home/<user>/omic-sol61/s3_m3m4/maftools-landscape:/scratch -v /home/<user>/omic-integrate/.omicstat-acceptance:/omicstat/.omicstat-acceptance:ro -w /omicstat -e HOME=/tmp/omicstat-home -e OMICSTAT_TEST_TMP=/scratch -e OMICSTAT_CONTAINER=1 -e OMICSTAT_IMAGE_ID=sha256:d77c48fe94fe3f06ded5af701246b0d06eaf823096b84529e620a2fc7cdde0c7 -e OMICSTAT_REQUIRE_LOCKED=1 -e PYTHONDONTWRITEBYTECODE=1 -e OMP_NUM_THREADS=1 -e OPENBLAS_NUM_THREADS=1 -e MKL_NUM_THREADS=1 -e NUMBA_NUM_THREADS=1 -e PATH=/opt/omicstat/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin omicstat-r:2026.10.1 Rscript skills/maftools-landscape/tests/run_smoke_test.R
```
Exit 0; raw log: `/home/<user>/omic-sol61/s3_m3m4/maftools-landscape/smoke.log`.
```bash
docker run --rm --network none --user 1000:1000 -v /home/<user>/omic-s3m:/omicstat:ro -v /home/<user>/omic-sol61/s3_m3m4/maftools-landscape:/scratch -v /home/<user>/omic-integrate/.omicstat-acceptance:/omicstat/.omicstat-acceptance:ro -w /omicstat -e HOME=/tmp/omicstat-home -e OMICSTAT_TEST_TMP=/scratch -e OMICSTAT_CONTAINER=1 -e OMICSTAT_IMAGE_ID=sha256:d77c48fe94fe3f06ded5af701246b0d06eaf823096b84529e620a2fc7cdde0c7 -e OMICSTAT_REQUIRE_LOCKED=1 -e PYTHONDONTWRITEBYTECODE=1 -e OMP_NUM_THREADS=1 -e OPENBLAS_NUM_THREADS=1 -e MKL_NUM_THREADS=1 -e NUMBA_NUM_THREADS=1 -e PATH=/opt/omicstat/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin omicstat-r:2026.10.1 Rscript tools/make_module_lock.R maftools-landscape --check
```
Exit 0; raw log: `/home/<user>/omic-sol61/s3_m3m4/maftools-landscape/lock.log`.

Golden must PASS rather than SKIP: verified in smoke assertions/log; smoke exit 0.
Lock evidence (exit 0):
```text
module_lock maftools-landscape 1.0.0: OK (9 files)
```.

## Official workflow and anchor

Official TCGA-LAML read.maf -> native summaries/tmb/somaticInteractions. Exact193 samples,1241 genes,1732 non-silent,475 silent variants; TMB192 (zero-mutated sample omitted natively); clinical-only7 rows surfaced; all300 interaction pairs kept.

Locked documentary evidence: `/home/<user>/omic-s0-b/acceptance/exemplars/maftools-landscape/L1_bioc3.23`. PACK C/D/F and S0_VERIFICATION_M3M4 §3/§4.3 were used with the owner’s slim-policy override. No literature counts were used to choose defaults. Statistics are delegated to the named native package functions; descriptive reshaping/ranking is distinguished from inference.

Smoke evidence:
```text
PASS: package anchor file hashes 
PASS: end to end -Processing clinical data | maftools landscape completed 
PASS: PRINTED locked maftools vignette: 193 samples,1241 genes 
PASS: PRINTED locked vignette:1732 non-silent,475 silent 
PASS: native TMB192 (package omits zero non-silent sample) and all interaction pairs/pAdj 
PASS: clinical-only seven rows are reported 
PASS: oncoplot observed-sample denominator 193 (factor IDs preserved) 
PASS: native MAF from-run equal 
PASS: neutral ecosystem handoff 
PASS: resolved spec replay 
PASS: check_calls.R 
PASS: lint_r.py 
PASS: check_flag_docs.py 
PASS: container golden  
SMOKE PASSED: 14 checks
```

## Options

Compared engine/entry/registry/options.md and SKILL.md. `25` documented option rows; all non-`none` S0 extraction keys exist in `/home/<user>/omic-s3m/acceptance/exemplars/maftools-landscape/literature/extraction.jsonl`. Both reference services and ask-user guidance are present. Mandatory scientific inputs and native JSON overrides were inspected; input/object names, output keys, serial execution and recorded seeds are transport/execution contracts, not inferred scientific defaults.
The exact options defects, if any, are listed in the closed repair list below.

## Outputs, Methods and handoffs

Native objects observed: 3 RDS/H5AD files; Methods drafts observed: 3. Native result columns/objects are retained except any explicitly listed repair. Methods names, package versions and run options were inspected against the engine and generated outputs. `--from-run` and chain-state evidence are in the smoke logs; real producer-chain supplement is recorded separately where needed.

## Figures

Opened every generated PNG through SHA256-indexed contact sheets (byte-identical repeats share the opened image). 4 unique PNG contents for this module, 12 figure specs. Inventory: `/home/<user>/omic-sol61/s3_m3m4/visual/inventory.json`; sheets: `sheet_021.jpg`, `sheet_022.jpg`. Captions reside in `*.figure_spec.json`, not necessarily inside PNG pixels. Suite builders/theme/palette and finalizer are used. Visual findings: Plots are nonblank, labels readable and not clipped; plotted quantities follow the package workflow. Captions record n and thresholds or explicitly state no cutoff.

## Known issues / scope

Native tmb/somaticInteractions plotting side effects are discarded; final oncoplot/summary/TMB/interaction figures use suite builders. Capture-size is required and top=10/topInteractions25 are vignette values.

## Closed repair list

1. `skills/maftools-landscape/scripts/maftools_landscape_core.R:12` — Expose native tmb captureRegions (currently NULL) as an alternative required callable-territory input to captureSize, matching tmb.Rd mutual exclusion. Record actual region source/hash in Methods/provenance. Verify a local region subset changes native TMB identically to maftools::tmb; retain full variants/summaries and rerun smoke/lock. Evidence: PACK C/D/F; owner slim options/output/figure requirements. Re-verify in the same locked image; no tolerance relaxation or silent golden replacement.

VERDICT: FAIL
