# S3 request — clusterprofiler-compare 1.0.0

S2 only; independent acceptance and router/rules installation remain for the coordinator.

## Anchor and run

PACK C names clusterProfiler `gcSample` (eight lists) as a replay anchor but its book call omits an eligible background. This S2 test intersects each list with DOSE `geneList` and explicitly uses all 12,495 DOSE ranked IDs as the common selection-eligible fixture population. It does **not** claim to reproduce the book's unspecified-background result. The locked container direct `compareCluster` replay and module both yield 29,874 tested list-term rows, 247 BH adjusted P < 0.05 rows, eight lists and 11,525 effective GO background IDs per list. Four lists have at least one significant term. The golden manifest checks the full table byte for byte. Run outputs: `/home/<user>/omic-build-logs/build_m2/compare_smoke_user/anchor/`.

Please check the mandatory per-list study unit, model/contrast, direction, threshold, top-N, selection rule, list and background paths, candidate/mapped/effective counts, BP default and ALL/pool gate, full-table P/q treatment, and the branch between shared-universe compareCluster and separate enrichGO. Mixed-background output: `/home/<user>/omic-build-logs/build_m2/compare_smoke_user/mixed/`. It must have `mode = separate_background_ORA`, CX-01, distinct backgrounds and no pooled comparison figure. The compare dot plot PNG was opened: all eight labels, including four blank groups, are visible; no overlap or clipping. Its caption states BH 0.05, eight lists, four with a result below threshold and no between-list significance test.

## Known limitations / owner items

- The book example's original eligible population is unknown; the DOSE fixture is a deliberately different, explicit population. Scientific reproduction of the original book output would require its selection frame.
- As with ORA, computation uses P/q cutoffs 1/1 for a full testable table and a separate BH 0.05 label; PACK D-C3 defaults 0.05/0.2 need owner reconciliation against the cross-module full-table rule.
- The registered GO annotation lacks a final container asset hash/licence record. Other collections refuse with `OS_REFDATA_MISSING`; no KEGG content is included.
- A manifest records each list's study unit and model, but cannot independently validate sample independence from gene IDs alone. The module performs no between-list enrichment contrast test.

## Proposed S5 entries

Router §1 row:

`| several defined gene lists with explicit eligible backgrounds; compareCluster GO profiles, 多组富集比较 | \`clusterprofiler-compare\` | \`scripts/run_clusterprofiler_compare.R\` |`

Proposed `module_rules_v1.json` record:

```json
{"module":"clusterprofiler-compare","rule_id":"PUB-M-CPCOMPARE-001","category":"design_conditional","severity":"hard_error","reporting_guidelines":["for every list state the study unit, model/contrast, direction, threshold, top-N, eligible universe and GO annotation version"],"effect_table_policy":{"primary_metrics":["pvalue","padj"],"allow_no_effect_table":true,"requirements":["tables/enrichment_full.csv is the primary tested list-term table","tables/list_definitions.csv gives per-list candidate and effective counts"]},"artifact_aliases":{"tables/enrichment_full.csv":"primary_table","results/*.json":"machine"},"artifact_expectations":["full enrichment table","per-list definitions","QC rule results","provenance","methods draft"],"required_diagnostics":["QC rules CX-01..CX-03","population and universe equality gate","per-list mapped background and input counts"],"narrative_points":["comparison dots are a visualization, not a between-list enrichment test","different backgrounds require separate ORA interpretation","raw P, adjusted P and q-value differ"],"causal_language":{"forbidden":["pathway A is significantly more enriched in group X than group Y based on this plot"],"restricted_to":["term passes BH 0.05 within list X under its stated eligible universe"]}}
```
