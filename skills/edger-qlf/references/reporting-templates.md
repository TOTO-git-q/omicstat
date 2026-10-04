# edger-qlf reporting templates

These fenced blocks are filled by `edger_qlf_draft()`; report thresholds as different concepts.

```template methods
edgeR (v{edger_version}) in R (v{r_version}) tested the contrast {target} versus {reference} within {condition} ({n_target} and {n_reference} biological replicates). Of {n_input} input genes, {n_tested} passed filterByExpr(design = `{design}`, min.count = {min_count}, min.total.count = {min_total_count}, large.n = {large_n}, min.prop = {min_prop}). Library normalization used TMM. A robust quasi-likelihood prior was estimated with glmQLFit(robust = TRUE, winsor.tail.p = c(0.05, 0.1), legacy = {legacy}, dispersion = NULL, abundance.trend = TRUE); {dispersion_note} The confirmatory test was {test_detail}, followed by BH adjustment. The significance threshold was FDR <= {alpha}.
```

```template results
Of {n_tested} filtered genes, {n_sig} met BH FDR <= {alpha}: {n_down} lower in {target}, {n_up} higher, and {n_notsig} not significant. The complete feature table retains every filtered gene. The BCV, QL dispersion, sample MDS, MD, volcano and top-gene heatmap are descriptive displays of the fitted data and contrast.
```

Slots are filled from the resolved flags, package version, edgeR fit and canonical feature table in `edger_qlf_draft()`.
