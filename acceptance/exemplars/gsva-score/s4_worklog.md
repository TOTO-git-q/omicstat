# gsva-score S4 worklog

Branch `s4/gsva-camera` (shared with limma-camera; its worklog is `../limma-camera/s4_worklog.md`). GT103 run dir
`~/omic-build-logs/s4/gsva-score`.

## Verified state
- 2026-09-29 (first helper, cut off ~04:30): F1-F4 + contracts b/c implemented and committed (41043a9, v1.1.0).
- 2026-09-29 (resumed helper): merged integrate/m1m2 (limma_io res[["expr"]] fix). Re-ran smoke at HEAD 0074ea8
  (`gsva-score-smoke2.log`): everything PASS except the golden check (golden manifest still lists the removed
  score_limma.csv / score_design.csv; regeneration pending). All 16 PNGs of that run looked at: legends present on the
  full and the two-row (max-size 60) heatmap, score-by-group boxes with group n in caption, no test drawn.
- Found: heatmap Group colours (os_heatmap default annotation palette) disagree with score_by_group colours
  (os_group_colours) -> shared need (os_gsva_score_heatmap should pass annot_colours). Heatmap caption wording
  "after gene ID intersection" omits constant-row removal -> shared need.
- Fixed in the smoke test: vignette line citations (were off by ~20 lines); added the vignette text anchor
  (:727-735, which subtype each set marks) on the vignette's own maxDiff=FALSE score matrix.

- Final: golden1 (goldens written, SMOKE PASSED) and smoke3 (plain rerun, golden PASS); module_lock regenerated and
  `--check` OK (14 files); S4_FIXES.md written; committed d1bb879.

## Next step
- None for this helper. Open: shared needs 1-2 in S4_FIXES.md (heatmap group colours, caption wording); owner item P-3.
