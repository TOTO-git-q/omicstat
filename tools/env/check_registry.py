#!/usr/bin/env python3
"""Check candidate/history metadata without claiming absent images were built."""
import pathlib,sys
from common import ROOT,load,structural_check,sha

def check(root=ROOT):
    root=pathlib.Path(root);errors=[];rows=[]
    paths=sorted((root/"env/candidates").glob("*/manifest.json"))+sorted((root/"env/py/candidates").glob("*/manifest.json"))+sorted((root/"env/history").glob("*/manifest.json"))
    ids=set();targets=set();tags=set()
    for p in paths:
        try:
            m,src,issues=structural_check(p.parent,root)
            errors.extend(m["id"]+": "+e for e in issues)
            for key,seen in [(m["id"],ids),(m["image_tag"],tags),((m["lane"],m["target_layer"]),targets)]:
                if key in seen:errors.append("duplicate candidate identity/tag/layer: "+str(key))
                seen.add(key)
            parent=m.get("parent_candidate")
            if parent:
                q=root/parent/"manifest.json"
                if not q.is_file():q=root/"env/history"/pathlib.Path(parent).name/"manifest.json"
                pm=load(q)
                if pm["lane"]!=m["lane"] or pm["image_tag"]!=m["base_image"]:errors.append(m["id"]+": invalid parent lineage")
            report=p.parent/"candidate_report.json"
            if "history" in p.parts and not report.exists():errors.append(m["id"]+": archived candidate lacks build evidence")
            if report.exists():
                r=load(report)
                for key,file in [("manifest_sha256","manifest.json"),("source_lock_sha256","sources.lock.json"),("packages_sha256","packages.csv")]:
                    if r.get(key)!=sha(p.parent/file):errors.append(m["id"]+": build evidence SHA drift: "+file)
            rows.append({"id":m["id"],"state":m["state"],"build_evidence_present":report.exists()})
        except (ValueError,OSError,KeyError) as e:errors.append(str(p)+": "+str(e))
    return errors,rows
if __name__=="__main__":
    import json
    errors,rows=check();print(json.dumps({"ok":not errors,"errors":errors,"candidates":rows},indent=2));sys.exit(bool(errors))
