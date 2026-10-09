# Reporting templates

Versions are filled from the actual run (`results/clusterprofiler_compare_results.json` field
`software`, matching `provenance/provenance.json`). `{scope_sentence}` states, per list, the effective
input/background of every testing family and the BH scope (`tables/test_families.csv`): one family per
list for BP, CC, MF or ALL with pool = TRUE; one per list and ontology for ALL with pool = FALSE.

```template methods
GO over-representation profiles for {n_lists} named gene lists used clusterProfiler {cp_version} (enrichGO; P values, BH adjustment and q-values computed by enrichit {enrichit_version}) with org.Hs.eg.db {annotation_version} and GO.db {godb_version} (Gene Ontology release {go_date}), using {key_type} identifiers. Each list's study unit, model/contrast, direction, selection rule, threshold, top-N and candidate/mapped/effective input and background counts are in tables/list_definitions.csv. GO ontology was {ontology}, pool = {pool}, with sets of size {min_size}–{max_size}. Calculation cutoffs were pvalueCutoff = 1 and qvalueCutoff = 1 to retain all testable terms; BH adjusted P < 0.05 was flagged separately. {scope_sentence} {population_note} Zero-overlap and unmapped sets were not tested.
```

```template results
The {mode} route yielded {tested} tested list-term rows, of which {sig} had BH adjusted P < 0.05. Raw P, BH adjusted P and q-value are separate columns in the full table. A term's presence in one list and absence in another is not a statistical test of a between-list enrichment difference.
```

`--database custom` (user-supplied GMT) uses the two templates below instead; the engine then inserts
the gene-set provenance sentence of `_shared/scripts/user_genesets.R` before the Results heading.

```template methods_custom
Over-representation profiles of user-supplied gene sets (database label: {label}) for {n_lists} named gene lists used clusterProfiler {cp_version} (the generic enricher function, with TERM2GENE and TERM2NAME taken from the user GMT; P values, BH adjustment and q-values computed by enrichit {enrichit_version}), matching {key_type} identifiers without conversion. Each list's study unit, model/contrast, direction, selection rule, threshold, top-N and candidate/annotated/effective input and background counts are in tables/list_definitions.csv. Sets of size {min_size}–{max_size} were tested. Calculation cutoffs were pvalueCutoff = 1 and qvalueCutoff = 1 to retain all testable sets; BH adjusted P < 0.05 was flagged separately. {scope_sentence} {population_note} Zero-overlap sets were not tested.
```

```template results_custom
The {mode} route yielded {tested} tested list-set rows, of which {sig} had BH adjusted P < 0.05. Raw P, BH adjusted P and q-value are separate columns in the full table. A set's presence in one list and absence in another is not a statistical test of a between-list enrichment difference.
```
