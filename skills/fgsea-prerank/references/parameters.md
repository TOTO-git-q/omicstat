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
| `--collection` | msigdb_collections | registered ID or user | Hallmark preset waits for locked registry; no download (PACK P-2). |
| `--gene-sets` | none | registered local GMT | Must match registry SHA-256 (PACK P-2). |
| `--min-size` | 15 | 1–100000 | Tutorial main workflow (PACK P-3). |
| `--max-size` | 500 | 1–100000 | Tutorial main workflow (PACK P-3). |
| `--alpha` | 0.05 | 0.000001–0.5 | BH reporting threshold (PACK D-F5). |
| `--seed` | 20260925 | integer | Reproducible fgsea multilevel run (ENGINEERING_PLAN §3.4). |
| `--journal` | nature | nature, cell, science, generic | Figure preset. |
| `--gene-sets-provenance` | none | JSON path | provenance written by the download tool (source, name, version_or_release, download_time, urls, sha256, terms, terms_url, id_type, species); its sha256 must equal the run-time hash of the file |
| `--gene-sets-source` | none | text | source of the user file (e.g. KEGG REST, PanglaoDB, MSigDB); required without a provenance JSON, never guessed |
| `--gene-sets-version` | none | text | release or version of the user file; required without a provenance JSON, never guessed |
| `--gene-sets-id-type` | none | ENTREZID, SYMBOL, ENSEMBL | identifier type of the user file; required without a provenance JSON; must equal the analysis key type (no silent conversion) |
| `--gene-sets-species` | none | text | species of the user file; compared with the analysis species when that is known |
| `--gene-sets-name` | none | text | display name; otherwise the provenance name or the file name |
| `--gene-sets-terms` | none | text | terms of use, recorded in provenance and Methods; the user is responsible for them |
| `--feature-id-type` | none | ENTREZID, SYMBOL, ENSEMBL | identifier type of the analysed features; required with a user file and compared with its ID type |

Fixed call arguments from locked fgsea 1.38.0 formals: `sampleSize=101`, `eps=1e-50`, `scoreType="std"`, `nproc=1` (suite), `gseaParam=1`, `BPPARAM=NULL`, `nPermSimple=1000`, `absEps=NULL`; `minSize` and `maxSize` are flags. All are explicit at the call site and in calls_registry.json.
