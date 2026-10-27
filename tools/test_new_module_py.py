#!/usr/bin/env python3
"""Tests of the Python-lane scaffold: tools/new_module.py --python + templates/module_py.

Usage: python tools/test_new_module_py.py   (standard library only)
Copies tools/, templates/, env/omicstat-env.json and skills/_shared/py into a
temporary suite, scaffolds `scanpy cluster --python` there and checks that the
skeleton is complete and passes the suite's mechanical checks as generated
(--help in the os_help format, check_defaults, check_flag_docs, check_calls,
byte-compiles). The R scaffold (no --python) must be unchanged. ASCII only.
"""
import json
import pathlib
import py_compile
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
FAILS = []


def check(cond, msg):
    print(("PASS: " if cond else "FAIL: ") + msg)
    if not cond:
        FAILS.append(msg)


tmp = pathlib.Path(tempfile.mkdtemp(prefix="new-module-py-"))
suite = tmp / "suite"
for d in ("tools", "templates"):
    shutil.copytree(ROOT / d, suite / d, ignore=shutil.ignore_patterns("__pycache__", "lit"))
(suite / "env").mkdir(parents=True)
shutil.copy(ROOT / 'env/omicstat-env.json', suite / 'env/omicstat-env.json')
shutil.copy(ROOT / 'env/pkg_lock.csv', suite / 'env/pkg_lock.csv')
shutil.copy(ROOT / 'env/r-env.json', suite / 'env/r-env.json')
(suite / 'env/py').mkdir()
shutil.copy(ROOT / 'env/py/py_installed.csv', suite / 'env/py/py_installed.csv')
shutil.copy(ROOT / 'env/py/py-env.json', suite / 'env/py/py-env.json')
shutil.copytree(ROOT / 'skills/_shared/schemas', suite / 'skills/_shared/schemas')
shutil.copytree(ROOT / "skills" / "_shared" / "py", suite / "skills" / "_shared" / "py",
                ignore=shutil.ignore_patterns("__pycache__"))
# The SSOT scaffold now generates the reference registry and SUITE as well.
# Carry their real dependencies and one existing accepted metadata/entry pair;
# never copy or regenerate a golden or module_lock for this temporary fixture.
for rel in ("reference_service/app/registry.py",
            "reference_service/app/schemas/literature_request.v1.json",
            "skills/_shared/publication/module_rules_v1.json", "SUITE.md"):
    dest = suite / rel
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy(ROOT / rel, dest)
existing = ROOT / "skills/limma-array/module.json"
meta = json.loads(existing.read_text())
for rel in ("module.json", meta["entry"]):
    dest = suite / "skills/limma-array" / rel
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy(existing.parent / rel, dest)


def tool(*argv):
    return subprocess.run([sys.executable] + [str(a) for a in argv], capture_output=True, text=True, cwd=str(tmp))


r = tool(suite / "tools" / "new_module.py", "scanpy", "cluster", "--python")
mod = suite / "skills" / "scanpy-cluster"
check(r.returncode == 0 and "QC prefix YC, Python lane" in r.stdout, "scaffold runs (%s)" % (r.stdout + r.stderr).strip())
want = ["SKILL.md", "scripts/run_scanpy_cluster.py", "scripts/scanpy_cluster_core.py", "scripts/scanpy_cluster_report.py",
        "scripts/scanpy_cluster_qc.py", "scripts/calls_registry.json", "tests/run_smoke_test.py", "module.json",
        "references/method-basis.md", "references/parameters.md", "references/qc-rules.md",
        "references/reporting-templates.md", "references/troubleshooting.md"]
missing = [w for w in want if not (mod / w).is_file()]
check(not missing, "every skeleton file exists (missing: %s)" % missing)
check(not list(mod.rglob("*.R")) and not list(mod.rglob("*.tmpl")), "no R entry and no unrendered template")
text = "".join(p.read_text(encoding="utf-8") for p in mod.rglob("*") if p.is_file())
check("{{" not in text, "every placeholder filled")
check('"scvi-tools"' not in (mod / "scripts" / "calls_registry.json").read_text(encoding="utf-8")
      and '"scanpy": "<py_lock>"' in (mod / "scripts" / "calls_registry.json").read_text(encoding="utf-8"),
      "registry keyed by distribution name")
check("run_scanpy_cluster.py" in (mod / "references" / "parameters.md").read_text(encoding="utf-8"),
      "parameters.md comes from templates/module_py")
for p in mod.rglob("*.py"):
    try:
        py_compile.compile(str(p), doraise=True, cfile=str(tmp / "c.pyc"))
        ok = True
    except py_compile.PyCompileError as exc:
        ok = False
        print(exc)
    check(ok, "%s byte-compiles" % p.name)
h = tool(mod / "scripts" / "run_scanpy_cluster.py", "--help")
check(h.returncode == 0 and h.stdout.startswith("Usage: python run_scanpy_cluster.py")
      and "  --seed <int>" in h.stdout and "Mutually exclusive: --input, --from-run" in h.stdout,
      "--help works before any scientific import, in the os_help format")
for t in ("check_defaults.py", "check_flag_docs.py", "check_calls.py"):
    c = tool(suite / "tools" / t, mod)
    check(c.returncode == 0, "%s passes on the fresh skeleton (%s)" % (t, (c.stdout + c.stderr).strip()[-160:]))
e = tool(mod / "scripts" / "run_scanpy_cluster.py", "--outdir", tmp / "o")
check(e.returncode == 1 and e.stderr.strip().startswith("OS_MISSING_PARAMETER"), "typed refusal without --input/--from-run")
r = tool(suite / "tools" / "new_module.py", "scanpy", "cluster", "--python")
check(r.returncode != 0 and "exists" in (r.stdout + r.stderr), "an existing module is not overwritten without --force")
r = tool(suite / "tools" / "new_module.py", "deseq2", "wald", "--prefix", "DW")
rmod = suite / "skills" / "deseq2-wald"
check(r.returncode == 0 and (rmod / "scripts" / "run_deseq2_wald.R").is_file() and not list(rmod.rglob("*.py")),
      "the R scaffold is unchanged (run_*.R, no .py)")
shutil.rmtree(tmp, ignore_errors=True)
print("== new_module --python: %s" % ("ALL PASSED" if not FAILS else "%d FAILED" % len(FAILS)))
sys.exit(1 if FAILS else 0)
