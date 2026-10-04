---
name: cellchat-communication
description: Wrap the official cellchat-communication workflow on clustered or annotated SCE, Seurat or AnnData; save native objects and native result tables.
---
# cellchat-communication

Input: `--input FILE --ecosystem bioconductor|seurat|scverse` or verified `--from-run DIR`; always name `--cluster-col`, required `--counts-layer` / `--logcounts-layer`, and `--source-assay` for Seurat. Conversion preserves cells, features, labels and embeddings. No front-end module is called.

Run `Rscript scripts/run_cellchat_communication.R --help` for the complete option list. Package argument flags independently expose every wrapped formal through JSON; absent flags use locked defaults. See [options.md](references/options.md) for meanings and S0 extraction keys. | --db-species | human skin tutorial example human | yes | database | | --db-subset | Secreted Signaling tutorial example | yes | database | | --cluster-col | labels tutorial example | yes | group_by | | --ppi-rds | none; official optional projectData branch | no | raw_use | Probability estimator choices triMean|truncatedMean|thresholdedMean|median; trim=0.1 locked default. Minimum cells=10 and nboot=100 are package/tutorial defaults. Choose database species/subset deliberately; the tutorial warns about using the entire v2 database indiscriminately. Explicit seed flag controls permutations (suite seed default; tutorial example seed.use=1). Advanced spatial arguments are exposed but spatial/condition-comparison workflows require separate evidence and S3; the tested wrapper is a single RNA network.

Before choosing **any required or judgement option listed in options.md**, query `reference_advise(module="cellchat-communication", ...)` and `reference_search` using its parameter key; when nothing is curated, show the official vignette example and ask the user. Reference evidence informs choices; it does not replace package defaults.

Outputs: `objects/native.rds` (package result), `objects/sce.rds` and verified neutral handoff, native-column CSV tables, suite-style PNG/PDF figures and figure specs, QC, provenance and short Methods with actual function options. Samples are replicates for differential analyses. Retain all native p-values; display thresholds do not replace the full tables.

待裁决: Python front end feeding R backend keeps the upstream ecosystem and raises a QC crossing flag; owner label decision pending. See S3_REQUEST for current execution limitations and proposed routing. No S3 acceptance or installation is performed here.

The 2026.10.1 image includes pinned presto, so the native default `--genes-do-fast true` runs the fast Wilcoxon route. The explicit `--genes-do-fast false` standard Wilcoxon branch remains available; both are checked on the human-skin anchor. Runtime installation is unnecessary. The native `projectData` tutorial option is unavailable at this pin; projected expression is refused.

`omicstat-r:2026.10.1` prebuilds the AnnData environment at `BASILISK_EXTERNAL_DIR=/opt/omicstat/basilisk`; non-root h5ad input works offline through the shared conversion contract. A custom environment without this prebuilt environment gives `OS_ENV_MISSING`; the runtime never downloads it.
