---
name: slingshot-trajectory
description: Wrap the official slingshot-trajectory workflow on clustered or annotated SCE, Seurat or AnnData; save native objects and native result tables.
---
# slingshot-trajectory

Input: `--input FILE --ecosystem bioconductor|seurat|scverse` or verified `--from-run DIR`; always name `--cluster-col`, required `--counts-layer` / `--logcounts-layer`, and `--source-assay` for Seurat. Conversion preserves cells, features, labels and embeddings. No front-end module is called.

Run `Rscript scripts/run_slingshot_trajectory.R --help` for the complete option list. Package argument flags independently expose every wrapped formal through JSON; absent flags use locked defaults. See [options.md](references/options.md) for meanings and S0 extraction keys. | --reduced-dim | PCA/UMAP vignette example; use existing upstream embedding | yes | reduced_dim | | --start-cluster | NULL unsupervised default, or known early cluster (vignette 1) | yes | start_cluster | | --fit-gam | true, official downstream tradeSeq workflow | no | none | Choose the root from biological time/state; `auto` deliberately requests unsupervised orientation. Slingshot extend choices: y|n|pc1; dist.method slingshot|simple|scaled.full|scaled.diag|mnn; smoother smooth.spline|loess. nknots=6 is the locked tradeSeq default; additional flexibility can overfit. --gam-genes restricts genes; --gam-U adds covariates; --gam-control controls mgcv.

Before choosing **any required or judgement option listed in options.md**, query `reference_advise(module="slingshot-trajectory", ...)` and `reference_search` using its parameter key; when nothing is curated, show the official vignette example and ask the user. Reference evidence informs choices; it does not replace package defaults.

Outputs: `objects/native.rds` (package result), `objects/sce.rds` and verified neutral handoff, native-column CSV tables, suite-style PNG/PDF figures and figure specs, QC, provenance and short Methods with actual function options. Samples are replicates for differential analyses. Retain all native p-values; display thresholds do not replace the full tables.

待裁决: Python front end feeding R backend keeps the upstream ecosystem and raises a QC crossing flag; owner label decision pending. See S3_REQUEST for current execution limitations and proposed routing. No S3 acceptance or installation is performed here.

`omicstat-r:2026.10.1` prebuilds the AnnData environment at `BASILISK_EXTERNAL_DIR=/opt/omicstat/basilisk`; non-root h5ad input works offline through the shared conversion contract. A custom environment without this prebuilt environment gives `OS_ENV_MISSING`; the runtime never downloads it.
