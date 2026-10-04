# Reporting templates

All placeholders come from the single result object. Full parameters accompany the draft.

```template methods
Descriptive cluster markers were computed with scanpy.tl.rank_genes_groups using test {test} with groups={groups}, reference={reference}, mask_var={mask_var_text}, rankby_abs={rankby_abs}, corr_method={corr_method}, tie_correct={tie_correct}, and n_genes={n_genes_text} (None requests all available genes). use_raw=False selected the declared expression layer. The native sc.get.rank_genes_groups_df CSV preserves native columns and ordering alongside the suite feature table and AnnData uns. Cells are descriptive units; this analysis does not test differences between conditions.
```

```template results
{n_tested_rows} cluster-gene rows were returned across {n_clusters} clusters; {n_significant_rows} rows met the declared adjusted P <= {alpha} using {corr_method} correction (corr_method={corr_method}), reference={reference}, groups={groups}, mask_var={mask_var_text}, rankby_abs={rankby_abs}, tie_correct={tie_correct}, and n_genes={n_genes_text}. These post-clustering statistics are descriptive and cannot be interpreted as confirmatory condition-level inference.
```
