# Options and locked evidence

| option | locked default / vignette value | required? | S0 extraction parameter key |
|---|---|---|---|
| --sets-source | required source/version | yes | none |
| --sets-licence | required licence/permission | yes | none |
| --accept-licence | required user-permitted | yes | none |
| --input | none; local SCE RDS | no | none |
| --from-run | none; upstream single-cell run | no | none |
| --outdir | none; output directory | yes | none |
| --spec | none; resolved spec replay | no | none |
| --cluster-col | none; group metadata for score distributions; scientific grouping choice | yes | none |
| --assay | none; expression assay counts or logcounts; rankings are monotonic-transform invariant except ties | yes | input_assay |
| --sets-file | required user offline GMT | yes | gene_set_source |
| --auc-max-rank | none; rank window; native default ceiling(0.05 * genes); check detected-gene distribution | no | auc_max_rank |
| --norm-auc | "TRUE"; native AUC normalization | no | norm_auc |
| --keep-zeroes-as-na | "FALSE"; native zero handling | no | keep_zeroes_as_na |
| --split-by-blocks | "FALSE"; native blocked ranking | no | split_by_blocks |
| --counts-layer | none; required counts source layer for conversion | no | none |
| --logcounts-layer | none; required normalized source layer for conversion | no | none |
| --source-assay | none; Seurat source assay for explicit conversion | no | none |
| --ranking-args | none; supplementary native ranking arguments | no | none |
| --auc-args | none; supplementary native AUC arguments | no | none |
| --seed | 333; explicit random seed | no | none |
| --journal | "nature"; figure preset | no | none |
| --gene-sets-provenance | none | no | none |
| --gene-sets-source | none | conditional; see SKILL.md "User-supplied gene sets" | gene_set_db |
| --gene-sets-version | none | conditional; see SKILL.md "User-supplied gene sets" | gene_set_db |
| --gene-sets-id-type | none | conditional; see SKILL.md "User-supplied gene sets" | none |
| --gene-sets-species | none | no | none |
| --gene-sets-name | none | no | none |
| --gene-sets-terms | none | no | none |
| --feature-id-type | none | conditional; see SKILL.md "User-supplied gene sets" | none |

Supplementary named JSON files expose every native argument, including delegated arguments. Omitted keys keep locked defaults; primary CLI options take precedence. calls_registry.json records container-read defaults. Every scientific choice must be informed by reference_advise and reference_search; absent curated evidence, show the official example and ask the user.

`--sets-file` is required; the bundled GPL-3 AUCell example is the smoke fixture. User-provided collections require matching identifiers and explicit permitted source/licence declarations. KEGG, CADD, PanglaoDB and DepMap are never bundled; an undeclared file naming them is refused, while a file the user obtained is accepted when declared through the user-supplied provenance contract (`--gene-sets-provenance` or `--gene-sets-version` + `--gene-sets-id-type`, with `--feature-id-type`).
