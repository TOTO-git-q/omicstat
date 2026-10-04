#!/usr/bin/env python3
"""Tests of tools/check_calls.py (lock 3, Python lane) on a synthetic package.

Usage: python tools/test_check_calls.py      (standard library only)
A throw-away package `fakesc` (functions, a class with methods and a
classmethod) stands in for scanpy / scvi-tools, so the checker is tested
without the omicstat-py image. Exit 0 = all passed. ASCII only.
"""
import json
import pathlib
import shutil
import subprocess
import sys
import tempfile
import textwrap

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import check_calls as CC                                      # noqa: E402

FAILS = []


def check(cond, msg):
    print(("PASS: " if cond else "FAIL: ") + msg)
    if not cond:
        FAILS.append(msg)


tmp = pathlib.Path(tempfile.mkdtemp(prefix="check-calls-"))
pkg = tmp / "lib" / "fakesc"
(pkg / "pp").mkdir(parents=True)
(pkg / "__init__.py").write_text("from . import pp\nfrom .model import Model\n", encoding="utf-8")
(pkg / "pp" / "__init__.py").write_text(textwrap.dedent("""
    def pca(adata, n_comps=None, svd_solver="arpack", random_state=0, **kwargs):
        return adata
    def neighbors(adata, n_neighbors=15, *, random_state):
        return adata
    def helper(x):
        return x
"""), encoding="utf-8")
(pkg / "model.py").write_text(textwrap.dedent("""
    class Model:
        def __init__(self, adata, n_latent=10, n_hidden=128):
            self.adata = adata
        def train(self, max_epochs=None, batch_size=128, **trainer_kwargs):
            return self
        @classmethod
        def from_other(cls, other, labels_key=None):
            return cls(other.adata)
        def latent(self):
            return 0
"""), encoding="utf-8")
sys.path.insert(0, str(tmp / "lib"))

reg = {
    "module": "fake-module",
    "package_versions": {"fakesc": "1.0.0"},
    "calls": [
        {"fn": "fakesc.pp.pca", "args": {"n_comps": {"value": 50, "function_default": "None"},
                                          "svd_solver": {"value": "arpack", "function_default": "'arpack'"},
                                          "random_state": {"flag": "--seed", "function_default": "0"}}},
        {"fn": "fakesc.pp.neighbors", "args": {"n_neighbors": {"value": 15, "function_default": "15"},
                                                "random_state": {"flag": "--seed", "function_default": "<required>"}}},
        {"fn": "fakesc.model.Model", "args": {"n_latent": {"value": 10, "function_default": "10"}}},
        {"fn": "fakesc.model.Model.train", "args": {"max_epochs": {"value": 5, "function_default": "None"},
                                                     "accelerator": {"value": "cpu", "function_default": "<absent>"}}},
        {"fn": "fakesc.model.Model.from_other", "returns": "fakesc.model.Model",
         "args": {"labels_key": {"value": "cell_type", "function_default": "None"}}},
    ],
    "accessors": ["fakesc.model.Model.latent"],
}

good = textwrap.dedent("""
    import fakesc as fs
    from fakesc.model import Model
    from fakesc import pp as P

    def run(adata, seed):
        fs.pp.pca(adata, n_comps=50, svd_solver="arpack", random_state=seed)
        nb = P.neighbors
        nb(adata, n_neighbors=15, random_state=seed)
        m = Model(adata, n_latent=10)
        m.train(max_epochs=5, accelerator="cpu")
        m2 = fs.model.Model.from_other(m, labels_key="cell_type")
        m2.train(max_epochs=5, accelerator="cpu")
        return m2.latent()
""")
script = tmp / "run_fake.py"
script.write_text(good, encoding="utf-8")
res = CC.check_calls([script], reg)
check(res["ok"], "a fully explicit script passes (%s)" % res["problems"])
check(res["n_sites"] == 7, "all call sites are counted (%d)" % res["n_sites"])
dd = CC.check_default_drift(reg)
check(dd["ok"], "no default drift against the installed fake package (%s)" % dd["problems"])


def problems_for(src, registry=reg):
    f = tmp / "case.py"
    f.write_text(textwrap.dedent(src), encoding="utf-8")
    return CC.check_calls([f], registry)["problems"]


p = problems_for("""
    import fakesc as fs
    def run(adata, seed):
        fs.pp.pca(adata, 50, svd_solver="arpack", random_state=seed)
""")
check(any(x.startswith("C1 case.py:4 fakesc.pp.pca") and "n_comps" in x for x in p),
      "C1: a positional argument does not count as naming it")
check(any(x.startswith("C3 registered function fakesc.pp.neighbors") for x in p), "C3: never-called registered function")
p = problems_for("""
    import fakesc
    fakesc.pp.helper(1)
""")
check(any(x == "C2 case.py:3 unregistered call fakesc.pp.helper" for x in p), "C2: unregistered package call")
p = problems_for("""
    import fakesc as fs
    def run(adata, seed, kw):
        fs.pp.pca(adata, n_comps=50, svd_solver="arpack", random_state=seed, **kw)
""")
check(any(x.startswith("C5 case.py:4") for x in p), "C5: **kwargs at a registered call site")
p = problems_for("""
    def run(get_model):
        get_model().train(max_epochs=5, accelerator="cpu")
""")
check(any(x.startswith("C4 case.py:3") and ".train()" in x for x in p), "C4: unresolved receiver of a registered method")
p = problems_for("""
    import fakesc as fs
    m = fs.model.Model(None, n_latent=10)
    m.latent()
""")
check(not any("latent" in x for x in p), "accessors are exempt from C2")

drift = json.loads(json.dumps(reg))
drift["calls"][0]["args"]["svd_solver"]["function_default"] = "'randomized'"
drift["calls"][1]["args"]["n_neighbors"]["function_default"] = "30"
drift["calls"].append({"fn": "fakesc.pp.nothere", "args": {"x": {"function_default": "1"}}})
dd = CC.check_default_drift(drift)
check(any(x == "D1 fakesc.pp.pca(svd_solver): locked default is 'arpack', PACK D recorded 'randomized'" for x in dd["problems"]),
      "D1: default drift is reported with both values")
check(any(x.startswith("D1 fakesc.pp.neighbors(n_neighbors)") for x in dd["problems"]), "D1 on a keyword-only signature")
check(any(x.startswith("D0 fakesc.pp.nothere") for x in dd["problems"]), "D0: unresolvable registered function")

# Singledispatch needs a positional required data input; options stay named.
input_reg = {"package_versions": {"fakesc": "1.0.0"}, "calls": [{
    "fn": "fakesc.pp.pca", "positional_inputs": ["adata"], "args": {
        "adata": {"function_default": "<required>"}, "n_comps": {"function_default": "None"}}}]}
check(not problems_for("import fakesc; fakesc.pp.pca(None, n_comps=2)", input_reg), "registered required positional input passes")
check(bool(problems_for("import fakesc; fakesc.pp.pca(None, 2)", input_reg)), "scientific positional option remains rejected")
check(bool(problems_for("import fakesc; fakesc.pp.pca(adata=None, n_comps=2)", input_reg)), "registered positional input must be supplied positionally")
invalid_reg = json.loads(json.dumps(input_reg))
invalid_reg['calls'][0]['positional_inputs'] = ['n_comps']
check(bool(problems_for("import fakesc; fakesc.pp.pca(None, n_comps=2)", invalid_reg)), "incorrect positional signature mapping rejected")

wrong_order = json.loads(json.dumps(input_reg))
wrong_order['calls'][0]['positional_inputs'] = ['n_comps']
check(any('positional_inputs differ from installed signature' in x for x in CC.check_default_drift(wrong_order)['problems']),
      "locked signature verifies positional input order")

# CLI on a module directory
mod = tmp / "skills" / "fake-module"
(mod / "scripts").mkdir(parents=True)
shutil.copy(script, mod / "scripts" / "run_fake.py")
(mod / "scripts" / "calls_registry.json").write_text(json.dumps(reg), encoding="utf-8")
env = dict(**__import__("os").environ)
env["PYTHONPATH"] = str(tmp / "lib")
out = subprocess.run([sys.executable, str(HERE / "check_calls.py"), str(mod)], capture_output=True, text=True, env=env)
check(out.returncode == 0 and out.stdout.strip().endswith("0 registry problems; 0 default-drift problems"),
      "CLI exit 0 and summary line (%s)" % out.stdout.strip()[-120:])
(mod / "scripts" / "extra.py").write_text("import fakesc\nfakesc.pp.helper(2)\n", encoding="utf-8")
out = subprocess.run([sys.executable, str(HERE / "check_calls.py"), str(mod)], capture_output=True, text=True, env=env)
check(out.returncode == 1 and "FAIL: C2 extra.py:2 unregistered call fakesc.pp.helper" in out.stdout, "CLI fails on a problem")

shutil.rmtree(tmp, ignore_errors=True)
print("== check_calls.py: %s" % ("ALL PASSED" if not FAILS else "%d FAILED" % len(FAILS)))
sys.exit(1 if FAILS else 0)
