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
| `--gene-sets-provenance` | none | JSON path: provenance written by the download tool (source, name, version_or_release, download_time, urls, sha256, terms, terms_url, id_type, species); its sha256 must equal the run-time hash of the file |
| `--gene-sets-source` | none | text: source of the user file (e.g. KEGG REST, PanglaoDB, MSigDB); required without a provenance JSON, never guessed |
| `--gene-sets-version` | none | text: release or version of the user file; required without a provenance JSON, never guessed |
| `--gene-sets-id-type` | none | ENTREZID, SYMBOL, ENSEMBL: identifier type of the user file; required without a provenance JSON; must equal the analysis key type (no silent conversion) |
| `--gene-sets-species` | none | text: species of the user file; compared with the analysis species when that is known |
| `--gene-sets-name` | none | text: display name; otherwise the provenance name or the file name |
| `--gene-sets-terms` | none | text: terms of use, recorded in provenance and Methods; the user is responsible for them |
| `--feature-id-type` | none | ENTREZID, SYMBOL, ENSEMBL: identifier type of the analysed features; required with a user file and compared with its ID type |
