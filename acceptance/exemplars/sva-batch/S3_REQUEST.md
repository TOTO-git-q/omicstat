# sva-batch: independent S3 review request

S2 build: `skills/sva-batch/` version 1.0.0. Locked image: `omicstat-r:2026.09.1`.
Reproduce with `Rscript skills/sva-batch/tests/run_smoke_test.R` in that image. The latest
container outputs and logs are under `/home/<user>/omic-build-logs/build_m1/_smoke/sva-batch-smoke/`
and `/home/<user>/omic-build-logs/build_m1/`. Goldens are from A5; lock is
`skills/sva-batch/module_lock.json`.

## Check closely

- The legends use the supplied `batch` and study-variable column names, and the title/caption
  state the correction method and display-only status. Inspect A1, A5, and F0 PNGs and specs.
- P-1 handoff: corrected matrices have type `batch_corrected_matrix`; deseq2-wald refuses them
  with `OS_BATCH_CORRECTED_INPUT`. Original counts and batch/SV design are the DE route.
- P-2: protected study design, full confounding refusal, partial confounding warning.
- P-3: `num.sv` seed and method, explicit result-affecting arguments in the registry.
- Confirm no inference is drawn from corrected scores, and no S5 router/rules installation occurred.

## Anchors and sources

| Anchor | Type and source | S2 result |
|---|---|---|
| A1 ComBat, bladderbatch | replay of protected-design call, PACK C / sva vignette ComBat section | corrected matrix equals direct call |
| A2 sva, bladderbatch | replay of `num.sv(method="be", B=20, seed=20260925)` | 9 SVs |
| A3 sva, bladderbatch | printed value, sva vignette SV estimation section | `num.sv(method="leek")` = 2 |
| A4 svaseq, zebrafishRNASeq | printed value, sva vignette sequencing section | 1 SV |
| A5 ComBat_seq, vignette simulation | replay of direct call and printed console messages | corrected integer matrix byte-identical |

## Known limitations / 待裁决

- Continuous study variable with ComBat_seq is refused as `OS_UNSUPPORTED_DESIGN` until its
  placement in `group`/`covar_mod` is decided.
- The sva/svaseq display matrix uses `removeBatchEffect(batch=NULL, covariates=SVs, design=mod)`;
  review this interpretation of the P-3 cross-reference.
- ComBat's base-graphics prior-density diagnostic is deferred under the suite figure contract.

## Proposed S5 entries (for the independent coordinator)

Router §1 row:

| question sounds like ... | module | entry |
|---|---|---|
| batch effect, ComBat, ComBat-seq, sva, svaseq, surrogate variable, 批次效应, 批次校正 | `sva-batch` | `scripts/run_sva_batch.R` |

Proposed `module_rules_v1.json` record:

```json
{
  "module": "sva-batch",
  "rule_id": "PUB-M-SVABATCH-001",
  "category": "design_conditional",
  "severity": "hard_error",
  "reporting_guidelines": ["name the batch/SV method, protected study design, and display-only status of corrected matrices"],
  "effect_table_policy": {"primary_metrics": [], "allow_no_effect_table": true, "requirements": ["batch correction is descriptive and supplies no differential-expression effect table"]},
  "artifact_aliases": {"tables/corrected_matrix.csv": "display_only_matrix", "results/*.json": "machine"},
  "artifact_expectations": ["before/after PCA", "batch report", "QC rule results", "provenance", "methods draft"],
  "required_diagnostics": ["QC rules SB-01..SB-08", "batch/study-variable confounding status", "number of surrogate variables where applicable"],
  "narrative_points": ["never use a corrected matrix as standard DE input", "put known batch or SVs into the DE model with uncorrected data"],
  "causal_language": {"forbidden": ["a differential-expression claim from corrected scores"], "restricted_to": []}
}
```
