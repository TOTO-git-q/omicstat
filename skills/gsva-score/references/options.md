# Options — gsva-score

Defaults are copied from the installed CLI's `parameters.md` flag table; that
file retains the locked function/vignette citations and conditional requirements.
No engine/default/test is changed. Keys are the exact parameter names in
`acceptance/exemplars/gsva-score/literature/extraction.jsonl`.
Before choosing scientific options, query `reference_advise` / `reference_search`;
observed literature values are context, never automatic defaults.

| option | locked default / vignette value | required? | S0 extraction parameter key |
|---|---|---|---|
| `--input` | none | no | input |
| `--from-run` | none | no | none |
| `--upstream-object` | none | no | none |
| `--outdir` | required | yes | none |
| `--spec` | none | no | none |
| `--input-scale` | required | yes | input |
| `--kcdf` | auto | no | kcdf |
| `--collection` | msigdb_collections | no | gene_set_db |
| `--gene-sets` | none | no | gene_set_db |
| `--min-size` | 5 | no | gs_size |
| `--max-size` | 500 | no | gs_size |
| `--samples` | none | no | none |
| `--sample-col` | sample | no | none |
| `--group-col` | condition | no | none |
| `--reference` | none | no | downstream_test |
| `--target` | none | no | downstream_test |
| `--covariates` | none | no | downstream_test |
| `--seed` | 20260925 | no | none |
| `--journal` | nature | no | none |
| `--gene-sets-provenance` | none | no | none |
| `--gene-sets-source` | none | conditional; see SKILL.md "User-supplied gene sets" | gene_set_db |
| `--gene-sets-version` | none | conditional; see SKILL.md "User-supplied gene sets" | gene_set_db |
| `--gene-sets-id-type` | none | conditional; see SKILL.md "User-supplied gene sets" | none |
| `--gene-sets-species` | none | no | none |
| `--gene-sets-name` | none | no | none |
| `--gene-sets-terms` | none | no | none |
| `--feature-id-type` | none | conditional; see SKILL.md "User-supplied gene sets" | none |

`none` means no corresponding extraction key for this option. Fixed native
arguments, package versions and context-only extraction rows have no CLI option;
they remain unmapped rather than being assigned an unrelated flag. Conditional
requirements and refused inference options retain the behavior in parameters.md.
