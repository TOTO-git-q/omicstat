# Options and reference-service evidence keys

| option | locked default / vignette value | required? | S0 extraction parameter key |
|---|---|---|---|
| --input | none | no | none |
| --from-run | none | no | none |
| --outdir | required | yes | none |
| --spec | none | no | none |
| --seed | 20260925; example 1 for tutorial/native score replay; suite contract 20260925 | no | seed |
| --journal | nature | no | none |
| --gene-sets | required; example cc.genes S and G2M (tutorial; caller GMT) | yes | gene_set |
| --set-organism | required; example Mus_musculus | yes | none |
| --nbin | 24 | no | nbin |
| --ctrl | 100; example 43 for CellCycleScoring replay; direct AddModuleScore default 100 | no | ctrl |
| --pool | none | no | pool |
| --assay | none | no | assay |
| --slot | data | no | slot |
| --name | Cluster | no | name |
| --k | false | no | k |
| --kmeans-object | none | no | kmeans_obj |
| --gene-sets-provenance | none | no | none |
| --gene-sets-source | none | conditional; see SKILL.md "User-supplied gene sets" | gene_set_db |
| --gene-sets-version | none | conditional; see SKILL.md "User-supplied gene sets" | gene_set_db |
| --gene-sets-id-type | none | conditional; see SKILL.md "User-supplied gene sets" | none |
| --gene-sets-species | none | no | none |
| --gene-sets-name | none | no | none |
| --gene-sets-terms | none | no | none |
| --feature-id-type | none | conditional; see SKILL.md "User-supplied gene sets" | none |

Provide an offline GMT with set name, source/version and membership for the declared organism. The tutorial uses cc.genes, not cc.genes.updated.2019; do not substitute a list silently. nbin groups genes by mean expression; ctrl selects controls per member. Use pool only with a justified background, assay/slot consistent with the supplied gene program, and k=true only with a native DoKMeans object. Raw scores are relative to matched controls; there is no universal zero cutoff or cross-set scale. The direct function default ctrl=100 differs from the CellCycleScoring wrapper ctrl=min(lengths(sets))=43.

Sources: locked PACK C/D and archived PBMC, Harmony Seurat, or cell-cycle tutorial. Advanced flags accept JSON values; package call defaults and the exact forwarded expressions are in calls_registry.json. Transport parameters are suite contracts. No literature counts determine defaults.
