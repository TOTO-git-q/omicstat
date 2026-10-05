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
| `--cluster-col` | `required` | string | observed cluster column |
| `--expression-layer` | `required` | string | natural-log1p normalized expression layer; use X explicitly for .X |
| `--purpose` | `required` | cluster-description, condition-inference | must declare descriptive use; condition-inference is refused |
| `--test` | `"t-test"` | t-test, t-test_overestim_var, wilcoxon | locked API test family; t-test is the package default |
| `--top-n` | `5` | (1, 100) | genes per cluster in native score order without adjusted-P filtering; full results retained |
| `--help` | `none` | bool | show this help and exit |

## Explicit package calls

| Function | Explicit arguments |
|---|---|
| `scanpy.tl.rank_genes_groups` | `adata`, `groupby`, `mask_var`, `use_raw`, `groups`, `reference`, `n_genes`, `rankby_abs`, `pts`, `key_added`, `copy`, `method`, `corr_method`, `tie_correct`, `layer` |

Every call expression is retained in calls_registry.json. Locked default-formal capture and drift checking remain mandatory; an API-doc URL is not a substitute for execution in the pinned image.
