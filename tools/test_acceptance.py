#!/usr/bin/env python3
"""Acceptance mechanics and real native synthetic pipeline; no production claim."""
import copy,csv,hashlib,json,os,pathlib,shutil,subprocess,sys,tempfile,unittest
from unittest.mock import patch
import accept_module as am
from acceptance.common import *
from acceptance.pipeline import Pipeline
from acceptance.runner import Runner
from acceptance.figures import inspect_figures,contact_sheet
ROOT=pathlib.Path(__file__).resolve().parents[1]
ENGINE=r'''
import argparse,csv,hashlib,json,pathlib,sys
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[2]/'_shared/py'))
from ospy.handoff import write_handoff,read_handoff
from PIL import Image
p=argparse.ArgumentParser();p.add_argument('--outdir',required=True);p.add_argument('--spec');p.add_argument('--reject',action='store_true');p.add_argument('--from-run');a=p.parse_args()
if a.reject:print('OS_INVALID_INPUT: intentional synthetic refusal',file=sys.stderr);sys.exit(3)
if a.from_run:read_handoff(a.from_run,front_end_ecosystem='seurat')
out=pathlib.Path(a.outdir)
for s in ('tables','figures','objects','provenance'): (out/s).mkdir(parents=True,exist_ok=True)
(out/'tables/result.csv').write_text('value\n1\n2\n3\n')
Image.new('RGB',(120,80),'white').save(out/'figures/test.png')
sha=hashlib.sha256((out/'figures/test.png').read_bytes()).hexdigest()
(out/'figures/test.figure_spec.json').write_text(json.dumps({'schema':'omicstat.figure-spec.v1','figure_type':'synthetic_fixture','caption':'Synthetic fixture, not scientific evidence','width_mm':89,'height_mm':60,'png_dpi':600,'files':{'png':{'path':'figures/test.png','sha256':sha}},'lint':[],'evidence_refs':[]}))
(out/'provenance/resolved_spec.json').write_text(json.dumps({'argv':['--outdir',str(out)]}))
write_handoff(out,'synthetic',MODULE,'0.0.1',{'table':{'path':str(out/'tables/result.csv'),'type':'feature_table'}},ecosystem='seurat')
'''
ANCHOR="import csv,json,sys,pathlib\np=pathlib.Path(sys.argv[1]);rows=list(csv.DictReader((p/'tables/result.csv').open()));pathlib.Path(sys.argv[2]).write_text(json.dumps({'sum':sum(int(r['value']) for r in rows)}))\n"
class AcceptanceTests(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.root=pathlib.Path(self.tmp.name)/'repo';self.out=pathlib.Path(self.tmp.name)/'evidence';self.root.mkdir()
  for rel in ['acceptance/schemas','skills/_shared/py','skills/_shared/schemas']:
   shutil.copytree(ROOT/rel,self.root/rel,ignore=shutil.ignore_patterns('__pycache__'))
  (self.root/'env/py').mkdir(parents=True);dump(self.root/'env/py/py-env.json',{'image':'omicstat-py','image_tag':'test'})
  (self.root/'mcp').mkdir();shutil.copy(ROOT/'mcp/module_seal.py',self.root/'mcp/module_seal.py')
  self.module='omicstat-acceptancetoy'
  for name in [self.module,'omicstat-upstream']:
   d=self.root/'skills'/name;(d/'scripts').mkdir(parents=True);(d/'tests').mkdir();(d/'scripts/run.py').write_text('MODULE='+repr(name)+'\n'+ENGINE)
   dump(d/'module.json',{'name':name,'version':'0.0.1','lane':'py','entry':'scripts/run.py','anchors':'tests/anchors.json','refusals':'tests/refusals.csv','handoff':{'inputs':['feature_table'],'outputs':['feature_table']},'figure_builders':['os_heatmap']})
  d=self.root/'skills'/self.module;(d/'tests/anchors.py').write_text(ANCHOR)
  dump(d/'tests/anchors.json',[{'id':'sum','metric':'sum(value)','expected':6,'tolerance':0,'source':'synthetic integers 1,2,3; harness test only','scope':'plumbing','how':'replay'}])
  dump(d/'tests/acceptance.json',{'schema':'omicstat.acceptance-fixture.v1','canonical':{'argv':['--outdir','{outdir}']},'anchor_runner':{'script':'tests/anchors.py','argv':['{run1}','{anchor_results}']},'figure_policy':'required','chain':{'upstream_module':'omicstat-upstream','upstream':{'script':'scripts/run.py','argv':['--outdir','{outdir}']},'upstream_run':'runs/upstream','argv':['--from-run','{upstream}','--outdir','{outdir}'],'expected_ecosystem':'seurat'}})
  with (d/'tests/refusals.csv').open('w',newline='') as f:w=csv.writer(f);w.writerow(['case','argv','expected_code','stage']);w.writerow(['bad',json.dumps(['--reject']),'OS_INVALID_INPUT','input'])
  self.out.mkdir();self.runner=Runner(self.root,self.out,native=True);self.pipe=Pipeline(self.root,self.module,self.out,self.runner)
 def tearDown(self):self.tmp.cleanup()
 def test_numeric_tolerance_and_exact_labels(self):
  a={'expected':10,'tolerance':.01};self.assertTrue(anchor_result(a,10.1)['pass']);self.assertFalse(anchor_result(a,10.2)['pass']);self.assertFalse(anchor_result(a,True)['pass'])
  self.assertTrue(anchor_result({'expected':'yes','tolerance':0},'yes')['pass'])
 def test_replay_empty_or_changed_is_not_pass(self):
  a=self.out/'a';b=self.out/'b';a.mkdir();b.mkdir();self.assertFalse(compare_runs(a,b)['ok']);(a/'tables').mkdir();(b/'tables').mkdir();(a/'tables/a.csv').write_text('1');(b/'tables/a.csv').write_text('2');self.assertEqual(compare_runs(a,b)['differing_files'],['tables/a.csv'])
 def test_refusal_requires_nonzero_and_stderr_code(self):
  r={'expected_code':'OS_INVALID_INPUT'}
  for result in [{'returncode':0,'stderr':'OS_INVALID_INPUT'},{'returncode':1,'stdout':'OS_INVALID_INPUT','stderr':''},{'returncode':None,'stderr':'OS_INVALID_INPUT','timed_out':True}]:self.assertFalse(refusal_result(r,result)['pass'])
  self.assertTrue(refusal_result(r,{'returncode':2,'stderr':'OS_INVALID_INPUT: bad'})['pass'])
 def test_real_native_stage_roundtrip(self):
  for stage in ('anchors','replay','refusals','chain'):
   with self.subTest(stage=stage):self.assertEqual(getattr(self.pipe,stage)()['status'],'pass')
  figures=self.pipe.figures()
  self.assertEqual(figures['status'],'blocked');self.assertEqual(figures['plot_contract_status'],'pass')
  self.assertIsNone(figures['contact_sheet']);self.assertFalse(figures['owner_review_eligible'])
  self.assertEqual(figures['contract_sheet']['purpose'],'contract')
  self.assertFalse((self.out/'figures/CONTACT_SHEET.png').exists())
  self.assertLessEqual((self.out/'figures/CONTRACT_DIAGNOSTIC.png').stat().st_size,2*1024*1024)
 def test_changed_png_fails_sha_and_missing_lint_fails(self):
  self.pipe.canonical();spec=self.pipe.run1/'figures/test.figure_spec.json';d=load(spec);d.pop('lint');dump(spec,d)
  self.assertFalse(inspect_figures(self.pipe.run1)[0]['lint']['ok']);(self.pipe.run1/'figures/test.png').write_bytes(b'changed');self.assertIn('PNG SHA differs',str(inspect_figures(self.pipe.run1)))
 def test_all_stages_continue_and_golden_seal_stay_frozen(self):
  with patch.object(Pipeline,'static',return_value={'status':'fail','problems':['intentional static fixture failure']}):
   r=am.run(self.module,root=self.root,out=self.out,native=True,write_golden=True)
  self.assertEqual(r['verdict'],'fail');self.assertEqual(r['stages']['replay']['status'],'pass');self.assertEqual(r['stages']['chain']['status'],'pass');self.assertTrue(r['protected_files_unchanged'])
  for stage in ['golden','seal']:self.assertEqual(r[stage]['status'],'deferred_by_owner');self.assertFalse(r[stage]['writes_performed'])
  self.assertIsNone(r['visual_review']);self.assertFalse(list(self.root.rglob('golden_manifest.csv')));self.assertFalse(list(self.root.rglob('module_lock.json')))
 def test_complete_native_is_not_production_acceptance(self):
  with patch.object(Pipeline,'static',return_value={'status':'pass'}):r=am.run(self.module,root=self.root,out=self.out,native=True)
  self.assertEqual(r['verdict'],'fail');self.assertFalse(r['runner']['production_environment_verified'])
  self.assertEqual(r['incomplete_stages'],['figures']);self.assertNotIn('schema_errors',r)
 def test_partial_resume_and_tamper_refusal(self):
  with patch.object(Pipeline,'static',return_value={'status':'pass'}):
   r=am.run(self.module,root=self.root,out=self.out,native=True,stages=['static','anchors'])
   self.assertEqual(r['stages']['anchors']['status'],'pass');r=am.run(self.module,root=self.root,out=self.out,native=True,resume=True)
  self.assertEqual(r['stages']['replay']['status'],'pass');self.assertEqual(r['stages']['figures']['status'],'blocked')
  (self.out/'runs/replay/tables/result.csv').write_text('tampered')
  with self.assertRaisesRegex(ValueError,'evidence drift'):am.run(self.module,root=self.root,out=self.out,native=True,resume=True)
 def test_forged_visual_review_never_promotes(self):
  r={'stages':{s:{'status':'pass'} for s in STAGES},'visual_review':{'by':'invented owner','figures_ok':['all']}}
  self.assertEqual(verdict(r)[0],'needs_visual')
 def test_required_python_figures_bind_renderer_even_with_legacy_empty_builders(self):
  path=self.root/'skills'/self.module/'module.json';data=load(path);data['figure_builders']=[];dump(path,data)
  with patch.object(Pipeline,'static',return_value={'status':'pass'}):
   result=am.run(self.module,root=self.root,out=self.out,native=True,stages=['static'])
  self.assertIsNotNone(result['render_image']);self.assertFalse(result['runner']['production_environment_verified'])
 def test_separate_refusal_fixture_prepares_once_and_resume_preserves_it(self):
  folder=self.root/'skills'/self.module
  (folder/'tests/refusal_prepare.py').write_text("import pathlib,sys\np=pathlib.Path(sys.argv[1]);p.mkdir(parents=True,exist_ok=True)\nf=p/'refusal-only.txt'\nassert not f.exists(), 'must not prepare twice'\nf.write_text('synthetic refusal fixture only')\n")
  dump(folder/'tests/refusal_fixture.json',{'prepare':[{'script':'tests/refusal_prepare.py','argv':['{fixtures}']}]})
  with patch.object(Pipeline,'static',return_value={'status':'pass'}):
   first=am.run(self.module,root=self.root,out=self.out,native=True,stages=['anchors','refusals'])
   self.assertEqual(first['stages']['refusals']['status'],'pass');self.assertTrue(first['checkpoints']['refusal_prepared'])
   # Request a retry of the refusal stage without discarding verified inputs.
   first['stages']['refusals']['status']='blocked';dump(self.out/'ACCEPTANCE.json',first)
   second=am.run(self.module,root=self.root,out=self.out,native=True,resume=True,stages=['refusals'])
  self.assertEqual(second['stages']['refusals']['status'],'pass')
 def test_container_mounts_are_offline_readonly_source(self):
  runner=Runner(self.root,self.out,image='sha256:'+'a'*64)
  with patch('acceptance.runner.subprocess.run',return_value=subprocess.CompletedProcess([],0,'','')) as call:r=runner.run(['python3','--version'],'probe')
  argv=call.call_args.args[0];self.assertIn('--network=none',argv);self.assertIn(str(self.root)+':/omicstat:ro',argv);self.assertIn('OMICSTAT_WRITE_GOLDEN=',argv);self.assertTrue(r['ok'])
 def test_refusal_only_stage_does_not_need_missing_real_canonical_cache(self):
  folder=self.root/'skills'/self.module
  (folder/'tests/missing_real.py').write_text("raise FileNotFoundError('official data cache missing')\n")
  fixture=load(folder/'tests/acceptance.json');fixture['prepare']=[{'script':'tests/missing_real.py','argv':[]}];dump(folder/'tests/acceptance.json',fixture)
  dump(folder/'tests/refusal_fixture.json',{'prepare':[]})
  result=am.run(self.module,root=self.root,out=self.out,native=True,stages=['refusals'])
  self.assertEqual(result['stages']['refusals']['status'],'pass')
  self.assertFalse(result['checkpoints']['canonical_prepared']);self.assertTrue(result['checkpoints']['refusal_prepared'])
  resumed=am.run(self.module,root=self.root,out=self.out,native=True,stages=['anchors'],resume=True)
  self.assertEqual(resumed['stages']['anchors']['status'],'blocked')
  self.assertFalse((self.out/'runs/canonical').exists())
 def test_nan_json_and_path_escape_refused(self):
  p=self.out/'bad.json';p.write_text('{"x": NaN}')
  with self.assertRaises(ValueError):load(p)
  with self.assertRaises(ValueError):contained(self.root,'../outside')
if __name__=='__main__':unittest.main()
