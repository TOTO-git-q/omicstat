# omicstat-py -- the Python (scverse) environment (ENGINEERING_PLAN 10.4 lock 1)

Second image of the suite, next to `omicstat-r` (unchanged). The only pin source is the
`python_lane` block of [`../omicstat-env.json`](../omicstat-env.json).

| Item | Value | Basis |
|---|---|---|
| Python | 3.12.13, `python:3.12.13-slim-bookworm@sha256:4766d8b5...` | newest 3.12 on or before 2026-09-15 (3.12.14 appeared 2026-09-19); scanpy/anndata/scvi-tools need >= 3.12 |
| scanpy | 1.12.4 (+ `[leiden]`: igraph, leidenalg) | newest STABLE PyPI release <= 2026-09-15 (1.13.0a2 is a pre-release) |
| anndata | 0.13.3.post0 | idem (0.13.4 is 2026-09-18) |
| scvi-tools | 1.5.1 | idem |
| torch | 2.14.0+cpu | CPU-only wheel from download.pytorch.org/whl/cpu (explicit index, torch only) |
| transitive deps | `uv.lock` | resolved with `exclude-newer = 2026-09-16T00:00:00Z`, linux x86_64 only |
| threads | OMP/OPENBLAS/MKL/NUMBA/NUMEXPR/VECLIB = 1, PYTHONHASHSEED=0 | lock 4 |

Files: `pyproject.toml` (resolver input), `uv.lock` (every file sha256), `../py_lock.txt` (its pip
export, installed with `pip --require-hashes --no-deps`; docrep, the only sdist-only package, is
built with `--no-build-isolation` against the hash-locked setuptools), `Dockerfile` (context `env/`),
`py_installed.csv` + `image_id.txt` (written by `build.sh`), `BUILD_RECORD.md`.

```bash
bash env/py/lock.sh        # only when a pin changes (uv == python_lane.locker)
bash env/py/build.sh       # build omicstat-py:<image_tag>; static self-test runs inside the build
bash env/py/test.sh        # in the image: functional determinism self-test + Python-lane tests
bash env/py/test_e2e.sh    # on the docker host: MCP stdio, python in omicstat-py -> R render in omicstat-r
bash env/py/setup_native.sh [python3.12]   # native venv (.omicstat-r/py-venv) + "python" key in native-env.json
```

Change rule: any value in `python_lane` -> new `py_env_version` + `image_tag` -> relock/rebuild ->
rerun the Python golden baselines (plan 10.9: the two images are pinned together in one file).
