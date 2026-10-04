# fgsea-prerank — independent S3 request

## Review scope

Run `skills/fgsea-prerank/tests/run_smoke_test.R` and `tools/make_module_lock.R fgsea-prerank --check` in `omicstat-r:2026.09.1`. Review strict ranked_list handoff (`feature_id,symbol,score`, descending, finite, unique), named direction/metric, offline registry hash and KEGG exclusion, explicit `fgseaMultilevel` arguments, set-size accounting, full table and seed, typed errors, `--spec`, `--from-run`, and both figures. Check the figure captions for thresholds and n. S3 review is independent; S2 has not accepted itself.

## Anchor and outputs

- Source: fgsea 1.38.0 package-embedded `exampleRanks` and `examplePathways`, used in PACK C and the official fgsea tutorial `Quick run`; the tutorial does not name the statistic behind `exampleRanks`, so the fixture labels it as unspecified. Generated input CSV SHA-256 `18a41efbab53aa9e60380b495615d8ac5f98494ef7fd465525b94ec17c55488a`. The registered mouse collection SHA-256 is `c26782589a8d38e92701386418a64101b7a66875702d2d48549f8151d29ee10e`.
- Fixed seed 20260925, min/max 15–500, alpha 0.05: 12,000 ranked genes; 1,457 input sets; 586 retained; 124 BH-significant; `5990979_Cell_Cycle,_Mitotic` NES 2.75941576990235. These are **replay anchors** from the locked container, not printed tutorial values. Direct `fgseaMultilevel` replay in the smoke checks the NES; golden manifest checks the full table and PNGs bytewise in the same environment signature.
- Last S2 smoke: `/home/<user>/omic-build-logs/build_m2b/fgsea_final_smoke.log` (22 PASS, 0 FAIL, SMOKE PASSED). Anchor outputs: `/home/<user>/omic-build-logs/build_m2b/fgsea-prerank-smoke/a1/`.

## Known limits and owner items

- Hallmark preset refuses with `OS_REFDATA_MISSING` until `msigdb_collections` has a resolved locked-container asset/version/hash (owner M1-3). The package fixture is for offline S2 replay.
- This branch's `deseq2-wald` does not yet produce `ranked_list`, despite the lane instruction; the handoff reader accepts the frozen type and was exercised with a conforming upstream. Coordinator should merge the upstream producer.
- The figure lint recorded one informational FIG-03 grayscale proximity for the shared blue/red NES palette. No blocking lint issue; figures were visually reviewed.

## Proposed router row

| preranked GSEA, fgsea multilevel, full directional Wald or moderated-t ranking, 预排序富集 | `fgsea-prerank` | `scripts/run_fgsea_prerank.R` |

## Proposed module_rules_v1.json record

```json
{
  "module": "fgsea-prerank",
  "rule_id": "PUB-M-FGSEA-001",
  "category": "design_conditional",
  "severity": "hard_error",
  "reporting_guidelines": ["Name the ranking metric and positive direction, fgsea version, offline collection/version/hash, 15–500 intersected set size, seed, eps floor, and BH reporting threshold."],
  "effect_table_policy": {"primary_metrics": ["nes", "padj"], "allow_no_effect_table": true, "requirements": ["Use the full enrichment_table.csv; do not report only significant sets as the tested population."]},
  "artifact_aliases": {"tables/enrichment_table.csv": "primary_table", "results/*.json": "machine"},
  "artifact_expectations": ["full enrichment table", "NES figure when significant", "GSEA curve when significant", "QC", "provenance", "methods draft"],
  "required_diagnostics": ["FG-01..FG-04", "tied-score count", "sets retained/excluded after ID intersection"],
  "narrative_points": ["A ranked statistic encodes direction; it is not a fold-change estimate.", "eps is a computation floor, not a tolerance."],
  "causal_language": {"forbidden": ["X activates a pathway based only on NES"], "restricted_to": ["enriched toward positive or negative ranked genes"]}
}
```
