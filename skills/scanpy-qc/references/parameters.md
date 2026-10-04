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
| `--mito-prefix` | `required` | string | explicit mitochondrial gene-name prefix |
| `--min-genes` | `required` | (1, 1000000) | inclusive lower detected-gene cutoff |
| `--max-genes` | `required` | (1, 1000000) | inclusive upper detected-gene cutoff |
| `--min-counts` | `required` | (1, 1000000000000.0) | inclusive lower library-count cutoff |
| `--max-counts` | `required` | (1, 1000000000000.0) | inclusive upper library-count cutoff |
| `--max-mito-percent` | `required` | (0, 100) | inclusive mitochondrial percentage ceiling |
| `--min-cells` | `required` | (1, 1000000) | minimum cells expressing each retained gene |
| `--doublet-mode` | `required` | skip, score, filter | prespecified doublet policy |
| `--expected-doublet-rate` | `none` | (1e-06, 0.999999) | expected doublet rate for scrublet; required unless skipped |
| `--doublet-threshold` | `none` | (0, 1) | explicit scrublet classification cutoff; required unless skipped |
| `--scrublet-pcs` | `30` | (2, 1000) | number of scrublet principal components |
| `--help` | `none` | bool | show this help and exit |

## Explicit package calls

| Function | Explicit arguments |
|---|---|
| `scanpy.pp.calculate_qc_metrics` | `adata`, `expr_type`, `var_type`, `qc_vars`, `percent_top`, `layer`, `use_raw`, `inplace`, `log1p`, `parallel` |
| `scanpy.pp.filter_cells` | `data`, `min_counts`, `min_genes`, `max_counts`, `max_genes`, `inplace`, `copy` |
| `scanpy.pp.filter_genes` | `data`, `min_counts`, `min_cells`, `max_counts`, `max_cells`, `inplace`, `copy` |
| `scanpy.pp.scrublet` | `adata`, `adata_sim`, `batch_key`, `sim_doublet_ratio`, `expected_doublet_rate`, `stdev_doublet_rate`, `synthetic_doublet_umi_subsampling`, `knn_dist_metric`, `normalize_variance`, `log_transform`, `mean_center`, `n_prin_comps`, `use_approx_neighbors`, `get_doublet_neighbor_parents`, `n_neighbors`, `threshold`, `verbose`, `copy`, `random_state` |

Every call expression is retained in calls_registry.json. Locked default-formal capture and drift checking remain mandatory; an API-doc URL is not a substitute for execution in the pinned image.
