# M1 + M2 build worklog (coordinator)

Task: build M1 (7 modules) + M2 (6 modules) of omicstat, deseq2-wald 1.1.0, env test fixes, plan sync.
Spec: owner task `opus_build_m1m2.md` (2026-09-27) with laptop adaptations A/B:
- code edited on the laptop worktree `E:\claude workspace\skills-dev\omic-build` (branch build/m1m2), committed there;
- every R run / test / golden runs on GT103 in `omicstat-r:2026.09.1` via the mirror `~/omic-build`
  (sync: push branch, then `git -C ~/omic-build fetch -q origin && git -C ~/omic-build reset -q --hard origin/build/m1m2`);
- long jobs on GT103: `setsid nohup ... > ~/omic-build-logs/<name>.log 2>&1 &`;
- on GT103 touch only ~/omic-build, ~/omic-build-logs, `docker run --rm omicstat-r:*`.

Resume rule: read this file, continue from the first step without DONE.

## Steps
| # | step | status | commit |
|---|---|---|---|
| 1a | merge origin/env/gt103-build-20260927 | DONE | dfdac21 |
| 1b | MCP python test failures, env/test.sh green | DONE (ALL PASSED, 0 skipped) | 5275d46, 71470c4 |
| 2 | deseq2-wald 1.0.0 -> 1.1.0 | DONE (goldens+lock from container, SUITE written) | 212681b |
| 3 | M1: deseq2-qc, deseq2-lrt, edger-qlf, limma-voom, limma-array, limma-dupcor, sva-batch | PAUSED in progress -- see RESUME POINT at the end | |
| 4 | M2: clusterprofiler-ora, -gsea, -compare, fgsea-prerank, gsva-score, limma-camera | todo | |
| 5 | ENGINEERING_PLAN v1.2 plan sync | todo | |
| 6 | M1M2_BUILD_REPORT.md, push, DONE | todo | |

## Log
- 1a: merge conflicts: github_pins.txt -> build-branch row order (as installed, +BPCells/speedglm) plus a
  provenance comment; docs/figure-gallery -> kept current (build branch gallery came from old 89f3696
  shared code); gallery to be regenerated in the container from current code.
- 1b: root causes verified on GT103: (i) root in container vs toto-owned checkout -> git "dubious ownership";
  (ii) ~/omic-build is a linked worktree, .git pointer outside the mount -> "not a git repository";
  (iii) ST-07: native route inside the image inherited OMICSTAT_CONTAINER=1. Fixes: env/test.sh (--user,
  GIT_CONFIG safe.directory, ro mount of git common dir), router native branch unsets the marker.
  env/test.sh on 5275d46: ALL PASSED, 0 skipped (report committed 71470c4). No image rebuild.
- Acceptance data layer (S1 M1-2): acceptance/data/install_acceptance_lib.R + acceptance_lib_lock.csv;
  installed on GT103 in ~/omic-build/.omicstat-acceptance (git-ignored); pasilla extracted-only (needs DEXSeq).
  Bulk anchor files fetched (fetch_anchor_data.sh bulk) into ~/omic-build/acceptance/data.
- Shared: OS_BATCH_CORRECTED_INPUT in read_handoff (2bb817c); fig_mod_bulk.R / fig_mod_enrich.R slots.
- Gallery regenerated in container (6 PNGs changed, inspected) -> committed.
- Builders (sonnet, background): deseq2-qc (wt omic-wt-deseq2-qc, branch wip/deseq2-qc, GT103 run deseq2-qc),
  sva-batch (wt omic-wt-sva-batch, wip/sva-batch, run sva-batch). Brief: scratchpad omic-tools/BUILDER_BRIEF.md;
  helpers gt_sync.sh / gt_run.sh / gt_wait.sh in the same folder.
- Figure review of deseq2-wald pasilla volcano/MA found label-label overlaps (ggrepel 0.9.8 stops early;
  fixed aspect.ratio worsens it). Fix: new deterministic placer os_label_place (fig_style.R 12b), volcano/MA
  without aspect.ratio (volcano 92 mm), FIGURE_STYLE 1.3.0. NOTE: style version is written into every
  figure_spec -> goldens of modules built before this change must be regenerated at S5.

## PAUSED 2026-09-27 (owner: Claude weekly quota) -- RESUME POINT

Local worktrees live under `E:\claude workspace\skills-dev\`. GT103 helpers and agent briefs:
`docs/build/agent_briefs/` (BUILDER_BRIEF.md, S3_REVIEWER_BRIEF.md, gt_sync.sh, gt_run.sh, gt_wait.sh;
the briefs refer to the session scratchpad copy -- on resume copy the folder to a new scratchpad and
update the `$T` path in both briefs).

| module | status | where | exact next action |
|---|---|---|---|
| deseq2-wald 1.1.0 | S2 follow-ups done; goldens + lock from the container; SUITE written | build/m1m2 (212681b) | nothing to install (router row / rules exist); mention in the final report |
| deseq2-qc 1.0.0 | S2 done (sonnet), merged 52da505; goldens + lock regenerated on the merged tree (86f2538); coordinator looked at all 4 figures: OK | build/m1m2 | **awaiting independent S3 -- partially done.** Opus reviewer paused with no verdict; notes in `acceptance/exemplars/deseq2-qc/S3_REVIEW.md` (smoke PASS in container, printed anchor verified; open findings F1 replay anchor re-implements the engine's PCA instead of DESeq2::plotPCA and asserts only 2 samples; F2 `dist_to_group_centroid` column + Results pointer go beyond the pending P-2; F3 Methods template omits nsub/fitType/sf type/fallback/supplement; F4 estimateSizeFactors registry entry mislabelled, `locfunc` unregistered, maybe checkable via registry "method"; F5 vst fallback condition may miss the "<1000 rows with mean > 5" case). Next: a NEW opus reviewer reads S3_REVIEW.md and continues from its NEXT STEP (probe script already on GT103: `~/omic-build-logs/runs/s3-deseq2-qc/s3_deseq2qc_probe.R`); then S4 fixes by the coordinator (F2: safest = drop the centroid column or keep it out of the draft until P-2 is decided); then S5 |
| sva-batch 1.0.0 | S2 done (sonnet), merged; coordinator figure review found internal column names (".batch_display"/".study_var_display") in legends and caption, "SUITE rule 7" in the figure title, no method in the caption. FIXED in the pause WIP commit (fig_mod_bulk.R `os_batch_pca_pair(method_label=)`, sva_batch_report.R uses the user's column names) but NOT re-run: goldens/lock in the tree are stale | build/m1m2 | 1) `gt_sync.sh "/e/claude workspace/skills-dev/omic-build" main`; `GT_ENV="OMICSTAT_WRITE_GOLDEN=1" gt_run.sh main sb-golden Rscript skills/sva-batch/tests/run_smoke_test.R` (fix the smoke test if it asserted the old labels); 2) copy `skills/sva-batch/tests/golden_manifest.csv` back; `gt_run.sh main sb-lock Rscript tools/make_module_lock.R sva-batch`; copy the lock back; 3) look at batch_pca PNGs of runs a1, a5, f0 again; 4) independent S3 (opus); 5) S5. Design point for S3: sva/svaseq display matrix = `limma::removeBatchEffect(batch = NULL, covariates = SVs, design = mod)`. New handoff type `sv_table`. Builder's shared changes: `os_acceptance_data` single-object fallback (bladderbatch data name differs from the object); `os_compose` default_height_mm -> regenerate the gallery once and look at F1/F2 |
| deseq2-lrt | S2 WIP (sonnet, paused): scaffold, core, qc (DL-01..13), new shared `os_lrt_trajectory()` in fig_mod_bulk.R (not yet run) | worktree `omic-wt-deseq2-lrt`, branch `wip/deseq2-lrt` (310a2f9); worklog `acceptance/exemplars/deseq2-lrt/build_worklog.md` NEXT STEP has 8 items | resume a sonnet builder with the same prompt (in this worklog's history: see agent_briefs + PACK); DEGreport is NOT in the image, so P-2 pattern clustering is not built (owner item) |
| edger-qlf | S2 WIP (sonnet, paused; see its worklog) | worktree `omic-wt-edger-qlf`, branch `wip/edger-qlf`; worklog `acceptance/exemplars/edger-qlf/build_worklog.md` | resume a sonnet builder; it continues from its worklog |
| limma-voom, limma-array, limma-dupcor | not started | -- | S2 builders (max 2 at a time). limma-voom first: export edgeR 4.10.5 `voomLmFit` Rd + formals in the container into `acceptance/exemplars/limma-voom/L1_bioc3.23/` with sha256 (task section 5) |
| M2 (6 modules), plan sync (step 5), report (step 6) | not started | -- | after M1 |

The wip branches `wip/deseq2-lrt` and `wip/edger-qlf` are local branches of the shared repository
(not pushed); they are recorded here and must be merged into build/m1m2 when their S2 finishes.

GT103 state: mirror `~/omic-build` (git worktree; acceptance layer in `.omicstat-acceptance`; bulk anchor
files fetched into `acceptance/data`); per-agent run copies in `~/omic-build-logs/runs/<name>/` (main,
deseq2-qc, sva-batch, deseq2-lrt, edger-qlf, s3-deseq2-qc). No coordinator container run was left running.

Router rows / module_rules records from the builder reports, to install at S5:
- deseq2-qc: `| does the RNA-seq count data look OK before testing it? sample PCA, sample clustering, batch/outlier check before deseq2-wald/deseq2-lrt, 样本质控, 样本PCA, 样本聚类 | deseq2-qc | scripts/run_deseq2_qc.R |` (add backticks); rules record PUB-M-DESEQ2QC-001 (design_conditional; allow_no_effect_table; narrative: never call a sample an outlier or removed).
- sva-batch: `| batch effect, ComBat, ComBat-seq, sva, svaseq, surrogate variable, 批次效应, 批次校正 | sva-batch | scripts/run_sva_batch.R |`; rules record: a corrected matrix is never a DE input (enforced by OS_BATCH_CORRECTED_INPUT).

Owner items so far: (1) deseq2-wald `log2fc` column holds shrunken values (unchanged); (2) deseq2-qc P-2
interim = display only, no outlier call (S3 finding F2 pending); (3) DEGreport missing from the image
(deseq2-lrt P-2 needs an image rebuild); (4) limma-voom `voomLmFit` call set (not built yet); (5) builder
worktrees add entries under omic-MCP/.git/worktrees (shared git metadata of the review clone; its working
tree is untouched) -- remove them with `git worktree remove` after merging.

WIP branch heads at pause (local only, not pushed per the push rule): wip/deseq2-lrt = 310a2f9 (scaffold, core, qc DL-01..13, os_lrt_trajectory not yet run); wip/edger-qlf = 795eada (scaffold + design decisions in its worklog; no engine code yet, no GT103 run). Both worklogs hold an exact NEXT STEP.
