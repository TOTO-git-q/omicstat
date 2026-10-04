# Options — fgsea-prerank

Defaults are copied from the installed CLI's `parameters.md` flag table; that
file retains the locked function/vignette citations and conditional requirements.
No engine/default/test is changed. Keys are the exact parameter names in
`acceptance/exemplars/fgsea-prerank/literature/extraction.jsonl`.
Before choosing scientific options, query `reference_advise` / `reference_search`;
observed literature values are context, never automatic defaults.

| option | locked default / vignette value | required? | S0 extraction parameter key |
|---|---|---|---|
| `--ranked-list` | none | no | none |
| `--from-run` | none | no | none |
| `--outdir` | required | yes | none |
| `--spec` | none | no | none |
| `--rank-metric` | wald_stat | no | ranking_metric |
| `--metric-name` | none | conditional; see parameters.md | ranking_metric |
| `--direction` | none | conditional; see parameters.md | none |
| `--collection` | msigdb_collections | no | gene_set_db |
| `--gene-sets` | none | no | gene_set_db |
| `--min-size` | 15 | no | gs_size |
| `--max-size` | 500 | no | gs_size |
| `--alpha` | 0.05 | no | enrich_cutoff |
| `--seed` | 20260925 | no | none |
| `--journal` | nature | no | none |

`none` means no corresponding extraction key for this option. Fixed native
arguments, package versions and context-only extraction rows have no CLI option;
they remain unmapped rather than being assigned an unrelated flag. Conditional
requirements and refused inference options retain the behavior in parameters.md.
