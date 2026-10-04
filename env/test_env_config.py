#!/usr/bin/env python3
"""Mechanical consistency checks of the omicstat R environment definition.

env/omicstat-env.json is the single source of truth; this test fails when the
Dockerfile, the layer files, the GitHub pin file or the routers disagree with
it. Runs anywhere (no docker, no R needed).
"""
import json, pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
fails = []
def check(cond, msg):
    print(("PASS: " if cond else "FAIL: ") + msg)
    if not cond:
        fails.append(msg)

cfg = json.loads((ROOT / "env/omicstat-env.json").read_text(encoding="utf-8"))
for k in ("r_version", "bioconductor", "base_image", "base_image_digest", "cran_snapshot", "cran_repo_linux",
          "cran_repo_other", "image", "image_tag", "layers", "env_version"):
    check(k in cfg, f"omicstat-env.json has '{k}'")
check(re.fullmatch(r"sha256:[0-9a-f]{64}", cfg["base_image_digest"]) is not None, "base image pinned by full sha256 digest")
check(cfg["cran_snapshot"] in cfg["cran_repo_linux"] and cfg["cran_snapshot"] in cfg["cran_repo_other"], "CRAN repos use the dated snapshot")
check("latest" not in cfg["cran_repo_linux"] + cfg["cran_repo_other"], "no floating 'latest' CRAN repo")
check(cfg["base_image"].endswith("R-" + cfg["r_version"]) and ("RELEASE_" + cfg["bioconductor"].replace(".", "_")) in cfg["base_image"],
      "base image tag matches r_version and bioconductor")
check(cfg["image_tag"] == cfg["env_version"], "image_tag equals env_version")

docker = (ROOT / "env/container/Dockerfile").read_text(encoding="utf-8")
copies = re.findall(r"^COPY env/layers/(L\d_[a-z_]+)\.txt", docker, re.M)
runs = re.findall(r"install_layer\.R /opt/omicstat/env (L\d_[a-z_]+)", docker)
check(copies == cfg["layers"], "Dockerfile COPYs every layer file in env order")
check(runs == cfg["layers"], "Dockerfile installs every layer in env order")
check("FROM ${BASE_IMAGE}" in docker and "ARG BASE_IMAGE\n" in docker, "Dockerfile base image comes only from build.sh (no default)")
for layer in cfg["layers"]:
    f = ROOT / "env/layers" / f"{layer}.txt"
    pk = [l.split("#")[0].strip() for l in f.read_text(encoding="utf-8").splitlines()] if f.exists() else []
    pk = [p for p in pk if p]
    check(f.exists() and len(pk) > 0 and len(pk) == len(set(pk)), f"layer {layer}: file exists, non-empty, no duplicates")
all_pk = [p for layer in cfg["layers"] for p in
          [l.split("#")[0].strip() for l in (ROOT / "env/layers" / f"{layer}.txt").read_text(encoding="utf-8").splitlines()] if p]
check(len(all_pk) == len(set(all_pk)), "no package is listed in two layers")
for need in ("ggplot2", "ggrepel", "patchwork", "ragg", "svglite", "ggrastr", "jsonlite", "digest", "gt", "RhpcBLASctl"):
    check(need in all_pk, f"figure/report/determinism dependency '{need}' is in a layer")

pins = [l.split() for l in (ROOT / "env/layers/github_pins.txt").read_text(encoding="utf-8").splitlines()
        if l.strip() and not l.lstrip().startswith("#")]
check(all(len(p) == 4 for p in pins), "github_pins.txt rows have 4 fields")
check(all(p[3] == "UNPINNED" or re.fullmatch(r"[0-9a-f]{40}", p[3]) for p in pins), "github pins are UNPINNED or 40-hex SHAs")
check(all(p[0] in {"L5", "L6", "L8", "DEP"} for p in pins), "github pins belong to L5/L6/L8 or DEP")

sh = (ROOT / "bin/omicstat-r-route.sh").read_text(encoding="utf-8")
ps1 = (ROOT / "bin/omicstat-r-route.ps1").read_text(encoding="utf-8")
check("omicstat-r:latest" not in sh and "omicstat-r:latest" not in ps1, "routers never use a floating image tag")
check("omicstat-env.json" in sh and "omicstat-env.json" in ps1, "routers read the image from omicstat-env.json")
check("R-4.6.0" not in ps1 and "Program Files" not in ps1, "Windows router has no hard-coded R installation")
for f in list((ROOT / "env").rglob("*")) + [ROOT / "bin/omicstat-r-route.sh", ROOT / "bin/omicstat-r-route.ps1", ROOT / "mcp/server.py"]:
    if f.is_file() and f.suffix in {".R", ".sh", ".ps1", ".py", ".json", ".txt", ""} and f.name != "test_env_config.py" and not f.name.endswith("_report.txt"):
        check("medstat" not in f.read_text(encoding="utf-8", errors="replace").lower()
              or f.name == "server.py", f"{f.relative_to(ROOT)} has no medstat runtime reference")
srv = (ROOT / "mcp/server.py").read_text(encoding="utf-8")
check("NATIVE_RSCRIPT" not in srv and "R-4.6.0" not in srv, "server.py has no hard-coded R installation")

sys.exit(1 if fails else 0)
