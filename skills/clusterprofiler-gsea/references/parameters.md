# Parameters — clusterprofiler-gsea

| Flag | Default | Allowed | Why |
|---|---|---|---|
| `--ranked` | none | CSV path | all rankable genes; no significance cut |
| `--ranking-metric` | none | named signed statistic or effect | explicit metric contract |
| `--direction` | none | contrast description | meaning of positive score |
| `--statistic-kind` | test_statistic | test_statistic, effect_size | kind of a `--ranked` score (S1 P-1); with `--from-run` the upstream metadata decides |
| `--lfc-type` | none | named LFC type | required for an effect-size ranking (S1 cross-module rule 2) |
| `--from-run` | none | directional DE run | inherit ranking, metric, LFC type and contrast from the upstream ranked_list metadata; refused without it |
| `--outdir` | (required) | directory | run outputs |
| `--spec` | none | JSON path | replay |
| `--database` | GO | GO, MSigDB, KEGG, Reactome | only pinned GO is enabled |
| `--ontology` | BP | BP, CC, MF, ALL | GO subset |
| `--key-type` | ENTREZID | OrgDb key type | matches ranked IDs |
| `--min-size` | 10 | positive integer | CP-GSEA method limit |
| `--max-size` | 500 | positive integer | CP-GSEA method limit |
| `--exploratory-fdr` | off | switch | also record predeclared BH 0.25 flag |
| `--top-n` | 15 | 1–100 | plot limit only |
| `--seed` | 20260925 | integer | set.seed before GSEA |
| `--journal` | nature | nature, cell, science, generic | figure preset |

Fixed `gseGO` arguments: `exponent = 1`, `pvalueCutoff = 1`, `pAdjustMethod = "BH"`, `verbose = FALSE`, `nPerm = 1000`, `method = "multilevel"`, `adaptive = FALSE`, `minPerm = 101`, `maxPerm = 1e5`, `pvalThreshold = 0.1`. The locked wrapper does not forward `...` to enrichit, so its downstream `eps`, `sampleSize`, `nPermSimple`, `scoreType`, `weight` and `seed` remain the locked defaults; `set.seed` fixes the R RNG before the wrapper. Reproducibility is checked by the smoke test.
