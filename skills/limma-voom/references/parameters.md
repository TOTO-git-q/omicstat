# limma-voom parameters

Flags are interpreted by the single entry specification. Every estimator parameter is explicit in `calls_registry.json` and `limma_voom_core.R`.

| Flag | Default | Allowed | Why |
|---|---|---|---|
| `--counts` | none | path | Raw integer counts only. |
| `--samples` | none | path | Matches every count column. |
| `--from-run` | none | path | Verified count and sample handoff. |
| `--outdir` | (required) | path | Run outputs. |
| `--spec` | none | path | Replay a resolved run. |
| `--sample-col` | sample | string | Sample identifier. |
| `--condition` | condition | string | Compared factor; may have more than two levels (other levels stay in the model). |
| `--reference` | (required) | string | Denominator. |
| `--target` | (required) | string | Numerator. |
| `--covariates` | none | string | Fixed-effect factors in the model. |
| `--interface` | voomLmFit | voomLmFit|legacy | voomLmFit is the locked-guide preset; legacy is a reproduction option (S1 P-1). |
| `--sample-weights` | off | switch | User enables after pre-specified QC (S1 P-3); named estimates are recorded in results JSON. |
| `--min-count` | 10 | int in [0, 100000] | filterByExpr cutoff (PACK D-V2). |
| `--alpha` | 0.05 | num in [0.000001, 0.5] | BH reporting cutoff (PACK D-08). |
| `--min-effect-fc` | 1 | num in [1, 100] | Linear FC, mapped to log2 for treat (S1 P-2). |
| `--display-lfc-filter` | 0 | num in [0, 20] | Post-test display only, default off (S1 P-2). |
| `--label-n` | 5 | int in [0, 30] | Figure labels only. |
| `--seed` | 20260925 | int | Recorded deterministic seed. |
| `--journal` | nature | nature|cell|science|generic | Shared figure preset. |

## Fixed calls

`filterByExpr` uses `min.total.count=15`, `large.n=10`, `min.prop=0.7`; `normLibSizes` uses TMM. `voomLmFit` explicitly sets all 17 arguments from locked edgeR formals, including `adaptive.span=TRUE`, `save.plot=TRUE` (trend figure only) and `keep.EList=TRUE`; the span it chooses is reported via `chooseLowessSpan(nrow, small.n=50, min.span=0.3, power=1/3)`, the call voomLmFit makes internally. Legacy `voom`/`voomWithQualityWeights` also use `save.plot=TRUE`. The sample MDS is `plotMDS(cpm(dge, log=TRUE, prior.count=2), top=500, gene.selection="pairwise", plot=FALSE)` (RNAseq123 workflow). `eBayes` uses `trend=FALSE`, `robust=FALSE`, `legacy=NULL`; optional `treat` receives both the user linear `fc` and its `log2` conversion. `topTable` uses `number=Inf`, BH, and no post hoc FC cutoff. See PACK S1 appendix P-1..P-3.
