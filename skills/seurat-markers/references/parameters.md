# Parameters

| Flag | Default | Allowed / purpose | Source |
|---|---|---|---|
| --input | none | path: Raw counts for QC; chain-state Seurat RDS for other modules | locked formals / transport contract |
| --from-run | none | path: Verified upstream Seurat run directory | locked formals / transport contract |
| --outdir | required | path: Run output directory | user_required |
| --spec | none | path: Replay prior provenance/resolved_spec.json | locked formals / transport contract |
| --seed | 20260925 | int: Recorded RNG seed | locked formals / transport contract |
| --journal | nature | enum: Figure preset | locked formals / transport contract |
| --mode | all | enum: All cluster markers or specified identity contrast | locked formals / transport contract |
| --ident-1 | none | string: Identity numerator for contrast mode | locked formals / transport contract |
| --ident-2 | none | string: Identity denominator; absent compares all other cells | locked formals / transport contract |
| --min-pct | 0.01 | num: Minimum expression fraction screening | locked formals / transport contract |
| --logfc-threshold | 0.1 | num: Pretest screening threshold in log2 units; not a minimum effect test | locked formals / transport contract |
| --only-pos | true | enum: Return positive markers only; official PBMC vignette TRUE | locked formals / transport contract |
| --test | wilcox | enum: Native marker statistical test | locked formals / transport contract |
| --assay | none | string: Optional marker assay override; absent uses upstream assay | locked formals / transport contract |
| --return-thresh | 0.01 | num: FindAllMarkers raw P return threshold | locked formals / transport contract |
| --display-lfc-filter | 0 | num: Separate display-only absolute log2FC filter | locked formals / transport contract |
| --top-n | 10 | int: Genes in descriptive marker figures | locked formals / transport contract |
| --condition | none | string: Condition inference request; refused as pseudoreplication | locked formals / transport contract |

All fixed package arguments and their locked function defaults are recorded in scripts/calls_registry.json. Every result-affecting argument is explicit at its call site. --help lists transport flags. Seed 20260925 follows the builder contract.

## 待裁决
Scientific choices not settled by documentation are required inputs. Tutorial values are examples, never silently chosen.

## Advanced options

Each advanced flag takes a JSON scalar or array (e.g. `false`, `0.3`, `"cosine"`, `[0.1,8]`). Omit it to use the locked default recorded below; JSON `null` passes NULL. For infinite cutoffs use the JSON string `"Inf"` or `"-Inf"`. These are passed directly to Seurat, which validates them. Structural object/assay/reduction names belong to the workflow.

| Flag | Default | Required? | S0 key |
|---|---|---|---|
| --markers-min-diff-pct | none | no; effective locked default `-Inf` | none |
| --markers-only-pos | none | no; effective locked default `identical(a[["only-pos"]],"true")` | none |
| --markers-max-cells-per-ident | none | no; effective locked default `Inf` | none |
| --markers-latent-vars | none | no; effective locked default `NULL` | none |
| --markers-min-cells-feature | none | no; effective locked default `3` | none |
| --markers-min-cells-group | none | no; effective locked default `3` | none |
| --markers-base | none | no; effective locked default `2` | none |
| --markers-densify | none | no; effective locked default `FALSE` | none |
| --contrast-latent-vars | none | no; effective locked default `NULL` | none |
| --contrast-only-pos | none | no; effective locked default `identical(a[["only-pos"]],"true")` | none |
| --contrast-min-diff-pct | none | no; effective locked default `-Inf` | none |
| --contrast-max-cells-per-ident | none | no; effective locked default `Inf` | none |
| --contrast-min-cells-feature | none | no; effective locked default `3` | none |
| --contrast-min-cells-group | none | no; effective locked default `3` | none |
| --contrast-densify | none | no; effective locked default `FALSE` | none |

| Flag | Default | Meaning | Source |
|---|---|---|---|
| --features | none | JSON; effective `NULL` | locked assay/marker method |
| --group-by | none | JSON; effective `NULL` | locked assay/marker method |
| --node | none | JSON; effective `NULL` | locked assay/marker method |
| --slot | none | JSON; effective `"data"` | locked assay/marker method |
| --fc-name | none | JSON; effective `NULL` | locked assay/marker method |
| --subset-ident | none | JSON; effective `NULL` | locked assay/marker method |
| --fc-slot | none | JSON; effective `"data"` | locked assay/marker method |
| --pseudocount-use | none | JSON; effective `1` | locked assay/marker method |
| --recorrect-umi | none | JSON; effective `TRUE` | locked assay/marker method |

The Seurat object interface derives norm.method from NormalizeData command history; forwarding it duplicates the internal argument in the locked API. Reduction DE is outside this cluster-marker assay workflow.

Identity arguments accept comma-separated native labels (tutorial example ident-1=5, ident-2=0,3). A display LFC filter applies to the native avg_log2FC column; alternative effect naming/base/ROC results are retained without that filter.
