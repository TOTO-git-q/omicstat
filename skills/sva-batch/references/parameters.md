# parameters -- sva-batch

One row per flag of `SPEC` in `scripts/run_sva_batch.R`. The "Default" column is machine-checked
against `--help` and `scripts/calls_registry.json` by `tools/check_defaults.py`. "P-x" points to
`acceptance/exemplars/sva-batch/PACK.md`'s "S1 审定附录（2026-09-27，所有者批准）", where each
value is traced to the sva / limma reference manual and vignette of the installed version.

## Flags

| Flag | Default | Allowed | Why |
|---|---|---|---|
| `--input` | none | existing csv/tsv | genomic measure matrix, first column the feature id: raw integer counts for `--method combat_seq`/`svaseq` (SB-01/SB-02 guard it), log-scale/normalized values for `combat`/`sva`; exclusive with `--from-run` |
| `--samples` | none | existing csv/tsv | sample table; needs `--input`; matched to matrix columns by id, never by position |
| `--from-run` | none | existing run directory | an upstream run (e.g. deseq2-qc) handing on `count_matrix` (combat_seq/svaseq) or `expression_matrix` (combat/sva) plus `sample_table` (`_shared/scripts/handoff.R`); an upstream object already known to be a batch-corrected matrix is refused with `OS_BATCH_CORRECTED_INPUT` |
| `--outdir` | (required) | writable directory | every module writes into one run directory |
| `--spec` | none | existing file | replay `provenance/resolved_spec.json`; flags given on the command line win |
| `--sample-col` | sample | column name | sample id column of the sample table |
| `--method` | (required) | combat, combat_seq, sva, svaseq | combat/combat_seq correct a KNOWN `--batch` (log-scale / raw counts respectively, PACK D-S1); sva/svaseq estimate surrogate variables for an UNKNOWN source of variation instead (no `--batch`) |
| `--batch` | none | column name | known batch; required for `combat`/`combat_seq`, refused (`OS_CONFLICTING_PARAMETERS`) for `sva`/`svaseq` |
| `--study-var` | (required) | column name | the protected research/study variable (P-2: required for every method; never regressed out) |
| `--study-var-type` | categorical | categorical, continuous | how `--study-var` is treated; `--method combat_seq` refuses `continuous` with `OS_UNSUPPORTED_DESIGN` (the S1 appendix "待澄清" item: it does not say whether a continuous research variable goes into ComBat_seq's `group` or `covar_mod`; nothing is guessed) |
| `--covariates` | none | comma-separated column names | additional columns protected alongside `--study-var` (factors; p-1 indicator columns per level for ComBat_seq's `covar_mod`) |
| `--num-sv-method` | be | be, leek | `num.sv()` method (sva/svaseq only); PACK P-3: "be" is the function default, "leek" an explicit sensitivity option (the sva vignette's own bladderbatch example uses "leek") |
| `--pca-ntop` | 500 | 10..20000 | most-variable features used by the before/after PCA (display only; `os_pca_scores` default) |
| `--seed` | 20260925 | integer | passed explicitly to `num.sv()` (PACK P-3 lock: seed argument written out, recorded in `provenance.json`) |
| `--journal` | nature | nature, cell, science, generic | figure preset (`_shared/docs/FIGURE_STYLE.md`) |

## Fixed arguments (not flags)

Written out in the calls (lock 3) with the value shown, even where it equals the function default;
see `scripts/calls_registry.json`.

| Call | Argument = value | Why |
|---|---|---|
| `ComBat` | `mod = ~ <--covariates> + <--study-var>` (intercept kept) | vignette 'Applying the ComBat function to adjust for known batches' (P-2) |
| `ComBat` | `par.prior = TRUE`, `mean.only = FALSE`, `ref.batch = NULL`, `prior.plots = FALSE` | D-S4: function defaults; `prior.plots` never opens a graphics device; the same prior diagnostic is recomputed by `sb_combat_prior()` (sva 3.60.0 ComBat source, line for line) and drawn by the shared `os_prior_density()` as `figures/combat_prior` (S4 F4) |
| `ComBat` | `BPPARAM = BiocParallel::SerialParam()` | single thread (deseq2-wald `parallel = FALSE` precedent); function default |
| `ComBat_seq` | `group = factor(--study-var)` (categorical only), `covar_mod = model.matrix(~ <--covariates>)[, -1]` or `NULL` | vignette 'ComBat-Seq for batch adjustment on RNA-Seq count data' (P-2) |
| `ComBat_seq` | `full_mod = TRUE`, `shrink = FALSE`, `shrink.disp = FALSE`, `gene.subset.n = NULL` | D-S5: function defaults ('Shrinkage off' printed by the package) |
| `num.sv` | `mod = ~ <--covariates> + <--study-var>` (full model), `vfilter = NULL`, `B = 20` | P-3: function defaults except `method`/`seed` |
| `sva` / `svaseq` | `mod0 = ~ <--covariates>` (null model), `n.sv = num.sv()` output, `controls = NULL`, `method = "irw"`, `vfilter = NULL`, `B = 5`, `numSVmethod = "be"`[, `constant = 1`] | P-3: function defaults; supervised sva (`controls`) is out of scope for v1 |
| `removeBatchEffect` | `x = <input matrix>`, `batch = NULL`, `batch2 = NULL`, `covariates = <estimated SVs>`, `design = mod` (full protected model), `group = NULL` | sva/svaseq route only: the display-only correction (deseq2-qc P-3 cross-reference); `design` is never `NULL` |
