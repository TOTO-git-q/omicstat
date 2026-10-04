# Parameters

| Flag | Default | Allowed / reason |
|---|---|---|
| --input | none | See typed --help |
| --from-run | none | See typed --help |
| --upstream-object | expression_matrix | See typed --help |
| --outdir | required | See typed --help |
| --spec | none | See typed --help |
| --input-scale | required | See typed --help |
| --preprocessing | required | See typed --help |
| --outlier-rule | required | See typed --help |
| --samples | required | See typed --help |
| --traits | required | See typed --help |
| --power | required | See typed --help |
| --power-reason | required | See typed --help |
| --powers | 1,2,3,4,5,6,7,8,9,10,12,14,16,18,20 | See typed --help |
| --network-type | unsigned | See typed --help |
| --tom-type | signed | See typed --help |
| --min-module-size | none | See typed --help |
| --deep-split | 2 | See typed --help |
| --merge-height | 0.15 | See typed --help |
| --max-block-size | 5000 | See typed --help |
| --pam-respects-dendro | true | See typed --help |
| --reassign-threshold | 0.000001 | See typed --help |
| --seed | 20260925 | See typed --help |
| --journal | nature | See typed --help |

Missing min-module-size resolves the locked expression min(20,nGenes/2). All other fixed arguments and their locked formals are recorded in scripts/calls_registry.json. Pearson correlation and one thread are explicit. No biological sample filtering is automatic.

## 待裁决
Power, preprocessing, sample exclusions and biological interpretation need explicit user decisions. Tutorial part 2 power 6, unsigned TOM, minModuleSize 30, deepSplit 2, mergeCutHeight 0.25, reassignThreshold 0 and pamRespectsDendro FALSE are documented examples, not general recommendations.
