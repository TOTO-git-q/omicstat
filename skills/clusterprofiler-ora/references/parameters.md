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
| `--database` | GO | GO, KEGG, MSigDB, Reactome, custom | registered GO, or custom for a user-supplied `--gene-sets` GMT; KEGG, MSigDB and Reactome are not bundled and refuse with the user-supplied route in the message |
| `--ontology` | BP | BP, CC, MF, ALL | S1 P-1 |
| `--pool` | none | TRUE, FALSE | required for ALL; S1 P-1 |
| `--alpha` | 0.05 | 0–1 | separate BH flag; not the computation cutoff |
| `--min-size` | 10 | positive integer | locked enrichGO default |
| `--max-size` | 500 | positive integer | locked enrichGO default |
| `--simplify` | off | switch | optional display summary; S1 P-3 |
| `--top-n` | 15 | 1–100 | dot plot only |
| `--seed` | 20260925 | integer | provenance |
| `--journal` | nature | nature, cell, science, generic | figure preset |
| `--gene-sets` | none | local GMT path | user-supplied GMT for the user-collection mode; never bundled or downloaded by omicstat |
| `--gene-sets-provenance` | none | JSON path | provenance written by the download tool (source, name, version_or_release, download_time, urls, sha256, terms, terms_url, id_type, species); its sha256 must equal the run-time hash of the file |
| `--gene-sets-source` | none | text | source of the user file (e.g. KEGG REST, PanglaoDB, MSigDB); required without a provenance JSON, never guessed |
| `--gene-sets-version` | none | text | release or version of the user file; required without a provenance JSON, never guessed |
| `--gene-sets-id-type` | none | ENTREZID, SYMBOL, ENSEMBL | identifier type of the user file; required without a provenance JSON; must equal the analysis key type (no silent conversion) |
| `--gene-sets-species` | none | text | species of the user file; compared with the analysis species when that is known |
| `--gene-sets-name` | none | text | display name; otherwise the provenance name or the file name |
| `--gene-sets-terms` | none | text | terms of use, recorded in provenance and Methods; the user is responsible for them |

Fixed analysis arguments: `enrichGO(pvalueCutoff = 1, pAdjustMethod = "BH", qvalueCutoff = 1, readable = FALSE, pool = FALSE)` unless ALL gives the explicit pool. `simplify(cutoff = 0.7, by = "p.adjust", select_fun = min, measure = "Wang", semData = NULL)` when requested; `enrichit::EXTID2NAME(OrgDb, geneID = <selected IDs>, keytype = --key-type, toType = "SYMBOL")` for the symbol supplement only. The package function defaults for nominal P and q-value are 0.05 and 0.2; setting both to 1 preserves the testable full table. The decision is recorded under 待裁决 because PACK D-O5 has not reconciled these calculation and reporting thresholds.
