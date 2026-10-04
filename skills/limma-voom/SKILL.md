---
name: limma-voom
description: "Run limma-voom differential expression on raw bulk RNA-seq counts and produce a feature table, volcano, MD, voom mean-variance and sample MDS figures, and a filled Methods/Results draft. Use for one target-vs-reference RNA-seq contrast (further condition groups stay in the model) with optional fixed-effect covariates; Chinese triggers: 差异表达, RNA测序, voom. NOT for normalized array intensities (use limma-array); NOT for repeated correlated units (use limma-dupcor)."
---

## When to use / when not

Use for one target-versus-reference comparison of bulk RNA-seq counts. The condition may have more than two groups (as in the RNAseq123 workflow: Basal, LP, ML plus lane): the compared pair is one coefficient of `~ covariates + condition` and the other groups remain in the model. For normalized log2 microarrays use `limma-array`; for repeated measures use `limma-dupcor`.

## Input requirements

A raw nonnegative integer feature-by-sample count CSV/TSV and a sample table with `sample` and `condition` columns are required. There must be at least two samples per compared group, a full-rank design and at least two residual degrees of freedom. `--from-run` accepts a verified `count_matrix` and `sample_table` handoff.

## Run

`Rscript scripts/run_limma_voom.R --counts counts.csv --samples samples.csv --reference control --target treated --outdir run`

### Via MCP

Select `limma-voom` with those same arguments. `--help` lists every option; the ones that matter most are `--interface`, `--sample-weights`, `--min-effect-fc` and `--display-lfc-filter`. See `references/parameters.md` for all flag defaults and fixed arguments.

## What gets produced

`tables/feature_table.csv` is the complete canonical table; `tables/limma_full.csv` has the full limma columns. `tables/direction_summary.csv` gives Down/NotSig/Up. `figures/volcano.*` and `figures/md.*` are the DE figures; `figures/voom_trend.*` (with `tables/voom_trend_points.csv`) is the voom mean-variance trend and `figures/mds.*` (with `tables/mds_coordinates.csv`) the sample MDS of filtered TMM log2 CPM (plotMDS, top 500, pairwise). `draft/methods_results.md` reports every setting of the actual run (edgeR version, filterByExpr thresholds used, TMM factors, interface and adaptive span, sample weights, eBayes/treat settings and prior df) and ends with figure legends. `qc/qc_results.csv`, `results/limma_results.json`, and `objects/handoff.json` record interpretation and provenance.

## Reading the results

BH adjusted P values test zero effect unless a minimum effect was prespecified with `--min-effect-fc`; that option invokes `treat`. A display-only filter never changes the full table or adjusted P values. The hand-off carries the MArrayLM fit, the EList with its precision weights, the voom log-CPM expression matrix, the sample table and a ranked list of moderated t (treat t with `--min-effect-fc`). See the report template.

## When a QC rule fires

`LV-01..LV-05` cover limited replication, too few retained features, invalid adjusted P values, nonfinite effects, and all-significant results. Input and design blockers stop fitting. See `references/qc-rules.md`.

## Known limitations

The `voomLmFit` call set is proposed for owner confirmation after the locked edgeR 4.10.5 help export. The legacy interface is only for reproduction. The sample weight switch uses the sample-specific variance model; grouped or covariate sample-weight models are pending a separate input contract.

## Reference files

`method-basis.md` records L1 evidence; `parameters.md` documents flags and fixed calls; `qc-rules.md` gives QC sources; `reporting-templates.md` is filled by the engine; `troubleshooting.md` maps typed errors to fixes.
