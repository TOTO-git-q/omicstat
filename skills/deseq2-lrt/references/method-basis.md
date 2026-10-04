# deseq2-lrt method basis

| Claim | Locked source |
|---|---|
| LRT compares nested full and reduced negative-binomial models; degrees of freedom are their model-matrix column difference | DESeq2 1.52.0 `DESeq.Rd`, `nbinomLRT.Rd`; PACK S1 P-1 |
| LRT P value tests the joint removed terms, while the displayed log2 fold change is one coefficient | DESeq2 vignette FAQ “I ran a likelihood ratio test, but results() only gives me one comparison.”; PACK S1 P-3 |
| A positive `results(lfcThreshold=)` would invoke a Wald-style threshold test; zero is required here | `results.Rd`, PACK S1 P-3 |
| fission interaction `~ strain + minute + strain:minute` vs `~ strain + minute` is the primary anchor; pasilla nested model is secondary | PACK S1 P-4; rnaseqGene “Time course experiments”, saved verbatim with its printed output in `acceptance/exemplars/deseq2-lrt/workflow_source/rnaseqGene_fission_timecourse.txt` |
| Pattern clustering is exploratory and calls `DEGreport::degPatterns` only when available | DEGreport `degPatterns.Rd`, PACK S1 P-2; 2026.10.1 adds DEGreport 1.48.0; opt-in only |

The full result table retains all tested features. `stat` is a nonnegative deviance difference and is not a directional ranking statistic. `log2fc` is the named coefficient shown by DESeq2 and is never shrunk. There is no `ranked_list` handoff in this version. The transform matrix is for displays, not another test.

## Anchors (tests/run_smoke_test.R, S4 F1)

- **A0 printed (fission, workflow settings).** The rnaseqGene workflow prints `head(resTC[order(resTC$padj),], 4)` (Bioc 3.23 build, DESeq2 1.52.0). The workflow code itself is first run in the test and must reproduce every printed cell. The engine is then run the way the workflow runs -- no pre-filter (`--min-count 0 --min-samples 1`, 7,039 rows) and `--alpha 0.1` (the `results()` default) -- and its four smallest adjusted P must be the printed genes, with baseMean, LRT statistic, P and adjusted P equal to the printed digits. The printed log2FoldChange/lfcSE belong to `strainmut.minute180` (fission's level order wt, mut); the engine orders levels by radix and displays `strainwt.minute180`, a different coefficient, so those two columns are asserted on the workflow code only (the smoke log prints both).
- **A0/A1 replay (fission).** Every row and every numeric column (baseMean, log2fc, SE, stat, P, adjusted P) of the engine's full table equals `results()` of the workflow code run in the test session, with identical NA positions and relative difference <= 1e-8 (10 significant digits in the tables). A0: workflow settings. A1: the suite's anchor settings -- pre-filter count >= 10 in >= 3 samples (the workflow has no fission pre-filter; its only one, count >= 10 in >= 4 samples, is for airway) and alpha 0.05. Both use the suite's level order.
- **A2 replay (pasilla).** The DESeq2 vignette's own pasilla code (DESeq2 extdata input, its pre-filter, `~ type + condition` from the multi-factor section, LRT form of its `simpleLRT2` chunk with `reduced = ~ type`) against the engine: all 8,148 rows, all columns, NA positions.
- **F3.** `--report-coef` changes only `log2fc`/`log2fc_se` (checked against `results(name =)` of the workflow fit); feature ids, baseMean, stat, P, adjusted P and filter reasons are byte-identical.
