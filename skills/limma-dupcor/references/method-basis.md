# Method basis

- limma 3.68.5 User's Guide §17.3 shows the Illumina donor example and prints consensus 0.134. `Rd/duplicateCorrelation.Rd` defines block and trim; PACK S1 P-1/P-2 requires explicit estimated consensus in `lmFit` and a described, estimable correlated unit.
- User's Guide §18.1 shows two voom/duplicateCorrelation rounds in RNA-seq and prints 0.446 after both. The guide is a static PDF last re-run around limma 3.42; limma NEWS 3.66.0 changed `voom(adaptive.span)` to TRUE. With `adaptive.span = FALSE` (span 0.5) the guide code reproduces every printed §18.1.9 value in the locked container (smoke test, printed anchor); the suite route (`adaptive.span = TRUE`, S1) gives 0.4449716 / 0.4454514 and is asserted by locked replay against the guide code run with that setting (docs/build/S4_ANCHOR_TRACE.md).
- PACK S1 P-3 and limma-array P-1 govern platform-specific array moderation; RNA voom uses the locked plain eBayes options.
