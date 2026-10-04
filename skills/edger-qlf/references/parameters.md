# edger-qlf parameters

Locked image: edgeR 4.10.5 (`omicstat-r:2026.09.1`). Frozen decisions: PACK S1 appendix P-1 to P-3. Defaults in the registry come from container `formals()` including S3 DGEList methods.

| Flag | Default | Allowed | Why |
|---|---|---|---|
| `--counts` | none | raw count file | direct input |
| `--samples` | none | sample table | required with counts |
| `--from-run` | none | upstream run | deseq2-qc handoff |
| `--outdir` | (required) | directory | run output |
| `--spec` | none | resolved spec | deterministic replay |
| `--sample-col` | sample | column | sample ID |
| `--condition` | condition | column | factor for the contrast |
| `--reference` | (required) | condition level | contrast denominator |
| `--target` | (required) | condition level | contrast numerator |
| `--covariates` | none | comma-separated columns | adjustment factors |
| `--min-count` | 10 | integer >=0 | filterByExpr min.count |
| `--min-total-count` | 15 | integer >=0 | filterByExpr min.total.count |
| `--large-n` | 10 | integer >=1 | filterByExpr large.n |
| `--min-prop` | 0.7 | 0 to 1 | filterByExpr min.prop |
| `--alpha` | 0.05 | 1e-6 to 0.5 | BH significance and display |
| `--treat-fc` | 0 | 0 or linear FC >1 | 0: QLF zero-effect test; >1: prespecified glmTreat minimum-effect test, P-3 |
| `--display-lfc-filter` | 0 | log2FC >=0 | separate display-only significant subset; P values unchanged |
| `--legacy` | off | switch | old QL method only on explicit request, P-1 |
| `--gene-annotation` | none | feature_id,symbol table | display labels |
| `--top-n` | 50 | 2 to 500 | top-gene heatmap |
| `--label-n` | 10 | 0 to 50 | volcano/MD labels |
| `--seed` | 20260925 | integer | provenance seed |
| `--journal` | nature | nature, cell, science, generic | figure preset |

The filter passes the full `~0 + group + covariates` design to `filterByExpr`, which computes minimum sample size by inverse leverage. This is the edgeR alternative to DESeq2's explicit smallest-group pre-filter rule. All condition levels stay in the fit; only the target minus reference numeric contrast selects a comparison. Factor labels may contain dots or other characters because the contrast is built by exact column matching, without parsing a coefficient name. `estimateDisp` supplies the BCV figure and, only when `--legacy` is selected, the dispersion-bearing DGEList required by the old QL fit. It does not supply dispersion to the default new QL fit. All result-affecting edgeR arguments are in `scripts/calls_registry.json`.

Figures (S4, PACK F): the QL dispersion display reads `AveLogCPM`, the adjusted deviance/df (legacy: deviance/zero-corrected df), `s2.post` and `s2.prior` from the fit exactly as edgeR `plotQLDisp` does (table `tables/ql_dispersion.csv`). The sample MDS calls `limma::plotMDS(top = 500, gene.selection = "pairwise", dim.plot = c(1, 2), plot = FALSE)` on `cpm(y, log = TRUE, prior.count = 2)` of the filtered TMM DGEList, which is what edgeR `plotMDS(y)` in User's Guide 4.4.5 computes (table `tables/mds_coordinates.csv`); limma 3.68.5 is registered in `calls_registry.json`. Both are displays only.
