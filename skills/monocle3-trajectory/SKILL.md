---
name: monocle3-trajectory
description: Wrap the official monocle3-trajectory workflow on clustered or annotated SCE, Seurat or AnnData; save native objects and native result tables.
---
# monocle3-trajectory

Input: `--input FILE --ecosystem bioconductor|seurat|scverse` or verified `--from-run DIR`; always name `--cluster-col`, required `--counts-layer` / `--logcounts-layer`, and `--source-assay` for Seurat. Conversion preserves cells, features, labels and embeddings. No front-end module is called.

Run `Rscript scripts/run_monocle3_trajectory.R --help` for the complete option list. Package argument flags independently expose every wrapped formal through JSON; absent flags use locked defaults. See [options.md](references/options.md) for meanings and S0 extraction keys. | --partition-col | official cluster_cells partitions copied upstream | yes | none | | --root-rationale | earliest developmental time in guide | yes | root_rationale | | --root-time-col / --root-time-value | embryo.time.bin / 130-170 guide example; alternative is --order-root-cells or --order-root-pr-nodes | conditional | root_rationale | | --graph-genes-file | all genes; explicit subset only | no | gene_filter | A root is a scientific judgement: select known early cells/states and explain it. Roots must cover each partition intended for traversal; unreachable partitions remain Inf. learn_graph close_loop true/use_partition true are locked defaults; --learn-learn-graph-control is the full JSON control list. graph_test neighbor_graph=principal_graph follows the differential guide (function default knn); k=25, Moran_I, greater, quasipoisson are locked defaults. This backend preserves UMAP/clusters/partitions. Preprocessing/alignment belongs in the supplied object, as demonstrated by the anchor fixture.

Before choosing **any required or judgement option listed in options.md**, query `reference_advise(module="monocle3-trajectory", ...)` and `reference_search` using its parameter key; when nothing is curated, show the official vignette example and ask the user. Reference evidence informs choices; it does not replace package defaults.

Outputs: `objects/native.rds` (package result), `objects/sce.rds` and verified neutral handoff, native-column CSV tables, suite-style PNG/PDF figures and figure specs, QC, provenance and short Methods with actual function options. Samples are replicates for differential analyses. Retain all native p-values; display thresholds do not replace the full tables.

Python front end feeding a neutral R backend preserves the upstream ecosystem and raises informational `OS_ECOSYSTEM_CROSSING` QC. See S3_REQUEST for current execution limitations and proposed routing. No S3 acceptance or installation is performed here.

`omicstat-r:2026.10.1` prebuilds the AnnData environment at `BASILISK_EXTERNAL_DIR=/opt/omicstat/basilisk`; non-root h5ad input works offline through the shared conversion contract. A custom environment without this prebuilt environment gives `OS_ENV_MISSING`; the runtime never downloads it.
