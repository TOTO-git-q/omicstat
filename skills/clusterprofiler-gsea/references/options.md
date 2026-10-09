# Options — clusterprofiler-gsea

Defaults are copied from the installed CLI's `parameters.md` flag table; that
file retains the locked function/vignette citations and conditional requirements.
No engine/default/test is changed. Keys are the exact parameter names in
`acceptance/exemplars/clusterprofiler-gsea/literature/extraction.jsonl`.
Before choosing scientific options, query `reference_advise` / `reference_search`;
observed literature values are context, never automatic defaults.

| option | locked default / vignette value | required? | S0 extraction parameter key |
|---|---|---|---|
| `--ranked` | none | no | none |
| `--ranking-metric` | none | no | ranking_metric |
| `--direction` | none | no | none |
| `--statistic-kind` | test_statistic | no | ranking_metric |
| `--lfc-type` | none | conditional; see parameters.md | ranking_metric |
| `--from-run` | none | no | none |
| `--outdir` | (required) | yes | none |
| `--spec` | none | no | none |
| `--database` | GO | no | gene_set_db |
| `--ontology` | BP | no | gene_set_db |
| `--key-type` | ENTREZID | no | none |
| `--min-size` | 10 | no | gs_size |
| `--max-size` | 500 | no | gs_size |
| `--exploratory-fdr` | off | no | enrich_cutoff |
| `--top-n` | 15 | no | none |
| `--seed` | 20260925 | no | none |
| `--journal` | nature | no | none |
| `--gene-sets` | none | conditional; see SKILL.md "User-supplied gene sets" | gene_set_db |
| `--gene-sets-provenance` | none | no | none |
| `--gene-sets-source` | none | conditional; see SKILL.md "User-supplied gene sets" | gene_set_db |
| `--gene-sets-version` | none | conditional; see SKILL.md "User-supplied gene sets" | gene_set_db |
| `--gene-sets-id-type` | none | conditional; see SKILL.md "User-supplied gene sets" | none |
| `--gene-sets-species` | none | no | none |
| `--gene-sets-name` | none | no | none |
| `--gene-sets-terms` | none | no | none |

`none` means no corresponding extraction key for this option. Fixed native
arguments, package versions and context-only extraction rows have no CLI option;
they remain unmapped rather than being assigned an unrelated flag. Conditional
requirements and refused inference options retain the behavior in parameters.md.
