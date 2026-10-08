# Display and representation options

| Flag | Default | Meaning |
|---|---|---|
| `--colour-registry` | none | seeded figure colour registry JSON |
| `--cell-list` | none | explicit display-only cell selection; CSV cell column or one ID per line |
| `--display-max-per-group` | none | embedding drawing cap only; analysis objects and tables retain all cells |
| `--label-placement` | median | embedding label coordinates; largest-island requires explicit DBSCAN parameters |
| `--label-island-eps` | none | DBSCAN eps in embedding units for largest-island labels |
| `--label-island-min-samples` | none | DBSCAN min_samples for largest-island labels |
| `--label-style` | plain | embedding label rendering; halo adds a white outline and label spacing (display only) |
| `--latent-from-run` | none | reuse matched or subset cells from an earlier scvi-integrate run; no training |
| `--leiden-resolution` | none | optional explicit Leiden resolution on scvi_neighbors |
| `--scvi-cluster-col` | none | new column for optional scVI-graph Leiden; requires leiden-resolution |

These optional choices require reference_advise first. Explicit cell-list subsetting marks the object display_only; a display-max-per-group cap changes drawing only. Largest-island labels require both density parameters.

Latent reuse retains the existing integration input contract (batch and cluster columns, raw counts, an upstream uncorrected graph and at least two batches). The existing CLI still requires max-epochs, but no epochs run and model-construction/training options are inactive on this path; the reuse Methods and caption state this explicitly.
