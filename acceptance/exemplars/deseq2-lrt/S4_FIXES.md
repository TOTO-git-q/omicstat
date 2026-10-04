# deseq2-lrt -- S4 fixes (1.0.0 -> 1.1.0)

Branch `s4/deseq2-qc-lrt` (from `integrate/m1m2` @fb63e52). Work list: `S3_REVIEW_astra.md` (F1-F3).
GT103 run dir: `~/omic-build-logs/s4/deseq2-lrt` (logs `~/omic-build-logs/s4/deseq2-lrt-<tag>.log`).
Container `omicstat-r:2026.09.1` (DESeq2 1.52.0, R 4.6.1). Evidence runs: `f-golden`
(OMICSTAT_WRITE_GOLDEN=1), `f-check` and `f-check2` (normal reruns; f-check2 adds the F2 fallback
test), all SMOKE PASSED / EXIT 0, 0 FAIL lines; `lock2` + `lockcheck` (module_lock 1.1.0 OK).

## F1 -- all P / adjusted P with NA alignment; fission workflow source saved (PACK C / S1 P-4)

What changed
- Workflow source saved: `workflow_source/rnaseqGene_fission_timecourse.txt` -- every code chunk
  of rnaseqGene "Time course experiments" and its pre-filter chunk, verbatim with Rmd line
  numbers (github mikelove/rnaseqGene @0d7e27dde3ca, file sha256 recorded), plus the printed
  output of `head(resTC[order(resTC$padj),], 4)` from the rendered Bioc 3.23 workflow (R 4.6.0 RC,
  DESeq2_1.52.0; html sha256 recorded). A section "How the suite differs" marks: (1) the workflow
  applies NO pre-filter to fission (its only pre-filter, count >= 10 in >= 4, is in the airway
  section); the suite anchor uses count >= 10 in >= 3; (2) results() alpha 0.1 vs suite 0.05;
  (3) level order wt, mut (workflow) vs radix mut, wt (suite).
  (code.bioconductor.org served an expired TLS certificate on 2026-09-29, so RELEASE_3_23 source was
  not read there; the chunks equal the code echoed in the Bioc 3.23 HTML.)
- `tests/run_smoke_test.R`
  - `:26` `fission_oracle()` = the workflow code (`library("fission"); data("fission");
    DESeqDataSet(...); DESeq(test="LRT", reduced=...); results()`); each non-NULL argument is one
    named deviation. `:44` `assert_all_columns()` compares EVERY row and every numeric column
    (baseMean, log2fc, SE, stat, pvalue, padj) of the engine's full table with the oracle:
    identical feature set, identical NA positions, relative diff <= 1e-8 elsewhere; plus JSON
    tested/significant/padj-NA counts. `:65` `printed_ok()` = match to the printed digits.
  - `:105` A1 REPLAY (suite settings, replaces the old ">1,000 genes, P < 1e-8 abs, padj NA only"
    check): 6,205 rows, all columns.
  - `:170` A0 PRINTED (new): the workflow code is run as written and must reproduce every printed
    cell (4 x 7) and both header lines; then the engine is run with the workflow's settings
    (`--min-count 0 --min-samples 1` = all 7,039 rows, `--alpha 0.1`): its 4 smallest padj are the
    printed genes in printed order, and baseMean, stat, pvalue, padj equal the printed digits.
    A0 REPLAY: all 7,039 rows / all columns vs the workflow code with the suite level order.
  - `:255` A2 pasilla REPLAY (replaces "df/row count/term name only"): DESeq2 vignette code (DESeq2
    extdata input, pre-filter, multi-factor `~ type + condition`, LRT form of chunk simpleLRT2 with
    `reduced = ~ type`) vs the engine: all 8,148 rows, all columns, NA positions.
- `references/method-basis.md` gains an "Anchors" section describing A0/A1/A2/F3 and the
  deviations.

Evidence (f-check2 log)
- A0 oracle self-check PASS (every printed cell and header). A0 PRINTED PASS for ids/order,
  baseMean 174.671/444.505/336.373/261.773, stat, pvalue 1.97415e-19 ..., padj 1.33453e-15 ....
- A0 REPLAY 7,039 rows: 279 NA in log2fc/SE/stat/P/padj, identical positions; max relative diffs
  <= 4.98e-10. A1 REPLAY 6,205 rows: 0 NA, max relative diff <= 4.98e-10; 8 significant.
  A2 REPLAY 8,148 rows: padj 316 NA identical, max relative diff <= 4.97e-10; 1,112 significant.
- INFO line: workflow level order vs suite level order give LRT P that differ by up to 1.64e-05
  relative (IRLS convergence under another parameterization); that is why the full replays use the
  suite level order, and why the printed anchor is matched at printed digits only.

## F2 -- Methods and captions state the actual transformation and selection (PACK W/F)

What changed
- `scripts/deseq2_lrt_core.R:202-209`: the display transform records `vst_fallback` and
  `n_vst_eligible` (same >5 mean-normalized-count rule as before; no estimator change).
- `scripts/deseq2_lrt_report.R:16` `dl_display_transform()` writes the call that ran
  (`DESeq2::vst(blind = FALSE, nsub = 1000, fitType = "...")` or `DESeq2::varianceStabilizingTransformation(
  blind = FALSE, fitType = "...") -- the direct VST, because only N features had a mean normalized
  count > 5 ...`). `:27` `.dl_selection_text()`: "the k with the smallest BH-adjusted P among the K
  features with adjusted P < alpha in the likelihood ratio test (full ... vs reduced ...); n = S
  samples". `:52` heatmap caption and `:60` trajectory caption append these to the shared
  builders' captions (module-side, as deseq2-wald does); the trajectory caption states it uses
  `counts(dds, normalized = TRUE)` and no VST. `:77` results JSON: `display_transform`,
  `display_transform_blind`, `display_transform_nsub`, `display_transform_fallback`,
  `n_vst_eligible`, `n_samples`.
- `references/reporting-templates.md`: Methods gets a separate paragraph -- figures are displays
  separate from the inferential test, selection = BH-adjusted LRT P < alpha across n samples,
  heatmap transform = the call that ran, "does not enter the likelihood ratio test".
- Tests (`:126`): a1 Methods, heatmap caption, trajectory caption and JSON; `:145` a synthetic
  600-feature run exercises the direct-VST fallback (JSON, Methods, heatmap caption).

Evidence: f-check2 PASS lines "F2 Methods ...", "F2 heatmap caption ...", "F2 trajectory caption
...", "F2 results JSON ...", "F2 fallback ..." (3 checks). Actual a1 Methods text:
"... up to 50 in the heatmap, as row z-scores of expression transformed with DESeq2::vst(blind =
FALSE, nsub = 1000, fitType = "parametric") after the fit, and up to 12 in the trajectory figure
..., as DESeq2 normalized counts. The transformation is used only for display and does not enter
the likelihood ratio test."

Figures looked at (PNG): a1 `top_heatmap` (8 genes, strain bar, z-score key, labels unclipped),
a1 `trajectory` (8 facets in 2 columns, legend strain, axes readable, no clipped strip labels),
a0 `top_heatmap` (15 genes), a2 `top_heatmap` (pasilla, 50 genes, sample labels readable),
f3 `trajectory` (same genes as a1 -- selection depends only on joint padj), f2-fallback
`top_heatmap` (45 genes). Captions state the threshold (padj < alpha), n samples and the transform.

## F3 -- results(name =) registered; --report-coef changes only the displayed coefficient (PACK T / lock 3)

What changed
- `scripts/deseq2_lrt_core.R:185-194`: one `results()` call with `name = used_coef` always written
  out -- `--report-coef` if given, else `resultsNames(dds)[length]`, which is exactly what
  `results()` substitutes for a missing `name` (`if (missing(name)) name <- lastCoefName(object)`,
  DESeq2 1.52.0 body; probe `acceptance/exemplars/deseq2-qc/_s4/probe_env.R`: explicit last name
  gives an identical DataFrame, and changing `name` leaves pvalue/padj identical). The earlier two
  call sites (with/without `name`) are gone, so lock 3 can require the argument at the one site.
- `scripts/calls_registry.json:124` registers `name` (value null = flag absent, `value_rule`,
  source, pack, `flag: --report-coef`, function_default ""). check_defaults.py: 0 problems;
  call registry / default drift PASS.
- `references/parameters.md` "Fixed package calls" updated.
- Tests (`:226`): static registry assertion; run with `--report-coef strainwt.minute30`: feature
  ids, baseMean, stat, pvalue, padj, filter reasons byte-identical to the default run; joint
  counts unchanged; log2fc/SE differ; the f3 table replays `results(name = "strainwt.minute30")`
  of the workflow fit on all rows/columns.

Evidence: f-check2 PASS lines "F3 ..." (7 checks incl. the full replay, max relative diff <= 4.98e-10).

## Version, goldens, lock
`DL_MODULE_VERSION` 1.0.0 -> 1.1.0. Goldens regenerated in the container (f-golden); f-check and
f-check2 `PASS: G golden baseline`. `module_lock.json` regenerated after the last test edit (lock2)
and `--check` OK (lockcheck). check_defaults.py / check_flag_docs.py / lint_r.py PASS inside the
smoke test in the container.

## Known failing anchors
None. Note (not a failing anchor): the printed log2FoldChange/lfcSE columns are coefficient
`strainmut.minute180`; the engine displays `strainwt.minute180` because it orders factor levels by
radix (mut before wt). They are asserted on the workflow code (oracle self-check), not on the
engine; the smoke log prints both (`NOTE: A0 ...`: printed -2.6567195 / 0.752261; engine
2.6567256 / 0.752262). Whether the module should honour the sample table's level order or offer a
reference-level flag is an owner question, listed below; nothing was changed.

## Owner items (not decided here)
- DEGreport pattern clustering: still the `OS_UNAVAILABLE_DEPENDENCY` refusal (test E1 PASS).
- New, for information: displayed-coefficient reference level. The engine's radix level order makes
  the default displayed coefficient differ from the workflow's (`strainwt.minute180` vs
  `strainmut.minute180`); joint P/padj are unaffected (to 1.64e-05 relative, IRLS convergence).
  `--report-coef` can only pick coefficients of the engine's parameterization.

## Shared needs
None required. Same observation as deseq2-qc: `formatC(..., digits = 10, format = "g")` pads a
vector to a common width (e.g. `"      1e-20"`) in module writers and in
`_shared/scripts/feature_table.R::write_feature_table`; harmless for readers, cosmetic.

## Notes for the final verifier
- The oracles call `library("DESeq2")`, `library("fission")` (acceptance library via
  `os_acceptance_lib`) and the guide code unqualified, on purpose; no engine or `_shared` function
  is used inside an oracle (`os_acceptance_lib` only puts the acceptance library on `.libPaths()`).
- Deviations from guide code are commented at each use: suite pre-filter, suite alpha, suite level
  order (fission and pasilla), `type` as the retained LRT term for pasilla.
