# deseq2-lrt: independent S3 review request

S2 module `skills/deseq2-lrt/` 1.1.0, image `omicstat-r:2026.10.1`.
Reproduce with `Rscript skills/deseq2-lrt/tests/run_smoke_test.R` in the locked image.
Outputs: `/home/<user>/omic-build-logs/build_m1/_smoke/deseq2-lrt-smoke/` and logs
`lrt-golden.log`, `lrt-check.log`, `lrt-lock.log`. The a1 run is fission, a2 is pasilla.

## Review focus

- P-1: confirm both formulas, nested/full-rank/positive-df checks and retained adjustment terms; fission interaction is the primary anchor. `--min-samples` must be explicit.
- P-3: `results(lfcThreshold=0)` preserves joint LRT P values; `log2fc` displays only one labelled coefficient. No LFC threshold, shrinkage or directional ranked list is inferred.
- P-2: `--pattern-clustering` is explicitly opt-in with DEGreport 1.48.0; --pattern-genes and --time-col are required. The caller supplies gene selection; native options and assignments are recorded. Verify default LRT outputs stay byte-identical.
- Inspect fission and pasilla top heatmaps and the fission trajectory PNGs/specs. The trajectory is exploratory; it does not define a second confirmatory test.
- Check the shared feature-ID fix: fission IDs with numeric dot suffixes remain distinct; Ensembl version suffixes still strip.

## Anchors

| Anchor | Type/source | S2 result |
|---|---|---|
| fission interaction | REPLAY, PACK S1 P-4; fission assay SHA256 `4bec9e6d01665301ced3de128eff4cfb1269aed9701146e794087e24f526fe30` | 7,039 input; 6,205 tested; 8 significant; df=5; independent DESeq2 p-values and padj missingness match |
| pasilla additive nested model | secondary REPLAY, PACK S1 P-4; input files SHA256 checked by `make_pasilla.R` | 14,599 input; 8,148 tested; 1,112 significant; df=1 |
| spec and handoff | deterministic replay and deseq2-qc upstream | byte-identical table/JSON/PNGs; tampered upstream refused |

## Known limitations / 待裁决

Pattern clustering defaults off; no gene-selection rule is inferred. A 60-gene fission probe passed native assignment sanity and default LRT byte parity; complete smoke is queued. `--adjust` checks only named terms. No LRT ranked list is handed off because the joint statistic has no direction.

## Proposed S5 entries (for the independent coordinator)

Router §1 row:

| question sounds like ... | module | entry |
|---|---|---|
| RNA-seq time course, interaction, multiple-group joint test, likelihood ratio test, 似然比检验, 时间序列, 多组比较 | `deseq2-lrt` | `scripts/run_deseq2_lrt.R` |

Proposed `module_rules_v1.json` record:

```json
{
  "module": "deseq2-lrt",
  "rule_id": "PUB-M-DESEQ2LRT-001",
  "category": "design_conditional",
  "severity": "hard_error",
  "reporting_guidelines": ["state full and reduced formulas, removed terms, degrees of freedom and FDR method", "label the one reported log2fc coefficient separately from the joint P value"],
  "effect_table_policy": {"primary_metrics": ["pvalue", "padj"], "requirements": ["full LRT table retained", "no single-coefficient FC threshold for joint significance"]},
  "artifact_aliases": {"tables/feature_table.csv": "feature_table", "results/*.json": "machine"},
  "artifact_expectations": ["top heatmap when at least two genes are significant", "trajectory when time column supplied", "QC rule results", "provenance", "Methods draft"],
  "required_diagnostics": ["QC rules DL-01..DL-13", "nested-model and replicate checks", "single coefficient warning"],
  "narrative_points": ["one displayed log2fc does not represent the joint test", "pattern clustering requires explicit caller genes/time and recorded native options"],
  "causal_language": {"forbidden": ["directional claim from the unsigned LRT statistic"], "restricted_to": []}
}
```
