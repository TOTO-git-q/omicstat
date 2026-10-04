# Reporting templates

All placeholders come from the single result object. Full parameters accompany the draft.

```template methods
Raw counts for {n_model_genes} genes were processed with scvi.model.SCVI.setup_anndata and SCVI using the resolved covariates, architecture and likelihood below. CPU model.train used at most {max_epochs} epochs and seed {seed}; {n_latent} latent dimensions entered the declared neighbors/UMAP pipeline. Before/after graph diagnostics are descriptive. Integration preserved counts and original cluster labels. The small two-epoch simulator fixture checks deterministic execution and serialization, not convergence or biological integration quality.
```

```template results
{n_cells} cells across {n_batches} batches were represented in {n_latent} latent dimensions. Graph mixing is reported per cell and does not establish preservation of biological signals or removal of all batch effects.
```
