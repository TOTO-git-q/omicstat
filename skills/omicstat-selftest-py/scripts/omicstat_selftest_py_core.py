"""omicstat_selftest_py_core.py -- core layer of module omicstat-selftest-py.

This module is an ENVIRONMENT SELF-TEST of the Python (scverse) lane, not an
analysis. The core layer (1) reads the environment pins
(env/omicstat-env.json, block python_lane), (2) probes the running
interpreter (versions, CPU-only torch, thread variables, execution tier) with
the standard library and lazy imports, so the probe works even when the
scverse packages are missing, (3) applies the randomness lock
(ospy.seed.set_seed) and records it, and (4) builds the deterministic
synthetic fixtures -- a feature table and a small single-cell object with a
2-D embedding -- from random.Random(seed), so the fixture bytes do not depend
on NumPy's generator. No statistical engine is called anywhere in this module
(scripts/calls_registry.json registers no call). ASCII only.
"""
import importlib
import importlib.metadata as md
import json
import math
import os
import platform
import random
import sys

from ospy import module_kit as K
from ospy import seed as S

SP_MODULE = "omicstat-selftest-py"
SP_MODULE_VERSION = "0.1.0"
SP_DEFAULT_SEED = 20260925
SP_JOURNALS = ["nature", "cell", "science", "generic"]
SP_FIXTURE_N = 1000
SP_CELLS_PER_CLUSTER = 100
SP_CLUSTERS = ["Cluster A", "Cluster B", "Cluster C"]
SP_GENES = 40
SP_PADJ = 0.05
SP_LFC = 1
IMPORT_NAMES = {"scvi-tools": "scvi"}


def read_env_config(suite_root):
    """(path, python_lane dict) from the checkout, else the image copy (OMICSTAT_ENV_DIR)."""
    cands = [os.path.join(suite_root, "env", "py", "py-env.json")]
    if os.environ.get("OMICSTAT_ENV_DIR"):
        cands.append(os.path.join(os.environ["OMICSTAT_ENV_DIR"], "py", "py-env.json"))
    for p in cands:
        try:
            with open(p, encoding="utf-8") as fh:
                return os.path.abspath(p).replace(os.sep, "/"), json.load(fh)
        except (OSError, ValueError):
            continue
    return None, None


def _dist_version(name):
    try:
        return md.version(name)
    except md.PackageNotFoundError:
        return None


def probe(cfg_path, cfg):
    pins = (cfg or {}).get("pins") or {}
    pkgs = {}
    for dist in sorted(pins):
        pkgs[dist] = {"pin": pins[dist], "installed": _dist_version(dist), "importable": False, "error": ""}
        try:
            importlib.import_module(IMPORT_NAMES.get(dist, dist.replace("-", "_")))
            pkgs[dist]["importable"] = True
        except Exception as exc:                               # noqa: BLE001
            pkgs[dist]["error"] = "%s: %s" % (type(exc).__name__, str(exc)[:200])
    torch_info = {"installed": False}
    try:
        import torch                                           # noqa: PLC0415
        torch_info = {"installed": True, "version": torch.__version__, "cuda": torch.version.cuda,
                      "cuda_available": bool(torch.cuda.is_available())}
    except Exception:                                          # noqa: BLE001
        pass
    return {
        "env_config_path": cfg_path,
        "py_env_version": (cfg or {}).get("py_env_version"),
        "python_version": platform.python_version(),
        "python_pin": (cfg or {}).get("python_version"),
        "python_implementation": platform.python_implementation(),
        "platform": "%s-%s" % (sys.platform, platform.machine()),
        "executable": sys.executable,
        "packages": pkgs,
        "numpy": _dist_version("numpy"), "pandas": _dist_version("pandas"),
        "torch": torch_info,
        "threads": {v: os.environ.get(v) for v in S.THREAD_VARS},
        "pythonhashseed": os.environ.get("PYTHONHASHSEED"),
        "mode": {"container": "container", "native": "native"}.get(K.env_tier(), "unmanaged"),
        "image_id": os.environ.get("OMICSTAT_PY_IMAGE_ID") or None,
    }


def _bh(pvals):
    """Benjamini-Hochberg adjusted P values (None stays None)."""
    idx = [i for i, p in enumerate(pvals) if p is not None]
    m = len(idx)
    order = sorted(idx, key=lambda i: pvals[i])
    out = [None] * len(pvals)
    running = 1.0
    for rank in range(m, 0, -1):
        i = order[rank - 1]
        running = min(running, pvals[i] * m / rank)
        out[i] = min(1.0, running)
    return out


def feature_fixture(seed):
    """1,000-feature synthetic table (shape fixture; never a finding)."""
    rng = random.Random(seed)
    rows = []
    for i in range(SP_FIXTURE_N):
        kind = "up" if i < 150 else ("down" if i < 270 else "null")
        lfc = {"up": rng.gauss(2.0, 0.6), "down": rng.gauss(-2.0, 0.6), "null": rng.gauss(0.0, 0.35)}[kind]
        se = rng.uniform(0.15, 0.5)
        z = lfc / se
        p = max(math.erfc(abs(z) / math.sqrt(2.0)), 1e-300)
        base = math.exp(rng.gauss(5.0, 1.5))
        filtered = kind == "null" and rng.random() < 0.05
        rows.append({"feature_id": "PYFX%04d" % (i + 1), "symbol": "Gene%04d" % (i + 1),
                     "contrast": "Synthetic fixture: treated vs control", "base_mean": base, "log2fc": lfc,
                     "log2fc_se": se, "stat": z, "pvalue": p, "padj": None, "method": "self-test fixture (not an analysis)",
                     "shrinkage": "none", "n_group1": 3, "n_group2": 3,
                     "filtered_reason": "independent_filtering" if filtered else "", "_filtered": filtered})
    adj = _bh([None if r["_filtered"] else r["pvalue"] for r in rows])
    for r, a in zip(rows, adj):
        r["padj"] = a
        del r["_filtered"]
    return rows


def cell_fixture(seed):
    """3 clusters x 100 cells: 2-D embedding + a small count matrix (lists, no NumPy)."""
    rng = random.Random(seed + 1)
    centres = {"Cluster A": (-4.0, 0.5), "Cluster B": (3.5, 3.0), "Cluster C": (0.5, -4.0)}
    cells, x, y, cl = [], [], [], []
    counts = []
    profile = {c: [rng.uniform(0.2, 4.0) for _ in range(SP_GENES)] for c in SP_CLUSTERS}
    k = 0
    for c in SP_CLUSTERS:
        for _ in range(SP_CELLS_PER_CLUSTER):
            k += 1
            cells.append("cell%04d" % k)
            x.append(centres[c][0] + rng.gauss(0, 1.0))
            y.append(centres[c][1] + rng.gauss(0, 1.0))
            cl.append(c)
            counts.append([_poisson(rng, lam) for lam in profile[c]])
    return {"cell": cells, "x": x, "y": y, "cluster": cl, "counts": counts,
            "genes": ["Gene%04d" % (g + 1) for g in range(SP_GENES)]}


def _poisson(rng, lam):
    # Knuth's method; small lambdas only (deterministic given rng).
    limit, k, p = math.exp(-lam), 0, 1.0
    while True:
        p *= rng.random()
        if p <= limit:
            return k
        k += 1


def counts_of(ft):
    """Same classification as the volcano: padj < 0.05 and |log2fc| > 1; padj NA counted apart."""
    na = [r["padj"] is None for r in ft]
    sig = [(not n) and r["padj"] < SP_PADJ and abs(r["log2fc"]) > SP_LFC for r, n in zip(ft, na)]
    return {"n_features": len(ft), "n_up": sum(1 for r, s in zip(ft, sig) if s and r["log2fc"] > 0),
            "n_down": sum(1 for r, s in zip(ft, sig) if s and r["log2fc"] < 0),
            "n_ns": sum(1 for n, s in zip(na, sig) if not n and not s), "n_padj_na": sum(na)}


def compute(suite_root, seed):
    cfg_path, cfg = read_env_config(suite_root)
    pr = probe(cfg_path, cfg)
    seed_record = S.set_seed(seed)
    return {"probe": pr, "config": cfg, "seed_record": seed_record,
            "features": feature_fixture(seed), "cells": cell_fixture(seed)}
