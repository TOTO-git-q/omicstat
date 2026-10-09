---
name: clusterprofiler-compare
description: >
  Compare GO enrichment profiles for several defined gene lists and produce a full tested table, QC and Methods/Results draft. Use for compareCluster, multi-list ORA, GO term profiles, 多组富集比较. NOT for one selected list (use clusterprofiler-ora). NOT for a ranked continuous gene list (use clusterprofiler-gsea).
---
# clusterprofiler-compare

## When to use / when not
Use for two or more named selected gene lists with explicit eligibility and provenance. Use `clusterprofiler-ora` for one list; use `clusterprofiler-gsea` for a directional ranked statistic.

## Input requirements
A CSV manifest with one row per group and columns `group,genes,universe,population,study_unit,model,contrast,direction,threshold,top_n,selection_rule`. List/background CSVs contain `feature_id`. The study unit and direction must describe what each list represents; do not treat repeated samples of the same unit as independent.

## Run
`Rscript scripts/run_clusterprofiler_compare.R --manifest lists.csv --outdir run`

### Via MCP
Call `omicstat_run` with `module="clusterprofiler-compare"`; see `--help` and `references/parameters.md` for all flags and defaults.

## What gets produced
`tables/enrichment_full.csv` (with `test_family`), `tables/list_definitions.csv`, `tables/test_families.csv` (effective input/background, tested terms and BH scope per list and testing family), an optional shared-universe comparison dot plot, QC, `results/clusterprofiler_compare_results.json`, filled Methods/Results, provenance and `enrichment_table` handoff.

## Reading the results
A common-universe plot appears only when the declared selectable population and all universe memberships match. Otherwise each list has its own ORA background and no pooled comparison plot. The plot never tests a difference in enrichment between lists. Raw P, adjusted P and q-value remain separate. BH is always within one list; with `--ontology ALL --pool FALSE` it is also within one ontology, and each list x ontology has its own effective input and background. `list_definitions.csv` then leaves `n_effective_input`/`n_effective_background` empty and gives `effective_*_by_family` (e.g. `BP=198;CC=201;MF=205`); every row keeps its real GeneRatio/BgRatio.

## When a QC rule fires
CX-01 marks different eligible populations, CX-02 no significant term, CX-03 engine warnings. See `references/qc-rules.md`.

## Known limitations
Only registered human GO annotation is enabled offline. Other collections refuse. The GO registry entry lacks final asset hash and licence evidence. Formula input is not exposed; the named-list manifest retains all per-list metadata instead. This module does not perform a between-list enrichment contrast test.

## User-supplied gene sets

omicstat never bundles or downloads KEGG, PanglaoDB, MSigDB or similar gene sets. A local file that the user obtained (for example with the web app's public-data tool, or KEGG pathways from the KEGG REST API under its academic terms) runs through `--database custom`, using `clusterProfiler::compareCluster(fun = "enricher")` for one shared population, otherwise `enricher` per list. Give `--gene-sets-provenance <json>` (written by the download tool), or without it `--gene-sets-source`, `--gene-sets-version` and `--gene-sets-id-type` explicitly: these are never guessed. Optional: `--gene-sets-species`, `--gene-sets-name`, `--gene-sets-terms`. The analysis key type is `--key-type`.

`Rscript scripts/run_clusterprofiler_compare.R --manifest lists.csv --database custom --gene-sets kegg_hsa.gmt --gene-sets-provenance kegg_hsa.provenance.json --outdir run`

The file's SHA-256 is computed at run time and must equal the provenance `sha256` (`OS_REFDATA_MISMATCH` otherwise). A GMT must be tab-separated with a term ID, a description and at least one gene per line (`OS_INVALID_INPUT`). The gene-set identifier type must equal the analysis key type; identifiers are never converted (`OS_GENE_SET_ID_MISMATCH`). Species is compared with Homo sapiens (the module is bound to org.Hs.eg.db) (`OS_GENE_SET_SPECIES_MISMATCH`). Fewer than 10% of the unique set genes present in the analysed features is refused as a probable identifier error (`OS_GENE_SET_LOW_OVERLAP`). The KEGG term-ID exclusion applies to bundled/registered collections only, never to user files. The record (name, source, release, retrieval time, URLs, terms, ID type, species, SHA-256, overlap, "user-supplied, not bundled with omicstat") is written to `provenance/user_gene_sets.json` and `provenance/provenance.json`, and one Methods sentence states it. The user is responsible for the terms of use of the file.

## Reference files
`references/method-basis.md`, `parameters.md`, `qc-rules.md`, `reporting-templates.md`, `troubleshooting.md`.
