# edger-qlf: independent S3 review request

S2 module `skills/edger-qlf/` 1.0.0 in `omicstat-r:2026.09.1` (edgeR 4.10.5). Reproduce with `Rscript skills/edger-qlf/tests/run_smoke_test.R` in the locked image. Outputs: `/home/<user>/omic-build-logs/build_m1/_smoke/edger-qlf-smoke/`, with logs `eq-smoke-write.log`, `eq-smoke-check.log`, `eq-lock.log` under the lane logs.

## Review focus

- Confirm S1 P-1/P-2: default `glmQLFit(legacy=FALSE, dispersion=NULL, abundance.trend=TRUE, robust=TRUE, winsor.tail.p=c(0.05,0.1))`; `estimateDisp` feeds the BCV diagnostic and only supplies the required dispersion-bearing DGEList to the explicitly selected `--legacy` branch.
- Confirm S1 P-3: default `glmQLFTest` tests zero effect, while `--treat-fc` explicitly sets the prespecified linear FC criterion for `glmTreat(null="interval")`. `--display-lfc-filter` changes only the labelled display table, never the complete results or BH FDR.
- Check all GSE60450 figure PNGs and specs, especially GEO accession labels on the top heatmap; MD uses average log2 CPM without a second log transform. BCV omits the trend line by design and says so.
- Check `--from-run` with uncorrected count handoff, batch-corrected refusal, independent replay, numerical anchor and version difference below.

## Anchors

| Anchor | Source | S2 locked-version value |
|---|---|---|
| GSE60450 source | edgeR User's Guide §4.4, gz SHA256 `906b6ec4c33e95ca0ba454a3e0d07ad74e9cb7528ee38b89a9b122f5674a5f0d` | 27,179 input, 15,969 pass `filterByExpr`; design-aware filter equals guide group filter |
| QLF B.pregnant vs B.lactate | guide printout (reproduced by the guide code in 4.10.5, S4): Down 2,607 / NotSig 10,546 / Up 2,816 | edgeR 4.10.5: Down 2,608 / NotSig 10,546 / Up 2,815; independent same-version all-gene P/FDR replay matches |
| top QLF gene | guide printout: Mrgprf (Entrez 211577), logFC -5.15, logCPM 2.74, F 473, P 7.62e-13 | Entrez 211577: logFC -5.148701616, F 473.1673102, P 7.554955726e-13 |
| `glmTreat(lfc=log2(1.2))` | guide printout (reproduced by the guide code in 4.10.5, S4): Down 1,533 / NotSig 12,573 / Up 1,863 | edgeR 4.10.5: Down 1,535 / NotSig 12,570 / Up 1,864 |

## Known limitations / 待裁决

[S4 correction, 2026-09-29: the original sentence here attributed the difference to edgeR 4.9.9 -> 4.10.5. That was wrong. In the same 4.10.5 image the guide's own code (estimateDisp before glmQLFit) reproduces the printed counts; the suite route (S1 P-1, no estimateDisp before glmQLFit) differs because glmQLFit.DGEList uses the AveLogCPM cached by estimateDisp. See skills/edger-qlf/references/method-basis.md and S4_FIXES.md F1.] The implementation follows S1 P-1 and does not alter the estimator to force the printed counts. A `ranked_list` handoff is withheld because S1 did not freeze a signed QL F statistic for downstream ranking. [S4 correction: `fit$dispersion` is a length-1 NB dispersion under the new QL method; the printed 0.013 is asserted on the guide route (0.0129556217857436).] `cpm()` was added to the calls registry from locked-container `formals()` because its Rd was absent from this module's L1 bundle. The BCV figure shows tagwise points and the common BCV line, without edgeR's trended curve. [S4: the QL dispersion and MDS figures required by PACK F are now produced; see S4_FIXES.md F2.]

## Proposed S5 entries (for the independent coordinator)

Router §1 row:

| question sounds like ... | module | entry |
|---|---|---|
| edgeR quasi-likelihood, robust QL F-test, glmQLFit, glmQLFTest, prespecified glmTreat fold-change threshold, 准似然差异表达 | `edger-qlf` | `scripts/run_edger_qlf.R` |

Proposed `module_rules_v1.json` record:

```json
{
  "module": "edger-qlf",
  "rule_id": "PUB-M-EDGERQLF-001",
  "category": "design_conditional",
  "severity": "hard_error",
  "reporting_guidelines": ["state edgeR version, robust QL fit, legacy choice, full design, contrast, TMM, filterByExpr and BH FDR", "distinguish zero-effect QLF, prespecified minimum-effect glmTreat and display-only log2FC filter"],
  "effect_table_policy": {"primary_metrics": ["log2fc", "pvalue", "padj"], "requirements": ["retain the full QL or glmTreat table", "no display filter changes significance"]},
  "artifact_aliases": {"tables/feature_table.csv": "feature_table", "results/*.json": "machine"},
  "artifact_expectations": ["volcano", "MD", "BCV", "top heatmap when at least two genes are significant", "QC rule results", "provenance", "Methods draft"],
  "required_diagnostics": ["QC rules EQ-01..EQ-11", "integer count and replicate blockers", "BCV points and common dispersion"],
  "narrative_points": ["BCV estimateDisp is display-only under the new QL fit", "glmTreat requires a prespecified linear FC"],
  "causal_language": {"forbidden": ["causal interpretation of an observational contrast"], "restricted_to": []}
}
```
