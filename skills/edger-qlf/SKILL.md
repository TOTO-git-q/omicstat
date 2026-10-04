---
name: edger-qlf
description: >
  Run edgeR's robust quasi-likelihood F-test for a bulk RNA-seq group contrast and produce a complete gene table, figures and filled Methods draft. Triggers: edgeR, glmQLFit, glmQLFTest, glmTreat, quasi-likelihood, RNA-seq differential expression, 准似然, 差异表达. Use when raw counts and a group contrast are available. NOT for a DESeq2 Wald analysis (use deseq2-wald); NOT for a joint time-course LRT (use deseq2-lrt); NOT for sample QC (use deseq2-qc).
---
# edger-qlf

## When to use / when not
Use for a prespecified target-versus-reference RNA-seq comparison with edgeR's robust QL fit. All condition levels remain in the design; the contrast selects two. Use deseq2-lrt for a joint interaction/time-course test and deseq2-qc for sample diagnostics.

## Input requirements
Raw nonnegative integer genes-by-samples counts, one sample table row per column, condition levels containing both `--reference` and `--target`. At least two biological replicates in each compared group. `--from-run` accepts deseq2-qc handoff; batch-corrected display matrices are refused.

## Run
`Rscript scripts/run_edger_qlf.R --counts counts.tsv --samples samples.csv --reference B.lactate --target B.pregnant --outdir run`

The default is `glmQLFTest` against zero effect. `--treat-fc 1.2` explicitly requests `glmTreat` against a linear 1.2-fold minimum effect. `--display-lfc-filter 1` writes a separate display subset and leaves all P values unchanged. `--legacy` reproduces the older QL fit. Flag defaults and sources: references/parameters.md.

### Via MCP
Use `omicstat_run` with `module="edger-qlf"` and these flags, then `omicstat_read`. `--help` is the typed flag list.

## What gets produced
Complete canonical `tables/feature_table.csv`, edgeR full results, logCPM expression matrix, BCV diagnostic table, QL dispersion table, sample MDS coordinates, results JSON, QC, provenance and a Methods/Results draft. Figures: volcano, MD (average log2 CPM on x), BCV points plus common-BCV line, QL dispersion (raw, squeezed and trended quarter-root QL dispersion against average log2 CPM, as edgeR plotQLDisp), sample MDS (limma plotMDS on log2 CPM, top 500 genes, leading log2 fold change), and top-gene heatmap when at least two genes pass FDR. The handoff includes original counts, DGEList, feature table and logCPM matrix.

## Reading the results
`padj` is BH FDR for the selected QLF or minimum-effect test. `log2fc` is target versus reference; `base_mean` holds edgeR average log2 CPM. Results JSON separates `null_test`, `min_effect_lfc_threshold` (log2 units), `treat_fc_linear`, and `display_lfc_filter`. The display filter has no new FDR guarantee. Read references/reporting-templates.md before writing up.

## When a QC rule fires
Read `qc/qc_results.csv`. EQ-01..03 block fitting and withhold the draft; EQ-09 always records robust QL prior estimation. EQ-10/11 mark the legacy and minimum-effect options. Criteria and sources: references/qc-rules.md.

## Known limitations
The BCV diagnostic omits the trended curve from edgeR's `plotBCV`; it shows tagwise points and the common BCV line. No ranked-list handoff is produced because a signed square root of the QL F statistic is not frozen by the S1 appendix. `cpm()` is a direct locked-container formals addition to the call registry because its Rd was absent from this exemplar's L1 collection. The frozen fit (no `estimateDisp` before `glmQLFit`, S1 P-1) differs slightly from the User's Guide 4.4 printout (QLF 2608/10546/2815 versus 2607/10546/2816) because `estimateDisp` caches a different AveLogCPM that the guide's `glmQLFit` then uses; it is not an edgeR version difference. The guide's own code reproduces the printout in the locked image. See references/method-basis.md.

## Reference files
- references/parameters.md: flags and locked calls
- references/method-basis.md: L1 and anchor evidence
- references/qc-rules.md: EQ-01..EQ-11
- references/reporting-templates.md: filled draft wording
- references/troubleshooting.md: typed-error remedies
