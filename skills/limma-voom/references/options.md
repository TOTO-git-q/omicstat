# Options — limma-voom

Defaults are copied from the installed CLI's `parameters.md` flag table; that
file retains the locked function/vignette citations and conditional requirements.
No engine/default/test is changed. Keys are the exact parameter names in
`acceptance/exemplars/limma-voom/literature/extraction.jsonl`.
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
| `--condition` | condition | no | none |
| `--reference` | (required) | yes | none |
| `--target` | (required) | yes | none |
| `--covariates` | none | no | none |
| `--interface` | voomLmFit | no | voom_variant |
| `--sample-weights` | off | no | voom_variant |
| `--min-count` | 10 | no | filter |
| `--alpha` | 0.05 | no | padj_cutoff |
| `--min-effect-fc` | 1 | no | none |
| `--display-lfc-filter` | 0 | no | lfc_filter |
| `--label-n` | 5 | no | none |
| `--seed` | 20260925 | no | none |
| `--journal` | nature | no | none |

`none` means no corresponding extraction key for this option. Fixed native
arguments, package versions and context-only extraction rows have no CLI option;
they remain unmapped rather than being assigned an unrelated flag. Conditional
requirements and refused inference options retain the behavior in parameters.md.
