# deseq2-qc: reporting templates

The engine fills **these exact blocks** (`os_read_templates()` reads every fenced block tagged `template <id>`), so the draft in `draft/methods_results.md` and this page cannot drift apart. Edit a template here and the next run uses it; every slot must stay in the table below, or the run stops with `OS_TEMPLATE_SLOT_MISSING`.

Wording follows PACK section W (`acceptance/exemplars/deseq2-qc/PACK.md`): software + version + function + the arguments that change results, in the order the analysis ran, stating the transform's purpose and its `blind` value (S1 P-1).

## Methods

```template methods
Sample-level quality assessment was performed with DESeq2 (v{deseq2_version}) in R (v{r_version}) before any differential test. Of {n_input} features in the count matrix, {n_tested} with a count of at least {min_count} in at least {min_samples} samples were retained. Size factors were estimated with DESeq2::estimateSizeFactors(type = "{sf_type}"). Counts were transformed with {transform_detail}; blind = TRUE re-estimates the dispersion trend using only an intercept so that the transformation is unbiased by the experimental design ({design}). This setting is for sample QA, not for downstream differential testing. {supplement_detail} Principal component analysis used the {ntop} most variable features of the primary transformed matrix (centred, not scaled); a Euclidean sample-to-sample distance matrix was computed using all {n_tested} retained features of that transformed matrix. No sample or biological group was removed automatically at any step.
```

## Results

```template results
Across {n_samples} samples, the first two principal components explained {pc1_pct}% and {pc2_pct}% of the variance among the {ntop} most variable features. A descriptive per-sample table (PC1/PC2 scores and size factor) is provided in tables/sample_qc_descriptive.csv for manual review.
```

## Note on sample-outlier review (interim, PACK P-2 pending)

```template outlier_note
This module does not compute or apply a numeric sample-outlier statistic or threshold: DESeq2 does not define one for sample-level QC (Cook's distance is a per-gene, not a per-sample, diagnostic). The per-sample table is descriptive only; no sample was flagged, scored against a cutoff, or removed by this run. Any sample exclusion decision must be made by a person reviewing the PCA and sample-distance figures directly, and reported as such.
```

## Slots

| Slot | Engine field (`dq_template_values()`) |
|---|---|
| `{deseq2_version}` | `packageVersion("DESeq2")` |
| `{r_version}` | `getRversion()` |
| `{n_input}` | rows of the count matrix |
| `{n_tested}` | rows of the transformed (post-pre-filter) matrix |
| `{min_count}` | `--min-count` |
| `{min_samples}` | `--min-samples`, or the smaller/only-explicit resolved value when 0 was given |
| `{design}` | design formula (`--covariates` + `--condition`) |
| `{condition}` | `--condition` |
| `{transform}` | `--transform` (`vst` or `rlog`) |
| `{transform_detail}` | actual primary function, blind value, nsub and fitType; states the fallback when used |
| `{sf_type}` | `--sf-type` passed to `estimateSizeFactors` |
| `{supplement_detail}` | whether the design-aware `blind = FALSE` supplement was produced and its actual function |
| `{ntop}` | features used for PCA (`--ntop`, or fewer if the transformed matrix has fewer rows) |
| `{pc1_pct}`, `{pc2_pct}` | percent variance of PC1 / PC2 |
| `{n_samples}` | samples in the input |

## What not to write

- **"Outlier samples were removed."** This module never removes a sample. If a person removes one after reviewing the figures, that is a separate, reported, manual decision -- not an output of this run.
- **Treating the descriptive table as a QC verdict.** Its PC scores and size factors have no sample-outlier threshold; do not call a row "an outlier" because of its values.
- **Using the blind = TRUE matrix to claim there is, or is not, a group difference.** Blind dispersion estimation is deliberately unbiased by the design; it is for QA, not for reading off effect sizes. Use deseq2-wald / deseq2-lrt for that question.
