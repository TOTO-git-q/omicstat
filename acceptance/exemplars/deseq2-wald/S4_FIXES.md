# deseq2-wald — S4 fixes (1.1.0 -> 1.2.0)

Repaired by the S4 coordinator on `integrate/m1m2` against
`S3_REVIEW_astra.md` (pin `build/m1m2@212681b`) and the cross-module contract
(a) of `docs/build/S3_REPORT_astra.md` sec 5. All runs in `omicstat-r:2026.09.1`
on GT103, run dir `~/omic-build-logs/s4/coord/` (logs `coord-wald*.log`).

## F1 — vst on inputs with too few eligible rows (PACK D-10/F, typed failure)
- Change: `scripts/deseq2_wald_core.R` (compute, block after `DESeq2::DESeq`):
  the heatmap/vst-matrix path is chosen from the rows `vst()` itself subsamples
  (`rowMeans(counts(dds, normalized = TRUE)) > 5`), not from `nrow(dds)`: `vst(blind = FALSE,
  nsub = 1000, fitType)` only when >= 1000 rows are eligible, else
  `varianceStabilizingTransformation(blind = FALSE, fitType)` directly (DESeq2's own
  recommendation in the error message). The path and the eligible count are returned
  (`vst_path`, `n_vst_eligible`), written to `results/deseq2_wald_results.json`
  (`heatmap_transformation`) and to the Methods.
- Evidence: smoke section "S4" replays Astra's probe (seed 42, 1,200 x 6, 100 high rows,
  `--min-count 0 --sf-type poscounts --fit-type mean --shrinkage none`): exit 0,
  `heatmap_transformation.path = varianceStabilizingTransformation`, 100 eligible rows.
  Before the fix the same input died with the untyped "less than 'nsub' rows with mean
  normalized count > 5". Printed anchors A1–A3 unchanged (same checks PASS); the golden
  feature/full tables are byte-identical to 1.1.0 (only the results JSON, the heatmap
  figure_spec caption and the new ranked list changed in the manifest).

## F2 — Methods from the resolved options (PACK W, D-03/D-04/D-10)
- Change: `references/reporting-templates.md` methods template now uses slots
  `{sf_sentence}`, `{disp_sentence}`, `{vst_sentence}`; `scripts/deseq2_wald_report.R`
  (`dw_template_values`) fills them from `--sf-type` (ratio / poscounts), `--fit-type`
  (parametric / local / mean) and the transformation actually used; the shrinkage sentence now
  names the package version (apeglm / ashr) and the coefficient and the fixed lfcShrink
  arguments. The heatmap caption appends the transformation (vst/VST, blind = FALSE,
  fitType, nsub) and the significance rule with n. Results JSON adds `size_factor_type`,
  `dispersion_fit_type`, `shrinkage_package_version`, `heatmap_transformation`.
- Evidence (smoke "S4-F2"): poscounts/mean/no-shrinkage draft names the modified geometric
  mean, the mean dispersion fit and the direct VST, and contains neither "median-of-ratios"
  nor "parametric"; results JSON and resolved_spec agree; the default pasilla draft names
  median-of-ratios, the parametric trend, apeglm v1.34.0 with coef
  `condition_treated_vs_untreated`, and vst(blind = FALSE, nsub = 1000); the heatmap
  caption states the transformation.

## Contract (a) — real ranked_list producer (S3_REPORT sec 5.1, MODULE_BUILD_BRIEF sec 3)
- Change: `scripts/run_deseq2_wald.R` writes `objects/ranked_list.csv`
  (`feature_id,symbol,score`, score = unshrunken Wald `stat` of the single contrast, sorted
  descending, ties by feature_id) with `objects/ranked_list.meta.json`, and hands both on
  (`ranked_list`, `ranked_list_meta`) with the metadata in handoff state `ranked_list`
  (shared contract `skills/_shared/scripts/ranked_list.R`): metric, statistic
  `wald_stat`, `test_statistic`, directional, contrast, what the positive/negative ends mean,
  null test (zero effect, or minimum effect with the lfcThreshold), ranked universe
  (pre-filtered features with a finite Wald stat), counts of excluded and tied scores.
- Evidence (smoke R1–R3 on pasilla a2): metadata validated by the consumer-side
  `os_ranked_list_meta()`; the file validated by `os_rank_read()`; 8,148 ranked, 0 excluded;
  scores equal the feature table's `stat`; R3 = independent replay of the vignette call
  `DESeq2::results(dds, contrast = c("condition", "treated", "untreated"))$stat` sorted the
  same way: identical IDs and values. `objects/ranked_list.csv` added to the golden manifest.
- Provenance now also hashes `--gene-annotation` when given.

## Version, goldens, lock
- `DW_MODULE_VERSION` 1.1.0 -> 1.2.0; goldens regenerated in the container
  (`coord-waldg.log`), normal rerun PASS incl. golden (`coord-wald2.log`, `coord-wald3.log`);
  `module_lock.json` regenerated (1.2.0, 14 files).
- Figures looked at: volcano/MA of the low-count run (no significant features: labels and
  captions sensible); pasilla volcano/MA/heatmap unchanged apart from the heatmap caption.

## Owner items
- Unchanged from 1.1.0: whether the primary table's `log2fc` must name the shrunken value
  separately (SUITE S1 follow-up 2).

## Notes for the final verifier
- A consumer must read the ranked list's meaning from the metadata, not from the producer
  name (clusterprofiler-gsea F1). Check the consumer modules against a real deseq2-wald run.
