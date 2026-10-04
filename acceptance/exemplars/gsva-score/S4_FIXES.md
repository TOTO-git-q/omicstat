# gsva-score S4 fixes (1.0.0 -> 1.1.0)

Branch `s4/gsva-camera`. Work list: `S3_REVIEW_astra.md` F1-F4, `docs/build/S3_REPORT_astra.md` sec 2, 4, 5 (items 2, 3, 5).
GT103 run dir `~/omic-build-logs/s4/gsva-score` (container `omicstat-r:2026.09.1`). Logs:
`gsva-score-golden1.log` (goldens written, SMOKE PASSED, EXIT 0), `gsva-score-smoke3.log` (plain rerun, golden PASS),
`gsva-score-lock.log` / `gsva-score-lockcheck.log` (module_lock written / `--check` OK).
History: F1-F4 and contracts b/c were implemented by the first S4 helper (commit 41043a9); the resumed helper re-ran
and checked them, fixed the vignette line citations, added the vignette text anchor, regenerated goldens and the lock.

## F1 - no inference from undecided settings (S1 P-3) - fixed
- `scripts/run_gsva_score.R:27-29,35-39`: `--reference/--target/--covariates` are inference requests and are refused
  with `OS_OWNER_DECISION_PENDING` before any output directory is written. The inference code (limma on scores,
  eBayes FALSE/FALSE, score_limma.csv / score_design.csv) is removed from `scripts/gsva_score_core.R`, the report and
  the registry. The module scores and hands on only.
- Methods (`references/reporting-templates.md`) say that no group inference was performed and why; JSON and hand-off
  state carry `inference = false`.
- Evidence (`tests/run_smoke_test.R:48-53`, `:118-123`): three refusal checks (reference+target, covariates alone,
  target alone) with no output directory created; on the suite run no score_limma/score_design table exists,
  `inference` is false, the draft contains "No group inference was performed on the scores" and no eBayes/BH text.

## F2 - original vignette workflow separate from the suite preset - fixed
Anchors, each labelled with its kind in the smoke output (`tests/run_smoke_test.R:55-110`); vignette lines refer to
`acceptance/exemplars/gsva-score/L1_bioc3.23/GSVA/vignettes/GSVA.rendered.txt`:
- PRINTED (the vignette's own code on the sha256-locked GSVAdata acceptance layer): `gbm_eset` 11861 features x 173
  samples (:686); `head(featureNames(gbm_eset))` (:697-698); `table(gbm_eset$subtype)` Classical 38, Mesenchymal 56,
  Neural 26, Proneural 53 (:699-702); `lengths(brainTxDbSets)` 85, 88, 98, 70 (:704-706); `lapply(brainTxDbSets, head)`
  all four (:707-718). The first helper cited these ~20 lines off; corrected.
- Vignette code `gbmPar <- gsvaParam(gbm_eset, brainTxDbSets, maxDiff=FALSE); gbm_es <- gsva(gbmPar)` (:723-724) is run
  as written: finite 4 x 173 matrix. The vignette prints no score values; its text (:727-735) says which subtype each
  set marks, asserted on that maxDiff=FALSE matrix as a qualitative printed-text anchor: highest group mean
  neuronal_up = Neural, astroglia_up = Mesenchymal, oligodendrocytic_up = Proneural, astrocytic_up top two =
  Classical + Neural.
- REPLAY (full matrix): the vignette call on the engine's CSV input gives the same complete 4 x 173 matrix as on the
  ExpressionSet (max |diff| 0), i.e. the module's input is the vignette's data.
- REPLAY (suite preset, separate): the engine's complete 4 x 173 score table equals a direct `gsvaParam(minSize 5,
  maxSize 500, kcdf auto, maxDiff TRUE, ...)` call (max |diff| 5e-16); the two routes are checked to differ
  (max |score diff| 0.1945) so the suite preset is never presented as the vignette.
- The FIR inference example (:1006-1066) is not used as an anchor: inference is refused (F1).
- Evidence: `gsva-score-golden1.log` / `gsva-score-smoke3.log`, lines "A-vig printed", "A-vig text", "A-vig replay",
  "A-suite replay".

## F3 - true post-filterRows per-set sizes - fixed
- `scripts/gsva_score_core.R:16-81`: constant rows (what `filterRows = TRUE` removes for a dense matrix) are listed;
  per-set sizes come from GSVA itself (`GSVA::geneSets()` / `geneSetSizes()` on the returned object) and the table
  gives, per set, n_collection, n_matched_ids, n_after_constant_filter, n_used_by_gsva, retained/excluded and the
  reason; the engine refuses (`OS_INVALID_RESULT`) if GSVA's sizes disagree with that reconstruction.
- `tables/gene_set_sizes.csv`, the JSON (`set_sizes`, n_retained/n_excluded/n_scored) and the Methods sentence
  ("k of n sets were scored (m excluded: reasons); the sizes used by GSVA were min-max, median") come from that table.
- Evidence: GBM suite run astrocytic_up 85->59, astroglia_up 88->69, neuronal_up 98->70, oligodendrocytic_up 70->47,
  equal to `geneSetSizes()` of the direct suite call; `--max-size 60` excludes sets with "more than 60 members" in
  table, JSON and Methods; Astra's boundary (3 sets, one all-constant): n_retained 2, n_excluded 1 (reason "fewer
  than 5 members after GSVA removed constant-expression rows (filterRows)"), n_scored 2, sizes 20 and 10, and the
  Methods/JSON say "2 of 3 sets were scored (1 excluded ...)" and "GSVA removed 10 rows with constant expression"
  (`tests/run_smoke_test.R:213-239`).

## F4 - score-by-group figure and few-row heatmap legends - fixed (one shared cosmetic need)
- `scripts/gsva_score_report.R:8-26`: `figures/score_by_group` (shared `os_score_by_group`: one panel per set, sample
  points over group boxes; descriptive only, no test annotation) whenever a group column is available, including the
  limma sample table of a limma upstream; the heatmap uses the updated shared builder whose few-row version keeps both
  legends.
- Evidence: captions state group n, sets shown and "Descriptive only: no group test is shown"; both legends in the
  draft (`tests/run_smoke_test.R:132-141`). PNGs looked at (see below).
- Shared cosmetic need (not blocking the review item, listed below): heatmap Group colours differ from score_by_group
  colours in the same run.

## Contract (c) - corrected lineage - done
- `scripts/run_gsva_score.R:86-94,130-146`: scores of a batch_corrected_matrix input or a corrected-lineage upstream
  are handed on typed `batch_corrected_matrix` with state `batch_corrected_lineage = TRUE`; QC GV-03 fires.
- Evidence: a DE-style consumer (`read_handoff(expect = expression_matrix)`) refuses them with
  `OS_BATCH_CORRECTED_INPUT`; display consumers can read them as batch_corrected_matrix; a real downstream run of
  limma-camera on them is refused with `OS_BATCH_CORRECTED_INPUT` (`tests/run_smoke_test.R:186-211`).

## Contract (b) - real limma run - done
- `scripts/run_gsva_score.R:62-84`: a limma-voom / limma-array / limma-dupcor run is read with
  `os_limma_handoff_read()`; GSVA scores the EList `E`; the declared `--input-scale` must match the upstream scale
  (`OS_HANDOFF_MISMATCH` otherwise); the limma sample table and condition annotate the figures. Methods, provenance and
  hand-off state say that the EList carries precision weights and that GSVA uses E only and does not use them
  (`precision_weights_used = false`).
- Evidence: real limma-voom run on the Yoruba acceptance counts -> gsva-score scores equal a direct GSVA call on
  `elist$E` (max |diff| < 1e-12); Methods/hand-off text checked; mismatched scale refused
  (`tests/run_smoke_test.R:241-278`).

## Figures looked at (Read, every distinct PNG of `gsva-score-smoke2` / `golden1`)
- a1 (= a2, a3, a5, corrected_scores) `score_heatmap.png`: 4 of 4 sets, 24 of 173 samples, Group and Row z score
  legends, dendrograms, labels not clipped.
- a1 `score_by_group.png`: four panels, per-group boxes with points, subtype legend, y title "GSVA score", rotated
  group labels readable; no test annotation.
- a4 (max-size 60) `score_heatmap.png`: two rows, both legends present (the S3 defect); `score_by_group.png`: two
  panels, legend present.
- gsva_from_voom `score_heatmap.png` / `score_by_group.png`: Y and X rows, Female/Male groups, legends present.
- no_kernel and poisson `score_heatmap.png`: no sample table -> no Group track, Row z legend present.
- Observation: Group colours differ between heatmap and score_by_group (e.g. Male orange vs blue) - shared need 1.

## Known failing anchors
None.

## Owner items
- S1 P-3 (unchanged, not decided here): which limma entry receives GSVA scores and the eBayes trend/robust (gene-set
  size trend) settings. Until then inference requests are refused with `OS_OWNER_DECISION_PENDING`.
- If the owner wants the FIR/SV/robust/size-trend vignette inference (:1006-1066) as a printed anchor, it can only be
  added after P-3 is decided.
- Hallmark stays `OS_REFDATA_MISSING` (asserted). No KEGG.

## Shared needs
1. `skills/_shared/scripts/fig_mod_enrich_rank.R::os_gsva_score_heatmap()` - pass
   `annot_colours = list(Group = os_group_colours(levels(annot$Group)))` to `os_heatmap()` when `annot` is not NULL, so
   the heatmap Group track uses the same colours as `os_score_by_group()` (which uses `os_group_colours(lv)`).
   Why: in one run the two figures colour the same group differently (GBM: Classical blue vs orange; Yoruba: Male
   orange vs blue) - misleading side by side. Item: F4 (figure consistency). Goldens of gsva-score must be regenerated
   after the change.
2. Same function, caption: "Set sizes after gene ID intersection: min-max" should read "Set sizes after gene ID
   intersection and GSVA's constant-row removal: min-max" (matches F3 and the Methods). Item: F3 wording.

## Notes for the final verifier
- `tests/golden_manifest.csv` now locks scores.csv, gene_set_sizes.csv, the result JSON and both figures (PNG +
  spec); the old score_limma/score_design goldens are gone with F1.
- The A-vig text anchor is qualitative (group-mean ordering stated in prose); it is labelled as such and is not a
  numeric printed anchor.
- Run `bash docs/build/agent_briefs/s4_run.sh gsva-score <tag> Rscript skills/gsva-score/tests/run_smoke_test.R`.
