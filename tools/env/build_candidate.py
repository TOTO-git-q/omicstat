#!/usr/bin/env python3
"""Build only a new candidate tag; offline and strictly additive. Never promote."""
import argparse,json,pathlib,shutil,subprocess,sys
from common import ROOT,manifest,structural_check,check_sources,additive_diff,dump,sha,inventory,norm
from r_artifacts import candidate_policy,verify_parent_image,verify_parent_runtime,PARENT_PROBE_R
from check_build_context import check as check_build_context

def command(*argv):return subprocess.check_output(argv,text=True).strip()
def inspect(image):return json.loads(command("docker","image","inspect",image))[0]

def build(candidate, root=ROOT, execute=False):
    candidate=pathlib.Path(candidate).resolve();root=pathlib.Path(root).resolve()
    m,rows,errors=structural_check(candidate,root)
    from source_metadata import additive_metadata_errors
    errors+=additive_metadata_errors(candidate,m,root)
    policy=candidate_policy(m,rows,root) if m["lane"]=="R" else None
    errors+=check_sources(candidate,rows)
    required=[str((candidate/"sources"/r["filename"]).relative_to(root)) for r in rows]
    context=check_build_context(candidate/"Dockerfile",root,required)
    errors+=context["errors"]
    preparation=None
    if m.get("source_preparation_required") or policy:
        from prepare_locked_sources import prepare
        preparation=prepare(candidate,root,expected_lock_sha256=sha(candidate/"sources.lock.json"))
        errors+=preparation["errors"]
    errors=list(dict.fromkeys(errors))
    if m.get('isolated_profile'):errors.append('isolated dependency profile required; additive build forbidden: '+m['isolated_profile'])
    if m.get("system_requirements") and not m.get("system_requirements_verified"):
        errors.append("native prerequisites unresolved: "+", ".join(m["system_requirements"]))
    if not m["base_image_id"]:errors.append("base image ID not yet resolved")
    if m["state"]=="planned":errors.append("source resolution remains pending")
    report={"schema":"omicstat.env-candidate-report.v1","candidate":m["id"],"lane":m["lane"],
            "manifest_sha256":sha(candidate/"manifest.json"),"source_lock_sha256":sha(candidate/"sources.lock.json"),
            "state":"blocked" if errors else "ready_to_build","errors":errors,"executed":False,
            "network":"none","promotion":"deferred_by_owner","disk_free_bytes":shutil.disk_usage(root).free,
            "commands":[["docker","build","--network=none","--pull=false","--build-arg","BASE_IMAGE="+m["base_image"],"-f",str(candidate/"Dockerfile"),"-t",m["image_tag"],str(root)]]}
    report["build_context"]=context
    report["r_artifact_policy"]=policy
    report["actual_parent_runtime_verified"]=False
    if preparation is not None:
        report["source_preparation"]=preparation
        report["source_preparation_command"]=["python3","tools/env/prepare_locked_sources.py",str(candidate.relative_to(root)),"--lock-sha256",sha(candidate/"sources.lock.json"),"--check"]
        report["source_download_automatic"]=False
        report["source_cache_instruction"]="If missing, explicitly supply --source-cache pointing to the already verified exact archives; never substitute bytes or versions."
    if not execute or errors:return report
    # docker inspect must succeed before any build; missing docker is not a pass.
    base=inspect(m["base_image"])
    if base["Id"]!=m["base_image_id"]:raise ValueError("base image identity drift")
    verify_parent_image(base,policy)
    if policy:
        runtime=json.loads(command("docker","run","--rm","--network","none","--read-only","--tmpfs","/tmp","--entrypoint","Rscript",base["Id"],"-e",PARENT_PROBE_R))
        verify_parent_runtime(runtime,policy)
        report["actual_parent_runtime_verified"]=True
        report["parent_runtime"]=runtime
    probe=subprocess.run(["docker","image","inspect",m["image_tag"]],capture_output=True,text=True)
    if probe.returncode==0:raise ValueError("OS_ENV_TAG_EXISTS: refusing to replace a candidate tag")
    if "No such image" not in probe.stderr and "No such object" not in probe.stderr:raise ValueError("could not establish candidate tag absence: "+probe.stderr)
    inv_path=m.get("inventory_path","/opt/omicstat/pkg_lock.csv" if m["lane"]=="R" else "/opt/omicstat/py_installed.csv")
    base_text=command("docker","run","--rm","--network","none","--read-only","--entrypoint","cat",base["Id"],inv_path)+"\n"
    subprocess.run(report["commands"][0],check=True)
    child=inspect(m["image_tag"])
    base_layers=base["RootFS"]["Layers"];child_layers=child["RootFS"]["Layers"]
    if child_layers[:len(base_layers)]!=base_layers:raise ValueError("candidate changed inherited filesystem layers")
    now=command("docker","run","--rm","--network","none","--read-only","--entrypoint","cat",child["Id"],inv_path)+"\n"
    diff=additive_diff(base_text,now,m["new_packages"],m["lane"])
    canonical=norm if m["lane"]=="py" else lambda x:x
    installed={canonical(k):v for k,v in inventory(now).items()}
    version_checks=[dict(package=r["package"],expected=r["version"],actual=installed.get(canonical(r["package"]),{}).get("version",installed.get(canonical(r["package"]),{}).get("Version"))) for r in rows]
    diff["locked_versions"]=version_checks
    diff["locked_versions_match"]=all(v["actual"]==v["expected"] for v in version_checks)
    diff["ok"]=diff["ok"] and diff["locked_versions_match"]
    report.update(executed=True,state="built" if diff["ok"] else "rejected",inventory_diff=diff,
                  image={"tag":m["image_tag"],"id":child["Id"],"size_bytes":child.get("Size")},
                  base_image={"tag":m["base_image"],"id":base["Id"]},
                  filesystem_prefix_preserved=True,layer_growth_bytes=child.get("Size",0)-base.get("Size",0))
    report["disk_warning"]=report["layer_growth_bytes"]>4*1024**3
    (candidate/"base_pkg_lock.csv").write_text(base_text);(candidate/"packages.csv").write_text(now)
    report["packages_sha256"]=sha(candidate/"packages.csv")
    args=["Rscript","--vanilla","-e","sessionInfo()"] if m["lane"]=="R" else ["python","-c","import sys,platform; print(sys.version); print(platform.platform())"]
    session=command("docker","run","--rm","--network","none","--read-only","--tmpfs","/tmp","--entrypoint",args[0],child["Id"],*args[1:])
    (candidate/"sessionInfo.txt").write_text(session+"\n")
    if inspect(m["base_image"])["Id"]!=base["Id"]:
        report.update(state="rejected",errors=["parent tag changed during candidate build"])
    (candidate/"candidate_report.json").write_text(dump(report))
    return report

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("candidate",type=pathlib.Path);p.add_argument("--root",type=pathlib.Path,default=ROOT)
    g=p.add_mutually_exclusive_group();g.add_argument("--build",action="store_true");g.add_argument("--check",action="store_true");g.add_argument("--plan-only",action="store_true")
    p.add_argument("--out",type=pathlib.Path);a=p.parse_args()
    try:r=build(a.candidate,a.root,a.build)
    except (ValueError,OSError,subprocess.SubprocessError) as e:r={"state":"blocked","error":str(e),"promotion":"deferred_by_owner"}
    if a.out:a.out.parent.mkdir(parents=True,exist_ok=True);a.out.write_text(dump(r))
    print(dump(r));return int(r.get("state") not in ("ready_to_build","built"))
if __name__=="__main__":raise SystemExit(main())
