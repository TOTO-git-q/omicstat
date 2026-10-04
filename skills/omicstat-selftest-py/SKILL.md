---
name: omicstat-selftest-py
description: >
  Check that the omicstat Python (scverse) environment is installed correctly and prove that the
  Python lane works end to end: argument whitelist and typed errors, the randomness lock, the
  shared feature table, an AnnData (.h5ad) object with a --from-run handoff in the scverse
  ecosystem, and a figure request that the R figure layer renders (volcano + embedding).
  Compares the running interpreter with env/omicstat-env.json (python_lane: Python, scanpy,
  anndata, scvi-tools, CPU-only torch) and checks single-threaded numerics, deterministic torch
  and the execution environment (omicstat-py container or native venv). Use after building the
  omicstat-py image or running env/py/setup_native.sh, before the first scverse analysis, or when
  a Python module fails for an environment reason. NOT an analysis: its table, object and figures
  come from synthetic fixtures and are never findings. Triggers: Python lane self-test, scverse
  environment check, omicstat-py, 环境自检, Python 环境检查, is scanpy set up.
---
# omicstat-selftest-py

## When to use / when not
- Use right after `bash env/py/build.sh` (container) or `bash env/py/setup_native.sh` (native),
  before the first scverse analysis, and whenever a Python module fails with an environment-looking
  error (missing package, wrong version, GPU torch, thread variables).
- Not for analysing data: every number comes from a synthetic shape fixture. For an analysis
  question go back to the router (`skills/omicstat/SKILL.md`).
- The R environment has its own self-test, `omicstat-selftest`; run both after a rebuild.

## Input requirements
None. The "input" is the running interpreter. The module must sit inside an omicstat checkout
(`<suite>/skills/omicstat-selftest-py/`) so that `env/omicstat-env.json` can be read; inside the
container the copy under `OMICSTAT_ENV_DIR` is the fallback.

## Run
```
python scripts/run_omicstat_selftest_py.py --outdir <dir> [--strict] [--seed <int>] [--journal nature|cell|science|generic] [--from-run <dir>] [--spec <resolved_spec.json>]
```
Through the pinned environments: `bin/omicstat-r-route.sh python skills/omicstat-selftest-py/scripts/run_omicstat_selftest_py.py --outdir <dir>`
(omicstat-py image), or the same with `OMICSTAT_R_NATIVE=1` (native venv). A direct run writes the
figure REQUEST only; draw the figures with
`bin/omicstat-r-route.sh Rscript skills/_shared/scripts/render_figure_request.R --run-dir <dir>`
(omicstat-r). The MCP shell does both steps.

### Via MCP
Call `omicstat_run` with `module="omicstat-selftest-py"` and the flags as `args` (e.g.
`{"strict": true}`); the shell runs the Python entry in omicstat-py, then the R render step in
omicstat-r, and returns one manifest. Read files with `omicstat_read`.

| Flag | Default | Effect |
|---|---|---|
| `--outdir` | required | output directory (the MCP shell allocates a UUID leaf) |
| `--strict` | off | bare switch: exit non-zero (`OS_ENV_CHECK_FAILED`) when a blocker or error rule is triggered |
| `--seed` | 20260925 | seed of the synthetic fixtures and of the randomness lock |
| `--journal` | nature | figure preset used by the R render step |
| `--from-run` | none | continue an earlier omicstat-selftest-py run (handoff check) |
| `--spec` | none | replay an earlier run's `provenance/resolved_spec.json` |

Details: references/parameters.md.

## What gets produced
- `environment_report.md` -- verdict (PASS/FAIL), every rule, session facts, pinned packages. Read this first.
- `qc/qc_results.csv` -- one row per rule PY-01..PY-10 (`id, check, severity, triggered, blocking, message, action, evidence`)
- `qc/engine_warnings.csv` -- every warning / logging message / error raised inside a stage; each warning is also printed as `OS_ENGINE_WARNING: [stage] ...`
- `tables/feature_table.csv` -- 1,000-feature synthetic feature table (byte-identical to the R writer's format)
- `objects/adata.h5ad` + `objects/handoff.json` -- synthetic AnnData (300 cells x 40 genes, `obs.cluster`, `obsm.X_umap`); handoff ecosystem `scverse`, object type `AnnData`
- `figure_data/*.csv` + `figure_data/figure_request.json` -- the data of two figures (volcano, embedding)
- after the R render step: `figures/volcano.*`, `figures/umap_clusters.*` (pdf, png, figure_spec.json), `objects/colour_registry.json`, `qc/render_warnings.csv`, `provenance/figure_render.json`
- `draft/methods_results.md` -- Methods/Results paragraph that says it is a self-test
- `results/selftest_summary.json` -- machine summary (verdict, rule counts, fixture counts)
- `provenance/provenance.json` + `provenance/resolved_spec.json` -- command, Python environment, package versions, seed record, output hashes, the render step

The closing console line is `N of 10 rules triggered; read environment_report.md first`.

## Reading the results
- Verdict FAIL = at least one blocker or error rule triggered. Without `--strict` the run still
  exits 0 so the report is always written; with `--strict` it exits 1.
- The fixture counts in `results/selftest_summary.json` are a wiring check, never a result.

## When a QC rule fires
Rules `PY-01..PY-10` -- see references/qc-rules.md. PY-06 names the execution environment in every
run (container / native / unmanaged); a plain host Python fails PY-02 and PY-06 by design.

## Known limitations
- The figures exist only after the R render step (the MCP shell runs it; a direct CLI run does not).
- Golden baseline: none recorded (tests/golden_manifest.csv holds the header only), as for
  omicstat-selftest; the smoke test checks rerun byte-identity instead.
- See references/troubleshooting.md.

## Reference files
- references/method-basis.md -- what each exercised piece implements
- references/parameters.md -- every flag
- references/qc-rules.md -- PY-01..PY-10
- references/reporting-templates.md -- the draft templates
- references/troubleshooting.md -- common errors
