# limma-dupcor parameters

Block must be a described correlated unit with repeated samples. The design must be full rank with at least two residual degrees of freedom.

| Flag | Default | Allowed | Why |
|---|---|---|---|
| `--mode` | (required) | array|rna | RNA counts or normalized log2 array. |
| `--matrix` | none | path | Normalized array input. |
| `--counts` | none | path | Raw uncorrected RNA counts. |
| `--samples` | none | path | Align every sample. |
| `--from-run` | none | path | Verified upstream matrix and sample table. |
| `--outdir` | (required) | path | Run outputs. |
| `--spec` | none | path | Replay resolved run. |
| `--sample-col` | sample | string | Sample ID field. |
| `--condition` | condition | string | Compared factor. |
| `--reference` | (required) | string | Denominator level. |
| `--target` | (required) | string | Numerator level. |
| `--covariates` | none | string | Fixed effects. |
| `--block` | (required) | string | Correlated unit mapped to samples. |
| `--block-description` | (required) | string | Meaning of correlated unit in Methods. |
| `--block-role` | correlated_unit | correlated_unit|technical_batch | Technical batch defaults to fixed effect. |
| `--block-rationale` | none | string | Explicit reason for special random batch. |
| `--platform` | none | agilent|other | Agilent preset or other explicit choices. |
| `--trend` | auto | auto|true|false | Array platform rule; RNA auto FALSE. |
| `--robust` | auto | auto|true|false | Array platform rule; RNA auto FALSE. |
| `--min-count` | 10 | int in [0, 100000] | RNA filterByExpr cutoff. |
| `--alpha` | 0.05 | num in [0.000001, 0.5] | BH reporting cutoff. |
| `--min-effect-fc` | 1 | num in [1, 100] | Linear FC sent to treat as log2. |
| `--display-lfc-filter` | 0 | num in [0, 20] | Post-test display only, off by default. |
| `--label-n` | 5 | int in [0, 30] | Figure labels. |
| `--seed` | 20260925 | int | Recorded seed. |
| `--journal` | nature | nature|cell|science|generic | Figure preset. |

## Fixed calls

`duplicateCorrelation(object, design, block, trim=0.15, ndups=2, spacing=1, weights=NULL)` estimates the consensus. In RNA mode it is called twice around two explicitly parameterized `voom` calls; in array mode once. `lmFit` receives the final consensus in `correlation`. Agilent array `eBayes` uses trend and robust TRUE; other arrays require explicit values; RNA auto uses FALSE/FALSE. `topTable` uses BH with no inferential post hoc FC gate. The round-2 `voom` uses `save.plot=TRUE` for the trend figure only. The sample MDS is `plotMDS(x, top=500, gene.selection="pairwise", plot=FALSE)` with x = `cpm(dge, log=TRUE, prior.count=2)` (RNA) or the supplied matrix (array). Optional `treat` uses declared linear FC and its log2 value. See PACK S1 appendix P-1..P-3.
