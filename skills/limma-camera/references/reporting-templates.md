# Reporting templates

```template methods
We used limma {limma_version} to run {method} for the prespecified {question} gene-set question. {input_sentence} {design_sentence} {replicate_sentence} {ranking_sentence} {method_sentence} The offline {collection} collection (version {collection_version}, SHA-256 {collection_sha256}, {collection_species}) supplied {n_input_sets} sets; {n_matched_sets} overlapped the {n_input_features} input features ({n_unmatched_sets} without overlap could not be tested). {selection_sentence} The reporting threshold was BH adjusted P < {alpha}.
```

```template results
Of {tested_phrase}, {n_significant} met the prespecified adjusted-P reporting threshold. Direction Up means {direction_meaning}. Full unfiltered results, direction, set sizes and raw method fields are in tables/gene_set_table.csv and tables/method_raw.csv. Collection membership, overlap, selection and testing status are recorded separately in tables/gene_set_selection.csv.
```
