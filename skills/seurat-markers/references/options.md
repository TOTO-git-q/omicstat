# Options and reference-service evidence keys

| option | locked default / vignette value | required? | S0 extraction parameter key |
|---|---|---|---|
| --markers-mean-fxn | NULL; package::function | no | none |
| --input | none | no | none |
| --from-run | none | no | none |
| --outdir | required | yes | none |
| --spec | none | no | none |
| --seed | 20260925 | no | none |
| --journal | nature | no | none |
| --mode | all; example all; tutorial contrast ident-1=2 versus others | no | none |
| --ident-1 | none | no | ident_1 |
| --ident-2 | none | no | ident_2 |
| --min-pct | 0.01 | no | min_pct |
| --logfc-threshold | 0.1 | no | logfc_threshold |
| --only-pos | true; example true | no | only_pos |
| --test | wilcox; example wilcox | no | test |
| --assay | none | no | assay |
| --return-thresh | 0.01 | no | return_thresh |
| --display-lfc-filter | 0 | no | logfc_filter |
| --top-n | 10 | no | none |
| --condition | none | no | none |
| --markers-min-diff-pct | locked -Inf; effective `-Inf` | no | min_diff_pct |
| --markers-only-pos | locked FALSE; effective `identical(a[["only-pos"]],"true")` | no | only_pos |
| --markers-max-cells-per-ident | locked Inf; effective `Inf` | no | max_cells_per_ident |
| --markers-latent-vars | locked NULL; effective `NULL` | no | latent_vars |
| --markers-min-cells-feature | locked 3; effective `3` | no | min_cells_feature |
| --markers-min-cells-group | locked 3; effective `3` | no | min_cells_group |
| --markers-base | locked 2; effective `2` | no | base |
| --markers-densify | locked FALSE; effective `FALSE` | no | none |
| --contrast-latent-vars | locked NULL; effective `NULL` | no | latent_vars |
| --contrast-only-pos | locked <absent>; effective `identical(a[["only-pos"]],"true")` | no | only_pos |
| --contrast-min-diff-pct | locked <absent>; effective `-Inf` | no | min_diff_pct |
| --contrast-max-cells-per-ident | locked <absent>; effective `Inf` | no | max_cells_per_ident |
| --contrast-min-cells-feature | locked <absent>; effective `3` | no | min_cells_feature |
| --contrast-min-cells-group | locked <absent>; effective `3` | no | min_cells_group |
| --contrast-densify | locked <absent>; effective `FALSE` | no | none |
| --features | locked <absent>; effective `NULL` | no | features |
| --group-by | locked NULL; effective `NULL` | no | group_by |
| --node | locked NULL; effective `NULL` | no | node |
| --slot | locked <absent>; effective `"data"` | no | slot |
| --fc-name | locked <absent>; effective `NULL` | no | none |
| --subset-ident | locked NULL; effective `NULL` | no | subset_ident |
| --fc-slot | locked <absent>; effective `"data"` | no | fc_slot |
| --pseudocount-use | locked <absent>; effective `1` | no | pseudocount_use |
| --recorrect-umi | locked <absent>; effective `TRUE` | no | recorrect_umi |

Use mode=all to describe each cluster against the remaining cells, or contrast with ident-1 and optional ident-2 for prespecified identities. Wilcoxon is the locked default; native alternatives are exposed. Screening min-pct/logfc-threshold changes genes tested, only-pos changes returned directions, and return-thresh changes returned rows. display-lfc-filter only changes the separate display table. Select an unintegrated RNA or appropriately prepared SCT assay; condition inference needs muscat-pseudobulk. Dotplot uses log1p(mean(expm1(data))) scaled per gene; heatmap shows cluster means of available native scale.data genes.

Sources: locked PACK C/D and archived PBMC, Harmony Seurat, or cell-cycle tutorial. Advanced flags accept JSON values; package call defaults and the exact forwarded expressions are in calls_registry.json. Transport parameters are suite contracts. No literature counts determine defaults.

`--markers-base` and `--markers-mean-fxn` apply to both all and contrast modes. Native effect-column naming is retained (e.g. avg_logFC for base exp(1)); a custom mean function defines its own effect scale.
