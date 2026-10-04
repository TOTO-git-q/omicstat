# Parameters

| Flag | Default | Allowed / purpose | Source |
|---|---|---|---|
| --input | none | path: Raw counts for QC; chain-state Seurat RDS for other modules | locked formals / transport contract |
| --outdir | required | path: Run output directory | user_required |
| --spec | none | path: Replay prior provenance/resolved_spec.json | locked formals / transport contract |
| --seed | 20260925 | int: Recorded RNG seed | locked formals / transport contract |
| --journal | nature | enum: Figure preset | locked formals / transport contract |
| --input-format | 10x | enum: Count input format | locked formals / transport contract |
| --metadata | none | path: Optional cell metadata table with cell and sample columns | locked formals / transport contract |
| --sample | sample | string: Sample name when no metadata is supplied | locked formals / transport contract |
| --organism | required | string: Declared organism | user_required |
| --feature-type | required | string: Declared feature identifier type | user_required |
| --mito-pattern | required | string: Regular expression matching mitochondrial genes | user_required |
| --min-cells | required | int: Explicit count threshold; retention limits are strict except minimum UMI | user_required |
| --create-min-features | required | int: Explicit count threshold; retention limits are strict except minimum UMI | user_required |
| --min-features | required | int: Explicit count threshold; retention limits are strict except minimum UMI | user_required |
| --max-features | required | int: Explicit count threshold; retention limits are strict except minimum UMI | user_required |
| --min-counts | required | int: Explicit count threshold; retention limits are strict except minimum UMI | user_required |
| --max-counts | required | int: Explicit count threshold; retention limits are strict except minimum UMI | user_required |
| --max-mito | required | num: Explicit strict mitochondrial upper limit in percent | user_required |

All fixed package arguments and their locked function defaults are recorded in scripts/calls_registry.json. Every result-affecting argument is explicit at its call site. --help lists transport flags. Seed 20260925 follows the builder contract.

## 待裁决
Scientific choices not settled by documentation are required inputs. Tutorial values are examples, never silently chosen.

## Advanced options

Each advanced flag takes a JSON scalar or array (e.g. `false`, `0.3`, `"cosine"`, `[0.1,8]`). Omit it to use the locked default recorded below; JSON `null` passes NULL. For infinite cutoffs use the JSON string `"Inf"` or `"-Inf"`. These are passed directly to Seurat, which validates them. Structural object/assay/reduction names belong to the workflow.

| Flag | Default | Required? | S0 key |
|---|---|---|---|
| --create-names-field | none | no; effective default `1L` (locked function default; omitted CLI uses this value) | none |
| --create-names-delim | none | no; effective default `"_"` (locked function default; omitted CLI uses this value) | none |
| --create-project | none | no; effective default `"SeuratProject"` (locked function default; omitted CLI uses this value) | none |

| --missing-mito | error | error or explicit zero for a preselected matrix lacking mitochondrial genes | native zero from PercentageFeatureSet |
