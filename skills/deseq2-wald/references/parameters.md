# parameters -- deseq2-wald

One row per flag of `SPEC` in `scripts/run_deseq2_wald.R`. The "Default" column is machine-checked
against `--help` and `scripts/calls_registry.json` by `tools/check_defaults.py`. Section numbers
(D-xx) point to `acceptance/exemplars/deseq2-wald/PACK.md`, where each value is traced to the
DESeq2 vignette / reference manual of the installed version and the S1 decision is recorded.

## Flags

| Flag | Default | Allowed | Why |
|---|---|---|---|
| `--counts` | none | existing csv/tsv | raw integer counts, first column the feature id (DW-01/DW-02 guard it); exclusive with `--from-run` |
| `--samples` | none | existing csv/tsv | sample table; needs `--counts`; matched to matrix columns by id, never by position |
| `--from-run` | none | existing run directory | a deseq2-qc run handing on `count_matrix` and `sample_table` (`_shared/scripts/handoff.R`) |
| `--outdir` | (required) | writable directory | every module writes into one run directory |
| `--spec` | none | existing file | replay `provenance/resolved_spec.json`; flags given on the command line win |
| `--sample-col` | sample | column name | sample id column of the sample table |
| `--condition` | condition | column name | the compared factor; placed last in the design (D-01) |
| `--reference` | (required) | a level of `--condition` | denominator; the factor is releveled to it so the coefficient is `<condition>_<target>_vs_<reference>` (D-01) |
| `--target` | (required) | a level of `--condition` | numerator of the log2 fold change (D-01) |
| `--covariates` | none | comma-separated columns | extra design factors placed before the condition (e.g. batch, subject for paired designs) (D-01); with covariates `--min-samples` must be given explicitly (S1 P-3) |
| `--min-count` | 10 | integer >= 0 | vignette pre-filter "a count of at least 10" (D-11) |
| `--min-samples` | 0 | integer >= 0; 0 = smaller compared group | vignette: "the minimal number of samples ... the smallest group size" (D-11). 0 is accepted only for a simple two-group design: with `--covariates` or more than two levels in the condition column the run stops with `OS_MISSING_PARAMETER` until an explicit n is given (S1 P-3, owner 2026-09-27) |
| `--alpha` | 0.05 | (1e-6, 0.5] | FDR level used BOTH for independent filtering and as the significance cutoff; the vignette says alpha should equal the adjusted-P cutoff you report (D-08, S1) |
| `--lfc-threshold` | 0 | [0, 20] | null hypothesis of the Wald test (`results(lfcThreshold)`, log2 units); a prespecified minimum effect belongs here, not in a post hoc filter (D-07; S1 P-2) |
| `--display-lfc-filter` | 0 | [0, 20]; 0 = off | display-only filter in log2 units (S1 P-2): significant features with \|log2fc\| >= value are ALSO written to `tables/display_filtered.csv`; padj and the full tables are unchanged, the Methods state it separately (templates `methods_display`, `results_display`) |
| `--shrinkage` | apeglm | apeglm, ashr, normal, none | vignette recommends apeglm for ranking and visualization; P values always come from the unshrunken test (D-09) |
| `--fit-type` | parametric | parametric, local, mean | dispersion trend (`DESeq(fitType)`, also `vst(fitType)`) (D-03) |
| `--sf-type` | ratio | ratio, poscounts | median-of-ratios size factors; `poscounts` when every gene has a zero in some sample (D-04) |
| `--gene-annotation` | none | csv/tsv with `feature_id`, `symbol` | display symbols only; IDs stay the key (CONVENTIONS sec 8; DW-10) |
| `--top-n` | 50 | 2..500 | rows of the top heatmap (significant features, smallest padj first) |
| `--label-n` | 10 | 0..50 | labelled features per direction in volcano and MA plots |
| `--seed` | 20260925 | integer | recorded and set; the Wald / apeglm pipeline itself draws no random numbers |
| `--journal` | nature | nature, cell, science, generic | figure preset (`_shared/docs/FIGURE_STYLE.md`) |

## Fixed arguments (not flags)

Written out in the calls (lock 3) with the value shown; see `scripts/calls_registry.json`.

| Call | Argument = value | Why |
|---|---|---|
| `DESeq` | `test = "Wald"`, `useT = FALSE` | this module is the Wald test; the LRT is deseq2-lrt (D-02) |
| `DESeq` | `betaPrior = FALSE` | DESeq2 >= 1.16 default; shrinkage is done by `lfcShrink` instead (D-05) |
| `DESeq` | `minReplicatesForReplace = 7` | outlier replacement only with >= 7 replicates, vignette "Approach to count outliers" (D-06) |
| `results` | `cooksCutoff = TRUE` | the default 0.99 quantile of F(p, m - p); outliers get padj = NA and `filtered_reason = outlier` (D-06) |
| `results` | `independentFiltering = TRUE`, `pAdjustMethod = "BH"`, `altHypothesis = "greaterAbs"` | vignette defaults, written out (D-07, D-08) |
| `lfcShrink` | `coef = <condition>_<target>_vs_<reference>`, `res = <results>`, `apeAdapt = TRUE`, `apeMethod = "nbinomCR"`, `svalue = FALSE` | vignette call `lfcShrink(dds, coef = ..., type = "apeglm")`; passing `res` keeps the Wald P values (D-09) |
| `vst` / `varianceStabilizingTransformation` | `blind = FALSE`, `nsub = 1000` | for the heatmap only; `blind = FALSE` uses the design-aware dispersion trend (vignette "Blind dispersion estimation") (D-10) |
| `counts` | `normalized = TRUE` | size-factor-normalized counts table (display only) |
