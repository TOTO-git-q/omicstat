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

All fixed package arguments and their locked function defaults are recorded in scripts/calls_registry.json. Every result-affecting argument is explicit at its call site. --help lists transport flags. Seed 20260925 follows the builder contract.

## 待裁决
Scientific choices not settled by documentation are required inputs. Tutorial values are examples, never silently chosen.

| --assay | none | upstream normalized assay; RNA or SCT | locked default NULL |
| --slot | data | data, counts, scale.data | locked default |
| --name | Cluster | native score prefix | locked default |
| --k | false | false or true with a DoKMeans RDS | locked default |
| --kmeans-object | none | DoKMeans RDS when k=true | user input |

Online HGNC search is disabled under the offline analysis contract (search=FALSE). Supply an already mapped GMT. No score threshold is inferred. K-means mode uses the object's native feature clusters; gene_sets.csv records the supplied GMT but the score columns are cluster programs in this mode.
