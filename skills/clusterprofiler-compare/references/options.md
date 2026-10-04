# Options — clusterprofiler-compare

Defaults are copied from the installed CLI's `parameters.md` flag table; that
file retains the locked function/vignette citations and conditional requirements.
No engine/default/test is changed. Keys are the exact parameter names in
`acceptance/exemplars/clusterprofiler-compare/literature/extraction.jsonl`.
Before choosing scientific options, query `reference_advise` / `reference_search`;
observed literature values are context, never automatic defaults.

| option | locked default / vignette value | required? | S0 extraction parameter key |
|---|---|---|---|
| `--manifest` | (required) | yes | clusters |
| `--outdir` | (required) | yes | none |
| `--spec` | none | no | none |
| `--database` | GO | no | gene_set_db |
| `--ontology` | BP | no | gene_set_db |
| `--pool` | none | conditional; see parameters.md | none |
| `--key-type` | ENTREZID | no | none |
| `--min-size` | 10 | no | none |
| `--max-size` | 500 | no | none |
| `--top-n-per-group` | 5 | no | none |
| `--seed` | 20260925 | no | none |
| `--journal` | nature | no | none |

`none` means no corresponding extraction key for this option. Fixed native
arguments, package versions and context-only extraction rows have no CLI option;
they remain unmapped rather than being assigned an unrelated flag. Conditional
requirements and refused inference options retain the behavior in parameters.md.
