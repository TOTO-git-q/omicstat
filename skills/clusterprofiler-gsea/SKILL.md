---
name: clusterprofiler-gsea
description: >
  Run GO preranked GSEA and produce a full tested-set table, enrichment figures, QC and Methods/Results draft. Use for a named, signed gene ranking from a single DE contrast, GSEA, 基因集富集, 预排序富集. NOT for a selected gene list with an explicit eligible universe (use clusterprofiler-ora). NOT for several selected lists (use clusterprofiler-compare).
---
# clusterprofiler-gsea

## When to use / when not
Use for a continuous directional gene ranking. Use `clusterprofiler-ora` for a selected list and eligible background, and `clusterprofiler-compare` for several selected lists.

## Input requirements
Direct CSV: `feature_id,score` with unique IDs and finite signed scores, plus a named metric and positive direction. `--from-run` accepts a directional DE run with a `ranked_list`, or its complete finite `stat` column when that handoff is absent. No padj significance filter is applied. Omnibus LRT/F rankings refuse.

## Run
`Rscript scripts/run_clusterprofiler_gsea.R --ranked ranks.csv --ranking-metric 'DESeq2 Wald stat' --direction 'treated vs control' --outdir run`

### Via MCP
Call `omicstat_run` with `module="clusterprofiler-gsea"`; see `--help` and `references/parameters.md` for flags and defaults.

## What gets produced
`tables/enrichment_full.csv`, optional `figures/gsea_dotplot.*` and `gsea_curve.*`, `results/clusterprofiler_gsea_results.json`, QC, filled Methods/Results, ranked-list handoff and provenance.

## Reading the results
The full table retains all testable terms. `significant_bh05` marks the main conclusion; `exploratory_bh25` appears only when requested in advance. `eps` is a computation floor. NES and P values are specific to the locked enrichit engine and seed.

## When a QC rule fires
CG-01 marks NA P values, CG-02 no BH 0.05 finding, CG-03 package warnings; see `references/qc-rules.md`.

## Known limitations
Only registered human GO annotation is available offline. The locked clusterProfiler wrapper does not forward `...` to enrichit. An upstream `ranked_list` is preferred; the current deseq2-wald 1.1.0 branch supplies only `feature_table`, so the fallback uses every finite `stat` row and its contrast state. The GO asset lacks final registry hash/licence evidence.

## User-supplied gene sets

omicstat never bundles or downloads KEGG, PanglaoDB, MSigDB or similar gene sets. A local file that the user obtained (for example with the web app's public-data tool, or KEGG pathways from the KEGG REST API under its academic terms) runs through `--database custom`, using `clusterProfiler::GSEA` (TERM2GENE/TERM2NAME from the GMT, same multilevel arguments as the GO route). Give `--gene-sets-provenance <json>` (written by the download tool), or without it `--gene-sets-source`, `--gene-sets-version` and `--gene-sets-id-type` explicitly: these are never guessed. Optional: `--gene-sets-species`, `--gene-sets-name`, `--gene-sets-terms`. The analysis key type is `--key-type`.

`Rscript scripts/run_clusterprofiler_gsea.R --ranked ranked.csv --ranking-metric "Wald stat" --direction "higher in treated" --database custom --gene-sets kegg_hsa.gmt --gene-sets-provenance kegg_hsa.provenance.json --outdir run`

The file's SHA-256 is computed at run time and must equal the provenance `sha256` (`OS_REFDATA_MISMATCH` otherwise). A GMT must be tab-separated with a term ID, a description and at least one gene per line (`OS_INVALID_INPUT`). The gene-set identifier type must equal the analysis key type; identifiers are never converted (`OS_GENE_SET_ID_MISMATCH`). Species is compared with Homo sapiens (the module is bound to org.Hs.eg.db) (`OS_GENE_SET_SPECIES_MISMATCH`). Fewer than 10% of the unique set genes present in the analysed features is refused as a probable identifier error (`OS_GENE_SET_LOW_OVERLAP`). The KEGG term-ID exclusion applies to bundled/registered collections only, never to user files. The record (name, source, release, retrieval time, URLs, terms, ID type, species, SHA-256, overlap, "user-supplied, not bundled with omicstat") is written to `provenance/user_gene_sets.json` and `provenance/provenance.json`, and one Methods sentence states it. The user is responsible for the terms of use of the file.

## Reference files
`references/method-basis.md`, `parameters.md`, `qc-rules.md`, `reporting-templates.md`, `troubleshooting.md`.
