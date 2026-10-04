# troubleshooting -- omicstat-selftest-py

| Symptom | Cause | Fix |
|---|---|---|
| `OS_ENV_MISSING: ... no usable "python" interpreter` | native engine without the Python venv | `bash env/py/setup_native.sh` (Linux x86_64) or use the container engine |
| PY-02 lists every package as absent | a plain host Python ran the module | run it through `bin/omicstat-r-route.sh python ...` (omicstat-py image) |
| PY-06 triggered (unmanaged) | the module ran outside both engines | same as above |
| `OS_FIG_LINT_BLOCKER` in the render step with `--journal cell` | the shared volcano's 5.5 pt labels are below Cell's 6 pt minimum | use `--journal science` (see parameters.md) |
| No `figures/` after a direct CLI run | Python modules do not draw; the R render step does | run `Rscript skills/_shared/scripts/render_figure_request.R --run-dir <outdir>` in omicstat-r (the MCP shell does this automatically) |

Expected, harmless console output: the "Seed set to ..." line that lightning prints when
`scvi.settings.seed` is set (it lands in `qc/engine_warnings.csv` as a message only when lightning
logs it through `logging`).
