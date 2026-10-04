# Reporting templates
```template methods
Per-cell QC metrics were computed with scuttle {version} on the counts assay, using the explicitly supplied mitochondrial feature IDs. Filtering mode was {mode}: {settings}; batch column: {batch}. MAD bounds are reported in tables/thresholds.csv. Alternative experiments retain their input structure. No doublet removal was performed.
```
```template results
Of {n_input} cells, {n_retained} were retained and {n_removed} removed. Per-cell flags and reasons are in tables/metrics.csv; per-batch input/retained/discarded counts are in tables/flow.csv.
```
Supplementary `--metrics-args` and `--filter-args` values are recorded in provenance. All function defaults refer to the locked container, not a literature frequency.
