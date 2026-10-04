# Method basis

- Reference annotation and marker selection -> SingleR@2.14.2, `L1_bioc3.23/SingleR/Rd/SingleR.Rd`, PACK D-SR1..D-SR20.
- Per-cell reference recipe and Wilcoxon marker recommendation -> SingleR vignette `Using single-cell references`, `L1_bioc3.23/SingleR/vignettes/SingleR.Rmd` (exact heading verified locally).
- Relative score diagnostics and pruning -> same vignette `Annotation diagnostics`, pruneScores.Rd, PACK C/D-SR7/8/21/22.
- Reference data identity differs from package version -> celldex@1.22.0 fetchReference.Rd, PACK D-SR25. User supplies reference; no network fetch.
- Current locked container lacks scrapper, so the printed pancreas anchor and cluster-unit path cannot execute. Build remains incomplete; see build_worklog.md and lane report.
