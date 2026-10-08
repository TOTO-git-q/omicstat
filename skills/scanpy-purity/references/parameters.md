# Parameters

| Flag | Default | Meaning |
|---|---|---|
| `--input` | none | local AnnData .h5ad file; never downloaded |
| `--from-run` | none | verified upstream run; exclusive with --input |
| `--upstream-object` | none | name of the upstream AnnData when more than one exists |
| `--outdir` | required | new output directory |
| `--spec` | none | replay provenance/resolved_spec.json |
| `--study-contract` | none | local StudyContract JSON; must match the upstream hash |
| `--species` | required | declared organism; not inferred from identifiers |
| `--annotation` | required | declared feature annotation release |
| `--sample-col` | required | obs column identifying biological samples |
| `--counts-layer` | required | raw integer count layer; use X explicitly for .X |
| `--seed` | 20260925 | fixed random seed |
| `--colour-registry` | none | seeded figure colour registry JSON |
| `--cell-list` | none | explicit display-only cell selection; CSV cell column or one ID per line |
| `--display-max-per-group` | none | embedding drawing cap only; analysis objects and tables retain all cells |
| `--label-placement` | median | embedding label coordinates; largest-island requires explicit DBSCAN parameters |
| `--label-island-eps` | none | DBSCAN eps in embedding units for largest-island labels |
| `--label-island-min-samples` | none | DBSCAN min_samples for largest-island labels |
| `--label-style` | plain | embedding label rendering; halo adds a white outline and label spacing (display only) |
| `--journal` | nature | shared R figure preset |
| `--label-col` | required | descriptive identity column |
| `--graph-key` | none | neighbors uns key or obsp connectivity key |
| `--use-rep` | none | obsm representation instead of an existing graph |
| `--n-neighbors` | none | required for representation purity |
| `--metric` | minkowski | native nearest-neighbor distance metric |
| `--purity-threshold` | required | prespecified graph/representation purity cut |
| `--embedding-neighbors` | required | UMAP neighbor count for display curation |
| `--embedding-purity-threshold` | required | prespecified UMAP-space purity cut |
| `--island-eps` | required | DBSCAN eps in UMAP coordinate units |
| `--island-min-samples` | required | DBSCAN minimum density count |
| `--island-min-size` | required | minimum retained island cell count |
| `--exclude-label` | none | explicit label to flag for exclusion, e.g. Unresolved |
| `--help` | none | show this help and exit |

`--graph-key` and `--use-rep` are mutually exclusive; choose exactly one neighbour definition. Conflicting choices are refused rather than silently ignored.
