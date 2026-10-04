# seurat-markers — independent S3 review

Reviewed source commit: `d7355bec9aa73496eba8e2c548a55415455e0508` (branch `s3/m3m4`). Review-only files are excluded from the implementation under review. No module source, golden or lock was changed.

Environment: `omicstat-r:2026.10.1`; image ID `sha256:d77c48fe94fe3f06ded5af701246b0d06eaf823096b84529e620a2fc7cdde0c7`. Non-root, network disabled; suite and acceptance-library mounts read-only; lane scratch writable. `OMICSTAT_WRITE_GOLDEN` was not set.

## Commands and runtime evidence

```bash
docker run --rm --network none --user 1000:1000 -v /home/<user>/omic-s3m:/omicstat:ro -v /home/<user>/omic-sol61/s3_m3m4/seurat-markers:/scratch -v /home/<user>/omic-integrate/.omicstat-acceptance:/omicstat/.omicstat-acceptance:ro -w /omicstat -e HOME=/tmp/omicstat-home -e OMICSTAT_TEST_TMP=/scratch -e OMICSTAT_CONTAINER=1 -e OMICSTAT_IMAGE_ID=sha256:d77c48fe94fe3f06ded5af701246b0d06eaf823096b84529e620a2fc7cdde0c7 -e OMICSTAT_REQUIRE_LOCKED=1 -e PYTHONDONTWRITEBYTECODE=1 -e OMP_NUM_THREADS=1 -e OPENBLAS_NUM_THREADS=1 -e MKL_NUM_THREADS=1 -e NUMBA_NUM_THREADS=1 -e PATH=/opt/omicstat/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin omicstat-r:2026.10.1 Rscript skills/seurat-markers/tests/run_smoke_test.R
```
Exit 0; raw log: `/home/<user>/omic-sol61/s3_m3m4/seurat-markers/smoke.log`.
```bash
docker run --rm --network none --user 1000:1000 -v /home/<user>/omic-s3m:/omicstat:ro -v /home/<user>/omic-sol61/s3_m3m4/seurat-markers:/scratch -v /home/<user>/omic-integrate/.omicstat-acceptance:/omicstat/.omicstat-acceptance:ro -w /omicstat -e HOME=/tmp/omicstat-home -e OMICSTAT_TEST_TMP=/scratch -e OMICSTAT_CONTAINER=1 -e OMICSTAT_IMAGE_ID=sha256:d77c48fe94fe3f06ded5af701246b0d06eaf823096b84529e620a2fc7cdde0c7 -e OMICSTAT_REQUIRE_LOCKED=1 -e PYTHONDONTWRITEBYTECODE=1 -e OMP_NUM_THREADS=1 -e OPENBLAS_NUM_THREADS=1 -e MKL_NUM_THREADS=1 -e NUMBA_NUM_THREADS=1 -e PATH=/opt/omicstat/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin omicstat-r:2026.10.1 Rscript tools/make_module_lock.R seurat-markers --check
```
Exit 0; raw log: `/home/<user>/omic-sol61/s3_m3m4/seurat-markers/lock.log`.

Golden must PASS rather than SKIP: verified in smoke assertions/log; smoke exit 0.
Lock evidence (exit 0):
```text
module_lock seurat-markers 1.0.0: OK (15 files)
```.

## Official workflow and anchor

Native FindAllMarkers and tutorial cluster-2 FindMarkers. 11648 rows; 7023 above log2FC1; IL32 1.324556; exact native table/contrast replay; strict final presto golden passes.

Locked documentary evidence: `/home/<user>/omic-s0-a/acceptance/exemplars/seurat-markers/L1_cran2026-09-15`. PACK C/D/F and S0_VERIFICATION_M3M4 §3/§4.3 were used with the owner’s slim-policy override. No literature counts were used to choose defaults. Statistics are delegated to the named native package functions; descriptive reshaping/ranking is distinguished from inference.

Smoke evidence:
```text
PASS PACK C PBMC archive hash 
PASS REPLAY native FindAllMarkers table 
PASS printed PBMC cell/cluster shape 
OBSERVED marker rows 11648 above log2FC 1 7023 
PASS REPLAY tutorial contrast gene identities 
PASS REPLAY contrast native log2FC 
OBSERVED contrast head IL32,LTB,CD3D,IL7R,LDHB IL32 FC 1.324556 
PASS real QC-cluster-marker chain 
PASS main result table golden 
PASS registered calls 
PASS locked defaults 
PASS no device leak 
```

## Options

Compared engine/entry/registry/options.md and SKILL.md. `42` documented option rows; all non-`none` S0 extraction keys exist in `/home/<user>/omic-s0-a/acceptance/exemplars/seurat-markers/literature/extraction.jsonl`. Both reference services and ask-user guidance are present. Mandatory scientific inputs and native JSON overrides were inspected; input/object names, output keys, serial execution and recorded seeds are transport/execution contracts, not inferred scientific defaults.
The exact options defects, if any, are listed in the closed repair list below.

## Outputs, Methods and handoffs

Native objects observed: 4 RDS/H5AD files; Methods drafts observed: 4. Native result columns/objects are retained except any explicitly listed repair. Methods names, package versions and run options were inspected against the engine and generated outputs. `--from-run` and chain-state evidence are in the smoke logs; real producer-chain supplement is recorded separately where needed.

## Figures

Opened every generated PNG through SHA256-indexed contact sheets (byte-identical repeats share the opened image). 10 unique PNG contents for this module, 10 figure specs. Inventory: `/home/<user>/omic-sol61/s3_m3m4/visual/inventory.json`; sheets: `sheet_000.jpg`, `sheet_001.jpg`, `sheet_005.jpg`, `sheet_006.jpg`. Captions reside in `*.figure_spec.json`, not necessarily inside PNG pixels. Suite builders/theme/palette and finalizer are used. Visual findings: Plots are nonblank, labels readable and not clipped; plotted quantities follow the package workflow. Captions record n and thresholds or explicitly state no cutoff.

## Known issues / scope

Archived 7019/1.3070772 are not reproduced. Difference is openly documented and not hidden by tolerance. Presto authorized golden change concerns P-value serialization, not this pre-existing FC difference.

## Closed repair list

1. `skills/seurat-markers/scripts/seurat_markers_core.R:8` — Forward an exposed base option in the FindMarkers contrast branch as well as FindAllMarkers; current --markers-base only reaches all mode. Keep native base=2 default; update registry/options and verify base=exp(1) changes native effect column identically in contrast before smoke/lock. Evidence: PACK C/D/F; owner slim options/output/figure requirements. Re-verify in the same locked image; no tolerance relaxation or silent golden replacement.
2. `skills/seurat-markers/scripts/seurat_markers_core.R:6` — Expose FindAllMarkers mean.fxn rather than fixing NULL, and bind a corresponding native mean.fxn option in contrast mode where applicable. Accept a documented supported native function name/RDS callable, keep the native NULL default and retain output column semantics. Re-verify the supplied function against direct native FindAllMarkers/FindMarkers and rerun strict goldens/lock. Evidence: PACK C/D/F; owner slim options/output/figure requirements. Re-verify in the same locked image; no tolerance relaxation or silent golden replacement.

VERDICT: FAIL
