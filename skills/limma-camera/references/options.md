# Options — limma-camera

Defaults are copied from the installed CLI's `parameters.md` flag table; that
file retains the locked function/vignette citations and conditional requirements.
No engine/default/test is changed. Keys are the exact parameter names in
`acceptance/exemplars/limma-camera/literature/extraction.jsonl`.
Before choosing scientific options, query `reference_advise` / `reference_search`;
observed literature values are context, never automatic defaults.

| option | locked default / vignette value | required? | S0 extraction parameter key |
|---|---|---|---|
| `--input` | none | no | expression_input |
| `--ranked-list` | none | no | none |
| `--from-run` | none | no | none |
| `--upstream-object` | none | no | none |
| `--outdir` | required | yes | none |
| `--spec` | none | no | none |
| `--question` | required | yes | test |
| `--self-contained-method` | none | no | test |
| `--set-id` | none | no | none |
| `--collection` | msigdb_collections | no | gene_set_db |
| `--gene-sets` | none | conditional; see parameters.md | gene_set_db |
| `--input-scale` | none | conditional; see parameters.md | expression_input |
| `--samples` | none | no | none |
| `--sample-col` | sample | no | none |
| `--group-col` | condition | no | none |
| `--reference` | none | no | none |
| `--target` | none | no | none |
| `--covariates` | none | no | none |
| `--weights` | none | no | none |
| `--block-col` | none | no | none |
| `--correlation` | none | no | none |
| `--acknowledge-block-ignored` | off | no | none |
| `--rank-metric` | wald_stat | no | none |
| `--metric-name` | none | conditional; see parameters.md | none |
| `--direction` | none | no | none |
| `--alpha` | 0.05 | no | enrich_cutoff |
| `--nrot` | 9999 | no | none |
| `--seed` | 20260925 | no | none |
| `--journal` | nature | no | none |

`none` means no corresponding extraction key for this option. Fixed native
arguments, package versions and context-only extraction rows have no CLI option;
they remain unmapped rather than being assigned an unrelated flag. Conditional
requirements and refused inference options retain the behavior in parameters.md.
