# reporting-templates -- omicstat-selftest-py

The self-test is never reported in a manuscript. The engine fills the two blocks below into
`draft/methods_results.md` (same text as shown here; `ospy.module_kit.fill_template`).

```template methods
The omicstat Python-lane self-test ({module} {module_version}) compared the running interpreter with the pins in env/omicstat-env.json (py_env_version {py_env_version}; running Python {python_version}) using {n_rules} rules (PY-01 to PY-10). Deterministic synthetic fixtures ({n_features} features and {n_cells} cells, seed {seed}) were written with the shared Python layer (feature table, AnnData object, --from-run handoff) and requested as two figures (a volcano plot at adjusted P < {padj} and |log2 fold change| > {lfc}, and a UMAP-style embedding) that the R figure layer renders with the {journal} preset.
```

```template results
The self-test ran in the {execution_mode} environment: {n_triggered} of {n_rules} rules triggered; verdict {verdict}. The fixture numbers are a wiring check only and are never findings.
```

Named failure modes:
- Quoting the fixture counts (up/down/NA) as a result. They are a wiring check only (default seed
  <!-- default --seed -->20260925<!-- /default -->; any other seed changes them).
- Calling a native PASS "identical to the container". Correct form: "same pins"; byte-level golden
  checks run on the container only.
