# Method basis

- GSVA 2.6.6 `gsvaParam.Rd` and `gsva.Rd` (L1_bioc3.23): parameter-object API, auto kernel threshold, Poisson for integer counts, `filterRows` (constant rows removed before mapping gene sets), score return type with the `geneSets` attribute; NEWS 2.x `geneSets()` / `geneSetSizes()` getters.
- `GSVA.Rmd`, sections `Overview of the GSVA functionality`, `Quantification of pathway activity in bulk microarray and RNA-seq data`, `Molecular signature identification` (GBM example, `maxDiff=FALSE`) and `Differential expression at pathway level`: distinct 5–500/5–300 examples; the pathway-level limma example is documented but not run here (S1 P-3 owner-pending).
- PACK S1 appendix P-1–P-3 and SUITE cross-module rules 6–8: input scale, size bounds, batch and score inference contract; S4 contracts b (limma hand-off: EList E, weights not used) and c (batch-corrected lineage).
- GSVAdata 1.48.1, sha256-locked acceptance layer: gbm_VerhaakEtAl ExpressionSet and brainTxDbSets demonstration fixture.

## Anchors (tests/run_smoke_test.R)
- A-vig (printed + replay): the vignette's own GBM code (`GSVA.rendered.txt:683-725`, `gsvaParam(gbm_eset, brainTxDbSets, maxDiff=FALSE)`) run in the test session; printed dimensions 11861 x 173, the first six feature names, subtype counts 38/56/26/53 and set lengths 85/88/98/70 (with the printed first members) are asserted; the full 4 x 173 vignette score matrix is compared with the same vignette call on the engine's CSV fixture. There are no printed score values for this example.
- A-suite (replay): the frozen suite preset (`maxDiff=TRUE`, 5-500, auto kernel -> Gaussian) run directly with GSVA in the session on the ExpressionSet equals the engine's complete score table; GSVA's own `geneSetSizes()` equals the engine's per-set table.
- No inference anchor: the vignette's FIR/SV/robust example is not a module route while S1 P-3 is pending.
