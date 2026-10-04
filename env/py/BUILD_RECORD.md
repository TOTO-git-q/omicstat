# omicstat-py build record

- host: toto-GT103 (docker 29.6.2, buildx 0.35.0); built 2026-09-29 (image Created 2026-09-29T02:49:08+09:00)
- image: omicstat-py:2026.09.1  id: sha256:dedf331e03f3832cbd069bd3c75af3ac1a6f4f1daf88eea6f72204a3b114b96f
  (built from env/ at 6945efd; env/py, env/py_lock.txt and env/omicstat-env.json are unchanged since)
- base: python:3.12.13-slim-bookworm@sha256:4766d8b510c428e595d74b9cc5bbb2fae8e26316fffb4adc89908d79aacd58a2
- pins: scanpy 1.12.4, anndata 0.13.3.post0, scvi-tools 1.5.1, torch 2.14.0+cpu (CPU index), Python 3.12.13
- lock: env/py/uv.lock (uv 0.11.24, exclude-newer 2026-09-16T00:00:00Z) -> env/py_lock.txt, 98 requirements,
  all with sha256; installed: env/py/py_installed.csv (99 distributions = 98 locked + pip)
- docker build: split 97 wheel / 1 sdist-only (docrep 0.3.2, built --no-build-isolation); `pip check`: no broken requirements;
  static image self-test inside the build: ALL PASSED (versions == lock, no extra distribution, CPU-only torch, threads = 1, PYTHONHASHSEED = 0)
- env/py/test.sh (in omicstat-py): ALL PASSED -- functional determinism (scanpy PCA / Leiden / UMAP and a 2-epoch scVI
  latent space bit-identical across two seeded runs), python_lane config, ospy unit tests, check_calls tests,
  new_module --python, check_calls + check_defaults + smoke test of omicstat-selftest-py (details: env/py/test_report.txt)
- env/test.sh (in omicstat-r, full existing suite + Python-lane tests incl. render_figure_request.R and cross-lane
  byte parity): ALL PASSED, 4 skipped for the absent acceptance data layer (identical to the baseline run)
- env/py/test_e2e.sh (MCP stdio on the GT103 host, container engine): 92 assertions, 91 passed, 1 failed, 3 skipped;
  the failure is `selftest/container: upstream_runs ends with this run` of the R self-test, reproduced on the unmodified
  base (finding F1 in docs/build/infra_python_worklog.md); all 29 Python-lane assertions pass (env/py/e2e_report.txt)
