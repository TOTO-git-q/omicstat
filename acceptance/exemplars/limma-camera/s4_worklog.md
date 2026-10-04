# limma-camera S4 worklog

Branch `s4/gsva-camera` (shared with gsva-score). GT103 run dir `~/omic-build-logs/s4/limma-camera`.

## Verified state
- 2026-09-29 (first helper): F1-F5 + contracts b/c implemented, left uncommitted at the rate-limit cut-off; the
  coordinator saved them as WIP 644c72e (unverified). Its last smoke (`limma-camera-smoke2.log`) failed F4 + golden.
- 2026-09-29 (resumed helper): re-ran smoke at HEAD 0074ea8 (`limma-camera-smoke3.log`): everything PASS (F1 printed
  camera anchor via guide code + adaptive.span = FALSE, suite replay, F2 drafts per route, F3 figures, F4 83
  call-site args, F5 asset, contracts b/c) except the golden check (regeneration pending). All distinct PNGs of that
  run looked at: bar charts have axis titles and a Direction legend on every route (roast shows Up only, the one
  direction present); barcodes show worm + members; MD plots highlight Y/X with a legend.
- Found and fixed: cameraPR on a file without metadata wrote "the declared by the user contrast ... the opposite of:
  ..."; now "the user-declared contrast", "the opposite direction", "null test not stated in the file".
  cameraPR Y P underflows to 0 -> barcode legend said "BH adjusted P = 0"; now "< 2.23e-308 (below double precision,
  returned as 0)" plus a draft note. registry check now also ties each flag binding's value to flag_defaults.
  F5 asset: LC-EVAL-03 evidence re-verified in the PMC OA BioC text (Europe PMC XML not served); wording corrected.
  SKILL.md / method-basis / qc-rules (LC-06) / troubleshooting updated.

- Resumed fix 2: cameraPR-voom barcode y title (long metric) overlapped the panel tag -> short axis label; asserted.
- Final: golden2 (goldens written) and smoke5 (plain rerun, golden PASS, SMOKE PASSED); module_lock regenerated
  (lock2) and `--check` OK (14 files); every distinct PNG looked at; S4_FIXES.md written. Commits e470043 + this one.

## Next step
- None for this helper. Open: shared needs in S4_FIXES.md (MD highlight palette); owner item (suite voom span).
