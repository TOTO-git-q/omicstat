# Parameters — clusterprofiler-compare

| Flag | Default | Allowed | Why |
|---|---|---|---|
| `--manifest` | (required) | CSV path | named lists with explicit background and provenance |
| `--outdir` | (required) | directory | output location |
| `--spec` | none | JSON path | replay |
| `--database` | GO | GO, KEGG, MSigDB, Reactome | only pinned GO is enabled |
| `--ontology` | BP | BP, CC, MF, ALL | same GO ontology as ORA |
| `--pool` | none | TRUE, FALSE | required explicitly for ALL |
| `--key-type` | ENTREZID | OrgDb key type | consistent IDs |
| `--min-size` | 10 | positive integer | locked enrichGO default |
| `--max-size` | 500 | positive integer | locked enrichGO default |
| `--top-n-per-group` | 5 | 1–50 | comparison plot only |
| `--seed` | 20260925 | integer | provenance |
| `--journal` | nature | nature, cell, science, generic | figure preset |

Manifest columns: `group,genes,universe,population,study_unit,model,contrast,direction,threshold,top_n,selection_rule`. `genes` and `universe` point to CSVs with `feature_id`; relative paths are resolved beside the manifest. All fields must be nonempty. The common-universe compareCluster route is used only when the declared `population` is the same and every eligible universe has identical membership. Otherwise each list gets its own explicit-universe enrichGO call. The full table calculation uses P and q cutoffs 1, BH adjustment, and a separate BH 0.05 flag.
