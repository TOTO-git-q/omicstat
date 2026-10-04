# build_worklog -- deseq2-qc (S2 builder)

- module: deseq2-qc
- worktree: E:\claude workspace\skills-dev\omic-wt-deseq2-qc (Git Bash: /e/claude workspace/skills-dev/omic-wt-deseq2-qc)
- branch: wip/deseq2-qc
- GT103 run name: deseq2-qc (~/omic-build-logs/runs/deseq2-qc/)
- started: 2026-09-27

## Checklist (BUILDER_BRIEF sec 3)

- [x] 1. Scaffold via tools/new_module.py deseq2 qc
- [x] 2. Engine (run_deseq2_qc.R, core, spec, typed errors)
- [x] 3. scripts/calls_registry.json (defaults verified in container)
- [x] 4. QC rules (DQ-xx)
- [x] 5. references/*.md + SKILL.md
- [x] 6. Figures via _shared only
- [x] 7. tests/run_smoke_test.R + fixtures
- [x] 8. Smoke test green in container; goldens; module_lock.json
- [x] 9. Look at every figure PNG
- [x] 10. Final commit

## VERIFIED facts

- (2026-09-27) Read BUILDER_BRIEF.md, MODULE_BUILD_BRIEF.md, ENGINEERING_PLAN.md parts 1-9,
  SUITE.md "M1/M2 S1 审定", acceptance/exemplars/deseq2-qc/PACK.md (incl. S1 appendix),
  docs/build/S1_DECISION_TABLE_M1M2.md deseq2-qc rows, reference module skills/deseq2-wald
  in full (entry, core, report, qc, calls_registry, references/*, SKILL.md, tests, fixtures,
  module_lock.json), skills/_shared/scripts/{args,module_kit,engine_run,design_check,
  feature_table,handoff,fig_bulk,fig_all,fig_mod_bulk,fig_style(colour registry section)}.R,
  skills/_shared/docs/CONVENTIONS.md, tools/new_module.py, tools/qc_prefixes.json (DQ planned
  prefix), acceptance/exemplars/deseq2-qc/L1_bioc3.23/DESeq2/{defaults.tsv,Rd/*,vignettes/*}.
- DESeq2 vignette (rendered, this exemplar's L1) confirms: pasilla dds is built with
  design = ~ condition, pre-filter smallestGroupSize = 3 (count >= 10 in >= 3 samples,
  matching deseq2-wald's own D-11 anchor of 8,148 features), then `dds <- DESeq(dds)`;
  later `vsd <- vst(dds, blind=FALSE)` with PRINTED values for head(assay(vsd), 3):
  FBgn0000008 = 7.777746 7.984491 7.765448 7.735026 7.807720 7.997378 7.832458 (cols:
  treated1 treated2 treated3 untreated1 untreated2 untreated3 untreated4);
  FBgn0000017 = 11.954934 12.035700 12.028610 12.049838 12.295662 12.471723 12.089675;
  FBgn0000018 = 9.219162 9.089390 9.028791 9.374577 9.173538 9.052143 9.142848.
  plotPCA(vsd, intgroup=c("condition","type")) and sampleDists <- dist(t(assay(vsd)))
  follow on the SAME vsd (blind=FALSE) -- no printed numeric values for those (figure only)
  and no printed value at all for blind=TRUE on this dataset (blind=TRUE is described only in
  prose). Plan: primary QA path is blind=TRUE (P-1, no printed anchor -> use a REPLAY anchor:
  recompute vst(dds, blind=TRUE) on the identically-constructed, sha256-checked pasilla dds
  in the smoke test session and compare to the engine's default output); optional
  --blind-false-supplement flag (default off) reproduces the vignette's blind=FALSE path and
  is checked against the three PRINTED gene rows above (a true printed-value anchor).
- skills/_shared/scripts/fig_bulk.R already has os_pca_scores/os_pca_plot (plotPCA-equivalent:
  ntop most-variable rows, prcomp centred/unscaled, PCA sign normalization) and
  os_sample_distance (Euclidean dist(t(assay)), pheatmap-style). Both pre-exist and match PACK
  F section exactly -- decided NOT to add a new builder to fig_mod_bulk.R (it stays empty);
  the optional size-factor diagnostic will use the existing generic os_diag_xy(kind="points")
  with numeric x = log10(library size) (no new shared code, no FIGURE_STYLE.md edit needed).
- P-2 (outlier statistic/threshold) is C, pending, and the "display/flag-only, never remove"
  sub-question is itself flagged 待澄清 (not pre-approved). Decision for this build (safest
  interim per BUILDER_BRIEF sec 5 and the coordinator's task instructions): the per-sample
  table is PURELY DESCRIPTIVE (sample, condition, [second factor], size_factor, PC1, PC2,
  dist_to_group_centroid) -- no "outlier"/"flag" column, no QC rule keyed to it, no threshold
  anywhere in code or docs; SKILL.md/qc-rules.md/reporting-templates.md state this is INTERIM
  pending the owner's P-2 decision.
- deseq2-qc has no upstream module (root of the bulk chain); --from-run is NOT offered for
  input. It IS the upstream of deseq2-wald/deseq2-lrt: handoff carries count_matrix,
  sample_table (byte-identical copies of the input, same object types deseq2-wald's
  read_handoff expects), expression_matrix (the primary QA vst/rlog matrix, blind=TRUE),
  and colour_registry.
- Pre-filter (D-11): same rule as deseq2-wald (count >= min-count in >= min-samples samples),
  min-samples 0 = smallest level of --condition ONLY when the design is a simple case (no
  --covariates and exactly 2 condition levels); otherwise explicit --min-samples is required
  or OS_MISSING_PARAMETER (BUILDER_BRIEF sec 6 / deseq2-wald P-3 pattern). NOTE: deseq2-qc's
  --condition is not restricted to 2 levels (no contrast is fit), so with 3+ levels the
  "smallest of two compared groups" idea does not apply -- the rule instead reads "smallest
  of all condition levels" for the simple case (no covariates, exactly 2 levels), matching
  the vignette's own smallestGroupSize logic; recorded as a S2 judgment call, not a fresh
  PACK decision (report it in 待裁决 below).

- Container probes (GT103, omicstat-r:2026.09.1, DESeq2 1.52.0, Bioconductor 3.23, R 4.6.1):
  `vst`/`rlog`/`varianceStabilizingTransformation`/`DESeqDataSetFromMatrix` are plain functions
  (isGeneric FALSE); their formals matched calls_registry.json exactly on the first
  check_default_drift run (blind=TRUE, nsub=1000, fitType="parametric", tidy=FALSE,
  ignoreRank=FALSE) -- no drift. `estimateSizeFactors` IS an S4 generic
  (`isGeneric("estimateSizeFactors")` TRUE) whose `DESeqDataSet` method is a thin
  `function(object, ...) { .local <- function(object, type = c("ratio","poscounts","iterate"),
  ...) ...; .local(object, ...) }` wrapper (confirmed via `getMethod(...)` + body reflection in
  the container): `formals()`/`getMethod()` never expose `type`, so `check_default_drift` would
  report it `<absent>` no matter what value is declared. Decision: no `function_default` is
  recorded for that one argument (documented in calls_registry.json with a `note` explaining why
  and citing the container reflection that established the true default is
  `c("ratio","poscounts","iterate")`); `check_default_drift` correctly skips a field with no
  `function_default` and PASSED cleanly once this was in place. This is an S2 implementation
  detail, not a fresh PACK decision (estimateSizeFactors/--sf-type itself mirrors deseq2-wald's
  D-04 sfType convention, cross-referenced in the registry).
- Smoke test iterations fixed on GT103 (all now PASS): (1) `--shape-col type` crashed
  `deseq2_qc_render` because `res$design$coldata` only ever carried `--covariates` + `--condition`,
  not `--shape-col` -- fixed by giving `dq_design()` a `shape_col` argument that rides along in
  `coldata` for display only (never enters the model formula/model.matrix); (2) an R parse error
  `could not find function "&&<-"` from `if (r$status==0 && r2ok <- file.exists(...))` in the
  smoke test -- split into two statements; (3) the D3 tamper test's `file.copy(list.files(...),
  ...)` silently failed on files whose destination subdirectory did not exist yet -- switched to
  `file.copy(a2, tamp_parent, recursive = TRUE)`; (4) the F2 flag-effectiveness test's
  `--min-count 400` on the synthetic negbinom(mu=200,size=5) fixture filtered out all 600 genes
  (`OS_DEGENERATE`) -- lowered to `--min-count 250` (expected ~140/600 genes survive, confirmed
  in the run: reduces from 600 to a smaller nonzero count, as intended).
- Full smoke test green in the container (all sections: static checks incl. check_calls,
  check_default_drift, check_defaults.py, check_flag_docs.py (17/17 flags documented), lint_r.py;
  A1 printed anchor blind=FALSE matches vignette's 3 printed gene rows exactly; A2 REPLAY anchor
  blind=TRUE PC1/PC2 for treated1 and untreated4 matched an independent in-session
  vst(blind=TRUE)+prcomp recomputation; A3 rlog path; D1 --spec replay byte-identical on 7 files;
  D2 forward chain deseq2-qc -> deseq2-wald --from-run exits 0 with a non-empty feature table;
  D3 tampered handoff refused with OS_HANDOFF_MISMATCH; E1-E6 typed errors/blockers incl. the new
  complex-design OS_MISSING_PARAMETER rule and DQ-01/02/03 blockers; F0-F4 flag effectiveness incl.
  DQ-04 singleton-group warning and DQ-05 vst-nsub-fallback info rule; G golden baseline PASS
  (not SKIP) after `tools/make_module_lock.R` and copying `golden_manifest.csv` back and
  re-syncing). `module_lock.json` generated (14 files, DESeq2 1.52.0, container tier, Bioc 3.23).
  Looked at all 4 anchor-run figures (pca, sample_distance, size_factor, pca_blind_false PNGs):
  no overlapping/clipped labels, legends and axis titles readable, captions state the transform,
  its `blind` value, n, and (for pca_blind_false) that it is supplementary, not the primary output.

## NEXT STEP
2026-09-28 lane M1 S3 defect fixes: version 1.0.1. Removed the pending centroid-distance column,
Results pointer, and all active documentation promises of that statistic; retained descriptive
PC scores and size factors only. Methods now names size-factor type, nsub, fitType, actual
varianceStabilizingTransformation fallback and the requested blind=FALSE supplement. DQ-05 checks
eligible rows (normalized mean > 5), including the new >=1000-row/low-mean regression F5.
estimateSizeFactors now registers/checks the DESeqDataSet method's type and locfunc defaults.
The method's geoMeans/controlGenes/normMatrix defaults are *missing arguments*: explicitly
supplying NULL causes a different branch and broke pasilla in the first container test; these
remain omitted intentionally. The subsequent container smoke had every check PASS except the
expected stale golden mismatch; golden-write run then passed every check, including G.
All four a1 PNGs were reopened: axes, legends and data are readable and unclipped; method,
sample count and supplement status are in their figure specs. Ordinary smoke rerun PASS,
G golden PASS, no Rplots.pdf. `module_lock.json` regenerated (1.0.1, 14 files, container).
S3 request updated. Next: independent S3 review; replay-anchor question F1 belongs to reviewer.

## 待裁决 (S2 follow-up)

- P-2 centroid-distance definition, scaling, group-size requirement and any threshold remain
  open. The column was removed; no sample is automatically flagged or removed. See the owner's
  S1 appendix and reviewer finding F2.

## 待裁决 (S2)
- P-2 (sample-outlier statistic/threshold): implemented as the safe interim (purely descriptive
  per-sample table, no flag/threshold/removal); SKILL.md "Known limitations", qc-rules.md header
  note, and reporting-templates.md's `outlier_note` template all state this is INTERIM pending the
  owner's P-2 decision (mirrors the PACK's own unresolved 待澄清 on whether even "display/flag-only,
  never remove" is pre-approved -- this build treats nothing as pre-approved and adds no flag at
  all, only display).
- Pre-filter auto-`--min-samples` rule for deseq2-qc's "simple case": since this module has no
  --reference/--target contrast, "simple" was defined as "no --covariates and exactly 2
  --condition levels" (smallest of those two levels), rather than deseq2-wald's "smallest of the
  two COMPARED groups". This is a straightforward carry-over of the BUILDER_BRIEF sec 6 /
  deseq2-wald P-3 pattern to a module with no contrast, not a new PACK decision; flagging it here
  in case the coordinator wants it stated as an explicit PACK row later.
- `estimateSizeFactors`'s `type` argument default could not be mechanically drift-checked (S4
  generic wrapping a `.local` closure, see VERIFIED facts above); documented in
  calls_registry.json with a `note` instead of a `function_default`. Flagging in case the
  coordinator wants `_shared/scripts/calls_check.R` extended with a `"method"`-style override for
  this Bioconductor idiom (would help other modules that call estimateSizeFactors too, e.g. any
  future module needing explicit size-factor control).
2026-10-01 env_rebuild: baseline new-image smoke PASS; existing golden retained; lock refreshed/check; addon-specific checks pending
deseq2-qc: final 2026.10.1 smoke PASS (non-root/offline; golden unchanged; lock checked; awaiting independent S3); next remaining full R suite
