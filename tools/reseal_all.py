#!/usr/bin/env python3
"""Run smoke and lock checks in a chosen image, preserving all sealed artifacts."""
import argparse,datetime,hashlib,json,pathlib,subprocess,sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
def protected():
    return {str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (ROOT/'skills').rglob('*') if p.is_file() and (p.name=='module_lock.json' or 'golden' in str(p.relative_to(ROOT)))}
def smoke_command(root,module):
    # Some R candidates deliberately use a Python orchestrator; lane is not
    # the smoke script language. Historical model scope suites are explicit.
    for filename,interpreter in [('run_smoke_test.R','Rscript'),('run_smoke_test.py','python3'),('run_development_test.R','Rscript')]:
        rel=f'skills/{module}/tests/{filename}'
        if (pathlib.Path(root)/rel).is_file():return [interpreter,rel]
    raise ValueError('No declared smoke/development test exists for '+module)
def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('image');ap.add_argument('--check',action='store_true');ap.add_argument('--dry-run',action='store_true');ap.add_argument('--plan-only',action='store_true');ap.add_argument('--report',type=pathlib.Path,default=ROOT/'docs/build/RESEAL_v2_REPORT.md');a=ap.parse_args()
    before=protected();rows=[]
    for p in sorted((ROOT/'skills').glob('*/module.json')):
        m=json.loads(p.read_text());name=m['name'];ext='R' if m['lane']=='R' else 'py'
        if m['lane']=='py' and not a.image.startswith('omicstat-py:'):continue
        if m['lane']=='R' and not a.image.startswith('omicstat-r:'):continue
        runner='Rscript' if ext=='R' else 'python3'
        for stage,command in [('smoke',smoke_command(ROOT,name)),('lock_check',[runner,f'tools/make_module_lock.{ext}',name,'--check'])]:
            argv=['docker','run','--rm','--network=none','-e','OMICSTAT_WRITE_GOLDEN=','-v',f'{ROOT}:/omicstat:ro','-w','/omicstat',a.image]+command
            rec={'module':name,'stage':stage,'command':argv,'status':'not_run'}
            if not a.plan_only:
                try:
                    proc=subprocess.run(argv,capture_output=True,text=True,timeout=1500);rec.update(status='pass' if proc.returncode==0 else 'fail',returncode=proc.returncode,output=(proc.stdout+proc.stderr)[-20000:])
                except (OSError,subprocess.TimeoutExpired) as e:rec.update(status='blocked',output=str(e))
            rows.append(rec)
    unchanged=protected()==before;doc={'schema':'omicstat.reseal-report.v2','mode':'check_only','seal_write':'deferred_by_owner','protected_files_unchanged':unchanged,'image':a.image,'stages':rows}
    a.report.parent.mkdir(parents=True,exist_ok=True);a.report.with_suffix('.json').write_text(json.dumps(doc,indent=2)+'\n')
    a.report.write_text('# Lock v2 check-only report\n\nSeal writes: deferred_by_owner.\n\nGolden and module_lock bytes unchanged: '+str(unchanged)+'\n\n'+'\n'.join(f'- {r["module"]} / {r["stage"]}: {r["status"]}' for r in rows)+'\n')
    print(a.report);return int(not unchanged or any(x['status'] in ('fail','blocked') for x in rows))
if __name__=='__main__':raise SystemExit(main())
