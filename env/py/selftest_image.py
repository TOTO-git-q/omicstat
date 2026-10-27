#!/usr/bin/env python3
"""Self-test of the omicstat-py image (ENGINEERING_PLAN 10.8 item 1).

Usage: python selftest_image.py --static        (run at the end of docker build)
       python selftest_image.py --functional    (docker run; needs the checkout
                                                  at /omicstat for skills/_shared/py)

--static      Python version == pin; every env/py_lock.txt requirement is
              installed at exactly its locked version and nothing else is
              (pip itself excepted); the four scverse pins import and report
              the pinned versions; torch is a CPU-only build; the thread
              variables are 1.
--functional  --static plus determinism on this platform: a tiny scanpy chain
              (normalize_total, log1p, highly_variable_genes, pca, neighbors,
              leiden, umap) and a tiny scVI fit (2 epochs) are each run twice
              with the same seed through skills/_shared/py/ospy/seed.py, and
              the outputs must be bit-identical.
Prints PASS/FAIL lines; exit 0 only when everything passed. ASCII only.
"""
import argparse
import importlib
import importlib.metadata as md
import json
import os
import pathlib
import platform
import re
import sys

FAILS = []
CFG_CANDIDATES = [pathlib.Path("/omicstat/env/py/py-env.json"),
                  pathlib.Path(os.environ.get("OMICSTAT_ENV_DIR", "/opt/omicstat/env")) / "py" / "py-env.json"]
LOCK_CANDIDATES = [pathlib.Path("/omicstat/env/py_lock.txt"),
                   pathlib.Path(os.environ.get("OMICSTAT_ENV_DIR", "/opt/omicstat/env")) / "py_lock.txt"]
IMPORT_NAME = {"scvi-tools": "scvi"}
THREAD_VARS = ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS", "NUMBA_NUM_THREADS")


def check(cond, msg):
    print(("PASS: " if cond else "FAIL: ") + msg, flush=True)
    if not cond:
        FAILS.append(msg)
    return cond


def norm(name):
    return re.sub(r"[-_.]+", "-", name).lower()


def first(paths):
    for p in paths:
        if p.is_file():
            return p
    return None


def static_checks():
    cfg_path = first(CFG_CANDIDATES)
    if not check(cfg_path is not None, "omicstat-env.json found (%s)" % ", ".join(map(str, CFG_CANDIDATES))):
        return
    cfg = json.loads(cfg_path.read_text(encoding="utf-8"))
    check(platform.python_version() == cfg["python_version"],
          "Python %s == pin %s" % (platform.python_version(), cfg["python_version"]))
    lock_path = first(LOCK_CANDIDATES)
    if check(lock_path is not None, "py_lock.txt found"):
        want = {}
        for m in re.finditer(r"^([A-Za-z0-9_.-]+)==([^ ;\\\n]+)", lock_path.read_text(encoding="utf-8"), re.M):
            want[norm(m.group(1))] = m.group(2)
        have = {norm(d.metadata["Name"]): d.version for d in md.distributions()}
        wrong = sorted("%s (lock %s, installed %s)" % (n, v, have.get(n, "absent"))
                       for n, v in want.items() if have.get(n) != v)
        extra = sorted(set(have) - set(want) - {"pip"})
        check(not wrong, "every locked distribution installed at its locked version (%d)%s"
              % (len(want), "" if not wrong else ": " + "; ".join(wrong[:8])))
        check(not extra, "no distribution outside the lock (pip excepted)%s" % ("" if not extra else ": " + ", ".join(extra[:8])))
    for dist, ver in cfg["pins"].items():
        mod = IMPORT_NAME.get(dist, dist)
        try:
            m = importlib.import_module(mod)
            got = getattr(m, "__version__", md.version(dist))
            check(got == ver or md.version(dist) == ver, "import %s -> %s == pin %s" % (mod, got, ver))
        except Exception as exc:                                  # noqa: BLE001
            check(False, "import %s failed: %s: %s" % (mod, type(exc).__name__, exc))
    try:
        import torch
        check(torch.version.cuda is None and not torch.cuda.is_available() and "+cpu" in torch.__version__,
              "torch is a CPU-only build (%s, cuda=%s)" % (torch.__version__, torch.version.cuda))
    except Exception as exc:                                      # noqa: BLE001
        check(False, "torch probe failed: %s" % exc)
    for v in THREAD_VARS:
        check(os.environ.get(v) == "1", "%s=1 (got %r)" % (v, os.environ.get(v)))
    check(os.environ.get("PYTHONHASHSEED") == "0", "PYTHONHASHSEED=0")


def functional_checks():
    shared = pathlib.Path("/omicstat/skills/_shared/py")
    if not check(shared.is_dir(), "checkout mounted at /omicstat (skills/_shared/py)"):
        return
    sys.path.insert(0, str(shared))
    from ospy import seed as ospy_seed                        # noqa: PLC0415
    import warnings                                            # noqa: PLC0415
    import numpy as np                                         # noqa: PLC0415
    import anndata as ad                                       # noqa: PLC0415
    import scanpy as sc                                        # noqa: PLC0415

    def toy(seed):
        rng = np.random.default_rng(seed)
        n_cells, n_genes = 300, 200
        centers = rng.gamma(2.0, 1.0, size=(3, n_genes))
        grp = np.repeat([0, 1, 2], n_cells // 3)
        counts = rng.poisson(centers[grp] * 2.0).astype(np.float32)
        a = ad.AnnData(counts)
        a.obs_names = ["c%03d" % i for i in range(n_cells)]
        a.var_names = ["g%03d" % i for i in range(n_genes)]
        a.obs["batch"] = np.where(np.arange(n_cells) % 2 == 0, "b1", "b2")
        a.obs["batch"] = a.obs["batch"].astype("category")
        a.layers["counts"] = a.X.copy()
        return a

    def scanpy_chain(seed):
        ospy_seed.set_seed(seed)
        a = toy(seed)
        sc.pp.normalize_total(a, target_sum=1e4)
        sc.pp.log1p(a)
        sc.pp.highly_variable_genes(a, n_top_genes=100, flavor="seurat")
        sc.pp.pca(a, n_comps=10, svd_solver="arpack", random_state=seed)
        sc.pp.neighbors(a, n_neighbors=15, n_pcs=10, random_state=seed)
        sc.tl.leiden(a, resolution=0.5, random_state=seed, flavor="igraph", n_iterations=2, directed=False)
        sc.tl.umap(a, random_state=seed)
        return a.obsm["X_pca"].tobytes(), a.obs["leiden"].astype(str).tolist(), a.obsm["X_umap"].tobytes()

    try:
        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            r1, r2 = scanpy_chain(20260925), scanpy_chain(20260925)
        check(r1[0] == r2[0], "scanpy PCA bit-identical across two seeded runs")
        check(r1[1] == r2[1], "scanpy Leiden labels identical across two seeded runs (%d clusters)" % len(set(r1[1])))
        check(r1[2] == r2[2], "scanpy UMAP bit-identical across two seeded runs")
    except Exception as exc:                                      # noqa: BLE001
        check(False, "scanpy chain failed: %s: %s" % (type(exc).__name__, exc))

    def scvi_fit(seed):
        import scvi                                            # noqa: PLC0415
        rec = ospy_seed.set_seed(seed)
        a = toy(seed)
        scvi.model.SCVI.setup_anndata(a, layer="counts", batch_key="batch")
        m = scvi.model.SCVI(a, n_latent=5, n_hidden=32, n_layers=1)
        m.train(max_epochs=2, accelerator="cpu", devices=1, batch_size=128,
                enable_progress_bar=False, logger=False, enable_checkpointing=False)
        return m.get_latent_representation().tobytes(), rec

    try:
        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            (l1, rec), (l2, _rec) = scvi_fit(20260925), scvi_fit(20260925)
        check(l1 == l2, "scVI latent space bit-identical across two seeded runs")
        check(rec.get("torch_deterministic_algorithms") is True and rec.get("torch_num_threads") == 1,
              "seed record: deterministic algorithms on, torch threads 1 (%s)" % rec)
        check(rec.get("scvi_settings_seed") == 20260925, "scvi.settings.seed set from --seed")
    except Exception as exc:                                      # noqa: BLE001
        check(False, "scVI fit failed: %s: %s" % (type(exc).__name__, exc))


def main():
    ap = argparse.ArgumentParser()
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--static", action="store_true")
    g.add_argument("--functional", action="store_true")
    a = ap.parse_args()
    static_checks()
    if a.functional:
        functional_checks()
    print("== omicstat-py image self-test: %s" % ("ALL PASSED" if not FAILS else "%d FAILED" % len(FAILS)))
    return 1 if FAILS else 0


if __name__ == "__main__":
    sys.exit(main())
