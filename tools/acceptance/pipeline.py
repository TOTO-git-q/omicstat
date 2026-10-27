"""Executable module acceptance stages, with explicit missing-evidence blockers."""
import csv,json,pathlib,re,shutil,subprocess,sys
from .common import *
from .figures import inspect_figures,contact_sheet
from .runner import Runner
class Pipeline:
 def __init__(self,root,module,out,runner,render_runner=None):
  self.root=pathlib.Path(root).resolve();self.folder=self.root/'skills'/module;self.module=load(self.folder/'module.json');self.out=pathlib.Path(out);self.runner=runner;self.render_runner=render_runner
  self.fixture_path=self.folder/'tests/acceptance.json';self.fixture=load(self.fixture_path) if self.fixture_path.exists() else None
  self.run1=self.out/'runs/canonical';self.run2=self.out/'runs/replay';self.fixtures=self.out/'fixtures';self.anchor_file=self.out/'anchors.obtained.json';self.prepared=False;self.ran=False;self.refusal_prepared=False
  self.refusal_fixture=load(self.folder/'tests/refusal_fixture.json') if (self.folder/'tests/refusal_fixture.json').exists() else None
  if self.fixture:
   from lint_contracts import validate
   errors=validate(self.fixture,load(self.root/'acceptance/schemas/fixture.v1.schema.json'))
   if errors:raise ValueError('invalid acceptance fixture: '+str(errors))
 def engine(self,script):return ['Rscript' if str(script).endswith('.R') else 'python3',self.runner.path(script)]
 def values(self,outdir=None,upstream=None):return {'root':self.runner.path(self.root),'module':self.runner.path(self.folder),'fixtures':self.runner.path(self.fixtures),'outdir':self.runner.path(outdir or self.run1),'run1':self.runner.path(self.run1),'run2':self.runner.path(self.run2),'anchor_results':self.runner.path(self.anchor_file),'upstream':self.runner.path(upstream or self.out/'runs/upstream')}
 def expand(self,args,**kwargs):
  if not isinstance(args,list) or not all(isinstance(x,str) for x in args):raise ValueError('argv must be a string array')
  values=self.values(**kwargs);expanded=[]
  for x in args:
   for k,v in values.items():x=x.replace('{'+k+'}',v)
   if re.search(r'\{(?:root|module|fixtures|outdir|run1|run2|anchor_results|upstream)\}',x):raise ValueError('unexpanded fixture token')
   if x in ('--write-golden','--seal'):raise ValueError('protected write flag forbidden')
   expanded.append(x)
  return expanded
 def execute_script(self,command,stage,base=None):
  script=contained(base or self.folder,safe_rel(command['script']))
  if script.suffix not in ('.R','.py') or not script.is_file():raise ValueError('explicit R/Python fixture script required')
  return self.runner.run(self.engine(script)+self.expand(command['argv']),stage)
 def prepare(self):
  if self.prepared:return
  definition=self.fixture or self.refusal_fixture
  if not definition:raise ValueError('tests/acceptance.json is missing; no canonical fixture may be guessed')
  self.fixtures.mkdir(parents=True,exist_ok=True)
  for command in definition.get('prepare',[]):
   r=self.execute_script(command,'prepare')
   if not r['ok']:raise ValueError('fixture preparation failed: '+r['log'])
  self.prepared=True
  if self.fixture is None:self.refusal_prepared=True
 def render_output(self,directory,stage):
  request=directory/'figure_data/figure_request.json'
  if self.module['lane']!='py' or not request.is_file():return
  renderer=self.render_runner or (self.runner if self.runner.native else None)
  if renderer is None:raise ValueError('Python figures require a separately verified R image runner')
  r=renderer.run(['Rscript',renderer.path(self.root/'skills/_shared/scripts/render_figure_request.R'),'--run-dir',renderer.path(directory)],stage)
  if not r['ok']:raise ValueError('shared R figure rendering failed: '+r['log'])
  return {'argv':r['argv'],'returncode':r['returncode'],'timed_out':r['timed_out'],
          'log':r['log'],'log_sha256':sha(self.out/r['log']),'native':renderer.native,'image_id':renderer.image}
 def canonical(self):
  if self.ran:return
  if not self.fixture:raise ValueError('canonical acceptance.json is missing; refusal-only data cannot stand in for canonical anchors')
  self.prepare()
  if self.run1.exists():raise ValueError('canonical directory already exists without reusable checkpoint; use a fresh evidence directory')
  self.run1.parent.mkdir(parents=True,exist_ok=True)
  args=self.expand(self.fixture['canonical']['argv'])
  if '--outdir' not in args:raise ValueError('canonical argv must explicitly bind --outdir {outdir}')
  if args[args.index('--outdir')+1]!=self.runner.path(self.run1):raise ValueError('canonical outdir must be the evidence run directory')
  from .owner_data import source_hashes,input_snapshot
  sources_before=source_hashes(self.root,self.module['name'],self.fixture)
  inputs_before=input_snapshot(self.fixtures,self.fixture)
  command=self.engine(self.folder/self.module['entry'])+args
  r=self.runner.run(command,'canonical')
  if not r['ok']:raise ValueError('canonical run failed: '+r['log'])
  rendered=self.render_output(self.run1,'render-canonical')
  if source_hashes(self.root,self.module['name'],self.fixture)!=sources_before:raise ValueError('source changed during canonical execution')
  if input_snapshot(self.fixtures,self.fixture)!=inputs_before:raise ValueError('canonical input changed during execution')
  dump(self.out/'canonical_execution.json',{'schema':'omicstat.canonical-execution.v1','command':command,'runner_argv':r['argv'],
       'returncode':r['returncode'],'timed_out':r['timed_out'],'log':r['log'],'log_sha256':sha(self.out/r['log']),
       'source_scripts_sha256':sources_before,'input_snapshot':inputs_before,
       'artifacts_sha256':replay_inventory(self.run1),'renderer':rendered,
       'engine':{'native':self.runner.native,'image_id':self.runner.image}})
  self.ran=True
 def static(self):
  mod='skills/'+self.module['name'];py='python3';commands={
   'contracts':[py,'tools/lint_contracts.py',self.module['name'],'--check'],
   'defaults':[py,'tools/check_defaults.py',mod], 'flags':[py,'tools/check_flag_docs.py',mod],
   'frontmatter':[py,'tools/check_skill_frontmatter.py'], 'registry':[py,'tools/sync_registry.py','--check']}
  if self.module['lane']=='R':commands.update(lint_r=[py,'tools/lint_r.py',mod+'/scripts'],calls=['Rscript','tools/check_calls.R',mod])
  else:commands.update(calls_static=[py,'tools/check_calls_py_static.py',mod],calls_locked=[py,'tools/check_calls.py',mod])
  tools={k:self.runner.run(v,'static-'+k) for k,v in commands.items()}
  text=(self.folder/'SKILL.md').read_text();missing=[h for h in HEADINGS if '## '+h not in text]
  tools['headings']={'ok':not missing,'problems':missing}
  return {'status':'pass' if all(x['ok'] for x in tools.values()) else 'fail','tools':{k:{'ok':v['ok'],'problems':v.get('problems',[] if v['ok'] else [v.get('stderr','')[-4000:]]),'log':v.get('log')} for k,v in tools.items()}}
 def anchors(self):
  defs=load(contained(self.folder,self.module['anchors']))
  from lint_contracts import validate
  problems=validate(defs,load(self.root/'acceptance/schemas/anchors.v1.schema.json'))
  if problems:raise ValueError('invalid anchor definitions: '+str(problems))
  self.canonical()
  command=self.fixture.get('anchor_runner')
  if not command:raise ValueError('explicit anchor_runner is missing')
  run=self.execute_script(command,'anchors')
  if not run['ok']:return {'status':'fail','problems':['anchor script failed'],'anchors':[],'log':run['log']}
  actual=load(self.anchor_file)
  if not isinstance(actual,dict) or set(actual)!={a['id'] for a in defs}:raise ValueError('obtained anchor IDs must exactly match definitions')
  rows=[anchor_result(a,actual[a['id']]) for a in defs]
  return {'status':'pass' if all(r['pass'] for r in rows) else 'fail','anchors':rows}
 def replay(self):
  self.canonical();spec=contained(self.run1,self.fixture['canonical'].get('replay_spec','provenance/resolved_spec.json'))
  if not spec.is_file():raise ValueError('canonical resolved spec is missing')
  if self.run2.exists():raise ValueError('replay directory already exists; use a fresh evidence directory')
  r=self.runner.run(self.engine(self.folder/self.module['entry'])+['--spec',self.runner.path(spec),'--outdir',self.runner.path(self.run2)],'replay')
  if not r['ok']:return {'status':'fail','problems':['spec replay failed'],'log':r['log']}
  self.render_output(self.run2,'render-replay')
  result=compare_runs(self.run1,self.run2);return {'status':'pass' if result['ok'] else 'fail',**result}
 def refusals(self):
  rows=read_refusals(contained(self.folder,self.module['refusals']))
  if not rows:raise ValueError('refusal cases are empty')
  out=[]
  # A canonical real-data fixture must not hide a separate synthetic refusal
  # fixture (e.g. the retained 141000-nucleus resource guard). Prepare that
  # fixture only for refusals, and checkpoint it independently on resume.
  if self.refusal_fixture:
   if not self.refusal_prepared:
    self.fixtures.mkdir(parents=True,exist_ok=True)
    for command in self.refusal_fixture.get('prepare',[]):
     prepared=self.execute_script(command,'prepare-refusals')
     if not prepared['ok']:raise ValueError('refusal fixture preparation failed: '+prepared['log'])
    self.refusal_prepared=True
  else:self.prepare()
  for row in rows:
   directory=self.out/'runs/refusals'/row['case'];args=self.expand(row['argv'],outdir=directory)
   if '--outdir' not in args:args+=['--outdir',self.runner.path(directory)]
   r=self.runner.run(self.engine(self.folder/self.module['entry'])+args,'refusal-'+row['case']);out.append(refusal_result(row,r))
  return {'status':'pass' if all(r['pass'] for r in out) else 'fail','refusals':out}
 def chain(self):
  if not self.module['handoff']['inputs']:return {'status':'not_applicable','reason':'module declares no handoff inputs','positive':None,'negative':[]}
  self.prepare();cfg=self.fixture.get('chain')
  if not cfg:raise ValueError('declared handoff inputs require explicit upstream fixture and chain cases')
  upstream=contained(self.out,safe_rel(cfg['upstream_run']));command=cfg['upstream'];expected=self.root/'skills'/cfg['upstream_module']
  if not (expected/'module.json').is_file():raise ValueError('chain upstream must identify an existing module')
  script=contained(expected,safe_rel(command['script']));r=self.runner.run(self.engine(script)+self.expand(command['argv'],outdir=upstream,upstream=upstream),'chain-upstream')
  if not r['ok']:raise ValueError('upstream fixture failed: '+r['log'])
  handoff=upstream/'objects/handoff.json';doc=load(handoff)
  if doc.get('module')!=cfg['upstream_module']:raise ValueError('upstream handoff module identity differs')
  def consume(directory,label):
   dest=self.out/'runs'/label;args=self.expand(cfg['argv'],outdir=dest,upstream=directory)
   if '--from-run' not in args or args[args.index('--from-run')+1]!=self.runner.path(directory):raise ValueError('chain argv must bind --from-run {upstream}')
   if '--outdir' not in args:args+=['--outdir',self.runner.path(dest)]
   return self.runner.run(self.engine(self.folder/self.module['entry'])+args,label)
  positive=consume(upstream,'chain-positive');negative=[]
  if any(p.is_symlink() for p in upstream.rglob('*')):raise ValueError('upstream symlink artifact is forbidden')
  bad=self.out/'runs/chain-tampered';shutil.copytree(upstream,bad);tampered=load(bad/'objects/handoff.json')
  if not tampered.get('objects'):raise ValueError('upstream contains no typed objects')
  tampered['objects'][0]['sha256']='0'*64;dump(bad/'objects/handoff.json',tampered)
  r=consume(bad,'chain-negative-hash');negative.append(refusal_result({'case':'tampered-handoff','expected_code':'OS_HANDOFF_MISMATCH'},r))
  if cfg['expected_ecosystem']!='neutral':
   mixed=self.out/'runs/chain-mixed';shutil.copytree(upstream,mixed);d=load(mixed/'objects/handoff.json');other='scverse' if cfg['expected_ecosystem']!='scverse' else 'seurat';d['ecosystem']=other;d.setdefault('state',{})['front_end_ecosystem']=other;dump(mixed/'objects/handoff.json',d)
   negative.append(refusal_result({'case':'mixed-ecosystem','expected_code':'OS_ECOSYSTEM_MIXED'},consume(mixed,'chain-negative-ecosystem')))
  else:negative.append({'case':'mixed-ecosystem','status':'not_applicable','pass':True,'reason':'neutral module explicitly permits ecosystem crossings; hash negative still required'})
  return {'status':'pass' if positive['ok'] and all(x['pass'] for x in negative) else 'fail','positive':{'pass':positive['ok'],'log':positive['log']},'negative':negative}
 def figures(self):
  self.canonical();records=inspect_figures(self.run1)
  if not records:
   if self.fixture.get('figure_policy')=='none' and self.fixture.get('reason_no_figures') and not self.module['figure_builders']:return {'status':'not_applicable','reason':self.fixture['reason_no_figures'],'figures':[]}
   raise ValueError('required figure inventory is empty')
  contract_ok=all(r['lint']['ok'] for r in records)
  try:
   from .owner_data import bind_run
   declaration=self.fixture.get('owner_review')
   if not declaration:raise ValueError('registered real-data owner_review declaration is missing')
   receipt=load(contained(self.fixtures,safe_rel(declaration['receipt'])))
   input_argv={x['path']:self.runner.path(self.fixtures/safe_rel(x['path'])) for x in receipt.get('prepared_inputs',[])}
   evidence=self.out/'figures/owner_run_evidence.json'
   bind_run(self.root,self.module['name'],self.fixtures,self.run1,records,self.fixture,
            self.expand(self.fixture['canonical']['argv']),input_argv,evidence,execution_root=self.out,
            expected_command=self.engine(self.folder/self.module['entry'])+self.expand(self.fixture['canonical']['argv']))
   context=dict(root=self.root,module=self.module['name'],fixtures=self.fixtures,fixture=self.fixture,evidence_path=evidence,
                execution_root=self.out,expected_command=self.engine(self.folder/self.module['entry'])+self.expand(self.fixture['canonical']['argv']))
   sheet=contact_sheet(self.run1,records,self.out/'figures/CONTACT_SHEET.png',purpose='owner',owner_context=context)
   sheet['path']=str(pathlib.Path(sheet['path']).relative_to(self.out))
   return {'status':'pass' if contract_ok else 'fail','figures':records,'contact_sheet':sheet,
           'owner_data_evidence':str(evidence.relative_to(self.out)),'plot_contract_status':'pass' if contract_ok else 'fail','visual_review':None}
  except (ValueError,OSError,KeyError,TypeError) as error:
   sheet=contact_sheet(self.run1,records,self.out/'figures/CONTRACT_DIAGNOSTIC.png',purpose='contract')
   sheet['path']=str(pathlib.Path(sheet['path']).relative_to(self.out))
   return {'status':'blocked' if contract_ok else 'fail','figures':records,'contact_sheet':None,'contract_sheet':sheet,
           'plot_contract_status':'pass' if contract_ok else 'fail','owner_review_eligible':False,
           'problems':['Owner real-data sheet unavailable: '+str(error)],'visual_review':None}
