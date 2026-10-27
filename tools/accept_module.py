#!/usr/bin/env python3
"""Run/checkpoint module acceptance. Golden/seal writes are owner-deferred.

Default execution is inside a verified, offline Docker image with source
mounted read-only. --native is a developer test seam, never locked acceptance.
"""
from __future__ import annotations
import argparse,hashlib,json,os,pathlib,platform,re,subprocess,sys
from acceptance.common import *
from acceptance.runner import Runner
from acceptance.pipeline import Pipeline
ROOT=pathlib.Path(__file__).resolve().parents[1]

def git(root,*args):
 try:return subprocess.check_output(['git','-C',str(root),*args],text=True,stderr=subprocess.DEVNULL).strip()
 except (OSError,subprocess.SubprocessError):return 'unknown'
def source_fingerprint(root,module,request,image):
 files=[]
 dependencies=[];fixture=root/'skills'/module/'tests/acceptance.json'
 if fixture.is_file():
  upstream=load(fixture).get('chain',{}).get('upstream_module')
  if upstream:
   if not re.fullmatch('[a-z0-9]+-[a-z0-9]+',upstream):raise ValueError('unsafe upstream module')
   dependencies.append(root/'skills'/upstream)
 for base in dependencies+[root/'skills'/module,root/'skills/_shared',root/'tools',root/'tests',root/'mcp',root/'acceptance/schemas',root/'acceptance/data/owner_review_datasets.json',root/'acceptance/data/ANCHOR_REGISTRY.md',root/'acceptance/data/fetch_anchor_data.sh',root/'env/owner_decisions.json']:
  for p in ([base] if base.is_file() else base.rglob('*')):
   if p.is_file() and '__pycache__' not in p.parts and p.suffix not in ('.pyc',):files.append((p.relative_to(root).as_posix(),sha(p)))
 return hashlib.sha256(json.dumps({'source':sorted(files),'request':request,'image':image},sort_keys=True,separators=(',',':')).encode()).hexdigest()
def tree_hashes(folder):return {p.relative_to(folder).as_posix():sha(p) for p in folder.rglob('*') if p.is_file() and not p.is_symlink()}
def checked_request(root,path,module=None):
 from lint_contracts import validate
 r=load(path);problems=validate(r,load(root/'acceptance/schemas/exec_request.v1.schema.json'))
 if problems:raise ValueError('invalid exec request: '+str(problems))
 if module and module not in r['modules']:raise ValueError('module is not listed in the exec request')
 for name in r['modules']:
  if not re.fullmatch('[a-z0-9]+-[a-z0-9]+',name) or not (root/'skills'/name/'module.json').is_file():raise ValueError('request names an unknown module')
 # Resolved candidates that require source preparation must bind exact locks.
 candidates={x for x in [r['image_candidate'],r.get('render_image_candidate'),*r.get('module_image_candidates',{}).values()] if x}
 locks={}
 for item in r.get('source_locks',[]):
  candidate=item['candidate']
  if candidate not in candidates or candidate in locks:raise ValueError('source lock names unknown/duplicate candidate')
  if item['path']!=candidate+'/sources.lock.json':raise ValueError('source lock path differs from candidate')
  lock=contained(root,safe_rel(item['path']))
  if sha(lock)!=item['sha256']:raise ValueError('source lock SHA differs from request')
  manifest=load(contained(root,safe_rel(candidate))/'manifest.json');rows=load(lock)['sources'];names=[x['package']for x in rows]
  if len(set(names))!=len(names) or set(names)!=set(manifest['new_packages']) or set(item['required_packages'])!=set(names):raise ValueError('source lock omits declared additive packages')
  locks[candidate]=item
 for candidate in candidates:
  manifest=load(contained(root,safe_rel(candidate))/'manifest.json')
  if manifest.get('source_preparation_required') and candidate not in locks:raise ValueError('candidate requires an explicit request source lock')
 from acceptance.source_requests import validate_preparation
 validate_preparation(r,locks)
 if r['fixtures_to_fetch']:
  registry=root/'acceptance/data/ANCHOR_REGISTRY.md'
  if not registry.is_file():raise ValueError('ANCHOR_REGISTRY missing; cannot authorize fixture resolution')
  ids=set(re.findall(r'\bF\d+\b',registry.read_text()))
  if not set(r['fixtures_to_fetch'])<=ids:raise ValueError('fixture IDs must come from ANCHOR_REGISTRY')
 return r

def run(module,*,root=ROOT,out=None,image=None,request=None,stages=None,full=False,native=False,resume=False,write_golden=False,runner_name=None,render_image=None):
 root=pathlib.Path(root).resolve()
 if not re.fullmatch('[a-z0-9]+-[a-z0-9]+',module):raise ValueError('unsafe module name')
 m=load(root/'skills'/module/'module.json');req=checked_request(root,request,module) if request else None
 if req:full=full or req['full_regression'];stages=stages or req['stages']
 selected=set(stages or STAGES)
 if not selected<=set(STAGES):raise ValueError('unknown acceptance stage')
 out=pathlib.Path(out or root/'acceptance/exemplars'/module).resolve()
 if out==root or out.is_relative_to(root/'skills') or out.is_relative_to(root/'tools') or any('golden' in p for p in out.parts):raise ValueError('evidence output may not overwrite source/protected paths')
 out.mkdir(parents=True,exist_ok=True);(out/'logs').mkdir(exist_ok=True);report_path=out/'ACCEPTANCE.json'
 if report_path.exists() and not resume:raise ValueError('ACCEPTANCE.json exists; use --resume for identical inputs or a fresh output directory')
 cfg=load(root/('env/r-env.json' if m['lane']=='R' else 'env/py/py-env.json'))
 tag=image or cfg['image']+':'+cfg['image_tag'];identity={'tag':None if native else tag,'id':None};environment_error=None
 if not native:
  try:
   if not tag.startswith(('omicstat-r:' if m['lane']=='R' else 'omicstat-py:')):raise ValueError('image must belong to the module lane')
   inspected=json.loads(subprocess.check_output(['docker','image','inspect',tag],text=True))[0];identity['id']=inspected['Id']
   if not re.fullmatch('sha256:[0-9a-f]{64}',identity['id']):raise ValueError('Docker returned an invalid image ID')
  except (OSError,ValueError,KeyError,subprocess.SubprocessError) as e:environment_error=str(e);identity['id']=None
 render_identity=None;render_error=None
 # Legacy metadata may have an empty builder list despite emitting a genuine
 # FigureRequest. An explicit canonical fixture requiring figures also binds R.
 fixture_path=root/'skills'/module/'tests/acceptance.json'
 fixture_requires_figures=fixture_path.is_file() and load(fixture_path).get('figure_policy')=='required'
 if m['lane']=='py' and (m.get('figure_builders') or fixture_requires_figures):
  render_identity={'tag':None,'id':None}
  if not native:
   try:
    rcfg=load(root/'env/r-env.json');rtag=render_image or rcfg['image']+':'+rcfg['image_tag'];render_identity['tag']=rtag
    if not rtag.startswith('omicstat-r:'):raise ValueError('render image must belong to R lane')
    inspected=json.loads(subprocess.check_output(['docker','image','inspect',rtag],text=True))[0];render_identity['id']=inspected['Id']
    if not re.fullmatch('sha256:[0-9a-f]{64}',render_identity['id']):raise ValueError('invalid R renderer image ID')
   except (OSError,ValueError,KeyError,subprocess.SubprocessError)as e:render_error=str(e);render_identity['id']=None
 fingerprint_image={'engine':identity,'renderer':render_identity} if render_identity is not None else identity
 fingerprint=source_fingerprint(root,module,req,fingerprint_image)
 record={'schema':'omicstat.acceptance.v1','module':module,'module_version':m['version'],'lane':m['lane'],'commit':git(root,'rev-parse','HEAD'),'branch':git(root,'branch','--show-current'),'image':identity,'started':now(),'finished':None,'runner':{'name':runner_name or 'unspecified','kind':'developer_native' if native else 'offline_container','host_platform':platform.platform(),'production_environment_verified':not native and identity['id'] is not None and (render_identity is None or render_identity['id'] is not None),'environment_error':environment_error},'stages':{s:{'status':'not_run'} for s in STAGES},'verdict':'fail','visual_review':None,'logs_dir':'logs','fingerprint':fingerprint,'anchors':[],'replay':{},'refusals':[],'chain':{},'figures':[],'golden':{},'seal':{},'regression':{},'write_golden_requested':bool(write_golden),'owner_policy':'deferred_by_owner','request':req,'checkpoints':{}}
 record['render_image']=render_identity;record['render_environment_error']=render_error
 if resume:
  prior=load(report_path)
  if prior['fingerprint']!=fingerprint:raise ValueError('resume fingerprint differs; use fresh evidence for changed source/request/image')
  for rel,digest in prior.get('artifact_hashes',{}).items():
   artifact=contained(out,safe_rel(rel))
   if not artifact.is_file() or sha(artifact)!=digest:raise ValueError('resume evidence drift: '+rel)
  record=prior;record['finished']=None;record['visual_review']=None
 runner=Runner(root,out,identity['id'],native=native);renderer=Runner(root,out,render_identity['id'],native=native) if render_identity is not None else None;pipe=Pipeline(root,module,out,runner,renderer)
 for key,folder in [('fixtures',pipe.fixtures),('canonical',pipe.run1)]:
  checkpoint=record.get('checkpoints',{}).get(key)
  if checkpoint is not None:
   if not folder.is_dir() or tree_hashes(folder)!=checkpoint:raise ValueError('resume artifact drift: '+key)
   if key=='fixtures':pipe.prepared=record.get('checkpoints',{}).get('canonical_prepared',True)
   else:pipe.ran=True
 pipe.refusal_prepared=record.get('checkpoints',{}).get('refusal_prepared',False)
 if pipe.refusal_prepared and 'fixtures' not in record.get('checkpoints',{}):raise ValueError('refusal preparation checkpoint lacks fixture bytes')
 if resume:
  for folder,valid in [(pipe.run1,pipe.ran),(pipe.run2,record['stages']['replay']['status']=='pass')]:
   if folder.exists() and not valid:
    archived=folder.with_name(folder.name+'.interrupted-'+now().replace(':','').replace('.',''));folder.rename(archived)
 protected_before=protected(root)
 def save(stage):
  if pipe.prepared or pipe.refusal_prepared:
   record['checkpoints']['fixtures']=tree_hashes(pipe.fixtures)
   record['checkpoints']['canonical_prepared']=pipe.prepared
  if pipe.ran:record['checkpoints']['canonical']=tree_hashes(pipe.run1)
  if pipe.refusal_prepared:record['checkpoints']['refusal_prepared']=True
  record['verdict'],record['incomplete_stages']=verdict(record,full)
  if not record['runner']['production_environment_verified']:record['verdict']='fail';record['environment_acceptance']='blocked: native or unavailable image is not production acceptance'
  record['artifact_hashes']={rel:digest for rel,digest in tree_hashes(out).items() if rel not in ('ACCEPTANCE.json','WORKLOG.md') and not rel.endswith('.tmp')}
  dump(report_path,record)
  with (out/'WORKLOG.md').open('a') as f:f.write('- '+now()+' '+stage+': '+record['stages'].get(stage,{}).get('status','checkpoint')+'\n')
 save('start')
 for stage in STAGES:
  if stage in ('golden','seal'):
   result={'status':'deferred_by_owner','writes_performed':False}
   if stage=='seal':
    sys.path.insert(0,str(root/'mcp'));from module_seal import verify_module_seal
    result['readonly_existing_verification']=verify_module_seal(root,module);lock=root/'skills'/module/'module_lock.json';result['lock_sha256']=sha(lock) if lock.exists() else None
   else:
    manifest=root/'skills'/module/'tests/golden_manifest.csv';result['manifest_sha256']=sha(manifest) if manifest.exists() else None
   record[stage]=result;record['stages'][stage]=result;save(stage);continue
  if stage not in selected or (stage=='regression' and not full):continue
  if resume and record['stages'][stage]['status'] in ('pass','not_applicable'):continue
  try:
   if stage=='regression':
    if native:raise ValueError('full regression requires locked Docker environments')
    host=Runner(root,out,native=True);env=os.environ.copy();env.update(OMICSTAT_IMAGE=tag,OMICSTAT_TEST_REPORT=str(out/'logs/full-regression.log'),OMICSTAT_TEST_ARTIFACTS=str(out/'regression'),OMICSTAT_WRITE_GOLDEN='')
    with (out/'logs/regression-host.log').open('w') as f:p=subprocess.run(['bash','env/test.sh' if m['lane']=='R' else 'env/py/test.sh'],cwd=root,env=env,stdin=subprocess.DEVNULL,stdout=f,stderr=subprocess.STDOUT,timeout=7200)
    log=(out/'logs/regression-host.log').read_text();skipped=[l for l in log.splitlines() if 'SKIP:' in l];failed=[l for l in log.splitlines() if l.startswith('FAIL')]
    seals=host.run(['python3','tools/reseal_all.py',tag,'--check','--report',str(out/'regression/seals.md')],'regression-seals')
    result={'status':'pass' if p.returncode==0 and not skipped and not failed and seals['ok'] else 'fail','passed':p.returncode==0,'failed':failed,'skipped':skipped,'seals_ok':seals['ok']}
   else:result=getattr(pipe,stage)()
  except Exception as e:result={'status':'blocked','problems':[type(e).__name__+': '+str(e)]}
  record['stages'][stage]=result
  if stage in ('anchors','refusals','figures'):record[stage]=result.get(stage,[])
  elif stage!='static':record[stage]=result
  save(stage)
 record['protected_files_unchanged']=protected(root)==protected_before
 record['finished']=now();save('finished')
 if not record['protected_files_unchanged']:record['verdict']='fail';record['protected_write_violation']=True
 from lint_contracts import validate
 errors=validate(record,load(root/'acceptance/schemas/acceptance.v1.schema.json'))
 if errors:record['verdict']='fail';record['schema_errors']=errors
 dump(report_path,record);return record

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('module');p.add_argument('--root',type=pathlib.Path,default=ROOT);p.add_argument('--out',type=pathlib.Path);p.add_argument('--image');p.add_argument('--render-image',help='Separately verified R image for Python figure requests');p.add_argument('--request',type=pathlib.Path);p.add_argument('--stages',nargs='+',choices=STAGES);p.add_argument('--full',action='store_true');p.add_argument('--native',action='store_true');p.add_argument('--resume',action='store_true');p.add_argument('--write-golden',action='store_true');p.add_argument('--runner');a=p.parse_args()
 try:r=run(a.module,root=a.root,out=a.out,image=a.image,request=a.request,stages=a.stages,full=a.full,native=a.native,resume=a.resume,write_golden=a.write_golden,runner_name=a.runner,render_image=a.render_image);print(json.dumps({'module':r['module'],'verdict':r['verdict'],'stages':{k:v['status'] for k,v in r['stages'].items()},'visual_review':None},indent=2));return int(r['verdict']=='fail')
 except (ValueError,OSError) as e:print(json.dumps({'verdict':'fail','error':str(e)}));return 2
if __name__=='__main__':raise SystemExit(main())
