# limma-dupcor S4 fixes (S3_REVIEW_astra F1-F3)

Branch `s4/limma-voom-dupcor` (from `integrate/m1m2` @53006d8, merged again at 6c22204). Module 1.0.0 -> **1.1.0**
(`scripts/limma_dupcor_core.R:5`). All R ran in `omicstat-r:2026.09.1` (limma 3.68.5, edgeR 4.10.5) on GT103, run dir
`~/omic-build-logs/s4/limma-dupcor/`, logs `~/omic-build-logs/s4/limma-dupcor-<tag>.log`.

- Goldens written: `limma-dupcor-golden.log` (`OMICSTAT_WRITE_GOLDEN=1`, SMOKE PASSED).
- Final normal run on the merged tree (shared `limma_io` `res[["expr"]]` fix included): `limma-dupcor-d1.log`
  SMOKE PASSED, EXIT 0, `PASS: container golden`, no FAIL/SKIP lines.
- Lock: `limma-dupcor-lock.log` (1.1.0, 14 files, tier container); `limma-dupcor-lockcheck.log` `OK (14 files)`.
- check_defaults.py (26/26), check_flag_docs.py, lint_r.py, calls registry C1-C3 and default drift: PASS inside the smoke.

History: a first helper made the F1-F3 edits and was cut off by a rate limit; the edits were saved unverified in WIP
c34d593. The module tree of c34d593 is byte-identical (md5) to the tree that ran `limma-dupcor-final.log`; everything
was re-run on the merged tree here and the smoke test was tightened (Illumina guide-code anchor, locked round-1 value).

## F1 - Yoruba printed anchor and RNA engine anchor (fixed)

Root cause of 0.4455 vs printed 0.446 (docs/build/S4_ANCHOR_TRACE.md, coordinator probe): the User's Guide is a static
PDF last re-run around limma 3.42; limma 3.66.0 made `voom(adaptive.span = TRUE)` the default. With the guide's own code
and the guide-era span written out (`adaptive.span = FALSE`, span 0.5) every printed sec 18.1.9 value is reproduced.

What changed
- `tests/fixtures/guide_yoruba.R` (new; same file in limma-voom): the guide's own sec 18.1 code on the sha-locked
  `acceptance/data/limma_Yoruba.RData` - Targets from the printed table (guide:6854-6944), concentration as factor
  (:6963), filter A > 50 and annotation present (:7204-7208), TMM (:7213), `model.matrix(~ gender + concentration)`
  (:7395), voom / duplicateCorrelation twice (:7398-7408), `lmFit(block, correlation)` + `eBayes` (:7415-7416),
  `decideTests` (:7417), `topTable(coef = "genderMale", p = 0.05)` (:7422). Only the voom span setting is written out
  (argument `adaptive.span`). Printed values parsed from the guide text.
- `tests/fixtures/replay_yoruba.R` removed (it only checked finiteness); the "ANCHOR GAP ... SMOKE PASSED" pattern is gone.
- `tests/run_smoke_test.R:90-160` (Yoruba block), anchor kinds stated in the header (lines 2-12).
- Illumina (row 7) tightened in the same spirit: `run_smoke_test.R:51-59` now asserts the printed 0.134 with the guide's
  own code (`ct <- factor(targets$CellType); design <- model.matrix(~0+ct); duplicateCorrelation(y, design,
  block = targets$Donor)`, guide:6521-6525, printed value parsed from guide:6526) and the engine array route as a replay
  of that code (locked 0.1344848639). Previously only the engine value was compared with 0.134.

Anchors and their kind (`limma-dupcor-d1.log`)
| kind | what | asserted |
|---|---|---|
| PRINTED (guide code) | sec 17.3: 24691 x 12 after the detection filter (guide:6500); consensus 0.1344848639 prints 0.134 (guide:6526) | PASS |
| REPLAY (engine array route) | engine consensus == guide code (1e-9), locked 0.1344848639; MDS coordinates == `plotMDS(y)` (guide:6502) | PASS |
| PRINTED (guide code, `adaptive.span = FALSE`) | sec 18.1: 16918 x 86 (guide:7210); consensus 0.4455442 / 0.4459984 print 0.446 / 0.446 (guide:7402, :7410); `summary(decideTests(fit))` all 4 coefficients (guide:7418-7421); all 49 printed topTable rows, IDs, symbols, logFC, AveExpr, t, P, adj.P, B at printed precision (guide:7423-7473) | PASS |
| REPLAY (engine RNA route, suite `adaptive.span = TRUE`) | the guide-filtered 16918 x 86 counts into the engine (`--mode rna --block cellline --covariates concentration`, `--min-count 0` so filterByExpr keeps every gene; engine design `~ concentration + gender` spans the guide's): both consensus rounds == guide code with `adaptive.span = TRUE` (1e-9) and locked 0.4449716 / 0.4454514 (5e-8); logFC/AveExpr/t/P/BH/B for all 16918 genes; direction summary 27/16869/22 (also equals the printed genderMale row); hand-off EList E and weights == round-2 voom (guide:7406); voom trend points; MDS coordinates | PASS |

The printed guide-path anchor and the engine route are separate checks; the log line
`NOTE: guide code with the locked default adaptive.span = TRUE gives consensus 0.4449716 / 0.4454514 (prints 0.445)`
states the version difference; it is not a gap that the test passes over (both paths are asserted).

## F2 - Methods from the actual run (fixed)

- `scripts/limma_dupcor_core.R:137-190` `ld_template_values()` + `references/reporting-templates.md`: new slots
  `edger_sentence`, `data_kind`, `input_sentence`, `chain_sentence`, `block_sentence`, `moderation_sentence`,
  `consensus_value`, `n_blocks`.
  - RNA: edgeR version; filterByExpr arguments and the thresholds applied (CPM cutoff = min.count / median library size,
    minimum sample size from the design leverage, total count) and genes kept; TMM settings and factor range; both
    voom -> duplicateCorrelation rounds (round 1 without block, its span and consensus; round 2 with block and the
    round-1 correlation, its span and the re-estimated consensus used in `lmFit`); `adaptive.span = TRUE`.
  - Both modes: block meaning / column / role (+ rationale), number of units and their sizes, trim = 0.15,
    `lmFit(block, correlation = <value>)`; eBayes or treat with trend/robust and their source (RNA-seq preset,
    registered Agilent preset or explicit user setting), proportion, stdev.coef.lim, estimated prior df / variance;
    treat fc, lfc = log2(fc) and the interval null. Array: the user-supplied matrix and platform, no edgeR claim.
  - Results: consensus and unit count. Results JSON `details` carry filter, TMM factors, both spans, both correlations,
    trim, trend/robust, moderation, prior.
- Assertions: `run_smoke_test.R:61-67` (array Methods), `:143-154` (RNA Methods on the Yoruba run: every number checked
  against the guide-code replay), `:176` (treat fc / lfc).

## F3 - sample MDS and voom diagnostic (fixed)

- `scripts/limma_dupcor_core.R:100-104`: `limma::plotMDS(x, top = 500, gene.selection = "pairwise", plot = FALSE)` with
  x = `edgeR::cpm(dge, log = TRUE, prior.count = 2)` (RNA; RNAseq123 Rmd:280) or the supplied matrix (array; guide:6502).
  The shared writer draws `figures/mds.*` + `tables/mds_coordinates.csv`; donors are shapes when there are few blocks.
- `:55-59`: the round-2 voom call has `save.plot = TRUE` (display only; registered): `figures/voom_trend.*` +
  `tables/voom_trend_points.csv` in RNA mode (none in array mode, asserted).
- Captions state n samples / features, top 500, input scale, span; asserted at `run_smoke_test.R:72-73, :155-158`.
- Figures looked at (PNG copies from `_smoke/limma-dupcor-smoke`):
  - a0/mds: 12 arrays, 4 cell types coloured, 3 donors shaped, % variance on axes; two ML points nearly overlap (true
    coordinates). a0/volcano: 3348 down / 3792 up in legend, BH line, 10 probe labels readable. a0/md: coloured by BH,
    zero line. a0/sa_diagnostic: 24691 probes, axes labelled (shared plot draws no trend line; unchanged).
  - yoruba/voom_trend: 16918 points, lowess line, span in caption. yoruba/mds: 86 samples coloured by gender, no shapes
    (74 blocks). yoruba/volcano: 27 down / 22 up = printed genderMale row; labels are Entrez IDs (no annotation input).
    yoruba/md: fine.
  - rna0 (synthetic behaviour fixture): mds with 4 donor shapes, voom_trend (500 genes), volcano 0/40, md fine.
    rnatreat: volcano 0/2 under treat fc 1.5, md fine.
  - Nothing clipped, legends present where the plot has groups.

## Known failing anchors

None.

## Owner items

- **adaptive.span (new)**: acknowledge that the sec 18.1 printed anchors are asserted with the guide-era voom span
  (`adaptive.span = FALSE`, limma NEWS 3.66.0) while the frozen suite route keeps `adaptive.span = TRUE`
  (0.4454514, prints 0.445). Whether the suite should switch is not decided here.
- Non-Agilent array presets (limma-array P-1 / dupcor P-3): unchanged; non-Agilent arrays still require explicit
  `--trend/--robust` (typed refusal asserted).
- Illumina sec 17.3.7 (outside PACK C row 7, which registers only the consensus): the probe
  `_s4/probe_illumina_guide.R` (log `_s4/probe_illumina_guide.log`) shows the guide code reproduces the printed
  `decideTests(fit2, method = "global")` table exactly and the printed `topTable(fit2, coef = 1)` except row 9
  (ILMN_1777199) P value 4.236877e-11 vs printed 4.23e-11. Not asserted because it is not a registered anchor; if
  the owner extends row 7 to the DE output, that P value would be a known failing printed value (static-PDF era).

## Shared needs (not edited here)

1. `skills/_shared/scripts/limma_io.R` `os_limma_direction_summary()`: the `lfc` column is always 0; for treat runs it
   should carry the treat lfc (the counts follow the treat P values correctly).
2. `os_limma_sa()` draws points only; a plotSA-style trend line (the eBayes prior trend when trend = TRUE) would make
   the diagnostic readable. Cosmetic, not an F item.
(The `res$expr` partial-match hazard reported by the first helper is fixed on integrate/m1m2 fa9227c; the core still
sets `expr` explicitly.)

## Notes for the final verifier

- Yoruba guide code runs three times in the smoke (FALSE, TRUE and the engine), about 1.5 min; whole smoke about 4 min.
- The engine design is `~ concentration + gender` (covariates first) while the guide uses `~ gender + concentration`;
  same column space, so the genderMale coefficient, correlations and weights are identical (asserted).
- `--min-count 0` in the Yoruba engine run only makes filterByExpr a no-op so the guide's own filter (A > 50 and
  annotation) defines the gene set; the Methods text then honestly reports "at least 0 counts per million".
