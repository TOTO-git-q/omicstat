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
| `--reference-run` | required | fixed reference run with UMAP and neighbors |
| `--query-run` | none | query run; optionally select explicit cell-list |
| `--label-col` | required | existing descriptive label for reference-neighbor agreement |
| `--neighbors-key` | required | reference uns neighbor graph key |
| `--n-neighbors` | required | reference neighbors used for ingest and label agreement |
| `--queue-size` | 5 | locked ingest nearest-neighbor query queue size |
| `--epsilon` | 0.1 | locked ingest nearest-neighbor query epsilon |
| `--help` | none | show this help and exit |

Reference graphs must explicitly record `use_rep` for an existing obsm representation in both objects. Both representations must come from the same basis/model; independently fitted PCA or scVI spaces are unsuitable. Automatic PCA/raw-X graph fallback is refused rather than guessing the space used for agreement diagnostics. Suite cluster/scVI graphs explicitly record the representation.
