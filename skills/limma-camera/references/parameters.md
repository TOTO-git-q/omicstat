# Parameters

| Flag | Default | Allowed | Why |
|---|---|---|---|
| `--input` | none | expression CSV | Continuous expression, feature_id first, samples as columns. |
| `--ranked-list` | none | ranked CSV | Exact feature_id,symbol,score handoff; cameraPR only. |
| `--from-run` | none | upstream run | A limma-voom / limma-array / limma-dupcor run (its EList E + weights, fitted design and tested coefficient are used unchanged), or a typed expression_matrix / ranked_list handoff. Batch-corrected objects and corrected lineages are refused. |
| `--upstream-object` | none | object name | Select one input object; from a limma run `elist` (default) or `ranked_list` (cameraPR with its metadata). |
| `--outdir` | required | path | Run output. |
| `--spec` | none | prior spec | Replay resolved parameters. |
| `--question` | required | competitive, self-contained | Set the scientific null before testing. |
| `--self-contained-method` | none | fry, roast, mroast | Explicit one-method choice. |
| `--set-id` | none | registered term | roast tests one set. |
| `--collection` | msigdb_collections | registered ID | Offline SHA-256 checked collection; unresolved default refuses. |
| `--gene-sets` | none | registered GMT | Required for a file-backed collection. |
| `--input-scale` | none | logcpm, vst, normalized_array | Required for a CSV or non-limma expression input (reported in Methods); a limma upstream states its own scale. |
| `--samples` | none | sample CSV | Expression design. |
| `--sample-col` | sample | column | Sample IDs. |
| `--group-col` | condition | column | Two-group contrast. |
| `--reference` | none | group | Reference level. |
| `--target` | none | group | Target level. |
| `--covariates` | none | comma-separated columns | Factor terms after group in design. |
| `--weights` | none | positive matrix CSV | Optional voom precision weights. |
| `--block-col` | none | column | Repeated unit for self-contained route only. |
| `--correlation` | none | -0.99 to 0.99 | Paired prespecified/upstream within-block correlation. |
| `--acknowledge-block-ignored` | off | switch | camera on a limma-dupcor upstream: acknowledge that camera cannot model the block (otherwise `OS_UNSUPPORTED_DESIGN`). |
| `--rank-metric` | wald_stat | wald_stat, moderated_t, other | Names the score statistic of a ranked file without omicstat metadata. |
| `--metric-name` | none | text | Required for other score. |
| `--direction` | none | text | Positive-score meaning of a ranked file without omicstat metadata; refused when the metadata states it. |
| `--alpha` | 0.05 | 0.000001 to 0.5 | BH reporting threshold only. |
| `--nrot` | 9999 | 1999 or >=9999 | Publication rotations; 1999 is development-only. |
| `--seed` | 20260925 | integer | Recorded seed for reproducible rotations. |
| `--journal` | nature | nature, cell, science, generic | Figure preset. |

`camera`/`cameraPR` explicitly set `inter.gene.cor=0.01`, `use.ranks=FALSE`, and `directional=TRUE`. Correlation 0.01 is prespecified, never estimated. `roast` and `mroast` explicitly use `set.statistic="mean"`, `approx.zscore=TRUE`, and `legacy=FALSE`; `mroast` sets `adjust.method="BH"` and `midp=TRUE`. The 1999-rotation development signature is flagged and cannot be cited as a publication result.

With a limma upstream the samples, design, coefficient, weights and block come from the upstream run: `--samples`, `--weights`, `--covariates`, `--block-col`, `--correlation`, `--sample-col` are refused and `--reference/--target/--group-col` must agree with it (`OS_CONFLICTING_PARAMETERS`); nothing is rebuilt. Barcode and MD figures use the upstream fit's moderated t; for a plain expression input a display-only `lmFit` + `eBayes(trend = FALSE, robust = FALSE)` on the same design/weights/block gives that statistic (never used by the gene-set test). The barcode worm is `tricubeMovingAverage(membership, span = 0.45, power = 3)` divided by the mean membership, as `barcodeplot` computes it.
