# S3 request — clusterprofiler-gsea 1.0.0

S2 only; independent acceptance and installation remain for the coordinator.

## Anchor and tests

PACK C replay anchor: DOSE `geneList` (12,495 named Entrez genes), GO BP through registered org.Hs.eg.db 3.23.1 in `omicstat-r:2026.09.1`. The engine uses all ranks without a significance filter and the locked clusterProfiler 4.20.0 → enrichit 0.2.1 multilevel route. A same-session `gseGO` replay with the full explicit call yields 5,299 tested sets and 715 BH adjusted P < 0.05; first row GO:0000819, NES 2.89486744, adjusted P 8.02878788e-09. Main table and both PNGs were byte-identical across two fresh processes with `set.seed(20260925)`. Run: `/home/<user>/omic-build-logs/build_m2/gsea_smoke_user/anchor/`.

Please check the ranking and contrast metadata, all finite genes/no significance cut, ontology and size rules, exact GSEA arguments, downstream enrichit defaults, RNG behavior, full-table BH 0.05 inference versus optional exploratory 0.25 flag, NA P handling, figures and filled prose. The dot plot and curve PNGs were opened: labels and legend are readable, no overlaps or clipping. Captions/specs state thresholds and counts.

## Known limitations / owner items

- The locked `gseGO` and `GSEA` wrappers do not pass their `...` to `enrichit::gsea_gson`. Thus `seed`, `eps`, `sampleSize`, `nPermSimple`, `scoreType` and `weight` cannot be set explicitly through this wrapper. `enrichit::gsea(seed = FALSE)` samples one seed from the R RNG; `set.seed(20260925)` produced byte-identical replay in the locked container. Owner should decide whether the inherited downstream defaults satisfy S1 P-2 or whether a new wrapper/API is needed.
- `deseq2-wald` on this branch does not currently hand off `ranked_list`; the fallback takes every finite `stat` row from its `feature_table` plus its directional contrast. The preferred `ranked_list` path is supported and tested.
- GO is registered and installed, but `env/refdata_registry.json` has no final container GO asset hash/licence evidence. MSigDB, Reactome and KEGG refuse offline with `OS_REFDATA_MISSING`. No KEGG content is bundled.

## Proposed S5 entries

Router §1 row:

`| named signed ranking from one DE contrast; GO GSEA, preranked enrichment, 预排序富集 | \`clusterprofiler-gsea\` | \`scripts/run_clusterprofiler_gsea.R\` |`

Proposed `module_rules_v1.json` record:

```json
{"module":"clusterprofiler-gsea","rule_id":"PUB-M-CPGSEA-001","category":"design_conditional","severity":"hard_error","reporting_guidelines":["name the directional ranking statistic, contrast, GO ontology, intersected set-size range, seed, enrichit version and BH 0.05 threshold"],"effect_table_policy":{"primary_metrics":["nes","padj"],"allow_no_effect_table":true,"requirements":["tables/enrichment_full.csv retains all testable sets","exploratory BH 0.25 is separate from the main BH 0.05 flag"]},"artifact_aliases":{"tables/enrichment_full.csv":"primary_table","results/*.json":"machine"},"artifact_expectations":["full enrichment table","GSEA figures when significant terms exist","QC rule results","provenance","methods draft"],"required_diagnostics":["QC rules CG-01..CG-03","number of ranked genes and tested sets","NA P count"],"narrative_points":["raw P, BH adjusted P and q-value are distinct","eps is a computation floor","NES is engine and seed specific"],"causal_language":{"forbidden":["a pathway is activated because its NES is positive"],"restricted_to":["enriched toward the positive or negative end of the stated ranking"]}}
```
