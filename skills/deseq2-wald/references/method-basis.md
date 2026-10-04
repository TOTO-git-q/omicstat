# method-basis -- deseq2-wald

Format: claim -> source. "Vignette" = the DESeq2 vignette shipped with the installed package
(`system.file("doc", "DESeq2.html", package = "DESeq2")`), exported with its sha256 to
`acceptance/exemplars/deseq2-wald/L1/`. Literature citations are the ones the packages
themselves declare (`citation()`), copied from `L1/<pkg>/CITATION.txt`; no reference here is
written from memory.

Versions at S0: DESeq2 1.50.2, apeglm 1.32.0, ashr 2.2-63 (dev tier, Bioconductor 3.22). The
locked container (Bioconductor 3.23) re-checks every function default in `calls_registry.json`
(`check_default_drift`); a difference fails the smoke test until PACK section D is updated.

## Method

| Claim | Source |
|---|---|
| Negative binomial GLM with median-of-ratios size factors, shrunken dispersion estimates and Wald tests | Love MI, Huber W, Anders S (2014). Genome Biology 15:550. doi:10.1186/s13059-014-0550-8 (DESeq2 `citation()`); vignette "Differential expression analysis"; `?DESeq` |
| DESeq2 needs un-normalized integer counts | vignette "Why un-normalized counts?" |
| Pre-filter: count >= 10 in at least the smallest group size | vignette "Pre-filtering" |
| Reference level via `relevel`; the coefficient reads `condition_<target>_vs_<reference>` | vignette "Note on factor levels"; "Log fold change shrinkage for visualization and ranking" (`resultsNames(dds)`) |
| `alpha` in `results()` should equal the adjusted-P cutoff that will be reported | vignette "p-values and adjusted p-values" ("If the adjusted p value cutoff will be a value other than 0.1, alpha should be set to that value") |
| Independent filtering on the mean of normalized counts; padj = NA for filtered rows | vignette "Independent filtering of results"; FAQ "Why are some p values set to NA?" |
| Cook's distance outliers get pvalue = padj = NA; replacement only with >= 7 replicates | vignette "Approach to count outliers"; `?results` (`cooksCutoff`); `?DESeq` (`minReplicatesForReplace`) |
| Testing against a fold-change threshold (`lfcThreshold`, `altHypothesis = "greaterAbs"`) instead of filtering on fold change after the test | vignette "Tests of log2 fold change above or below a threshold" (threshold-based Wald tests); `?results` (`lfcThreshold`, `altHypothesis`) |
| apeglm shrinkage for ranking and visualization; `lfcShrink` with `res` keeps the Wald P values | Zhu A, Ibrahim JG, Love MI (2018). Bioinformatics. doi:10.1093/bioinformatics/bty895 (apeglm `citation()`); vignette "Log fold change shrinkage for visualization and ranking"; `?lfcShrink` |
| ashr as an alternative shrinkage estimator | Stephens M et al. ashr (R package). doi:10.32614/CRAN.package.ashr (ashr `citation()`); vignette "Alternative shrinkage estimators" |
| `vst(blind = FALSE)` for visualization when the design is known | vignette "Blind dispersion estimation" |

## Open-source implementations consulted (design, not evidence)

| What | Where | Used for |
|---|---|---|
| nf-core `deseq2/differential` module template (`templates/deseq2_differential.R`) | github.com/nf-core/modules | parameter surface (test, fitType, sfType, minReplicatesForReplace, useT, lfcThreshold, altHypothesis, independentFiltering, pAdjustMethod, alpha, minmu, vst nsub) cross-checked against our flags; our defaults follow the vignette where they differ (nf-core shrinks with `ashr`, alpha 0.1) |
| Bioconductor workflow rnaseqGene (source) | github.com/mikelove/rnaseqGene | pre-filter and `vst(blind = FALSE)` usage in a full workflow |

## Anchor (PACK section C)

The pasilla example of the vignette, rebuilt by `tests/fixtures/make_pasilla.R` exactly as the
vignette does, reproduces the vignette's printed values (see `tests/run_smoke_test.R`, A1-A4):
8,148 features after pre-filtering; 1,069 with padj < 0.1 (533 up, 536 down); 416 up / 437 down
at alpha = 0.05; FBgn0000017 log2FC (MLE) -0.23842494, padj 0.289604, apeglm -0.18810628.
