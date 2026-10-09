# Parameters

| Flag | Default | Allowed | Why |
|---|---|---|---|
| `--input` | none | expression CSV | First column feature_id, remaining samples. |
| `--from-run` | none | upstream run | Typed expression_matrix / batch_corrected_matrix handoff, or a limma-voom / limma-array / limma-dupcor run (EList E used; weights not used). |
| `--upstream-object` | none | object name | Resolve multiple upstream matrices (non-limma upstream). |
| `--outdir` | required | path | Output location. |
| `--spec` | none | prior spec | Replay. |
| `--input-scale` | required | vst, logcpm, normalized_array, counts | Record input scale; counts require Poisson (PACK P-1). A limma upstream must match its hand-off scale (voom E = logcpm, array = normalized_array). |
| `--kcdf` | auto | auto, Gaussian, Poisson, none | Auto with threshold 200 (PACK P-1). |
| `--collection` | msigdb_collections | registered ID or user | Offline only; Hallmark awaits M1-3 (PACK P-2). |
| `--gene-sets` | none | registered GMT | SHA-256 checked. |
| `--min-size` | 5 | 1–100000 | Bulk preset (PACK P-2); counted after ID intersection and GSVA's constant-row removal. |
| `--max-size` | 500 | 1–100000 | Bulk preset; 300 may reproduce immunologic example (PACK P-2). |
| `--samples` | none | sample CSV | Group annotation of the heatmap and the score-by-group figure. |
| `--sample-col` | sample | column name | Match expression columns. |
| `--group-col` | condition | column name | Display grouping (a limma upstream's condition when not given). |
| `--reference` | none | refused | Inference request: `OS_OWNER_DECISION_PENDING` (S1 P-3 owner-pending). |
| `--target` | none | refused | Inference request: `OS_OWNER_DECISION_PENDING`. |
| `--covariates` | none | refused | Inference request: `OS_OWNER_DECISION_PENDING`. |
| `--seed` | 20260925 | integer | Reproducible run. |
| `--journal` | nature | nature, cell, science, generic | Figure preset. |
| `--gene-sets-provenance` | none | JSON path | provenance written by the download tool (source, name, version_or_release, download_time, urls, sha256, terms, terms_url, id_type, species); its sha256 must equal the run-time hash of the file |
| `--gene-sets-source` | none | text | source of the user file (e.g. KEGG REST, PanglaoDB, MSigDB); required without a provenance JSON, never guessed |
| `--gene-sets-version` | none | text | release or version of the user file; required without a provenance JSON, never guessed |
| `--gene-sets-id-type` | none | ENTREZID, SYMBOL, ENSEMBL | identifier type of the user file; required without a provenance JSON; must equal the analysis key type (no silent conversion) |
| `--gene-sets-species` | none | text | species of the user file; compared with the analysis species when that is known |
| `--gene-sets-name` | none | text | display name; otherwise the provenance name or the file name |
| `--gene-sets-terms` | none | text | terms of use, recorded in provenance and Methods; the user is responsible for them |
| `--feature-id-type` | none | ENTREZID, SYMBOL, ENSEMBL | identifier type of the analysed features; required with a user file and compared with its ID type |

The locked GSVA 2.6.6 `gsvaParam` call explicitly writes `assay=NA_character_`, `annotation=NULL`, `kcdfNoneMinSampleSize=200`, `tau=1`, `maxDiff=TRUE`, `absRanking=FALSE`, `sparse=TRUE`, `checkNA="auto"`, `use="everything"`, `filterRows=TRUE`, `ondisk="auto"`, and `verbose=FALSE`. `gsva()` uses a serial BiocParallel backend. The gene sets GSVA actually used and their sizes are read back with `geneSets()` / `geneSetSizes()` on the returned matrix. No limma inference is run on the scores: the receiving limma entry and the eBayes trend/robust settings are owner-pending (S1 P-3).
