"""seed.py -- randomness lock of the Python lane (ENGINEERING_PLAN 10.4 lock 4).

    rec = set_seed(args["seed"])        # once, before any computation
    ...
    sc.pp.pca(adata, ..., random_state=args["seed"])   # AND pass it explicitly
    sc.tl.leiden(adata, ..., random_state=args["seed"])

set_seed() seeds every generator the scverse stack draws from -- Python's
`random`, NumPy's legacy global generator, torch (manual_seed), and
scvi.settings.seed (which also seeds lightning) -- switches torch to
deterministic algorithms (torch.use_deterministic_algorithms(True)) with one
intra-op thread, and returns a record for provenance ("seed_record"). Packages
that are not installed are reported as such and skipped (the entry of a module
that does not use torch still works on a lighter interpreter). The explicit
random_state=/seed= arguments at the call sites remain mandatory: they are
lock 3 registry entries, and set_seed() does not replace them.

It also records the determinism environment: the thread variables
(OMP/MKL/OPENBLAS/NUMBA_NUM_THREADS must be 1, set by the image and by the
native router) and PYTHONHASHSEED. check_thread_env() returns the variables
that are not 1. ASCII only.
"""
import os
import random

THREAD_VARS = ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS", "NUMBA_NUM_THREADS")


def check_thread_env():
    """{variable: value} for every thread variable that is not "1"."""
    return {v: os.environ.get(v) for v in THREAD_VARS if os.environ.get(v) != "1"}


def set_seed(seed, torch_threads=1):
    if not isinstance(seed, int) or isinstance(seed, bool):
        raise TypeError("seed must be an int, got %r" % (seed,))
    rec = {"seed": seed, "python_random": True,
           "thread_env": {v: os.environ.get(v) for v in THREAD_VARS},
           "pythonhashseed": os.environ.get("PYTHONHASHSEED")}
    random.seed(seed)
    try:
        import numpy as np                                     # noqa: PLC0415
        np.random.seed(seed % (2 ** 32))
        rec["numpy_global"] = True
    except ImportError:
        rec["numpy_global"] = "not installed"
    try:
        import torch                                           # noqa: PLC0415
        torch.manual_seed(seed)
        torch.use_deterministic_algorithms(True)
        torch.set_num_threads(int(torch_threads))
        rec["torch_manual_seed"] = True
        rec["torch_deterministic_algorithms"] = bool(torch.are_deterministic_algorithms_enabled())
        rec["torch_num_threads"] = int(torch.get_num_threads())
        rec["torch_cuda_available"] = bool(torch.cuda.is_available())
    except ImportError:
        rec["torch_manual_seed"] = "not installed"
    try:
        import scvi                                            # noqa: PLC0415
        scvi.settings.seed = seed
        rec["scvi_settings_seed"] = int(scvi.settings.seed)
    except ImportError:
        rec["scvi_settings_seed"] = "not installed"
    return rec
