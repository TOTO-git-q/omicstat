# Reporting templates

```template methods
Gene-set scores were computed with GSVA {gsva_version} using the gsvaParam object API on {n_features} features and {n_samples} samples. {input_source} Input scale was declared {input_scale} ({input_storage} storage). Requested kcdf was {kcdf}; the branch used was {kernel} (auto threshold 200 samples). The offline collection was {collection} for {collection_species} ({collection_version}; SHA-256 {collection_sha256}). GSVA removed {n_constant_rows} rows with constant expression (filterRows=TRUE) before mapping gene sets; set sizes were counted after gene ID intersection and this removal and restricted to {min_size}–{max_size}. {n_retained} of {n_sets} sets were scored ({n_excluded} excluded: {exclusion_summary}); the sizes used by GSVA were {size_range}, and per-set sizes with exclusion reasons are in tables/gene_set_sizes.csv. tau=1, maxDiff=TRUE, absRanking=FALSE, sparse=TRUE, checkNA=auto, use=everything, filterRows=TRUE, and seed {seed} were recorded. {corrected_sentence} No group inference was performed on the scores: the limma entry and the empirical Bayes settings for GSVA scores await the owner's decision (S1 P-3).
```

```template results
GSVA returned {n_scored} gene-set score rows for {n_samples} samples. The full score matrix is in tables/scores.csv and is handed on unchanged. Batch-corrected input: {corrected_input}. Group inference: {inference_status}.
```
