---
name: limma-camera
description: Run one prespecified limma competitive or self-contained gene-set test on continuous expression or a ranked statistic; produce a gene-set table, figure, QC, and Methods/Results draft. Use for camera, cameraPR, fry, roast, mroast, competitive or self-contained enrichment.
---
# limma-camera

## Use

Choose `--question competitive` before testing; expression runs camera, a ranked-list runs cameraPR. Choose `--question self-contained --self-contained-method fry|roast|mroast` on expression. roast additionally needs `--set-id`. Do not choose the method after inspecting P values. Use fgsea-prerank for a running-score preranked GSEA curve, and gsva-score for per-sample set scores.

## Inputs

Expression CSV has a `feature_id` column and continuous sample columns; give a sample table, two explicit groups, `--input-scale`, and optional factor covariates/voom weights. Ranked CSV has exactly `feature_id,symbol,score`, sorted descending, all rankable genes, no significance filter; without omicstat metadata it needs `--direction` (and a metric name). `--from-run` of a limma-voom/limma-array/limma-dupcor run uses its EList E + weights, fitted design and tested coefficient unchanged (`--upstream-object ranked_list` for cameraPR on its ranked_list metadata); a dupcor block is modelled by fry/roast/mroast, while camera on it needs `--acknowledge-block-ignored`. Other `--from-run` inputs are typed expression_matrix or ranked_list handoffs. A corrected matrix or corrected lineage is refused for inference. The collection must be offline and SHA-256 registered; the unresolved MSigDB default raises `OS_REFDATA_MISSING`.

## Run

```sh
Rscript skills/limma-camera/scripts/run_limma_camera.R --input expression.csv --samples samples.csv --question competitive --reference control --target treatment --collection limma_gender_genes --outdir run
```

Use `--help` for the complete flag list; all defaults and choices are documented in `references/parameters.md`. MCP uses `omicstat_run` with `module="limma-camera"` and the same arguments. The entry writes `qc/engine_warnings.csv` for engine warnings.

## Outputs and interpretation

`tables/gene_set_table.csv` contains set size after ID overlap, direction, P and BH adjusted P; `tables/method_raw.csv` retains method-specific columns. `tables/design.csv` is the design actually used. `figures/gene_set_bar` shows adjusted P; `figures/barcode_1|2` show the top sets on the ranked statistic with the enrichment worm; `figures/md_set_highlight` (expression routes) highlights them on the MD plot. The Methods state input scale and weights, design, coefficient, replicate unit/correlation or the ranking metric and direction, per route. `draft/methods_results.md`, `results/limma_camera_results.json`, `qc/qc_results.csv`, provenance, and typed handoff are written. camera correlation 0.01 is a preset. roast/mroast seed, RNG, nrot and midp status are recorded; nrot 1999 is development-only.

## QC and limits

Read triggered QC rules LC-01 through LC-06 in `references/qc-rules.md`. The printed Yoruba camera P values reproduce with the guide-era `voom(adaptive.span = FALSE)`; the suite route keeps the locked default and has its own replay values (`references/method-basis.md`). No KEGG data are supplied.

## User-supplied gene sets

omicstat never bundles or downloads KEGG, PanglaoDB, MSigDB or similar gene sets. A local file that the user obtained (for example with the web app's public-data tool, or KEGG pathways from the KEGG REST API under its academic terms) runs through `--collection user`, using the same limma calls as a registered collection. Give `--gene-sets-provenance <json>` (written by the download tool), or without it `--gene-sets-source`, `--gene-sets-version` and `--gene-sets-id-type` explicitly: these are never guessed. Optional: `--gene-sets-species`, `--gene-sets-name`, `--gene-sets-terms`. The analysis key type is `--feature-id-type`.

`Rscript scripts/run_limma_camera.R --question competitive --from-run voom_run --collection user --gene-sets sets.gmt --gene-sets-provenance sets.provenance.json --feature-id-type ENTREZID --outdir run`

The file's SHA-256 is computed at run time and must equal the provenance `sha256` (`OS_REFDATA_MISMATCH` otherwise). A GMT must be tab-separated with a term ID, a description and at least one gene per line (`OS_INVALID_INPUT`). The gene-set identifier type must equal the analysis key type; identifiers are never converted (`OS_GENE_SET_ID_MISMATCH`). Species is compared with not declared by this module, so only the record is kept (`OS_GENE_SET_SPECIES_MISMATCH`). Fewer than 10% of the unique set genes present in the analysed features is refused as a probable identifier error (`OS_GENE_SET_LOW_OVERLAP`). The KEGG term-ID exclusion applies to bundled/registered collections only, never to user files. The record (name, source, release, retrieval time, URLs, terms, ID type, species, SHA-256, overlap, "user-supplied, not bundled with omicstat") is written to `provenance/user_gene_sets.json` and `provenance/provenance.json`, and one Methods sentence states it. The user is responsible for the terms of use of the file.
