# deseq2-wald: reporting templates

The engine fills **these exact blocks** (`os_read_templates()` reads every fenced block tagged `template <id>`), so the draft in `draft/methods_results.md` and this page cannot drift apart. Edit a template here and the next run uses it; every slot must stay in the table below, or the run stops with `OS_TEMPLATE_SLOT_MISSING`.

Wording follows PACK section W (acceptance/exemplars/deseq2-wald/PACK.md): software + version + function + the arguments that change results, in the order the analysis ran.

## Methods

```template methods
Differential expression was assessed with DESeq2 (v{deseq2_version}) in R (v{r_version}). Of {n_input} features in the count matrix, {n_tested} with a count of at least {min_count} in at least {min_samples} samples were retained (pre-filter recommended by the DESeq2 vignette). {sf_sentence} {disp_sentence} The design was {design}, and {target} (n = {n_target}) was compared with {reference} (n = {n_reference}) by a Wald test on the {condition} coefficient. {lfc_sentence} P values were adjusted with the Benjamini-Hochberg procedure; independent filtering on the mean of normalized counts targeted a false discovery rate of {alpha}, and Cook's distance flagged count outliers. {shrink_sentence} {vst_sentence}
```

Written only when `--display-lfc-filter` is above 0 (display-only filter, S1 P-2):

```template methods_display
For display only, significant features were additionally listed when the absolute {display_lfc_type} log2 fold change was at least {display_lfc_filter}; this filter was applied after the test, does not change the adjusted P values, and the filtered list carries no false discovery rate guarantee of its own.
```

## Results

```template results
Of {n_tested} features tested, {n_sig} had an adjusted P value below {alpha} when {target} was compared with {reference}: {n_up} with higher and {n_down} with lower expression in {target}.
```

Written only when some adjusted P values are NA:

```template results_na
Adjusted P values were not computed for {n_padj_na} features: {n_indep} were removed by independent filtering because of low mean counts, and {n_outlier} had a Cook's distance above the cutoff.
```

Written only when `--display-lfc-filter` is above 0:

```template results_display
Of these, {n_display} had an absolute {display_lfc_type} log2 fold change of at least {display_lfc_filter} (display-only list, tables/display_filtered.csv).
```

## Slots

| Slot | Engine field (`dw_template_values()`) |
|---|---|
| `{deseq2_version}` | `packageVersion("DESeq2")` |
| `{r_version}` | `getRversion()` |
| `{n_input}` | rows of the count matrix |
| `{n_tested}` | rows of `tables/feature_table.csv` |
| `{min_count}` | `--min-count` |
| `{min_samples}` | `--min-samples`, or the smaller compared group when it is 0 |
| `{design}` | design formula (`--covariates` + `--condition`) |
| `{condition}`, `{target}`, `{reference}` | `--condition`, `--target`, `--reference` |
| `{n_target}`, `{n_reference}` | samples in each compared group |
| `{alpha}` | `--alpha` |
| `{lfc_sentence}` | depends on `--lfc-threshold` (0 or a positive threshold) |
| `{shrink_sentence}` | depends on `--shrinkage` |
| `{shrink_pkg_version}` | apeglm / ashr version (used inside `{shrink_sentence}`) |
| `{sf_sentence}` | depends on `--sf-type` (`ratio` = median-of-ratios, `poscounts` = modified geometric mean of positive counts); DESeq() sfType |
| `{disp_sentence}` | depends on `--fit-type` (`parametric` / `local` / `mean` dispersion trend); DESeq() fitType |
| `{vst_sentence}` | the transformation actually used for the heatmap: `vst(blind = FALSE, nsub = 1000, fitType)` or, when fewer than 1000 features have a mean normalized count above 5 (the rows vst() subsamples from), `varianceStabilizingTransformation(blind = FALSE, fitType)` directly |
| `{n_sig}`, `{n_up}`, `{n_down}` | features with padj < `--alpha`; direction = sign of the Wald statistic |
| `{n_padj_na}`, `{n_indep}`, `{n_outlier}` | `filtered_reason` counts in the feature table |
| `{display_lfc_filter}` | `--display-lfc-filter` (log2 units; the display templates are used only when it is above 0) |
| `{display_lfc_type}` | the feature-table log2 fold change: `apeglm-shrunken` / `ashr-shrunken` / `normal-shrunken`, or `maximum-likelihood` with `--shrinkage none` |
| `{n_display}` | rows of `tables/display_filtered.csv` |

## What not to write

- **Fold-change filter after the test.** Calling genes "differentially expressed" when padj < alpha *and* |log2FC| > 1, with `--lfc-threshold 0`, reports a post hoc filter as if it were the test. The correct form: test against the threshold (`--lfc-threshold 1`), which the Methods sentence then states. A display-only list (`--display-lfc-filter`) is allowed, but it is described separately (templates `methods_display` / `results_display`) and never as a test result with the original FDR.
- **Linear and log2 units mixed.** Both `--lfc-threshold` and `--display-lfc-filter` are in log2 units: a 2-fold change is 1, a 1.5-fold change is log2(1.5) = 0.585. State the unit in the Methods.
- **Shrunken LFC with unshrunken P values described as one test.** The shrunken log2 fold change is for ranking and display; the P value belongs to the Wald test on the MLE. The Methods template says so; keep that sentence.
- **Supplied instead of tested features.** Report `{n_tested}` (after pre-filter), not the rows of the input matrix.
