#!/usr/bin/env python3
"""run_smoke_test.py -- module omicstat-selftest-py. ASCII only.

Required checks (ENGINEERING_PLAN 7.2 S2, Python lane): anchors, flag
effectiveness, call-registry consistency (tools/check_calls.py), default
consistency (tools/check_defaults.py), flag-doc coverage, typed refusals,
--spec replay, --from-run chain, determinism, cwd independence. For this
self-test the "anchors" are the output contract and the fixture's
deterministic counts.

Usage: python skills/omicstat-selftest-py/tests/run_smoke_test.py
Engine part: runs anywhere with Python >= 3.10 (a plain host interpreter
fails PY-02/PY-06 by design and the environment verdict is then not
asserted); run it in the omicstat-py image for the PASS verdict
(env/py/test.sh). Render part: the R render step is run on the
default run -- only when OMICSTAT_SMOKE_RSCRIPT names the omicstat
Rscript; otherwise it is reported as SKIP -- the end-to-end path
(omicstat-py -> omicstat-r -> MCP) is covered by mcp/test_client.py.
Exit 0 = all passed.
"""
import hashlib
import json
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile
import time

HERE = pathlib.Path(__file__).resolve().parent
MODULE = HERE.parent
SUITE = MODULE.parent.parent
ENTRY = MODULE / "scripts" / "run_omicstat_selftest_py.py"
# Default-seed anchors of the fixtures (random.Random(20260925); stdlib only).
ANCHOR = {"n_features": 1000, "n_up": 144, "n_down": 116, "n_padj_na": 26, "n_cells": 300}
FAILS, SKIPS = [], []


def check(cond, msg):
    print(("PASS: " if cond else "FAIL: ") + msg, flush=True)
    if not cond:
        FAILS.append(msg)


def sha(p):
    return hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()


work = pathlib.Path(tempfile.mkdtemp(prefix="omicstat_selftest_py_smoke_"))
os.chdir(work)                      # cwd independence: never run from the module directory


def run(*argv, env=None):
    e = dict(os.environ)
    e.update(env or {})
    p = subprocess.run([sys.executable, str(ENTRY)] + [str(a) for a in argv], capture_output=True, text=True,
                       stdin=subprocess.DEVNULL, env=e)
    return p.returncode, p.stdout, p.stderr


# ---- lock 3 and default consistency ------------------------------------------------
cc = subprocess.run([sys.executable, str(SUITE / "tools" / "check_calls.py"), str(MODULE)], capture_output=True, text=True)
check(cc.returncode == 0, "call registry consistent / no default drift (%s)" % cc.stdout.strip()[-160:])
cd = subprocess.run([sys.executable, str(SUITE / "tools" / "check_defaults.py"), str(MODULE)], capture_output=True, text=True)
check(cd.returncode == 0, "defaults consistent across --help/registry/docs (%s)" % (cd.stdout + cd.stderr).strip()[-200:])
fd = subprocess.run([sys.executable, str(SUITE / "tools" / "check_flag_docs.py"), str(MODULE)], capture_output=True, text=True)
check(fd.returncode == 0, "every flag documented (%s)" % fd.stdout.strip()[-160:])

# ---- --help ------------------------------------------------------------------------
rc, out, err = run("--help")
check(rc == 0 and all(f in out for f in ("--outdir", "--strict", "--seed", "--journal", "--from-run", "--spec", "--help")),
      "--help lists every flag")
check(out.splitlines()[0] == "Usage: python run_omicstat_selftest_py.py --outdir <dir> [options]", "--help usage line")

# ---- typed refusals ----------------------------------------------------------------
for argv, code, what in (
        (["--bogus", "x"], "OS_UNKNOWN_FLAG", "unknown flag"),
        (["--seed", "1"], "OS_MISSING_PARAMETER", "missing --outdir"),
        (["--outdir", work / "bad", "--seed", "abc"], "OS_INVALID_PARAMETER", "non-integer --seed"),
        (["--outdir", work / "bad", "--journal", "lancet"], "OS_INVALID_PARAMETER", "unknown --journal"),
        (["--outdir", work / "bad", "--seed", "1", "--seed", "2"], "OS_CONFLICTING_PARAMETERS", "flag given twice"),
        (["--outdir", work / "bad", "--from-run", work / "absent"], "OS_INVALID_PARAMETER", "missing --from-run directory"),
        (["--outdir", work / "bad", "--from-run", work], "OS_HANDOFF_MISSING", "--from-run without handoff.json")):
    rc, out, err = run(*argv)
    check(rc == 1 and err.strip().startswith(code) and "Traceback" not in err, "%s -> %s" % (what, code))

# ---- default run: output contract -------------------------------------------------------
t0 = time.time()
rc, out, err = run("--outdir", work / "a")
elapsed = time.time() - t0
A = work / "a"
check(rc == 0, "default run exits 0 (%s)" % err.strip()[-300:])
check(elapsed < 120, "default run under 120 s (%.1f s)" % elapsed)
check(out.strip().splitlines()[-1:] == ["%s of 10 rules triggered; read environment_report.md first" % out.strip().split()[0]]
      if out.strip() else False, "closing line")
res = json.loads((A / "results" / "selftest_summary.json").read_text(encoding="utf-8")) if (A / "results" / "selftest_summary.json").is_file() else {}
adata_ok = bool(res.get("adata_written"))
if not adata_ok:
    SKIPS.append("AnnData parts (anndata not importable in this interpreter; PY-10 reports it)")
promised = ["tables/feature_table.csv", "objects/handoff.json", "figure_data/figure_request.json",
            "figure_data/volcano__ft.csv", "figure_data/umap_clusters__emb.csv", "qc/qc_results.csv", "qc/engine_warnings.csv",
            "draft/methods_results.md", "environment_report.md", "results/selftest_summary.json",
            "provenance/provenance.json", "provenance/resolved_spec.json"]
promised += ["objects/adata.h5ad"] if adata_ok else []
missing = [p for p in promised if not (A / p).is_file()]
check(not missing, "all outputs written (missing: %s)" % missing)
qc_lines = (A / "qc" / "qc_results.csv").read_text(encoding="utf-8").splitlines()
check(qc_lines[0] == '"id","check","severity","triggered","blocking","message","action","evidence"'
      and [l.split(",")[0] for l in qc_lines[1:]] == ['"PY-%02d"' % k for k in range(1, 11)], "qc table: PY-01..PY-10 in the shared dialect")
res = json.loads((A / "results" / "selftest_summary.json").read_text(encoding="utf-8"))
check(all(res.get(k) == v for k, v in ANCHOR.items()),
      "fixture anchors %s (got %s)" % (ANCHOR, {k: res.get(k) for k in ANCHOR}))
check(res["n_triggered"] == sum(1 for l in qc_lines[1:] if l.split(",")[3] == '"TRUE"'), "results JSON agrees with the qc table")
managed = res["execution_mode"] in ("container", "native")
if managed:
    check(res["environment_ok"] is True, "managed environment passes every blocker/error rule (failed: %s)" % res["failed_rules"])
else:
    SKIPS.append("environment verdict (unmanaged interpreter: PY-02/PY-06 fail by design)")
ho = json.loads((A / "objects" / "handoff.json").read_text(encoding="utf-8"))
check(ho["module"] == "omicstat-selftest-py" and ho["ecosystem"] == "scverse" and ho["upstream_runs"] == ["a"]
      and {o["name"]: o["type"] for o in ho["objects"]} == dict({"feature_table": "feature_table"}, **({"adata": "AnnData"} if adata_ok else {})),
      "handoff.json: scverse ecosystem, AnnData + feature_table")
req = json.loads((A / "figure_data" / "figure_request.json").read_text(encoding="utf-8"))
check([f["builder"] for f in req["figures"]] == ["os_volcano", "os_embedding"] and req["journal"] == "nature"
      and req["colour_registry_out"] == "objects/colour_registry.json", "figure request: volcano + embedding, journal, registry out")
prov = json.loads((A / "provenance" / "provenance.json").read_text(encoding="utf-8"))
check(prov["language"] == "python" and prov["seed"] == 20260925 and prov["render_step"]["runs_in"].startswith("omicstat-r")
      and prov["seed_record"]["seed"] == 20260925 and "packages" in prov and prov["outputs"]["tables/feature_table.csv"] == sha(A / "tables" / "feature_table.csv"),
      "provenance: language, seed + seed record, render step, packages, output hashes")
draft = (A / "draft" / "methods_results.md").read_text(encoding="utf-8")
check("self-test" in draft and "{" not in draft, "draft is filled and says it is a self-test")
ew = (A / "qc" / "engine_warnings.csv").read_text(encoding="utf-8").splitlines()
n_warn = sum(1 for l in ew[1:] if l.split(",")[1] == '"warning"')
check(ew[0] == '"stage","type","message"' and n_warn == err.count("OS_ENGINE_WARNING: "),
      "every captured warning is echoed as OS_ENGINE_WARNING (%d)" % n_warn)

# ---- determinism --------------------------------------------------------------------
rc_b, _o, _e = run("--outdir", work / "b")
B = work / "b"
same = ["tables/feature_table.csv", "qc/qc_results.csv", "figure_data/figure_request.json", "figure_data/volcano__ft.csv",
        "figure_data/umap_clusters__emb.csv", "draft/methods_results.md", "environment_report.md", "results/selftest_summary.json"]
diff = [f for f in same if sha(A / f) != sha(B / f)]
check(rc_b == 0 and not diff, "rerun is byte-identical (differs: %s)" % diff)

# ---- flag effectiveness ---------------------------------------------------------------
rc, _o, _e = run("--outdir", work / "seed7", "--seed", "7")
check(rc == 0 and sha(work / "seed7" / "tables" / "feature_table.csv") != sha(A / "tables" / "feature_table.csv"), "--seed changes the fixture")
rc, _o, _e = run("--outdir", work / "sci", "--journal", "science")
check(rc == 0 and json.loads((work / "sci" / "figure_data" / "figure_request.json").read_text(encoding="utf-8"))["journal"] == "science",
      "--journal reaches the figure request")
rc, _o, err = run("--outdir", work / "strict", "--strict")
check(rc == (0 if res["environment_ok"] else 1) and (res["environment_ok"] or "OS_ENV_CHECK_FAILED" in err),
      "--strict turns the verdict into the exit code")

# ---- --spec replay and --from-run chain -------------------------------------------------
rc, _o, _e = run("--outdir", work / "replay", "--spec", A / "provenance" / "resolved_spec.json")
check(rc == 0 and sha(work / "replay" / "tables" / "feature_table.csv") == sha(A / "tables" / "feature_table.csv"),
      "--spec replays the run")
rc, _o, _e = run("--outdir", work / "replay7", "--spec", work / "seed7" / "provenance" / "resolved_spec.json", "--seed", "20260925")
check(rc == 0 and sha(work / "replay7" / "tables" / "feature_table.csv") == sha(A / "tables" / "feature_table.csv"),
      "--spec: a flag given on the command line wins")
rc, _o, err = run("--outdir", work / "chain", "--from-run", A)
ch = json.loads((work / "chain" / "objects" / "handoff.json").read_text(encoding="utf-8")) if rc == 0 else {}
check(rc == 0 and ch.get("upstream_runs") == ["a", "chain"], "--from-run extends the upstream_runs chain (%s)" % err.strip()[-200:])
(A / "tables" / "feature_table.csv").write_text("tampered\n", encoding="utf-8")
rc, _o, err = run("--outdir", work / "chain2", "--from-run", A)
check(rc == 1 and err.strip().startswith("OS_HANDOFF_MISMATCH"), "a changed upstream object -> OS_HANDOFF_MISMATCH")
shutil.copy(B / "tables" / "feature_table.csv", A / "tables" / "feature_table.csv")

# ---- R render step (optional here; always covered by mcp/test_client.py) -------------------
# Only an explicitly named Rscript of the omicstat R environment is used (a
# stray Rscript on a development PATH may belong to another suite).
rscript = os.environ.get("OMICSTAT_SMOKE_RSCRIPT")
if rscript:
    r = subprocess.run([rscript, str(SUITE / "skills" / "_shared" / "scripts" / "render_figure_request.R"), "--run-dir", str(B)],
                       capture_output=True, text=True, stdin=subprocess.DEVNULL)
    check(r.returncode == 0 and (B / "figures" / "volcano.png").is_file() and (B / "figures" / "umap_clusters.png").is_file()
          and (B / "provenance" / "figure_render.json").is_file(), "R render step draws both figures (%s)" % r.stderr.strip()[-200:])
    if r.returncode == 0:
        spec = json.loads((B / "figures" / "volcano.figure_spec.json").read_text(encoding="utf-8"))
        rb = json.loads((B / "results" / "selftest_summary.json").read_text(encoding="utf-8"))
        check(spec["counts"]["up"] == rb["n_up"] and spec["counts"]["down"] == rb["n_down"], "R volcano counts agree with the Python table")
else:
    SKIPS.append("R render step (no Rscript here; covered by mcp/test_client.py)")

check(not any(p.name == "Rplots.pdf" for p in work.rglob("Rplots.pdf")), "no stray Rplots.pdf")
shutil.rmtree(work, ignore_errors=True)
for s in SKIPS:
    print("SKIP:", s)
print("SMOKE %s (%d skipped)" % ("PASSED" if not FAILS else "FAILED: %d" % len(FAILS), len(SKIPS)))
sys.exit(1 if FAILS else 0)
