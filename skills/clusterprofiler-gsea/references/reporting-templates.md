# Reporting templates

```template methods
GO preranked gene-set enrichment used clusterProfiler {clusterprofiler_version} with enrichit {enrichit_version} and org.Hs.eg.db {annotation_version}. The ranking was {metric}, positive for {direction}. {ranking_detail}All {n_ranked} finite rankable genes entered without significance filtering. GO ontology was {ontology}; gene sets intersected with ranked genes were retained at sizes {min_size}–{max_size}. The multilevel method used exponent 1, BH adjustment, pvalueCutoff = 1, R seed {seed}, and one thread. The enrichit defaults were eps = 1e-10, sampleSize = 101, nPermSimple = 1000, scoreType = "std", weight = NULL; eps is a P-value computation floor. Main significance was BH adjusted P < {alpha} on the full tested table.
```

```template results
Of {tested} testable GO sets, {sig} had BH adjusted P < {alpha}. Raw P, BH adjusted P and q-value are separate columns in the full table. No comparison with another GSEA engine is implied by equality of set names.
```

`--database custom` (user-supplied GMT) uses the two templates below instead; the engine then inserts
the gene-set provenance sentence of `_shared/scripts/user_genesets.R` before the Results heading.

```template methods_custom
Preranked gene-set enrichment of user-supplied gene sets (database label: {label}) used the generic GSEA function of clusterProfiler {clusterprofiler_version}, with TERM2GENE and TERM2NAME taken from the user GMT, and enrichit {enrichit_version}. The ranking was {metric}, positive for {direction}. {ranking_detail}All {n_ranked} finite rankable genes entered without significance filtering and were matched to the gene sets on their identifiers without conversion. Gene sets intersected with ranked genes were retained at sizes {min_size}–{max_size}. The multilevel method used exponent 1, BH adjustment, pvalueCutoff = 1, R seed {seed}, and one thread. The enrichit defaults were eps = 1e-10, sampleSize = 101, nPermSimple = 1000, scoreType = "std", weight = NULL; eps is a P-value computation floor. Main significance was BH adjusted P < {alpha} on the full tested table.
```

```template results_custom
Of {tested} testable user-supplied gene sets, {sig} had BH adjusted P < {alpha}. Raw P, BH adjusted P and q-value are separate columns in the full table.
```
