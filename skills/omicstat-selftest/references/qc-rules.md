# qc-rules -- omicstat-selftest

Written to `qc/qc_results.csv`, one row per rule whether triggered or not. A triggered rule of
severity blocker or error makes the verdict FAIL (and `--strict` exit 1); `blocking = TRUE` only
for triggered blockers.

| Rule | Check | Severity | Triggered when | Action |
|---|---|---|---|---|
| ST-01 | r_version | error (warning at patch level) | R major.minor differs from `r_version` in env/omicstat-env.json, or the file cannot be read; patch-only difference = warning | use the container or a native R of the pinned major.minor |
| ST-02 | bioconductor | error (warning when BiocManager is missing outside the container) | `BiocManager::version()` differs from `bioconductor`; BiocManager missing = warning outside the container, error inside | rebuild the image / re-run env/native/setup_native.R |
| ST-03 | utf8_locale | warning (error if no UTF-8 locale exists) | LC_CTYPE at start is not UTF-8; error when the figure layer could not switch to one either | set LANG/LC_ALL=C.UTF-8 |
| ST-04 | single_thread | warning | any of OMP_NUM_THREADS, OPENBLAS_NUM_THREADS, MKL_NUM_THREADS is not 1 | run through the router, or export them as 1 |
| ST-05 | font | error | "Liberation Sans" is not a systemfonts family | install fonts-liberation, `fc-cache -f` |
| ST-06 | figure_packages | blocker | a required figure-layer package does not load | install the L7_figures layer / re-run setup_native.R |
| ST-07 | execution_environment | error | neither `OMICSTAT_CONTAINER=1` nor `OMICSTAT_R_LIBS` is set (unmanaged R); the message always names the environment | start R through bin/omicstat-r-route.sh |
| ST-08 | library_isolation | blocker | native environment only: `.libPaths()` contains a path other than `OMICSTAT_R_LIBS` and `.Library` | start R with R_PROFILE_USER=env/native/Rprofile.omicstat; drop R_LIBS overrides |
