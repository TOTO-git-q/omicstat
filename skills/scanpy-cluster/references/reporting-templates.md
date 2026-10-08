# Reporting templates

All placeholders come from the single result object. Full parameters accompany the draft.

```template methods
Counts were processed with scanpy.pp.normalize_total, log1p and highly_variable_genes using the resolved native arguments below. {n_hvg} variable genes entered PCA with {n_pcs} components; scaling was enabled: {scaled}. The graph, Leiden partition and UMAP used the declared settings and seed {seed}. PCA signs and cluster IDs were canonicalized. Counts and transformed expression were retained.
```

```template results
{n_cells} cells from {n_samples} samples were assigned to {n_clusters} descriptive clusters. PCA and UMAP are exploratory summaries, not independent evidence of condition-specific effects.
```

```template methods_rep
Counts were normalized and log-transformed with the declared arguments; {n_hvg} variable genes were recorded for expression diagnostics. Existing representation {use_rep} ({n_pcs} dimensions) entered neighbors, Leiden and UMAP without recomputing PCA or scaling. PCA-specific requested settings were inactive. Counts and transformed expression were retained; the partition and embedding are descriptive.
```

```template results_rep
{n_cells} cells from {n_samples} samples were assigned to {n_clusters} descriptive clusters using {use_rep}. The supplied representation and UMAP are exploratory summaries, not independent evidence of condition-specific effects.
```
