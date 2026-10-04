# Reporting templates

All placeholders come from the single result object. Full parameters accompany the draft.

```template methods
Raw integer counts were evaluated using scanpy.calculate_qc_metrics. Cells were retained only when they met all prespecified feature, count and mitochondrial cutoffs. Genes were then retained according to the declared minimum number of cells. Doublet handling was {doublet_mode}; when requested, Scrublet used the explicit expected rate and score cutoff. Counts were not normalized.
```

```template results
Of {n_input_cells} input cells, {n_cells} cells and {n_genes} genes were retained. The cell-level audit retains all exclusion reasons; {n_predicted_doublets} cells were classified as predicted doublets. These are QC classifications, not biological findings.
```
