"""Offline candidate invariants shared by build and promotion tools."""
from __future__ import annotations
import csv,hashlib,json,pathlib,re
ROOT=pathlib.Path(__file__).resolve().parents[2]

def load(path):return json.loads(pathlib.Path(path).read_text())
def dump(obj):return json.dumps(obj,indent=2,sort_keys=True)+"\n"
def sha(path):return hashlib.sha256(pathlib.Path(path).read_bytes()).hexdigest()
def norm(name):return re.sub(r"[-_.]+","-",name).lower()
def safe_rel(path):
    p=pathlib.PurePosixPath(path)
    if not path or p.is_absolute() or ".." in p.parts or "\\" in path:raise ValueError("unsafe relative path: "+path)
    return p

def manifest(candidate, root=ROOT):
    candidate=pathlib.Path(candidate).resolve();root=pathlib.Path(root).resolve()
    if not candidate.is_relative_to(root/"env"):raise ValueError("candidate must live under repository env/")
    m=load(candidate/"manifest.json")
    required=("schema","id","lane","base_image","base_image_id","image_tag","target_layer","target_env_version","new_packages","state")
    if any(k not in m for k in required) or m["schema"]!="omicstat.env-candidate.v1":raise ValueError("incomplete candidate manifest")
    if m["lane"] not in ("R","py") or m["state"] not in ("planned","resolved","built"):raise ValueError("invalid lane/state")
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]+",m["id"]):raise ValueError("unsafe candidate ID")
    image="omicstat-r" if m["lane"]=="R" else "omicstat-py"
    if not m["base_image"].startswith(image+":") or not m["image_tag"].startswith(image+":candidate-"):raise ValueError("candidate must preserve its independent lane lineage")
    if m["base_image_id"] is not None and not re.fullmatch(r"sha256:[0-9a-f]{64}",m["base_image_id"]):raise ValueError("base image ID must be a full SHA256")
    if not re.fullmatch(r"(?:py-)?L\d+_[a-z_]+",m["target_layer"]):raise ValueError("invalid target layer")
    if not isinstance(m["new_packages"],list) or len(set(m["new_packages"]))!=len(m["new_packages"]) or (not m["new_packages"] and m["state"]!="planned"):raise ValueError("new packages must be unique; only unresolved plans may be empty")
    return m

def sources(candidate):
    p=pathlib.Path(candidate)/"sources.lock.json"
    d=load(p)
    rows=d if isinstance(d,list) else d.get("sources",[])
    out=[]
    lane=load(pathlib.Path(candidate)/"manifest.json")["lane"]
    for x in rows:
        row={"package":x.get("package",x.get("Package")),"version":x.get("version",x.get("Version")),
             "filename":x.get("filename"),"url":x.get("url"),"sha256":x.get("sha256")}
        for key in ("kind","ppm_snapshot_url","platform"):
            if key in x:row[key]=x[key]
        if lane=="R":
            from r_artifacts import record_policy
            record_policy(row)
        if any(not row[k] for k in ("package","version","filename","url","sha256")):raise ValueError("source lock has unresolved fields")
        safe_rel(row["filename"])
        if pathlib.PurePosixPath(row["filename"]).name!=row["filename"]:raise ValueError("source filename must be flat")
        if not row["url"].startswith("https://") or not re.fullmatch(r"[0-9a-f]{64}",row["sha256"]):raise ValueError("source needs HTTPS and full SHA256")
        out.append(row)
    if len({r["filename"] for r in out})!=len(out):raise ValueError("duplicate archive filename")
    return out

def check_sources(candidate, rows):
    errors=[]
    for r in rows:
        p=pathlib.Path(candidate)/"sources"/r["filename"]
        if not p.is_file():errors.append("missing source: "+r["filename"])
        elif sha(p)!=r["sha256"]:errors.append("source SHA mismatch: "+r["filename"])
    return errors

def inventory(text):
    rows=list(csv.DictReader(text.splitlines()));result={}
    for row in rows:
        key=row.get("package",row.get("Package",row.get("name")))
        if not key or key in result:raise ValueError("inventory has missing/duplicate package")
        result[key]=row
    if not result:raise ValueError("empty package inventory")
    return result

def additive_diff(base_text, new_text, expected, lane="R"):
    base,new=inventory(base_text),inventory(new_text)
    canonical=norm if lane=="py" else lambda x:x
    b={canonical(k):v for k,v in base.items()};n={canonical(k):v for k,v in new.items()}
    removed=sorted(set(b)-set(n));changed=[];metadata_added=set()
    for k in set(b)&set(n):
        # New dependency metadata is allowed; every inherited field is exact.
        if any(n[k].get(c)!=v for c,v in b[k].items()):changed.append(k)
        added=set(n[k])-set(b[k]);metadata_added.update(added)
        if added-{"deps"}:changed.append(k)
    added=sorted(set(n)-set(b));wanted={canonical(x) for x in expected}
    return {"ok":not removed and not changed and set(added)==wanted,"added":added,
            "removed":removed,"changed":sorted(set(changed)),"unexpected_added":sorted(set(added)-wanted),
            "missing_expected":sorted(wanted-set(added)),"metadata_columns_added":sorted(metadata_added)}

def structural_check(candidate, root=ROOT):
    m=manifest(candidate,root);rows=sources(candidate);errors=[]
    if m["state"]!="planned" and not rows:errors.append("resolved candidate has no source lock")
    if rows and {norm(r["package"]) for r in rows}!={norm(p) for p in m["new_packages"]}:errors.append("source packages differ from additive package declaration")
    if m["lane"]=="R" and rows:
        from r_artifacts import candidate_policy
        candidate_policy(m,rows,root)
    docker=(pathlib.Path(candidate)/"Dockerfile").read_text()
    if "ARG BASE_IMAGE" not in docker or "FROM ${BASE_IMAGE}" not in docker:errors.append("Dockerfile must inherit the supplied exact base")
    if len(re.findall(r"^FROM ",docker,re.M))!=1:errors.append("candidate must have exactly one inherited image stage")
    if re.search(r"\b(?:curl|wget|apt-get|yum|conda install)\b",docker):errors.append("network provisioning belongs in a separately resolved source layer")
    if m["lane"]=="py" and not m.get("exclude_newer"):errors.append("Python candidate needs uv exclude-newer cutoff")
    return m,rows,errors
