# deseq2-qc: independent S3 review request (S2 follow-up 1.0.1)

Locked image: `omicstat-r:2026.09.1`. Reproduce with
`Rscript skills/deseq2-qc/tests/run_smoke_test.R`. Logs and output:
`/home/<user>/omic-build-logs/build_m1/dq-check.log`, `dq-golden.log`, and
`_smoke/deseq2-qc-smoke/` (a1 is the supplement; a2 is the golden default run).
This request updates the paused `S3_REVIEW.md`; it does not claim an S3 verdict.

## Review focus

- F2: `dist_to_group_centroid` was removed from the table, draft, SKILL and rule text.
  P-2 remains under 待裁决: no outlier call, flag or removal. Verify the actual a2 output.
- F3: inspect a1 and F5 Methods. They state nsub, fitType, `estimateSizeFactors` type,
  the `blind = FALSE` supplement and, for F5, the direct VST fallback.
- F4: registry points to `estimateSizeFactors.DESeqDataSet`; `type` and `locfunc`
  defaults pass `check_default_drift`. The method has missing-argument defaults for
  geoMeans/controlGenes/normMatrix; explicitly passing NULL changed the estimator and was
  reverted. Please check this exception to the explicit-argument rule.
- F5: new F5 synthetic run keeps at least 1,000 rows but fewer than 1,000 eligible rows
  with normalized mean > 5. The fallback and DQ-05 must fire; check the draft.
- F1 replay anchor is left to the independent reviewer as the lane task directs.
- Inspect all four a1 PNGs, their specs, and any output contract concerns before S3 verdict.

## Anchors and sources

| Anchor | Source and type | S2 result |
|---|---|---|
| A1 pasilla, `blind=FALSE` | printed `head(assay(vsd), 3)` in `L1_bioc3.23/DESeq2/vignettes/DESeq2.rendered.txt`, around lines 925-936 | 8,148 of 14,599 rows; three printed gene rows match to tolerance 5e-6 |
| A2 pasilla, `blind=TRUE` | replay, PACK C and DESeq2 vignette construction | PC1/PC2 for treated1 and untreated4 match test-session recomputation; independent reviewer to assess anchor strength (F1) |
| D2 handoff | deseq2-wald `--from-run` | nonempty feature table; tampered handoff refused |
| F5 fallback | synthetic regression for DESeq2 `vst()` eligible-row condition | DQ-05 and direct VST fallback triggered |

## Known limitations / 待裁决

- P-2: no numeric per-sample outlier statistic, threshold, or calibrated centroid distance is
  frozen. The table is descriptive; a person reviews the PCA and distance figure.
- The A2 replay anchor question remains for the independent reviewer (F1).

## Proposed S5 entries (for the independent coordinator)

Router §1 row:

| question sounds like ... | module | entry |
|---|---|---|
| does the RNA-seq count data look OK before testing it? sample PCA, sample clustering, batch/outlier check before deseq2-wald/deseq2-lrt, 样本质控, 样本PCA, 样本聚类 | `deseq2-qc` | `scripts/run_deseq2_qc.R` |

Proposed `module_rules_v1.json` record:

```json
{
  "module": "deseq2-qc",
  "rule_id": "PUB-M-DESEQ2QC-001",
  "category": "design_conditional",
  "severity": "warning",
  "reporting_guidelines": ["state the primary transform and blind value, size-factor type, fitType and any fallback or supplement", "describe the PCA and sample-distance display without an outlier verdict"],
  "effect_table_policy": {"primary_metrics": [], "allow_no_effect_table": true, "requirements": ["sample QA supplies no differential-expression effect table"]},
  "artifact_aliases": {"tables/sample_qc_descriptive.csv": "descriptive_samples", "results/*.json": "machine"},
  "artifact_expectations": ["sample PCA", "sample-distance heatmap", "size-factor diagnostic", "QC rule results", "provenance", "Methods draft"],
  "required_diagnostics": ["QC rules DQ-01..DQ-07", "prefilter sample count", "transform fallback status"],
  "narrative_points": ["never call a sample an outlier or removed automatically", "the primary blind=TRUE matrix is for sample QA"],
  "causal_language": {"forbidden": ["a differential-expression claim from QA scores"], "restricted_to": []}
}
```
