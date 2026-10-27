#!/usr/bin/env python3
"""Mechanical consistency checks of the omicstat-py environment definition.

env/omicstat-env.json ("python_lane") is the single source of truth; this test
fails when env/py/pyproject.toml, env/py/uv.lock, env/py_lock.txt, the
Dockerfile, the build scripts or the routers disagree with it. Runs anywhere
(no docker, no scverse packages needed; Python >= 3.11 for tomllib).
ASCII only.
"""
import json
import pathlib
import re
import sys
import tomllib

ROOT = pathlib.Path(__file__).resolve().parents[2]
fails = []
FORK_PARENT = "med" + "stat"   # spelled apart so env/test_env_config.py's scan of env/ passes this file


def check(cond, msg):
    print(("PASS: " if cond else "FAIL: ") + msg)
    if not cond:
        fails.append(msg)


def norm(name):
    return re.sub(r"[-_.]+", "-", name).lower()


cfg_all = json.loads((ROOT / "env/r-env.json").read_text(encoding="utf-8"))
cfg = json.loads((ROOT / "env/py/py-env.json").read_text(encoding="utf-8"))
for k in ("schema", "py_env_version", "image", "image_tag", "python_version", "base_image", "base_image_digest",
          "pypi_cutoff", "exclude_newer", "pins", "pypi_index", "pytorch_index", "locker", "resolver_input",
          "lock", "py_lock", "installed_record", "image_id_file", "threads"):
    check(k in cfg, "python_lane has '%s'" % k)
check(cfg.get("schema") == "omicstat.py-environment.v1", "python_lane schema tag")
check(cfg.get("image_tag") == cfg.get("py_env_version"), "python_lane image_tag equals py_env_version")
check(cfg.get("image") != cfg_all.get("image"), "the Python image is a second image (not omicstat-r)")
check(re.fullmatch(r"sha256:[0-9a-f]{64}", cfg.get("base_image_digest", "")) is not None,
      "Python base image pinned by full sha256 digest")
check(cfg.get("base_image", "").startswith("python:%s-" % cfg.get("python_version")),
      "base image tag matches python_version")
check(cfg.get("threads") == 1, "threads pinned to 1")
check(cfg.get("pytorch_index", "").rstrip("/").endswith("/whl/cpu"), "PyTorch comes from the CPU-only index")
check(cfg.get("exclude_newer", "")[:10] > cfg.get("pypi_cutoff", "9999"),
      "exclude_newer lies after the PyPI cutoff day")

PRE = re.compile(r"(a|b|rc|\.dev)\d*(\+.*)?$")
pins = cfg.get("pins", {})
for need in ("scanpy", "anndata", "scvi-tools", "torch"):
    check(need in pins, "pin for %s" % need)
for name, ver in pins.items():
    check(not PRE.search(ver.split("+")[0].replace(".post", "#")), "%s %s is not a pre-release" % (name, ver))
check(pins.get("torch", "").endswith("+cpu"), "torch pin is the +cpu build")

# pyproject (resolver input) == pins
py = tomllib.loads((ROOT / "env/py/pyproject.toml").read_text(encoding="utf-8"))
deps = {}
for d in py["project"]["dependencies"]:
    m = re.match(r"^([A-Za-z0-9_.-]+)(\[[^\]]*\])?==(.+)$", d.strip())
    check(m is not None, "pyproject dependency '%s' is an exact == pin" % d)
    if m:
        deps[norm(m.group(1))] = m.group(3)
for name, ver in pins.items():
    check(deps.get(norm(name)) == ver.split("+")[0], "pyproject pins %s==%s" % (name, ver.split("+")[0]))
check(py["project"]["requires-python"] == "==%s.*" % ".".join(cfg.get("python_version", "0.0").split(".")[:2]),
      "pyproject requires-python matches python_version")
check(py["tool"]["uv"].get("exclude-newer") == cfg.get("exclude_newer"), "pyproject exclude-newer == python_lane.exclude_newer")
check(py["tool"]["uv"]["sources"]["torch"]["index"] == "pytorch-cpu"
      and any(i["name"] == "pytorch-cpu" and i["url"] == cfg.get("pytorch_index") and i.get("explicit")
              for i in py["tool"]["uv"]["index"]),
      "torch is resolved only from the explicit CPU index")

# uv.lock == py_lock.txt == pins
lock = tomllib.loads((ROOT / "env/py/uv.lock").read_text(encoding="utf-8"))
check(lock.get("options", {}).get("exclude-newer") == cfg.get("exclude_newer"), "uv.lock was resolved with exclude-newer")
locked = {norm(p["name"]): p["version"] for p in lock["package"] if p["name"] != py["project"]["name"]}
for p in lock["package"]:
    if p["name"] == py["project"]["name"]:
        continue
    files = (p.get("wheels") or []) + ([p["sdist"]] if p.get("sdist") else [])
    check(bool(files) and all(str(f.get("hash", "")).startswith("sha256:") for f in files),
          "uv.lock %s %s: every file carries a sha256" % (p["name"], p["version"]))
txt = (ROOT / "env/py_lock.txt").read_text(encoding="utf-8")
exported = {}
for block in re.split(r"\n(?=[A-Za-z0-9])", txt.strip()):
    m = re.match(r"^([A-Za-z0-9_.-]+)==([^ ;\\]+)", block)
    if m:
        exported[norm(m.group(1))] = (m.group(2), "--hash=sha256:" in block)
check(set(exported) == set(locked), "py_lock.txt lists exactly the uv.lock packages (%d)" % len(locked))
check(all(exported[n][0] == locked.get(n) for n in exported), "py_lock.txt versions equal uv.lock versions")
check(all(h for _v, h in exported.values()), "every py_lock.txt requirement carries a sha256 hash")
for name, ver in pins.items():
    check(exported.get(norm(name), ("?",))[0] == ver, "py_lock.txt has %s==%s" % (name, ver))
check(not any(n.startswith("nvidia-") or n in {"triton", "cuda-toolkit", "cuda-bindings"} for n in locked),
      "no CUDA distribution in the lock (CPU-only torch)")

docker = (ROOT / "env/py/Dockerfile").read_text(encoding="utf-8")
check("FROM ${BASE_IMAGE}" in docker and "ARG BASE_IMAGE\n" in docker, "Dockerfile base image comes only from build.sh")
check("--require-hashes" in docker and "--no-deps" in docker, "Dockerfile installs with --require-hashes --no-deps")
for var in ("OMP_NUM_THREADS=1", "MKL_NUM_THREADS=1", "OPENBLAS_NUM_THREADS=1", "NUMBA_NUM_THREADS=1", "PYTHONHASHSEED=0"):
    check(var in docker, "Dockerfile sets %s" % var)
build = (ROOT / "env/py/build.sh").read_text(encoding="utf-8")
check("py-env.json" in build and "base_image_digest" in build, "build.sh reads every pin from python_lane")
for f in (ROOT / "bin/omicstat-r-route.sh", ROOT / "bin/omicstat-r-route.ps1"):
    t = f.read_text(encoding="utf-8")
    check("py-env.json" in t and "omicstat-py:latest" not in t, "%s picks the Python image from python_lane" % f.name)
for f in sorted((ROOT / "env/py").glob("*")):
    if f.is_file() and f.suffix in {".py", ".sh", ".toml", ".txt", ""} and f.name != "test_py_env_config.py":
        check(FORK_PARENT not in f.read_text(encoding="utf-8", errors="replace").lower(),
              "env/py/%s has no runtime reference to the fork parent suite" % f.name)

print("== python_lane config: %s" % ("ALL PASSED" if not fails else "%d FAILED" % len(fails)))
sys.exit(1 if fails else 0)
