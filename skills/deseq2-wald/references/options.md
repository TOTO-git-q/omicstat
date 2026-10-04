# Options — deseq2-wald

Defaults are copied from the installed CLI's `parameters.md` flag table; that
file retains the locked function/vignette citations and conditional requirements.
No engine/default/test is changed. Keys are the exact parameter names in
`acceptance/exemplars/deseq2-wald/literature/extraction.jsonl`.
Before choosing scientific options, query `reference_advise` / `reference_search`;
observed literature values are context, never automatic defaults.

| option | locked default / vignette value | required? | S0 extraction parameter key |
|---|---|---|---|
| `--counts` | none | no | none |
| `--samples` | none | no | none |
| `--from-run` | none | no | none |
| `--outdir` | (required) | yes | none |
| `--spec` | none | no | none |
| `--sample-col` | sample | no | none |
| `--condition` | condition | no | design |
| `--reference` | (required) | yes | design |
| `--target` | (required) | yes | design |
| `--covariates` | none | no | design |
| `--min-count` | 10 | no | prefilter |
| `--min-samples` | 0 | no | prefilter |
| `--alpha` | 0.05 | no | padj_cutoff |
| `--lfc-threshold` | 0 | no | lfc_threshold_test |
| `--display-lfc-filter` | 0 | no | lfc_filter |
| `--shrinkage` | apeglm | no | shrinkage |
| `--fit-type` | parametric | no | none |
| `--sf-type` | ratio | no | none |
| `--gene-annotation` | none | no | none |
| `--top-n` | 50 | no | none |
| `--label-n` | 10 | no | none |
| `--seed` | 20260925 | no | none |
| `--journal` | nature | no | none |

`none` means no corresponding extraction key for this option. Fixed native
arguments, package versions and context-only extraction rows have no CLI option;
they remain unmapped rather than being assigned an unrelated flag. Conditional
requirements and refused inference options retain the behavior in parameters.md.
