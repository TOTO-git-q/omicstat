"""omicstat_selftest_py_qc.py -- qc layer of module omicstat-selftest-py.

One row per rule PY-01..PY-10 (references/qc-rules.md), triggered or not,
written to qc/qc_results.csv in the id / severity / triggered / blocking /
message / action / evidence dialect (ospy.module_kit, = module_kit.R). A
check FAILS (and --strict exits non-zero) when a blocker or error rule is
triggered; warnings never fail --strict. ASCII only.
"""
import os

from ospy import feature_table as FT
from ospy import figure_request as FR
from ospy import handoff as H
from ospy import module_kit as K

EVID = "environment_report.md"


def _mm(v):
    return ".".join(str(v).split(".")[:2]) if v else None


def qc(res, rend, outdir):
    pr, rows = res["probe"], []
    R = lambda *a, **k: rows.append(K.qc_rule(*a, evidence=k.pop("evidence", EVID), **k))   # noqa: E731

    # PY-01 Python version vs the pin
    if not pr["python_pin"]:
        R("PY-01", "python_version", True, "error", "env/omicstat-env.json (python_lane) could not be read; the Python pin is unknown.",
          action="Run the self-test from an omicstat checkout (the module must sit in <suite>/skills/).")
    elif _mm(pr["python_version"]) != _mm(pr["python_pin"]):
        R("PY-01", "python_version", True, "error", "Python %s does not match the pinned Python %s (major.minor must match)."
          % (pr["python_version"], pr["python_pin"]), action="Use the omicstat-py image or env/py/setup_native.sh with Python %s." % _mm(pr["python_pin"]))
    elif pr["python_version"] != pr["python_pin"]:
        R("PY-01", "python_version", True, "warning", "Python %s differs from the pinned %s at patch level only."
          % (pr["python_version"], pr["python_pin"]), action="Acceptable for the native tier; byte-level golden checks apply to the container only.")
    else:
        R("PY-01", "python_version", False, "error", "Python %s matches the pin." % pr["python_version"])

    # PY-02 the four scverse-lane pins
    bad = ["%s (pin %s, installed %s%s)" % (d, v["pin"], v["installed"] or "absent", "" if v["importable"] else ", not importable")
           for d, v in pr["packages"].items() if v["installed"] != v["pin"] or not v["importable"]]
    R("PY-02", "pinned_packages", bool(bad) or not pr["packages"], "error",
      ("Not at the pinned version: %s." % "; ".join(bad)) if bad else
      ("scanpy, anndata, scvi-tools and torch are installed at their pins." if pr["packages"] else "No pins could be read."),
      action="Use the omicstat-py image (env/py/build.sh) or rebuild the native venv with env/py/setup_native.sh.")

    # PY-03 CPU-only torch
    t = pr["torch"]
    if not t.get("installed"):
        R("PY-03", "torch_cpu_only", False, "error", "torch is not installed (reported by PY-02).")
    else:
        gpu = t.get("cuda") is not None or t.get("cuda_available") or "+cpu" not in str(t.get("version"))
        R("PY-03", "torch_cpu_only", gpu, "error",
          "torch %s is %s (cuda=%s)." % (t.get("version"), "NOT a CPU-only build" if gpu else "a CPU-only build", t.get("cuda")),
          action="Install torch from the CPU index only (env/py_lock.txt); GPU is out of scope (ENGINEERING_PLAN 10.6).")

    # PY-04 single-threaded numerics
    badt = {k: v for k, v in pr["threads"].items() if v != "1"}
    R("PY-04", "single_thread", bool(badt), "warning",
      ("Not set to 1: %s." % ", ".join("%s=%r" % kv for kv in badt.items())) if badt
      else "OMP_NUM_THREADS, OPENBLAS_NUM_THREADS, MKL_NUM_THREADS and NUMBA_NUM_THREADS are 1.",
      action="Run through bin/omicstat-r-route.sh python ... (it sets them) or export them as 1.")

    # PY-05 randomness lock
    sr = res["seed_record"]
    det_bad = sr.get("torch_manual_seed") is True and not (sr.get("torch_deterministic_algorithms") is True
                                                           and sr.get("torch_num_threads") == 1)
    R("PY-05", "determinism", det_bad, "error",
      "set_seed(%d): torch deterministic algorithms %s, torch threads %s, scvi.settings.seed %s; PYTHONHASHSEED=%s."
      % (sr["seed"], sr.get("torch_deterministic_algorithms"), sr.get("torch_num_threads"), sr.get("scvi_settings_seed"),
         pr["pythonhashseed"]),
      action="torch.use_deterministic_algorithms(True) failed; check the torch build (PY-03).")

    # PY-06 execution environment
    R("PY-06", "execution_environment", pr["mode"] == "unmanaged", "error",
      "Execution environment: %s." % pr["mode"],
      action="Start Python through bin/omicstat-r-route.sh python (omicstat-py image) or with OMICSTAT_R_NATIVE=1 (native venv).")

    # PY-07 feature table written, re-read, byte-stable
    v = FT.validate_feature_table(rend["ft"])
    tmp = os.path.join(outdir, "qc", ".ft_rewrite.csv")
    FT.write_feature_table(FT.as_feature_table(res["features"]), tmp)
    stable = K.sha256_file(tmp) == K.sha256_file(rend["feature_table"])
    os.remove(tmp)
    R("PY-07", "feature_table", not (v["ok"] and stable), "error",
      "Feature table %s; a second write is %sbyte-identical." % ("validates" if v["ok"] else "fails: " + "; ".join(v["errors"]), "" if stable else "NOT "),
      action="skills/_shared/py/ospy/feature_table.py is broken; run skills/_shared/py/tests/test_ospy.py.",
      evidence="tables/feature_table.csv")

    # PY-08 handoff round trip (sha256 + types + scverse ecosystem)
    want = {"feature_table": "feature_table"}
    if rend["adata_info"].get("written"):
        want["adata"] = H.ANNDATA_TYPE
    try:
        H.read_handoff(outdir, expect=want, front_end_ecosystem="scverse")
        ok, msg = True, "objects/handoff.json reads back (%s)." % ", ".join(sorted(want))
    except Exception as exc:                                   # noqa: BLE001
        ok, msg = False, "handoff round trip failed: %s" % exc
    R("PY-08", "handoff", not ok, "error", msg, action="skills/_shared/py/ospy/handoff.py is broken.", evidence="objects/handoff.json")

    # PY-09 figure request valid (files + sha256)
    probs = FR.validate_request(outdir)
    R("PY-09", "figure_request", bool(probs), "error",
      ("figure_request.json problems: %s" % "; ".join(probs)) if probs else "figure_data/figure_request.json and its data files agree.",
      action="skills/_shared/py/ospy/figure_request.py is broken.", evidence="figure_data/figure_request.json")

    # PY-10 AnnData object
    ai = rend["adata_info"]
    R("PY-10", "anndata_object", not (ai.get("written") and ai.get("roundtrip_ok")), "error",
      ("AnnData %s written to objects/adata.h5ad and read back." % ai.get("shape")) if ai.get("written") and ai.get("roundtrip_ok")
      else "AnnData object not written or not read back (%s)." % (ai.get("error") or "shape/categories differ"),
      action="anndata / h5py are missing or broken (see PY-02).", evidence="objects/adata.h5ad")

    return K.qc_finalize(rows, read_first=EVID)
