"""Offline provenance validation. Returns metadata, never unpickles models."""
import hashlib,json,pathlib,re,urllib.parse

def user_supplied(path,provenance,refdata_id):
    path=pathlib.Path(path)
    try:p=json.loads(pathlib.Path(provenance).read_text())
    except (OSError,ValueError) as e:raise ValueError("OS_REFDATA_MISSING: provenance JSON is absent or invalid") from e
    fields=("refdata_id","source_url","version","licence","sha256","permitted_use")
    if not isinstance(p,dict) or any(not isinstance(p.get(k),str) or not p[k].strip() for k in fields):
        raise ValueError("OS_REFDATA_MISSING: explicit provenance fields are required")
    u=urllib.parse.urlsplit(p["source_url"])
    if u.scheme!="https" or not u.hostname or u.username or u.password or not re.fullmatch(r"[0-9a-f]{64}",p["sha256"]):
        raise ValueError("OS_REFDATA_MISMATCH: provenance URL/SHA is invalid")
    if p["refdata_id"]!=refdata_id or not path.is_file():raise ValueError("OS_REFDATA_MISMATCH: payload ID/path differs")
    h=hashlib.sha256()
    with path.open("rb") as f:
        while b:=f.read(1024*1024):h.update(b)
    if h.hexdigest()!=p["sha256"]:raise ValueError("OS_REFDATA_MISMATCH: payload SHA256 differs")
    return dict(p)
