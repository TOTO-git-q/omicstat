# cellchat-communication — independent S3 review

Reviewed source commit: `d7355bec9aa73496eba8e2c548a55415455e0508` (branch `s3/m3m4`). Review-only files are excluded from the implementation under review. No module source, golden or lock was changed.

Environment: `omicstat-r:2026.10.1`; image ID `sha256:d77c48fe94fe3f06ded5af701246b0d06eaf823096b84529e620a2fc7cdde0c7`. Non-root, network disabled; suite and acceptance-library mounts read-only; lane scratch writable. `OMICSTAT_WRITE_GOLDEN` was not set.

## Commands and runtime evidence

```bash
docker run --rm --network none --user 1000:1000 -v /home/<user>/omic-s3m:/omicstat:ro -v /home/<user>/omic-sol61/s3_m3m4/cellchat-communication:/scratch -v /home/<user>/omic-integrate/.omicstat-acceptance:/omicstat/.omicstat-acceptance:ro -w /omicstat -e HOME=/tmp/omicstat-home -e OMICSTAT_TEST_TMP=/scratch -e OMICSTAT_CONTAINER=1 -e OMICSTAT_IMAGE_ID=sha256:d77c48fe94fe3f06ded5af701246b0d06eaf823096b84529e620a2fc7cdde0c7 -e OMICSTAT_REQUIRE_LOCKED=1 -e PYTHONDONTWRITEBYTECODE=1 -e OMP_NUM_THREADS=1 -e OPENBLAS_NUM_THREADS=1 -e MKL_NUM_THREADS=1 -e NUMBA_NUM_THREADS=1 -e PATH=/opt/omicstat/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin omicstat-r:2026.10.1 Rscript skills/cellchat-communication/tests/run_smoke_test.R
```
Exit 0; raw log: `/home/<user>/omic-sol61/s3_m3m4/cellchat-communication/smoke.log`.
```bash
docker run --rm --network none --user 1000:1000 -v /home/<user>/omic-s3m:/omicstat:ro -v /home/<user>/omic-sol61/s3_m3m4/cellchat-communication:/scratch -v /home/<user>/omic-integrate/.omicstat-acceptance:/omicstat/.omicstat-acceptance:ro -w /omicstat -e HOME=/tmp/omicstat-home -e OMICSTAT_TEST_TMP=/scratch -e OMICSTAT_CONTAINER=1 -e OMICSTAT_IMAGE_ID=sha256:d77c48fe94fe3f06ded5af701246b0d06eaf823096b84529e620a2fc7cdde0c7 -e OMICSTAT_REQUIRE_LOCKED=1 -e PYTHONDONTWRITEBYTECODE=1 -e OMP_NUM_THREADS=1 -e OPENBLAS_NUM_THREADS=1 -e MKL_NUM_THREADS=1 -e NUMBA_NUM_THREADS=1 -e PATH=/opt/omicstat/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin omicstat-r:2026.10.1 Rscript tools/make_module_lock.R cellchat-communication --check
```
Exit 0; raw log: `/home/<user>/omic-sol61/s3_m3m4/cellchat-communication/lock.log`.

Golden must PASS rather than SKIP: verified in smoke assertions/log; smoke exit 0.
Lock evidence (exit 0):
```text
module_lock cellchat-communication 1.0.0: OK (10 files)
```.

## Official workflow and anchor

Locked human skin LS 17328 genes,5011 cells,12 labels: createCellChat/DB subset/subsetData -> identifyOverExpressedGenes/Interactions -> computeCommunProb(triMean,raw) -> filterCommunication -> pathway -> aggregateNet -> subsetCommunication -> centrality. Both do.fast=FALSE Wilcoxon and default TRUE presto branches sealed separately.

Locked documentary evidence: `/home/<user>/omic-s3m/acceptance/exemplars/cellchat-communication/L1_github`. PACK C/D/F and S0_VERIFICATION_M3M4 §3/§4.3 were used with the owner’s slim-policy override. No literature counts were used to choose defaults. Statistics are delegated to the named native package functions; descriptive reshaping/ranking is distinguished from inference.

Smoke evidence:
```text
PASS: PACK C anchor, native output, --from-run chain equality, static calls/default drift and golden
PASS: default do.fast=TRUE human skin anchor and explicit Wilcoxon goldens; old golden retained
```

## Options

Compared engine/entry/registry/options.md and SKILL.md. `94` documented option rows; all non-`none` S0 extraction keys exist in `/home/<user>/omic-s3m/acceptance/exemplars/cellchat-communication/literature/extraction.jsonl`. Both reference services and ask-user guidance are present. Mandatory scientific inputs and native JSON overrides were inspected; input/object names, output keys, serial execution and recorded seeds are transport/execution contracts, not inferred scientific defaults.
The exact options defects, if any, are listed in the closed repair list below.

## Outputs, Methods and handoffs

Native objects observed: 9 RDS/H5AD files; Methods drafts observed: 4. Native result columns/objects are retained except any explicitly listed repair. Methods names, package versions and run options were inspected against the engine and generated outputs. `--from-run` and chain-state evidence are in the smoke logs; real producer-chain supplement is recorded separately where needed.

Independent real producer chain: `{
  "exits": [
    0,
    0
  ],
  "upstream": "actual CellChat anchor producer -> CellChat consumer; hash-verified saved SCE with native logcounts",
  "native_anchor_bytes_equal": true,
  "table": "tables/communication.csv",
  "scope": "The official skin input has normalized expression only; attempted scater-qc producer correctly refused absent raw counts. No invented count assay was added. Both attempts and commands retained.",
  "ecosystem": "bioconductor front_end_ecosystem; neutral backend"
}`. Commands/logs: `/home/<user>/omic-sol61/s3_m3m4/cellchat-communication/real_chain_*.command.json` / `real_chain_*.log`.

## Figures

Opened every generated PNG through SHA256-indexed contact sheets (byte-identical repeats share the opened image). 2 unique PNG contents for this module, 8 figure specs. Inventory: `/home/<user>/omic-sol61/s3_m3m4/visual/inventory.json`; sheets: `sheet_020.jpg`. Captions reside in `*.figure_spec.json`, not necessarily inside PNG pixels. Suite builders/theme/palette and finalizer are used. Visual findings: Plots are nonblank, labels readable and not clipped; plotted quantities follow the package workflow. Captions record n and thresholds or explicitly state no cutoff.

## Known issues / scope

raw.use=FALSE explicitly refuses unsupported projectData in this pin. Required DB species/subset; transcriptomic inference caveat. Equal-node circle intentionally omits autocrine edges; caption discloses that and heatmap/native tables retain them.

## Closed repair list

None. Notes are limitations/documentation observations, not permission to alter scientific defaults.

VERDICT: PASS WITH NOTES
