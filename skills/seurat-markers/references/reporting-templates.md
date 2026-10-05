# Reporting templates

```template methods
seurat-markers was run with Seurat {version} using FindAllMarkers or FindMarkers with the recorded, explicit parameters: {parameters}. This is a descriptive single-cell analysis. {details}
```

```template results
The marker table contains {rows} rows across {clusters} clusters. The result contains {n} cells and {features} features. Top 3 markers per cluster (native order among rows with avg_log2FC > 1, as in the Seurat tutorial), with pct.1/pct.2: {top_markers}. No replicate-level condition inference is supplied.
```

| Placeholder | Result field |
|---|---|
| version | installed Seurat version |
| parameters | canonical argv from SPEC |
| details | r$details |
| n | ncol(r$object) |
| features | nrow(r$object) |
