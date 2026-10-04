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
