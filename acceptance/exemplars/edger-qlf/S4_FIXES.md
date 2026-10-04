# edger-qlf S4 fixes

Branch `s4/edger-qlf` (from `integrate/m1m2@fb63e52`). GT103 run dir `~/omic-build-logs/s4/edger-qlf/`
(logs `~/omic-build-logs/s4/edger-qlf-<tag>.log`). Container `omicstat-r:2026.09.1` (R 4.6.1, edgeR 4.10.5, limma 3.68.5).

## F1 -- PACK C / S1 P-1: guide-route printed anchor, suite-route difference, dispersion assertions

What changed
- `skills/edger-qlf/tests/run_smoke_test.R`, block "C-guide" (after the fixture SHA check): the User's Guide 4.4
  code, copied from the locked L1 text `L1_bioc3.23/edgeR/vignettes/edgeRUsersGuide.rendered.txt`
  (SHA256 checked against the L1 manifest in the test), each line cited `rendered:<line>`
  (2520, 2484-2495, 2534-2536, 2539-2542, 2545, 2551, 2553, 2585, 2608-2609, 2637, 2648, 2670-2671, 2708).
  Only deviations: the locked GEO count file stands in for the guide's featureCounts output; the targets
  table is typed from its printout; `plotMDS(y, plot = FALSE)` without col/pch. `options(digits = 3)`
  reproduces the printed precision. Guide objects are not produced by any engine or shared helper.
  PRINTED anchors, compared as text with the rendered lines (whitespace-normalised):
  `summary(keep)` (2549-2550), `y$samples` (2555-2567), MDS dim 1/2 65 %/17 % (2589-2590),
  `y$common.dispersion` `[1] 0.0134` (2639), `fit$dispersion` `[1] 0.013` (2650), `head(fit$coefficients)`
  (2652-2658), `topTags(qlf)` (2678-2688), `summary(decideTests(qlf))` 2607/10546/2816 (2696-2698),
  `topTags(tr)` (2711-2721), `summary(decideTests(tr))` 1533/12573/1863 (2726-2728).
- Which quantity the guide prints as `fit$dispersion`: in edgeR 4.10.5 `glmQLFit.default` with `legacy = FALSE`,
  `dispersion = NULL` sets `dispersion <- estimateGLMCommonDisp(y[i, ], ...)` over the top `top.proportion`
  genes by AveLogCPM and stores `fit$dispersion <- dispersion` -- a length-1 NB dispersion ("overall estimate of
  the squared BCV", rendered:2645), not a QL dispersion. Source printed by `_s4/probe_source.R`
  (`edger-qlf-probe-src.log`). The test asserts `length(fit$dispersion) == 1`, printed `[1] 0.013` and the
  locked value 0.0129556217857436 (|diff| < 1e-12); common dispersion printed `[1] 0.0134`, locked
  0.0134413085635106.
- Block "C-suite" (inside the A1/A2 sections): the frozen suite route (engine; S1 P-1 call set) is kept and
  REPLAYED independently in the test (engine vs in-test P/FDR < 1e-10 for QLF and, new, for glmTreat). The
  exact difference to the guide route is asserted: max |AveLogCPM guide - suite| 0.2674049001; guide
  AveLogCPM = `aveLogCPM(y, dispersion = common.dispersion)`, suite AveLogCPM = `aveLogCPM(y)` (aveLogCPM
  default dispersion 0.05; `_s4/probe_avelogcpm.R`); suite `fit$dispersion` 0.0129516892728812 vs guide
  0.0129556217857436; QLF max |P guide - suite| 0.002497297218; glmTreat 0.002447249876. Cache probe
  (Astra `_s3/cache_probe.R` re-done in the test): suite input + guide AveLogCPM reproduces the guide P values
  exactly (max diff 0, same scalar dispersion). Dispersion-only probe: guide scalar dispersion with the suite
  AveLogCPM leaves the gap (> 1e-3; 0.002519070785 in `_s4/probe_f1.R`). So the difference is the AveLogCPM
  cached by estimateDisp and passed through `glmQLFit.DGEList` (it picks the genes for the scalar dispersion,
  enters the average QL dispersion and is the covariate of the QL prior trend), not the edgeR version.
- Suite-route checks relabelled (no more "guide 4.9.9"): A1 2608/10546/2815, top row 211577, A2 1535/12570/1864.
- Attribution text corrected: `skills/edger-qlf/references/method-basis.md` (new section), `SKILL.md` Known
  limitations, `acceptance/exemplars/edger-qlf/S3_REQUEST.md` (anchor table, known limitations, marked
  "[S4 correction]"). The estimator is unchanged.

Evidence
- Probe `acceptance/exemplars/edger-qlf/_s4/probe_f1.R` -> `~/omic-build-logs/s4/edger-qlf-probe-f1.log` (EXIT 0).
- Smoke `~/omic-build-logs/s4/edger-qlf-f1-smoke.log`: all C-guide and C-suite checks PASS, SMOKE PASSED, EXIT 0.

## F2 -- PACK F: QL dispersion plot and sample MDS

What changed
- `skills/edger-qlf/scripts/edger_qlf_core.R`: `eq_ql_disp_data(fit)` reads the display quantities from the fitted
  DGEGLM exactly as edgeR 4.10.5 `plotQLDisp()` does (source in `edger-qlf-probe-src.log`): x = `fit$AveLogCPM`;
  raw = `deviance.adj / df.residual.adj` (new method) or `deviance / df.residual.zeros` (legacy), 0 where df < 1e-8;
  squeezed = `s2.post`; trend = `s2.prior`; plus `df.prior`. `edger_qlf_compute()` now also calls
  `limma::plotMDS(logcpm, top = 500, labels = NULL, pch = NULL, cex = 1, dim.plot = c(1, 2), gene.selection = "pairwise",
  xlab = NULL, ylab = NULL, plot = FALSE, var.explained = TRUE)` on `cpm(y, log = TRUE, prior.count = 2)` of the
  filtered TMM DGEList -- the matrix and call that edgeR `plotMDS.DGEList` (User's Guide 4.4.5 `plotMDS(y)`) makes.
  Constants `EQ_MDS_TOP = 500`, `EQ_CPM_PRIOR_COUNT = 2`. Module version 1.0.0 -> 1.1.0.
- `scripts/calls_registry.json`: `limma` 3.68.5 in `package_versions`; `limma::plotMDS` (method `plotMDS.default`)
  with all 10 arguments, values and container `function_default`s (default-drift check PASS).
- `scripts/edger_qlf_report.R`: figures `ql_dispersion` (shared `os_ql_dispersion`; df_prior = largest robust prior df,
  n_outlier = genes with a smaller prior df) and `mds` (shared `os_sample_mds`, colours from the run's colour registry);
  tables `tables/ql_dispersion.csv`, `tables/mds_coordinates.csv`. Captions state n features / n samples, design,
  robust, winsor.tail.p, prior df, robust-outlier count, the raw-dispersion definition (new vs legacy), the NB dispersion
  used inside the QL fit, MDS top 500 of n, distance (leading log2 FC), input scale (log2 CPM, TMM, prior count 2), and
  "display only / no significance threshold". `run_edger_qlf.R`: provenance outputs list the two tables.
- SKILL.md (What gets produced), references/parameters.md, references/reporting-templates.md updated.

Regression assertions (`tests/run_smoke_test.R`)
- "F2 QL dispersion table equals edgeR::plotQLDisp x/y and fit s2.post/s2.prior/df.prior over 15969 genes": REPLAY
  against `edgeR::plotQLDisp(suite_fit)` called on a null PDF device in the test (x, quarter-root raw) and the
  independent suite fit (< 1e-8).
- "F2 MDS coordinates equal the guide's plotMDS(y) for all 12 samples": REPLAY against the guide's own
  `plotMDS(y, plot = FALSE)` (C-guide block, rendered:2585), |diff| < 1e-8; spec variance explained equals the guide
  object (< 1e-6) and rounds to the PRINTED 65 %/17 % (rendered:2589-2590).
- Caption content checks for both figures; legacy run: QL figure uses the legacy deviance/df and says so, table differs.
- A1 six figures with caption/PNG/PDF; D1 spec replay byte-identical for both new PNGs, specs and tables;
  goldens now include both specs and both tables.

Figures looked at (copied from `~/omic-build-logs/s4/edger-qlf/_smoke/edger-qlf-smoke/`)
- a1/ql_dispersion.png: raw grey, squeezed red, trend blue line; legend "QL dispersion"; axes log2 CPM / quarter-root QL
  dispersion; nothing clipped. Shape matches plotQLDisp (trend dips near 6 log2 CPM).
- a1/mds.png: 12 samples, 6 condition colours matching the heatmap annotation; basal left, luminal right, as the guide
  figure; axis labels "Leading log2 fold change dim 1 (65.4%)" / "dim 2 (17.4%)"; legend complete.
- legacy/ql_dispersion.png: legacy raw/squeezed/trend; readable, legend present.
- a1/volcano.png, a1/md.png, a1/bcv.png, a1/top_heatmap.png (unchanged builders): counts 2,608/2,815, labels
  readable, heatmap 12 accessions and 50 rows unclipped.
- treat/ and legacy/ mds.png and treat/ql_dispersion.png are byte-identical to the a1 PNGs (same data; sha256 checked).

Evidence
- `~/omic-build-logs/s4/edger-qlf-f2-smoke.log` (only the expected golden JSON change failed before regeneration),
  `edger-qlf-golden-write.log` (OMICSTAT_WRITE_GOLDEN=1, SMOKE PASSED), `edger-qlf-final-smoke.log` (73 PASS, 0 FAIL,
  golden PASS, no Rplots.pdf, SMOKE PASSED, EXIT 0), `edger-qlf-lock.log` (module_lock 1.1.0, 14 files, tier
  container), `edger-qlf-lock-check.log` (`--check` OK). check_defaults.py / check_flag_docs.py / lint_r.py /
  call registry / default drift PASS inside the container smoke and locally.

## Known failing anchors
None. Every printed PACK C value is reproduced on the guide route in the locked container.

## Owner items
- PACK C / S1 P-1 coordination: PACK C lists the guide's printed counts as "printed-value anchors for S2",
  while the frozen S1 P-1 call set (no estimateDisp before glmQLFit) gives 2608/10546/2815 and 1535/12570/1864
  on the same data and edgeR version. The printed anchors now pass on the guide route; the engine keeps the
  S1 route. Whether the suite route should adopt the guide's AveLogCPM (i.e. estimateDisp's cached,
  common-dispersion AveLogCPM), or PACK C should record the suite-route values as the S2 anchor, is for the
  owner. Not decided here; estimator unchanged.
- ranked_list for QL F remains unproduced (formula not frozen; S3 report sec 4 accepts this as safe).

## Shared needs
None so far.

## Notes for the final verifier
- Anchor kinds: C-guide = PRINTED anchors on the guide's own code (text compared with the rendered L1 lines);
  A1/A2 in-test suite-route fits = REPLAY anchors of the engine; C-suite = measured differences between the two
  routes (asserted to 1e-9, cache probe exact); F2 QL = replay of `edgeR::plotQLDisp`; F2 MDS = replay of the guide's
  `plotMDS(y)` plus the printed 65 %/17 %.
- The C-guide block needs `org.Mm.eg.db` (present in the locked image) because the guide adds the Symbol column
  that appears in the printed topTags lines; it also needs the L1 rendered text in `acceptance/exemplars/edger-qlf/`.
- The option-effect checks named "F1 display..." / "F2 legacy..." in the smoke output are the builder's older labels
  for flag checks, not the S3 F items.
- Robust-outlier count differs by method on GSE60450: 0 (new method; df.prior constant 6.373) vs 2654 (legacy).
- Captions show the design as the internal formula `~ 0 + .eqgrp` (existing convention of the module's Methods text).
- ranked_list not added (instruction; not frozen).
