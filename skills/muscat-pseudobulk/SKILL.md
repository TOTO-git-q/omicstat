---
name: muscat-pseudobulk
description: Wrap the official muscat-pseudobulk workflow on clustered or annotated SCE, Seurat or AnnData; save native objects and native result tables.
---
# muscat-pseudobulk

Input: `--input FILE --ecosystem bioconductor|seurat|scverse` or verified `--from-run DIR`; always name `--cluster-col`, required `--counts-layer` / `--logcounts-layer`, and `--source-assay` for Seurat. Conversion preserves cells, features, labels and embeddings. No front-end module is called.

Run `Rscript scripts/run_muscat_pseudobulk.R --help` for the complete option list. Package argument flags independently expose every wrapped formal through JSON; absent flags use locked defaults. See [options.md](references/options.md) for meanings and S0 extraction keys. | --sample-col | vignette sample_id | yes | sample_key | | --condition-col | vignette group_id | yes | group_key | | --reference / --target | ctrl / stim vignette example | yes | contrast | Methods: edgeR|DESeq2|limma-trend|limma-voom|DD; filtering: both|genes|samples|none. Optional `--ds-design` is a JSON design matrix (rows must follow pseudobulk sample order); `--ds-contrast` and `--ds-coef` control the tested comparison. Default design is ~group_id; paired studies should supply a donor-adjusted design.

Before choosing **any required or judgement option listed in options.md**, query `reference_advise(module="muscat-pseudobulk", ...)` and `reference_search` using its parameter key; when nothing is curated, show the official vignette example and ask the user. Reference evidence informs choices; it does not replace package defaults.

Outputs: `objects/native.rds` (package result), `objects/sce.rds` and verified neutral handoff, native-column CSV tables, suite-style PNG/PDF figures and figure specs, QC, provenance and short Methods with actual function options. Samples are replicates for differential analyses. Retain all native p-values; display thresholds do not replace the full tables.

Python front end feeding a neutral R backend preserves the upstream ecosystem and raises informational `OS_ECOSYSTEM_CROSSING` QC. See S3_REQUEST for current execution limitations and proposed routing. No S3 acceptance or installation is performed here.

`omicstat-r:2026.10.1` prebuilds the AnnData environment at `BASILISK_EXTERNAL_DIR=/opt/omicstat/basilisk`; non-root h5ad input works offline through the shared conversion contract. A custom environment without this prebuilt environment gives `OS_ENV_MISSING`; the runtime never downloads it.

Replication is rechecked on every fitted cluster after native filtering. If a fitted model retains fewer than two biological samples in either compared condition, `OS_PSEUDOREPLICATION` withholds all inferential outputs.
