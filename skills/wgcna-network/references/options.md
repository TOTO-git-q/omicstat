# Options (locked WGCNA 1.74)

| option | locked default / vignette value | required? | S0 extraction parameter key |
|---|---|---|---|
| --gsg-weights | `NULL` | no | none |
| --gsg-min-fraction | `1/2` | no | none |
| --gsg-min-nsamples | `4` | no | none |
| --gsg-min-ngenes | `4` | no | none |
| --gsg-tol | `NULL` | no | none |
| --gsg-min-relative-weight | `0.1` | no | none |
| --soft-weights | `NULL` | no | none |
| --soft-rsquared-cut | `0.85` | no | none |
| --soft-remove-first | `FALSE` | no | none |
| --soft-n-breaks | `10` | no | none |
| --soft-cor-fnc | `WGCNA::cor` | no | none |
| --soft-cor-options | `list(use = "p")` | no | none |
| --network-cor-type | `"pearson"` | no | none |
| --network-max-poutliers | `1` | no | none |
| --network-quick-cor | `0` | no | none |
| --network-pearson-fallback | `"individual"` | no | none |
| --network-cosine-correlation | `FALSE` | no | none |
| --network-tomdenom | `"min"` | no | none |
| --network-replace-missing-adjacencies | `FALSE` | no | none |
| --network-suppress-tomfor-zero-adjacencies | `FALSE` | no | none |
| --network-suppress-negative-tom | `FALSE` | no | none |
| --network-detect-cut-height | `0.995` | no | none |
| --network-pam-stage | `TRUE` | no | none |
| --network-min-core-kme | `0.5` | no | none |
| --network-min-core-kmesize | `minSize/3` | no | none |
| --network-min-kmeto-stay | `0.3` | no | none |
| --network-impute | `TRUE` | no | none |
| --eigengene-impute | `TRUE` | no | none |
| --eigengene-n-pc | `1` | no | none |
| --eigengene-align | `"along average"` | no | none |
| --eigengene-exclude-grey | `FALSE` | no | none |
| --eigengene-sub-hubs | `TRUE` | no | none |
| --eigengene-scale | `TRUE` | no | none |
| --cor-use | `"p"` (tutorial pairwise correlation) | no | none |
| --cor-method | `"pearson"` | no | none |
| --cor-weights-x | `NULL` | no | none |
| --cor-weights-y | `NULL` | no | none |
| --cor-cosine | `FALSE` | no | none |
| --cor-cosine-x | `FALSE` | no | none |
| --cor-cosine-y | `FALSE` | no | none |
| --cor-quick | `0` | no | none |
| --trait-p-adjust | BH | no | none |
| --input | none | no | none |
| --from-run | none | no | none |
| --upstream-object | "expression_matrix" | no | none |
| --outdir | required | yes | none |
| --spec | none | no | none |
| --input-scale | required | yes | input_expression |
| --preprocessing | required | yes | none |
| --outlier-rule | required | yes | sample_outlier_rule |
| --samples | required | yes | none |
| --traits | required | yes | none |
| --power | required | yes | soft_power |
| --power-reason | required | yes | none |
| --powers | "1,2,3,4,5,6,7,8,9,10,12,14,16,18,20" | no | none |
| --network-type | "unsigned" | no | network_type |
| --tom-type | "signed" | no | none |
| --min-module-size | none | no | min_module_size |
| --deep-split | 2L | no | deep_split |
| --merge-height | 0.15 | no | merge_cut_height |
| --max-block-size | 5000L | no | none |
| --pam-respects-dendro | "true" | no | none |
| --reassign-threshold | 0.000001 | no | none |
| --seed | 20260925L | no | none |
| --journal | "nature" | no | none |

Tutorial part 2 examples: power 6; unsigned TOM; minModuleSize 30; deepSplit 2; mergeCutHeight 0.25; reassignThreshold 0; pamRespectsDendro FALSE. These examples do not establish a general optimum.

New native controls accept JSON values; matrix/list values can use `{ "rds": "/path/file.rds" }`. `--soft-cor-fnc` takes package::function, e.g. WGCNA::cor or WGCNA::bicor; set matching --soft-cor-options explicitly. The trait p.adjust summary covers all module-trait tests together and preserves native unadjusted p_value.

All resolved native controls are written in draft/native_parameters.md (supplementary Methods) and provenance; the main Methods and trait caption name the actual correlation and p.adjust method. cosineX/cosineY inherit cosine when omitted, as in locked formals.
