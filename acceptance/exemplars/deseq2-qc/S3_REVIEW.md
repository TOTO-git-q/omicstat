# S3 review -- deseq2-qc (independent reviewer, 2026-09-27)

GT103 run name: `s3-deseq2-qc`. Reviewed tree: `build/m1m2` HEAD e6b5b13 (read-only).
STATE: **PAUSED by owner request (quota) mid-review; no verdict yet.** Not committed (reviewer brief:
only this file may be written, no commits).

## Checklist
- [x] 0. Read brief, PACK (+ S1 appendix), SUITE M1/M2, builder worklog, all module code/docs
- [~] 1. Anchors (PACK C) -- smoke PASSED in container; printed A1 values checked vs L1; replay A2 code origin judged (finding F1); probe P3/P4 NOT yet run
- [ ] 2. Table shape (PACK T) -- code read (finding F2); real table not yet inspected
- [~] 3. Wording (PACK W) -- template read (finding F3); real `draft/methods_results.md` of a1 not yet read
- [~] 4. Mechanical -- registry vs appendix done (findings F4, F5); vst guard probe P1/P2 not yet run
- [ ] 5. Figures -- PNGs not yet copied/viewed
- [~] 6. Coordinator points 1-4 -- preliminary judgements below

## Evidence so far
- Smoke test in container (`gt_run.sh s3-deseq2-qc smoke`, log `~/omic-build-logs/s3-deseq2-qc-smoke.log`):
  `SMOKE PASSED`, `EXIT 0`, no FAIL and no SKIP lines; G golden baseline PASS; no Rplots.pdf;
  D1 --spec replay byte-identical; D2/D3 forward chain into deseq2-wald OK. Outputs on GT103 under
  `~/omic-build-logs/runs/s3-deseq2-qc/_smoke/deseq2-qc-smoke/{a1,a2,a3,...}`.
- PRINTED anchor (coordinator point 2): `L1_bioc3.23/DESeq2/vignettes/DESeq2.rendered.txt:925-936`
  `vsd <- vst(dds, blind=FALSE); head(assay(vsd), 3)` prints exactly the three rows asserted in
  `tests/run_smoke_test.R:66-68` (same 7-column order treated1..3, untreated1..4). Classification
  "printed" is honest. The vignette's dds there is post-`DESeq()` (line 525), the engine's is
  size-factors-only; `vst()` refits the trend on its nsub subset in both cases, and the container
  assertion (tol 5e-6 relative) passed, so the engine path reproduces the printed values.
- REPLAY anchor (point 2): `run_smoke_test.R:104-123`. The vst part is the vignette construction
  (pre-filter, `DESeqDataSetFromMatrix`, `vst(blind=TRUE)`), but the PCA part is NOT the vignette's
  `plotPCA(vsd, intgroup = c("condition","type"))`: it hand-codes `apply(var)`, a radix tie-break
  on rownames, `prcomp` and the lock-4 sign normalisation -- i.e. it mirrors `_shared os_pca_scores`
  (engine code), not the vignette. It also asserts only PC1/PC2 of 2 samples; the vst matrix, the
  percent variance and the sample distances (all named in PACK C) are not asserted.
  `references/method-basis.md:44-47` says the test "checks that the engine's default output matches
  it exactly" -- overstated.
- P-2 (point 1): no outlier/flag column, no threshold, no removal anywhere (`deseq2_qc_core.R:248-267`,
  `deseq2_qc_qc.R` DQ-01..07 none keyed to PCA/distance; smoke A2 asserts no outlier/flag column).
  Draft heading + `outlier_note` template say "interim, PACK P-2 pending"; SKILL.md Known limitations
  says "class C, pending". BUT the table ships `dist_to_group_centroid` (unscaled Euclidean distance
  in the PC1/PC2 plane to the inclusive group mean) and the Results template advertises it "for
  manual review" -- this is exactly the statistic whose definition/scaling/group-size requirement the
  S1 appendix P-2 lists as missing evidence, while the appendix freezes only "plotPCA(ntop = 500,
  pcsToUse = 1:2) 只出图". Preliminary: a C item decided in part (the statistic's definition) -> F2.
- estimateSizeFactors `type` (point 3): the S4 `.local` claim is true for the exported generic, but
  `_shared/scripts/calls_check.R:84-86` ALREADY supports a registry `"method"` field looked up in the
  package namespace; if `DESeq2:::estimateSizeFactors.DESeqDataSet` exists in 1.52.0 (to verify, probe
  P2) the default IS mechanically checkable with the existing tool. Also: `"source": "vignette"`,
  `"pack": "D-QC-SF"` -- no such PACK D row; L1 has no `estimateSizeFactors.Rd` although the PACK L1
  row lists it; `locfunc` (default `stats::median`, result-affecting) is not registered/written.
- Pre-filter simple design (point 4): `deseq2_qc_core.R:197-209` simple = no `--covariates` AND exactly
  2 condition levels -> smallest level; else explicit `--min-samples` or `OS_MISSING_PARAMETER`
  (smoke E2). Mirrors deseq2-wald 1.1.0 (SUITE line 318: covariates or >2 levels -> explicit). With
  pasilla (`--shape-col type` is display only) resolves to 3 = vignette smallestGroupSize. Preliminary:
  acceptable and conservative; not a PACK row -> note (record as PACK D-11 addendum).

## Preliminary findings (to be confirmed before the verdict)
- F1 [PACK C] replay anchor uses engine-mirrored PCA code, not `DESeq2::plotPCA(..., returnData=TRUE)`;
  asserts 2 samples only; no vst-matrix / percentVar / `dist(t(assay(vsd)))` assertion.
- F2 [S1 appendix P-2, PACK T] `dist_to_group_centroid` column + Results sentence pre-empt the pending
  statistic definition; appendix allows plot only.
- F3 [PACK W] Methods template (`references/reporting-templates.md:10`) omits result-affecting
  arguments: `nsub = 1000`, `fitType` (user-changeable `--fit-type`), size-factor type (`--sf-type`
  poscounts possible), the `varianceStabilizingTransformation` fallback when DQ-05 fires (DQ-05's own
  action says to state it), rlog vs vst naming is filled but the `blind = FALSE` supplement is never
  mentioned when requested. Also internal jargon "PACK P-2" in a paper-facing draft (cosmetic).
- F4 [lock 3 / point 3] estimateSizeFactors registry entry: mislabeled source/pack; checkable via
  `"method"` field (pending probe); `locfunc` unregistered.
- F5 [PACK X] vst fallback condition is `nrow(dds) >= 1000` (`deseq2_qc_core.R:217`), but DESeq2's
  `vst()` (to confirm, probe P1) stops when fewer than `nsub` rows have mean normalized count > 5 ->
  possible untyped DESeq2 error for >=1000 rows with <1000 rows of baseMean > 5 (e.g. `--min-count 0`).

## NEXT STEP
1. Probe is already on GT103 at `~/omic-build-logs/runs/s3-deseq2-qc/s3_deseq2qc_probe.R` (copy
   also in the session scratchpad; if lost: rewrite it -- it prints `deparse(body(vst))`
   lines matching nsub/baseMean; `exists("estimateSizeFactors.DESeqDataSet", asNamespace("DESeq2"))` +
   its formals; the vignette code verbatim (pre-filter, relevel, `DESeq`, `vst(blind=FALSE)` head);
   `plotPCA(vst(ddsraw, blind=TRUE), intgroup=c("condition","type"), returnData=TRUE)` vs
   `_smoke/deseq2-qc-smoke/a2/tables/sample_qc_descriptive.csv` (abs + sign), percentVar vs results
   JSON, engine `vst_matrix.csv` vs `assay(vsd)`, `dist(t(.))`, size factors vs `DESeq()`) into
   `~/omic-build-logs/runs/s3-deseq2-qc/` and run `gt_run.sh s3-deseq2-qc probe Rscript s3_deseq2qc_probe.R`.
2. Engine run to test F5: synthetic >=1000 rows with <1000 rows of baseMean > 5, `--min-count 0`.
3. scp a1 `draft/methods_results.md`, `results/*.json`, `tables/sample_qc_descriptive.csv`, all
   `figures/*.png` + `*.figure_spec.json`; read them (checks 2, 3, 5).
4. Finalise F1-F5 and write the verdict line.
