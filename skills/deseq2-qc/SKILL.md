---
name: deseq2-qc
description: >
  Run DESeq2's sample-level quality assessment (vst/rlog variance-stabilizing transform, PCA of
  samples, sample-to-sample distance heatmap) on a raw RNA-seq count matrix, BEFORE any
  differential test, and produce a Methods/Results draft with the numbers filled in. Triggers:
  DESeq2, vst, rlog, varianceStabilizingTransformation, plotPCA, sample distance, blind dispersion,
  样本质控, 样本PCA, 样本聚类, 批次检查, bulk RNA-seq QC. Use before deseq2-wald / deseq2-lrt, to
  check for outlier samples, batch structure or mislabeled groups on raw integer counts. NOT for
  differential expression itself (use deseq2-wald for a two-group contrast, deseq2-lrt for
  multi-group/time-course); NOT for microarray or already-normalized data (use limma-array); NOT
  for single-cell QC (use seurat-qc / scater-qc); NOT a numeric sample-outlier test -- it never
  removes a sample (P-2 pending; see Known limitations).
---
# deseq2-qc

## When to use / when not
- Use to QA a raw RNA-seq count matrix before fitting anything: transform the counts (vst by
  default, or rlog), look at the sample PCA and the sample-to-sample distance heatmap, and get a
  descriptive per-sample table (PC scores and size factor) for manual review.
- Not for testing whether a condition changes expression -- that is deseq2-wald (two groups) or
  deseq2-lrt (3+ groups / time course); this module fits no contrast and reports no P value.
- Not for microarray data or already-normalized/log-transformed intensities: use **limma-array**
  (DQ-01 blocks non-integer input).
- Not for single-cell data: use **seurat-qc** (Seurat line) or **scater-qc** (Bioconductor line).
- Not a decision-maker about which samples to exclude: it never removes a sample or a biological
  group automatically, and (PACK P-2 is still pending the module owner) it does not compute or
  apply any numeric sample-outlier statistic or threshold. A person reviews the figures/table and
  makes that call, reported separately.
- Not for batch-corrected display: an already-corrected matrix belongs to **sva-batch**, which
  produces its own paired before/after PCA; this module's `--blind-false-supplement` is a
  design-aware (not batch-corrected) transform, a different thing.

## Input requirements
- `--counts`: features x samples, first column the feature id, raw integer counts; no
  normalization, no batch correction (DQ-01/DQ-02 guard this).
- `--samples`: one row per sample with the id column (`--sample-col`, default `sample`) matching
  the matrix column names exactly, the `--condition` column, and any `--covariates` / `--shape-col`
  columns. At least 3 samples total (DQ-03).
- No `--from-run`: this module has no upstream (it is the root of the bulk-DE chain and the
  upstream of deseq2-wald / deseq2-lrt via its own `objects/handoff.json`).

## Run
```
Rscript scripts/run_deseq2_qc.R --counts counts.tsv --samples samples.csv --outdir runs/qc1 \
  [--condition condition] [--shape-col type] [--covariates batch] [--transform vst|rlog]
```

Every flag, its type and its default come from one spec in the entry script (`SPEC`,
`_shared/scripts/args.R`); `--help` prints it. Invalid input stops with a typed error
(`OS_UNKNOWN_FLAG`, `OS_MISSING_PARAMETER`, `OS_INVALID_PARAMETER`, `OS_CONFLICTING_PARAMETERS`,
`OS_INVALID_DESIGN`). Warnings raised by the engine are kept in `qc/engine_warnings.csv`.
`--spec <run>/provenance/resolved_spec.json` replays an earlier run.

### Via MCP
Call `omicstat_run` with `module="deseq2-qc"` and the same flags as `args`; read the result with
`omicstat_read`. `--help` lists every option; the ones that matter most:

| Flag | Default | Effect |
|---|---|---|
| `--condition` | condition | biological group used to colour the PCA/distance figures |
| `--shape-col` | none | optional second factor used as the PCA point shape (e.g. sequencing batch) |
| `--covariates` | none | extra design factors (affects only the design formula and the optional supplement) |
| `--transform` | vst | `vst` (fast, default) or `rlog`; both run `blind = TRUE` by default (sample QA) |
| `--blind-false-supplement` | off | also produce a labelled, design-aware (`blind = FALSE`) supplementary PCA/matrix -- never the default output |
| `--min-count` / `--min-samples` | 10 / 0 | pre-filter; 0 auto-resolves only for a simple two-level, no-covariate design |

Details and sources: references/parameters.md.

## What gets produced
- `tables/sample_qc_descriptive.csv` -- DESCRIPTIVE ONLY: sample, condition, [shape-col],
  size_factor, PC1, PC2; no flag, verdict or threshold column (P-2 pending)
- `tables/vst_matrix.csv` or `tables/rlog_matrix.csv` -- the primary (blind = TRUE) transformed
  matrix; `tables/size_factors.csv`; `tables/sample_distances.csv` -- the sample-by-sample Euclidean
  distances of that matrix (vignette `dist(t(assay(vsd)))`), the numbers behind `figures/sample_distance`
- `tables/<transform>_matrix_blind_false.csv` -- only with `--blind-false-supplement`
- `figures/pca`, `figures/sample_distance`, `figures/size_factor` (`.pdf`, `.png`,
  `.figure_spec.json`) from `_shared/scripts/fig_bulk.R` (`os_pca_plot`, `os_sample_distance`,
  `os_diag_xy`) -- no new shared figure builder was needed for this module
- `figures/pca_blind_false` -- only with `--blind-false-supplement`, clearly captioned as
  supplementary and stating `blind = FALSE`
- `draft/methods_results.md` -- Methods, Results and an explicit note on why no sample-outlier
  call is made (withheld when a blocker fires)
- `results/deseq2_qc_results.json` -- design, transform, counts, percent variance, QC summary
- `qc/qc_results.csv` (DQ-01..DQ-07), `qc/engine_warnings.csv`
- `objects/handoff.json` with `count_matrix`, `sample_table` (byte-identical copies of the input,
  for deseq2-wald / deseq2-lrt `--from-run`), `expression_matrix` (the primary blind = TRUE
  transform matrix) and `colour_registry`
- `provenance/provenance.json`, `provenance/resolved_spec.json`

## Reading the results
Write-up templates and their slots: references/reporting-templates.md. Named failure modes:
- **"Outlier samples were removed"**: this module never removes a sample; any exclusion is a
  separate, manual, reported decision (P-2 is pending a calibrated statistic).
- **Reading blind = TRUE as "no group difference"**: blind dispersion estimation is deliberately
  unbiased by the design -- it says nothing about whether groups differ. Use deseq2-wald /
  deseq2-lrt to test that.
- **PC scores as a verdict**: they describe the PCA display; no sample-outlier statistic or
  threshold is defined for them here.
- **Handing the blind = TRUE `expression_matrix` to a group-difference visualization** downstream
  without noting that it is blind to the design; state the transform's `blind` value whenever the
  matrix is reused.

## When a QC rule fires
Rules `DQ-01..DQ-07` -- see references/qc-rules.md. DQ-01..DQ-03 are blockers decided on the
input: the run stops with `OS_QC_BLOCKER` and no draft. Warnings (DQ-04, DQ-06, DQ-07) must be
read before reporting; DQ-05 is informational (an automatic, harmless fallback).

## Known limitations
- **No numeric sample-outlier statistic or threshold (PACK P-2, class C, pending the module
  owner)**: the per-sample table is descriptive only. DESeq2 itself defines no such per-sample
  statistic (Cook's distance is per gene); a future version may add a calibrated rule once the
  owner decides one, with registered evidence.
- Fixed at PCs 1:2 for the PCA figure and table (no `--pcs` flag yet).
- No gene-symbol annotation or gene labelling on any figure (PCA and sample-distance are
  sample-level, not feature-level, plots).
- `--blind-false-supplement` reuses the module's own `--covariates`/`--condition` design; it is
  not a substitute for sva-batch's protected-design batch correction display (PACK P-3).
- Continuous covariates are not supported (covariates are treated as factors), matching
  deseq2-wald.

## Reference files
- references/method-basis.md -- sources (package@version, vignette section, DOI from `citation()`)
- references/parameters.md -- every flag and fixed argument, value and why (PACK D section ids)
- references/qc-rules.md -- rule id, severity, criterion, action, source
- references/reporting-templates.md -- the Methods/Results templates the engine fills, and their slots
- references/troubleshooting.md -- symptom -> cause -> fix (English)
