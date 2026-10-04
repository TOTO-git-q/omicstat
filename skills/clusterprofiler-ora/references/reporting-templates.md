# Reporting templates

Filled from the actual run: versions come from the loaded packages and the GO.db / org.Hs.eg.db
metadata of the locked container (`results/clusterprofiler_ora_results.json` field `software`, which
matches `provenance/provenance.json` `packages`). `{family_sentence}`, `{scope_sentence}` and
`{family_results}` state the effective input/background and BH family per testing family
(`tables/test_families.csv`): one family for BP, CC, MF or ALL with pool = TRUE; one per ontology for
ALL with pool = FALSE. The simplify paragraph (or "No term simplification was applied.") is added
after the Methods template by the engine.

```template methods
GO over-representation analysis used the enrichGO function of clusterProfiler {cp_version}; hypergeometric P values, BH adjusted P values and q-values were computed by enrichit {enrichit_version} (ora_gson), which removes zero-overlap sets before adjustment. GO annotation came from org.Hs.eg.db {annotation_version} (Entrez Gene source {eg_date}; GO annotation source {org_go_date}) and GO.db {godb_version} (Gene Ontology release {go_date}), with {key_type} identifiers. The selection rule was: {rule}. The candidate eligible background contained {candidate} genes, of which {mapped} mapped to OrgDb; {input} selected genes were supplied and {mapped_input} mapped to OrgDb. Ontology was {ontology}, with pool = {pool}. {family_sentence} Sets of size {min_size}–{max_size} were tested. Nominal P and q-value calculation cutoffs were both 1 to retain all testable terms. {scope_sentence} Adjusted P < {alpha} was flagged separately. Zero-overlap and unmapped sets were not tested. Result tables keep the original {key_type} identifiers; gene symbols ({n_symbol} of {input} selected genes mapped) are given in tables/gene_symbol_map.csv and tables/enrichment_full_symbols.csv, using the mapping of setReadable.
```

```template results
Of {tested} tested GO terms, {sig} had BH adjusted P < {alpha}.{family_results} The complete tested table, including raw P, BH adjusted P and q-value where available, is in tables/enrichment_full.csv. A term in one list is not evidence of a difference in enrichment from another list.
```
