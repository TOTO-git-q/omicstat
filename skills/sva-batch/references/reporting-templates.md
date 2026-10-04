# sva-batch: reporting templates

The engine fills **these exact blocks** (`os_read_templates()` reads every fenced block tagged
`template <id>`), so the draft in `draft/methods_results.md` and this page cannot drift apart.
Edit a template here and the next run uses it; every slot must stay in the table below, or the
run stops with `OS_TEMPLATE_SLOT_MISSING`.

Wording follows PACK section W (`acceptance/exemplars/sva-batch/PACK.md`): sva/limma + version +
function + batch variable + preserved biological covariates + what the corrected matrix is used
for -- the L3 corpus showed most exemplars omit the preserved covariate and the intended use, so
the template states both every time.

## Methods

```template methods
Batch correction was performed with {method_label} (sva v{sva_version} / limma v{limma_version}) in R (v{r_version}) for {design_sentence}. {model_sentence} {parameter_sentence} {sv_sentence}{prior_sentence} The corrected matrix ({n_features} features, {n_samples} samples) was used only for visualization (principal component analysis) and downstream descriptive scoring; it was never used as the input to a differential expression test (the uncorrected data, with the batch or surrogate variables added to the design instead, is the legitimate DE input).
```

## Results

```template results
Sample principal component analysis (Figure "batch_pca") shows the effect of the correction on the sample structure; see tables/batch_report.md for the batch/study-variable design details and tables/corrected_matrix.csv for the display matrix.
```

## Slots

| Slot | Engine field (`sb_template_values()`) |
|---|---|
| `{method_label}` | "ComBat" / "ComBat-seq" / "sva" / "svaseq" (from `--method`) |
| `{sva_version}` | `packageVersion("sva")` |
| `{limma_version}` | `packageVersion("limma")` |
| `{r_version}` | `getRversion()` |
| `{design_sentence}` | known batch + protected variables (combat/combat_seq), or "an unknown source of variation" + protected variables (sva/svaseq) |
| `{model_sentence}` | the actual protected design and fitted model (ComBat / ComBat-seq: `mod` or `group` + `covar_mod`, and the per-feature model with the batch indicators ComBat adds itself), or the full and null model formulas (sva/svaseq) -- `sb_model_formulas()`, user column names |
| `{parameter_sentence}` | the values the calls received (`r$calls`): ComBat `par.prior`/`mean.only`/`ref.batch`; ComBat_seq `full_mod`/`shrink`/`shrink.disp`/`gene.subset.n`/`covar_mod`; num.sv `method`/`B`/`seed`/`vfilter`; sva/svaseq `method`/`B` iterations/`vfilter`/`controls` (+ `constant`) |
| `{sv_sentence}` | number of surrogate variables and the display-only removeBatchEffect call (sva/svaseq), or the joint-design estimability check and confounding status (combat/combat_seq) |
| `{prior_sentence}` | ComBat only: one sentence pointing to the prior diagnostic (Figure "combat_prior", `tables/combat_prior.csv`); empty on every other path |
| `{n_features}`, `{n_samples}` | dimensions of the input/corrected matrix |

## What not to write

- **"Batch effects were corrected with ComBat-seq (sva package)" and nothing else.** The PACK L3
  review found this is the median exemplar sentence; it omits the preserved covariate and what the
  corrected matrix was used for -- both of which change how a reader should weigh the result. Use
  the template's full sentence instead.
- **Feeding the corrected matrix to a differential expression test.** PACK S1 P-1 (frozen): the
  corrected/display matrix is for visualization and descriptive scoring only. `read_handoff()`
  refuses it automatically for any DE module (`OS_BATCH_CORRECTED_INPUT`); do not work around this
  by copying the corrected matrix under a different name.
- **Regressing out surrogate variables before testing.** PACK P-3: surrogate variables are added
  to the downstream DE design (as covariates protecting the study variable), never used to first
  produce a "cleaned" matrix that is then tested as if the SVs did not exist.
