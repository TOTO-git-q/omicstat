---
name: clusterprofiler-ora
description: >
  Run GO over-representation analysis and produce a full enrichment table, dot plot, QC, and filled Methods/Results draft. Use for selected gene lists with an explicit eligible universe, GO enrichment, ORA, 过度富集, 通路富集. NOT for ranked-list GSEA (use clusterprofiler-gsea). NOT for several lists (use clusterprofiler-compare).
---
# clusterprofiler-ora

## When to use / when not
Use when a selected gene list and its selection-eligible background are available. Use `clusterprofiler-gsea` for a continuous ranked list; use `clusterprofiler-compare` for several lists.

## Input requirements
CSV files with one ID column, or `--from-run` with an untampered `feature_table`. Direct input requires a rule explaining which genes could have been selected. `--from-run` uses all finite adjusted P rows as the background and selects rows with padj below `--alpha`. IDs must match the OrgDb key type.

## Run
`Rscript scripts/run_clusterprofiler_ora.R --input genes.csv --universe eligible.csv --selection-rule 'padj < 0.05' --outdir run`

`--ontology BP` is the preset. `--ontology ALL` requires an explicit `--pool TRUE` or `FALSE`: with `FALSE` clusterProfiler tests BP, CC and MF separately, each with its own effective input, background and BH family (reported per ontology); with `TRUE` the three are one collection and one BH family. `--simplify` adds a display table and the merged-term -> representative-term relation without changing the original result.

### Via MCP
Call `omicstat_run` with `module="clusterprofiler-ora"` and the same flags as args; read with `omicstat_read`. See `references/parameters.md` and `--help` for all defaults.

## What gets produced
`tables/enrichment_full.csv` (original IDs, `test_family` column), `tables/test_families.csv` (effective input/background, tested terms and BH scope per testing family), `tables/gene_symbol_map.csv` and `tables/enrichment_full_symbols.csv` (symbols via the setReadable mapping), optional `tables/enrichment_simplified_display.csv` with `tables/simplify_relation.csv`, `figures/ora_dotplot.*` when significant terms exist, `qc/qc_results.csv`, `qc/engine_warnings.csv`, `results/clusterprofiler_ora_results.json`, `draft/methods_results.md`, `objects/handoff.json`, provenance and resolved spec.

## Reading the results
The full table contains all tested, overlapping terms, with raw P, BH adjusted P, q-value and a separate BH flag. Each term keeps its real GeneRatio/BgRatio; for ALL with pool = FALSE the denominators and adjusted P values belong to that term's ontology, so read `tables/test_families.csv` before comparing across ontologies. The Methods draft names clusterProfiler, enrichGO, enrichit, GO.db (GO release date) and org.Hs.eg.db from the actual run. An absent term may have had zero overlap or lacked mapping. The dot plot shows only terms under the requested BH threshold.

## When a QC rule fires
Read `references/qc-rules.md`; CO-01 warns about mapping loss, CO-02 states that no term passed the threshold, and CO-03 points to package warnings.

## Known limitations
Only the registered human GO annotation is enabled offline. KEGG, MSigDB and Reactome are typed refusals until reference data are pinned. The registry does not yet contain a container GO asset hash. The full-table cutoff reconciliation remains under 待裁决.

## Reference files
`references/method-basis.md`, `parameters.md`, `qc-rules.md`, `reporting-templates.md`, `troubleshooting.md`.
