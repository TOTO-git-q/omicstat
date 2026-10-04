# S3 request — clusterprofiler-ora 1.0.0

S2 only; independent acceptance and router/rules installation remain for the coordinator.

## Anchor and run

Replay anchor from PACK C and `acceptance/data/ANCHOR_REGISTRY.md` row 9: DOSE `geneList`, selected IDs `names(geneList)[abs(geneList)>2]`, explicit eligible background `names(geneList)`, GO BP on registered org.Hs.eg.db 3.23.1. Locked container `omicstat-r:2026.09.1` yields 207 selected genes, 12,495 candidate background genes, 194 effective GO input IDs, 11,525 effective GO background IDs, 2,588 tested terms, 154 BH adjusted P < 0.05 terms. First term GO:0140014 has adjusted P 1.69548321341e-16. The smoke test replays the clusterProfiler call in the same R session and compares IDs and adjusted P; the golden manifest compares the main table byte for byte under the same signature. Run outputs: `/home/<user>/omic-build-logs/build_m2/ora_smoke_user/anchor/`.

Please check: effective universe and list mapping, BP/ALL pool behaviour, direct and `--from-run` eligibility, all result-affecting arguments and `simplify`, full-table P/q treatment, QC messages, reporting text and figure captions. A tampered handoff must be rejected. The dot plot PNG was visually inspected: labels and legend are readable, with no clipping or overlap; the saved figure specification contains threshold and counts.

## Known limitations / owner items

- PACK D-O5 gives package default P/q calculation cutoffs 0.05/0.2. This implementation uses 1/1 to retain testable terms, and applies BH 0.05 only as a separate label, following the cross-module full-table rule. Owner reconciliation requested.
- `env/refdata_registry.json` has GO registration but no container asset sha256 or final redistribution evidence. Other collections refuse with `OS_REFDATA_MISSING`; no KEGG content is bundled.
- Zero-overlap and unannotated GO sets are absent from the tested table by package design; the draft says so.

## Proposed S5 entries

Router §1 row:

`| selected gene list with an explicit eligible background; GO over-representation, ORA, 过度富集 | \`clusterprofiler-ora\` | \`scripts/run_clusterprofiler_ora.R\` |`

Proposed `module_rules_v1.json` record:

```json
{"module":"clusterprofiler-ora","rule_id":"PUB-M-CPORA-001","category":"design_conditional","severity":"hard_error","reporting_guidelines":["state the gene selection rule, eligible universe, ID type, ontology, OrgDb version, tested-set count and BH threshold"],"effect_table_policy":{"primary_metrics":["pvalue","padj"],"allow_no_effect_table":true,"requirements":["tables/enrichment_full.csv is the primary tested-term table","report effective GO input and background counts"]},"artifact_aliases":{"tables/enrichment_full.csv":"primary_table","results/*.json":"machine"},"artifact_expectations":["full enrichment table","QC rule results","provenance","methods draft"],"required_diagnostics":["QC rules CO-01..CO-03","background mapping loss","number of tested terms"],"narrative_points":["distinguish raw P, BH adjusted P and q-value","do not describe absent terms as tested","simplification is a display summary"],"causal_language":{"forbidden":["a GO term proves a causal mechanism"],"restricted_to":["over-represented among the selected genes relative to the stated eligible universe"]}}
```
