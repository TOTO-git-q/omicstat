#!/usr/bin/env python3
"""Prepare candidate promotion; current owner policy explicitly forbids apply.

The complete plan is inspectable with --dry-run. A future owner decision must
change the policy and authorize --apply; no CLI flag bypasses that decision.
This tool never writes a module lock, golden, deployment or production route.
"""
import argparse,importlib.util,json,pathlib,shutil,subprocess,tempfile
from common import ROOT,manifest,load,dump,sha,additive_diff

def plan(candidate,root=ROOT):
    root=pathlib.Path(root).resolve();candidate=pathlib.Path(candidate).resolve();m=manifest(candidate,root)
    report=load(candidate/"candidate_report.json")
    if report.get("state")!="built" or not report.get("executed") or not report.get("inventory_diff",{}).get("ok"):
        raise ValueError("promotion requires an actual successful additive candidate report")
    if report.get("manifest_sha256")!=sha(candidate/"manifest.json") or report.get("source_lock_sha256")!=sha(candidate/"sources.lock.json") or report.get("packages_sha256")!=sha(candidate/"packages.csv"):
        raise ValueError("candidate evidence changed since build")
    cfg_path="env/r-env.json" if m["lane"]=="R" else "env/py/py-env.json"
    cfg=load(root/cfg_path);current=cfg["image"]+":"+cfg["image_tag"]
    if m["base_image"]!=current:
        history=root/"env/history"/pathlib.Path(m.get("parent_candidate") or "unresolved").name
        if not (history/"manifest.json").is_file():raise ValueError("promote parent candidate first: current environment is "+current)
        parent=load(history/"manifest.json");evidence=load(history/"candidate_report.json")
        if parent["image_tag"]!=m["base_image"] or parent["target_env_version"]!=cfg["image_tag"] or evidence["image"]["id"]!=m["base_image_id"]:
            raise ValueError("archived parent alias does not identify current canonical image")
    id_path="env/image_id.txt" if m["lane"]=="R" else "env/py/image_id.txt"
    if (root/id_path).read_text().strip()!=m["base_image_id"]:raise ValueError("current image ID differs from candidate parent")
    inv_path="env/pkg_lock.csv" if m["lane"]=="R" else "env/py/py_installed.csv"
    diff=additive_diff((root/inv_path).read_text(),(candidate/"packages.csv").read_text(),m["new_packages"],m["lane"])
    if not diff["ok"]:raise ValueError("current inventory is not an unchanged candidate prefix")
    if m["target_layer"] in cfg.get("layers",[]):raise ValueError("target layer already exists")
    cfg.setdefault("layers",[]).append(m["target_layer"])
    cfg.setdefault("candidate_history",[]).append("env/history/"+m["id"])
    cfg["addon_base_image"]=current;cfg["addon_base_image_id"]=m["base_image_id"]
    cfg["env_version" if m["lane"]=="R" else "py_env_version"]=m["target_env_version"];cfg["image_tag"]=m["target_env_version"]
    canonical=cfg["image"]+":"+cfg["image_tag"]
    layer="env/"+("layers/" if m["lane"]=="R" else "py/layers/")+m["target_layer"]+".txt"
    affected=[]
    for p in (root/"skills").glob("*/module.json"):
        mod=load(p)
        if mod["lane"]==m["lane"] and set(mod["engine_packages"]) & set(m["new_packages"]):affected.append(mod["name"])
    upgrade="docs/upgrade/"+m["target_env_version"]
    text="# Candidate promotion impact\n\nAdditive packages: "+", ".join(m["new_packages"])+".\n\nAffected direct module dependencies: "+(", ".join(sorted(affected)) or "none yet")+".\n\nRun tools/upgrade/news_filter.py against actual archived NEWS; absence is not a no-change finding.\n"
    suite=(root/"SUITE.md").read_text()+f"\n<!-- env-promotion:{m['id']} -->\n## Environment {m['target_env_version']} ({m['lane']})\n\nAdditive layer `{m['target_layer']}`: {', '.join(m['new_packages'])}.\nCandidate evidence archived in `env/history/{m['id']}`.\n"
    changes={cfg_path:dump(cfg),id_path:report["image"]["id"]+"\n",inv_path:(candidate/"packages.csv").read_text(),layer:"\n".join(m["new_packages"])+"\n",upgrade+"/affected_modules.md":text,"SUITE.md":suite}
    if m["lane"]=="py":
        for filename,target in [("uv.lock","env/py/uv.lock"),("pyproject.toml","env/py/pyproject.toml")]:
            if not (candidate/filename).is_file():raise ValueError("Python candidate lacks "+filename)
            changes[target]=(candidate/filename).read_text()
        if not (candidate/"requirements.lock.txt").exists():raise ValueError("Python candidate requires reviewed uv export for py_lock.txt")
        changes["env/py_lock.txt"]=(candidate/"requirements.lock.txt").read_text()
    spec=importlib.util.spec_from_file_location("omicstat_news_filter",root/"tools/upgrade/news_filter.py")
    news=importlib.util.module_from_spec(spec);spec.loader.exec_module(news)
    filtered=news.run(root,{},6)
    changes[upgrade+"/news_filter.md"]=news.render(filtered,"Candidate NEWS scan; missing sources are unresolved")
    preimages={p:sha(root/p) if (root/p).exists() else None for p in changes}
    return {"schema":"omicstat.env-promotion-plan.v1","candidate":m["id"],"lane":m["lane"],"image":report["image"],"canonical_tag":canonical,"archive":"env/history/"+m["id"],"changes":changes,"preimages":preimages,"affected_modules":sorted(affected),"news_filter_command":["python3","tools/upgrade/news_filter.py","--repo",str(root),"--out",upgrade+"/news_filter.md"],"sealing":"deferred_by_owner"}

def apply(candidate,root,proposal):
    root=pathlib.Path(root).resolve();candidate=pathlib.Path(candidate).resolve();policy=load(root/"env/owner_decisions.json")
    if not policy.get("environment_promotion_allowed") or not policy.get("decision_reference"):
        raise PermissionError("deferred_by_owner: environment promotion is frozen; inspect --dry-run only")
    # Recompute all evidence and compare, including current file preimages.
    if plan(candidate,root)!=proposal:raise ValueError("promotion inputs changed after planning")
    if (root/proposal["archive"]).exists():raise ValueError("history destination already exists")
    for rel in proposal["changes"]:
        if "golden" in pathlib.PurePosixPath(rel).parts or pathlib.PurePosixPath(rel).name=="module_lock.json":raise ValueError("protected path in promotion plan")
    image=json.loads(subprocess.check_output(["docker","image","inspect",proposal["image"]["tag"]],text=True))[0]
    if image["Id"]!=proposal["image"]["id"]:raise ValueError("candidate image ID drift")
    probe=subprocess.run(["docker","image","inspect",proposal["canonical_tag"]],capture_output=True,text=True)
    if probe.returncode==0:raise ValueError("canonical target tag already exists; never replace it")
    if "No such image" not in probe.stderr and "No such object" not in probe.stderr:raise ValueError("could not establish canonical tag absence")
    # File backups are reversible. No container is started or restarted.
    backup={rel:(root/rel).read_bytes() if (root/rel).exists() else None for rel in proposal["changes"]}
    tagged=False
    try:
        for rel,content in proposal["changes"].items():
            p=root/rel;p.parent.mkdir(parents=True,exist_ok=True);temp=p.with_name(p.name+".promotion-tmp");temp.write_text(content);temp.replace(p)
        subprocess.run(["docker","tag",proposal["image"]["id"],proposal["canonical_tag"]],check=True)
        tagged=True
        archive=root/proposal["archive"];archive.parent.mkdir(parents=True,exist_ok=True);shutil.move(str(candidate),archive)
    except BaseException as error:
        for rel,content in backup.items():
            p=root/rel
            if content is None:
                if p.exists():p.unlink()
            else:p.write_bytes(content)
        raise RuntimeError("apply failed; metadata files restored; candidate tag created="+str(tagged)+"; inspect archive/tag before retry: "+str(error)) from error
    return {"status":"promoted_metadata","archive":proposal["archive"],"canonical_tag":proposal["canonical_tag"],"deployment_performed":False,"sealing":"deferred_by_owner"}

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("candidate",type=pathlib.Path);p.add_argument("--root",type=pathlib.Path,default=ROOT)
    g=p.add_mutually_exclusive_group();g.add_argument("--dry-run",action="store_true");g.add_argument("--apply",action="store_true");p.add_argument("--out",type=pathlib.Path);a=p.parse_args()
    try:
        if a.apply and not load(a.root/"env/owner_decisions.json").get("environment_promotion_allowed"):raise PermissionError("deferred_by_owner: promotion is frozen")
        result=plan(a.candidate,a.root)
        if a.apply:result=apply(a.candidate,a.root,result)
        else:result={"status":"dry_run","writes_performed":False,"owner_policy":load(a.root/"env/owner_decisions.json"),"plan":result}
        if a.out:a.out.parent.mkdir(parents=True,exist_ok=True);a.out.write_text(dump(result))
        print(dump(result));return 0
    except (ValueError,OSError,RuntimeError,subprocess.SubprocessError) as e:print(dump({"status":"deferred_by_owner" if isinstance(e,PermissionError) else "blocked","error":str(e),"writes_performed": "unknown_after_apply_failure" if a.apply and not isinstance(e,PermissionError) else False}));return 2
if __name__=="__main__":raise SystemExit(main())
