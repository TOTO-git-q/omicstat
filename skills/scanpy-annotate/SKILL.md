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

## References
See references/options.md, parameters.md, method-basis.md, qc-rules.md, reporting-templates.md and troubleshooting.md.
