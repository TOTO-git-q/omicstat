# Options and reference-service evidence keys

| option | locked default / vignette value | required? | S0 extraction parameter key |
|---|---|---|---|
| --input | none | no | none |
| --outdir | required | yes | none |
| --spec | none | no | none |
| --seed | 20260925 | no | none |
| --journal | nature | no | none |
| --input-format | 10x | no | none |
| --metadata | none | no | none |
| --sample | sample | no | none |
| --organism | required; example Homo_sapiens | yes | none |
| --feature-type | required; example symbol | yes | none |
| --mito-pattern | required; example ^MT- | yes | mito_pattern |
| --min-cells | required; example 3 | yes | min_cells |
| --create-min-features | required; example 200 | yes | min_features |
| --min-features | required; example 200 | yes | feature_lower |
| --max-features | required; example 2500 | yes | feature_upper |
| --min-counts | required; example 0 (explicit no lower UMI filter) | yes | count_lower |
| --max-counts | required; example 1e9 (explicit no practical upper UMI filter) | yes | count_upper |
| --max-mito | required; example 5 | yes | mito_upper |
| --create-names-field | locked 1; effective `1L` | no | none |
| --create-names-delim | locked "_"; effective `"_"` | no | none |
| --create-project | locked "CreateSeuratObject"; effective `"SeuratProject"` | no | none |
| --missing-mito | error | no | none |

Choose QC limits from per-sample feature/count/mitochondrial distributions and study biology; choose the mitochondrial pattern for the declared species and identifiers. All creation/retention thresholds are explicit; limits are recorded even when outside the axes. Missing mitochondrial features require explicit missing-mito=zero; this is appropriate only when the feature list lacks those genes, not evidence of mitochondrial quality.

Sources: locked PACK C/D and archived PBMC, Harmony Seurat, or cell-cycle tutorial. Advanced flags accept JSON values; package call defaults and the exact forwarded expressions are in calls_registry.json. Transport parameters are suite contracts. No literature counts determine defaults.
