# limma-array S4 worklog

Branch `s4/limma-array` from `integrate/m1m2@53006d8`; GT103 run dir `~/omic-build-logs/s4/limma-array`.

## Verified state
- Read brief, S3 review (F1-F4), S3 report sec 2-5, PACK, module code, shared limma_io.R.
- Annotation trace (`_s4/probe_annot.R`, log `~/omic-build-logs/s4/limma-array-annot.log`):
  RnAgilentDesign028282.db 3.2.3 (Bioc 3.23 BioCann, Artistic-2.0, sha256 4e9197128f43...) depends on
  org.Rn.eg.db 3.23.0 (sha256 2fb0c72f8da5..., 63 MB, not in image); AnnotationDbi 1.74.0 is in the image.
  Both installed ONLY into `~/omic-build-logs/s4/limma-array/.s4-annot-lib`.
- `_s4/probe_full_anchor.R` (log `limma-array-f1-full.log`): ALL printed values of 17.4 reproduce with the
  guide's own code (dim 44254x19, genes 201-205, dim(yfilt) 27024x19, head(yfilt), decideTests, top-20);
  engine direction_summary 756/24734/1534 and RT1-Bb 9.33 PASS. The engine-vs-guide replay compare failed
  only because feature_table.csv is printed with 10 significant digits (debug `_s4/debug_compare.R`: max rel
  diff 5e-10); compare now uses objects/fit.rds (tol 1e-10) + table at 10 digits.
- F1 smoke (`limma-array-f1-smoke.log`): everything else PASS; flag doc + golden failed (expected).
- F2/F3/F4 implemented; goldens rewritten (`limma-array-golden.log`), normal rerun `limma-array-final.log`
  SMOKE PASSED (47 PASS, NOT-RUN line for the full chain), full probe `limma-array-full2.log` FULL ANCHOR PASSED,
  module_lock regenerated + `--check` OK. Figures read. S4_FIXES.md written.

## Next step
- Done. Waiting for the coordinator to add RnAgilentDesign028282.db + org.Rn.eg.db to the acceptance layer
  (S4_FIXES Shared needs 1); then rerun the smoke test: the NOT-RUN line must turn into PASS lines.
