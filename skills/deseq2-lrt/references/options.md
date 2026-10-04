# Options — deseq2-lrt

Defaults are copied from the installed CLI's `parameters.md` flag table; that
file retains the locked function/vignette citations and conditional requirements.
No engine/default/test is changed. Keys are the exact parameter names in
`acceptance/exemplars/deseq2-lrt/literature/extraction.jsonl`.
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
| `--full` | (required) | yes | full_model, design_type |
| `--reduced` | (required) | yes | reduced_model |
| `--adjust` | none | no | design_type |
| `--group-col` | none | no | none |
| `--group-reference` | none | no | none |
| `--time-col` | none | no | none |
| `--min-count` | 10 | no | none |
| `--min-samples` | 0 | conditional; see parameters.md | none |
| `--alpha` | 0.05 | no | padj_cutoff |
| `--report-coef` | none | no | none |
| `--fit-type` | parametric | no | none |
| `--sf-type` | ratio | no | none |
| `--gene-annotation` | none | no | none |
| `--top-n` | 50 | no | none |
| `--pattern-clustering` | off | conditional; see parameters.md | pattern_clustering |
| `--seed` | 20260925 | no | none |
| `--journal` | nature | no | none |

`none` means no corresponding extraction key for this option. Fixed native
arguments, package versions and context-only extraction rows have no CLI option;
they remain unmapped rather than being assigned an unrelated flag. Conditional
requirements and refused inference options retain the behavior in parameters.md.
