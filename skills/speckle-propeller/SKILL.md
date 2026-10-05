---
name: speckle-propeller
description: Wrap the official speckle-propeller workflow on clustered or annotated SCE, Seurat or AnnData; save native objects and native result tables.
---
# speckle-propeller

Input: `--input FILE --ecosystem bioconductor|seurat|scverse` or verified `--from-run DIR`; always name `--cluster-col`, required `--counts-layer` / `--logcounts-layer`, and `--source-assay` for Seurat. Conversion preserves cells, features, labels and embeddings. No front-end module is called.

Run `Rscript scripts/run_speckle_propeller.R --help` for the complete option list. Package argument flags independently expose every wrapped formal through JSON; absent flags use locked defaults. See [options.md](references/options.md) for meanings and S0 extraction keys. | --sample-col | vignette sample | yes | sample_key | | --condition-col | vignette group | yes | group_key | Transform: logit|asin; locked logit default, vignette demonstrates both. `--prop-trend false` / `--prop-robust true` are locked defaults. More than two groups invokes ANOVA; two groups invokes the package t-test. A paired/covariate-specific analysis is outside this simple propeller wrapper and requires a separate design-aware workflow.

Before choosing **any required or judgement option listed in options.md**, query `reference_advise(module="speckle-propeller", ...)` and `reference_search` using its parameter key; when nothing is curated, show the official vignette example and ask the user. Reference evidence informs choices; it does not replace package defaults.

Outputs: `objects/native.rds` (package result), `objects/sce.rds` and verified neutral handoff, native-column CSV tables, suite-style PNG/PDF figures and figure specs, QC, provenance and short Methods with actual function options. Samples are replicates for differential analyses. Retain all native p-values; display thresholds do not replace the full tables.

Python front end feeding a neutral R backend preserves the upstream ecosystem and raises informational `OS_ECOSYSTEM_CROSSING` QC. See S3_REQUEST for current execution limitations and proposed routing. No S3 acceptance or installation is performed here.

`omicstat-r:2026.10.1` prebuilds the AnnData environment at `BASILISK_EXTERNAL_DIR=/opt/omicstat/basilisk`; non-root h5ad input works offline through the shared conversion contract. A custom environment without this prebuilt environment gives `OS_ENV_MISSING`; the runtime never downloads it.
