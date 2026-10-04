---
name: deseq2-wald
description: >
  Run DESeq2's Wald-test differential expression with apeglm log2 fold change shrinkage on an
  RNA-seq count matrix for one two-group contrast, and produce the publication feature table,
  volcano plot, MA plot, top-gene heatmap and a Methods/Results draft with the numbers filled in.
  Triggers: DESeq2, DESeq, results, lfcShrink, apeglm, Wald test, differential expression,
  差异表达, 差异基因, 两组比较, 火山图, bulk RNA-seq. Use for bulk RNA-seq raw counts when one
  condition level is compared with a reference level, optionally adjusted for batch or pairing
  covariates. NOT for multi-group or time-course tests of any change (use deseq2-lrt); NOT for
  microarray or already-normalized intensities (use limma-array); NOT for sample QC, PCA or
  outlier review (use deseq2-qc); NOT for single-cell conditions (use muscat-pseudobulk).
---
# deseq2-wald

## When to use / when not
- Use for bulk RNA-seq **raw integer counts** with one comparison `target vs reference` of a
  factor, e.g. treated vs control, with optional covariates such as batch or subject (paired design).
- Not for "does anything change across 3+ groups or over time" -- that is a likelihood-ratio test:
  use **deseq2-lrt**.
- Not for microarray data or matrices that are already normalized or log-transformed: use
  **limma-array** (DW-01 blocks non-integer input).
- Not for sample-level QC (PCA, sample distances, outliers): run **deseq2-qc** first and chain
  with `--from-run`.
- Not for comparing conditions in single-cell data: aggregate to pseudobulk with **muscat-pseudobulk**.
- Not a second opinion engine: edgeR (**edger-qlf**) or limma-voom (**limma-voom**) may be run as
  a sensitivity analysis next to this one, never as a replacement chosen after seeing results.

## Input requirements
- `--counts`: features x samples, first column the feature id (unversioned Ensembl ID preferred;
  other ID spaces are kept as given), raw integer counts; no normalization, no batch correction.
- `--samples`: one row per sample with the id column (`--sample-col`, default `sample`) matching the
  matrix column names exactly, the condition column (`--condition`) and any `--covariates` columns.
  Levels must be syntactic R names (`single_read`, not `single-read`).
- Or `--from-run <deseq2-qc run>`: takes `count_matrix` and `sample_table` from the upstream
  handoff after checking their sha256.
- At least 2 biological replicates per compared group (DW-03); 3+ recommended (DW-04).

## Run
```
Rscript scripts/run_deseq2_wald.R --counts counts.tsv --samples samples.csv \
  --reference control --target treated --outdir runs/dw1 [--covariates batch] [--alpha 0.05]
```

Every flag, its type and its default come from one spec in the entry script (`SPEC`,
`_shared/scripts/args.R`); `--help` prints it. Invalid input stops with a typed error
(`OS_UNKNOWN_FLAG`, `OS_MISSING_PARAMETER`, `OS_INVALID_PARAMETER`, `OS_CONFLICTING_PARAMETERS`,
`OS_INVALID_DESIGN`). Warnings raised by the engine are kept in `qc/engine_warnings.csv`.
`--spec <run>/provenance/resolved_spec.json` replays an earlier run.

### Via MCP
Call `omicstat_run` with `module="deseq2-wald"` and the same flags as `args`; read the result with `omicstat_read`.
`--help` lists every option; the ones that matter most:

| Flag | Default | Effect |
|---|---|---|
| `--reference` / `--target` | required | denominator / numerator of the log2 fold change |
| `--covariates` | none | extra design factors placed before the condition (batch, subject) |
| `--alpha` | 0.05 | FDR level: independent-filtering target AND significance cutoff |
| `--lfc-threshold` | 0 | test against \|log2FC\| > threshold (log2 units) instead of filtering on fold change afterwards |
| `--display-lfc-filter` | 0 | display-only list of significant features with \|log2fc\| >= value (log2 units); padj unchanged; off at 0 |
| `--shrinkage` | apeglm | shrinkage of the reported log2 fold change (P values are never shrunk) |
| `--min-count` / `--min-samples` | 10 / 0 | pre-filter; 0 = the smaller compared group (two-group designs only: with covariates or 3+ condition levels give `--min-samples` explicitly) |

Details and sources: references/parameters.md.

## What gets produced
- `tables/feature_table.csv` -- primary table (feature_table schema): one row per tested feature,
  `log2fc` = shrunken estimate, `stat`/`pvalue`/`padj` from the Wald test, `filtered_reason` for padj = NA
- `tables/deseq2_results_full.csv` -- MLE and shrunken log2FC side by side, max Cook's distance
- `tables/normalized_counts.csv`, `tables/vst_matrix.csv`, `tables/size_factors.csv`
- `tables/display_filtered.csv` -- only with `--display-lfc-filter > 0`: the display-only subset
- `figures/volcano`, `figures/ma`, `figures/top_heatmap` (`.pdf`, `.png`, `.figure_spec.json`) from
  `_shared/scripts/fig_*.R` (style: `_shared/docs/FIGURE_STYLE.md`); the heatmap is skipped when
  fewer than 2 features are significant
- `draft/methods_results.md` -- Methods, Results and figure legends with the numbers filled in
  (withheld when a blocker fires)
- `results/deseq2_wald_results.json` -- counts, design, coefficient, top features
- `qc/qc_results.csv` (DW-01..DW-12), `qc/engine_warnings.csv`
- `objects/handoff.json` with `feature_table`, `dds` (DESeqDataSet .rds), `vst_matrix`,
  `count_matrix`, `sample_table`, `colour_registry` and `ranked_list` for downstream modules
  (clusterprofiler-ora, clusterprofiler-gsea, fgsea-prerank, limma-camera cameraPR)
- `objects/ranked_list.csv` (`feature_id,symbol,score`, score = unshrunken Wald `stat`, sorted
  descending, ties by feature_id) with `objects/ranked_list.meta.json` and handoff state
  `ranked_list`: metric, contrast, which end is higher in the target, null test, ranked universe
  (all pre-filtered features with a finite Wald statistic), counts of excluded and tied scores
  (contract: `_shared/scripts/ranked_list.R`)
- `provenance/provenance.json`, `provenance/resolved_spec.json`

## Reading the results
Write-up templates and their slots: references/reporting-templates.md. Named failure modes:
- **Post hoc fold-change filter**: "padj < 0.05 and |log2FC| > 1" with `--lfc-threshold 0` is not
  a test of fold change. Correct form: `--lfc-threshold 1`, and the Methods state the null
  hypothesis |log2FC| <= 1. A display-only list (`--display-lfc-filter`) is reported separately
  and never inherits the test's FDR (results JSON `fc_criterion` records the three fields).
- **Shrunken fold change, unshrunken P value**: the table's `log2fc` is shrunken for ranking and
  display; `pvalue`/`padj` belong to the Wald test on the MLE. Say both, as the Methods template does.
- **Supplied vs tested features**: the denominator is the number tested after pre-filtering
  (`n_tested`), not the rows of the input.
- **padj = NA is not "not significant"**: it means filtered (low counts) or an outlier; see
  `filtered_reason`.

## When a QC rule fires
Rules `DW-01..DW-12` -- see references/qc-rules.md. DW-01..DW-03 are blockers decided on the input:
the run stops with `OS_QC_BLOCKER` and no draft. DW-05 (all padj NA) is an error: nothing can be
reported. Warnings (DW-04, DW-06, DW-09, DW-10, DW-11) must be read before reporting; info rules
(DW-07, DW-08, DW-12) describe what was filtered.

## Known limitations
- One two-level contrast per run; for another pair run the module again (the dispersion fit is
  repeated, so results equal a single fit with all samples only when the same samples are given).
- Continuous covariates are not supported (covariates are treated as factors).
- The main table's `log2fc` column holds the shrunken estimate (the MLE is in
  `tables/deseq2_results_full.csv` as `log2fc_mle`); whether the primary table must name the
  shrunken value separately is an open owner question (SUITE, S1 follow-up 2) -- unchanged in 1.2.0.
- The heatmap transformation is `vst(blind = FALSE, nsub = 1000)` when at least 1,000 features have
  a mean normalized count above 5, otherwise `varianceStabilizingTransformation(blind = FALSE)`
  directly (recorded in the results JSON `heatmap_transformation` and in the Methods).
- No tximport offsets: transcript-level estimated counts are out of scope for v1.
- Interaction terms and custom contrasts (linear combinations) are not exposed.
- Gene symbols come only from `--gene-annotation`; the module never queries an annotation database.

## Reference files
- references/method-basis.md -- sources (package@version, vignette section, DOI from `citation()`)
- references/parameters.md -- every flag and fixed argument, value and why (PACK D section ids)
- references/qc-rules.md -- rule id, severity, criterion, action, source
- references/reporting-templates.md -- the Methods/Results templates the engine fills, and their slots
- references/troubleshooting.md -- symptom -> cause -> fix (English)
