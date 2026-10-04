---
name: deseq2-lrt
description: >
  Run a DESeq2 likelihood ratio test of nested bulk RNA-seq count models and produce a joint-test table, displays and filled Methods draft. Triggers: LRT, multi-group differential expression, time course, interaction, 似然比检验, 时间序列, 多组比较. Use for an explicit full/reduced design. NOT for one prespecified two-group contrast (use deseq2-wald); NOT for sample quality assessment (use deseq2-qc); NOT for microarray data (use limma-array).
---
# deseq2-lrt

## When to use / when not
Use for a nested full and reduced design whose removed terms are tested jointly, including multi-level or interaction/time-course designs. Use deseq2-wald for a single Wald contrast and deseq2-qc for sample QC. The LRT P value does not test the one displayed log2 fold change.

## Input requirements
Raw nonnegative integer features-by-samples counts; matching sample table. The two one-sided formulas must be full rank and nested. Give `--min-samples` explicitly. Each full-design cell needs biological replicates. `--from-run` accepts deseq2-qc handoff; batch-corrected matrices are refused.

## Run
`Rscript scripts/run_deseq2_lrt.R --counts counts.tsv --samples samples.csv --full '~ strain + minute + strain:minute' --reduced '~ strain + minute' --group-col strain --time-col minute --min-samples 3 --outdir run`

`--spec` replays a resolved spec. `--pattern-clustering` is an explicit opt-in DEGreport route, requiring `--pattern-genes` and `--time-col`. Defaults and sources for every flag: references/parameters.md.

### Via MCP
Use `omicstat_run` with `module="deseq2-lrt"` and the same arguments, then `omicstat_read`. The entry script's `--help` is the typed flag list.

## What gets produced
`tables/feature_table.csv`, complete `tables/deseq2_lrt_results_full.csv`, normalized counts, VST matrix, size factors, results JSON with both formulas/tested terms/df/coefficient, QC, provenance, handoff and filled draft. A top heatmap is written when at least two features meet `padj < alpha`; a trajectory figure is also written when `--time-col` is given. Figures use the shared figure layer.

## Reading the results
`stat` is nonnegative LRT deviance, and `padj` measures joint significance. `log2fc` is one explicitly named or DESeq2-default coefficient; it is not the effect of the joint test. No fold-change cutoff is applied to LRT significance. For one effect, run a separately prespecified Wald contrast. See references/reporting-templates.md and method-basis.md.

## When a QC rule fires
Read `qc/qc_results.csv`. DL-01..03 block fitting and withhold the draft. DL-13 is an informational reminder on every completed run. Rule criteria and sources: references/qc-rules.md.

## Known limitations
Pattern clustering with `DEGreport::degPatterns` is exploratory and uses an explicit input-gene list and metadata fields. `--adjust` terms are checked only when named; the module does not infer the intended adjustment set. No LFC shrinkage or directional ranked list is produced for a joint LRT. A heatmap/trajectory needs at least two significant features.

## Reference files
- references/parameters.md: flag and package-call decisions
- references/method-basis.md: L1 and PACK evidence
- references/qc-rules.md: DL-01..DL-13
- references/reporting-templates.md: filled draft text
- references/troubleshooting.md: typed-error remedies

Optional --pattern-clustering (default off) requires --pattern-genes and --time-col; --pattern-group-col and --pattern-options expose the native DEGreport workflow. See references/parameters.md for all locked defaults and outputs. Query reference_advise and reference_search before gene-selection or clustering choices.
