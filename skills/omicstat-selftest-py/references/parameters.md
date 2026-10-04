# parameters -- omicstat-selftest-py

Human-readable version of `--help` (`python scripts/run_omicstat_selftest_py.py --help`). No
registered call exists (see `scripts/calls_registry.json`), so no PACK section applies.

| Flag | Default | Meaning |
|---|---|---|
| `--outdir` | required | output directory (the MCP shell allocates a UUID leaf under it) |
| `--strict` | off | bare switch: exit 1 with `OS_ENV_CHECK_FAILED` when a blocker or error rule is triggered |
| `--seed` | 20260925 | seed of the synthetic fixtures, also passed to `ospy.seed.set_seed` |
| `--journal` | nature | figure preset (`nature`, `cell`, `science`, `generic`) handed to the R render step |
| `--from-run` | none | an earlier omicstat-selftest-py run to continue; exercises the `--from-run` handoff check (`OS_HANDOFF_*`, `OS_ECOSYSTEM_MIXED`) |
| `--spec` | none | replay `provenance/resolved_spec.json` of an earlier run; flags given on the command line win |

`--journal cell` fails the figure lint of the shared volcano (5.5 pt labels are below Cell's 6 pt
minimum), exactly as in omicstat-selftest; use `science` to exercise a non-default preset.
