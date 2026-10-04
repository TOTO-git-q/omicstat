---
name: limma-dupcor
description: Run limma duplicateCorrelation differential expression for repeated correlated units and produce a complete feature table, volcano and MD figures, and a filled Methods/Results draft reporting the consensus correlation. Use for donor, patient, clone, or comparable repeated units in normalized arrays or raw bulk RNA-seq; Chinese triggers include 配对芯片, 重复测量, 相关性区组. NOT for independent samples (use limma-array or limma-voom); NOT for a technical batch without a random-block rationale (include it as a fixed design effect).
---

## When to use / when not

Use when several measurements belong to a described correlated unit, such as one donor. For independent arrays use `limma-array`; for independent RNA samples use `limma-voom`.

## Input requirements

Supply a normalized log2 array matrix or raw integer RNA counts, matching sample table, condition, reference, target, and `--block` column. The block description must name the correlated unit. Repeated units, design rank, residual degrees of freedom, and estimability are checked. `--from-run` accepts a verified expression or count matrix plus sample table.

## Run

`Rscript scripts/run_limma_dupcor.R --mode array --matrix log2_arrays.csv --samples samples.csv --block donor --block-description 'human donor' --platform other --trend true --robust false --reference MS --target ML --outdir run`

### Via MCP

Select `limma-dupcor` with the same flags. `--help` lists every option; `--mode`, `--block`, `--platform`, `--trend`, `--robust`, and `--min-effect-fc` are the key choices. See `references/parameters.md` for defaults and fixed calls.

## What gets produced

`tables/feature_table.csv` and `tables/limma_full.csv` preserve the full inferential result. `tables/direction_summary.csv` gives Down/NotSig/Up. Figures: volcano, MD, the sample MDS (`figures/mds.*`, coordinates in `tables/mds_coordinates.csv`; RNA: filtered TMM log2 CPM, arrays: the supplied matrix; donors shaped when there are few), the round-2 voom mean-variance trend in RNA mode (`figures/voom_trend.*`) and the SA diagnostic for non-Agilent arrays. The draft Methods report every setting of the actual run (edgeR version, filterByExpr thresholds and TMM factors in RNA mode; both voom -> duplicateCorrelation rounds with spans and consensus values; block meaning, unit count and sizes; trim; eBayes/treat settings with their source and prior df) and end with figure legends. The results JSON and fit hand-off record the same values. The hand-off carries the fit, the voom `EList` (RNA), the expression matrix, the sample table and a ranked list.

## Reading the results

The consensus correlation is estimated from the input, reported, and passed to `lmFit`; it is never a preset. RNA mode estimates the voom weights and correlation twice. Agilent arrays inherit `limma-array` trend/robust TRUE; non-Agilent arrays need explicit choices. A prespecified `treat` threshold and display-only filter remain separate.

## When a QC rule fires

`LD-01..LD-05` cover replication, too few features, invalid adjusted P values, nonfinite effects, and all-significant results. Block and design failures stop before fitting. See `references/qc-rules.md`.

## Known limitations

The Illumina guide prints 0.134 and the engine reproduces it on the guide's 12 arrays. The Yoruba guide (sec 18.1) prints 0.446: the guide's code reproduces it, and every other printed sec 18.1.9 value, only with the guide-era voom span 0.5 (`adaptive.span = FALSE`; limma 3.66.0 made `adaptive.span = TRUE` the default). The suite keeps the locked default `adaptive.span = TRUE`, under which the consensus is 0.4454514 (prints 0.445); the test asserts the printed values with the guide code and the engine against a locked replay. Non-Agilent array moderation presets await owner clarification (explicit `--trend`/`--robust` required).

## Reference files

`method-basis.md` records locked sources; `parameters.md` documents flags; `qc-rules.md` lists sources; `reporting-templates.md` supplies filled prose; `troubleshooting.md` maps typed errors to fixes.
