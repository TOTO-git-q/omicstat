# Reporting templates

```template methods
seurat-markers was run with Seurat {version} using FindAllMarkers or FindMarkers with the recorded, explicit parameters: {parameters}. This is a descriptive single-cell analysis. {details}
```

```template results
The marker table contains {significant} rows with Bonferroni-adjusted P (p_val_adj) < 0.05. The result contains {n} cells and {features} features. {details} No replicate-level condition inference is supplied.
```

| Placeholder | Result field |
|---|---|
| version | installed Seurat version |
| parameters | canonical argv from SPEC |
| details | r$details |
| n | ncol(r$object) |
| features | nrow(r$object) |
