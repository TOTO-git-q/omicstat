#!/usr/bin/env python3
"""Offline wheel-only additive installer, run by the inherited image Python."""
import hashlib,importlib.metadata as md,json,os,pathlib,re,subprocess,sys,zipfile,email

def norm(x):return re.sub(r"[-_.]+","-",x).lower()
def installed():
    rows={}
    for d in md.distributions():
        key=norm(d.metadata["Name"])
        if key in rows:raise ValueError("ambiguous inherited distribution "+key)
        rows[key]=(d.version,(d.read_text("INSTALLER") or "").strip())
    return rows

def install(root):
    root=pathlib.Path(root);m=json.loads((root/"manifest.json").read_text());x=json.loads((root/"sources.lock.json").read_text());rows=x if isinstance(x,list) else x["sources"]
    before=installed();wanted={norm(p) for p in m["new_packages"]}
    if not wanted or wanted!={norm(r["package"]) for r in rows}:raise ValueError("source lock differs from additive declaration")
    if wanted & before.keys():raise ValueError("refusing to replace inherited distributions")
    lines=[]
    for row in rows:
        name=row["filename"]
        if pathlib.PurePath(name).name!=name or "\\" in name or not name.endswith(".whl"):raise ValueError("only flat locked wheels allowed")
        p=root/"sources"/name
        if hashlib.sha256(p.read_bytes()).hexdigest()!=row["sha256"]:raise ValueError("source SHA mismatch")
        with zipfile.ZipFile(p) as z:
            names=[s for s in z.namelist() if s.endswith(".dist-info/METADATA")]
            if len(names)!=1:raise ValueError("wheel metadata is ambiguous")
            meta=email.message_from_bytes(z.read(names[0]))
            if norm(meta["Name"])!=norm(row["package"]) or meta["Version"]!=row["version"]:raise ValueError("wheel identity differs")
        lines.append(p.resolve().as_uri()+" --hash=sha256:"+row["sha256"])
    req=root/"offline-requirements.txt";req.write_text("\n".join(lines)+"\n")
    subprocess.run([sys.executable,"-m","pip","install","--no-index","--no-deps","--require-hashes","-r",str(req)],check=True)
    subprocess.run([sys.executable,"-m","pip","check"],check=True)
    after=installed()
    if any(after.get(k)!=v for k,v in before.items()) or set(after)-set(before)!=wanted:raise ValueError("additive invariant failed")
    subprocess.run([sys.executable,os.environ.get("OMICSTAT_CANDIDATE_WRITER","/opt/omicstat/env/py/write_py_installed.py"),os.environ.get("OMICSTAT_CANDIDATE_INVENTORY","/opt/omicstat/py_installed.csv")],check=True)
if __name__=="__main__":install(os.environ.get("OMICSTAT_CANDIDATE_DIR","/candidate"))
