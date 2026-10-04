# parameters -- deseq2-qc

One row per flag of `SPEC` in `scripts/run_deseq2_qc.R`. The "Default" column is machine-checked
against `--help` and `scripts/calls_registry.json` by `tools/check_defaults.py`. Section numbers
(D-QCxx) point to `acceptance/exemplars/deseq2-qc/PACK.md`, where each value is traced to the
DESeq2 vignette / reference manual of the installed version and the S1 decision is recorded.

## Flags

| Flag | Default | Allowed | Why |
|---|---|---|---|
| `--counts` | (required) | existing csv/tsv | raw integer counts, first column the feature id (DQ-01/DQ-02 guard it); no `--from-run` for input -- deseq2-qc has no upstream |
| `--samples` | (required) | existing csv/tsv | sample table; matched to matrix columns by id, never by position |
| `--outdir` | (required) | writable directory | every module writes into one run directory |
| `--spec` | none | existing file | replay `provenance/resolved_spec.json`; flags given on the command line win |
| `--sample-col` | sample | column name | sample id column of the sample table |
| `--condition` | condition | column name | the biological group used to colour PCA/distance figures and placed last in the design (D-QC1) |
| `--shape-col` | none | column name | an optional second sample-table column used as the PCA point shape, e.g. `type` (vignette `plotPCA(vsd, intgroup=c("condition","type"))`) |
| `--covariates` | none | comma-separated columns | extra design factors placed before `--condition` (e.g. batch); affects only the `--blind-false-supplement` transform and the Methods text, since `blind = TRUE` ignores the design internally |
| `--min-count` | 10 | integer >= 0 | vignette pre-filter "a count of at least 10" (D-11, same rule as deseq2-wald) |
| `--min-samples` | 0 | integer >= 0; 0 = smaller `--condition` level (simple design only) | vignette "the minimal number of samples" (`smallestGroupSize`); with `--covariates` or 3+ condition levels an explicit value is required, else `OS_MISSING_PARAMETER` (BUILDER_BRIEF sec 6, deseq2-wald P-3 pattern) (D-11) |
| `--transform` | vst | vst, rlog | S1 P-1: vst is the default (majority 18/20, and the vignette's speed recommendation); rlog is offered as the documented alternative (D-QC1) |
| `--fit-type` | parametric | parametric, local, mean | dispersion trend fit passed to `vst`/`rlog`/`varianceStabilizingTransformation` (D-QC6) |
| `--sf-type` | ratio | ratio, poscounts | median-of-ratios size factors (`estimateSizeFactors(type=)`); `poscounts` when every gene has a zero in some sample -- same convention as deseq2-wald's `--sf-type`, not itself a fresh PACK row of this module (S2 consistency choice) |
| `--ntop` | 500 | 10..100000 | most-variable features used for the PCA; `plotPCA` default (D-QC3) |
| `--blind-false-supplement` | off | switch | S1 P-1: an OPTIONAL supplementary blind = FALSE PCA figure and matrix, requested explicitly; never replaces the primary blind = TRUE QA output and never removes a biological group |
| `--seed` | 20260925 | integer | recorded and set; this pipeline draws no random numbers |
| `--journal` | nature | nature, cell, science, generic | figure preset (`_shared/docs/FIGURE_STYLE.md`) |

## Fixed arguments (not flags)

Written out in the calls (lock 3) with the value shown; see `scripts/calls_registry.json`.

| Call | Argument = value | Why |
|---|---|---|
| `DESeqDataSetFromMatrix` | `tidy = FALSE`, `ignoreRank = FALSE` | vignette defaults, written out (D-00) |
| `DESeqDataSetFromMatrix` | `design = ~ <covariates> + <condition>` | builds a valid `DESeqDataSet`; `blind = TRUE` ignores this design internally when estimating the QA dispersion trend (D-QC1) |
| `estimateSizeFactors` | `type = "ratio"` (`--sf-type`) | median-of-ratios size factors, explicit even though it equals the function default (lock 3) |
| `vst` / `rlog` / `varianceStabilizingTransformation` | `blind = TRUE` (primary), `blind = FALSE` (only with `--blind-false-supplement`) | S1 P-1: QA is blind by design; the optional supplement is explicitly labelled and never the default (D-QC1, D-QC2) |
| `vst` | `nsub = 1000` | vignette default; when fewer than 1,000 pre-filtered rows have mean normalized count > 5, the engine falls back to `varianceStabilizingTransformation` automatically (DQ-05; PACK X) (D-QC6) |
| `vst` / `rlog` / `varianceStabilizingTransformation` | `fitType = "parametric"` (`--fit-type`) | vignette default dispersion trend (D-QC6) |

## Not exposed as flags (fixed by the shared PCA/distance builders, not by this module)

| Value | Where | Why |
|---|---|---|
| `ntop` most-variable rows selected by row variance, `prcomp(center=TRUE, scale.=FALSE)`, PCA sign normalization | `_shared/scripts/fig_bulk.R::os_pca_scores` (the `plotPCA` computation -- same row selection and `prcomp` -- with variance ties broken by feature id and each component's sign fixed by ENGINEERING_PLAN lock 4, so a component can differ from `plotPCA` by a whole-column sign; checked against `plotPCA(returnData=TRUE)` in the smoke test) | shared across every module that plots a sample PCA; changing it is a `_shared` change, not a per-module flag |
| PCs 1:2 | `os_pca_plot` | PACK F: "PC1 vs PC2"; `plotPCA`'s own default `pcsToUse = 1:2` (D-QC3) |
| Euclidean distance, hierarchical clustering (complete linkage) | `_shared/scripts/fig_bulk.R::os_sample_distance` | vignette `dist(t(assay(vsd)))` (D-QC4) |
