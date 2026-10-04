# troubleshooting -- omicstat-selftest

| Symptom | Cause | Fix |
|---|---|---|
| ST-01 FAIL "R 4.x does not match the pinned R 4.6.1" | plain `Rscript` on a system R | run through bin/omicstat-r-route.sh (container) or build the native env with R 4.6 |
| ST-02 FAIL "Bioconductor 3.18 does not match 3.23" | a system BiocManager bound to an older R | use the container, or env/native/setup_native.R with R 4.6 |
| ST-03 warn "LC_CTYPE was C" | minimal shell without LANG | `export LANG=C.UTF-8` (the container sets it) |
| ST-04 warn "Not set to 1" | R started without the router | start through the router, or export the three variables as 1 |
| ST-05 FAIL font not resolvable | fonts-liberation missing | install it and run `fc-cache -f` |
| ST-06 blocker / `OS_MISSING_PACKAGE` | figure packages not in the library | install the L7_figures layer; the report still lists which packages are missing |
| ST-07 FAIL "unmanaged R session" | neither engine was used | `bin/omicstat-r-route.sh Rscript ...` or `OMICSTAT_R_NATIVE=1` |
| ST-08 blocker library leak | R_LIBS/R_LIBS_USER set, or R_PROFILE_USER not pointing at env/native/Rprofile.omicstat | unset the overrides; start through the router |
| `OS_ENV_MISSING` from the router | no native environment file | `Rscript env/native/setup_native.R`, or point OMICSTAT_NATIVE_ENV at a native-env.json |
| `OS_ENV_CHECK_FAILED` exit 1 | `--strict` and a blocker/error rule triggered | read environment_report.md; drop `--strict` to only report |
| `OS_FIG_LINT_BLOCKER: FIG-01 ... cell minimum 6 pt` with `--journal cell` | the shared volcano draws gene labels at 5.5 pt, below the Cell preset minimum (a `_shared` figure-layer issue, not an environment fault) | use `--journal nature`, `science` or `generic` until the shared layer is fixed |
| `OS_ENGINE_WARNING: [stage] ...` on stderr | a warning raised inside a stage (compute, qc, render, provenance) | read `qc/engine_warnings.csv`; the run still finished, but the warning names the step to check |
