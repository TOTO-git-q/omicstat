# parameters -- omicstat-selftest

| Flag | Default | Allowed | Why |
|---|---|---|---|
| `--outdir` | (required) | writable directory | every module writes into one run directory; the MCP shell passes a UUID leaf |
| `--strict` | off (bare switch) | present / absent | lets scripts and CI fail on a broken environment; off by default so the report is always written and inspected |
| `--seed` | 20260925 | integer | seed of the synthetic fixture; changing it changes the table and figure, not the verdict |
| `--journal` | nature | nature, cell, science, generic | figure preset of the volcano (widths, font sizes; `_shared/docs/FIGURE_STYLE.md`) |
| `--help` | -- | -- | prints every flag and exits 0 |

Fixed internal values (not flags): fixture size 1,000 features; volcano thresholds adjusted P < 0.05
and |log2 fold change| > 1; figure width "single".
Flags are declared once in `run_omicstat_selftest.R` (`SPEC`, `_shared/scripts/args.R`): the same
spec prints `--help`, fills the defaults above and validates the values. `tools/check_defaults.py`
fails when this table, SKILL.md, the reporting templates and `--help` disagree on a default.
Typed errors: `OS_UNKNOWN_FLAG`, `OS_MISSING_PARAMETER` (no `--outdir`, or a flag without a value),
`OS_INVALID_PARAMETER` (non-integer seed, unknown journal, empty `--outdir`; the message says
expected vs got), `OS_CONFLICTING_PARAMETERS` (a flag given twice), `OS_MISSING_PACKAGE` (figure layer
cannot load; the QC table and environment report are still written), `OS_ENV_CHECK_FAILED`
(`--strict` and a blocker/error rule triggered).
