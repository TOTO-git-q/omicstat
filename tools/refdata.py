#!/usr/bin/env python3
"""Validate registry metadata or offline payloads. Never fetch, deploy or license data.

--metadata-only is not payload acceptance. --check verifies every selected
entry and returns nonzero for unresolved, missing or mismatched payloads.
"""
import argparse,hashlib,json,pathlib,re,sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
ALLOW={"CC0-1.0","CC-BY-4.0","Artistic-2.0","MIT","BSD-2-Clause","BSD-3-Clause","GPL-2","GPL-3","GPL-2.0-only","GPL-2.0-or-later","GPL-3.0-only","GPL-3.0-or-later","LGPL-2.1-only","LGPL-2.1-or-later","LGPL-3.0-only","LGPL-3.0-or-later","Apache-2.0"}
KINDS={"annotation","geneset","reference_profiles","model","coordinates","ortholog","cellchat_db"}

def load(path):return json.loads(pathlib.Path(path).read_text())
def digest(path):
    h=hashlib.sha256()
    with pathlib.Path(path).open("rb") as f:
        while b:=f.read(1024*1024):h.update(b)
    return h.hexdigest()

def metadata(registry,root=ROOT):
    problems=[];entries=registry.get("entries",[]);ids=[e.get("id") for e in entries]
    if registry.get("schema")!="omicstat.refdata.v2":problems.append("registry schema must be omicstat.refdata.v2")
    if len(ids)!=len(set(ids)):problems.append("duplicate refdata ID")
    for e in entries:
        rid=e.get("id","");prefix=rid+": "
        required=("id","kind","source_url","version","sha256","licence","redistribution","species","consumers","fetch","tier","status")
        if any(k not in e for k in required):problems.append(prefix+"missing v2 field");continue
        if e["kind"] not in KINDS or e["tier"] not in ("container","dev"):problems.append(prefix+"invalid kind/tier")
        if e["redistribution"] not in ("bundled_in_image","build_cached","user_supplied"):problems.append(prefix+"invalid redistribution mode")
        if e["sha256"] is not None and not re.fullmatch(r"[0-9a-f]{64}",e["sha256"]):problems.append(prefix+"invalid SHA256")
        if e["status"] not in ("ready","pending"):problems.append(prefix+"invalid status")
        if e["status"]=="ready" and (not e["source_url"] or not e["version"] or not e["sha256"] or e.get("licence_status")!="verified"):problems.append(prefix+"ready requires resolved version/hash and verified licence")
        licence=e["licence"]
        if licence is not None and licence not in ALLOW and not licence.startswith("custom:https://") and not licence.startswith("CC-BY-NC") and not licence.startswith("CC-BY-ND"):
            problems.append(prefix+"licence must be an explicit SPDX identifier or custom HTTPS terms")
        if e["redistribution"]=="bundled_in_image" and (licence not in ALLOW or e.get("licence_status")!="verified"):
            problems.append(prefix+"bundling requires verified allowlisted terms")
        if e["redistribution"]=="build_cached" and licence not in ALLOW and not e.get("internal_use_declaration"):
            problems.append(prefix+"restricted internal cache requires an explicit internal-use declaration")
        if rid.startswith(("dorothea","collectri","progeny","omnipath")) and e["redistribution"]!="user_supplied":
            problems.append(prefix+"owner requires user_supplied for decoupler/OmniPath resources")
        if "kegg" in rid.lower() and e["redistribution"]!="user_supplied":problems.append(prefix+"KEGG remains excluded from bundled data")
        if not isinstance(e["consumers"],list) or not isinstance(e["fetch"],dict):problems.append(prefix+"invalid consumers/fetch contract")
    byid={e["id"]:e for e in entries}
    for p in (pathlib.Path(root)/"skills").glob("*/module.json"):
        m=load(p)
        for rid in m.get("refdata",[]):
            if rid not in byid:problems.append(m["name"]+": unknown refdata "+rid);continue
            if byid[rid]["redistribution"]=="user_supplied":
                contract=m.get("refdata_contracts",{}).get(rid,{})
                flag=contract.get("provenance_flag")
                if not flag or not flag.endswith("-provenance") or not contract.get("input_flag"):
                    problems.append(m["name"]+": user-supplied refdata requires explicit input/provenance flags")
                else:
                    src="\n".join(f.read_text() for f in (p.parent/"scripts").glob("*") if f.suffix in (".R",".py"))
                    if flag not in src and not re.search(r'\bos_flag\s*\(\s*[\"\']'+re.escape(flag.removeprefix('--'))+r'[\"\']',src):problems.append(m["name"]+": provenance flag absent from module scripts")
    return problems

def tree_digest(folder):
    folder=pathlib.Path(folder);lines=[]
    for p in sorted(folder.rglob("*"),key=lambda p:p.relative_to(folder).as_posix()):
        if p.is_symlink():raise ValueError("reference tree contains a symlink; materialize and lock real payloads")
        if p.is_file():lines.append(digest(p)+"  "+p.relative_to(folder).as_posix()+"\n")
    return hashlib.sha256("".join(lines).encode()).hexdigest()

def check_entry(entry,root):
    rid=entry["id"];payload=entry.get("payload",{});rel=payload.get("path");expected=payload.get("sha256",entry.get("sha256"))
    if entry.get("status")!="ready" or not rel or not expected:return {"id":rid,"status":"pending","reason":"payload locator/version/hash or licence review is unresolved"}
    root=pathlib.Path(root).resolve();p=pathlib.Path(rel)
    if p.is_absolute() or ".." in p.parts:return {"id":rid,"status":"fail","reason":"payload path must stay relative to reference root"}
    path=(root/p).resolve()
    if not path.is_relative_to(root):return {"id":rid,"status":"fail","reason":"payload symlink escapes reference root"}
    if not path.exists():return {"id":rid,"status":"fail","reason":"payload missing"}
    kind=payload.get("hash_kind","file")
    if kind=="tree" and path.is_dir():actual=tree_digest(path)
    elif kind=="file" and path.is_file():actual=digest(path)
    else:return {"id":rid,"status":"pending","reason":"semantic verifier or payload kind is not yet supplied"}
    return {"id":rid,"status":"pass" if actual==expected else "fail","actual_sha256":actual,"expected_sha256":expected}

# One runtime implementation, also exercised by the command-line tests.
sys.path.insert(0,str(ROOT/"skills/_shared/py"))
from ospy.refdata import user_supplied

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--registry",type=pathlib.Path,default=ROOT/"env/refdata_registry.json");p.add_argument("--root",type=pathlib.Path,default=ROOT)
    p.add_argument("--payload-root",type=pathlib.Path,default=pathlib.Path("/opt/omicstat/refdata"));p.add_argument("--metadata-only",action="store_true");p.add_argument("--check",action="store_true");p.add_argument("--id",action="append",default=[]);p.add_argument("--tier",choices=["container","dev"]);a=p.parse_args()
    try:
        registry=load(a.registry);errors=metadata(registry,a.root)
        entries=[e for e in registry["entries"] if (not a.id or e["id"] in a.id) and (not a.tier or e["tier"]==a.tier)]
        missing=set(a.id)-{e["id"] for e in entries}
        errors.extend("unknown/unselected ID: "+s for s in sorted(missing))
        records=[] if a.metadata_only else [check_entry(e,a.payload_root) for e in entries]
        ok=not errors and all(r["status"]=="pass" for r in records)
        print(json.dumps({"ok":ok,"mode":"metadata_only" if a.metadata_only else "offline_payload_check","problems":errors,"entries":records},indent=2));return int(not ok)
    except (ValueError,OSError,KeyError) as e:print(json.dumps({"ok":False,"error":str(e)}));return 1
if __name__=="__main__":raise SystemExit(main())
