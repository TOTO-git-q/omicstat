# Parameters — clusterprofiler-compare

| Flag | Default | Allowed | Why |
|---|---|---|---|
| `--manifest` | (required) | CSV path | named lists with explicit background and provenance |
| `--outdir` | (required) | directory | output location |
| `--spec` | none | JSON path | replay |
| `--database` | GO | GO, KEGG, MSigDB, Reactome, custom | registered GO, or custom for a user-supplied `--gene-sets` GMT; KEGG, MSigDB and Reactome are not bundled |
| `--ontology` | BP | BP, CC, MF, ALL | same GO ontology as ORA |
| `--pool` | none | TRUE, FALSE | required explicitly for ALL |
| `--key-type` | ENTREZID | OrgDb key type | consistent IDs |
| `--min-size` | 10 | positive integer | locked enrichGO default |
| `--max-size` | 500 | positive integer | locked enrichGO default |
| `--top-n-per-group` | 5 | 1–50 | comparison plot only |
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

Manifest columns: `group,genes,universe,population,study_unit,model,contrast,direction,threshold,top_n,selection_rule`. `genes` and `universe` point to CSVs with `feature_id`; relative paths are resolved beside the manifest. All fields must be nonempty. The common-universe compareCluster route is used only when the declared `population` is the same and every eligible universe has identical membership. Otherwise each list gets its own explicit-universe enrichGO call. The full table calculation uses P and q cutoffs 1, BH adjustment, and a separate BH 0.05 flag.
