---
name: gsva-score
description: >
  Score each sample against offline gene sets with GSVA's parameter-object API and produce a score matrix, per-set size table, heatmap, score-by-group figure, and filled Methods/Results draft. Use for GSVA, pathway scores, 单样本通路打分. NOT for preranked population enrichment (use fgsea-prerank). NOT for count differential expression (use deseq2-wald).
---
# gsva-score

Per-cell gene-set activity on a single-cell object routes to `aucell-score`;
sample-level scores on bulk or pseudobulk matrices route to `gsva-score`.
Neither AUCell nor GSVA is the suite standard. Coordinator decision 3 is
reversible by the owner.

## When to use / when not
Use this module for per-sample gene-set scores from VST, logCPM, or explicitly declared normalized array expression. Use fgsea-prerank for a ranked population result and deseq2-wald for count differential expression.

## Input requirements
A feature-by-sample CSV, a typed upstream expression matrix, or a limma-voom / limma-array / limma-dupcor run (its EList `E` is scored; GSVA does not use the precision weights and the Methods say so), a declared scale, and an offline gene-set collection in the locked registry. Count input requires explicit `--kcdf Poisson`. A sample table only annotates the figures.

## Run
```
Rscript scripts/run_gsva_score.R --input expression.csv --input-scale vst --collection gsva_brain_txdb_sets --outdir run
```
Add `--samples` and `--group-col` for group annotation. `--reference`, `--target` or `--covariates` (a request for group inference) is refused with `OS_OWNER_DECISION_PENDING`. `--help` lists all flags.

### Via MCP
Call `omicstat_run` with `module="gsva-score"` and the same flags as `args`, then read with `omicstat_read`.

## What gets produced
`tables/scores.csv` (all scores), `tables/gene_set_sizes.csv` (per set: collection size, matched IDs, size after GSVA's constant-row removal, size used by GSVA, retained/excluded and reason), `figures/score_heatmap`, `figures/score_by_group` (with a group column; descriptive, no test), `objects/gsva_param.rds`, result JSON, QC, provenance, draft, and a typed score-matrix handoff (typed `batch_corrected_matrix` with `batch_corrected_lineage = TRUE` when the input was batch-corrected).

## Reading the results
Scores are continuous and sample-level. The heatmap row z scores and the score-by-group boxes are for display only. This module performs no group inference. Scores derived from batch-corrected expression are descriptive only and every downstream module refuses them (`OS_BATCH_CORRECTED_INPUT`).

## When a QC rule fires
GV-01–GV-06 are documented in `references/qc-rules.md`.

## Known limitations
The owner has not frozen which limma module receives GSVA scores or the eBayes trend/robust settings (S1 P-3); until then inference requests are refused (`OS_OWNER_DECISION_PENDING`) and no P values are produced. The Hallmark registry entry still needs locked-container resolution (M1-3). Survival and repeated-measures inference are outside this module.

## User-supplied gene sets

omicstat never bundles or downloads KEGG, PanglaoDB, MSigDB or similar gene sets. A local file that the user obtained (for example with the web app's public-data tool, or KEGG pathways from the KEGG REST API under its academic terms) runs through `--collection user`, using the same `GSVA::gsvaParam`/`gsva` calls as a registered collection. Give `--gene-sets-provenance <json>` (written by the download tool), or without it `--gene-sets-source`, `--gene-sets-version` and `--gene-sets-id-type` explicitly: these are never guessed. Optional: `--gene-sets-species`, `--gene-sets-name`, `--gene-sets-terms`. The analysis key type is `--feature-id-type`.

`Rscript scripts/run_gsva_score.R --input expr.csv --input-scale logcpm --collection user --gene-sets sets.gmt --gene-sets-provenance sets.provenance.json --feature-id-type SYMBOL --outdir run`

The file's SHA-256 is computed at run time and must equal the provenance `sha256` (`OS_REFDATA_MISMATCH` otherwise). A GMT must be tab-separated with a term ID, a description and at least one gene per line (`OS_INVALID_INPUT`). The gene-set identifier type must equal the analysis key type; identifiers are never converted (`OS_GENE_SET_ID_MISMATCH`). Species is compared with not declared by this module, so only the record is kept (`OS_GENE_SET_SPECIES_MISMATCH`). Fewer than 10% of the unique set genes present in the analysed features is refused as a probable identifier error (`OS_GENE_SET_LOW_OVERLAP`). The KEGG term-ID exclusion applies to bundled/registered collections only, never to user files. The record (name, source, release, retrieval time, URLs, terms, ID type, species, SHA-256, overlap, "user-supplied, not bundled with omicstat") is written to `provenance/user_gene_sets.json` and `provenance/provenance.json`, and one Methods sentence states it. The user is responsible for the terms of use of the file.

## Reference files
- `references/method-basis.md`
- `references/parameters.md`
- `references/qc-rules.md`
- `references/reporting-templates.md`
- `references/troubleshooting.md`
