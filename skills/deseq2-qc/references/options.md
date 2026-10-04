# Options — deseq2-qc

Defaults are copied from the installed CLI's `parameters.md` flag table; that
file retains the locked function/vignette citations and conditional requirements.
No engine/default/test is changed. Keys are the exact parameter names in
`acceptance/exemplars/deseq2-qc/literature/extraction.jsonl`.
Before choosing scientific options, query `reference_advise` / `reference_search`;
observed literature values are context, never automatic defaults.

| option | locked default / vignette value | required? | S0 extraction parameter key |
|---|---|---|---|
| `--counts` | (required) | yes | none |
| `--samples` | (required) | yes | none |
| `--outdir` | (required) | yes | none |
| `--spec` | none | no | none |
| `--sample-col` | sample | no | none |
| `--condition` | condition | no | none |
| `--shape-col` | none | no | none |
| `--covariates` | none | no | none |
| `--min-count` | 10 | no | prefilter |
| `--min-samples` | 0 | conditional; see parameters.md | prefilter |
| `--transform` | vst | no | transform |
| `--fit-type` | parametric | no | none |
| `--sf-type` | ratio | no | none |
| `--ntop` | 500 | no | pca_ntop |
| `--blind-false-supplement` | off | no | blind |
| `--seed` | 20260925 | no | none |
| `--journal` | nature | no | none |

`none` means no corresponding extraction key for this option. Fixed native
arguments, package versions and context-only extraction rows have no CLI option;
they remain unmapped rather than being assigned an unrelated flag. Conditional
requirements and refused inference options retain the behavior in parameters.md.
