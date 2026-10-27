#!/usr/bin/env python3
"""One-time candidate source resolution. No analysis-runtime downloads.

R candidates declare exact versioned HTTPS archives in manifest.sources.
Python candidates extend a copied uv lock under the fixed release cutoff;
any inherited version change is refused before a source lock is produced.
"""
import argparse,email.parser,hashlib,json,pathlib,re,subprocess,tarfile,tomllib,urllib.parse,urllib.request
from common import ROOT,manifest,load,dump,sha,norm,safe_rel,inventory
from r_artifacts import candidate_policy, inspect_archive

def r_description(path, row=None, policy=None):
    result=inspect_archive(path,row,policy)
    deps=[]
    for field in ("Depends","Imports","LinkingTo"):
        deps.extend(re.sub(r"\s*\([^)]*\)","",x).strip() for x in result.get(field,"").split(",") if x.strip())
    return result.get("Package"),result.get("Version"),[d for d in deps if d!="R"]

def install_order(rows):
    remaining={r["package"]:set(r.get("dependencies",[])) for r in rows};order=[]
    while remaining:
        ready=sorted(k for k,v in remaining.items() if not (v & remaining.keys()))
        if not ready:raise ValueError("candidate source dependencies have a cycle")
        order.extend(ready)
        for key in ready:del remaining[key]
    return order

def python_sources(candidate,m,root):
    if not (candidate/"pyproject.toml").is_file():raise ValueError("Python candidate needs a reviewed pyproject.toml")
    parent=root/m["parent_candidate"] if m.get("parent_candidate") else root/"env/py"
    lock=parent/"uv.lock"; inv=parent/("packages.csv" if m.get("parent_candidate") else "py_installed.csv")
    if not lock.is_file() or not inv.is_file():raise ValueError("resolve/build parent candidate first; inherited lock/inventory required")
    inherited=tomllib.loads(lock.read_text())["package"]
    if not (candidate/"uv.lock").exists():(candidate/"uv.lock").write_bytes(lock.read_bytes())
    subprocess.run(["uv","lock","--project",str(candidate),"--exclude-newer",m["exclude_newer"]],check=True)
    locked=tomllib.loads((candidate/"uv.lock").read_text())["package"]
    current={norm(p["name"]):p for p in locked}
    for old in inherited:
        if "virtual" in old.get("source",{}) or "editable" in old.get("source",{}):continue
        new=current.get(norm(old["name"]),{})
        for field in ("version","source","sdist","wheels"):
            if new.get(field)!=old.get(field):raise ValueError("inherited uv lock identity/hash changed: "+old["name"]+"/"+field)
    subprocess.run(["uv","export","--project",str(candidate),"--frozen","--no-emit-project","--format","requirements-txt","--output-file",str(candidate/"requirements.lock.txt")],check=True)
    base=inventory(inv.read_text());base={norm(k):v["version"] for k,v in base.items()}
    from packaging.tags import cpython_tags,compatible_tags
    from packaging.utils import parse_wheel_filename
    py=tuple(map(int,m.get("python_version","3.12").split(".")[:2]));abi="cp"+"".join(map(str,py))
    platforms=["manylinux_2_%d_x86_64"%v for v in range(36,16,-1)]+["manylinux2014_x86_64","linux_x86_64"]
    tags=list(cpython_tags(py,[abi],platforms))+list(compatible_tags(py,interpreter=abi,platforms=platforms));rank={t:i for i,t in enumerate(tags)}
    rows=[]
    for p in locked:
        if "virtual" in p.get("source",{}) or "editable" in p.get("source",{}):continue
        key=norm(p["name"])
        if key in base:
            # Installed +cpu local-version suffix must never be replaced.
            if p["version"]!=base[key] and not (base[key].startswith(p["version"]+"+") and key=="torch"):
                raise ValueError("uv resolution changed inherited package "+key)
            continue
        choices=[]
        for w in p.get("wheels",[]):
            filename=urllib.parse.unquote(urllib.parse.urlparse(w["url"]).path.rsplit("/",1)[-1])
            _,_,_,wtags=parse_wheel_filename(filename);matching=[rank[t] for t in wtags if t in rank]
            if matching:choices.append((min(matching),filename,w))
        if not choices:raise ValueError("no locked compatible wheel for "+key+"; resolve native source prerequisites explicitly")
        _,filename,w=min(choices,key=lambda x:(x[0],x[1]))
        rows.append(dict(package=p["name"],version=p["version"],url=w["url"],filename=filename,sha256=w["hash"].removeprefix("sha256:"),dependencies=[d["name"] for d in p.get("dependencies",[])]))
    if not {norm(p) for p in m["new_packages"]} <= {norm(r["package"]) for r in rows}:raise ValueError("resolution lacks a requested new package")
    return rows

def resolve(candidate,root=ROOT,download=False,lock_python=False):
    candidate=pathlib.Path(candidate).resolve();root=pathlib.Path(root).resolve();m=manifest(candidate,root)
    from source_metadata import additive_metadata_errors
    metadata_errors=additive_metadata_errors(candidate,m,root)
    if metadata_errors:raise ValueError('; '.join(metadata_errors))
    if m.get('isolated_profile'):raise ValueError('isolated dependency profile required; additive resolution forbidden')
    rows=python_sources(candidate,m,root) if lock_python else m.get("sources",[])
    if not rows:raise ValueError("exact source URLs/versions are unresolved; do not guess newest versions")
    policy=candidate_policy(m,rows,root) if m["lane"]=="R" else None
    out=[];folder=candidate/"sources"
    if download:folder.mkdir(exist_ok=True)
    for row in rows:
        r=dict(row);safe_rel(r["filename"])
        if pathlib.PurePosixPath(r["filename"]).name!=r["filename"]:raise ValueError("flat source filenames required")
        parsed=urllib.parse.urlparse(r["url"])
        if parsed.scheme!="https" or parsed.username or parsed.password:raise ValueError("HTTPS sources without embedded credentials required")
        path=folder/r["filename"]
        if not path.exists():
            if not download:raise ValueError("source not cached; explicit --download required: "+r["filename"])
            partial=path.with_suffix(path.suffix+".part")
            try:
                with urllib.request.urlopen(r["url"],timeout=120) as response,partial.open("wb") as f:
                    while block:=response.read(1024*1024):f.write(block)
                partial.replace(path)
            finally:
                if partial.exists():partial.unlink()
        digest=sha(path)
        if r.get("sha256") and digest!=r["sha256"]:raise ValueError("source SHA mismatch: "+r["filename"])
        r["sha256"]=digest
        if m["lane"]=="R":
            name,version,deps=r_description(path,r,policy)
            if name!=r["package"] or version!=r["version"]:raise ValueError("archive identity differs from declared package/version")
            r["dependencies"]=deps
        out.append(r)
    if not {norm(p) for p in m["new_packages"]} <= {norm(r["package"]) for r in out}:raise ValueError("source resolution omitted requested packages")
    m.setdefault("requested_packages",m["new_packages"])
    m["new_packages"]=[r["package"] for r in out];m["install_order"]=install_order(out);m["state"]="resolved"
    (candidate/"sources.lock.json").write_text(dump({"schema":"omicstat.env-sources.v1","sources":out}))
    (candidate/"manifest.json").write_text(dump(m))
    return {"state":"resolved","sources":len(out),"manifest_sha256":sha(candidate/"manifest.json"),"source_lock_sha256":sha(candidate/"sources.lock.json")}

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("candidate",type=pathlib.Path);p.add_argument("--root",type=pathlib.Path,default=ROOT);p.add_argument("--download",action="store_true");p.add_argument("--lock-python",action="store_true");a=p.parse_args()
    try:r=resolve(a.candidate,a.root,a.download,a.lock_python)
    except (ValueError,OSError,subprocess.SubprocessError) as e:print(dump({"state":"blocked","error":str(e)}));return 1
    print(dump(r));return 0
if __name__=="__main__":raise SystemExit(main())
