# qc-rules -- omicstat-selftest-py

Written to `qc/qc_results.csv`, one row per rule whether triggered or not. A triggered rule of
severity blocker or error makes the verdict FAIL (and `--strict` exit 1).

| Rule | Check | Severity | Triggered when | Action |
|---|---|---|---|---|
| PY-01 | python_version | error (warning at patch level) | Python major.minor differs from `python_lane.python_version`, or the pins cannot be read | use the omicstat-py image or `env/py/setup_native.sh` with the pinned Python |
| PY-02 | pinned_packages | error | scanpy, anndata, scvi-tools or torch is absent, not importable, or not at its pin | rebuild the image (`env/py/build.sh`) or the native venv |
| PY-03 | torch_cpu_only | error | the installed torch is not a `+cpu` build or sees CUDA | install torch only from the CPU index (the lock does) |
| PY-04 | single_thread | warning | any of OMP/OPENBLAS/MKL/NUMBA_NUM_THREADS is not 1 | run through `bin/omicstat-r-route.sh python ...` |
| PY-05 | determinism | error | after `set_seed`, torch deterministic algorithms are off or torch uses more than one thread | check the torch build |
| PY-06 | execution_environment | error | neither the omicstat-py container nor the native venv runs the module; the message always names the environment | start through the router |
| PY-07 | feature_table | error | the written feature table does not validate or a second write is not byte-identical | run `skills/_shared/py/tests/test_ospy.py` |
| PY-08 | handoff | error | `objects/handoff.json` does not read back (sha256, types, ecosystem scverse) | run `skills/_shared/py/tests/test_ospy.py` |
| PY-09 | figure_request | error | `figure_data/figure_request.json` and its data files disagree | run `skills/_shared/py/tests/test_ospy.py` |
| PY-10 | anndata_object | error | the synthetic AnnData object is not written to / read back from `objects/adata.h5ad` | see PY-02 |
