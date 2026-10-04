---
name: omicstat-selftest
description: >
  Check that the omicstat R environment is installed correctly and produce an environment report,
  a QC rule table (ST-01..ST-08), a synthetic feature table, a volcano figure, a provenance record
  and a handoff file that prove the shared table, figure and --from-run layers work end to end.
  Compares the running R session with env/omicstat-env.json (R and Bioconductor versions), and
  checks the UTF-8 locale, single-threaded numerics, the Liberation Sans figure font, the
  figure-layer packages, whether it runs in the omicstat-r container or the isolated native
  environment, and whether the native library path leaks. Use after building the container or
  running env/native/setup_native.R, before the first analysis, or when a module fails for an
  environment reason. NOT an analysis: its table and figure come from a synthetic fixture and are
  never findings (use an analysis module from the omicstat router). Triggers: omicstat self-test,
  environment check, 环境自检, 安装检查, is R set up, check the setup.
---
# omicstat-selftest

## When to use / when not
- Use right after `env/build.sh` (container) or `Rscript env/native/setup_native.R` (native), before
  the first analysis, and whenever a module fails with an environment-looking error (missing
  package, wrong font, locale, library leak).
- Not for analysing data: every number it writes comes from a synthetic shape fixture. For an
  analysis question go back to the router (`skills/omicstat/SKILL.md`) and pick the analysis module.
- Not a package-lock audit: it checks the R/Bioconductor pins and the figure-layer packages only;
  the full lock is `env/pkg_lock*.csv`.

## Input requirements
None. The "input" is the running R session. The module must sit inside an omicstat checkout
(`<suite>/skills/omicstat-selftest/`) so that `env/omicstat-env.json` can be read; inside the
container the copy under `OMICSTAT_ENV_DIR` is used as a fallback.

## Run
```
Rscript scripts/run_omicstat_selftest.R --outdir <dir> [--strict] [--seed <int>] [--journal nature|cell|science|generic]
```
Through the pinned environments: `bin/omicstat-r-route.sh Rscript skills/omicstat-selftest/scripts/run_omicstat_selftest.R --outdir <dir>`
(docker image), or the same with `OMICSTAT_R_NATIVE=1` (isolated native library).

### Via MCP
Call `omicstat_run` with `module="omicstat-selftest"` and the same flags as `args` (e.g.
`{"strict": true}`); read the result with `omicstat_read`.
`--help` lists every option; the ones that matter most:

| Flag | Default | Effect |
|---|---|---|
| `--outdir` | required | output directory (the MCP shell allocates a UUID leaf) |
| `--strict` | off | bare switch: exit non-zero (`OS_ENV_CHECK_FAILED`) when a blocker or error rule is triggered |
| `--seed` | 20260925 | seed of the synthetic fixture |
| `--journal` | nature | figure preset of the volcano plot |

Details: references/parameters.md.

## What gets produced
- `environment_report.md` -- the verdict (PASS/FAIL), every rule with status and action, session facts, library path, package versions. Read this first.
- `qc/qc_results.csv` -- one row per rule ST-01..ST-08 (`id, check, severity, triggered, blocking, message, action, evidence`)
- `qc/engine_warnings.csv` -- every warning / message / error raised inside a stage (`stage, type, message`; header only when clean); each warning is also printed to stderr as `OS_ENGINE_WARNING: [stage] ...`
- `tables/feature_table.csv` -- 1,000-feature synthetic feature table (feature_table schema, `_shared/scripts/feature_table.R`)
- `figures/volcano.pdf|png|figure_spec.json` -- drawn with `os_volcano` + `os_finalize_figure` (style: `_shared/docs/FIGURE_STYLE.md`)
- `draft/methods_results.md` -- short Methods/Results paragraph that says it is a self-test
- `results/selftest_summary.json` -- machine summary (verdict, rule counts, fixture counts)
- `provenance/provenance.json` -- command, R version, `.libPaths()`, env_version, seed, versions of every loaded package, output hashes
- `objects/handoff.json` + `objects/colour_registry.json` -- a `--from-run` handoff (ecosystem neutral)

The closing console line is `N of 8 rules triggered; read environment_report.md first`.

## Reading the results
- Verdict FAIL = at least one blocker or error rule triggered. Without `--strict` the run still
  exits 0 so the report is always written; with `--strict` it exits 1.
- Warnings (patch-level R difference, locale switched by the figure layer, thread variables not
  set, BiocManager missing outside the container) do not fail the check.
- The fixture counts (195 up, 175 down, 43 padj = NA at the default seed) are a wiring check, not
  a result. Never quote them as findings. See references/reporting-templates.md.

## When a QC rule fires
Rules `ST-01..ST-08` -- see references/qc-rules.md. Blockers: ST-06 (figure packages missing) and
ST-08 (native library path leaks outside the omicstat library). ST-07 names the execution
environment in every run (container / native / unmanaged).

## Known limitations
- In an unmanaged R session (plain `Rscript` outside both engines) ST-07 fails by design, and
  ST-08 is not applicable.
- Bioconductor is read with `BiocManager::version()` offline; a BiocManager that cannot map the R
  version reports it as unreadable (ST-02).
- `--journal cell` currently stops with `OS_FIG_LINT_BLOCKER` (the shared volcano's 5.5 pt labels
  are below the Cell 6 pt minimum); the other presets work.
- Byte-level golden checks of analysis modules apply to the container only; a PASS in the native
  environment means "same pins", not "byte-identical figures".

## Reference files
- references/method-basis.md -- what each check reads and why
- references/parameters.md -- every parameter value and why
- references/qc-rules.md -- rule id, severity, criterion, message, action
- references/reporting-templates.md -- how to quote a self-test result
- references/troubleshooting.md -- symptom -> cause -> fix
