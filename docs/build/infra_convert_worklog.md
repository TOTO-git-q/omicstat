# infra-convert worklog: single-cell object conversion layer

- Deliverable: `skills/_shared/scripts/convert.R` + `skills/_shared/tests/test_convert.R`
  (prerequisite for the ecosystem-neutral single-cell back ends, M3b).
- Local worktree: `E:/claude workspace/skills-dev/omic-infra-convert`, branch `infra/sc-convert`
  (from `origin/build/m1m2` at `2ddf174`). Push only `infra/sc-convert`.
- GT103 runtime mirror: `~/omic-infra-convert` (detached worktree of `~/omic-MCP`), logs in
  `~/omic-build-logs/infra-convert/`. Container `omicstat-r:2026.09.1`.
- Spec: ENGINEERING_PLAN v1.2 sec 1.3 (single-cell ecosystem rules), 10.3, part 3, part 8 G6;
  MODULE_BUILD_BRIEF sec 3-4.

## Steps

| # | step | status |
|---|---|---|
| 1 | read spec, probe the container (zellkonverter / basilisk / SeuratObject) | done |
| 2 | worklog + branch pushed, GT103 mirror created | done (`aafcaad`) |
| 3 | `convert.R` (Seurat <-> SCE <-> AnnData, checks, provenance step, typed errors) | done |
| 4 | minimal `handoff.R` additions (scverse ecosystem; chain ecosystem through neutral modules) | done |
| 5 | `test_convert.R` (round trips on pbmc_small, negative tests), registered in `tools/run_tests.sh` | done |
| 6 | run in container (as the calling user AND as root for the h5ad lane), fix, commit, push | done |
| 7 | final report | done |

## Verified facts

- 2026-09-29 container probe (`omicstat-r:2026.09.1`): zellkonverter 1.22.0, basilisk 1.24.0,
  SeuratObject 5.4.0, Seurat 5.5.1, SingleCellExperiment 1.34.0 present; anndataR absent.
- The basilisk env `zellkonverterAnnDataEnv-0.12.3` (python 3.14, anndata 0.12.3) IS prebuilt,
  but under `/root/.cache/R/basilisk/1.24.0/zellkonverter/1.22.0/`; `/root` is mode 700.
  `bin/omicstat-r-route.sh` runs the container with `--user $(id -u):$(id -g)`, so in the
  production path the env is unreachable and basilisk would try to download conda (network)
  on first use. As root with `--network none` the env works (probe3: python reader round trip
  keeps factor levels incl. non-alphabetical order, logical columns, reducedDim names and
  colnames, counts identical).
- zellkonverter `readH5AD(reader = "R")` drops every obsm (reducedDims fail with a dimension
  error) -> the R reader cannot satisfy "carry embeddings"; only the python reader is used.
- Fixture: `SeuratObject::pbmc_small` (80 cells x 230 genes, a real pbmc3k subsample shipped
  in the locked package; counts integer, clusters RNA_snn_res.0.8 / RNA_snn_res.1, pca, tsne).

- 2026-09-29 test_convert.R in the container (`--network none`, mirror mounted read-only):
  as root (h5ad lane live) 98 PASS / 0 SKIP / 0 FAIL; as the calling user (the router's mode)
  85 PASS / 1 SKIP (AnnData round trips; OS_ENV_MISSING asserted instead) / 0 FAIL.
  `test_omics_shared.R` after the handoff.R change: ALL PASSED. `tools/lint_r.py` on
  convert.R + handoff.R: 0 problems. ASCII only.
- The post-conversion check caught three real Seurat -> AnnData losses during development
  (all fixed, all now tested): anndata writes string columns as categoricals (fixed by a
  JSON marker in uns["omicstat_convert"] naming the character columns; files without the
  marker keep their categoricals as factors), character columns with NA (same fix, NA kept),
  and uwot's "scaled:center" attribute on the UMAP matrix (obsm holds coordinates only; the
  fingerprint covers coordinates + column names, the attribute loss is listed in
  step$not_carried).
- Probe 8: `Seurat::as.SingleCellExperiment` upper-cases reduction names (pca -> PCA, tsne ->
  TSNE) and adds an `ident` colData column, and `as.Seurat` keeps both changes: they do not
  carry objects "as they are", so convert.R builds with the constructors
  (SingleCellExperiment(), CreateAssay5Object/CreateSeuratObject/CreateDimReducObject).
  The h5ad written twice from the same object is byte-identical (sha256 equal).
- Seurat -> SCE on pbmc_small: 0.12 s.

## NEXT STEP

None. Final re-run on the pushed commit c109017 (GT103 mirror reset to it, tested files sha256-equal): root 98 PASS, calling user 85 PASS + 1 SKIP. DONE.

## 待裁决

1. Image defect (owner / env decision, not fixable here without a rebuild): the basilisk
   anndata env is prebuilt under `/root/.cache/R/basilisk` (`/root` mode 700) while the router
   runs the container as the calling user, so AnnData conversion is refused in production with
   `OS_ENV_MISSING` (never a download). Fix options for the next env_version: build with
   `ENV BASILISK_EXTERNAL_DIR=/opt/omicstat/basilisk` (world-readable) before the prebuild
   RUN and keep it in the runtime env, or install zellkonverter with
   `BASILISK_USE_SYSTEM_DIR=1`. convert.R already honours both variables.
2. Constructors instead of `as.SingleCellExperiment` / `as.Seurat` (reason: probe 8 above).
   The plan text names those functions as examples; confirm the substitution.
3. Not carried (listed per step in `not_carried`): PCA loadings / stdev, scale.data, graphs,
   neighbours, images, commands, other assays/layers, SCE metadata/altExps/pairs, AnnData
   uns/varm/obsp/varp/raw. Back ends do not re-reduce, so none is needed downstream.
4. `OS_CONVERT_LAYER_ROLE` heuristic for logcounts: identical to counts, or integer-valued with
   max > 30. The 30 is a guard value, not from a PACK.
5. Chain ecosystem through neutral modules is stored in `state$front_end_ecosystem` (no
   handoff schema change); neutral modules must pass `os_sc_chain_state(h)` into
   `write_handoff(state = ...)`. To be written into the M3b module brief.
6. Documentation left to the coordinator (files others edit): MODULE_BUILD_BRIEF sec 3 needs
   an `AnnData` row (`.h5ad`, ecosystem scverse); CONVENTIONS sec 3 should list the new
   `OS_CONVERT_*` family (LAYER_MISSING, LAYER_ROLE, UNSUPPORTED, MISMATCH).
