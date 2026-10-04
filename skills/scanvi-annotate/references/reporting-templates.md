# Reporting templates

All placeholders come from the single result object. Full parameters accompany the draft.

```template methods
scvi.model.SCANVI.from_scvi_model initialized the model from the hash-verified local scVI model. The reference contained {n_reference_cells} labeled cells in {n_label_categories} categories and {n_query_cells} unlabeled cells. model.train used at most {max_epochs} CPU epochs with the resolved split/training arguments below. model.predict used the declared use_posterior_mean setting for both hard and soft predictions. Observed labels, native model files, class probabilities and the cluster-label crosstab were retained. UMAP coordinates are inherited from scVI; no scANVI embedding or validated prediction accuracy is claimed.
```

```template results
Labels were predicted for {n_cells} cells; {n_low_confidence} cells had maximum model probability below the prespecified display threshold {min_confidence}. Class probabilities are not calibrated accuracy estimates; no held-out accuracy is claimed.
```
