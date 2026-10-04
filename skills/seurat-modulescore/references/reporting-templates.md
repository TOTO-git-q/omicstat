# Reporting templates

```template methods
seurat-modulescore was run with Seurat {version} using AddModuleScore with the recorded, explicit parameters: {parameters}. This is a descriptive single-cell analysis. {details}
```

```template results
The result contains {n} cells and {features} features. {details} No replicate-level condition inference is supplied.
```

| Placeholder | Result field |
|---|---|
| version | installed Seurat version |
| parameters | canonical argv from SPEC |
| details | r$details |
| n | ncol(r$object) |
| features | nrow(r$object) |
