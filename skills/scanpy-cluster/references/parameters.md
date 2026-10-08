# Parameters

Generated from the entry SPEC and explicit calls registry. Do not edit table cells by hand.

Policy: function defaults from the locked version; official tutorial departures are named below. Scientific choices without a package recommendation are required. No literature-majority claim is made.

| Flag | Default | Allowed | Meaning |
|---|---|---|---|
| `--input` | `none` | path | local AnnData .h5ad file; never downloaded |
| `--from-run` | `none` | path | verified upstream run; exclusive with --input |
| `--upstream-object` | `none` | string | name of the upstream AnnData when more than one exists |
| `--outdir` | `required` | path | new output directory |
| `--spec` | `none` | path | replay provenance/resolved_spec.json |
| `--study-contract` | `none` | path | local StudyContract JSON; must match the upstream hash |
| `--species` | `required` | string | declared organism; not inferred from identifiers |
| `--annotation` | `required` | string | declared feature annotation release |
| `--sample-col` | `required` | string | obs column identifying biological samples |
| `--counts-layer` | `required` | string | raw integer count layer; use X explicitly for .X |
| `--seed` | `20260925` | (0, 2147483647) | fixed random seed |
| `--journal` | `"nature"` | nature, cell, science, generic | shared R figure preset |
| `--n-hvg` | `required` | (3, 100000) | prespecified highly variable gene count; tutorial examples are not defaults |
| `--n-pcs` | `required` | (2, 1000) | prespecified PCA dimension |
| `--n-neighbors` | `required` | (2, 1000) | prespecified number of neighbors |
| `--resolution` | `required` | (0.0001, 100) | prespecified Leiden resolution |
| `--cluster-col` | `"cluster"` | string | output cluster metadata column |
| `--target-sum` | `none` | (1, 1000000000000.0) | normalize_total target; omitted means locked API median-library behavior |
| `--hvg-batch-col` | `none` | string | optional batch column for batch-aware HVG selection |
| `--scale-max` | `none` | (1e-06, 1000) | optional display-independent clipping after scaling; omitted means no clipping |
| `--min-dist` | `0.5` | (0, 1) | UMAP minimum distance |
| `--help` | `none` | bool | show this help and exit |

## Explicit package calls

| Function | Explicit arguments |
|---|---|
| `scanpy.pp.normalize_total` | `adata`, `copy`, `exclude_highly_expressed`, `inplace`, `key_added`, `layer`, `max_fraction`, `obsm`, `target_sum` |
| `scanpy.pp.log1p` | `base`, `chunk_size`, `chunked`, `copy`, `data`, `layer`, `obsm` |
| `scanpy.pp.highly_variable_genes` | `adata`, `batch_key`, `check_values`, `filter_unexpressed_genes`, `flavor`, `inplace`, `layer`, `max_disp`, `max_mean`, `min_disp`, `min_mean`, `n_bins`, `n_top_genes`, `span`, `subset` |
| `scanpy.pp.scale` | `copy`, `data`, `layer`, `mask_obs`, `max_value`, `obsm`, `zero_center` |
| `scanpy.pp.pca` | `chunk_size`, `chunked`, `copy`, `data`, `dtype`, `key_added`, `layer`, `mask_var`, `n_comps`, `obsm`, `random_state`, `return_info`, `svd_solver`, `use_highly_variable`, `zero_center` |
| `scanpy.pp.neighbors` | `adata`, `copy`, `distances`, `key_added`, `knn`, `method`, `metric`, `metric_kwds`, `n_neighbors`, `n_pcs`, `random_state`, `transformer`, `use_rep` |
| `scanpy.tl.leiden` | `adata`, `adjacency`, `copy`, `directed`, `flavor`, `key_added`, `n_iterations`, `neighbors_key`, `obsp`, `partition_type`, `random_state`, `resolution`, `restrict_to`, `use_weights` |
| `scanpy.tl.umap` | `a`, `adata`, `alpha`, `b`, `copy`, `gamma`, `init_pos`, `key_added`, `maxiter`, `method`, `min_dist`, `n_components`, `negative_sample_rate`, `neighbors_key`, `random_state`, `spread` |

Every call expression is retained in calls_registry.json. Locked default-formal capture and drift checking remain mandatory; an API-doc URL is not a substitute for execution in the pinned image.

With `--use-rep`, PCA-specific settings are inactive, while normalization/HVG diagnostics remain. Tables `representation_scores.csv` and `representation_variance.csv` describe supplied coordinates and their variance fractions, not PCA explained variance. The default PCA tables and guards are unchanged.
