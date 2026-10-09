---
name: fgsea-prerank
description: >
  Run fgsea multilevel preranked enrichment and produce a full gene-set table, NES figures, and a filled Methods/Results draft. Use for directional full-ranking GSEA, fgsea, 预排序基因集富集. NOT for over-representation analysis (use clusterprofiler-ora). NOT for per-sample pathway scores (use gsva-score).
---
# fgsea-prerank

## When to use / when not
Use a full directional ranking, not a significant DEG subset. Use clusterprofiler-ora for an unranked gene list and gsva-score for sample-level scores.

## Input requirements
A ranked_list CSV with exactly feature_id,symbol,score sorted descending, or a typed `ranked_list` upstream handoff (deseq2-wald, limma-voom, limma-array, limma-dupcor). Scores must be finite and IDs unique. With `--from-run` the metric, contrast and direction come from the upstream ranked_list metadata (`_shared/scripts/ranked_list.R`); an upstream without that metadata, or with an undirectional statistic (LRT / F), is refused. A plain CSV needs `--rank-metric`/`--metric-name` and `--direction`. The table is ordered by NES within the significant and the non-significant sets; captions describe the two ends of the named ranking, never assuming up/down-regulated expression. Gene sets must be available offline in `env/refdata_registry.json`, with a resolved version and SHA-256. KEGG content is excluded.

## Run
```
Rscript scripts/run_fgsea_prerank.R --ranked-list ranks.csv --direction 'treated versus control' --collection fgsea_example_pathways --outdir run
```
`--help` lists all flags. `--spec` replays a prior resolved spec.

### Via MCP
Call `omicstat_run` with `module="fgsea-prerank"` and the same flags as `args`, then `omicstat_read` for results.

## What gets produced
`tables/enrichment_table.csv` (all tested sets), `figures/nes_bar` and `figures/gsea_curve` when sets meet alpha, `results/fgsea_prerank_results.json`, `draft/methods_results.md`, `qc/qc_results.csv`, provenance, and typed handoff objects.

## Reading the results
NES sign follows the named ranking direction. `eps` is a P-value computation floor, not a tolerance. Compare full tables bytewise only with the same environment signature and inputs. A missing significant figure means no set crossed the reporting threshold; the full table remains.

## When a QC rule fires
FG-01–FG-04 are documented in `references/qc-rules.md`.

## Known limitations
The Hallmark preset cannot run until the locked-container `msigdb_collections` registry entry is resolved (owner M1-3). Current `deseq2-wald` on this branch lacks the ranked_list handoff, so direct CSV input or another conforming upstream is needed.

## User-supplied gene sets

omicstat never bundles or downloads KEGG, PanglaoDB, MSigDB or similar gene sets. A local file that the user obtained (for example with the web app's public-data tool, or KEGG pathways from the KEGG REST API under its academic terms) runs through `--collection user`, using the same `fgsea::fgseaMultilevel` call as a registered collection. Give `--gene-sets-provenance <json>` (written by the download tool), or without it `--gene-sets-source`, `--gene-sets-version` and `--gene-sets-id-type` explicitly: these are never guessed. Optional: `--gene-sets-species`, `--gene-sets-name`, `--gene-sets-terms`. The analysis key type is `--feature-id-type`.

`Rscript scripts/run_fgsea_prerank.R --from-run de_run --collection user --gene-sets kegg_hsa.gmt --gene-sets-provenance kegg_hsa.provenance.json --feature-id-type ENTREZID --outdir run`

The file's SHA-256 is computed at run time and must equal the provenance `sha256` (`OS_REFDATA_MISMATCH` otherwise). A GMT must be tab-separated with a term ID, a description and at least one gene per line (`OS_INVALID_INPUT`). The gene-set identifier type must equal the analysis key type; identifiers are never converted (`OS_GENE_SET_ID_MISMATCH`). Species is compared with not declared by this module, so only the record is kept (`OS_GENE_SET_SPECIES_MISMATCH`). Fewer than 10% of the unique set genes present in the analysed features is refused as a probable identifier error (`OS_GENE_SET_LOW_OVERLAP`). The KEGG term-ID exclusion applies to bundled/registered collections only, never to user files. The record (name, source, release, retrieval time, URLs, terms, ID type, species, SHA-256, overlap, "user-supplied, not bundled with omicstat") is written to `provenance/user_gene_sets.json` and `provenance/provenance.json`, and one Methods sentence states it. The user is responsible for the terms of use of the file.

## Reference files
- `references/method-basis.md`
- `references/parameters.md`
- `references/qc-rules.md`
- `references/reporting-templates.md`
- `references/troubleshooting.md`
