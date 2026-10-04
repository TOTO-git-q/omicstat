# S3 independent review request: limma-voom 1.0.1

Review the S2 implementation against PACK S1 appendix P-1..P-3 and locked edgeR/limma defaults. No independent S3 judgment has been made in this lane.

## Anchor and run

- F4 GSE63310: `acceptance/data/GSE63310_RAW.tar`, sha256 `d2567b6753711e86820acbed4a4786ea1c57c59212503a8622b56982bcd53e44` (ANCHOR_REGISTRY row 5). The fixture uses the first 5 sorted count files, the first 5000 features, and an explicit 2-vs-3 contrast. These group labels are a test grouping, not the published biological contrast. This is a replay anchor, not a printed guide value.
- Container run: `/home/<user>/omic-build-logs/build_m1b/limma-voom-smoke/a0/`. 5000 input genes, 3320 tested after `filterByExpr`, 17 BH discoveries at 0.05. Direct locked-package replay of raw and adjusted P values passed within CSV precision. The complete table and figure specs passed byte-identical `--spec` replay; `treat`, display filter, legacy route, handoff and typed-error checks passed.
- `tests/golden_manifest.csv` and `module_lock.json` were generated in `omicstat-r:2026.09.1` (R 4.6.1, edgeR 4.10.5, limma 3.68.5). Figures in that run were opened and reviewed: volcano labels and count key are distinct, MD has no labels to collide, neither is clipped; captions state n and BH threshold.

## Needs owner confirmation: proposed `voomLmFit` call set

The new locked Rd/formals and sha256 are in `L1_bioc3.23/manifest.tsv`. Proposed default call:

`edgeR::voomLmFit(counts=dge, design=model$design, block=NULL, prior.weights=NULL, sample.weights=FALSE, var.design=NULL, var.group=NULL, prior.n=10, lib.size=NULL, offset=NULL, offset.prior=NULL, normalize.method="none", span=0.5, adaptive.span=TRUE, plot=FALSE, save.plot=FALSE, keep.EList=TRUE)`.

The explicit `--sample-weights` switch changes only `sample.weights` to TRUE. Estimated, named per-sample weights are recorded in `results/limma_results.json`; the smoke test checks that this flag changes the fit. The returned `MArrayLM` is handed on as `fit`, and its `EList` member is saved as `elist` for expression values and voom weights. The older `voom`/`lmFit` path is available only with `--interface legacy`; with sample weights it calls `voomWithQualityWeights` then `lmFit`. Review downstream camera and GSVA contracts against `MArrayLM`/`EList` before S5.

For optional `treat`, this build uses `fc=<user linear FC>` and `lfc=log2(fc)` together, as the PACK's interim suggestion; owner confirmation is pending.

## Proposed installation records

Router row: `| bulk RNA-seq count differential expression, voom, TMM, RNA测序差异表达 | limma-voom | scripts/run_limma_voom.R |`

Rules record: `{ "id": "PUB-M-LIMV-001", "module": "limma-voom", "category": "design_conditional", "rule": "Use raw counts with a full-rank replicate design; distinguish the zero-effect test, prespecified treat threshold, and display-only filter; report the fit interface and estimated sample weights." }`

Known limitation: this S2 anchor subset replays the new interface but does not assert RNAseq123's published contrast values. S3 should also review the 2-sample group and the placement of the new `EList` handoff.

Version 1.0.1 refreshes the shared MD rendering and its golden and adds per-sample weight reporting. The inferential default remains the same.
