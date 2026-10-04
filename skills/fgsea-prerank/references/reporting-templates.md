# Reporting templates

The engine fills these exact blocks. Source: PACK S1 P-1–P-3 and fgsea 1.38.0 tutorial.

```template methods
Preranked gene-set enrichment used fgsea {fgsea_version} fgseaMultilevel on {n_genes} rankable genes. The ranking metric was {metric}; positive scores mean {direction}. The offline collection was {collection} for {collection_species} ({collection_version}; SHA-256 {collection_sha256}). Sets were intersected with ranked IDs and retained at size {min_size}–{max_size}; {n_retained} of {n_sets} sets remained and {n_excluded} were excluded. The weighting exponent was 1, score type was standard, sample size 101, nPermSimple 1000, nproc 1, and seed {seed}. eps = 1e-50 was the P-value computation floor. BH adjusted P < {alpha} was the reporting threshold; it did not subset the input ranking. Tied scores: {n_tied}.
```

```template results
Of {n_retained} retained gene sets, {n_sig} had BH adjusted P < {alpha}. The full tested-set table reports ES, NES, nominal and adjusted P, log2err, set size, and leading-edge IDs.
```
