# Options — edger-qlf

Defaults are copied from the installed CLI's `parameters.md` flag table; that
file retains the locked function/vignette citations and conditional requirements.
No engine/default/test is changed. Keys are the exact parameter names in
`acceptance/exemplars/edger-qlf/literature/extraction.jsonl`.
Before choosing scientific options, query `reference_advise` / `reference_search`;
observed literature values are context, never automatic defaults.

| option | locked default / vignette value | required? | S0 extraction parameter key |
|---|---|---|---|
| `--counts` | none | no | none |
| `--samples` | none | conditional; see parameters.md | none |
| `--from-run` | none | no | none |
| `--outdir` | (required) | yes | none |
| `--spec` | none | no | none |
| `--sample-col` | sample | no | none |
| `--condition` | condition | no | none |
| `--reference` | (required) | yes | none |
| `--target` | (required) | yes | none |
| `--covariates` | none | no | none |
| `--min-count` | 10 | no | filter |
| `--min-total-count` | 15 | no | filter |
| `--large-n` | 10 | no | filter |
| `--min-prop` | 0.7 | no | filter |
| `--alpha` | 0.05 | no | padj_cutoff |
| `--treat-fc` | 0 | no | treat |
| `--display-lfc-filter` | 0 | no | lfc_filter |
| `--legacy` | off | no | none |
| `--gene-annotation` | none | no | none |
| `--top-n` | 50 | no | none |
| `--label-n` | 10 | no | none |
| `--seed` | 20260925 | no | none |
| `--journal` | nature | no | none |

`none` means no corresponding extraction key for this option. Fixed native
arguments, package versions and context-only extraction rows have no CLI option;
they remain unmapped rather than being assigned an unrelated flag. Conditional
requirements and refused inference options retain the behavior in parameters.md.
