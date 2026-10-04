# Parameters

| Flag | Default | Allowed | Why |
|---|---|---|---|
| `--ranked-list` | none | existing CSV | Ranking contract: feature_id,symbol,score descending (PACK P-1). |
| `--from-run` | none | upstream run | Read typed ranked_list handoff (PACK P-1). |
| `--outdir` | required | path | Output location. |
| `--spec` | none | prior resolved spec | Replay. |
| `--rank-metric` | wald_stat | wald_stat, moderated_t, other | Name the ranking statistic (PACK P-1). |
| `--metric-name` | none | text | Required for other statistics (PACK P-1). |
| `--direction` | none | text | Meaning of positive scores (PACK P-1); required with a `--ranked-list` file that carries no omicstat metadata; with `--from-run` the upstream ranked_list metadata states it and a conflicting value is refused. |
| `--collection` | msigdb_collections | registered ID | Hallmark preset waits for locked registry; no download (PACK P-2). |
| `--gene-sets` | none | registered local GMT | Must match registry SHA-256 (PACK P-2). |
| `--min-size` | 15 | 1–100000 | Tutorial main workflow (PACK P-3). |
| `--max-size` | 500 | 1–100000 | Tutorial main workflow (PACK P-3). |
| `--alpha` | 0.05 | 0.000001–0.5 | BH reporting threshold (PACK D-F5). |
| `--seed` | 20260925 | integer | Reproducible fgsea multilevel run (ENGINEERING_PLAN §3.4). |
| `--journal` | nature | nature, cell, science, generic | Figure preset. |

Fixed call arguments from locked fgsea 1.38.0 formals: `sampleSize=101`, `eps=1e-50`, `scoreType="std"`, `nproc=1` (suite), `gseaParam=1`, `BPPARAM=NULL`, `nPermSimple=1000`, `absEps=NULL`; `minSize` and `maxSize` are flags. All are explicit at the call site and in calls_registry.json.
