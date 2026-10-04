# gsva-score — independent S3 request

## Review scope

Run `skills/gsva-score/tests/run_smoke_test.R` and `tools/make_module_lock.R gsva-score --check` in the locked image with the read-only `.omicstat-acceptance` layer mounted. Review the `gsvaParam` object API and every explicit argument, `auto`/Poisson/none kernel reporting, input scale checks, 5–500 default and 5–300 configurable option, offline collection hash, no silent KEGG use, score matrix, sample-aligned design, provisional limma inference, corrected-input refusal, figure, QC, handoff and deterministic golden. S3 review is independent; S2 has not accepted itself.

## Anchor and outputs

- Source: GSVAdata 1.48.1 `gbm_VerhaakEtAl` expression and `brainTxDbSets`, from the sha256-locked acceptance layer (PACK C main bulk-data replacement under SUITE M2-3). Generated expression CSV SHA-256 `93027d9f196fb704fb8e7c146ec382bf2bf27a2f0f5deb51c8a2e9162ec3f19c`; sample table `fade8abcb255460b9f45f2552aaad1b03432b11a23c277ee9793b0de251ab8d0`; collection canonical hash `5d7e7ddf228e7f4ef3aad178e904e8ca99218d339af9e5624c28588609bc124c`.
- **Replay anchors**, not printed vignette values: 11,861 features, 173 samples, four sets scored at 5–500; `kcdf="auto"` chose Gaussian. Provisional Proneural reference n=53 versus Classical target n=38: all four score rows have BH adjusted P < 0.05; `oligodendrocytic_up` logFC = -0.522609890627989. Independent parameter-object GSVA and limma calls in the smoke reproduce one score and one adjusted P. The golden checks full score, limma, design, result JSON, PNG and figure spec bytewise in the same signature.
- Last S2 smoke: `/home/<user>/omic-build-logs/build_m2b/gsva_final_smoke.log` (27 PASS, 0 FAIL, SMOKE PASSED); anchor output: `/home/<user>/omic-build-logs/build_m2b/gsva-score-smoke/a1/`. Golden and `module_lock --check` pass in the locked container. Every distinct PNG was visually checked; informational FIG-03 grayscale proximity appears for the shared group palette, without a lint blocker.

## Owner items and limitations

- PACK P-3 leaves the receiving limma module and `eBayes` trend/robust settings unresolved. S2 uses direct continuous `lmFit(scores, design)` and `eBayes(trend=FALSE, robust=FALSE)`, writes the design matrix, and marks this provisional. No voom, probe filtering, or count model is used. Please review the setting before S5.
- Repeated subjects need limma-dupcor and are refused for inference here. Survival inference is outside scope. A batch-corrected upstream matrix may be scored descriptively; group inference on those scores is refused.
- Hallmark remains `OS_REFDATA_MISSING` until owner M1-3 resolves the locked-container registry asset. The GSVAdata brain collection is an offline S2 demonstration fixture, not a Hallmark default.

## Proposed router row

| per-sample pathway activity, GSVA scores, score heatmap, 单样本通路打分 | `gsva-score` | `scripts/run_gsva_score.R` |

## Proposed module_rules_v1.json record

```json
{
  "module": "gsva-score",
  "rule_id": "PUB-M-GSVA-001",
  "category": "design_conditional",
  "severity": "hard_error",
  "reporting_guidelines": ["Name the input scale, GSVA version, parameter-object method, requested kcdf and actual branch, collection species/version/hash, set-size bounds, and whether limma inference was performed."],
  "effect_table_policy": {"primary_metrics": ["score"], "allow_no_effect_table": true, "requirements": ["The full score matrix is the primary product; any limma table is a separate inference result on continuous scores."]},
  "artifact_aliases": {"tables/scores.csv": "primary_table", "tables/score_limma.csv": "inference_table", "results/*.json": "machine"},
  "artifact_expectations": ["full score matrix", "score heatmap", "sample design if inference", "QC", "provenance", "methods draft"],
  "required_diagnostics": ["GV-01..GV-06", "sets retained/excluded", "input storage and actual kernel branch"],
  "narrative_points": ["Heatmap row z scores are display only.", "Batch-corrected scores are descriptive; inference uses original expression with covariates in the design.", "The provisional limma eBayes settings need owner review."],
  "causal_language": {"forbidden": ["X activates a pathway based only on GSVA score"], "restricted_to": ["higher or lower gene-set score in the declared comparison"]}
}
```
