# Parameters — clusterprofiler-ora

| Flag | Default | Allowed | Why |
|---|---|---|---|
| `--input` | none | CSV path | selected IDs |
| `--universe` | none | CSV path | all genes eligible for the selection rule; S1 P-2 |
| `--selection-rule` | none | text | identifies the eligibility rule; S1 P-2 |
| `--from-run` | none | run directory | use finite upstream padj as eligibility and padj below alpha as selected |
| `--outdir` | (required) | directory | output location |
| `--spec` | none | JSON path | replay resolved arguments |
| `--id-column` | feature_id | column name | same identifier type in both CSVs |
| `--key-type` | ENTREZID | OrgDb key type | must match gene IDs |
| `--database` | GO | GO, KEGG, MSigDB, Reactome | only registered, installed GO is enabled; other collections refuse |
| `--ontology` | BP | BP, CC, MF, ALL | S1 P-1 |
| `--pool` | none | TRUE, FALSE | required for ALL; S1 P-1 |
| `--alpha` | 0.05 | 0–1 | separate BH flag; not the computation cutoff |
| `--min-size` | 10 | positive integer | locked enrichGO default |
| `--max-size` | 500 | positive integer | locked enrichGO default |
| `--simplify` | off | switch | optional display summary; S1 P-3 |
| `--top-n` | 15 | 1–100 | dot plot only |
| `--seed` | 20260925 | integer | provenance |
| `--journal` | nature | nature, cell, science, generic | figure preset |

Fixed analysis arguments: `enrichGO(pvalueCutoff = 1, pAdjustMethod = "BH", qvalueCutoff = 1, readable = FALSE, pool = FALSE)` unless ALL gives the explicit pool. `simplify(cutoff = 0.7, by = "p.adjust", select_fun = min, measure = "Wang", semData = NULL)` when requested; `enrichit::EXTID2NAME(OrgDb, geneID = <selected IDs>, keytype = --key-type, toType = "SYMBOL")` for the symbol supplement only. The package function defaults for nominal P and q-value are 0.05 and 0.2; setting both to 1 preserves the testable full table. The decision is recorded under 待裁决 because PACK D-O5 has not reconciled these calculation and reporting thresholds.
