---
name: scanpy-annotate
description: "Name AnnData clusters descriptively using a user marker panel and label map. Triggers: marker-panel annotation, cluster naming, cell type naming."
---

# scanpy-annotate

## Inputs
Use a verified scverse run with raw counts and existing UMAP. Provide --from-run.

## Choosing judgement options
Before selecting thresholds, cell lists, marker panels, naming maps, neighbour counts, density parameters or display caps, call `reference_advise(module="scanpy-annotate", ...)` and `reference_search`. If evidence is absent, show the worked example and obtain a user decision. No data-derived cutoffs are defaults.

`--label-style halo` (default `plain`) only changes how embedding labels are drawn: a white halo behind each name and deterministic label spacing with a thin leader when a label moves. It is a rendering choice, not a scientific judgement, and needs no reference consultation.

## Run
`python scripts/run_scanpy_annotate.py --help`

## Outputs
Native AnnData, descriptive CSV tables, figure request, QC, handoff, provenance and Methods draft. Run the shared R renderer for publication figures.

## Scientific limits
Names are descriptive. Unresolved clusters stay in the object. Cleaning, balanced cell lists and ingest are display/curation only. Never use curated cells for proportions, pseudobulk, markers or DE: the handoff and embedded state record `display_only: true`. A figure drawing cap only samples figure data, never analysis objects or downstream tables.

## QC
Read triggered rules and their denominator before interpretation; locked version mismatches block the draft.

## Handoff
Stay in the scverse front end. Input hashes and chain state are checked. Retained-cell lists require explicit --cell-list on a rerun.

## User-supplied gene sets

omicstat never bundles or downloads KEGG, PanglaoDB, MSigDB or similar gene sets. A local file that the user obtained (for example with the web app's public-data tool, or KEGG pathways from the KEGG REST API under its academic terms) runs through `--marker-panel` declared with `--gene-sets-provenance` (or `--gene-sets-source`, `--gene-sets-version` and `--gene-sets-id-type`), using the unchanged panel-mean computation. Give `--gene-sets-provenance <json>` (written by the download tool), or without it `--gene-sets-source`, `--gene-sets-version` and `--gene-sets-id-type` explicitly: these are never guessed. Optional: `--gene-sets-species`, `--gene-sets-name`, `--gene-sets-terms`. The analysis key type is `--feature-id-type`.

`python scripts/run_scanpy_annotate.py --from-run cluster_run ... --marker-panel panglao_panel.json --gene-sets-provenance panglao_panel.provenance.json --feature-id-type SYMBOL --outdir run`

The file's SHA-256 is computed at run time and must equal the provenance `sha256` (`OS_REFDATA_MISMATCH` otherwise). A GMT must be tab-separated with a term ID, a description and at least one gene per line (`OS_INVALID_INPUT`). The gene-set identifier type must equal the analysis key type; identifiers are never converted (`OS_GENE_SET_ID_MISMATCH`). Species is compared with `--species` (`OS_GENE_SET_SPECIES_MISMATCH`). Fewer than 10% of the unique set genes present in the analysed features is refused as a probable identifier error (`OS_GENE_SET_LOW_OVERLAP`). The KEGG term-ID exclusion applies to bundled/registered collections only, never to user files. The record (name, source, release, retrieval time, URLs, terms, ID type, species, SHA-256, overlap, "user-supplied, not bundled with omicstat") is written to `provenance/user_gene_sets.json` and `provenance/provenance.json`, and one Methods sentence states it. The user is responsible for the terms of use of the file.

## References
See references/options.md, parameters.md, method-basis.md, qc-rules.md, reporting-templates.md and troubleshooting.md.
