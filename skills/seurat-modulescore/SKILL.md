---
name: seurat-modulescore
description: >
  Run seurat-modulescore and produce audited single-cell tables, figures and a Methods/Results draft.
  Use for Seurat modulescore, 单细胞, 质控, 聚类, 整合, marker or 模块打分 as appropriate.
  NOT for condition-level differential inference (use muscat-pseudobulk) or a Bioconductor front end (use scater-qc or scran-cluster).
---
# seurat-modulescore

## When to use / when not
Use for the modulescore stage of a Seurat chain. Keep one front-end ecosystem. Condition inference uses muscat-pseudobulk; cell proportions use speckle-propeller.

## Input requirements
QC receives raw integer counts; other modules receive --from-run from seurat-qc / seurat-cluster as applicable, or an unmodified Seurat RDS carrying the same chain state. Cell/sample identifiers must match exactly.

## Run
```bash
Rscript scripts/run_seurat_modulescore.R --help
```
Supply --input or the supported --from-run and --outdir plus required scientific parameters listed in references/parameters.md. --spec replays resolved parameters; explicit flags override it. MCP registration awaits independent S3.

## What gets produced
Tables under tables/, standard PDF/PNG figures with captions and figure_spec, draft/methods_results.md, qc/qc_results.csv, qc/engine_warnings.csv, results/results.json, provenance/resolved_spec.json and objects/handoff.json with hashed Seurat, cell metadata and colour registry.

## Reading the results
Read QC and the full audited tables first. Descriptive cell-level results do not establish condition differences. Every threshold and input state is recorded in the draft and provenance.

## When a QC rule fires
Rules OSS-01..03 are sourced in references/qc-rules.md. Input blockers stop before a draft.

## Known limitations
Independent S3 acceptance is pending. No automatic doublet removal, annotation, gene synonym lookup, gene-set thresholding or condition inference. Scientific thresholds and dimensions need explicit prespecification. Spatial scoring applicability is an owner evidence question, not an inferred suite policy.

## User-supplied gene sets

omicstat never bundles or downloads KEGG, PanglaoDB, MSigDB or similar gene sets. A local file that the user obtained (for example with the web app's public-data tool, or KEGG pathways from the KEGG REST API under its academic terms) runs through `--gene-sets` declared with `--gene-sets-provenance` (or `--gene-sets-source`, `--gene-sets-version` and `--gene-sets-id-type`), using the same `Seurat::AddModuleScore` call. Give `--gene-sets-provenance <json>` (written by the download tool), or without it `--gene-sets-source`, `--gene-sets-version` and `--gene-sets-id-type` explicitly: these are never guessed. Optional: `--gene-sets-species`, `--gene-sets-name`, `--gene-sets-terms`. The analysis key type is `--feature-id-type`.

`Rscript scripts/run_seurat_modulescore.R --from-run cluster_run --gene-sets panglao_markers.gmt --set-organism human --gene-sets-provenance panglao.provenance.json --feature-id-type SYMBOL --outdir run`

The file's SHA-256 is computed at run time and must equal the provenance `sha256` (`OS_REFDATA_MISMATCH` otherwise). A GMT must be tab-separated with a term ID, a description and at least one gene per line (`OS_INVALID_INPUT`). The gene-set identifier type must equal the analysis key type; identifiers are never converted (`OS_GENE_SET_ID_MISMATCH`). Species is compared with the chain organism (`--set-organism` must also match it) (`OS_GENE_SET_SPECIES_MISMATCH`). Fewer than 10% of the unique set genes present in the analysed features is refused as a probable identifier error (`OS_GENE_SET_LOW_OVERLAP`). The KEGG term-ID exclusion applies to bundled/registered collections only, never to user files. The record (name, source, release, retrieval time, URLs, terms, ID type, species, SHA-256, overlap, "user-supplied, not bundled with omicstat") is written to `provenance/user_gene_sets.json` and `provenance/provenance.json`, and one Methods sentence states it. The user is responsible for the terms of use of the file.

## Reference files
See references/method-basis.md, parameters.md, qc-rules.md, reporting-templates.md and troubleshooting.md.

## Choosing options / 待裁决

Provide an offline GMT with set name, source/version and membership for the declared organism. KEGG, CADD, PanglaoDB and DepMap collections are refused, including declarations in the GMT source column. The tutorial uses cc.genes, not cc.genes.updated.2019; do not substitute a list silently. nbin groups genes by mean expression; ctrl selects controls per member. Use pool only with a justified background, assay/slot consistent with the supplied gene program, and k=true only with a native DoKMeans object. Raw scores are relative to matched controls; there is no universal zero cutoff or cross-set scale. The direct function default ctrl=100 differs from the CellCycleScoring wrapper ctrl=min(lengths(sets))=43.

Before choosing `--gene-sets`, call `reference_advise(module='seurat-modulescore', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--set-organism`, call `reference_advise(module='seurat-modulescore', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--nbin`, call `reference_advise(module='seurat-modulescore', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--ctrl`, call `reference_advise(module='seurat-modulescore', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--pool`, call `reference_advise(module='seurat-modulescore', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--assay`, call `reference_advise(module='seurat-modulescore', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--slot`, call `reference_advise(module='seurat-modulescore', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--name`, call `reference_advise(module='seurat-modulescore', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--k`, call `reference_advise(module='seurat-modulescore', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--kmeans-object`, call `reference_advise(module='seurat-modulescore', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.

See references/options.md for every option, locked defaults, tutorial examples and S0 parameter keys. Alternative native routes may need additional locked packages; package errors are captured.
