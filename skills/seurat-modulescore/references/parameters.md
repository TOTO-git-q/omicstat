# Parameters

| Flag | Default | Allowed / purpose | Source |
|---|---|---|---|
| --input | none | path: Raw counts for QC; chain-state Seurat RDS for other modules | locked formals / transport contract |
| --from-run | none | path: Verified upstream Seurat run directory | locked formals / transport contract |
| --outdir | required | path: Run output directory | user_required |
| --spec | none | path: Replay prior provenance/resolved_spec.json | locked formals / transport contract |
| --seed | 20260925 | int: Recorded RNG seed | locked formals / transport contract |
| --journal | nature | enum: Figure preset | locked formals / transport contract |
| --gene-sets | required | path: Offline GMT gene sets with name and source in first two columns | user_required |
| --set-organism | required | string: Declared gene-set organism; must match chain | user_required |
| --nbin | 24 | int: Expression bins for control pool | locked formals / transport contract |
| --ctrl | 100 | int: Controls per matched feature | locked formals / transport contract |
| --pool | none | path: Optional text file with one control-pool gene per line | locked formals / transport contract |
| --gene-sets-provenance | none | JSON path | provenance written by the download tool (source, name, version_or_release, download_time, urls, sha256, terms, terms_url, id_type, species); its sha256 must equal the run-time hash of the file |
| --gene-sets-source | none | text | source of the user file (e.g. KEGG REST, PanglaoDB, MSigDB); required without a provenance JSON, never guessed |
| --gene-sets-version | none | text | release or version of the user file; required without a provenance JSON, never guessed |
| --gene-sets-id-type | none | ENTREZID, SYMBOL, ENSEMBL | identifier type of the user file; required without a provenance JSON; must equal the analysis key type (no silent conversion) |
| --gene-sets-species | none | text | species of the user file; compared with the analysis species when that is known |
| --gene-sets-name | none | text | display name; otherwise the provenance name or the file name |
| --gene-sets-terms | none | text | terms of use, recorded in provenance and Methods; the user is responsible for them |
| --feature-id-type | none | ENTREZID, SYMBOL, ENSEMBL | identifier type of the analysed features; required with a user file and compared with its ID type |

All fixed package arguments and their locked function defaults are recorded in scripts/calls_registry.json. Every result-affecting argument is explicit at its call site. --help lists transport flags. Seed 20260925 follows the builder contract.

## 待裁决
Scientific choices not settled by documentation are required inputs. Tutorial values are examples, never silently chosen.

| --assay | none | upstream normalized assay; RNA or SCT | locked default NULL |
| --slot | data | data, counts, scale.data | locked default |
| --name | Cluster | native score prefix | locked default |
| --k | false | false or true with a DoKMeans RDS | locked default |
| --kmeans-object | none | DoKMeans RDS when k=true | user input |

Online HGNC search is disabled under the offline analysis contract (search=FALSE). Supply an already mapped GMT. No score threshold is inferred. K-means mode uses the object's native feature clusters; gene_sets.csv records the supplied GMT but the score columns are cluster programs in this mode.
