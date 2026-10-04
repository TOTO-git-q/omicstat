# Options and locked evidence

| option | locked default / vignette value | required? | S0 extraction parameter key |
|---|---|---|---|
| --input | none; local SCE RDS | no | none |
| --from-run | none; upstream single-cell run | no | none |
| --outdir | none; output directory | yes | none |
| --spec | none; resolved spec replay | no | none |
| --batch-col | none; batch metadata column; scientific batch definition | yes | batch_definition |
| --n-hvg | none; HVG number; correction vignette example 5000 | yes | subset_row |
| --n-pcs | none; fastMNN rank; locked default 50, explicit study choice | yes | fastmnn_d |
| --mnn-k | none; MNN neighbours; locked default 20 | yes | fastmnn_k |
| --umap-dims | none; corrected dimensions for UMAP | yes | umap_dims |
| --umap-neighbors | none; UMAP neighbours; locked default 15 | yes | none |
| --mixing-k | none; neighbours for descriptive batch purity | yes | none |
| --label-col | none; optional biological annotation | no | none |
| --cos-norm | "TRUE"; cosine normalization | no | cos_norm |
| --ndist | 3; MNN distance cutoff | no | ndist |
| --auto-merge | "FALSE"; automatically select merge order | no | auto_merge |
| --umap-min-dist | 0.01; uwot locked minimum distance | no | none |
| --norm-args | none; supplementary native named JSON options; omitted arguments retain locked defaults | no | norm_args |
| --variance-args | none; supplementary native named JSON options; omitted arguments retain locked defaults | no | none |
| --combine-args | none; supplementary native named JSON options; omitted arguments retain locked defaults | no | none |
| --hvg-args | none; supplementary native named JSON options; omitted arguments retain locked defaults | no | none |
| --mnn-args | none; supplementary native named JSON options; omitted arguments retain locked defaults | no | none |
| --pca-args | none; supplementary native named JSON options; omitted arguments retain locked defaults | no | none |
| --umap-args | none; supplementary native named JSON options; omitted arguments retain locked defaults | no | none |
| --seed | 101; explicit random seed | no | none |
| --journal | "nature"; figure preset | no | none |

Supplementary named JSON files expose every native argument, including delegated arguments. Omitted keys keep locked defaults; primary CLI options take precedence. calls_registry.json records container-read defaults. Every scientific choice must be informed by reference_advise and reference_search; absent curated evidence, show the official example and ask the user.
