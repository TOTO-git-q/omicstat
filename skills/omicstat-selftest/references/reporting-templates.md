# reporting-templates -- omicstat-selftest

The self-test is never reported in a manuscript. What may be quoted, e.g. in a lab notebook or an
issue report:

> The omicstat environment self-test (omicstat-selftest {module_version}, env_version
> {env_version}) ran in the {execution_mode} environment on {r_version_string}: {n_triggered} of
> {n_rules} rules triggered; verdict {PASS|FAIL} ({failed_rules}).

Placeholder map: `results/selftest_summary.json` (`module_version`, `env_version`,
`execution_mode`, `n_triggered`, `n_rules`, `environment_ok`, `failed_rules`) and
`provenance/provenance.json` (`r_version`).

Named failure modes:
- Quoting the fixture counts (up/down/NA) as a result. Correct form: they are a wiring check only
  (195 up, 175 down, 43 padj = NA at the default seed
  <!-- default --seed -->20260925<!-- /default -->; any other seed changes them).
- Calling a native PASS "identical to the container". Correct form: "same pins"; byte-level golden
  checks run on the container only.
