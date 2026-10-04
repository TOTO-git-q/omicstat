# deseq2-qc -- S4 fixes (1.0.1 -> 1.1.0)

Branch `s4/deseq2-qc-lrt` (from `integrate/m1m2` @fb63e52). Work list: `S3_REVIEW_astra.md` (F1 only).
GT103 run dir: `~/omic-build-logs/s4/deseq2-qc` (logs `~/omic-build-logs/s4/deseq2-qc-<tag>.log`).
Container `omicstat-r:2026.09.1` (DESeq2 1.52.0, R 4.6.1).

## F1 -- independent oracle from the vignette's own code (PACK C/F)

What changed
- `tests/run_smoke_test.R:108-211` (section "A-oracle"): the old "independent replay" (apply(var) /
  radix order / prcomp / hand-written sign normalization = a copy of `_shared` `os_pca_scores`, two
  samples only) is removed. The test now runs the DESeq2 vignette's own chunks in-session
  (`L1_bioc3.23/DESeq2/vignettes/DESeq2.Rmd` loadPasilla :421-433, reorderPasila :459, matrixInput
  :479-484, prefilter :588-592, factorlvl :611-613, deseq :675-679, rlogAndVST :1284-1288,
  sampleClust :1394-1396, figPCA2 :1431-1434) on the vignette's own input files
  (`system.file("extdata", ..., package="DESeq2")`; probe `_s4/probe_env.R` shows they are
  identical to the acceptance-layer pasilla files used by the engine fixture). No engine or
  `_shared` function is called by the oracle.
  - A2 REPLAY (primary blind = TRUE path; the only change to the vignette code is `blind=TRUE`,
    which the vignette's "Blind dispersion estimation" text prescribes for sample QA): the whole
    8,148 x 7 vst matrix; PC1 and PC2 of all 7 samples from
    `plotPCA(vsd, intgroup=c("condition","type"), returnData=TRUE)` with an explicit, logged
    whole-column sign alignment (the only transformation allowed); both percentVar values; the
    whole 7 x 7 `as.matrix(dist(t(assay(vsd))))`.
  - A1 REPLAY (supplement, the vignette chunk as written: `dds <- DESeq(dds); vsd <- vst(dds,
    blind=FALSE)`): oracle self-check against the printed `head(assay(vsd), 3)`, then the whole
    supplement matrix and the supplement's percentVar (figure spec, stored at 4 decimals).
  - Tolerance: relative 1e-8 (floor 1), i.e. the 10-significant-digit precision of the engine's
    tables; printed values at their printed decimals. The already-correct printed anchor
    (`:62-71`, three rows x 7 columns, tolerance 5e-6 against 6 printed decimals) is kept unchanged.
- Engine: `scripts/deseq2_qc_report.R:31,36-38` writes `tables/sample_distances.csv` -- the
  Euclidean distances of the primary transformed matrix (`stats::dist(t(assay), method =
  "euclidean")`, the same call the figure uses), so the engine's own distance output can be
  asserted. Listed in provenance outputs (`run_deseq2_qc.R:121`), the golden set, the `--spec`
  byte-replay check and SKILL.md "What gets produced". No estimator changed.
- Wording: `references/method-basis.md` "Anchor" section rewritten -- the old text said the
  engine "matches it exactly"; it now states what is compared, the allowed sign flip, and the
  tolerance. `references/parameters.md:47` and `deseq2_qc_core.R:4` no longer call
  `os_pca_scores` "plotPCA-equivalent"; they say it is the plotPCA computation up to a
  whole-component sign (and tie-breaking by feature id).
- Version `DQ_MODULE_VERSION` 1.0.1 -> 1.1.0 (`deseq2_qc_core.R:15`).

Evidence (`deseq2-qc-f1-golden.log`, then `deseq2-qc-f1-check.log`, both SMOKE PASSED / EXIT 0)
- A2 REPLAY full vst matrix, 57,036 values: max |diff| 5e-09.
- PC1 (sign +1) max |diff| 3.58e-09; PC2 (sign -1, logged as INFO) max |diff| 1.5e-09; 7 samples each.
- percentVar 57.305916 / 29.953913 (engine JSON) = 100 x plotPCA percentVar.
- Distance matrix 7 x 7: max |diff| 4.49e-09.
- A1 oracle self-check: vignette code reproduces all 21 printed values.
- A1 REPLAY supplement matrix, 57,036 values: max |diff| 1.37e-08 (relative <= 1e-8);
  supplement percentVar 58.3699 / 29.1834 = round(100 x percentVar, 4).
- Golden regenerated in the container (`OMICSTAT_WRITE_GOLDEN=1`, f1-golden), normal rerun
  (f1-check) `PASS: G golden baseline`. `module_lock.json` regenerated (`deseq2-qc-lock.log`,
  1.1.0, 14 files) and `--check` OK (`deseq2-qc-lockcheck.log`). check_defaults.py,
  check_flag_docs.py and lint_r.py run inside the smoke test in the container: PASS.

Figures looked at (a1 of f1-golden, PNG): `pca` (legend type + condition, axes 57.3 % / 30.0 %,
no clipping), `pca_blind_false` (58.4 % / 29.2 %, supplementary caption with blind = FALSE),
`sample_distance` (7 x 7, condition bar, colour key, labels unclipped), `size_factor` (7 points,
axes readable). Captions state n = 7, ntop = 500, blind value and use; no significance threshold
applies. Figures are unchanged by this fix apart from being regenerated.

## Known failing anchors
None.

## Owner items (unchanged, not decided here)
- P-2 sample-outlier statistic/threshold: still class C. Behaviour stays descriptive only (no
  centroid distance, flag, verdict or removal); the new distance table is descriptive too.
- Reviewer's note: the explicit `--min-samples` for complex designs is a conservative carry-over
  from deseq2-wald; PACK D-11 wording is the owner's.

## Shared needs
None required for F1. Observation for the coordinator (not a blocker): `formatC(x, digits = 10,
format = "g")` pads every element of a vector to a common width, so a 0 in a table column is
written as `"          0"` (visible on the diagonal of `tables/sample_distances.csv`). The same
pattern is in `_shared/scripts/feature_table.R::write_feature_table` and in module writers; readers
parse it correctly. A `trimws()` in the shared writer would fix it suite-wide (goldens would change).

## Notes for the final verifier
- The oracle runs `library("DESeq2")` and vignette code unqualified on purpose (guide code path).
- The only deviations from the vignette code are commented where they occur (blind = TRUE for
  the primary path; per-component sign alignment).
- `_s4/probe_env.R` is the read-only environment probe (DESeq2 extdata vs acceptance pasilla,
  plotPCA method body, results(name) handling, fission printed values); log
  `~/omic-build-logs/s4/deseq2-qc-probe-env.log`.
