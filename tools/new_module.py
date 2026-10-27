#!/usr/bin/env python3
"""Scaffold a new omicstat module from templates/module (ENGINEERING_PLAN 4.2).

Usage: python tools/new_module.py <pkg> <part> [--prefix XX] [--force] [--python]
  e.g. python tools/new_module.py deseq2 wald   -> skills/deseq2-wald/
       python tools/new_module.py scanpy cluster --python   -> skills/scanpy-cluster/ (Python/scverse lane)

--python (ENGINEERING_PLAN 10.4 lock 2): scripts/tests/SKILL.md come from
templates/module_py/ (run_<pkg>_<part>.py + <pkg>_<part>_{core,report,qc}.py,
tests/run_smoke_test.py); references/ come from templates/module/ unless
templates/module_py/references/ has a file of the same name (parameters.md).

Fills module name, entry-script name, QC rule prefix (appendix A table; a
prefix already used by medstat or by another omicstat module gets an 'O'
in front) and the SKILL.md section headings. Content is written at S2.
"""
import argparse, csv, json, pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
TEMPLATES = ROOT / "templates" / "module"
TEMPLATES_PY = ROOT / "templates" / "module_py"
def package_case(pkg):
    from package_inventory import packages
    name=packages(ROOT,candidate=True).get(pkg.lower().replace('-',''))
    if name:return name
    raise SystemExit("OS_MISSING_PACKAGE: prefix needs a locked or attested observed candidate package")


def used_prefixes():
    used = set()
    for f in (ROOT / "skills").glob("*/references/qc-rules.md"):
        used |= set(re.findall(r"\b([A-Z]{2,4})-\d{2}\b", f.read_text(encoding="utf-8")))
    return used


def resolve_prefix(module, explicit):
    table = json.loads((ROOT / "tools" / "qc_prefixes.json").read_text(encoding="utf-8"))
    p = explicit or table["planned"].get(module)
    if not p:
        sys.exit(f"OS_INVALID_PARAMETER: no planned QC prefix for {module}; pass --prefix")
    taken = set(table["medstat_prefixes"]) | used_prefixes()
    if p in taken:
        p = "O" + p
    if p in used_prefixes():
        sys.exit(f"OS_INVALID_PARAMETER: QC prefix {p} already used in this suite")
    return p


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("pkg"); ap.add_argument("part")
    ap.add_argument("--adopt", action="store_true", help="adopt existing candidate sources without rewriting them")
    ap.add_argument("--domain", default="basic-stats")
    ap.add_argument("--question", default="Candidate analysis module; review its input contract")
    ap.add_argument("--prefix"); ap.add_argument("--force", action="store_true")
    ap.add_argument("--python", action="store_true", help="scaffold a Python/scverse-lane module")
    a = ap.parse_args()
    domain_schema=json.loads((ROOT/'skills/_shared/schemas/module.v1.schema.json').read_text())
    if a.domain not in domain_schema['properties']['domain']['enum']:sys.exit('OS_INVALID_PARAMETER: unknown module domain')
    pkg, part = a.pkg.lower(), a.part.lower()
    if not re.fullmatch(r"[a-z0-9]+", pkg) or not re.fullmatch(r"[a-z0-9]+", part):
        sys.exit("OS_INVALID_PARAMETER: pkg and part must be lowercase alphanumerics")
    module = f"{pkg}-{part}"
    dest = ROOT / "skills" / module
    if (dest / "module_lock.json").exists() and a.force:
        sys.exit("OS_INVALID_PARAMETER: owner seal freeze forbids overwriting an existing sealed module")
    if dest.exists() and not a.force and not a.adopt:
        sys.exit(f"OS_INVALID_PARAMETER: {dest} exists (use --force to overwrite template files)")
    subs = {"{{module}}": module, "{{pkg}}": pkg, "{{part}}": part,
            "{{pkg_cased}}": package_case(pkg), "{{prefix}}": resolve_prefix(module, a.prefix)}
    renames = {"run.R.tmpl": f"run_{pkg}_{part}.R", "core.R.tmpl": f"{pkg}_{part}_core.R",
               "report.R.tmpl": f"{pkg}_{part}_report.R", "qc.R.tmpl": f"{pkg}_{part}_qc.R",
               "run.py.tmpl": f"run_{pkg}_{part}.py", "core.py.tmpl": f"{pkg}_{part}_core.py",
               "report.py.tmpl": f"{pkg}_{part}_report.py", "qc.py.tmpl": f"{pkg}_{part}_qc.py"}
    if a.python:
        # Python lane: its own scripts/tests/SKILL.md; references shared with the R
        # template unless module_py overrides a file of the same name.
        sources = {s.relative_to(TEMPLATES): s for s in TEMPLATES.glob("references/*.tmpl")}
        sources.update({s.relative_to(TEMPLATES_PY): s for s in TEMPLATES_PY.rglob("*.tmpl")})
    else:
        sources = {s.relative_to(TEMPLATES): s for s in TEMPLATES.rglob("*.tmpl")}
    for rel in ([] if a.adopt else sorted(sources)):
        if "golden" in str(rel): continue  # owner section 0: no golden writes
        src = sources[rel]
        name = renames.get(rel.name, rel.name[:-5])
        out = dest / rel.parent / name
        out.parent.mkdir(parents=True, exist_ok=True)
        text = src.read_text(encoding="utf-8")
        for k, v in subs.items():
            text = text.replace(k, v)
        out.write_text(text, encoding="utf-8", newline="\n")
    (dest / "tests" / "fixtures").mkdir(parents=True, exist_ok=True)
    from sync_registry import sync
    prefix=subs['{{prefix}}']; lane="py" if a.python else "R"
    existing=[json.loads(p.read_text()) for p in (ROOT/'skills').glob('*/module.json')]
    meta={"schema":"omicstat.module.v1","name":module,"lane":lane,"domain":a.domain,
          "entry":f"scripts/run_{pkg}_{part}."+("py" if a.python else "R"),"version":"0.1.0",
          "qc_prefix":prefix,"engine_packages":[] if pkg=="omicstat" else [package_case(pkg)],"refdata":[],
          "handoff":{"inputs":[],"outputs":[]},"figure_builders":[],"anchors":"tests/anchors.json",
          "refusals":"tests/refusals.csv","routing":{"order":max([m['routing']['order'] for m in existing],default=-1)+1,"question":a.question},
          "publication":{"rule_category":"universal_hard"},"status":"candidate","status_notes":["owner_seal_freeze","scientific_review_pending"],"inputs":[],
          "reference":{"enabled":False,"added_at":"2026-10-16"}}
    (dest/'module.json').write_text(json.dumps(meta,indent=2)+"\n")
    registry=dest/'scripts/calls_registry.json'
    if registry.exists() and not a.adopt:
        reg=json.loads(registry.read_text());reg['module_version']=meta['version'];registry.write_text(json.dumps(reg,indent=2)+"\n")
    sync(ROOT)
    print(f"created {dest.relative_to(ROOT)} (QC prefix {subs['{{prefix}}']}{', Python lane' if a.python else ''})")


if __name__ == "__main__":
    main()
