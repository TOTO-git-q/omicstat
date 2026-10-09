---
name: aucell-score
description: >
  Run aucell-score using the locked official community workflow and save native results, CSV tables, diagnostic figures and SCE handoff. Triggers: aucell-score, SingleCellExperiment, 单细胞. For condition inference use muscat-pseudobulk; for GSVA use gsva-score.
---
# aucell-score
## Input and run
Run `Rscript scripts/run_aucell_score.R --help` in omicstat-r:2026.10.1. Supply a local SCE RDS or `--from-run` upstream with normalized logcounts. Bioconductor front ends require scater-qc state; scoring accepts explicit conversion through convert.R. Native errors are retained in the engine log.
## Options
[options.md](references/options.md) lists every CLI option, locked values, official examples and S0 parameter keys. Supplementary JSON options pass directly to package functions. All seeds are explicit. `--spec` replays resolved options.
AUCell provides per-cell gene-set activity on single-cell objects. Sample-level scores from bulk or pseudobulk matrices use gsva-score. Neither route is a suite standard. No thresholds or active/inactive assignments are inferred. Supply an offline `--sets-file` plus `--sets-source`, `--sets-licence` and `--accept-licence user-permitted`; the licensed bundled GMT is only the smoke fixture. KEGG, CADD, PanglaoDB and DepMap are forbidden. Normalized SCE or explicit convert.R Seurat/AnnData conversion is supported; gene identifiers must match.
## Scientific choices and reference service
Before choosing `--cluster-col`, call `reference_advise(module="aucell-score", ...)` and `reference_search` for published practice. If nothing is curated, show the locked vignette example and ask the user. group metadata for score distributions; scientific grouping choice.
Before choosing `--assay`, call `reference_advise(module="aucell-score", ...)` and `reference_search` for published practice. If nothing is curated, show the locked vignette example and ask the user. expression assay counts or logcounts; rankings are monotonic-transform invariant except ties.
Before choosing `--auc-max-rank`, call `reference_advise(module="aucell-score", ...)` and `reference_search` for published practice. If nothing is curated, show the locked vignette example and ask the user. rank window; native default ceiling(0.05 * genes); check detected-gene distribution.
Before choosing `--norm-auc`, call `reference_advise(module="aucell-score", ...)` and `reference_search` for published practice. If nothing is curated, show the locked vignette example and ask the user. native AUC normalization.
Before choosing `--keep-zeroes-as-na`, call `reference_advise(module="aucell-score", ...)` and `reference_search` for published practice. If nothing is curated, show the locked vignette example and ask the user. native zero handling.

## Outputs and interpretation
Native RDS objects in objects/, full native CSV tables in tables/, suite PNG/PDF/figure_spec files in figures/, captured warnings in qc/, actual package versions, functions and option values in draft/methods_results.md, provenance/resolved_spec.json, and objects/handoff.json. Read warning logs before interpreting results. Figures are descriptive.
## 待裁决 / limitations
AUCell provides per-cell gene-set activity on single-cell objects. Sample-level scores from bulk or pseudobulk matrices use gsva-score. Neither route is a suite standard. No thresholds or active/inactive assignments are inferred. Supply an offline `--sets-file` plus `--sets-source`, `--sets-licence` and `--accept-licence user-permitted`; the licensed bundled GMT is only the smoke fixture. KEGG, CADD, PanglaoDB and DepMap are forbidden. Normalized SCE or explicit convert.R Seurat/AnnData conversion is supported; gene identifiers must match.
S2 build awaits independent S3. No acceptance or installation is claimed.
Explicit Seurat conversion inherits convert.R restrictions: feature names containing `_` or `|` are refused because Seurat would rename them. Declare compatible identifiers upstream; this module never silently renames genes. `omicstat-r:2026.10.1` provides the prebuilt zellkonverter/basilisk environment at `/opt/omicstat/basilisk`, so non-root h5ad conversion works offline; custom environments without it raise OS_ENV_MISSING.

Before choosing `--sets-file` and its source/licence declaration, consult `reference_advise` and `reference_search`; confirm compatible identifiers and user permission, and ask the user if the intended collection is unspecified.

## User-supplied gene sets

omicstat never bundles or downloads KEGG, PanglaoDB, MSigDB or similar gene sets. A local file that the user obtained (for example with the web app's public-data tool, or KEGG pathways from the KEGG REST API under its academic terms) runs through `--sets-file` declared with `--gene-sets-provenance` (or `--gene-sets-version` and `--gene-sets-id-type`; `--sets-source` is the source), using the same `GSEABase::getGmt` and AUCell calls. Give `--gene-sets-provenance <json>` (written by the download tool), or without it `--gene-sets-source`, `--gene-sets-version` and `--gene-sets-id-type` explicitly: these are never guessed. Optional: `--gene-sets-species`, `--gene-sets-name`, `--gene-sets-terms`. The analysis key type is `--feature-id-type`.

`Rscript scripts/run_aucell_score.R --from-run sce_run --cluster-col cluster --assay counts --sets-file panglao_markers.gmt --sets-source PanglaoDB --sets-licence "PanglaoDB terms" --accept-licence user-permitted --gene-sets-provenance panglao.provenance.json --feature-id-type SYMBOL --outdir run`

The file's SHA-256 is computed at run time and must equal the provenance `sha256` (`OS_REFDATA_MISMATCH` otherwise). A GMT must be tab-separated with a term ID, a description and at least one gene per line (`OS_INVALID_INPUT`). The gene-set identifier type must equal the analysis key type; identifiers are never converted (`OS_GENE_SET_ID_MISMATCH`). Species is compared with not declared by the Bioconductor chain, so only the record is kept (`OS_GENE_SET_SPECIES_MISMATCH`). Fewer than 10% of the unique set genes present in the analysed features is refused as a probable identifier error (`OS_GENE_SET_LOW_OVERLAP`). The KEGG term-ID exclusion applies to bundled/registered collections only, never to user files. The record (name, source, release, retrieval time, URLs, terms, ID type, species, SHA-256, overlap, "user-supplied, not bundled with omicstat") is written to `provenance/user_gene_sets.json` and `provenance/provenance.json`, and one Methods sentence states it. The user is responsible for the terms of use of the file.
