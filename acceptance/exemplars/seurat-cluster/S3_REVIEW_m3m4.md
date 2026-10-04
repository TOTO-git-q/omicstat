# seurat-cluster — independent S3 review

Reviewed source commit: `d7355bec9aa73496eba8e2c548a55415455e0508` (branch `s3/m3m4`). Review-only files are excluded from the implementation under review. No module source, golden or lock was changed.

Environment: `omicstat-r:2026.10.1`; image ID `sha256:d77c48fe94fe3f06ded5af701246b0d06eaf823096b84529e620a2fc7cdde0c7`. Non-root, network disabled; suite and acceptance-library mounts read-only; lane scratch writable. `OMICSTAT_WRITE_GOLDEN` was not set.

## Commands and runtime evidence

```bash
docker run --rm --network none --user 1000:1000 -v /home/<user>/omic-s3m:/omicstat:ro -v /home/<user>/omic-sol61/s3_m3m4/seurat-cluster:/scratch -v /home/<user>/omic-integrate/.omicstat-acceptance:/omicstat/.omicstat-acceptance:ro -w /omicstat -e HOME=/tmp/omicstat-home -e OMICSTAT_TEST_TMP=/scratch -e OMICSTAT_CONTAINER=1 -e OMICSTAT_IMAGE_ID=sha256:d77c48fe94fe3f06ded5af701246b0d06eaf823096b84529e620a2fc7cdde0c7 -e OMICSTAT_REQUIRE_LOCKED=1 -e PYTHONDONTWRITEBYTECODE=1 -e OMP_NUM_THREADS=1 -e OPENBLAS_NUM_THREADS=1 -e MKL_NUM_THREADS=1 -e NUMBA_NUM_THREADS=1 -e PATH=/opt/omicstat/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin omicstat-r:2026.10.1 Rscript skills/seurat-cluster/tests/run_smoke_test.R
```
Exit 0; raw log: `/home/<user>/omic-sol61/s3_m3m4/seurat-cluster/smoke.log`.
```bash
docker run --rm --network none --user 1000:1000 -v /home/<user>/omic-s3m:/omicstat:ro -v /home/<user>/omic-sol61/s3_m3m4/seurat-cluster:/scratch -v /home/<user>/omic-integrate/.omicstat-acceptance:/omicstat/.omicstat-acceptance:ro -w /omicstat -e HOME=/tmp/omicstat-home -e OMICSTAT_TEST_TMP=/scratch -e OMICSTAT_CONTAINER=1 -e OMICSTAT_IMAGE_ID=sha256:d77c48fe94fe3f06ded5af701246b0d06eaf823096b84529e620a2fc7cdde0c7 -e OMICSTAT_REQUIRE_LOCKED=1 -e PYTHONDONTWRITEBYTECODE=1 -e OMP_NUM_THREADS=1 -e OPENBLAS_NUM_THREADS=1 -e MKL_NUM_THREADS=1 -e NUMBA_NUM_THREADS=1 -e PATH=/opt/omicstat/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin omicstat-r:2026.10.1 Rscript tools/make_module_lock.R seurat-cluster --check
```
Exit 0; raw log: `/home/<user>/omic-sol61/s3_m3m4/seurat-cluster/lock.log`.

Golden must PASS rather than SKIP: verified in smoke assertions/log; smoke exit 0.
Lock evidence (exit 0):
```text
module_lock seurat-cluster 1.0.0: OK (15 files)
```.

## Official workflow and anchor

PBMC3k NormalizeData -> FindVariableFeatures(vst,2000) -> ScaleData -> RunPCA -> FindNeighbors(1:10) -> FindClusters(0.5) -> RunUMAP. 2638 nodes,95927 edges,9 communities; native PCA/labels replay.

Locked documentary evidence: `/home/<user>/omic-s0-a/acceptance/exemplars/seurat-cluster/L1_cran2026-09-15`. PACK C/D/F and S0_VERIFICATION_M3M4 §3/§4.3 were used with the owner’s slim-policy override. No literature counts were used to choose defaults. Statistics are delegated to the named native package functions; descriptive reshaping/ranking is distinguished from inference.

Smoke evidence:
```text
PASS PRINTED PBMC 2638 graph nodes 
PASS PRINTED PBMC nine communities 
PASS PRINTED PBMC 95927 graph edges 
PASS tutorial 2000 HVGs 
PASS native reduction shape 
OBSERVED communities 9 first five 2,3,2,1,6 SNN nonzero 194492 
PASS REPLAY native community identities 
PASS REPLAY PCA 
PASS from-run chain state 
PASS main tables golden 
```

## Options

Compared engine/entry/registry/options.md and SKILL.md. `81` documented option rows; all non-`none` S0 extraction keys exist in `/home/<user>/omic-s0-a/acceptance/exemplars/seurat-cluster/literature/extraction.jsonl`. Both reference services and ask-user guidance are present. Mandatory scientific inputs and native JSON overrides were inspected; input/object names, output keys, serial execution and recorded seeds are transport/execution contracts, not inferred scientific defaults.
The exact options defects, if any, are listed in the closed repair list below.

## Outputs, Methods and handoffs

Native objects observed: 2 RDS/H5AD files; Methods drafts observed: 2. Native result columns/objects are retained except any explicitly listed repair. Methods names, package versions and run options were inspected against the engine and generated outputs. `--from-run` and chain-state evidence are in the smoke logs; real producer-chain supplement is recorded separately where needed.

Supplemental mixed_frontend command:
```bash
docker run --rm --network none --user 1000:1000 -v /home/<user>/omic-s3m:/omicstat:ro -v /home/<user>/omic-sol61/s3_m3m4/seurat-cluster:/scratch -v /home/<user>/omic-integrate/.omicstat-acceptance:/omicstat/.omicstat-acceptance:ro -w /omicstat -e HOME=/tmp/omicstat-home -e OMICSTAT_TEST_TMP=/scratch -e OMICSTAT_CONTAINER=1 -e OMICSTAT_IMAGE_ID=sha256:d77c48fe94fe3f06ded5af701246b0d06eaf823096b84529e620a2fc7cdde0c7 -e OMICSTAT_REQUIRE_LOCKED=1 -e PYTHONDONTWRITEBYTECODE=1 -e OMP_NUM_THREADS=1 -e OPENBLAS_NUM_THREADS=1 -e MKL_NUM_THREADS=1 -e NUMBA_NUM_THREADS=1 -e PATH=/opt/omicstat/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin -v /home/<user>/omic-sol61/s3_m3m4:/review:ro omicstat-r:2026.10.1 Rscript skills/seurat-cluster/scripts/run_seurat_cluster.R --from-run /review/scran-cluster/scran-cluster-smoke/anchor --normalization LogNormalize --n-hvg 1000 --n-pcs 15 --dims 10 --neighbors 10 --umap-neighbors 15 --resolution 0.5 --outdir /scratch/mixed_refused
```
Raw log: `/home/<user>/omic-sol61/s3_m3m4/seurat-cluster/mixed_frontend.log`.

## Figures

Opened every generated PNG through SHA256-indexed contact sheets (byte-identical repeats share the opened image). 6 unique PNG contents for this module, 6 figure specs. Inventory: `/home/<user>/omic-sol61/s3_m3m4/visual/inventory.json`; sheets: `sheet_000.jpg`, `sheet_001.jpg`. Captions reside in `*.figure_spec.json`, not necessarily inside PNG pixels. Suite builders/theme/palette and finalizer are used. Visual findings: Plots are nonblank, labels readable and not clipped; plotted quantities follow the package workflow. Captions record n and thresholds or explicitly state no cutoff.

## Known issues / scope

Alternate SCTransform route exists; smoke covers LogNormalize.

## Closed repair list

1. `skills/seurat-cluster/scripts/seurat_cluster_core.R:7` — Expose FindClusters initial.membership and node.sizes rather than fixing NULL; add documented native JSON/RDS options with locked NULL defaults and keys none. Re-verify a small graph with supplied initial membership/node weights against direct native calls; then smoke and lock check. Evidence: PACK C/D/F; owner slim options/output/figure requirements. Re-verify in the same locked image; no tolerance relaxation or silent golden replacement.
2. `skills/seurat-cluster/scripts/seurat_cluster_core.R:4` — Expose the additional fixed native scientific controls mean.function/dispersion.function (for the mean.var.plot/dispersion routes) and SCTransform reference.SCT.model/residual.features; provide documented named native function or RDS bindings, keeping locked defaults. Re-verify a native alternate HVG function configuration and supplied SCT reference/residual feature set on a small valid fixture, then smoke and lock. Evidence: PACK C/D/F; owner slim options/output/figure requirements. Re-verify in the same locked image; no tolerance relaxation or silent golden replacement.

VERDICT: FAIL
