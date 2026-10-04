# method-basis -- omicstat-selftest

The self-test runs no statistical method. Each check reads one fact of the running R session and
compares it with the environment contract in `env/omicstat-env.json` (ENGINEERING_PLAN lock 1).

| Check | What is read | Source of the expectation |
|---|---|---|
| R version | `getRversion()` | `r_version` in env/omicstat-env.json |
| Bioconductor | `BiocManager::version()` (offline) | `bioconductor` in env/omicstat-env.json |
| UTF-8 locale | `Sys.getlocale("LC_CTYPE")`, `l10n_info()` before the figure layer loads | env/container/Dockerfile (`LANG=C.UTF-8`) |
| Single thread | `OMP_NUM_THREADS`, `OPENBLAS_NUM_THREADS`, `MKL_NUM_THREADS` | `threads: 1` in env/omicstat-env.json |
| Font | `systemfonts::system_fonts()$family` contains "Liberation Sans" | `OS_FIG$font_family_preference` in `_shared/scripts/fig_style.R` |
| Figure packages | `requireNamespace()` of ggplot2, ggrepel, patchwork, ragg, systemfonts, scales, jsonlite, digest | `_shared/scripts/fig_*.R`, `handoff.R` |
| Environment | `OMICSTAT_CONTAINER=1` (set in the image) or `OMICSTAT_R_LIBS` (set by the native router) | bin/omicstat-r-route.sh, env/native/Rprofile.omicstat |
| Library isolation | `.libPaths()` vs `OMICSTAT_R_LIBS` + `.Library` | env/native/Rprofile.omicstat |

The end-to-end part (feature table -> volcano -> handoff) uses the shared SHAPE fixture
`skills/_shared/tests/fixtures/fig_fixtures.R::fx_feature_table(1000, seed)` (n must exceed the
500 planted DE features), `write_feature_table`, `os_volcano`, `os_finalize_figure` and
`write_handoff`, so a PASS also proves those shared layers run in this environment.
