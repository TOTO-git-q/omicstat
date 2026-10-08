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
| `--cluster-col` | required | cluster column to name descriptively |
| `--marker-panel` | required | JSON type to genes, lineage, order and optional colour |
| `--label-map` | none | JSON cluster to panel name; unassigned clusters remain unresolved |
| `--unresolved-label` | required | explicit label for unassigned clusters |
| `--expression-layer` | required | log expression layer for descriptive panel means |
| `--top-n` | 15 | number of evidence genes per cluster |
| `--help` | none | show this help and exit |
