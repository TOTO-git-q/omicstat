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

## Optional selected-feature source views

- `--selected-features`: comma-separated actual feature IDs present in the retained normalized-count matrix. No default selection is invented.
- `--selection-reason`: required when features are selected; retained in the figure spec. Selected examples are not genome-wide performance evidence.
- `--subject-col`: optional actual biological-subject column, used only to deduplicate descriptive n. Sample points are not averaged or treated as extra subjects.
- `--pair-col`: optional true pair-ID column; no lines are drawn without it. More than one sample per pair/group must be explicitly aggregated upstream.

The model design, Wald P/q values and shrinkage are unchanged by these reporting
options. Subject/pair labels do not automatically adjust the fitted model. The
display uses actual DESeq2 normalized counts, retains linear-scale zeros, exports
all sample values and group counts, and includes only the existing model results.
It never adds a naive sample-level significance test.
